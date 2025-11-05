class_name CameraBrushComputeHelper
extends RefCounted

var rd: RenderingDevice

var shader: RID
var pipeline: RID

var camera_brush_texture: RID
var sampler: RID
var overlay_texture: RID

var uniform_set: RID

var x_groups: int
var y_groups: int

func _init(camera_brush_texture: RID, overlay_texture: RID) -> void:
    RenderingServer.call_on_render_thread(_init_render_thread.bind(camera_brush_texture, overlay_texture))


func _init_render_thread(camera_brush_texture: RID, overlay_texture: RID) -> void:
    # get main rendering device, since render thread
    rd = RenderingServer.get_rendering_device()

    # create shader
    var shader_file := load("uid://bwm7j25sbgip3")
    var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
    shader = rd.shader_create_from_spirv(shader_spirv)
    pipeline = rd.compute_pipeline_create(shader)

    # set textures
    self.overlay_texture = overlay_texture
    self.camera_brush_texture = camera_brush_texture

    # input uniform: camera brush texture
    var camera_brush_texture_uniform := RDUniform.new()
    camera_brush_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    camera_brush_texture_uniform.binding = 0
    camera_brush_texture_uniform.add_id(camera_brush_texture)

    # output uniform: overlay texture
    var overlay_texture_uniform := RDUniform.new()
    overlay_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    overlay_texture_uniform.binding = 1
    overlay_texture_uniform.add_id(overlay_texture)

    # create uniform set
    uniform_set = rd.uniform_set_create([camera_brush_texture_uniform, overlay_texture_uniform], shader, 0)

    # get texture size to calculate work groups
    var tex_size: Vector2i = Vector2i(rd.texture_get_format(overlay_texture).width, rd.texture_get_format(overlay_texture).height)
    x_groups = (tex_size.x - 1) / 8 + 1
    y_groups = (tex_size.y - 1) / 8 + 1


func render_process():
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
    rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
    rd.compute_list_end()


func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _cleanup()

func _cleanup() -> void:
    if rd and uniform_set.is_valid():
        rd.free_rid(uniform_set)
    if rd and pipeline.is_valid():
        rd.free_rid(pipeline)
    if rd and shader.is_valid():
        rd.free_rid(shader)

