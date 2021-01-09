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
	var centre : Vector3
	var quad := -1
	var index := -1
	
	
const Icosphere = preload("Icosphere.gd")

# exposed
export var land_material : Material
export var water_material : Material
export var poss_cube_material : Material
export var voxel_inside_material : Material
export var voxel_outside_material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export var relax_iterations : int = 30
export var relax_iteration_delta : float = 0.05
export var water_deep_colour : Color
export var water_shallow_colour : Color
export var cell_height = 1.0
export var grid_height = 5
export var water_height = 0.5
export var wfc_visualisation = false
export var voxel_space_visualisation = false

# members
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
var _tiles = []
var _tile_meshes = []
var _wfc_data = []
var _wfc_added = []
var _wfc_step = 0.1
var _wfc_finished = false
var _surface_generate = false
var _cell_add_queue = []
var _debug_display_mode = 0

# visualisations
var _possibility_cubes = []
var _voxel_spheres = []

# grid
var _grid_cells = []
var _grid_voxels = []
var _grid_verts = []

# input
var _mouse_hover := false
var _mouse_pos_on_globe := Vector3()

onready var _camera = get_node("HGimbal")
onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")
onready var _globe_ocean : MeshInstance = get_node("GlobeOcean")
onready var _globe_land : MeshInstance = get_node("GlobeLand")
onready var _wfc = get_node("WaveFunctionCollapse")
onready var _sdf = get_node("SDFGen")


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
			if prototype.weight <= 0.0:
				continue
				
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
		globe_wireframe_array[Mesh.ARRAY_VERTEX][i] = globe_wireframe_array[Mesh.ARRAY_VERTEX][i].normalized() * (radius + water_height * 1.01)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
	
	# build a voxel map of our grid space by taking the icosphere verts and extending upwards
	# with a 2D array
	_grid_voxels = []
	_grid_verts = []
	_voxel_spheres = []
	for v in range(0, _icosphere_verts.size()):
		_grid_voxels.append([])
		_grid_verts.append([])
		_voxel_spheres.append([])
		for h in range(0, grid_height):
			_grid_voxels[v].append(0) # voxel field starts out zero-initialised and gets filled in as WFC runs
			_grid_verts[v].append(_icosphere_verts[v] + _icosphere_verts[v].normalized() * cell_height * h)
			if voxel_space_visualisation:
				var voxel_sphere = MeshInstance.new()
				var voxel_sphere_mesh = SphereMesh.new()
				voxel_sphere_mesh.radial_segments = 8
				voxel_sphere_mesh.rings = 4
				voxel_sphere.set_mesh(voxel_sphere_mesh)
				_voxel_spheres[v].append(voxel_sphere)
				add_child(voxel_sphere)

	# convert from quads on a sphere to cubes in our 3D grid space where the bottom of the lowest
	# level of the grid is the quad on the surface of the sphere
	var quad_cube_mapping = []
	var quad_to_quad_idx = {}
	for i in range(0, _icosphere_polys.size()):
		quad_cube_mapping.append([])
		quad_to_quad_idx[_icosphere_polys[i]] = i
		for h in range(0, grid_height):
			var cell = Cell.new()
			cell.layer = h
			cell.centre = Vector3(0.0, 0.0, 0.0)
			for v in range(0, 4):
				var vert = _icosphere_verts[_icosphere_polys[i].v[v]]
				#TODO: Don't store verts as floats but as index into vert array
				cell.v_bot.append(vert + (vert.normalized() * cell_height * float(h)))
				cell.v_top.append(vert + (vert.normalized() * cell_height * float(h + 1)))
				cell.centre += cell.v_bot[v - 1]
				cell.centre += cell.v_top[v - 1]
		
			cell.centre /= 8.0
			cell.quad = i
			quad_cube_mapping[i].append(cell)
			_grid_cells.append(cell)
			cell.index = _grid_cells.size() - 1
			
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
					
	# add possibility cubes
	if wfc_visualisation:
		var indices = [0,1,2, 2,3,0,
					   1,0,4, 4,5,1,
					   2,1,5, 5,6,2,
					   3,2,6, 6,7,3,
					   0,3,7, 7,4,0,
					   4,7,6, 6,5,4]
		
		var st = SurfaceTool.new()
		for i in range(0, _grid_cells.size()):
			var cube = MeshInstance.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			
			for v in _grid_cells[i].v_top:
				var n = v - _grid_cells[i].centre
				var v_height = radius + (cell_height * (float(_grid_cells[i].layer) + 1.0))
				var c_height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
				v = v.normalized() * v_height - (_grid_cells[i].centre.normalized() * c_height)
				st.add_normal(n.normalized())
				st.add_vertex(v)
				
			for v in _grid_cells[i].v_bot:
				var n = v - _grid_cells[i].centre
				var v_height = radius + (cell_height * (float(_grid_cells[i].layer)))
				var c_height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
				v = v.normalized() * v_height - (_grid_cells[i].centre.normalized() * c_height)
				st.add_normal(n.normalized())
				st.add_vertex(v)
				
			for idx in indices:
				st.add_index(idx)
			
			cube.set_mesh(st.commit())
			cube.set_surface_material(0, poss_cube_material)
			cube.cast_shadow = false
			_possibility_cubes.append(cube)
			var height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
			cube.transform.origin = (_grid_cells[i].centre.normalized() * height)
			add_child(cube)
				
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

	# process wfc
	if not _wfc_finished:		
		_wfc_finished = not _wfc.step(_grid_cells, _prototypes)
		_wfc_data = _wfc._wave		
		var quad_center := Vector3()
		for v in _grid_cells[_wfc._last_added].v_bot:
			quad_center += v
		quad_center /= 4.0
		#_camera.set_orientation(quad_center)
			
	# add new wfc tiles to a queue for meshing
	_wfc_step -= delta
	if _wfc_step < 0.0:
	#if Input.is_action_just_released("mouse_left"):
		_wfc_step = 0.0
		if _wfc_data.size() > 0:
			for i in range(_grid_cells.size()):
				if wfc_visualisation:
					_update_possibility_cube(i, _wfc_data[i].size())
				if _wfc_added[i]:
					continue
				if _wfc_data[i].size() > 1:
					continue
					
				_cell_add_queue.append(i)
				_wfc_added[i] = true
				break
		
	# pump the mesh/sdf builder
	_generate_surface_from_wfc()
	
	if Input.is_action_just_released("spacebar"):
		_debug_display_mode = (_debug_display_mode + 1) % 3
		match _debug_display_mode:
			0:
				$SDFGen/SDFVolume.visible = true
				$SDFGen/SDFPreview.visible = false
			1:
				$SDFGen/SDFVolume.visible = false
				$SDFGen/SDFPreview.visible = false
			2:
				$SDFGen/SDFVolume.visible = true
				$SDFGen/SDFPreview.visible = true
		
