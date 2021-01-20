extends Spatial
class_name Game


# exposed
export var land_material : Material
export var water_material : Material
export var water_deep_colour : Color
export var water_shallow_colour : Color
export var water_height = 0.5
export var camera_follow := false
export var wfc_auto := false

# members
var _cell_idx_to_surface = {}
var _cell_idx_to_prototype = {}
var _debug_display_mode = 0

onready var _camera = get_node("HGimbal")
onready var _globe_wireframe = get_node("GlobeWireframe")
onready var _globe_ocean : MeshInstance = get_node("GlobeOcean")
onready var _globe_land : MeshInstance = get_node("GlobeLand")
onready var _sdf = get_node("SDFGen")
onready var _wfc = get_node("WFC")
onready var _voxel_grid = get_node("VoxelGrid")
onready var _icosphere = get_node("Icosphere")
onready var _prototype_db = get_node("PrototypeDB")
onready var _mouse_picker = get_node("MousePicker")
onready var _atmosphere = get_node("Atmosphere")

func _ready() -> void:
	_icosphere.generate()
	_voxel_grid.create(_icosphere.get_verts(), _icosphere.get_polys(), _icosphere.radius)
	_prototype_db.load_prototypes()
	_wfc.setup(_voxel_grid.get_cells(), _prototype_db.get_prototypes(), _voxel_grid.get_voxels(), _voxel_grid.grid_height, not wfc_auto, _icosphere.get_polys())
	
	_setup_meshes()
	_update_gui();
	
func _update_gui():
	$VSplitContainer/HBoxContainer/QuinticFilteringValue.text = "%d" % [int(_sdf._sdf_quintic_filter)]
	
func _setup_meshes():
	var ocean_mesh = ArrayMesh.new()
	var ocean_mesh_array = _icosphere.get_array_mesh()
	for i in range(ocean_mesh_array[Mesh.ARRAY_VERTEX].size()):
		ocean_mesh_array[Mesh.ARRAY_VERTEX][i] = ocean_mesh_array[Mesh.ARRAY_VERTEX][i].normalized() * (_icosphere.radius + water_height)
	
	ocean_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ocean_mesh_array)
	ocean_mesh.surface_set_material(0, water_material)
	water_material.set_shader_param("u_deep_colour", water_deep_colour)
	water_material.set_shader_param("u_shallow_colour", water_shallow_colour)
	_globe_ocean.set_mesh(ocean_mesh)
	
#	var globe_wireframe_mesh = ArrayMesh.new()
#	var globe_wireframe_array = _icosphere.get_array_mesh(true)
#	for i in range(globe_wireframe_array[Mesh.ARRAY_VERTEX].size()):
#		globe_wireframe_array[Mesh.ARRAY_VERTEX][i] = globe_wireframe_array[Mesh.ARRAY_VERTEX][i].normalized() * (_icosphere.radius + water_height)
#	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
#	_globe_wireframe.set_mesh(globe_wireframe_mesh)

func _process(delta: float) -> void:
	_camera.update(delta)
		
	land_material.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)
	_sdf.set_sdf_params_on_mat(land_material)
	land_material.set_shader_param("u_sun_pos", $SunGimbal/Sun.global_transform.origin)
	
	water_material.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)
	_sdf.set_sdf_params_on_mat(water_material)
	water_material.set_shader_param("u_sun_pos", $SunGimbal/Sun.global_transform.origin)
	
	#_atmosphere.visible = true
	var atmosphere_mat = _atmosphere.mesh.surface_get_material(0)
	atmosphere_mat.set_shader_param("u_camera_pos", get_viewport().get_camera().global_transform.origin)
	_sdf.set_sdf_params_on_mat(atmosphere_mat)
	atmosphere_mat.set_shader_param("u_sun_pos", $SunGimbal/Sun.global_transform.origin)
	atmosphere_mat.set_shader_param("u_planet_radius", _icosphere.radius + water_height)
	
	$SunGimbal.rotation.y += delta * PI * 0.1
	
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
	
	_update_gui()
	
	# process wfc here because gdnative doesn't like being called from anywhere else
	if not _wfc._wfc_finished:
		var added_mesh = false
		while not added_mesh:
			var last_wfc = _wfc._wfc_gd.step()
			added_mesh = on_wfc_cell_collapsed(last_wfc, _wfc._wfc_gd.get_wave()[last_wfc])
			if last_wfc == -1:
				added_mesh = true
				_wfc._wfc_finished = true
			
	# find out which cell face the mouse is over
	_do_mouse_picking()
	
	# reset wfc
	if Input.is_action_just_pressed("r"):
		_reset()
		
