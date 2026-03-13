@tool
extends HBoxContainer

@onready var camera_brush: CameraBrush = $CameraBrush

@onready var check_button: CheckButton = $CheckButton
@onready var color_picker_button: ColorPickerButton = $ColorPickerButton
@onready var h_slider: HSlider = $HSlider

var drawing: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# sync the brush with the UI
	camera_brush.size = h_slider.value
	camera_brush.color = color_picker_button.color
	camera_brush.drawing = drawing
	check_button.button_pressed = drawing

func show() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func hide() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _on_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		camera_brush.size = h_slider.value


func _on_color_picker_button_color_changed(color: Color) -> void:
	camera_brush.color = color

func _on_check_button_toggled(toggled_on: bool) -> void:
	drawing = toggled_on
	# get textures of active scene
	camera_brush.get_atlas_textures()

func _process(delta: float) -> void:
	if drawing && Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT):
		var viewport := EditorInterface.get_editor_viewport_3d()
		var mouse_pos := viewport.get_mouse_position()
		var camera := viewport.get_camera_3d()
		var pos := camera.position
		var dir := camera.project_ray_normal(mouse_pos).normalized()

		camera_brush.position = pos
		camera_brush.look_at(pos + dir, Vector3.UP)

		camera_brush.drawing = true
	else:
		camera_brush.drawing = false

