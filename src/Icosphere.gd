extends Node
class_name Icosphere


export var radius := 10.0
export var subdivisions := 1
export var relax_iterations : = 30
export var relax_iteration_delta := 0.05

var _rng = RandomNumberGenerator.new()
var _verts = []
var _polys = []


class Tri:
	var type := "tri"
	var v = []
	var neighbors = [] # can be quads or tris
	var children = []
	
	func has_edge(edge : Vector2) -> bool:
		var edge_id = Vector2(min(edge.x, edge.y), max(edge.x, edge.y))
		if Vector2(min(v[0], v[1]), max(v[0], v[1])) == edge_id:
			return true
		if Vector2(min(v[1], v[2]), max(v[1], v[2])) == edge_id:
			return true
		if Vector2(min(v[2], v[0]), max(v[2], v[0])) == edge_id:
			return true
		return false
		
	func uid() -> Vector3:
		var sorted_verts = v.duplicate()
		sorted_verts.sort()
		return Vector3(sorted_verts[0], sorted_verts[1], sorted_verts[2])
	
class Quad:
	var type := "quad"
	var v = []
	var neighbors = [] # can be quads or tris
	var children = []	
	var tri_1_uid : Vector3
	var tri_2_uid : Vector3
	
	
func get_verts(): return _verts
func get_polys(): return _polys

