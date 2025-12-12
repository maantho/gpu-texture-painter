extends Camera3D

## FPS-style flying camera controller
## Hold right mouse button to look around, WASD to move, QE for up/down, Shift for speed boost

@export var mouse_sensitivity: float = 0.003
@export var move_speed: float = 5.0
@export var fast_move_multiplier: float = 3.0
@export var smooth_movement: bool = true
@export var movement_smoothing: float = 10.0

var _mouse_captured: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _rotation_x: float = 0.0
var _rotation_y: float = 0.0


func _ready() -> void:
	# Initialize rotation from current transform
	_rotation_x = rotation.x
	_rotation_y = rotation.y


func _input(event: InputEvent) -> void:
	# Handle mouse button for capturing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_mouse_captured = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_mouse_captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Handle mouse motion for looking around
	if event is InputEventMouseMotion and _mouse_captured:
		_rotation_y -= event.relative.x * mouse_sensitivity
		_rotation_x -= event.relative.y * mouse_sensitivity
		_rotation_x = clamp(_rotation_x, -PI / 2.0, PI / 2.0)
		
		rotation = Vector3(_rotation_x, _rotation_y, 0.0)


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	
	# WASD movement
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	
	# Up/Down movement (Q/E or Space/Ctrl)
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		input_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		input_dir += Vector3.DOWN
	
	# Normalize to prevent faster diagonal movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	# Speed multiplier with Shift
	var current_speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= fast_move_multiplier
	
	var target_velocity := input_dir * current_speed
	
	# Apply movement with optional smoothing
	if smooth_movement:
		_velocity = _velocity.lerp(target_velocity, movement_smoothing * delta)
	else:
		_velocity = target_velocity
	
	position += _velocity * delta
