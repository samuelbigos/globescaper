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

# exposed
export var land_material : Material
export var water_material : Material
export var water_deep_colour : Color
export var water_shallow_colour : Color
export var water_height = 0.5
export var camera_follow := false

# members
var _prototypes = []
var _wfc_data = []
var _wfc_added = []
var _wfc_step = 0.1
var _wfc_finished = false
var _cell_add_queue = []
var _debug_display_mode = 0
var _prototype_mesh_arrays = {}

onready var _camera = get_node("HGimbal")
onready var _globe_wireframe = get_node("GlobeWireframe")
onready var _globe_ocean : MeshInstance = get_node("GlobeOcean")
onready var _globe_land : MeshInstance = get_node("GlobeLand")
onready var _wfc = get_node("WaveFunctionCollapse")
onready var _sdf = get_node("SDFGen")
onready var _wfc_gd = get_node("WFC")
onready var _voxel_grid = get_node("VoxelGrid")
onready var _icosphere = get_node("Icosphere")

onready var _gdcell_script = load("res://bin/gdcell.gdns")
onready var _gdprototype_script = load("res://bin/gdprototype.gdns")

func _ready() -> void:	
	_icosphere.generate()
	_voxel_grid.create(_icosphere.get_verts(), _icosphere.get_polys())
	_prototypes = _load_prototype_data()
	
	var ocean_mesh = ArrayMesh.new()
	var ocean_mesh_array = _icosphere.get_array_mesh()
	for i in range(ocean_mesh_array[Mesh.ARRAY_VERTEX].size()):
		ocean_mesh_array[Mesh.ARRAY_VERTEX][i] = ocean_mesh_array[Mesh.ARRAY_VERTEX][i].normalized() * (_icosphere.radius + water_height)
	
	ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ocean_mesh_array)
	ocean_mesh.surface_set_material(0, water_material)
	water_material.set_shader_param("u_deep_colour", water_deep_colour)
	water_material.set_shader_param("u_shallow_colour", water_shallow_colour)
	_globe_ocean.set_mesh(ocean_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_array_mesh(true)
	for i in range(globe_wireframe_array[Mesh.ARRAY_VERTEX].size()):
		globe_wireframe_array[Mesh.ARRAY_VERTEX][i] = globe_wireframe_array[Mesh.ARRAY_VERTEX][i].normalized() * (_icosphere.radius + water_height)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
	
	var grid_cells = _voxel_grid.get_cells()
	_wfc.init(0, grid_cells, _prototypes, _voxel_grid.grid_height)
	_wfc_added = []
	for c in grid_cells:
		_wfc_added.append(false)
		
	# wfc gd
	var gd_cells = []
	for cell in grid_cells:
		var gd_cell = _gdcell_script.new()
		gd_cell.top = cell.v_top
		gd_cell.bot = cell.v_bot
		gd_cell.layer = cell.layer
		gd_cell.neighbors = []
		for n in cell.neighbors:
			if n == null:
				gd_cell.neighbors.append(-1)
			else:
				gd_cell.neighbors.append(n.index)
		gd_cells.append(gd_cell)
		
	var gd_prototypes = []
	for prot in _prototypes:
		var gd_prot = _gdprototype_script.new()
		gd_prot.top_slot = prot.top_int
		gd_prot.bot_slot = prot.bot_int
		gd_prot.h_slots = prot.h_ints
		gd_prot.h_slots_inv = prot.h_ints_inv
		gd_prot.rot = prot.rot
		gd_prototypes.append(gd_prot)
		
	_wfc_gd.setup_wfc(randi(), gd_cells, gd_prototypes, _voxel_grid.grid_height)
		
	_update_gui();

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
			
		for mesh_name in prototype.mesh_names:
			if not _prototype_mesh_arrays.has(mesh_name):
				var mesh : Mesh = load("res://assets/tiles/" + mesh_name + ".obj")
				if mesh.get_surface_count() > 0:
					_prototype_mesh_arrays[mesh_name] = mesh.surface_get_arrays(0)
			
	return new_prototypes
	
func _update_gui():
	$VSplitContainer/HBoxContainer/QuinticFilteringValue.text = "%d" % [int(_sdf._sdf_quintic_filter)]

func _process(delta : float) -> void:
	
	land_material.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)
	water_material.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)	
	_sdf.set_sdf_params_on_mat(land_material)
	_sdf.set_sdf_params_on_mat(water_material)	
	$SunGimbal.rotation.y += delta * PI * 0.01
	land_material.set_shader_param("u_sun_pos", $SunGimbal/Sun.global_transform.origin)
	water_material.set_shader_param("u_sun_pos", $SunGimbal/Sun.global_transform.origin)
			
	if not _wfc_finished:
		var last_wfc = _wfc_gd.step()
		if last_wfc == -1:
			_wfc_finished = true
		_wfc_data = _wfc_gd.get_wave()
	
	_process_wfc_gdnative(delta)
		
	# pump the mesh/sdf builder
	_generate_surface_from_wfc()
	
	if Input.is_action_just_released("spacebar"):
		_debug_display_mode = (_debug_display_mode + 1) % 2
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
	
	_update_gui()
	
func _generate_surface_from_wfc():
	if _cell_add_queue.size() > 0:
		var i = _cell_add_queue.pop_front()
			
		var matched_prot
		matched_prot = _prototypes[_wfc_data[i]]
			
		#_update_voxel_space(i, matched_prot)
		
		var mesh = _globe_land.get_mesh()
		var grid_cells = _voxel_grid.get_cells()
		_add_mesh_for_prototype_on_quad(matched_prot, grid_cells[i], mesh)
		
		if camera_follow:
			_camera.set_orientation(grid_cells[i].centre)
		
func _process_wfc_gdnative(delta) -> void:
	# add new wfc tiles to a queue for meshing
	_wfc_step -= delta
	if _wfc_step <= 0.0:
		_wfc_step = 0.0
		if _wfc_data.size() > 0:
			var grid_cells = _voxel_grid.get_cells()
			for i in range(grid_cells.size()):
				if _wfc_data[i] == -1:
					continue
				#if wfc_visualisation:
				#	_update_possibility_cube(i, _wfc_data[i].size())
				if _wfc_added[i]:
					continue
					
				_cell_add_queue.append(i)
				_wfc_added[i] = true
				break

func _add_mesh_for_prototype_on_quad(prototype, cell, array_mesh):
	var grid_verts = _voxel_grid.get_verts()
	var corner_verts_pos = []
	for j in range(0, 4):
		corner_verts_pos.append(grid_verts[cell.v_bot[j]])
		
	var sdf_verts = []
	for i in range(0, prototype.mesh_names.size()):
		if not _prototype_mesh_arrays.has(prototype.mesh_names[i]):
			return
			
		var tile_arrays = _prototype_mesh_arrays[prototype.mesh_names[i]].duplicate()
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
	var height = _icosphere.radius + (_voxel_grid.cell_height) * (float(layer) + vert_height)
	return vert.normalized() * height
