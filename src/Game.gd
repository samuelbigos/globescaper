extends Spatial
class_name Game


class Prototype:
	var mesh = ""
	var mesh_rot = 0
	var posX = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var posZ = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var posY = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var negX = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var negZ = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var negY = { "#": 0, "i": true, "s": false, "f": false, "r": 0 }
	var exclude = []
	var n_posX = []
	var n_posZ = []
	var n_posY = []
	var n_negX = []
	var n_negZ = []
	var n_negY = []

const Icosphere = preload("Icosphere.gd")

export var material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export(float, 0.0, 10.0) var noise_lacunarity = 3.0 setget set_noise_lacunarity
export(int, 1, 9) var noise_octaves = 3 setget set_noise_octaves
export(float, 0.0, 2.0) var noise_period = 1.0 setget set_noise_period
export(float, 0.0, 1.0) var noise_persistence = 0.8 setget set_noise_persistence
export(float, 0.0, 1.0) var noise_influence = 0.5 setget set_noise_influence
export var voxel_scene : PackedScene

var _generated := false
var _icosphere = null
var _noise = null
var _ico_mesh = []
var _ico_wireframe_mesh = []
var _generated_wireframe := false
var _icosphere_verts = []
var _icosphere_polys = []
var _prototypes = []
var _voxels = []
var _voxel_spheres = []
var _tiles = []
var _tile_meshes = []

var _mouse_hover := false
var _mouse_pos_on_globe := Vector3()

onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")


func _ready() -> void:
	_noise = OpenSimplexNoise.new()
	_icosphere = Icosphere.new()
	_icosphere._noise = _noise
	_generate()
	
	var prototypes = _load_prototype_data()

func _slot_from_string(slot_string):
	var slot = {}
	slot["#"] = slot_string.to_int()
	slot["i"] = slot_string.find("i") != -1
	slot["s"] = slot_string.find("s") != -1
	slot["f"] = slot_string.find("f") != -1
	slot["r"] = 0
	return slot
	
func _load_prototype_data():
	var file = File.new()
	file.open("res://assets/base_prototypes.json", file.READ)
	var text = file.get_as_text()
	var prototypes_dict = JSON.parse(text).result
	file.close()
	
	# convert dictionary to prototypes
	for p in prototypes_dict.values():
		var prototype := Prototype.new()
		prototype.mesh = p["mesh_name"]
		prototype.mesh_rot = p["mesh_rotation"]
		prototype.posX = _slot_from_string(p["posX"])
		prototype.posZ = _slot_from_string(p["posZ"])
		prototype.posY = _slot_from_string(p["posY"])
		prototype.negX = _slot_from_string(p["negX"])
		prototype.negZ = _slot_from_string(p["negZ"])
		prototype.negY = _slot_from_string(p["negY"])
		prototype.exclude = []
		prototype.n_posX = []
		prototype.n_posZ = []
		prototype.n_posY = []
		prototype.n_negX = []
		prototype.n_negZ = []
		prototype.n_negY = []
		
		_prototypes.append(prototype)
	
	# generate rotation prototypes
	var new_prototypes = []
	for prototype in _prototypes.duplicate():
		var swizzles = []
		swizzles.append(prototype.posX)
		swizzles.append(prototype.posZ)
		swizzles.append(prototype.negX)
		swizzles.append(prototype.negZ)
		for i in range(1, 4):
			var new_p := Prototype.new()
			new_p.mesh = prototype.mesh
			new_p.mesh_rot = i
			new_p.posX = swizzles[i % 4]
			new_p.posZ = swizzles[(i + 1) % 4]
			new_p.posY = prototype["posY"]
			new_p.posY["r"] = i
			new_p.negX = swizzles[(i + 1) % 4]
			new_p.negZ = swizzles[(i + 1) % 4]
			new_p.negY = prototype["negY"]
			new_p.negY["r"] = i
			new_p.exclude = prototype.exclude.duplicate()
			new_p.n_posX = []
			new_p.n_posY = []
			new_p.n_posZ = []
			new_p.n_negX = []
			new_p.n_negY = []
			new_p.n_negZ = []
			_prototypes.append(new_p)
			
	# calculate valid neighbors
	for p in _prototypes:
		for np in _prototypes:
			if p == np:
				continue
					
			if _match_h(p.posX, np.negX):
				p.n_posX.append(np)
			if _match_h(p.posZ, np.negZ):
				p.n_posZ.append(np)
			if _match_v(p.posY, np.negY):
				p.n_posY.append(np)
			if _match_h(p.negX, np.posX):
				p.n_negX.append(np)
			if _match_h(p.negZ, np.posZ):
				p.n_negZ.append(np)
			if _match_v(p.negY, np.posY):
				p.n_negY.append(np)
	
	return _prototypes
	
func _match_h(p1, p2) -> bool:
	if p1["#"] != p2["#"]:
		return false
	if p1["s"] and p2["s"]:
		return true
	if p1["f"] and p2["f"]:
		return false
	if not p1["f"] and not p2["f"]:
		return false
	return true
	
func _match_v(p1, p2) -> bool:
	if p1["#"] != p2["#"]:
		return false
	if p1["i"] and p2["i"]:
		return true
	if p1["r"] != p2["r"]:
		return false
	return true
	
func _generate() -> void:
	_icosphere._radius = radius
	_icosphere._noise_influence = noise_influence
	_noise.lacunarity = noise_lacunarity
	_noise.octaves = noise_octaves
	_noise.period = noise_period
	_noise.persistence = noise_persistence
	
	_icosphere_verts = []
	_icosphere_polys = _icosphere.generate_icosphere(_icosphere_verts, iterations)
	var colours = {}
	
	var globe_mesh = ArrayMesh.new()	
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	globe_mesh.surface_set_material(0, material)
	_globe.set_mesh(globe_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
	
	_voxels = []
	_voxels.resize(_icosphere_verts.size())
	for i in range(0, _voxels.size()):
		_voxels[i] = 0
		
	_generated = true
		
func _process(delta : float) -> void:
	
	var closest_vert = -1
	var closest_dist = 9999.0
	for i in range(_icosphere_verts.size()):
		var dist_sq = _icosphere_verts[i].distance_to(_mouse_pos_on_globe)
		if dist_sq < closest_dist:
			closest_vert = i
			closest_dist = dist_sq

	if Input.is_action_just_pressed("mouse_left"):
		_voxels[closest_vert] = 1
		var voxel = voxel_scene.instance()
		voxel.transform.origin = _icosphere_verts[closest_vert]
		_voxel_spheres[closest_vert] = voxel
		add_child(voxel)
		
		
		
	var colours = {}
	for poly in _icosphere_polys:
		if poly.v.has(closest_vert):
			colours[poly] = Color.green
	
	var globe_mesh = ArrayMesh.new()
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	globe_mesh.surface_set_material(0, material)
	_globe.set_mesh(globe_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)

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

func _on_Area_mouse_entered():
	_mouse_hover = true
	
func _on_Area_input_event(camera, event, click_position, click_normal, shape_idx):
	_mouse_pos_on_globe = click_position

func _on_Area_mouse_exited():
	_mouse_hover = false
