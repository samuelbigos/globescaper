extends Node


var _wfc_finished = false

onready var _wfc_gd = get_node("WFCNative")
onready var _gdcell_script = load("res://bin/gdcell.gdns")
onready var _gdprototype_script = load("res://bin/gdprototype.gdns")


func setup(var grid_cells, var prototypes, var voxels, var verts, var grid_height: int, var constrained: bool, var quads):
	var start = OS.get_ticks_msec()
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
				gd_cell.constraint_bot.append(voxels[quads[cell.quad].v[i]][cell.layer].value)
				gd_cell.constraint_top.append(voxels[quads[cell.quad].v[i]][cell.layer + 1].value)
			
		gd_cell.position = verts[cell.v_top[0]]
		gd_cells.append(gd_cell)
		
	var gd_prototypes = []
	for prot in prototypes:
		var gd_prot = _gdprototype_script.new()
		gd_prot.rot = prot.rot
		gd_prot.top = prot.corners_top
		gd_prot.bot = prot.corners_bot
		gd_prototypes.append(gd_prot)

	_wfc_gd.setup_wfc(randi(), gd_cells, gd_prototypes, grid_height)
	_wfc_finished = false
	
func set_voxel(var voxel, var voxels, var quads):
	for cell in voxel.connected_cells:
		var bot = []
		var top = []
		for i in range(0, 4):
			bot.append(voxels[quads[cell.quad].v[i]][cell.layer].value)
			top.append(voxels[quads[cell.quad].v[i]][cell.layer + 1].value)
		add_constraint(cell.index, top, bot)
	
func add_constraint(var cell, var top, var bot):
	_wfc_gd.add_constraint(cell, top, bot)
	
func reset():
	_wfc_gd.reset()
	_wfc_finished = false
		
func _process(_delta) -> void:
	pass
