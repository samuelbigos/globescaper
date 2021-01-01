extends Spatial
class_name Game


class Prototype:
	var mesh_names = []
	var mesh_rots = []
	var rotations = []
	var rot := 0
	var corners = []
	var slots = []
	var weight := 1.0
	
const Icosphere = preload("Icosphere.gd")

export var land_material : Material
export var water_material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export var relax_iterations : int = 30
export var relax_iteration_delta : float = 0.05
export var water_deep_colour : Color
export var water_shallow_colour : Color
export var water_height := 1.05

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
		
	_wfc.init(0, _icosphere_polys, _prototypes)
	_wfc_added = []
	for p in _icosphere_polys:
		_wfc_added.append(false)


func _load_prototype_data():
	var file = File.new()
	file.open("res://assets/base_prototypes.json", file.READ)
	var text = file.get_as_text()
	var prototypes_dict = JSON.parse(text).result
	file.close()
	
	# convert dictionary to prototypes
	for p in prototypes_dict.values():
		var prototype := Prototype.new()
		prototype.mesh_names = p["mesh_names"]
		prototype.mesh_rots = p["mesh_rots"]
		prototype.rotations = p["rotations"]
		prototype.corners = p["corners"]
		prototype.slots = [ p["up"], p["right"], p["down"], p["left"] ]
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
			new_p.corners = []
			new_p.corners.append(prototype.corners[(0 + int(i)) % 4])
			new_p.corners.append(prototype.corners[(1 + int(i)) % 4])
			new_p.corners.append(prototype.corners[(2 + int(i)) % 4])
			new_p.corners.append(prototype.corners[(3 + int(i)) % 4])
			new_p.slots = []
			new_p.slots.append(prototype.slots[(0 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(1 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(2 + int(i)) % 4])
			new_p.slots.append(prototype.slots[(3 + int(i)) % 4])
			new_p.weight = prototype.weight
			new_prototypes.append(new_p)
			
	return new_prototypes


func _generate() -> void:
	_icosphere._radius = radius
	
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
		ocean_mesh_array[Mesh.ARRAY_VERTEX][i] = ocean_mesh_array[Mesh.ARRAY_VERTEX][i].normalized() * radius * water_height
		
	ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ocean_mesh_array)
	ocean_mesh.surface_set_material(0, water_material)
	water_material.set_shader_param("u_deep_colour", water_deep_colour)
	water_material.set_shader_param("u_shallow_colour", water_shallow_colour)
	_globe_ocean.set_mesh(ocean_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	for i in range(globe_wireframe_array[Mesh.ARRAY_VERTEX].size()):
		globe_wireframe_array[Mesh.ARRAY_VERTEX][i] = globe_wireframe_array[Mesh.ARRAY_VERTEX][i].normalized() * radius * (water_height * 1.001)
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
			_wfc_finished = not _wfc.step(_icosphere_polys, _prototypes)
			if _wfc_finished:
				break
		_wfc_data = _wfc._wave
		_generate_surface_from_wfc()
		
		var quad_center := Vector3()
		for v in _icosphere_polys[_wfc._last_added].v:
			quad_center += _icosphere_verts[v]
		quad_center /= 4.0
		_camera.set_orientation(quad_center)
		
		if _wfc_finished:
			_camera.enable_manual_control()
			
		#_generate_surface_from_voxels()
		

func _add_from_wfc():
	var prototype = _prototypes[_wfc_data[_wfc._last_added][0]]
	var quad = _icosphere_polys[_wfc._last_added]
	var mesh = _globe_land.get_mesh()
	_add_mesh_for_prototype_on_quad(prototype, quad, mesh)
	

func _generate_surface_from_wfc():
	for i in range(_icosphere_polys.size()):
		if _wfc_added[i]:
			continue
			
		var poly = _icosphere_polys[i] as Icosphere.Quad
			
		# find a prototype that matches
		var tile_possibilities = _wfc_data[i]
		if tile_possibilities.size() > 1:
			continue
		
		for t in tile_possibilities.size():
			var matched_prot = _prototypes[tile_possibilities[t]]
			var mesh = _globe_land.get_mesh()
			_add_mesh_for_prototype_on_quad(matched_prot, poly, mesh)
			_wfc_added[i] = true


func _add_mesh_for_prototype_on_quad(prototype, quad, array_mesh, possibilities = false, possibility_idx = 0):
		
	var corner_verts_pos = []
	for j in range(0, 4):
		corner_verts_pos.append(_icosphere_verts[quad.v[j]])
	
	# display possibilities in a grid
	if possibilities:
		var grid = 5.0
		var new_corners = []
		var t = possibility_idx
		var x = float(t % int(grid)) - (grid * 0.5)
		var y = float(t / int(grid)) - (grid * 0.5)

		var offset = Vector3((2.0 / grid * float(x)), 0.0, (2.0 / grid * float(y)))
		new_corners.append(_transform_vert(offset, corner_verts_pos, 0))
		offset = Vector3((2.0 / grid * float(x + 1.0)), 0.0, (2.0 / grid * float(y)))
		new_corners.append(_transform_vert(offset, corner_verts_pos, 0))
		offset = Vector3((2.0 / grid * float(x + 1.0)), 0.0, (2.0 / grid * float(y + 1.0)))
		new_corners.append(_transform_vert(offset, corner_verts_pos, 0))
		offset = Vector3((2.0 / grid * float(x)), 0.0, (2.0 / grid * float(y + 1.0)))
		new_corners.append(_transform_vert(offset, corner_verts_pos, 0))

		corner_verts_pos = new_corners
		
	for i in range(0, prototype.mesh_names.size()):
		var tile_mesh : Mesh = load("res://assets/tiles/" + prototype.mesh_names[i] + ".obj")
		var tile_arrays = tile_mesh.surface_get_arrays(0).duplicate()
		if tile_arrays.size() == 0:
			return
			
		# transform each vert in the prototype mesh
		var rot_matrix = Transform.IDENTITY.rotated(Vector3(0.0, 1.0, 0.0).normalized(), PI * 0.5 * prototype.mesh_rots[i])
		for v in range(0, tile_arrays[Mesh.ARRAY_VERTEX].size()):
			var vert = tile_arrays[Mesh.ARRAY_VERTEX][v]
			vert = rot_matrix.xform(vert)
			vert = _transform_vert(vert, corner_verts_pos, prototype.rot)
			tile_arrays[Mesh.ARRAY_VERTEX][v] = vert
			
		# add the new mesh to the array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile_arrays)
		array_mesh.surface_set_material(array_mesh.get_surface_count() - 1, land_material)


func _generate_surface_from_voxels():
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
			if prototype.corners[0] == corners[0] and \
				prototype.corners[1] == corners[1] and \
				prototype.corners[2] == corners[2] and \
				prototype.corners[3] == corners[3]:
				
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
				corner_verts_pos.append(_icosphere_verts[poly.v[j]])
			
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
				tile_arrays[Mesh.ARRAY_VERTEX][v] = _transform_vert(tile_arrays[Mesh.ARRAY_VERTEX][v], corner_verts_pos, matched_prot.mesh_rot)
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
					mirrored_tile_arrays[Mesh.ARRAY_VERTEX][v] = _transform_vert(vert, corner_verts_pos, matched_prot.mesh_rot)
					#mirrored_tile_arrays[Mesh.ARRAY_NORMAL][v] = trans.xform(tile_arrays[Mesh.ARRAY_NORMAL][v])
					
				surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mirrored_tile_arrays)
				surface_mesh.surface_set_material(surface_mesh.get_surface_count() - 1, land_material)


func _transform_vert(var vert : Vector3, var corners, var rot : int) -> Vector3:
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
	
	# add height (map to a hardcoded fraction of the sphere radius for now)
	var vert_height = (vert.y + 1.0) / 2.0 # map to 0-1
	return new_vert.normalized() * (radius + (vert_height * 0.2) * radius)
	
	
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
