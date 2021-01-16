extends Node


var _wfc_finished = false

onready var _wfc_gd = get_node("WFCNative")
onready var _gdcell_script = load("res://bin/gdcell.gdns")
onready var _gdprototype_script = load("res://bin/gdprototype.gdns")

#signal on_wfc_cell_collapsed(cell_id, prototype_id)


func setup(var grid_cells, var prototypes, var voxels, var grid_height: int, var constrained: bool, var quads):
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
			
		gd_cell.constrained = false
		if constrained:
			gd_cell.constrained = true
			gd_cell.constraint_bot = []
			gd_cell.constraint_top = []
			for i in range(0, 4):
				gd_cell.constraint_bot.append(int(voxels[quads[cell.quad].v[i]][cell.layer].inside))
				gd_cell.constraint_top.append(int(voxels[quads[cell.quad].v[i]][cell.layer + 1].inside))
			
		gd_cells.append(gd_cell)
		
	var gd_prototypes = []
	for prot in prototypes:
		var gd_prot = _gdprototype_script.new()
		gd_prot.top_slot = prot.top_int
		gd_prot.bot_slot = prot.bot_int
		gd_prot.h_slots = prot.h_ints
		gd_prot.h_slots_inv = prot.h_ints_inv
		gd_prot.rot = prot.rot
		gd_prototypes.append(gd_prot)
		
	_wfc_gd.setup_wfc(randi(), gd_cells, gd_prototypes, grid_height)
	_wfc_finished = false
		
func _process(_delta) -> void:
	pass
