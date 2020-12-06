extends Node
class_name Icosphere


var _radius := 1.0
var _noise_influence := 0.0
var _noise
var _rng = RandomNumberGenerator.new()

class Tri:
	var type := "tri"
	var verts = []
	
	func has_edge(edge : Vector2) -> bool:
		var edge_id = Vector2(min(edge.x, edge.y), max(edge.x, edge.y))
		if Vector2(min(verts[0], verts[1]), max(verts[0], verts[1])) == edge_id:
			return true
		if Vector2(min(verts[1], verts[2]), max(verts[1], verts[2])) == edge_id:
			return true
		if Vector2(min(verts[2], verts[0]), max(verts[2], verts[0])) == edge_id:
			return true
		return false
		
	func uid() -> Vector3:
		var sorted_verts = verts.duplicate()
		sorted_verts.sort()
		return Vector3(sorted_verts[0], sorted_verts[1], sorted_verts[2])
	
class Quad:
	var type := "quad"
	var tris = []


func generate_icosphere(verts, iterations : int):
	var middle_point_index_cache = {}
	var unit_vert_array = []
	
	var t = (1.0 + sqrt(5.0)) / 2.0;
	
	_add_vert(verts, Vector3(-1, t, 0))
	_add_vert(verts, Vector3(1, t, 0))
	_add_vert(verts, Vector3(-1, -t, 0))
	_add_vert(verts, Vector3(1, -t, 0))	
	_add_vert(verts, Vector3(0, -1, t))
	_add_vert(verts, Vector3(0, 1, t))
	_add_vert(verts, Vector3(0, -1, -t))
	_add_vert(verts, Vector3(0, 1, -t))	
	_add_vert(verts, Vector3(t, 0, -1))
	_add_vert(verts, Vector3(t, 0, 1))
	_add_vert(verts, Vector3(-t, 0, -1))
	_add_vert(verts, Vector3(-t, 0, 1))
		
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
	
	for _i in range(0, iterations):
		var new_tris = []
		for tri in tris:
			var a = _get_middle(middle_point_index_cache, verts, tri[0], tri[1])
			var b = _get_middle(middle_point_index_cache, verts, tri[1], tri[2])
			var c = _get_middle(middle_point_index_cache, verts, tri[2], tri[0])
			
			new_tris.append(_add_triangle(tri[0], a, c))
			new_tris.append(_add_triangle(tri[1], b, a))
			new_tris.append(_add_triangle(tri[2], c, b))
			new_tris.append(_add_triangle(a, b, c))
			
		tris = new_tris
	
	# we're now going to remove edges randomly so we get a grid of quads and tris
	var polys = []
	var used_edges = []
	
	for i in range(0, tris.size()):
		
		var tri := Tri.new()
		tri.verts.append(tris[i][0])
		tri.verts.append(tris[i][1])
		tri.verts.append(tris[i][2])
		
		var cont = false
		for poly in polys:
			if poly.type == "quad":
				if poly.tris[0].uid() == tri.uid() or poly.tris[1].uid() == tri.uid():
					cont = true
					break
					
		if cont:
			continue
		
		var edges = []
		if not used_edges.has(Vector2(min(tri.verts[0], tri.verts[1]), max(tri.verts[0], tri.verts[1]))):
			edges.append(Vector2(tri.verts[0], tri.verts[1]))
		if not used_edges.has(Vector2(min(tri.verts[1], tri.verts[2]), max(tri.verts[1], tri.verts[2]))):
			edges.append(Vector2(tri.verts[1], tri.verts[2]))
		if not used_edges.has(Vector2(min(tri.verts[2], tri.verts[0]), max(tri.verts[2], tri.verts[0]))):
			edges.append(Vector2(tri.verts[2], tri.verts[0]))
		
		if edges.size() == 0:
			polys.append(tri)
			continue
			
		var rand_edge = _rng.randi_range(0, edges.size() - 1)
		var edge = edges[rand_edge]
		
		# find the tri opposite the edge
		# this will be the other tri in tris that matches the two indices in the edge
		var opposite : Tri = null
		for j in range(0, tris.size()):
			if i == j:
				continue
				
			var test_tri = Tri.new()
			test_tri.verts.append(tris[j][0])
			test_tri.verts.append(tris[j][1])
			test_tri.verts.append(tris[j][2])
			
			if test_tri.has_edge(edge):
				opposite = test_tri
				break
		
		# merge the two tris between the edge
		var tri1 := Tri.new()
		tri1.verts.append(tri.verts[0])
		tri1.verts.append(tri.verts[1])
		tri1.verts.append(tri.verts[2])
		var tri2 := Tri.new()
		tri2.verts.append(opposite.verts[0])
		tri2.verts.append(opposite.verts[1])
		tri2.verts.append(opposite.verts[2])
		var quad := Quad.new()
		quad.tris.append(tri1)
		quad.tris.append(tri2)
		
		# mark the 6 edges as used so that we don't further break up this poly (we don't want
		# anything with more that 4 verts.
		# add and test in ascending order so we only have to add an edge once
		used_edges.append(Vector2(min(tri.verts[0], tri.verts[1]), max(tri.verts[0], tri.verts[1])))
		used_edges.append(Vector2(min(tri.verts[1], tri.verts[2]), max(tri.verts[1], tri.verts[2])))
		used_edges.append(Vector2(min(tri.verts[2], tri.verts[0]), max(tri.verts[2], tri.verts[0])))
		used_edges.append(Vector2(min(tri2.verts[0], tri2.verts[1]), max(tri2.verts[0], tri2.verts[1])))
		used_edges.append(Vector2(min(tri2.verts[1], tri2.verts[2]), max(tri2.verts[1], tri2.verts[2])))
		used_edges.append(Vector2(min(tri2.verts[2], tri2.verts[0]), max(tri2.verts[2], tri2.verts[0])))
		
		polys.append(quad)
		
	# next, split each quad into 4, and each tri into 3 (to make quads)
	var new_polys = []
	for poly in polys:
		if poly.type == "quad":
			new_polys.append(poly)
			
