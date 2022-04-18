extends Spatial
class_name Game


# exposed
export var PlanetScene : PackedScene
export var SunRadius = 100.0
export var SunAtmosphereRadiusMod = 1.1;

# members
var _debug_display_mode = 0
var _active_placement_mode := 1
var _planets = []
var _active_planet : Planet

onready var _camera = get_node("Camera")
onready var _sun = get_node("Sun")
onready var _sun_surface_mesh = _sun.get_node("Surface").mesh
onready var _sun_atmosphere_mesh = _sun.get_node("Atmosphere").mesh
onready var _sun_atmosphere_mat = _sun_atmosphere_mesh.surface_get_material(0)
onready var _skybox = get_node("Skybox")	


func _ready() -> void:
	PrototypeDB.load_prototypes()
	
	var planet = PlanetScene.instance()
	var planet_gimbal = Spatial.new()
	add_child(planet_gimbal)
	planet_gimbal.add_child(planet)
	_planets.append(planet)
	planet.setup(planet_gimbal, 200.0, _sun, _sun, PlanetScene, 0, 0.1)
	
	_active_planet = planet
	
	_sun_surface_mesh.radius = SunRadius
	_sun_surface_mesh.height = _sun_surface_mesh.radius * 2.0
	_sun_atmosphere_mesh.radius = SunRadius * SunAtmosphereRadiusMod
	_sun_atmosphere_mesh.height = _sun_atmosphere_mesh.radius * 2.0	

func _process(delta: float) -> void:
	_camera._tracking_target = _active_planet
	_camera.update(delta)
	
	# debug input stuff
	if Input.is_action_just_released("spacebar"):
		_debug_display_mode = (_debug_display_mode + 1) % 2
		match _debug_display_mode:
			0:
				$SDFGen/SDFVolume.visible = false
				$SDFGen/SDFPreview.visible = false
			1:
				$SDFGen/SDFVolume.visible = true
				$SDFGen/SDFPreview.visible = false
			2:
				$SDFGen/SDFVolume.visible = true
				$SDFGen/SDFPreview.visible = true
				
	# find out which cell face the mouse is over
	_active_planet._do_mouse_picking(_camera, _active_placement_mode)
	
	# reset wfc
	if Input.is_action_just_pressed("r"):
		_active_planet._reset()
	
	for planet in _planets:
		planet.update(delta)
		
	var sun_pos = _sun.global_transform.origin
	var dir_to_sun = get_viewport().get_camera().global_transform.origin.normalized()
	_sun_atmosphere_mat.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin - sun_pos)
	_sun_atmosphere_mat.set_shader_param("u_sun_pos", sun_pos + dir_to_sun * 99999.0)
	_sun_atmosphere_mat.set_shader_param("u_planet_radius", SunRadius)
	_sun_atmosphere_mat.set_shader_param("u_atmosphere_radius", SunRadius * SunAtmosphereRadiusMod)
	
	_skybox.material_override.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)
	_skybox.global_transform.origin = get_viewport().get_camera().global_transform.origin
	
	_camera.post_update(delta)

func _on_GUI_on_mode_changed(mode):
	_active_placement_mode = mode
