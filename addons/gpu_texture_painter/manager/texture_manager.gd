@tool
class_name TextureManager
extends Node

@export var overlay_material: Material = preload("uid://bdnbf5ol6km4a")
@export_tool_button("Apply Materials") var tmp = _apply_materials

@export var overlay_texture_size: int = 1024
var overlay_texture_rid: RID = RID()
@export_storage var overlay_texture_resource: Texture2DRD = null

var rd: RenderingDevice

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rd = RenderingServer.get_rendering_device()
	_create_texture()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _exit_tree() -> void:
	if overlay_texture_rid and rd:
		rd.free_rid(overlay_texture_rid)
		overlay_texture_rid = RID()
		overlay_texture_resource.texture_rd_rid = RID()

func _apply_materials() -> void:
	var mesh_instances :=  _get_child_mesh_instances(get_parent())

	var rects: Array[Vector2] = []
	for mesh_instance in mesh_instances:
		rects.push_back(Vector2(mesh_instance.mesh.lightmap_size_hint))

	var packed_rects: Array[Rect2] = MaxRectsPacker.pack_into_square(rects)

	for mesh_instance in mesh_instances:
		mesh_instance.material_overlay = overlay_material.duplicate()
		mesh_instance.material_overlay.set_shader_parameter("overlay_texture", overlay_texture_resource)
		mesh_instance.material_overlay.set_shader_parameter("position_in_atlas", packed_rects[mesh_instances.find(mesh_instance)].position)
		mesh_instance.material_overlay.set_shader_parameter("size_in_atlas", packed_rects[mesh_instances.find(mesh_instance)].size)
		print("set material")


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
	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = overlay_texture_size
	fmt.height = overlay_texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	#var image := Image.create(overlay_texture_size, overlay_texture_size, false, Image.FORMAT_RGBAF)
	var image := Image.load_from_file("uid://b8e56cw41rh6y")
	overlay_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 

	_apply_texture_to_texture_resource()


func _apply_texture_to_texture_resource() -> void:
	#create Texture2DRD
	if not overlay_texture_resource:
		overlay_texture_resource = Texture2DRD.new()
	
	overlay_texture_resource.texture_rd_rid = overlay_texture_rid
	notify_property_list_changed()
