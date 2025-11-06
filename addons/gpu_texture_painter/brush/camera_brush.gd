@tool
class_name CameraBrush
extends Node3D

var viewport: SubViewport
var camera: Camera3D
var camera_brush_scene: PackedScene = preload("uid://be0n8acdsbi8p")

# Compute shader properties
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var camera_brush_texture_rid: RID
var brush_image_texture_rid: RID
var overlay_texture_rid: RID
var uniform_set: RID
var x_groups: int
var y_groups: int

@export var texture_manager: TextureManager:
	set(value):
		texture_manager = value
		call_deferred("_init_compute_shader_on_render_thread")

@export_group("Camera Settings")
@export var projection: Camera3D.ProjectionType = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
	set(value):
		projection = value
		notify_property_list_changed()
		if camera:
			camera.projection = projection

@export var fov: float = 5.0:
	set(value):
		fov = clampf(value, 0.1, 179.0)
		if camera:
			camera.fov = fov

@export var size: float = 0.5:
	set(value):
		size = maxf(value, 0.01)
		if camera:
			camera.size = size

@export var near: float = 0.1:
	set(value):
		near = maxf(value, 0.001)
		if camera:
			camera.near = near
@export var far: float = 1000.0:
	set(value):
		far = maxf(value, near + 0.01)
		if camera:
			camera.far = far

@export_group("Render Settings")
@export var brush_image: Image = preload("uid://b6knnm8h3nhpi"):
	set(value):
		brush_image = value
		if texture_manager:
			call_deferred("_init_compute_shader_on_render_thread")

@export var resolution: Vector2i = Vector2i(256, 256):
	set(value):
		resolution = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		if viewport:
			viewport.size = resolution

@export var color: Color = Color.ORANGE

@export var bleed: int = 0


@export var drawing: bool = true

func _enter_tree() -> void:
	if !viewport:
		_setup_viewport()
	if texture_manager:
		call_deferred("_init_compute_shader_on_render_thread")


func _process(delta: float) -> void:
	if not camera:
		return
	
	camera.global_position = global_position
	camera.global_rotation = global_rotation

	if drawing and pipeline.is_valid():
		RenderingServer.call_on_render_thread(_dispatch_compute_shader)


func _validate_property(property: Dictionary) -> void:
	if projection == Camera3D.ProjectionType.PROJECTION_ORTHOGONAL:
		if property.name == "fov":
			property.usage = PROPERTY_USAGE_NONE
	else:
		if property.name == "size":
			property.usage = PROPERTY_USAGE_NONE

	if property.name == "projection":
		property.hint_string = "Perspective,Orthogonal"


func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(_cleanup_compute_shader)


func _setup_viewport() -> void:
	if not camera_brush_scene:
		push_error("CameraBrush: Camera brush scene is not loaded")
		return
	
	viewport = camera_brush_scene.instantiate() as SubViewport
	if not viewport:
		push_error("CameraBrush: Failed to instantiate camera brush viewport scene")
		return

	add_child(viewport)

	camera = viewport.get_child(0) as Camera3D
	if not camera:
		push_error("CameraBrush: Failed to get camera from camera brush viewport scene")
		return

	camera.cull_mask += int(1) << int(20)  # Set layer 21 to detect brush render

	camera.projection = projection
	camera.fov = fov
	camera.size = size
	camera.near = near
	camera.far = far
	viewport.size = resolution


func _create_brush_image_texture() -> void:
	# Convert brush_image Texture2D to RenderingDevice texture
	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = brush_image.get_width()
	fmt.height = brush_image.get_height()
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	#var image := Image.create(overlay_texture_size, overlay_texture_size, false, Image.FORMAT_RGBAF)
	brush_image_texture_rid = rd.texture_create(fmt, view, [brush_image.get_data()]) 


func _init_compute_shader_on_render_thread() -> void:
	RenderingServer.call_on_render_thread(_init_compute_shader)

func _init_compute_shader() -> void:
	if not texture_manager or not viewport or not brush_image:
		return
	
	rd = RenderingServer.get_rendering_device()

	# Clean up existing shader resources if any
	_cleanup_compute_shader()

	var viewport_texture := viewport.get_texture()
	var viewport_texture_rid := viewport_texture.get_rid()
	var viewport_rd_texture_rid := RenderingServer.texture_get_rd_texture(viewport_texture_rid)
	
	# Store texture RIDs for compute shader
	camera_brush_texture_rid = viewport_rd_texture_rid

	_create_brush_image_texture()

	overlay_texture_rid = texture_manager.overlay_texture_rid

	# create shader
	var shader_file := load("uid://bwm7j25sbgip3")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

	# input uniform: camera brush texture
	var camera_brush_texture_uniform := RDUniform.new()
	camera_brush_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	camera_brush_texture_uniform.binding = 0
	camera_brush_texture_uniform.add_id(camera_brush_texture_rid)

	# input uniform: brush image texture
	var brush_image_uniform := RDUniform.new()
	brush_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	brush_image_uniform.binding = 1
	brush_image_uniform.add_id(brush_image_texture_rid)

	# output uniform: overlay texture
	var overlay_texture_uniform := RDUniform.new()
	overlay_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	overlay_texture_uniform.binding = 2
	overlay_texture_uniform.add_id(overlay_texture_rid)

	# create uniform set
	uniform_set = rd.uniform_set_create([camera_brush_texture_uniform, brush_image_uniform, overlay_texture_uniform], shader, 0)

	# get texture size to calculate work groups
	var tex_format := rd.texture_get_format(overlay_texture_rid)
	var tex_size := Vector2i(tex_format.width, tex_format.height)
	
	x_groups = (tex_size.x - 1) / 8 + 1
	y_groups = (tex_size.y - 1) / 8 + 1


func _dispatch_compute_shader() -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _cleanup_compute_shader() -> void:
	if not rd:
		return
	
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
	brush_image_texture_rid = RID()