#			var quad := poly as Quad
#			var a = _get_middle(middle_point_index_cache, verts, tri.verts[0], tri.verts[1])
#			var b = _get_middle(middle_point_index_cache, verts, tri.verts[1], tri.verts[2])
#			var c = _get_middle(middle_point_index_cache, verts, tri.verts[2], tri.verts[0])
#			var center = _get_middle_3(middle_point_index_cache, verts, tri.verts[0], tri.verts[1], tri.verts[2])
#
#			var new_quad = Quad.new()
#			new_quad.tris.append(Tri.new())
#			new_quad.tris.append(Tri.new())
#			new_quad.tris[0].verts = [ c, tri.verts[0], center ]
#			new_quad.tris[1].verts = [ tri.verts[0], a, center ]
#			new_polys.append(new_quad)
		
		if poly.type == "tri":
			var tri := poly as Tri
			var a = _get_middle(middle_point_index_cache, verts, tri.verts[0], tri.verts[1])
			var b = _get_middle(middle_point_index_cache, verts, tri.verts[1], tri.verts[2])
			var c = _get_middle(middle_point_index_cache, verts, tri.verts[2], tri.verts[0])
			var center = _get_middle_3(middle_point_index_cache, verts, tri.verts[0], tri.verts[1], tri.verts[2])
			
			var new_quad = Quad.new()
			new_quad.tris.append(Tri.new())
			new_quad.tris.append(Tri.new())
			new_quad.tris[0].verts = [ c, tri.verts[0], center ]
			new_quad.tris[1].verts = [ tri.verts[0], a, center ]
			new_polys.append(new_quad)
			
			new_quad = Quad.new()
			new_quad.tris.append(Tri.new())
			new_quad.tris.append(Tri.new())
			new_quad.tris[0].verts = [ a, tri.verts[1], center ]
			new_quad.tris[1].verts = [ tri.verts[1], b, center ]
			new_polys.append(new_quad)
			
			new_quad = Quad.new()
			new_quad.tris.append(Tri.new())
			new_quad.tris.append(Tri.new())
			new_quad.tris[0].verts = [ b, tri.verts[2], center ]
			new_quad.tris[1].verts = [ tri.verts[2], c, center ]
			new_polys.append(new_quad)

	return new_polys
	
func get_icosphere_mesh(ico_polys, ico_verts):
	var normals = []
	var colors = []
	
	var count = 0
	var mesh_verts = []
	for poly in ico_polys:
		var tris = []
		if poly.type == "tri":
			var rand_col = Color(_rng.randf(), _rng.randf(), _rng.randf())
			var tri : Tri = poly as Tri
			mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[0]]))
			mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[1]]))
			mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[2]]))
			normals.append(tri.verts[0])
			normals.append(tri.verts[1])
			normals.append(tri.verts[2])
			colors.append(rand_col)
			colors.append(rand_col)
			colors.append(rand_col)
			
		elif poly.type == "quad":
			var quad : Quad = poly as Quad
			var rand_col = Color(_rng.randf(), _rng.randf(), _rng.randf())
			for tri in quad.tris:
				mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[0]]))
				mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[1]]))
				mesh_verts.append(_unit_to_planet(ico_verts[tri.verts[2]]))
				normals.append(tri.verts[0])
				normals.append(tri.verts[1])
				normals.append(tri.verts[2])
				colors.append(rand_col)
				colors.append(rand_col)
				colors.append(rand_col)
				
		count += 1
