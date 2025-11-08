@tool
class_name CameraBrush
extends Node3D


@export var texture_manager: TextureManager:
	set(value):
		texture_manager = value
		_get_overlay_texture()

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

@export var max_distance: float = 1000.0:
	set(value):
		max_distance = value
		if camera:
			max_distance = maxf(value, camera.near + 0.01)
			camera.far = max_distance

@export_group("Render Settings")
@export var brush_shape: Image = preload("uid://b6knnm8h3nhpi"):
	set(value):
		brush_shape = value
		_create_brush_shape_texture()

@export var resolution: Vector2i = Vector2i(256, 256):
	set(value):
		resolution = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		_calculate_work_groups()
		if viewport:
			viewport.size = resolution
			_get_brush_viewport_texture()

@export var color: Color = Color.ORANGE

@export var bleed: int = 0
@export_range(0, 1, 0.01) var start_bleed_fade: float = 1.0

@export_range(0, 1, 0.01) var start_distance_fade: float = 1.0

@export var drawing: bool = true


var viewport: SubViewport
var camera: Camera3D
var camera_brush_scene: PackedScene = preload("uid://be0n8acdsbi8p")

# Compute shader properties
# static
var rd: RenderingDevice
var shader: RID
var pipeline: RID

var brush_viewport_texture_rid: RID
var brush_viewport_uniform_set: RID

#dynamic
var brush_shape_texture_rid: RID
var brush_shape_uniform_set: RID

var overlay_texture_rid: RID
var overlay_texture_uniform_set: RID

var x_groups: int
var y_groups: int


func _enter_tree() -> void:
	if not viewport:
		_setup()
	
	_create_brush_shape_texture()
	_get_overlay_texture()
	_calculate_work_groups()


func _process(delta: float) -> void:
	if not camera:
		return
	
	camera.global_position = global_position
	camera.global_rotation = global_rotation

	if drawing and pipeline.is_valid():
		RenderingServer.call_on_render_thread(_dispatch_compute_shader.bind(delta))


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


func _setup() -> void:
	_cleanup_compute_shader()

	# setup viewport nodes
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

	camera.cull_mask = int(1) << int(20)  # Set layer 21 to detect brush render

	# apply initial settings
	camera.projection = projection
	camera.fov = fov
	camera.size = size
	camera.far = max_distance
	viewport.size = resolution

	# setup shader
	rd = RenderingServer.get_rendering_device()
	_create_shader_and_pipeline()
	_get_brush_viewport_texture()

	#try start
	_create_brush_shape_texture()
	_get_overlay_texture()
	_calculate_work_groups()


func _create_shader_and_pipeline() -> void:
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
	
	print("CameraBrush: Creating compute shader and pipeline")

	# create shader
	var shader_file := load("uid://bwm7j25sbgip3")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)


func _get_brush_viewport_texture() -> void:
	if brush_viewport_uniform_set.is_valid():
		print("free: " + str(brush_viewport_uniform_set))
		rd.free_rid(brush_viewport_uniform_set)
		brush_viewport_uniform_set = RID()

	print("CameraBrush: Getting brush viewport texture")

	# get camera brush texture RID
	var viewport_texture := viewport.get_texture()
	var viewport_texture_rid := viewport_texture.get_rid()
	var viewport_rd_texture_rid := RenderingServer.texture_get_rd_texture(viewport_texture_rid)
	brush_viewport_texture_rid = viewport_rd_texture_rid

	#create uniform
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(brush_viewport_texture_rid)

	# create uniform set
	brush_viewport_uniform_set = rd.uniform_set_create([uniform], shader, 0)
	print("new: " + str(brush_viewport_uniform_set))



func _create_brush_shape_texture() -> void:
	if not brush_shape:
		return

	if brush_shape_uniform_set.is_valid():
		rd.free_rid(brush_shape_uniform_set)
		brush_shape_uniform_set = RID()
	
	if brush_shape_texture_rid.is_valid():
		rd.free_rid(brush_shape_texture_rid)
		brush_shape_texture_rid = RID()

	print("CameraBrush: Creating brush shape texture")

	# create texure format
	var fmt := RDTextureFormat.new()
	fmt.width = brush_shape.get_width()
	fmt.height = brush_shape.get_height()
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	#var image := Image.create(overlay_texture_size, overlay_texture_size, false, Image.FORMAT_RGBAF)
	brush_shape_texture_rid = rd.texture_create(fmt, view, [brush_shape.get_data()]) 

	# create uniform
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(brush_shape_texture_rid)

	brush_shape_uniform_set = rd.uniform_set_create([uniform], shader, 1)


func _get_overlay_texture() -> void:
	if not texture_manager:
		return
	
	if not texture_manager.overlay_texture_rid.is_valid():
		return

	if overlay_texture_uniform_set.is_valid():
		rd.free_rid(overlay_texture_uniform_set)
		overlay_texture_uniform_set = RID()


	print("CameraBrush: Getting overlay texture")

	overlay_texture_rid = texture_manager.overlay_texture_rid

	# output uniform: overlay texture
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(overlay_texture_rid)

	# create uniform set
	overlay_texture_uniform_set = rd.uniform_set_create([uniform], shader, 2)


func _calculate_work_groups() -> void:
	print("CameraBrush: Calculating work groups")

	x_groups = (resolution.x - 1) / 8 + 1
	y_groups = (resolution.y - 1) / 8 + 1


func _dispatch_compute_shader(delta: float) -> void:
	if not pipeline.is_valid():
		return
	
	if not (brush_viewport_uniform_set.is_valid() and brush_shape_uniform_set.is_valid() and overlay_texture_uniform_set.is_valid()):
		return

	# prepare push constant
	var linear_color := color.srgb_to_linear()
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(linear_color.r)
	push_constant.push_back(linear_color.g)
	push_constant.push_back(linear_color.b)
	push_constant.push_back(linear_color.a)
	push_constant.push_back(delta * 100)  # need 0.01 seconds to draw full opacity
	push_constant.push_back(max_distance)
	push_constant.push_back(start_distance_fade)
	push_constant.push_back(float(bleed))
	push_constant.push_back(start_bleed_fade)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, brush_viewport_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, brush_shape_uniform_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, overlay_texture_uniform_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_end()


func _cleanup_compute_shader() -> void:	
	if brush_viewport_uniform_set.is_valid():
		print("free: " + str(brush_viewport_uniform_set))
		rd.free_rid(brush_viewport_uniform_set)
		brush_viewport_uniform_set = RID()

	if brush_shape_uniform_set.is_valid():
		rd.free_rid(brush_shape_uniform_set)
		brush_shape_uniform_set = RID()
	
	if brush_shape_texture_rid.is_valid():
		rd.free_rid(brush_shape_texture_rid)
		brush_shape_texture_rid = RID()

	if overlay_texture_uniform_set.is_valid():
		rd.free_rid(overlay_texture_uniform_set)
		overlay_texture_uniform_set = RID()

	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