func generate() -> void:
	_verts = []
	_polys = []	
	var middle_point_index_cache = {}
	
	# create base set of verts from which all tris are made
	var t = (1.0 + sqrt(5.0)) / 2.0;
	_add_vert(_verts, Vector3(-1, t, 0))
	_add_vert(_verts, Vector3(1, t, 0))
	_add_vert(_verts, Vector3(-1, -t, 0))
	_add_vert(_verts, Vector3(1, -t, 0))	
	_add_vert(_verts, Vector3(0, -1, t))
	_add_vert(_verts, Vector3(0, 1, t))
	_add_vert(_verts, Vector3(0, -1, -t))
	_add_vert(_verts, Vector3(0, 1, -t))	
	_add_vert(_verts, Vector3(t, 0, -1))
	_add_vert(_verts, Vector3(t, 0, 1))
	_add_vert(_verts, Vector3(-t, 0, -1))
	_add_vert(_verts, Vector3(-t, 0, 1))
	
	# create base tris for the icosphere
	var tris = []
	tris.append(_add_triangle(5, 11, 0))
	tris.append(_add_triangle(1, 5, 0))
	tris.append(_add_triangle(7, 1, 0))
	tris.append(_add_triangle(10, 7, 0))
	tris.append(_add_triangle(11, 10, 0))
	
	tris.append(_add_triangle(9, 5, 1))
	tris.append(_add_triangle(4, 11, 5))
	tris.append(_add_triangle(2, 10, 11))
	tris.append(_add_triangle(6, 7, 10))
	tris.append(_add_triangle(8, 1, 7))
	
	tris.append(_add_triangle(4, 9, 3))
	tris.append(_add_triangle(2, 4, 3))
	tris.append(_add_triangle(6, 2, 3))
	tris.append(_add_triangle(8, 6, 3))
	tris.append(_add_triangle(9, 8, 3))
	
	tris.append(_add_triangle(5, 9, 4))
	tris.append(_add_triangle(11, 4, 2))
	tris.append(_add_triangle(10, 2, 6))
	tris.append(_add_triangle(7, 6, 8))
	tris.append(_add_triangle(1, 8, 9))
	
	# at this stage we connect up neighbors, and we need to remember update neighbors as 
	# we modify the icosphere since calculating neighbors again later will be expensive
	for tri1 in tris:
		# to get a tri's neighbors, find all other tris that share two verts with this tri
		for tri2 in tris:
			if tri1 == tri2:
				continue
			var shared_count = 0
			for vert1 in tri1.v:
				for vert2 in tri2.v:
					if vert1 == vert2:
						shared_count += 1
			if shared_count >= 2:
				tri1.neighbors.append(tri2)
		if tri1.neighbors.size() != 3:
			printerr("Error in neighbor calculation #1.")
			return
	
	# this is where we subdivide the original icosphere as many times as we want
	subdivisions = Globals.Size + 1
	for _i in range(0, subdivisions):
		var new_tris = []
		for tri in tris:
			# split each tri into 4 (into a triforce)
			var a = _get_middle_2(middle_point_index_cache, _verts, tri.v[0], tri.v[1])
			var b = _get_middle_2(middle_point_index_cache, _verts, tri.v[1], tri.v[2])
			var c = _get_middle_2(middle_point_index_cache, _verts, tri.v[2], tri.v[0])
			
			var new_tri_mid = _add_triangle(a, b, c)
			var new_tri = []
			new_tri.append(_add_triangle(tri.v[0], a, c))
			new_tri.append(_add_triangle(tri.v[1], b, a))
			new_tri.append(_add_triangle(tri.v[2], c, b))
			
			# update neighbors on the new tris
			# we know the 3 neighbors for the middle tri
			new_tri_mid.neighbors = [ new_tri[0], new_tri[1], new_tri[2] ]
			
			# the others are a bit more complicated. we know we're neighbored to the middle tri
			new_tri[0].neighbors = [ new_tri_mid ]
			new_tri[1].neighbors = [ new_tri_mid ]
			new_tri[2].neighbors = [ new_tri_mid ]
			
			# other neighbors are in other parent triangles
			for t1 in new_tri:
				for neighbor in tri.neighbors:
					for t2 in neighbor.children:
						# search neighbor children for tris that match 2 verts in our children
						var shared_count = 0
						for v1 in t1.v:
							for v2 in t2.v:
								if v1 == v2:
									shared_count += 1
						if shared_count == 2:
							# add to our new tri
							t1.neighbors.append(t2)
							# also add our new tri to neighbor
							t2.neighbors.append(t1)
							
				if t1.neighbors.size() > 3:
					printerr("Tri has too many neighbors.")
					return
					
			# add our new tris as children
			tri.children = [ new_tri[0], new_tri[1], new_tri[2], new_tri_mid ]
			
			new_tris.append(new_tri[0])
			new_tris.append(new_tri[1])
			new_tris.append(new_tri[2])
			new_tris.append(new_tri_mid)
			
		tris = new_tris
		
	# check neighbors are set correctly
	for tri in tris:
		if tri.neighbors.size() != 3:
			printerr("Error in neighbor calculation #2.")
			return
	
	# we're now going to remove edges randomly so we get a grid of quads and tris
	var used_edges = []
	
	for i in range(0, tris.size()):
		
		var tri = tris[i]
		
		var cont = false
		for poly in _polys:
			if poly.type == "quad":
				if poly.tri_1_uid == tri.uid() or poly.tri_2_uid == tri.uid():
					cont = true
					break
					
		if cont:
			continue
		
		var edges = []
		if not used_edges.has(Vector2(min(tri.v[0], tri.v[1]), max(tri.v[0], tri.v[1]))):
			edges.append(Vector2(tri.v[0], tri.v[1]))
		if not used_edges.has(Vector2(min(tri.v[1], tri.v[2]), max(tri.v[1], tri.v[2]))):
			edges.append(Vector2(tri.v[1], tri.v[2]))
		if not used_edges.has(Vector2(min(tri.v[2], tri.v[0]), max(tri.v[2], tri.v[0]))):
			edges.append(Vector2(tri.v[2], tri.v[0]))
		
		if edges.size() == 0:
			_polys.append(tri)
			continue
			
		var rand_edge_idx = _rng.randi_range(0, edges.size() - 1)
		var rand_edge = edges[rand_edge_idx]
		
		# find the tri opposite the edge
		# this will be the other tri in tris that matches the two indices in the edge
		var opposite : Tri = null
		for j in range(0, tris.size()):
			if i == j:
				continue
				
			if tris[j].has_edge(rand_edge):
				opposite = tris[j]
				break
				
		var opposite_verts = [ opposite.v[0], opposite.v[1], opposite.v[2] ]
		opposite_verts.erase(int(rand_edge.x))
		opposite_verts.erase(int(rand_edge.y))
		var opposite_vert = opposite_verts[0]
		
		# merge the two tris between the edge
		var quad := Quad.new()
		for j in range(0, 3):
			var edge = Vector2(tri.v[j], tri.v[(j + 1) % 3])
			if edge == rand_edge:
				quad.v.append(tri.v[j])
				quad.v.append(opposite_vert)
			else:
				quad.v.append(tri.v[j])
				
		quad.tri_1_uid = tri.uid()
		quad.tri_2_uid = opposite.uid()
						
		# mark the 6 edges as used so that we don't further break up this poly (we don't want
		# anything with more that 4 verts.
		# add and test in ascending order so we only have to add an edge once		
		used_edges.append(Vector2(min(tri.v[0], tri.v[1]), max(tri.v[0], tri.v[1])))
		used_edges.append(Vector2(min(tri.v[1], tri.v[2]), max(tri.v[1], tri.v[2])))
		used_edges.append(Vector2(min(tri.v[2], tri.v[0]), max(tri.v[2], tri.v[0])))
		used_edges.append(Vector2(min(opposite.v[0], opposite.v[1]), max(opposite.v[0], opposite.v[1])))
		used_edges.append(Vector2(min(opposite.v[1], opposite.v[2]), max(opposite.v[1], opposite.v[2])))
		used_edges.append(Vector2(min(opposite.v[2], opposite.v[0]), max(opposite.v[2], opposite.v[0])))
		
		# setup neighbors
		for n in tri.neighbors:
			if n == opposite:
				continue
			quad.neighbors.append(n)
			n.neighbors.erase(tri)
			n.neighbors.append(quad)
			
		for n in opposite.neighbors:
			if n == tri:
				continue
			quad.neighbors.append(n)
			n.neighbors.erase(opposite)
			n.neighbors.append(quad)
		
		_polys.append(quad)
		
	# check neighbors are set correctly
	for poly in _polys:
		if poly.v.size() != poly.neighbors.size():
			printerr("Error in neighbor calculation #3.")
			return
		
	# next, split each quad into 4, and each tri into 3 (to make quads)
	var new_polys = []
	for poly in _polys:
		if poly.type == "quad":
			var parent_quad := poly as Quad
			var a = _get_middle_2(middle_point_index_cache, _verts, parent_quad.v[0], parent_quad.v[1])
			var b = _get_middle_2(middle_point_index_cache, _verts, parent_quad.v[1], parent_quad.v[2])
			var c = _get_middle_2(middle_point_index_cache, _verts, parent_quad.v[2], parent_quad.v[3])
			var d = _get_middle_2(middle_point_index_cache, _verts, parent_quad.v[3], parent_quad.v[0])
			var m = _get_middle_4(_verts, parent_quad.v[0], parent_quad.v[1], parent_quad.v[2], parent_quad.v[3])

			var quads = [ Quad.new(), Quad.new(), Quad.new(), Quad.new() ]
			quads[0].v = [ parent_quad.v[0], a, m, d ]
			new_polys.append(quads[0])
			
			quads[1].v = [ parent_quad.v[1], b, m, a ]
			new_polys.append(quads[1])
			
			quads[2].v = [ parent_quad.v[2], c, m, b ]
			new_polys.append(quads[2])
			
			quads[3].v = [ parent_quad.v[3], d, m, c ]
			new_polys.append(quads[3])
			
			quads[0].neighbors = [ quads[3], quads[1] ]
			quads[1].neighbors = [ quads[0], quads[2] ]
			quads[2].neighbors = [ quads[1], quads[3] ]
			quads[3].neighbors = [ quads[2], quads[0] ]
			
			# setup surrounding neighbors
			for q1 in quads:
				for n in parent_quad.neighbors:
					for q2 in n.children:
						# for each possible neighbor poly, find those that share 2 verts
						var shared_count = 0
						for v1 in q1.v:
							for v2 in q2.v:
								if v1 == v2:
									shared_count += 1
						if shared_count == 2:
							# add to our new tri
							q1.neighbors.append(q2)
							# also add our new tri to neighbor
							q2.neighbors.append(q1)
							
				if q1.neighbors.size() > 4:
					printerr("Quad has too many neighbors.")
					return
							
			poly.children = [ quads[0], quads[1], quads[2], quads[3] ]
		
		if poly.type == "tri":
			var parent_tri := poly as Tri
			var a = _get_middle_2(middle_point_index_cache, _verts, parent_tri.v[0], parent_tri.v[1])
			var b = _get_middle_2(middle_point_index_cache, _verts, parent_tri.v[1], parent_tri.v[2])
			var c = _get_middle_2(middle_point_index_cache, _verts, parent_tri.v[2], parent_tri.v[0])
			var m = _get_middle_3(_verts, parent_tri.v[0], parent_tri.v[1], parent_tri.v[2])

			var quads = [ Quad.new(), Quad.new(), Quad.new() ]
			quads[0].v = [ c, parent_tri.v[0], a, m ]
			new_polys.append(quads[0])

			quads[1].v = [ a, parent_tri.v[1], b, m ]
			new_polys.append(quads[1])

			quads[2].v = [ b, parent_tri.v[2], c, m ]
			new_polys.append(quads[2])
			
			quads[0].neighbors = [ quads[1], quads[2] ]
			quads[1].neighbors = [ quads[0], quads[2] ]
			quads[2].neighbors = [ quads[0], quads[1] ]
			
			# setup surrounding neighbors
			for q1 in quads:
				for n in parent_tri.neighbors:
					for q2 in n.children:
						# for each possible neighbor poly, find those that share 2 verts
						var shared_count = 0
						for v1 in q1.v:
							for v2 in q2.v:
								if v1 == v2:
									shared_count += 1
						if shared_count == 2:
							# add to our new tri
							q1.neighbors.append(q2)
							# also add our new tri to neighbor
							q2.neighbors.append(q1)
							
				if q1.neighbors.size() > 4:
					printerr("Quad has too many neighbors.")
					return
							
			poly.children = [ quads[0], quads[1], quads[2] ]
			
	# check neighbors are set correctly
	for poly in new_polys:
		if poly.v.size() != poly.neighbors.size():
			printerr("Error in neighbor calculation #4.")
			return
			
	# fix neighbor winding so that the the first neighbor is always the one adjacent to v[0] and v[1] etc.
	for poly in new_polys:
		var new_neighbors = []
		for v in range(0, 4):
			for n in range(0, 4):
				if poly.neighbors[n].v.has(poly.v[v]) and poly.neighbors[n].v.has(poly.v[(v + 1) % 4]):
					new_neighbors.append(poly.neighbors[n])
					break
		poly.neighbors = new_neighbors
	
	_polys = new_polys
	
	_relax(_verts, _polys)
	