#		if count > 10:
#			break
	
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = PoolVector3Array(mesh_verts)
	mesh_array[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	mesh_array[Mesh.ARRAY_COLOR] = PoolColorArray(colors)
	return mesh_array
	
func get_icosphere_wireframe(ico_polys, ico_verts):
	var indices = []
	var normals = []
	var colors = []
	
	var count = 0
	var mesh_verts = []
	for poly in ico_polys:
		var tris = []
		if poly.type == "tri":
			
			var tri := poly as Tri
			var v0 = tri.verts[0]
			var v1 = tri.verts[1]
			var v2 = tri.verts[2]

			mesh_verts.append(_unit_to_planet(ico_verts[v0]))
			mesh_verts.append(_unit_to_planet(ico_verts[v1]))
			mesh_verts.append(_unit_to_planet(ico_verts[v1]))
			mesh_verts.append(_unit_to_planet(ico_verts[v2]))
			mesh_verts.append(_unit_to_planet(ico_verts[v2]))
			mesh_verts.append(_unit_to_planet(ico_verts[v0]))

			for i in range(0, 6):
				normals.append(0)
				colors.append(Color.white)
			
		elif poly.type == "quad":
			
			var quad := poly as Quad
			var edges = []
			edges.append(Vector2(quad.tris[0].verts[0], quad.tris[0].verts[1]))
			edges.append(Vector2(quad.tris[0].verts[1], quad.tris[0].verts[2]))
			edges.append(Vector2(quad.tris[0].verts[2], quad.tris[0].verts[0]))
			edges.append(Vector2(quad.tris[1].verts[0], quad.tris[1].verts[1]))
			edges.append(Vector2(quad.tris[1].verts[1], quad.tris[1].verts[2]))
			edges.append(Vector2(quad.tris[1].verts[2], quad.tris[1].verts[0]))
			
			var do_break = false
			for i in range(0, 6):
				for j in range(0, 6):
					if i == j:
						continue

					if Vector2(max(edges[i].x, edges[i].y), min(edges[i].x, edges[i].y)) == Vector2(max(edges[j].x, edges[j].y), min(edges[j].x, edges[j].y)):
						var edge_i = edges[i]
						var edge_j = edges[j]
						edges.erase(edge_i)
						edges.erase(edge_j)
						do_break = true
						break

				if do_break:
					break
					
			for edge in edges:
				mesh_verts.append(_unit_to_planet(ico_verts[edge.x]) * 1.001)
				mesh_verts.append(_unit_to_planet(ico_verts[edge.y]) * 1.001)
				normals.append(edge.x)
				normals.append(edge.y)
				colors.append(Color.white)
				colors.append(Color.white)
		
		count += 1
#		if count > 10:
#			break
						
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX)
	mesh_array[Mesh.ARRAY_VERTEX] = PoolVector3Array(mesh_verts)
	mesh_array[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	mesh_array[Mesh.ARRAY_COLOR] = PoolColorArray(colors)
	return mesh_array
	
func _add_triangle(v1 : int, v2 : int, v3 : int):
	var tri = []
	tri.append(v1)
	tri.append(v2)
	tri.append(v3)
	return tri
	
func _get_middle(middle_point_index_cache, verts, i1 : int, i2 : int) -> int:
	var key = Vector2(min(i1, i2), max(i1, i2))
	if middle_point_index_cache.has(key):
		return middle_point_index_cache[key]
	
	var middle_vec = (verts[i1] + verts[i2]) / 2.0
	_add_vert(verts, middle_vec)
	middle_point_index_cache[key] = verts.size() - 1
	return verts.size() - 1
	
func _get_middle_3(middle_point_index_cache, verts, i1 : int, i2 : int, i3 : int) -> int:
	var middle_vec = (verts[i1] + verts[i2] + verts[i3]) / 3.0
	_add_vert(verts, middle_vec)
	return verts.size() - 1

func _add_vert(verts, vert : Vector3) -> void:
	vert = vert.normalized()
	verts.append(vert)
	
#func _update_mesh():
#	assert(_mesh_array[Mesh.ARRAY_VERTEX].size() == _unit_vert_array.size())
#	var verts = PoolVector3Array()
#	for vert in _unit_vert_array:
#		verts.append(_unit_to_planet(vert))
#
#	var normals = PoolVector3Array()
#	normals.resize(verts.size())
#
#	var indices = _mesh_array[Mesh.ARRAY_INDEX]
#	for i in range(0, indices.size(), 3):
#		var v1 = verts[indices[i]]
#		var v2 = verts[indices[i + 1]]
#		var v3 = verts[indices[i + 2]]
#		var normal = -_get_tri_normal(v1, v2, v3)
#		normals[indices[i]] += normal
#		normals[indices[i + 1]] += normal
#		normals[indices[i + 2]] += normal
#
#	for i in range(0, normals.size()):
#		normals[i] /= 5.0
#
#	_mesh_array[Mesh.ARRAY_VERTEX] = verts
#	_mesh_array[Mesh.ARRAY_NORMAL] = normals
#
#	print("verts: %d" % [_mesh_array[Mesh.ARRAY_VERTEX].size()])
#	print("normals: %d" % [_mesh_array[Mesh.ARRAY_NORMAL].size()])
#	print("indices: %d" % [_mesh_array[Mesh.ARRAY_INDEX].size()])
#
#	return _mesh_array
	
func _get_tri_normal(a : Vector3, b : Vector3, c : Vector3) -> Vector3:
	return (b - a).cross(c - b).normalized()

# converts a unit vertex on our icosphere to the vertex on our planet, so we can apply deformations.
func _unit_to_planet(vert : Vector3) -> Vector3:
	var height = _radius + (_radius * _noise.get_noise_3d(vert.x, vert.y, vert.z) * _noise_influence)
	return vert * height