func _reset():
	_wfc.setup(_voxel_grid.get_cells(), _prototype_db.get_prototypes(), _voxel_grid.get_voxels(), _voxel_grid.grid_height, true, _icosphere.get_polys())
	#_reset_mesh()
	
func _reset_mesh():
	_globe_land.set_mesh(ArrayMesh.new())
	_cell_idx_to_surface.clear()
	_cell_idx_to_prototype.clear()
	_sdf.reset()
	
func _do_mouse_picking() -> void:
	var screen_pos = get_viewport().get_mouse_position()
	var ray_origin = _camera.get_camera().project_ray_origin(screen_pos)
	var ray_dir = _camera.get_camera().project_ray_normal(screen_pos).normalized()	
	var voxel = _voxel_grid.intersect(ray_origin, ray_dir)
	
	if voxel:
		_mouse_picker.transform.origin = _voxel_grid.get_verts()[voxel.vert]
		if Input.is_action_just_released("mouse_left"):
			_voxel_grid.set_voxel(voxel, true)
			_reset()

func _add_mesh_for_prototype_on_quad(cell, prototype):
	var array_mesh = _globe_land.get_mesh()
	var grid_verts = _voxel_grid.get_verts()
	var corner_verts_pos = []
	for j in range(0, 4):
		corner_verts_pos.append(grid_verts[cell.v_bot[j]])
		
	var sdf_verts = []
	_cell_idx_to_surface[cell.index] = []
	for i in range(0, prototype.mesh_names.size()):
		var mesh = _prototype_db.get_prototype_mesh(prototype.mesh_names[i])
		if mesh == null:
			return false
			
		var tile_arrays = mesh.duplicate()
		if tile_arrays.size() == 0:
			return false
					
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
		_cell_idx_to_surface[cell.index].append(array_mesh.get_surface_count() - 1)
		
	# draw these meshes on the sdf
	_sdf.set_mesh_texture(sdf_verts)
	
	return true

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

func on_wfc_cell_collapsed(var cell_idx : int, var prototype_idx : int) -> bool:
	var cell = _voxel_grid.get_cells()[cell_idx]
	var prot = _prototype_db.get_prototypes()[prototype_idx]
	if camera_follow:
		_camera.set_orientation(_voxel_grid.get_cells()[cell_idx].centre)
		
	if _cell_idx_to_prototype.has(cell.index) and _cell_idx_to_prototype[cell.index] == prototype_idx:
		return false
		
	remove_cell_surface(cell.index)
		
	_cell_idx_to_prototype[cell.index] = prototype_idx
	return _add_mesh_for_prototype_on_quad(cell, prot)

func remove_cell_surface(var cell_idx):
	if not _cell_idx_to_surface.has(cell_idx):
		return
		
	var surface_idx_array = _cell_idx_to_surface[cell_idx]
	for i in surface_idx_array:
		_globe_land.mesh.surface_remove(i)
		for key in _cell_idx_to_surface.keys():
			for s in range(0, _cell_idx_to_surface[key].size()):
				if _cell_idx_to_surface[key][s] > i:
					_cell_idx_to_surface[key][s] -= 1
