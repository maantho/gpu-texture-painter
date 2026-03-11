@tool
@icon("uid://c1jgnh1db12t")
class_name OverlayAtlasManager
extends Node3D


const  GROUP_NAME := "overlay_atlas_managers"

## Size of the overlay atlas texture (width and height in pixels).
@export_range(1, 1024 * 4) var atlas_size: int = 1024:
	set(value):
		atlas_size = clampi(value, 1, 1024 * 4)
		RenderingServer.call_on_render_thread(_create_texture)
		_apply_texture_to_texture_resource()
		
@export_storage var atlas_texture_resource: Texture2DRD = null
## Shader used for overlay materials.
@export var overlay_shader: Shader = preload("uid://qow53ph8eivf")

## Calculates the atlas and applies the overlay materials to all MeshInstance3D children & siblings.
@export_tool_button("Apply") var apply_action = apply

@export var apply_on_ready: bool = false

var atlas_index: int = 0

var rd: RenderingDevice
var atlas_texture_rid: RID = RID()

@export_category("Storage")
# File load and save
@export_file("*.webp", "*.png", "*.exr") var atlas_texture_path: String
@export_tool_button("Save atlas to file") var save_action = save_atlas_texture_to_file


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_get_atlas_index()

	rd = RenderingServer.get_rendering_device()
	
	if apply_on_ready:
		# create everything from scratch
		apply()
	else:
		# create texture and apply to existing resource
		RenderingServer.call_on_render_thread(_create_texture)
		_apply_texture_to_texture_resource()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_cleanup_texture)


func apply() -> void:
	RenderingServer.call_on_render_thread(_create_texture)
	_create_texture_resource()
	_apply_texture_to_texture_resource()
	_construct_atlas_and_apply_materials()


func _get_atlas_index() -> void:
		var possible_index: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]

		var all_managers := get_tree().get_nodes_in_group(GROUP_NAME)
		
		if all_managers.is_empty():
			return

		for manager: OverlayAtlasManager in all_managers:
			if manager == null or manager == self:
				continue
			possible_index.erase(manager.atlas_index)
		
		if possible_index.is_empty():
			push_error("OverlayAtlasManager: No available atlas indices left! Maximum of 8 overlay atlases reached.")
			return
		
		atlas_index = possible_index[0]
		print("OverlayAtlasManager: Assigned atlas index {0}".format([atlas_index]))


func _create_texture() -> void:
	if not rd:
		return

	print("OverlayAtlasManager: Creating overlay texture of size {0}x{0}".format([atlas_size]))

	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = atlas_size
	fmt.height = atlas_size
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# create texture view
	var view := RDTextureView.new()


	var image: Image

	# try to load texture from file
	if !atlas_texture_path.is_empty() and FileAccess.file_exists(atlas_texture_path):
		var loaded = load(atlas_texture_path)
		if loaded:
			if loaded is Texture2D:
				image = loaded.get_image()
			if loaded is Image:
				image = loaded
			image.decompress()
	
	#if not loaded create new image
	if !image:
		image = Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)

	# crete texture on RenderingDevice
	atlas_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 

	# notify brushes
	get_tree().call_group(CameraBrush.GROUP_NAME, "get_atlas_textures")


func _create_texture_resource() -> void:
		atlas_texture_resource = Texture2DRD.new()


func _apply_texture_to_texture_resource() -> void:
	#create Texture2DRD
	if not atlas_texture_resource:
		_create_texture_resource()
	
	atlas_texture_resource.texture_rd_rid = atlas_texture_rid  # handles cleanup of old RID
	notify_property_list_changed()


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
		mesh_instance.material_overlay.set_shader_parameter("atlas_index", atlas_index)
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


func _cleanup_texture() -> void:
	print("OverlayAtlasManager: Cleaning up overlay texture")
	if atlas_texture_resource:
			atlas_texture_resource.texture_rd_rid = RID()
	if atlas_texture_rid.is_valid():
		rd.free_rid(atlas_texture_rid)


func save_atlas_texture_to_file() -> void:
	if not Engine.is_editor_hint():
		push_warning("OverlayAtlasManager: Texture saving is only available in the editor.")
		return

	# get image form RenderingDevice
	var image := Image.create_from_data(atlas_size, atlas_size, false, Image.FORMAT_RGBA8, rd.texture_get_data(atlas_texture_rid, 0))

	# if no path is set, search for best option
	if atlas_texture_path.is_empty() or !FileAccess.file_exists(atlas_texture_path):
		var base_path: String = get_tree().edited_scene_root.scene_file_path.get_basename()
		var found := false
		# try paths until available one is found
		for i in range(50):
			var test_path := base_path + "_overlay_atlas_{0}.webp".format([i])
			if !FileAccess.file_exists(test_path):
				atlas_texture_path = test_path
				found = true
				break
		if !found:
			push_warning("OverlayAtlasManager: Could not save atlas texture, already 50 atlases where found belinging to this scene.")
			return

	# save as lossless webp
	image.save_webp(atlas_texture_path)
	print("OverlayAtlasManager: Saved atlas texture to '{0}'".format([atlas_texture_path]))

	# reimport the specific file so changes are picked in the Editor
	EditorInterface.get_resource_filesystem().update_file(atlas_texture_path)
	EditorInterface.get_resource_filesystem().reimport_files([atlas_texture_path])

	# mark scene as modified, does not work correctly :(
	notify_property_list_changed()
