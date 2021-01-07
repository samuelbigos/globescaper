extends Node
class_name WaveFunctionCollapse

var _rng = RandomNumberGenerator.new()

var _current = -1
var _wave = []
var _collapsed = []
var _stack = []
var _sum_of_weights = []
var _sum_of_weight_log_weights = []
var _entropy = []
var _cell_to_idx = {}
var _last_added := -1
var _tile_compatibility
var _layer = 0


func init(var i_seed : int, var i_cells, var i_prototypes, var grid_height : int):
	_rng.seed = i_seed
	_rng.randomize()
	
	_wave = []
	_collapsed = []
	_entropy = []
	_layer = 0
	
	var bot_domain = []
	for t in range(0, i_prototypes.size()):
		if i_prototypes[t].corners_bot[0] == 1 and \
			i_prototypes[t].corners_bot[1] == 1 and \
			i_prototypes[t].corners_bot[2] == 1 and \
			i_prototypes[t].corners_bot[3] == 1:
				
			bot_domain.append(t)
			
	var top_domain = []
	for t in range(0, i_prototypes.size()):
		if i_prototypes[t].corners_top[0] == 0 and \
			i_prototypes[t].corners_top[1] == 0 and \
			i_prototypes[t].corners_top[2] == 0 and \
			i_prototypes[t].corners_top[3] == 0:
				
			top_domain.append(t)
			
	var domain = []
	for t in range(0, i_prototypes.size()):
		domain.append(t)
		
	# build our initial state with each cell having all possible cell types (prototypes)
	for c in range(0, i_cells.size()):
		if i_cells[c].layer == 0:
			_wave.append(bot_domain.duplicate())
		elif i_cells[c].layer == grid_height - 1:
			_wave.append(top_domain.duplicate())
		else:
			_wave.append(domain.duplicate())
			
		_collapsed.append(false)
		_entropy.append(9999.9)
		
	_cell_to_idx = {}
	for i in range(0, i_cells.size()):
		_cell_to_idx[i_cells[i]] = i
	
	
func step(var i_cells, var i_prototypes) -> bool:
	var i_steps = 0
	while _stack.size() > 0:
		i_steps += 1
		if not _wfc_propagate(i_cells, i_prototypes):
			printerr("FAILURE! Propagation failed")
			return false
	return _wfc_collapse(i_cells, i_prototypes)
			
		
func _wfc_collapse(var i_cells, var i_prototypes) -> bool:
	# select a starting cell that has the least entropy
	_current = _wfc_observe(_wave)
	
	if _current == -1:
		return false
	
	# pick a weighted random tile from this cell's domain and remove all others
	var rand_tile = -1
	var sum_of_weights = 0.0
	for i in range(0, _wave[_current].size()):
		sum_of_weights += i_prototypes[_wave[_current][i]].weight
	var rnd = _rng.randf_range(0.0, sum_of_weights)
	for i in range(0, _wave[_current].size()):
		if rnd < i_prototypes[_wave[_current][i]].weight:
			rand_tile = _wave[_current][i]
			break
		rnd -= i_prototypes[_wave[_current][i]].weight
		
	if rand_tile == -1:
		printerr("FAILURE! Random tile failed")
		return false
		
	_wave[_current] = []
	_wave[_current].append(rand_tile)
	_collapsed[_current] = true
	_last_added = _current
	
	# propagate the change to every other cell's domain, reducing possibility space
	_stack = []
	_stack.push_back(_current)
	
	return true


func _wfc_propagate(var i_cells, var i_prototypes) -> bool:
	# get the current stack item
	var s = _stack.pop_back()
	var s_cell = i_cells[s]
		
	for n in range(0, s_cell.neighbors.size()):
		if s_cell.neighbors[n] == null:
			continue
			
		var n_cell = s_cell.neighbors[n]
		var n_idx = _cell_to_idx[n_cell]
		
		# for each possible tile in the neighbor domain, check if it matches with any tile
		# from the original tile and if not, remove it from the domain
		var incompatible = []
		for n_tile in _wave[n_idx]:
			
			var n_prot = i_prototypes[n_tile]
			var nv = 0
			if n < 4:
				for i in range(0, 4):
					if s_cell.v_bot[n] == n_cell.v_bot[(i + 1) % 4]:
						nv = i
			
			var compatible = false
			for s_tile in _wave[s]:
				
				var s_prot = i_prototypes[s_tile]
				
				# get the side in stack cell that matches the neighbor side
				if n ==  5:
					compatible = s_prot.bot_int == n_prot.top_int
				elif n ==  4:
					compatible = s_prot.top_int == n_prot.bot_int
				else:
					compatible = _wfc_compatible_h(s_prot, n_prot, n, nv)
					
				if compatible:
					break
			
			# remove cell if not compatible
			if not compatible:
				incompatible.append(n_tile)
		
		# if we changed the neighbors possibility space we need to propagate out to it's neighbors
		if incompatible.size() > 0:
			for i in range(0, incompatible.size()):
				_wfc_ban(_wave, n_idx, incompatible[i])
				
			if _wave[n_idx].size() == 0:
				printerr("FAILURE! Propagation failed")
				return false
				
			_entropy[n_idx] = _wfc_calc_entropy(_wave[n_idx])
			_stack.push_back(n_idx)
	
	return true
	
	
func _wfc_calc_entropy(domain):
	var sum_of_weights = 0.0
	var sum_of_weight_log_weights = 0.0
	for d in range(0, domain.size()):
		var p = 1.0
		sum_of_weights += p
		sum_of_weight_log_weights += p * log(p)
	return log(sum_of_weights) - sum_of_weight_log_weights / sum_of_weights
	
func _wfc_compatible_h(s_prot, n_prot, sv, nv):
	
	#var s_slot = s_prot.slots[sv]
	#var n_slot = n_prot.slots[nv]
	
	var compatible = s_prot.h_ints[sv] == n_prot.h_ints_inv[nv]
	#compatible = compatible and s_slot == n_slot
			
	return compatible
	
			
func _wfc_ban(wave, cell : int, tile : int) -> void:
	wave[cell].erase(tile)
	
		
func _wfc_observe(wave) -> int:
	var lowest_entropy_value := 99999.9
	var lowest_entropy_index := -1
	for i in range(0, wave.size()):
		if _collapsed[i]:
			continue
			
		if _entropy[i] == 0.0:
			lowest_entropy_index = i
			break
			
		if _entropy[i] < lowest_entropy_value:
			lowest_entropy_value = _entropy[i]
			lowest_entropy_index = i
			
	return lowest_entropy_index
