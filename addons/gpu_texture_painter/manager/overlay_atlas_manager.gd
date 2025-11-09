@tool
class_name OverlayAtlasManager
extends Node

@export_range(0, 8192) var atlas_size: int = 1024
var atlas_texture_rid: RID = RID()
@export_storage var atlas_texture_resource: Texture2DRD = null

@export var overlay_shader: Shader = preload("uid://qow53ph8eivf")

@export_tool_button("Apply") var apply_action = apply

var rd: RenderingDevice

const  GROUP_NAME := "overlay_atlas_managers"

func _ready() -> void:
	add_to_group(GROUP_NAME)

	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_create_texture)
	_apply_texture_to_texture_resource()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_cleanup_texture)


func apply() -> void:
	RenderingServer.call_on_render_thread(_create_texture)
	_apply_texture_to_texture_resource()
	_construct_atlas_and_apply_materials()


func _construct_atlas_and_apply_materials() -> void:
	var mesh_instances :=  _get_child_mesh_instances(get_parent())

	# pack into atlas
	var rects: Array[Vector2] = []
	for i in range(mesh_instances.size() - 1, -1, -1):
		var mesh_instance = mesh_instances[i]
		if mesh_instance.mesh == null:
			mesh_instances.erase(mesh_instance)
			push_warning("MeshInstance3D '{0}' has no mesh assigned, skipping overlay material application.".format([mesh_instance.name]))
		else:
			if mesh_instance.mesh.lightmap_size_hint == Vector2i.ZERO:
				mesh_instances.erase(mesh_instance)
				push_warning("MeshInstance3D '{0}' has no lightmap size hint set, skipping overlay material application.".format([mesh_instance.name]))
			else:
				rects.push_back(Vector2(mesh_instance.mesh.lightmap_size_hint))
	
	rects.reverse()

	var packed_rects: Array[Rect2] = MaxRectsPacker.pack_into_square(rects)

	print("OverlayAtlasManager: Packed {0} mesh instances into overlay atlas of size {1}x{1}".format([mesh_instances.size(), atlas_size]))

	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = overlay_shader

	for i in mesh_instances.size():
		var mesh_instance = mesh_instances[i]
		mesh_instance.material_overlay = overlay_material.duplicate()
		mesh_instance.material_overlay.set_shader_parameter("overlay_texture", atlas_texture_resource)
		mesh_instance.material_overlay.set_shader_parameter("position_in_atlas", packed_rects[i].position)
		mesh_instance.material_overlay.set_shader_parameter("size_in_atlas", packed_rects[i].size)
		mesh_instance.layers |= 1 << 20  # enable overlay layer 21
	
	print("OverlayAtlasManager: Applied overlay materials to mesh instances")


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


func _create_texture() -> void:
	if atlas_texture_rid.is_valid():
		if rd.texture_get_format(atlas_texture_rid).width == atlas_size:
			print("OverlayAtlasManager: Overlay texture already exists with correct size, skipping creation.")
			return

	print("OverlayAtlasManager: Creating overlay texture of size {0}x{0}".format([atlas_size]))

	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = atlas_size
	fmt.height = atlas_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	var image := Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBAF)
	atlas_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 

	# notify brushes
	get_tree().call_group(CameraBrush.GROUP_NAME, "set_atlas_texture", atlas_texture_rid)


func _apply_texture_to_texture_resource() -> void:
	#create Texture2DRD
	if not atlas_texture_resource:
		atlas_texture_resource = Texture2DRD.new()
	
	atlas_texture_resource.texture_rd_rid = atlas_texture_rid  # handles cleanup of old RID
	notify_property_list_changed()


func _cleanup_texture() -> void:
	print("OverlayAtlasManager: Cleaning up overlay texture")
	if atlas_texture_resource:
			atlas_texture_resource.texture_rd_rid = RID()
	if atlas_texture_rid.is_valid():
		rd.free_rid(atlas_texture_rid)
