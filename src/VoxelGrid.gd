extends Spatial
class_name VoxelGrid


class Cell:
	var v_bot = []
	var v_top = []
	var neighbors = []
	var centre : Vector3
	var layer = 0
	var quad := -1
	var index := -1
	
class Voxel:
	var vert : int
	var connected_cells = []
	var inside = false
	var vis_sphere = null
	
	
export var grid_height := 3
export var cell_height := 0.5
export var wfc_visualisation := false
export var voxel_space_visualisation := false
export var possibility_cube_material : Material
export var voxel_inside_material : Material
export var voxel_outside_material : Material

var _grid_cells = [] # 1D
var _grid_voxels = [] # 2D
var _grid_verts = [] # 1D

var _cell_collision_area_to_idx = {}

# visualisations
var _possibility_cubes = []
var _voxel_spheres = [] # 2D


func get_cells(): return _grid_cells
func get_verts(): return _grid_verts
func get_voxels(): return _grid_voxels

func create(var icosphere_verts, var icosphere_polys, var radius: float):
	# build a voxel map of our grid space by taking the icosphere verts and extending upwards
	# with a 2D array
	_grid_cells = []
	_grid_voxels = []
	_grid_verts = []
	_voxel_spheres = []
	var grid_verts_map = []
	var vert_idx = 0	
	for v in range(0, icosphere_verts.size()):
		_grid_voxels.append([])
		_voxel_spheres.append([])
		grid_verts_map.append([])
		for h in range(0, grid_height + 1):
			var vert = icosphere_verts[v]
			grid_verts_map[v].append(vert_idx)
			_grid_verts.append(vert.normalized() * (radius + cell_height * float(h)))
			
			var voxel = Voxel.new()
			voxel.vert = _grid_verts.size() - 1
			_grid_voxels[v].append(voxel)
			if h == 0:
				voxel.inside = true
			
			if voxel_space_visualisation:
				var sphere = _create_voxel_sphere(_grid_verts[vert_idx], voxel.inside)
				_voxel_spheres[v].append(sphere)
				add_child(sphere)
				voxel.vis_sphere = sphere
				
			vert_idx += 1

	# convert from quads on a sphere to cubes in our 3D grid space where the bottom of the lowest
	# level of the grid is the quad on the surface of the sphere
	var quad_cube_mapping = []
	var quad_to_quad_idx = {}
	for i in range(0, icosphere_polys.size()):
		quad_cube_mapping.append([])
		quad_to_quad_idx[icosphere_polys[i]] = i
		for h in range(0, grid_height):
			var cell = Cell.new()
			cell.layer = h
			cell.centre = Vector3(0.0, 0.0, 0.0)
			for v in range(0, 4):
				var vert_idx_bot = grid_verts_map[icosphere_polys[i].v[v]][h]
				var vert_idx_top = grid_verts_map[icosphere_polys[i].v[v]][h + 1]
				cell.v_bot.append(vert_idx_bot)
				cell.v_top.append(vert_idx_top)
				cell.centre += _grid_verts[cell.v_bot[v - 1]]
				cell.centre += _grid_verts[cell.v_top[v - 1]]
		
			cell.centre /= 8.0
			cell.quad = i
			quad_cube_mapping[i].append(cell)
			_grid_cells.append(cell)
			cell.index = _grid_cells.size() - 1
			
	# set up cell neighbors
	for i in range(0, quad_cube_mapping.size()):
		for h in range(0, quad_cube_mapping[i].size()):
			var cell = quad_cube_mapping[i][h]
			# add the 4 neighboring cubes from the same layer
			for n in range(0, 4):
				var n_quad_idx = quad_to_quad_idx[icosphere_polys[i].neighbors[n]]
				cell.neighbors.append(quad_cube_mapping[n_quad_idx][h])
			# add the cell above
			if h < grid_height - 1:
				cell.neighbors.append(quad_cube_mapping[i][h + 1])
			else: cell.neighbors.append(null)
			# add the cell below
			if h > 0:
				cell.neighbors.append(quad_cube_mapping[i][h - 1])
			else: cell.neighbors.append(null)
			
	# setup voxel cell relationships
	for i in range(0, _grid_cells.size()):
		var cell =  _grid_cells[i]
		for v in range(0, 4):
			var base_voxel_idx = icosphere_polys[cell.quad].v[v]
			var voxel_bot = _grid_voxels[base_voxel_idx][cell.layer]
			var voxel_top = _grid_voxels[base_voxel_idx][cell.layer + 1]
			voxel_bot.connected_cells.append(cell)
			voxel_top.connected_cells.append(cell)
			
	# setup collision areas for voxel picking
	for v in range(0, _grid_voxels.size()):
		for h in range(0, _grid_voxels[v].size()):
			var voxel = _grid_voxels[v][h] as Voxel
