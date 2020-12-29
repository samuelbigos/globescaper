extends Spatial
class_name Game


class Prototype:
	var mesh = ""
	var mesh_rot := 0
	var mirror := 0
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

export var land_material : Material
export var water_material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export var relax_iterations : int = 30
export var relax_iteration_delta : float = 0.05
export var water_deep_colour : Color
export var water_shallow_colour : Color

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
var _tiles = []
var _tile_meshes = []

var _surface_generate = false

var _mouse_hover := false
var _mouse_pos_on_globe := Vector3()

onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")
onready var _globe_ocean : MeshInstance = get_node("GlobeOcean")
onready var _globe_land : MeshInstance = get_node("GlobeLand")


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
		prototype.mirror = p["mirror"]
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
			new_p.mirror = prototype.mirror
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
	
	_icosphere_verts = []
	_icosphere_polys = _icosphere.generate_icosphere(_icosphere_verts, iterations)
	var colours = {}
	
	var globe_mesh = ArrayMesh.new()
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	_globe.set_mesh(globe_mesh)
	
	var ocean_mesh = ArrayMesh.new()
	var ocean_mesh_array = globe_mesh_array.duplicate()
	for i in range(ocean_mesh_array[Mesh.ARRAY_VERTEX].size()):
		ocean_mesh_array[Mesh.ARRAY_VERTEX][i] = ocean_mesh_array[Mesh.ARRAY_VERTEX][i].normalized() * radius * 1.08
		
	ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ocean_mesh_array)
	ocean_mesh.surface_set_material(0, water_material)
	water_material.set_shader_param("u_deep_colour", water_deep_colour)
	water_material.set_shader_param("u_shallow_colour", water_shallow_colour)
	_globe_ocean.set_mesh(ocean_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
	
	_voxels = []
	_voxels.resize(_icosphere_verts.size())
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
					
	# relaxation
	for iter in range(0, relax_iterations):
		var forces = []
		for i in range(0, _icosphere_verts.size()):
			forces.append(Vector3())

		for poly in _icosphere_polys:
			var force = Vector3()
			
			# get centroid
			var center = Vector3()
			for i in range(0, 4):
				center += _icosphere_verts[poly.v[i]]
			center /= 4.0
			
			# create the rotation matrix to rotate our force vector in 90 degree steps around the centroid normal
			var rot_matrix = Transform.IDENTITY.rotated(center.normalized(), PI * 0.5)
			
			# collect forces
			for i in range(0, 4):
				force += _icosphere_verts[poly.v[i]] - center
				force = rot_matrix.xform(force)
			force /= 4.0
			
			# store forces
			for i in range(0, 4):
				forces[poly.v[i]] += center + force - _icosphere_verts[poly.v[i]]
				force = rot_matrix.xform(force)
				
		# apply all accumulated forces on every vert
		for i in range(0, _icosphere_verts.size()):
			_icosphere_verts[i] = (_icosphere_verts[i] + forces[i] * relax_iteration_delta).normalized() * radius
		
	_generated = true
		
func _process(delta : float) -> void:
	
	water_material.set_shader_param("u_camera_pos", get_viewport().get_camera().get_camera_transform().origin)
	
	var closest_vert = -1
	var closest_dist = 9999.0
	for i in range(_icosphere_verts.size()):
		var dist_sq = _icosphere_verts[i].distance_to(_mouse_pos_on_globe)
		if dist_sq < closest_dist:
			closest_vert = i
			closest_dist = dist_sq

	if Input.is_action_just_pressed("mouse_left"):
		_voxels[closest_vert] = 1
		_surface_generate = true
		
	if _surface_generate:
		_surface_generate = false
				
		var surface_mesh = ArrayMesh.new()
		_globe_land.set_mesh(surface_mesh)
		
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
				var tile_mesh : Mesh = load("res://assets/tiles/" + matched_prot.mesh + ".obj")
				var tile_arrays = tile_mesh.surface_get_arrays(0).duplicate()
				
				### transform the mesh to fit the tile
				# get the final position of all the corner verts
				var corner_verts_pos = []
				for j in range(0, 4):
					corner_verts_pos.append(_icosphere_verts[poly.v[(j - 1 - matched_prot.mesh_rot) % 4]])
				
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
				
				# transform each vert in the prototype mesh
				for v in range(0, tile_arrays[Mesh.ARRAY_VERTEX].size()):
					tile_arrays[Mesh.ARRAY_VERTEX][v] = transform_vert(tile_arrays[Mesh.ARRAY_VERTEX][v], corner_verts_pos)
					#tile_arrays[Mesh.ARRAY_NORMAL][v] = trans.xform(tile_arrays[Mesh.ARRAY_NORMAL][v])
					
					
				# add the new mesh to the array mesh
				surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays)
				surface_mesh.surface_set_material(surface_mesh.get_surface_count() - 1, land_material)
				
				if matched_prot.mirror:
					var mirrored_tile_arrays = tile_mesh.surface_get_arrays(0).duplicate()
					for v in range(0, mirrored_tile_arrays[Mesh.ARRAY_VERTEX].size()):
						var vert = mirrored_tile_arrays[Mesh.ARRAY_VERTEX][v]
						vert.x = -vert.x
						vert.z = -vert.z
						mirrored_tile_arrays[Mesh.ARRAY_VERTEX][v] = transform_vert(vert, corner_verts_pos)
						#mirrored_tile_arrays[Mesh.ARRAY_NORMAL][v] = trans.xform(tile_arrays[Mesh.ARRAY_NORMAL][v])
						
					surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mirrored_tile_arrays)
					surface_mesh.surface_set_material(surface_mesh.get_surface_count() - 1, land_material)
					

func transform_vert(var vert : Vector3, var corners) -> Vector3:
	# flatten 3D vert 
	var vert_2d = Vector2(vert.x, vert.z)
	
	# get vert coords as a ratio along the x/y axis
	# assumes input vert is inside a 2x2 square centred at 0,0
	var vert_x = (vert_2d.x + 1.0) / 2.0
	var vert_y = (vert_2d.y + 1.0) / 2.0
	
	# calculate new vert position using quad corners and weights we found above
	var new_x1 = lerp(corners[0], corners[1], vert_x)
	var new_x2 = lerp(corners[3], corners[2], vert_x)
	var new_vert = lerp(new_x1, new_x2, vert_y)
	
	# add height (map to a hardcoded fraction of the sphere radius for now)
	var vert_height = (vert.y + 1.0) / 2.0 # map to 0-1
	return new_vert.normalized() * (radius + (vert_height * 0.2))
	
func set_iterations(val : int) -> void: 
	iterations = val
	if _generated:
		_generate()

func set_radius(val : float) -> void: 
	radius = val
	if _generated:
		_generate()
		
func _on_Area_mouse_entered():
	_mouse_hover = true
	
func _on_Area_input_event(camera, event, click_position, click_normal, shape_idx):
	_mouse_pos_on_globe = click_position

func _on_Area_mouse_exited():
	_mouse_hover = false
