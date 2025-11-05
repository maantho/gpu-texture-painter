@tool
class_name CameraBrush
extends Node3D

var viewport: SubViewport
var camera: Camera3D
var camera_brush_scene: PackedScene = preload("uid://be0n8acdsbi8p")

@export var texture_manager: TextureManager

@export var projection: Camera3D.ProjectionType = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
	set(value):
		projection = value
		notify_property_list_changed()
		if camera:
			camera.projection = projection

@export var fov: float = 70.0:
	set(value):
		fov = value
		if camera:
			camera.fov = fov

@export var size: float = 10.0:
	set(value):
		size = value
		if camera:
			camera.size = size

@export var near: float = 0.1:
	set(value):
		near = value
		if camera:
			camera.near = near
@export var far: float = 1000.0:
	set(value):
		far = value
		if camera:
			camera.far = far

@export var color: Color = Color.ORANGE

@export var bleed: int = 0

@export var resolution: Vector2i = Vector2i(256, 256):
	set(value):
		resolution = value
		if viewport:
			viewport.size = resolution

func _ready() -> void:
	viewport = camera_brush_scene.instantiate() as SubViewport
	if not viewport:
		push_error("Failed to instantiate camera brush viewport scene.")
		return

	add_child(viewport)

	camera = viewport.get_child(0) as Camera3D
	if not camera:
		push_error("Failed to get camera from camera brush viewport scene.")
		return

	camera.cull_mask += 1 << 20  # Set layer 21 to detect brush render

	camera.projection = projection
	camera.fov = fov
	camera.size = size
	camera.near = near
	camera.far = far
	viewport.size = resolution


func _process(delta: float) -> void:
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
