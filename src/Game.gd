extends Spatial
class_name Game


const Icosphere = preload("Icosphere.gd")

export var material : Material
export(float, 0.1, 10.0) var radius = 1.0 setget set_radius
export(int, 0, 7) var iterations = 2 setget set_iterations
export(float, 0.0, 10.0) var noise_lacunarity = 3.0 setget set_noise_lacunarity
export(int, 1, 9) var noise_octaves = 3 setget set_noise_octaves
export(float, 0.0, 2.0) var noise_period = 1.0 setget set_noise_period
export(float, 0.0, 1.0) var noise_persistence = 0.8 setget set_noise_persistence
export(float, 0.0, 1.0) var noise_influence = 0.5 setget set_noise_influence

var _generated := false
var _icosphere = null
var _noise = null
var _ico_mesh = []
var _ico_wireframe_mesh = []
var _generated_wireframe := false
var _icosphere_verts = []
var _icosphere_polys = []

var _mouse_hover := false
var _mouse_pos_on_globe := Vector3()

onready var _globe = get_node("Globe")
onready var _globe_wireframe = get_node("GlobeWireframe")


func _ready() -> void:
	_noise = OpenSimplexNoise.new()
	_icosphere = Icosphere.new()
	_icosphere._noise = _noise
	_generate()
	
func _generate() -> void:
	_icosphere._radius = radius
	_icosphere._noise_influence = noise_influence
	_noise.lacunarity = noise_lacunarity
	_noise.octaves = noise_octaves
	_noise.period = noise_period
	_noise.persistence = noise_persistence
	
	_icosphere_verts = []
	_icosphere_polys = _icosphere.generate_icosphere(_icosphere_verts, iterations)
	var colours = {}
	
	var globe_mesh = ArrayMesh.new()	
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	globe_mesh.surface_set_material(0, material)
	_globe.set_mesh(globe_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)
		
	_generated = true
		
func _process(delta : float) -> void:
	
	# relaxation
#	var vert_forces = []
#	vert_forces.resize(_icosphere_verts.size())
#
#	# first get the average distance between verts
#	var average := 0.0
#	for i in range(0, _icosphere_polys.size()):
#		for j in range(0, _icosphere_polys[i].v.size()):
#			var v1 = _icosphere_verts[_icosphere_polys[i].v[j]]
#			var v2 = _icosphere_verts[_icosphere_polys[i].v[(j + 1) % 4]]
#			average += v1.distance_to(v2)
#
#	var av_dist = average / float(_icosphere_polys.size() * 4)
#	av_dist = 0.5
#
#	# then, for each vert, calculate a force vector that would aim to equalise the 
#	# distance to each neighboring vert to the average distance between verts.
#	for poly in _icosphere_polys:
#		for i in range(0, poly.v.size()):
#
#			vert_forces[poly.v[i]] = Vector3()
#
#			var vl = poly.v[(i + 4 - 1) % 4]
#			if _icosphere_verts[poly.v[i]].distance_to(_icosphere_verts[vl]) > av_dist:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[vl]
#				vert_forces[poly.v[i]] += -vec.normalized() * vec.length()
#			else:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[vl]
#				vert_forces[poly.v[i]] += vec.normalized() * vec.length()
#
#			var vr = poly.v[(i + 4 + 1) % 4]
#			if _icosphere_verts[poly.v[i]].distance_to(_icosphere_verts[vr]) > av_dist:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[vr]
#				vert_forces[poly.v[i]] += -vec.normalized() * vec.length()
#			else:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[vr]
#				vert_forces[poly.v[i]] += vec.normalized() * vec.length()
#
#			var opp = poly.v[(i + 4 + 2) % 4]
#			var dist = sqrt(av_dist * av_dist + av_dist * av_dist)
#			if _icosphere_verts[poly.v[i]].distance_to(_icosphere_verts[opp]) > dist:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[opp]
#				vert_forces[poly.v[i]] += -vec.normalized() * vec.length()
#			else:
#				var vec = _icosphere_verts[poly.v[i]] - _icosphere_verts[opp]
#				vert_forces[poly.v[i]] += vec.normalized() * vec.length()
#
#	# apply the force on all our verts
#	for i in range(0, _icosphere_verts.size()):
#		var new_pos =  _icosphere_verts[i] + vert_forces[i] * 0.01
#		_icosphere_verts[i] = _icosphere._unit_to_planet(new_pos)

	var closest_poly = null
	var closest_dist = 9999.0
	for poly in _icosphere_polys:
		var center = Vector3(0.0, 0.0, 0.0)
		for v in poly.v:
			center += _icosphere_verts[v]
		center /= 4.0
		var dist_sq = center.distance_to(_mouse_pos_on_globe)
		if dist_sq < closest_dist:
			closest_poly = poly
			closest_dist = dist_sq
	
	print(_mouse_pos_on_globe)
	var colours = {}
	colours[closest_poly] = Color.green
	
	var globe_mesh = ArrayMesh.new()
	var globe_mesh_array = _icosphere.get_icosphere_mesh(_icosphere_polys, _icosphere_verts, colours)
	globe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, globe_mesh_array)
	globe_mesh.surface_set_material(0, material)
	_globe.set_mesh(globe_mesh)
	
	var globe_wireframe_mesh = ArrayMesh.new()
	var globe_wireframe_array = _icosphere.get_icosphere_wireframe(_icosphere_polys, _icosphere_verts)
	globe_wireframe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, globe_wireframe_array)
	_globe_wireframe.set_mesh(globe_wireframe_mesh)

func set_iterations(val : int) -> void: 
	iterations = val
	if _generated:
		_generate()

func set_radius(val : float) -> void: 
	radius = val
	if _generated:
		_generate()
		
func set_noise_lacunarity(val : int) -> void: 
	noise_lacunarity = val
	if _generated:
		_generate()
	
func set_noise_octaves(val : int) -> void: 
	noise_octaves = val
	if _generated:
		_generate()
	
func set_noise_period(val : int) -> void: 
	noise_period = val
	if _generated:
		_generate()
	
func set_noise_persistence(val : float) -> void: 
	noise_persistence = val
	if _generated:
		_generate()

func set_noise_influence(val : float) -> void: 
	noise_influence = val
	if _generated:
		_generate()

func _on_Area_mouse_entered():
	_mouse_hover = true
	
func _on_Area_input_event(camera, event, click_position, click_normal, shape_idx):
	_mouse_pos_on_globe = click_position

func _on_Area_mouse_exited():
	_mouse_hover = false