#			var area = Area.new()
#			var polygon = SphereShape.new()
#			var length = 0.0
#			for cell in voxel.connected_cells:
#				length += _grid_verts[voxel.vert].distance_to(cell.centre)
#
#			polygon.radius = length / voxel.connected_cells.size()
#			var owner_id = area.create_shape_owner(self)
#			area.shape_owner_add_shape(owner_id, polygon)
#			add_child(area)
#			_cell_collision_area_to_idx[area] = _grid_cells.size() - 1
					
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
				var vert = _grid_verts[v]
				var n = vert - _grid_cells[i].centre
				var v_height = radius + (cell_height * (float(_grid_cells[i].layer) + 1.0))
				var c_height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
				vert = vert.normalized() * v_height - (_grid_cells[i].centre.normalized() * c_height)
				st.add_normal(n.normalized())
				st.add_vertex(vert)
				
			for v in _grid_cells[i].v_bot:
				var vert = _grid_verts[v]
				var n = vert - _grid_cells[i].centre
				var v_height = radius + (cell_height * (float(_grid_cells[i].layer)))
				var c_height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
				vert = vert.normalized() * v_height - (_grid_cells[i].centre.normalized() * c_height)
				st.add_normal(n.normalized())
				st.add_vertex(vert)
				
			for idx in indices:
				st.add_index(idx)
			
			cube.set_mesh(st.commit())		
			cube.set_surface_material(0, possibility_cube_material)
			cube.cast_shadow = false
			_possibility_cubes.append(cube)
			var height = radius + (cell_height * (float(_grid_cells[i].layer) + 0.5))
			cube.transform.origin = (_grid_cells[i].centre.normalized() * height)
			add_child(cube)
			
func create_collision_volume_for_voxel():
	pass
#	# create the collision area for the cell for mouse picking
#	var area = Area.new()
#	var polygon = ConvexPolygonShape.new()
#	var polygon_verts = PoolVector3Array()
#	for v in range(0, 4):
#		polygon_verts.append(_grid_verts[cell.v_bot[v - 1]])
#		polygon_verts.append(_grid_verts[cell.v_top[v - 1]])
#	polygon.points = polygon_verts
#	var owner_id = area.create_shape_owner(self)
#	area.shape_owner_add_shape(owner_id, polygon)
#	add_child(area)
#	_cell_collision_area_to_idx[area] = _grid_cells.size() - 1
			
func intersect(var ray_origin: Vector3, var ray_dir: Vector3) -> Voxel:
	# find the voxel on each layer closest to the picking ray.
	var intersect_voxel
	for h in range(grid_height - 1, -1, -1):
		var closest = -1
		var closest_val = 9999.0
		for v in _grid_voxels.size():
			
			if h > 0 and not _grid_voxels[v][h - 1].inside:
				continue
				
			var point = _grid_verts[_grid_voxels[v][h].vert]
			if ray_dir.dot((point).normalized()) > 0.0:
				continue # ignore voxels on the dark side of the planet
			
			var dist = _nearest_point_on_line(ray_origin, ray_dir, point).distance_to(point)
			if dist < closest_val:
				closest_val = dist
				closest = v
		
		if closest != -1 and _grid_voxels[closest][h].inside == false:
			intersect_voxel = _grid_voxels[closest][h]

	return intersect_voxel
	
func set_voxel(var voxel: Voxel, var inside: bool):
	voxel.inside = inside
	if voxel_space_visualisation:
		if voxel.vis_sphere:
			if inside:
				voxel.vis_sphere.get_mesh().surface_set_material(0, voxel_inside_material)
			else:
				voxel.vis_sphere.get_mesh().surface_set_material(0, voxel_outside_material)
	
func _nearest_point_on_line(var line_point, var line_dir, var point):
	var v = point - line_point
	var d = v.dot(line_dir)
	return line_point + line_dir * d

func _create_voxel_sphere(var origin: Vector3, var inside: bool):
	var voxel_sphere = MeshInstance.new()
	var voxel_sphere_mesh = SphereMesh.new()
	voxel_sphere_mesh.radial_segments = 8
	voxel_sphere_mesh.rings = 4
	voxel_sphere.set_mesh(voxel_sphere_mesh)
	voxel_sphere.transform.origin = origin
	var size = 0.05
	voxel_sphere.scale = Vector3(size, size, size)
	if inside:
		voxel_sphere.get_mesh().surface_set_material(0, voxel_inside_material)
	else:
		voxel_sphere.get_mesh().surface_set_material(0, voxel_outside_material)
	return voxel_sphere
				
#func _update_voxel_space(var voxel, var inside = false):
#	var quad = _icosphere_polys[_grid_cells[i].quad] as Icosphere.Quad
#	for v in range(0, quad.v.size()):
#		_grid_voxels[quad.v[v]][_grid_cells[i].layer] = inside
#
#		if _grid_cells[i].layer < grid_height - 1:
#			inside = prototype.corners_top[v] != 0
#			_grid_voxels[quad.v[v]][_grid_cells[i].layer + 1] = inside
#
#		if voxel_space_visualisation:
#			var sphere = _voxel_spheres[quad.v[v]][_grid_cells[i].layer] as MeshInstance
#			var pos = _icosphere_verts[quad.v[v]].normalized() * (radius + (cell_height * _grid_cells[i].layer))
#			sphere.transform.origin = pos
#			var size = 0.05
#			sphere.scale = Vector3(size, size, size)
#			if inside:
#				sphere.get_mesh().surface_set_material(0, voxel_inside_material)
#			else:
#				sphere.get_mesh().surface_set_material(0, voxel_outside_material)

#func _update_possibility_cube(cell, size):
#	if size == 1 or _possibility_cubes.size() <= cell or _possibility_cubes[cell] == null:
#		return
#
#	var height = radius + (cell_height) * (float(_grid_cells[cell].layer))
#	var scaled = float(size) / float(_prototypes.size())
#	scaled *= 0.95
#	_possibility_cubes[cell].scale = Vector3(scaled, scaled, scaled)
