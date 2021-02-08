extends Spatial


export var AutoRotate := false
export var MinDistance := 25.0
export var MaxDistance := 200.0
export var ZoomSpeed := 5.0
export var ZoomDeceleration := 20.0

var _velocity := Vector2()
var _zoom_velocity := 0.0
var _mouse_position := Vector2()
var _tracking_target: Node = null

onready var _v_gimbal = get_node("VGimbal")
onready var _camera = get_node("VGimbal/Camera")


func get_camera(): return _camera

func update(delta: float) -> void:
	if Input.is_action_just_pressed("mouse_right"):
		_mouse_position = get_viewport().get_mouse_position()
	elif Input.is_action_pressed("mouse_right"):
		_velocity = _mouse_position - get_viewport().get_mouse_position()
		_mouse_position = get_viewport().get_mouse_position()
		
	var dist = _camera.transform.origin.z;
	if Input.is_action_just_released("mousewheel_up"):
		_zoom_velocity -= ZoomSpeed * (dist / MaxDistance);
	elif Input.is_action_just_released("mousewheel_down"):
		_zoom_velocity += ZoomSpeed * (dist / MaxDistance);
		
	_camera.transform.origin.z = clamp(_camera.transform.origin.z + _zoom_velocity, MinDistance, MaxDistance)
	_zoom_velocity = lerp(_zoom_velocity, 0.0, delta * ZoomDeceleration)
	
	if AutoRotate:
		_velocity.x = -20.0 * delta
	
	rotation.y += _velocity.x * 0.01
	_v_gimbal.rotation.x = min(max(_v_gimbal.rotation.x + _velocity.y * 0.01, -PI * 0.5), PI * 0.5)
	_velocity = lerp(_velocity, Vector2(0.0, 0.0), delta)

func post_update(delta):
	if _tracking_target:
		global_transform.origin = _tracking_target.global_transform.origin
