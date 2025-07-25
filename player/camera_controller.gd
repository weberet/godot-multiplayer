class_name CameraController
extends Node3D

@export_node_path var player_path: NodePath
@export var invert_mouse_y := false
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export_range(0.0, 8.0) var joystick_sensitivity := 2.0
@export var tilt_upper_limit := deg_to_rad(-60.0)
@export var tilt_lower_limit := deg_to_rad(60.0)

@onready var camera: Camera3D = $PlayerCamera
@onready var _camera_spring_arm: SpringArm3D = $CameraSpringArm
@onready var _pivot: Node3D = $CameraSpringArm/CameraThirdPersonPivot

var _rotation_input: float
var _tilt_input: float
var _mouse_input := false
var _offset: Vector3
var _anchor: CharacterBody3D
var _euler_rotation: Vector3


func _ready() -> void:
	if not is_multiplayer_authority():
		set_process_input(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = - event.relative.x * mouse_sensitivity
		_tilt_input = - event.relative.y * mouse_sensitivity


func setup(anchor: CharacterBody3D) -> void:
	_anchor = anchor
	
	# FIX: Don't preserve the initial offset - position the camera controller directly on the player
	# The old offset calculation was preserving incorrect initial positioning
	_offset = Vector3.ZERO # Remove any initial offset
	
	# Position the camera controller directly on the player
	global_position = anchor.global_position
	
	# CRITICAL FIX: Exclude the anchor from SpringArm3D collision detection
	# This prevents the camera from colliding with the character itself
	_camera_spring_arm.add_excluded_object(_anchor.get_rid())
	
	# Also exclude the anchor's collision shape if it has one
	if _anchor.has_method("get_rid"):
		_camera_spring_arm.add_excluded_object(_anchor.get_rid())
	
	# Additional fix: exclude all collision shapes from the character
	for child in _anchor.get_children():
		if child is CollisionShape3D:
			_camera_spring_arm.add_excluded_object(child.get_rid())


func _physics_process(delta: float) -> void:
	if not _anchor: return
	
	_rotation_input += Input.get_action_raw_strength("camera_left") - Input.get_action_raw_strength("camera_right")
	_tilt_input += Input.get_action_raw_strength("camera_up") - Input.get_action_raw_strength("camera_down")
	
	if EditMode.is_enabled:
		_rotation_input = 0.0
		_tilt_input = 0.0
	
	if invert_mouse_y:
		_tilt_input *= -1
	
	# FIX: Position camera controller directly on player, not with offset
	# Set camera controller to follow the player's position
	var target_position := _anchor.global_position
	target_position.y = lerp(global_position.y, _anchor._ground_height, 0.1)
	global_position = target_position
	
	# Rotates camera using euler rotation
	_euler_rotation.x += _tilt_input * delta
	_euler_rotation.x = clamp(_euler_rotation.x, tilt_lower_limit, tilt_upper_limit)
	_euler_rotation.y += _rotation_input * delta
	
	transform.basis = Basis.from_euler(_euler_rotation)
	
	# Ensure the camera follows the spring arm pivot properly
	camera.global_transform = _pivot.global_transform
	camera.rotation.z = 0
	
	_rotation_input = 0.0
	_tilt_input = 0.0
