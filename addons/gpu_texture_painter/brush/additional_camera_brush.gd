@tool
class_name AdditionalCameraBrush
extends Node

var parent_camera_brush: CameraBrush = null

var viewport: SubViewport
var camera: Camera3D
var camera_brush_scene: PackedScene = preload("uid://be0n8acdsbi8p")

# Compute shader properties
# static
var rd: RenderingDevice
var shader: RID
var pipeline: RID

var brush_viewport_uniform_set: RID

func _init(parent: CameraBrush) -> void:
	parent_camera_brush = parent

func _ready() -> void:
	rd = RenderingServer.get_rendering_device()

	_setup()


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_cleanup_compute_shader)


func _setup() -> void:
	RenderingServer.call_on_render_thread(_cleanup_compute_shader)

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
	camera.projection = parent_camera_brush.projection
	camera.fov = parent_camera_brush.fov
	camera.size = parent_camera_brush.size
	camera.far = parent_camera_brush.max_distance
	viewport.size = parent_camera_brush.resolution
	viewport.render_target_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS if parent_camera_brush.drawing else SubViewport.UpdateMode.UPDATE_DISABLED

	# setup shader
	RenderingServer.call_on_render_thread(_create_shader_and_pipeline)
	RenderingServer.call_on_render_thread(_get_brush_viewport_texture)


func _create_shader_and_pipeline() -> void:
	if not rd:
		return

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
	if not viewport:
		return

	if not rd:
		return

	print("CameraBrush: Getting brush viewport texture")

	# get camera brush texture RID
	var viewport_texture := viewport.get_texture()
	var viewport_texture_rid := viewport_texture.get_rid()
	var viewport_rd_texture_rid := RenderingServer.texture_get_rd_texture(viewport_texture_rid)
	var brush_viewport_texture_rid = viewport_rd_texture_rid

	#create uniform
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(brush_viewport_texture_rid)

	# create uniform set
	brush_viewport_uniform_set = rd.uniform_set_create([uniform], shader, 0)


func dispatch_compute_shader(delta: float) -> void:
	if not rd:
		return

	if not pipeline.is_valid():
		return
	
	if not (brush_viewport_uniform_set.is_valid() and parent_camera_brush.brush_shape_uniform_set.is_valid() and parent_camera_brush.atlas_texture_uniform_set.is_valid()):
		return

	# prepare push constant
	var linear_color := parent_camera_brush.color.srgb_to_linear()
	var push_constant : PackedFloat32Array = PackedFloat32Array()
	push_constant.push_back(linear_color.r)
	push_constant.push_back(linear_color.g)
	push_constant.push_back(linear_color.b)
	push_constant.push_back(linear_color.a)
	push_constant.push_back(delta * 100)  # need 0.01 seconds to draw full opacity
	push_constant.push_back(parent_camera_brush.max_distance)
	push_constant.push_back(parent_camera_brush.start_distance_fade)
	push_constant.push_back(float(parent_camera_brush.min_bleed))
	push_constant.push_back(float(parent_camera_brush.max_bleed))
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, brush_viewport_uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, parent_camera_brush.brush_shape_uniform_set, 1)
	rd.compute_list_bind_uniform_set(compute_list, parent_camera_brush.atlas_texture_uniform_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, parent_camera_brush.x_groups, parent_camera_brush.y_groups, 1)
	rd.compute_list_end()


func _cleanup_compute_shader() -> void:	
	print("CameraBrush: Cleaning up compute shader and resources")

	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
