extends Node
class_name VoxelGrid


class Cell:
	var v_bot = []
	var v_top = []
	var layer = 0
	var neighbors = []
	var centre : Vector3
	var quad := -1
	var index := -1
	
export var grid_height := 3
export var cell_height := 0.5
export var wfc_visualisation := false
export var voxel_space_visualisation := false
export var possibility_cube_material : Material
	
var _grid_cells = []
var _grid_voxels = []
var _grid_verts = []

# visualisations
var _possibility_cubes = []
var _voxel_spheres = []


func get_cells(): return _grid_cells
func get_verts():	return _grid_verts

func create(var icosphere_verts, var icosphere_polys):
	# build a voxel map of our grid space by taking the icosphere verts and extending upwards
	# with a 2D array
	_grid_voxels = []
	_voxel_spheres = []
	var radius = icosphere_verts[0].length()
	for v in range(0, icosphere_verts.size()):
		_grid_voxels.append([])
		_voxel_spheres.append([])
		for _h in range(0, grid_height):
			_grid_voxels[v].append(0) # voxel field starts out zero-initialised and gets filled in as WFC runs
			if voxel_space_visualisation:
				var voxel_sphere = MeshInstance.new()
				var voxel_sphere_mesh = SphereMesh.new()
				voxel_sphere_mesh.radial_segments = 8
				voxel_sphere_mesh.rings = 4
				voxel_sphere.set_mesh(voxel_sphere_mesh)
				_voxel_spheres[v].append(voxel_sphere)
				add_child(voxel_sphere)
				
				
	# build a list of vert ids
	_grid_verts = []
	var grid_verts_map = []
	var vert_idx = 0
	for i in range(0, icosphere_verts.size()):
		grid_verts_map.append([])
		for h in range(0, grid_height + 1):
			var vert = icosphere_verts[i]
			grid_verts_map[i].append(vert_idx)
			_grid_verts.append(vert + (vert.normalized() * cell_height * float(h)))
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
			
	# set up cube neighbors
	for i in range(0, quad_cube_mapping.size()):
		for h in range(0, quad_cube_mapping[i].size()):
			var cube = quad_cube_mapping[i][h]
			# add the 4 neighboring cubes from the same layer
			for n in range(0, 4):
				var n_quad_idx = quad_to_quad_idx[icosphere_polys[i].neighbors[n]]
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

#func _update_voxel_space(i, prototype : Prototype):
#	var quad = _icosphere_polys[_grid_cells[i].quad] as Icosphere.Quad
#	for v in range(0, quad.v.size()):
#		var inside = prototype.corners_bot[v] != 0
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
