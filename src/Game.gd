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
	var top = []
	var bot = []

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
var _vert_poly_neighbors = []
var _prototypes = []
var _voxels = []
var _voxel_spheres = []
var _tiles = []
var _tile_meshes = []

var _debug_generate = false
var _debug_ratio = 0.0
var _debug_mesh = null

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
		prototype.top = p["top"]
		prototype.bot = p["bot"]
		
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
			new_p.top = []
			new_p.top.append(prototype.top[(0 + i) % 4])
			new_p.top.append(prototype.top[(1 + i) % 4])
			new_p.top.append(prototype.top[(2 + i) % 4])
			new_p.top.append(prototype.top[(3 + i) % 4])
			new_p.bot = []
			new_p.bot.append(prototype.bot[(0 + i) % 4])
			new_p.bot.append(prototype.bot[(1 + i) % 4])
			new_p.bot.append(prototype.bot[(2 + i) % 4])
			new_p.bot.append(prototype.bot[(3 + i) % 4])
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
	_voxel_spheres.resize(_icosphere_verts.size())
	for i in range(0, _voxels.size()):
		_voxels[i] = 0
		
	# build a dictionary of all poly neighbors for each vert.
	_vert_poly_neighbors.resize(_icosphere_verts.size())
	for i in range(0, _icosphere_verts.size()):
		_vert_poly_neighbors[i] = []
		
	for i in range(0, _icosphere_polys.size()):
		for j in range(0, _icosphere_polys[i].neighbors.size()):
			for v in range(0, _icosphere_polys[i].neighbors[j].v.size()):
				var vert = _icosphere_polys[i].neighbors[j].v[v]
				if not _vert_poly_neighbors[vert].has(_icosphere_polys[i].neighbors[j]):
					_vert_poly_neighbors[vert].append(_icosphere_polys[i].neighbors[j])
		
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
		
		_debug_generate = true
		_debug_ratio = 1.0
		
	if _debug_generate:
		_debug_generate = false
		#_debug_ratio = min(1.0, _debug_ratio + delta * 0.05)
		
		if _debug_mesh != null:
			remove_child(_debug_mesh)
		
		for i in range(_icosphere_polys.size()):
			var poly = _icosphere_polys[i] as Icosphere.Quad
			# build an array of corners we need to match
			var corners = []
			corners.append(_voxels[poly.v[0]]) # bottom
			corners.append(_voxels[poly.v[1]]) # bottom
			corners.append(_voxels[poly.v[2]]) # bottom
			corners.append(_voxels[poly.v[3]]) # bottom
			corners.append(0) # top
			corners.append(0) # top
			corners.append(0) # top
			corners.append(0) # top
			
			if not corners.has(1):
				continue
			
			# find a prototype that matches
			var matched = false
			var matched_prot = null
			for prototype in _prototypes:
				if prototype.bot[0] == corners[0] and \
					prototype.bot[1] == corners[1] and \
					prototype.bot[2] == corners[2] and \
					prototype.bot[3] == corners[3] and \
					prototype.top[0] == corners[4] and \
					prototype.top[1] == corners[5] and \
					prototype.top[2] == corners[6] and \
					prototype.top[3] == corners[7]:
					
					matched = true
					matched_prot = prototype
					break
			
			if matched:
				#var tile_mesh : Mesh = load("res://assets/tiles/" + matched_prot.mesh + ".obj")
				var tile_mesh : Mesh = load("res://assets/tiles/" + "cube_monkey" + ".obj")
				var tile_arrays = tile_mesh.surface_get_arrays(0)
				
				### transform the mesh to fit the tile
				# get the final position of all the corner verts
				var corner_verts_pos = []
				corner_verts_pos.append(_icosphere_verts[poly.v[0]]) # bot
				corner_verts_pos.append(_icosphere_verts[poly.v[1]]) # bot
				corner_verts_pos.append(_icosphere_verts[poly.v[2]]) # bot
				corner_verts_pos.append(_icosphere_verts[poly.v[3]]) # bot
				corner_verts_pos.append(_icosphere_verts[poly.v[0]] * 1.25) # top
				corner_verts_pos.append(_icosphere_verts[poly.v[1]] * 1.25) # top
				corner_verts_pos.append(_icosphere_verts[poly.v[2]] * 1.25) # top
				corner_verts_pos.append(_icosphere_verts[poly.v[3]] * 1.25) # top
				
				var tile_centre = _icosphere_verts[poly.v[0]]
				tile_centre += _icosphere_verts[poly.v[1]]
				tile_centre += _icosphere_verts[poly.v[2]]
				tile_centre += _icosphere_verts[poly.v[3]]
				tile_centre /= 4.0
				
				var trans := Transform.IDENTITY
				# rotate so that up is always the surface normal
				var n = tile_centre.normalized()
				var r = Vector3(0.0, 1.0, 0.0)
				var e = r.cross(n).normalized()
				var d = n.cross(e).normalized()
				trans *= Transform(e, n, -d, Vector3(0.0, 0.0, 0.0))
				# elevate out of the sphere
				trans.origin += tile_centre.normalized() * 0.5
				# rescale
				trans = trans.scaled(Vector3(0.1, 0.1, 0.1))
				
				# the 8 corners of the mesh
				var cube_corners = []
				cube_corners.append(Vector3(-1.0, -1.0, -1.0))
				cube_corners.append(Vector3(1.0, -1.0, -1.0))
				cube_corners.append(Vector3(1.0, -1.0, 1.0))
				cube_corners.append(Vector3(-1.0, -1.0, 1.0))
				cube_corners.append(Vector3(-1.0, 1.0, -1.0))
				cube_corners.append(Vector3(1.0, 1.0, -1.0))
				cube_corners.append(Vector3(1.0, 1.0, 1.0))
				cube_corners.append(Vector3(-1.0, 1.0, 1.0))
				
				var colours = PoolColorArray()
				for c in range(0, tile_arrays[Mesh.ARRAY_VERTEX].size()):
					colours.append(Color.white)
					
				tile_arrays[Mesh.ARRAY_COLOR] = colours
				
				# transform each vert in the prototype mesh
				for v in range(0, tile_arrays[Mesh.ARRAY_VERTEX].size()):
					var vert : Vector3 = tile_arrays[Mesh.ARRAY_VERTEX][v]
					var vert_height = vert.y + 1.0
					
					var tri1 = [ cube_corners[0], cube_corners[1], cube_corners[2] ]
					var tri2 = [ cube_corners[2], cube_corners[3], cube_corners[0] ]
					
					var bary_coords_1 = {}
					var bary_coords_2 = {}
					barycentric(vert, tri1[0], tri1[1], tri1[2], bary_coords_1)
					barycentric(vert, tri2[0], tri2[1], tri2[2], bary_coords_2)
					
					var col = Color()
					var new_vert = Vector3(0.0, 0.0, 0.0)
					if bary_coords_1["v"] >= 0.0 and bary_coords_1["w"] >= 0.0 and bary_coords_1["u"] >= 0.0:
						new_vert += (corner_verts_pos[0] - tile_centre) * bary_coords_1["u"]
						new_vert += (corner_verts_pos[1] - tile_centre) * bary_coords_1["v"]
						new_vert += (corner_verts_pos[2] - tile_centre) * bary_coords_1["w"]
					else:
						new_vert += (corner_verts_pos[2] - tile_centre) * bary_coords_2["u"]
						new_vert += (corner_verts_pos[3] - tile_centre) * bary_coords_2["v"]
						new_vert += (corner_verts_pos[0] - tile_centre) * bary_coords_2["w"]
						
					new_vert = new_vert + (tile_centre.normalized() * vert_height) * 0.1
					
					var ratio = _debug_ratio
					tile_arrays[Mesh.ARRAY_VERTEX][v] = new_vert * ratio + vert * (1.0 - ratio) * 0.5
									
					if vert.x == -1.0 and vert.z == 1.0:
						tile_arrays[Mesh.ARRAY_COLOR][v] = Color.red
					if vert.x == 1.0 and vert.z == 1.0:
						tile_arrays[Mesh.ARRAY_COLOR][v] = Color.green
					if vert.x == 1.0 and vert.z == -1.0:
						tile_arrays[Mesh.ARRAY_COLOR][v] = Color.blue
					if vert.x == -1.0 and vert.z == -1.0:
						tile_arrays[Mesh.ARRAY_COLOR][v] = Color.yellow
						
					tile_arrays[Mesh.ARRAY_COLOR][v] = Color.white
				
				### create the mesh instance
				var tile = MeshInstance.new()
				var tile_arraymesh = ArrayMesh.new()
				tile_arraymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays)
				tile_arraymesh.surface_set_material(0, material)
				
				tile.set_mesh(tile_arraymesh)
				tile.transform.origin = tile_centre
				
				#_debug_mesh = tile
				add_child(tile)
		
	var colours = {}
	for poly in _vert_poly_neighbors[closest_vert]:
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
	
func barycentric(var p : Vector3, var a : Vector3, var b : Vector3, var c : Vector3, var output):
	var v0 = b - a
	var v1 = c - a
	var v2 = p - a
	var d00 = v0.dot(v0)
	var d01 = v0.dot(v1)
	var d11 = v1.dot(v1)
	var d20 = v2.dot(v0)
	var d21 = v2.dot(v1)
	var denom = d00 * d11 - d01 * d01
	output["v"] = (d11 * d20 - d01 * d21) / denom
	output["w"] = (d00 * d21 - d01 * d20) / denom
	output["u"] = 1.0 - output["v"] - output["w"]

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
