extends Spatial


var _velocity := Vector2()
var _mouse_position := Vector2()
var _follow_target := false
var _target := Vector3()
var _did_input = false

onready var _v_gimbal = get_node("VGimbal")
onready var _camera = get_node("VGimbal/Camera")


func _process(delta : float) -> void:
	
	if Input.is_action_just_pressed("mouse_right"):
		_mouse_position = get_viewport().get_mouse_position()
		enable_manual_control()
		_did_input = true
	elif Input.is_action_pressed("mouse_right"):
		_velocity = _mouse_position - get_viewport().get_mouse_position()
		_mouse_position = get_viewport().get_mouse_position()
		
	#_velocity.x = 20.0 * delta
	#_v_gimbal.rotation.x = -0.6
	
	if _follow_target:
		rotation.y = lerp(rotation.y, atan2(_target.x, _target.z), delta * 1.0)		
		_v_gimbal.rotation.x = lerp(_v_gimbal.rotation.x, asin(-_target.y), delta * 1.0)
	else:
		rotation.y += _velocity.x * 0.01
		_v_gimbal.rotation.x = min(max(_v_gimbal.rotation.x + _velocity.y * 0.01, -PI * 0.5), PI * 0.5)
		_velocity = lerp(_velocity, Vector2(0.0, 0.0), delta)

func set_orientation(lookat : Vector3):
	if not _did_input:
		_follow_target = true
		_target = lookat.normalized()
	
func enable_manual_control():
	_follow_target = false
