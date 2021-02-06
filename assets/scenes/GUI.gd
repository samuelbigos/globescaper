extends Control



signal on_mode_changed(mode)

var _moving_debug = false
var _debug_init_pos = Vector2()
var _moving_debug_press_start = Vector2()


func _process(delta):
	# drag functionality of the debug menu.
	if _moving_debug:
		var mouse_delta = get_global_mouse_position() - _moving_debug_press_start
		rect_position = _debug_init_pos + mouse_delta

func _on_ModeLandCheck_toggled(button_pressed):
	emit_signal("on_mode_changed", 1);

func _on_ModeBuildingCheck_toggled(button_pressed):
	emit_signal("on_mode_changed", 2);

func _on_Move_button_down():
	_moving_debug = true
	_debug_init_pos = rect_position
	_moving_debug_press_start = get_global_mouse_position()

func _on_Minimise_pressed():
	$TabContainer.visible = !$TabContainer.visible

func _on_Move_button_up():
	_moving_debug = false
