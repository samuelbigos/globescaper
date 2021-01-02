extends Spatial
class_name Game


class Prototype:
	var mesh_names = []
	var mesh_rots = []
	var rotations = []
	var rot := 0
	var corners_bot = []
	var corners_top = []
	var bot_int = 0
	var top_int = 0
	var h_ints = [0, 0, 0, 0]
	var h_ints_inv = [0, 0, 0, 0]
	var slots = []
	var slot_b : int
	var slot_t : int
	var weight := 1.0
	
class Cell:
	var v_bot = []
	var v_top = []
	var layer = 0
	var neighbors = []
	
	
const Icosphere = preload("Icosphere.gd")

export var land_material : Material
export var water_material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export var relax_iterations : int = 30
export var relax_iteration_delta : float = 0.05
export var water_deep_colour : Color
export var water_shallow_colour : Color
export var cell_height = 1.0
export var grid_height = 5
export var water_height = 0.5

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
var _wfc_data = []
var _wfc_added = []
var _wfc_step = 0.0
var _wfc_finished = false
var _surface_generate = false

var _grid_cells = []

var _mouse_hover := false
var _mouse_pos_on_globe := Vector3()

onready var _camera = get_node("HGimbal")
onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")
onready var _globe_ocean : MeshInstance = get_node("GlobeOcean")
onready var _globe_land : MeshInstance = get_node("GlobeLand")
onready var _wfc = get_node("WaveFunctionCollapse")


func _ready() -> void:
	_noise = OpenSimplexNoise.new()
	_icosphere = Icosphere.new()
	_icosphere._noise = _noise
	_generate()
	
	_prototypes = _load_prototype_data()
		
	_wfc.init(0, _grid_cells, _prototypes, grid_height)
	_wfc_added = []
	for c in _grid_cells:
		_wfc_added.append(false)