func _relax(verts, polys) -> void:
	var iterations = relax_iterations
	while iterations > 0:
		iterations -= 1
		var forces = []
		for _i in range(0, verts.size()):
			forces.append(Vector3())

		for poly in polys:
			var force = Vector3()
			
			# get centroid
			var center = Vector3()
			for i in range(0, 4):
				center += verts[poly.v[i]]
			center /= 4.0
			
			# create the rotation matrix to rotate our force vector in 90 degree steps around the centroid normal
			var rot_matrix = Transform.IDENTITY.rotated(center.normalized(), PI * 0.5)
			
			# collect forces
			for i in range(0, 4):
				force += verts[poly.v[i]] - center
				force = rot_matrix.xform(force)
			force /= 4.0
			
			# store forces
			for i in range(0, 4):
				forces[poly.v[i]] += center + force - verts[poly.v[i]]
				force = rot_matrix.xform(force)
				
		# apply all accumulated forces on every vert
		for i in range(0, verts.size()):
			verts[i] = (verts[i] + forces[i] * relax_iteration_delta).normalized() * 1.0
	
func get_array_mesh(var wireframe = false):
	var normals = []
	var mesh_verts = []
	for poly in _polys:
		if poly.type == "quad":
			var quad := poly as Quad
			if wireframe:
				var edges = []
				edges.append(Vector2(quad.v[0], quad.v[1]))
				edges.append(Vector2(quad.v[1], quad.v[2]))
				edges.append(Vector2(quad.v[2], quad.v[3]))
				edges.append(Vector2(quad.v[3], quad.v[0]))
				for edge in edges:
					mesh_verts.append(_unit_to_planet(_verts[edge.x]) * 1.001)
					mesh_verts.append(_unit_to_planet(_verts[edge.y]) * 1.001)
					normals.append(edge.x)
					normals.append(edge.y)					
			else:
				mesh_verts.append(_unit_to_planet(_verts[quad.v[0]]))
				mesh_verts.append(_unit_to_planet(_verts[quad.v[1]]))
				mesh_verts.append(_unit_to_planet(_verts[quad.v[3]]))
				normals.append(_verts[quad.v[0]])
				normals.append(_verts[quad.v[1]])
				normals.append(_verts[quad.v[3]])
				mesh_verts.append(_unit_to_planet(_verts[quad.v[1]]))
				mesh_verts.append(_unit_to_planet(_verts[quad.v[2]]))
				mesh_verts.append(_unit_to_planet(_verts[quad.v[3]]))
				normals.append(_verts[quad.v[1]])
				normals.append(_verts[quad.v[2]])
				normals.append(_verts[quad.v[3]])
	
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = PoolVector3Array(mesh_verts)
	mesh_array[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	return mesh_array
	
func _add_triangle(v1 : int, v2 : int, v3 : int):
	var tri := Tri.new()
	tri.v = [ v1, v2, v3 ]
	return tri
	
func _get_middle_2(middle_point_index_cache, verts, i1 : int, i2 : int) -> int:
	var key = Vector2(min(i1, i2), max(i1, i2))
	if middle_point_index_cache.has(key):
		return middle_point_index_cache[key]
	
	var middle_vec = (verts[i1] + verts[i2]) / 2.0
	_add_vert(verts, middle_vec)
	middle_point_index_cache[key] = verts.size() - 1
	return verts.size() - 1
	
func _get_middle_3(verts, i1 : int, i2 : int, i3 : int) -> int:
	var middle_vec = (verts[i1] + verts[i2] + verts[i3]) / 3.0
	_add_vert(verts, middle_vec)
	return verts.size() - 1
	
func _get_middle_4(verts, i1 : int, i2 : int, i3 : int, i4 : int) -> int:
	var middle_vec = (verts[i1] + verts[i2] + verts[i3] + verts[i4]) / 4.0
	_add_vert(verts, middle_vec)
	return verts.size() - 1

func _add_vert(verts, vert : Vector3) -> void:
	vert = vert.normalized()
	verts.append(vert)
	
func _get_tri_normal(a : Vector3, b : Vector3, c : Vector3) -> Vector3:
	return (b - a).cross(c - b).normalized()

func _unit_to_planet(vert : Vector3) -> Vector3:
	return vert.normalized() * radius
