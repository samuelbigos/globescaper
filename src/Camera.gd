extends Spatial


var _velocity := Vector2()
var _mouse_position := Vector2()

onready var _v_gimbal = get_node("VGimbal")
onready var _camera = get_node("VGimbal/Camera")


func _process(delta : float) -> void:
	
	if Input.is_action_just_pressed("mouse_right"):
		_mouse_position = get_viewport().get_mouse_position()
	elif Input.is_action_pressed("mouse_right"):
		_velocity = _mouse_position - get_viewport().get_mouse_position()
		_mouse_position = get_viewport().get_mouse_position()
	
	rotation.y += _velocity.x * 0.01
	_v_gimbal.rotation.x = min(max(_v_gimbal.rotation.x + _velocity.y * 0.01, -PI * 0.5), PI * 0.5)
	_velocity = lerp(_velocity, Vector2(0.0, 0.0), delta)