func _load_prototype_data():
	var file = File.new()
	file.open("res://assets/base_prototypes.json", file.READ)
	var text = file.get_as_text()
	var prototypes_dict = JSON.parse(text).result
	file.close()
	
	# convert dictionary to prototypes
	var prototype_json = prototypes_dict.values()
	for p in prototype_json[0]:
		var prototype := Prototype.new()
		prototype.mesh_names = p["mesh_names"]
		prototype.mesh_rots = p["mesh_rots"]
		prototype.rotations = p["rotations"]
		prototype.corners_bot = p["corners_bot"]
		prototype.corners_top = p["corners_top"]
		prototype.slots = [ p["up"], p["right"], p["down"], p["left"] ]
		prototype.slot_b = p["bottom"]
		prototype.slot_t = p["top"]
		if p.has("weight"):
			prototype.weight = p["weight"]
		
		_prototypes.append(prototype)
	
	# generate rotation prototypes
	var new_prototypes = []
	for prototype in _prototypes:
		for i in prototype.rotations:
			var new_p := Prototype.new()
			new_p.mesh_names = prototype.mesh_names.duplicate()
			new_p.mesh_rots = prototype.mesh_rots.duplicate()
			new_p.rot = int(i)
			new_p.corners_top = []
			new_p.corners_top.append(prototype.corners_top[(0 + int(i)) % 4])
			new_p.corners_top.append(prototype.corners_top[(1 + int(i)) % 4])
			new_p.corners_top.append(prototype.corners_top[(2 + int(i)) % 4])
			new_p.corners_top.append(prototype.corners_top[(3 + int(i)) % 4])
			new_p.corners_bot = []
			new_p.corners_bot.append(prototype.corners_bot[(0 + int(i)) % 4])
			new_p.corners_bot.append(prototype.corners_bot[(1 + int(i)) % 4])
			new_p.corners_bot.append(prototype.corners_bot[(2 + int(i)) % 4])
			new_p.corners_bot.append(prototype.corners_bot[(3 + int(i)) % 4])
			new_p.top_int = new_p.corners_top[0] * 1 + new_p.corners_top[1] * 2 + new_p.corners_top[2] * 4 + new_p.corners_top[3] * 8
			new_p.bot_int = new_p.corners_bot[0] * 1 + new_p.corners_bot[1] * 2 + new_p.corners_bot[2] * 4 + new_p.corners_bot[3] * 8
			new_p.h_ints = [0, 0, 0, 0]
			new_p.h_ints[0] = new_p.corners_top[0] * 1 + new_p.corners_top[1] * 2 + new_p.corners_bot[1] * 4 + new_p.corners_bot[0] * 8
			new_p.h_ints[1] = new_p.corners_top[1] * 1 + new_p.corners_top[2] * 2 + new_p.corners_bot[2] * 4 + new_p.corners_bot[1] * 8
			new_p.h_ints[2] = new_p.corners_top[2] * 1 + new_p.corners_top[3] * 2 + new_p.corners_bot[3] * 4 + new_p.corners_bot[2] * 8
			new_p.h_ints[3] = new_p.corners_top[3] * 1 + new_p.corners_top[0] * 2 + new_p.corners_bot[0] * 4 + new_p.corners_bot[3] * 8
			new_p.h_ints_inv = [0, 0, 0, 0]
			new_p.h_ints_inv[0] = new_p.corners_top[1] * 1 + new_p.corners_top[0] * 2 + new_p.corners_bot[0] * 4 + new_p.corners_bot[1] * 8
			new_p.h_ints_inv[1] = new_p.corners_top[2] * 1 + new_p.corners_top[1] * 2 + new_p.corners_bot[1] * 4 + new_p.corners_bot[2] * 8
			new_p.h_ints_inv[2] = new_p.corners_top[3] * 1 + new_p.corners_top[2] * 2 + new_p.corners_bot[2] * 4 + new_p.corners_bot[3] * 8
			new_p.h_ints_inv[3] = new_p.corners_top[0] * 1 + new_p.corners_top[3] * 2 + new_p.corners_bot[3] * 4 + new_p.corners_bot[0] * 8
			new_p.slots = []
			new_p.slots.append(prototype.slots[(0 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(1 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(2 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(3 + int(i)) % 4])
			new_p.slot_b = prototype.slot_b
			new_p.slot_t = prototype.slot_t
			new_p.weight = prototype.weight
			new_prototypes.append(new_p)
			
	return new_prototypes


func _generate() -> void:	
	_icosphere_verts = []
	_icosphere_polys = _icosphere.generate_icosphere(_icosphere_verts, iterations)
	var colours = {}
	
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
			_icosphere_verts[i] = (_icosphere_verts[i] + forces[i] * relax_iteration_delta).normalized() * 1.0
	
	var globe_mesh = ArrayMesh.new()
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	_globe.set_mesh(globe_mesh)
	
	var ocean_mesh = ArrayMesh.new()
	var ocean_mesh_array = globe_mesh_array.duplicate()
	for i in range(ocean_mesh_array[Mesh.ARRAY_VERTEX].size()):
		ocean_mesh_array[Mesh.ARRAY_VERTEX][i] = ocean_mesh_array[Mesh.ARRAY_VERTEX][i].normalized() * (radius + water_height)
		
	ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ocean_mesh_array)
	ocean_mesh.surface_set_material(0, water_material)
	water_material.set_shader_param("u_deep_colour", water_deep_colour)
	water_material.set_shader_param("u_shallow_colour", water_shallow_colour)
	_globe_ocean.set_mesh(ocean_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	for i in range(globe_wireframe_array[Mesh.ARRAY_VERTEX].size()):
		globe_wireframe_array[Mesh.ARRAY_VERTEX][i] = globe_wireframe_array[Mesh.ARRAY_VERTEX][i].normalized() * (radius + water_height)
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
					
	# calculate average polygon dimensions
	var total_length = 0.0
	for i in range(0, _icosphere_polys.size()):
		total_length += _icosphere_verts[_icosphere_polys[i].v[0]].distance_to(_icosphere_verts[_icosphere_polys[i].v[1]])
		total_length += _icosphere_verts[_icosphere_polys[i].v[1]].distance_to(_icosphere_verts[_icosphere_polys[i].v[2]])
		total_length += _icosphere_verts[_icosphere_polys[i].v[2]].distance_to(_icosphere_verts[_icosphere_polys[i].v[3]])
		total_length += _icosphere_verts[_icosphere_polys[i].v[3]].distance_to(_icosphere_verts[_icosphere_polys[i].v[0]])
	var average_dimension = total_length / (_icosphere_polys.size() * 4.0)
	
	# convert from quads on a sphere to cubes in our 3D grid space where the bottom of the lowest
	# level of the grid is the quad on the surface of the sphere
	var quad_cube_mapping = []
	var quad_to_quad_idx = {}
	var cell_height = average_dimension
	for i in range(0, _icosphere_polys.size()):
		quad_cube_mapping.append([])
		quad_to_quad_idx[_icosphere_polys[i]] = i
		for h in range(0, grid_height):
			var cell = Cell.new()
			cell.layer = h
			for v in range(0, 4):
				var vert = _icosphere_verts[_icosphere_polys[i].v[v]]
				cell.v_bot.append(vert + (vert.normalized() * cell_height * float(grid_height)))
				cell.v_top.append(vert + (vert.normalized() * cell_height * float(grid_height + 1)))
		
			quad_cube_mapping[i].append(cell)
			_grid_cells.append(cell)
			
	# set up cube neighbors
	for i in range(0, quad_cube_mapping.size()):
		for h in range(0, quad_cube_mapping[i].size()):
			var cube = quad_cube_mapping[i][h]
			# add the 4 neighboring cubes from the same layer
			for n in range(0, 4):
				var n_quad_idx = quad_to_quad_idx[_icosphere_polys[i].neighbors[n]]
				cube.neighbors.append(quad_cube_mapping[n_quad_idx][h])
			# add the cube above
			if h < grid_height - 1:
				cube.neighbors.append(quad_cube_mapping[i][h + 1])
			else: cube.neighbors.append(null)
			# add the cube below
			if h > 0:
				cube.neighbors.append(quad_cube_mapping[i][h - 1])
			else: cube.neighbors.append(null)
				
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

	_wfc_step -= delta
	#if Input.is_action_just_pressed("mouse_left"):
	if not _wfc_finished and _wfc_step < 0.0:
		_wfc_step = 0.0
		for i in range(0, 1):
			_wfc_finished = not _wfc.step(_grid_cells, _prototypes)
			if _wfc_finished:
				break
		_wfc_data = _wfc._wave
		_generate_surface_from_wfc()
		
		var quad_center := Vector3()
		for v in _grid_cells[_wfc._last_added].v_bot:
			quad_center += v
		quad_center /= 4.0
		_camera.set_orientation(quad_center)
		
		if _wfc_finished:
			_camera.enable_manual_control()
			
		#_generate_surface_from_voxels()	


func _generate_surface_from_wfc():
	for i in range(_grid_cells.size()):
		if _wfc_added[i]:
			continue
			
		var cell = _grid_cells[i] as Cell
			
		# find a prototype that matches
		var tile_possibilities = _wfc_data[i]
		if tile_possibilities.size() > 1:
			continue
		
		for t in tile_possibilities.size():
			var matched_prot = _prototypes[tile_possibilities[t]]
			var mesh = _globe_land.get_mesh()
			_add_mesh_for_prototype_on_quad(matched_prot, cell, mesh)
			_wfc_added[i] = true


func _add_mesh_for_prototype_on_quad(prototype, cell : Cell, array_mesh, possibilities = false, possibility_idx = 0):
		
	var corner_verts_pos = []
	for j in range(0, 4):
		corner_verts_pos.append(cell.v_bot[j])
		
	for i in range(0, prototype.mesh_names.size()):
		if prototype.mesh_names[i] == "0000-0000":
			return
			
		var tile_mesh : Mesh = load("res://assets/tiles/" + prototype.mesh_names[i] + ".obj")
		var tile_arrays = tile_mesh.surface_get_arrays(0).duplicate()
		if tile_arrays.size() == 0:
			print(prototype.mesh_names[i])
			printerr("MESH ERROR!")
			return
			
		# transform each vert in the prototype mesh
		var rot_matrix = Transform.IDENTITY.rotated(Vector3(0.0, 1.0, 0.0).normalized(), PI * 0.5 * prototype.mesh_rots[i])
		for v in range(0, tile_arrays[Mesh.ARRAY_VERTEX].size()):
			var vert = tile_arrays[Mesh.ARRAY_VERTEX][v]
			vert = rot_matrix.xform(vert)
			vert = _transform_vert(vert, corner_verts_pos, prototype.rot, cell.layer)
			tile_arrays[Mesh.ARRAY_VERTEX][v] = vert
			
		# add the new mesh to the array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, land_material)


func _transform_vert(var vert : Vector3, var corners, var rot : int, var layer : int) -> Vector3:
	# flatten 3D vert 
	var vert_2d = Vector2(vert.x, vert.z)
	
	# get vert coords as a ratio along the x/y axis
	# assumes input vert is inside a 2x2 square centred at 0,0
	var vert_x = (vert_2d.x + 1.0) / 2.0
	var vert_y = (vert_2d.y + 1.0) / 2.0
	
	# calculate new vert position using quad corners and weights we found above
	var new_x1 = lerp(corners[(0 - rot) % 4], corners[(1 - rot) % 4], vert_x)
	var new_x2 = lerp(corners[(3 - rot) % 4], corners[(2 - rot) % 4], vert_x)
	var new_vert = lerp(new_x1, new_x2, vert_y)
	
	# add height
	var vert_height = (vert.y + 1.0) / 2.0 # map to 0-1
	var height = radius + (cell_height) * (float(layer) + vert_height)
	return new_vert.normalized() * height
	
	
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
