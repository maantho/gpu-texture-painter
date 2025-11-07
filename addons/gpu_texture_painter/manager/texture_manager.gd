@tool
class_name TextureManager
extends Node

@export_range(0, 8192) var overlay_texture_size: int = 1024
var overlay_texture_rid: RID = RID()
@export_storage var overlay_texture_resource: Texture2DRD = null
@export_tool_button("Recreate Texture") var texture_action = _create_texture_apply_resource

@export var overlay_shader: Shader = preload("uid://qow53ph8eivf")
@export_tool_button("Construct Atlas and Apply Materials") var material_action = _construct_atlas_and_apply_materials

var rd: RenderingDevice


func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_create_texture_apply_resource()


func _exit_tree() -> void:
	if overlay_texture_resource:
		overlay_texture_resource.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(_cleanup_texture)


func _construct_atlas_and_apply_materials() -> void:
	var mesh_instances :=  _get_child_mesh_instances(get_parent())

	# pack into atlas
	var rects: Array[Vector2] = []
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh == null:
			mesh_instances.erase(mesh_instance)
			push_warning("MeshInstance3D '{0}' has no mesh assigned, skipping overlay material application.".format([mesh_instance.name]))
		else:
			if mesh_instance.mesh.lightmap_size_hint == Vector2i.ZERO:
				mesh_instances.erase(mesh_instance)
				push_warning("MeshInstance3D '{0}' has no lightmap size hint set, skipping overlay material application.".format([mesh_instance.name]))
			else:
				rects.push_back(Vector2(mesh_instance.mesh.lightmap_size_hint))

	var packed_rects: Array[Rect2] = MaxRectsPacker.pack_into_square(rects)

	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = overlay_shader

	for i in mesh_instances.size():
		var mesh_instance = mesh_instances[i]
		mesh_instance.material_overlay = overlay_material.duplicate()
		mesh_instance.material_overlay.set_shader_parameter("overlay_texture", overlay_texture_resource)
		mesh_instance.material_overlay.set_shader_parameter("position_in_atlas", packed_rects[i].position)
		mesh_instance.material_overlay.set_shader_parameter("size_in_atlas", packed_rects[i].size)


func _get_self_and_child_mesh_instances(node: Node, children_acc: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		children_acc.push_back(node)
		
	for child in node.get_children():
		children_acc = _get_self_and_child_mesh_instances(child, children_acc)

	return children_acc


func _get_child_mesh_instances(node: Node, children_acc: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	for child in node.get_children():
		children_acc = _get_self_and_child_mesh_instances(child, children_acc)

	return children_acc


func _create_texture_apply_resource() -> void:
	RenderingServer.call_on_render_thread(_create_texture)
	_apply_texture_to_texture_resource()


func _create_texture() -> void:
	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = overlay_texture_size
	fmt.height = overlay_texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	#var image := Image.create(overlay_texture_size, overlay_texture_size, false, Image.FORMAT_RGBAF)
	var image := Image.load_from_file("uid://b8e56cw41rh6y")
	overlay_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 


func _apply_texture_to_texture_resource() -> void:
	#create Texture2DRD
	if not overlay_texture_resource:
		overlay_texture_resource = Texture2DRD.new()
	
	overlay_texture_resource.texture_rd_rid = overlay_texture_rid  # handles cleanup of old RID
	notify_property_list_changed()


func _cleanup_texture() -> void:
	if overlay_texture_rid.is_valid():
		rd.free_rid(overlay_texture_rid)