func _generate_surface_from_wfc():
	if _cell_add_queue.size() > 0:
		var i = _cell_add_queue.pop_front()
			
		# find a prototype that matches
		var tile_possibilities = _wfc_data[i]
		if tile_possibilities.size() == 1:
			
			var matched_prot = _prototypes[tile_possibilities[0]]
			_update_voxel_space(i, matched_prot)
			
			var mesh = _globe_land.get_mesh()
			_add_mesh_for_prototype_on_quad(matched_prot, _grid_cells[i], mesh)
			
			if wfc_visualisation:
				_possibility_cubes[i].queue_free()
				

func _update_voxel_space(i, prototype : Prototype):
	var quad = _icosphere_polys[_grid_cells[i].quad] as Icosphere.Quad
	for v in range(0, quad.v.size()):
		var inside = prototype.corners_bot[v] != 0
		_grid_voxels[quad.v[v]][_grid_cells[i].layer] = inside
		
		if _grid_cells[i].layer < grid_height - 1:
			inside = prototype.corners_top[v] != 0
			_grid_voxels[quad.v[v]][_grid_cells[i].layer + 1] = inside
				
		if voxel_space_visualisation:
			var sphere = _voxel_spheres[quad.v[v]][_grid_cells[i].layer] as MeshInstance
			var pos = _icosphere_verts[quad.v[v]].normalized() * (radius + (cell_height * _grid_cells[i].layer))
			sphere.transform.origin = pos
			var size = 0.05
			sphere.scale = Vector3(size, size, size)
			if inside:
				sphere.get_mesh().surface_set_material(0, voxel_inside_material)
			else:
				sphere.get_mesh().surface_set_material(0, voxel_outside_material)
	

func _update_possibility_cube(cell, size):
	if size == 1 or _possibility_cubes.size() <= cell or _possibility_cubes[cell] == null:
		return
	
	var height = radius + (cell_height) * (float(_grid_cells[cell].layer))
	var scaled = float(size) / float(_prototypes.size())
	scaled *= 0.95
	_possibility_cubes[cell].scale = Vector3(scaled, scaled, scaled)
	

func _add_mesh_for_prototype_on_quad(prototype, cell : Cell, array_mesh, possibilities = false, possibility_idx = 0):
		
	var corner_verts_pos = []
	for j in range(0, 4):
		corner_verts_pos.append(cell.v_bot[j])
		
	var sdf_verts = []
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
			var normal = tile_arrays[Mesh.ARRAY_NORMAL][v]
			normal += vert
			normal = rot_matrix.xform(normal)
			normal = _transform_vert(normal, corner_verts_pos, prototype.rot, cell.layer)
						
			vert = rot_matrix.xform(vert)
			vert = _transform_vert(vert, corner_verts_pos, prototype.rot, cell.layer)
			normal -= vert
			
			tile_arrays[Mesh.ARRAY_VERTEX][v] = vert
			tile_arrays[Mesh.ARRAY_NORMAL][v] = normal
			
		for v in tile_arrays[Mesh.ARRAY_INDEX]:
			sdf_verts.append(tile_arrays[Mesh.ARRAY_VERTEX][v])
			
		# add the new mesh to the array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, land_material)
		
	# draw these meshes on the sdf
	_sdf.set_mesh_texture(sdf_verts)
		

func _nearest_point_on_line(var line_point, var line_dir, var point):
	var v = point - line_point
	var d = v.dot(line_dir)
	return line_point + line_dir * d


func _transform_vert(var vert : Vector3, var corners, var rot : int, var layer : int) -> Vector3:
	var vert_height = (vert.y + 1.0) / 2.0 # map to 0-1
	
	# flatten 3D vert 
	var vert_2d = Vector2(vert.x, vert.z)
	
	# get vert coords as a ratio along the x/y axis
	# assumes input vert is inside a 2x2 square centred at 0,0
	var vert_x = (vert_2d.x + 1.0) / 2.0
	var vert_y = (vert_2d.y + 1.0) / 2.0
	
	# calculate new vert position using quad corners and weights we found above
	var new_x1 = lerp(corners[(0 - rot) % 4], corners[(1 - rot) % 4], vert_x)
	var new_x2 = lerp(corners[(3 - rot) % 4], corners[(2 - rot) % 4], vert_x)
	vert = lerp(new_x1, new_x2, vert_y)
	
	# add height
	var height = radius + (cell_height) * (float(layer) + vert_height)
	return vert.normalized() * height
	
	
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
