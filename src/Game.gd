extends Spatial
class_name Game


const Icosphere = preload("Icosphere.gd")

export var material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export(float, 0.0, 10.0) var noise_lacunarity = 3.0 setget set_noise_lacunarity
export(int, 1, 9) var noise_octaves = 3 setget set_noise_octaves
export(float, 0.0, 2.0) var noise_period = 1.0 setget set_noise_period
export(float, 0.0, 1.0) var noise_persistence = 0.8 setget set_noise_persistence
export(float, 0.0, 1.0) var noise_influence = 0.5 setget set_noise_influence

var _generated := false
var _icosphere = null
var _noise = null
var _ico_mesh = []
var _ico_wireframe_mesh = []
var _generated_wireframe := false

onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")


func _ready() -> void:
	_noise = OpenSimplexNoise.new()
	_icosphere = Icosphere.new()
	_icosphere._noise = _noise
	_generate()
	
func _generate() -> void:
	_icosphere._radius = radius
	_icosphere._noise_influence = noise_influence
	_noise.lacunarity = noise_lacunarity
	_noise.octaves = noise_octaves
	_noise.period = noise_period
	_noise.persistence = noise_persistence
	
	var icoshphere_verts = []
	var icosphere_polys = _icosphere.generate_icosphere(icoshphere_verts, iterations)
	
	var globe_mesh = ArrayMesh.new()
	var globe_mesh_array = _icosphere.get_icosphere_mesh(icosphere_polys, icoshphere_verts)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	globe_mesh.surface_set_material(0, material)
	_globe.set_mesh(globe_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(icosphere_polys, icoshphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
		
	_generated = true
		
func _process(delta : float) -> void:
	pass

func set_iterations(val : int) -> void: 
	iterations = val
	if _generated:
		_generate()

func set_radius(val : float) -> void: 
	radius = val
	if _generated:
		_generate()
		
func set_noise_lacunarity(val : int) -> void: 
	noise_lacunarity = val
	if _generated:
		_generate()
	
func set_noise_octaves(val : int) -> void: 
	noise_octaves = val
	if _generated:
		_generate()
	
func set_noise_period(val : int) -> void: 
	noise_period = val
	if _generated:
		_generate()
	
func set_noise_persistence(val : float) -> void: 
	noise_persistence = val
	if _generated:
		_generate()

func set_noise_influence(val : float) -> void: 
	noise_influence = val
	if _generated:
		_generate()
