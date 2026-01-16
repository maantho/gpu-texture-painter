@tool
@icon("uid://ban43kgeaq7gv")
class_name CameraBrush
extends Node3D

## Corresponds to the projection value of the underlying camera.
## Orthogonal projection will keep the size constant. E.g. a pencil.
## Perspective projection will make the brush size vary with distance. E.g. a spray can.
@export var projection: Camera3D.ProjectionType = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
	set(value):
		projection = value
		notify_property_list_changed()
		if camera:
			camera.projection = projection

## Corresponds to the fov value of the underlying camera
@export var fov: float = 5.0:
	set(value):
		fov = clampf(value, 0.1, 179.0)
		if camera:
			camera.fov = fov

## Corresponds to the size value of the underlying camera
@export var size: float = 0.5:
	set(value):
		size = maxf(value, 0.01)
		if camera:
			camera.size = size

## Corresponds to the far value of the underlying camera
@export var max_distance: float = 1000.0:
	set(value):
		max_distance = value
		if camera:
			max_distance = maxf(value, camera.near + 0.01)
			camera.far = max_distance

# supplied for each invocation
## At which distance the brush starts to fade out (1 = at max_distance / no fade)
@export_range(0, 1, 0.01) var start_distance_fade: float = 1.0

#supplied for each invocation
## How many pixels the brush bleeds at every point in the overlay atlas textures, if the mesh is closest to the brush.
## If min_bleed and max_bleed are the same, bleed is constant.
## Bleed may be necessary at low viewport resolutions to avoid holes.
@export var min_bleed: int = 0:
	set(value):
		min_bleed = value
		if min_bleed > max_bleed:
			max_bleed = min_bleed

#supplied for each invocation
## How many pixels the brush bleeds at every point in the overlay atlas textures, if the mesh is at max distance from the brush.
## Bleed may be necessary at low viewport resolutions to avoid holes.
@export var max_bleed: int = 0:
	set(value):
		max_bleed = value
		if max_bleed < min_bleed:
			min_bleed = max_bleed

## The shape of the brush used for painting.
## Channel R is used as brush opacity.
@export var brush_shape: Texture2D = preload("uid://b6knnm8h3nhpi"):
	set(value):
		brush_shape = value
		if brush_compositor_effect:
			RenderingServer.call_on_render_thread(brush_compositor_effect.create_brush_shape_texture)

## The resolution of the brush viewport texture.
## Higher resolutions reduce holes in the overlay.
@export var resolution: Vector2i = Vector2i(256, 256):
	set(value):
		resolution = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		if viewport:
			viewport.size = resolution

## The color used for painting.
@export var color: Color = Color.ORANGE

## The rate at which the brush paints.
## Higher values make the brush paint faster.
## 10 means it takes 0.1 seconds to paint full opacity.
## 100 means it takes 0.01 seconds to paint full opacity.
@export var draw_speed: float = 100:
	set(value):
		draw_speed = maxf(value, 0.01)

## Whether the brush is currently drawing.
@export var drawing: bool = false:
	set(value):
		drawing = value
		if viewport:
			viewport.render_target_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS if drawing else SubViewport.UpdateMode.UPDATE_DISABLED

var last_delta: float = 0.0

var viewport: SubViewport
var camera: Camera3D
var brush_compositor_effect: BrushCompositorEffect

const  GROUP_NAME := "camera_brushes"

func _ready() -> void:
	add_to_group(GROUP_NAME)

	# load camera brush scene
	var camera_brush_scene: PackedScene = load("uid://be0n8acdsbi8p")

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
	viewport.render_target_update_mode = SubViewport.UpdateMode.UPDATE_ALWAYS if drawing else SubViewport.UpdateMode.UPDATE_DISABLED

	# get brush compositor effect
	brush_compositor_effect = camera.compositor.compositor_effects[0] as BrushCompositorEffect
	if not brush_compositor_effect:
		push_error("CameraBrush: Failed to get brush compositor effect from camera brush viewport scene")
		return
	
	brush_compositor_effect.camera_brush = self

	get_atlas_textures()
	RenderingServer.call_on_render_thread(brush_compositor_effect.create_brush_shape_texture)


func _process(delta: float) -> void:
	last_delta = delta

	if not camera:
		return
	
	camera.global_position = global_position
	camera.global_rotation = global_rotation


func _validate_property(property: Dictionary) -> void:
	if projection == Camera3D.ProjectionType.PROJECTION_ORTHOGONAL:
		if property.name == "fov":
			property.usage = PROPERTY_USAGE_NONE
	else:
		if property.name == "size":
			property.usage = PROPERTY_USAGE_NONE

	if property.name == "projection":
		property.hint_string = "Perspective,Orthogonal"


func get_atlas_textures() -> void:
	var all_managers := get_tree().get_nodes_in_group(OverlayAtlasManager.GROUP_NAME)
		
	if all_managers.is_empty():
		return

	RenderingServer.call_on_render_thread(brush_compositor_effect.get_atlas_textures.bind(all_managers))

