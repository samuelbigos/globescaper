extends Node
class_name PrototypeDB


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
	
var _prototypes = []
var _prototype_mesh_arrays = {}


func get_prototypes(): return _prototypes

func get_prototype_mesh(mesh_name):
	if _prototype_mesh_arrays.has(mesh_name):
		return _prototype_mesh_arrays[mesh_name]
	return null

func load_prototypes():
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
					
	_prototypes = new_prototypes
