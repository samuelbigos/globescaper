extends Control



signal on_mode_changed(mode)

var _moving_debug = false
var _debug_init_pos = Vector2()
var _moving_debug_press_start = Vector2()
var _loaded = false;
var _fps = 0.0

func _ready():
	get_node("TabContainer/Options/Auto/Auto/CheckButton").toggle_mode = Globals.AutoMode
	get_node("TabContainer/Options/Water/Water/CheckButton").toggle_mode = Globals.Water
	get_node("TabContainer/Options/Atmosphere/Atmosphere/CheckButton").toggle_mode = Globals.Atmosphere
	get_node("TabContainer/Options/Dof/Dof/CheckButton").toggle_mode = Globals.Dof
	get_node("TabContainer/Options/AutoRot/AutoRot/CheckButton").toggle_mode = Globals.AutoRotate
	get_node("TabContainer/Debug/Grid/Grid/CheckButton").toggle_mode = Globals.Grid
	get_node("TabContainer/Debug/Visual/Visual/CheckButton").toggle_mode = Globals.Visual
		
	if Globals.Size == 0:
		get_node("TabContainer/Options/Size/small").pressed = true
	if Globals.Size == 1:
		get_node("TabContainer/Options/Size/med").pressed = true
	if Globals.Size == 2:
		get_node("TabContainer/Options/Size/large").pressed = true

func _process(delta):
	# drag functionality of the debug menu.
	if _moving_debug:
		var mouse_delta = get_global_mouse_position() - _moving_debug_press_start
		rect_position = _debug_init_pos + mouse_delta
		
	_loaded = true
	_fps = _fps * 0.95 + (1.0 / delta) * 0.05
	get_node("TabContainer/Options/FPS").text = "FPS: %.1f" % _fps

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

func _on_CheckButton_button_up():
	Globals.AutoMode = !Globals.AutoMode
	get_tree().reload_current_scene()

func _on_large_toggled(button_pressed):
	if button_pressed && _loaded:
		Globals.Size = 2
		get_tree().reload_current_scene()

func _on_med_toggled(button_pressed):
	if button_pressed && _loaded:
		Globals.Size = 1
		get_tree().reload_current_scene()

func _on_small_toggled(button_pressed):
	if button_pressed && _loaded:
		Globals.Size = 0
		get_tree().reload_current_scene()

func _on_Water_button_up():
	Globals.Water = !Globals.Water

func _on_Atmosphere_button_up():
	Globals.Atmosphere = !Globals.Atmosphere

func _on_Dof_button_up():
	Globals.Dof = !Globals.Dof

func _on_Idle_button_up():
	Globals.AutoRotate = !Globals.AutoRotate

func _on_Grid_button_up():
	Globals.Grid = !Globals.Grid

func _on_Visual_button_up():
	Globals.Visual = !Globals.Visual
