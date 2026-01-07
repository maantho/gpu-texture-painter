@tool
class_name BrushCompositorEffect
extends CompositorEffect

var camera_brush: CameraBrush

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var dummy_texture_rid: RID

# can change
var brush_shape_texture_rid: RID
var brush_shape_uniform_set: RID

var atlas_texture_uniform_set: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)
	RenderingServer.call_on_render_thread(_create_dummy_texture)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)
		
		if brush_shape_texture_rid.is_valid():
			rd.free_rid(brush_shape_texture_rid)
			brush_shape_texture_rid = RID()

		if dummy_texture_rid.is_valid():
			rd.free_rid(dummy_texture_rid)
			dummy_texture_rid = RID()


#region Code in this region runs on the rendering thread.
# Compile our shader at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Compile our shader.
	var shader_file := load("uid://bwm7j25sbgip3")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


func create_brush_shape_texture() -> void:
	if not camera_brush:
		return

	if not camera_brush.brush_shape:
		return
	
	if not rd:
		return

	
	if brush_shape_texture_rid.is_valid():
		rd.free_rid(brush_shape_texture_rid)
		brush_shape_texture_rid = RID()

	print("CameraBrush: Creating brush shape texture")

	# Get image from texture and convert to RGBAF format
	var image := camera_brush.brush_shape.get_image()
	if image.get_format() != Image.FORMAT_RGBAF:
		image.convert(Image.FORMAT_RGBAF)

	# create texture format
	var fmt := RDTextureFormat.new()
	fmt.width = image.get_width()
	fmt.height = image.get_height()
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture with storage bit for image2D access
	brush_shape_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 

	# create uniform
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0
	uniform.add_id(brush_shape_texture_rid)

	brush_shape_uniform_set = rd.uniform_set_create([uniform], shader, 1)


func _create_dummy_texture() -> void:
	if not rd:
		return

	if dummy_texture_rid.is_valid():
		rd.free_rid(dummy_texture_rid)
		dummy_texture_rid = RID()

	var fmt := RDTextureFormat.new()
	fmt.width = 1
	fmt.height = 1
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT

	# create texture view
	var view := RDTextureView.new()

	# create texture
	var image := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	dummy_texture_rid = rd.texture_create(fmt, view, [image.get_data()]) 


func get_atlas_textures(all_managers: Array[Node]) -> void:
	if not rd:
		return

	var uniform_array: Array[RDUniform] = []
	uniform_array.resize(8)

	for manager: OverlayAtlasManager in all_managers:
		if manager == null:
			continue

		var uniform := RDUniform.new()
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		uniform.binding = manager.atlas_index
		uniform.add_id(manager.atlas_texture_rid)
		uniform_array[manager.atlas_index] = uniform

	for i: int in range(8):
		if uniform_array[i] == null:
			var uniform := RDUniform.new()
			uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			uniform.binding = i
			uniform.add_id(dummy_texture_rid)
			uniform_array[i] = uniform
	
	# create uniform set
	atlas_texture_uniform_set = rd.uniform_set_create(uniform_array, shader, 2)


func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if not rd:
		return
	
	if not p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return

	if not pipeline.is_valid():
		return
	
	if not brush_shape_uniform_set.is_valid() and not atlas_texture_uniform_set.is_valid():
		return
	
	if not camera_brush:
		return

	# Get our render scene buffers object, this gives us access to our render buffers.
	var render_scene_buffers := p_render_data.get_render_scene_buffers()
	if render_scene_buffers:
		var size: Vector2i = render_scene_buffers.get_internal_size()
		if size.x == 0 and size.y == 0:
			return

		# We can use a compute shader here.
		@warning_ignore("integer_division")
		var x_groups := (size.x - 1) / 8 + 1
		@warning_ignore("integer_division")
		var y_groups := (size.y - 1) / 8 + 1
		var z_groups := 1

		# prepare push constant
		var linear_color := camera_brush.color.srgb_to_linear()
		var push_constant : PackedFloat32Array = PackedFloat32Array()
		push_constant.push_back(linear_color.r)
		push_constant.push_back(linear_color.g)
		push_constant.push_back(linear_color.b)
		push_constant.push_back(linear_color.a)
		push_constant.push_back(camera_brush.last_delta * camera_brush.draw_speed)
		push_constant.push_back(camera_brush.max_distance)
		push_constant.push_back(camera_brush.start_distance_fade)
		push_constant.push_back(float(camera_brush.min_bleed))
		push_constant.push_back(float(camera_brush.max_bleed))
		push_constant.push_back(0.0)
		push_constant.push_back(0.0)
		push_constant.push_back(0.0)


		# Get the RID for our color image, we will be reading from and writing to it.
		var framebuffer_rid: RID = render_scene_buffers.get_color_layer(0)

		# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
		var framebuffer_uniform := RDUniform.new()
		framebuffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		framebuffer_uniform.binding = 0
		framebuffer_uniform.add_id(framebuffer_rid)
		var framebuffer_uniform_set := UniformSetCacheRD.get_cache(shader, 0, [framebuffer_uniform])

		# Run our compute shader.
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, framebuffer_uniform_set, 0)
		rd.compute_list_bind_uniform_set(compute_list, brush_shape_uniform_set, 1)
		rd.compute_list_bind_uniform_set(compute_list, atlas_texture_uniform_set, 2)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
		rd.compute_list_end()

#endregion
