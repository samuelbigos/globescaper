extends Node
class_name WaveFunctionCollapse

var _rng = RandomNumberGenerator.new()

var _current = -1
var _wave = []
var _stack = []
var _cell_to_idx = {}
var _last_added := -1


func init(var i_seed : int, var i_cells, var i_prototypes):
	_rng.seed = i_seed
	_rng.randomize()
	
	_wave = []
	
	# build our initial state with each cell having all possible cell types (prototypes)
	for c in range(0, i_cells.size()):
		var domain = []
		for t in range(0, i_prototypes.size()):
			domain.append(t)
		_wave.append(domain)
		
	_cell_to_idx = {}
	for i in range(0, i_cells.size()):
		_cell_to_idx[i_cells[i]] = i
	
	
func step(var i_cells, var i_prototypes) -> bool:
	while _stack.size() > 0:
		_wfc_propagate(i_cells, i_prototypes)
	return _wfc_collapse(i_cells, i_prototypes)
			
		
func _wfc_collapse(var i_cells, var i_prototypes) -> bool:
	# select a starting cell that has the least entropy
	_current = _wfc_observe(_wave)
	
	if _current == -1:
		for i in _wave:
			print("%d - %s" % [i.size(), i[0]])
		return false
	
	# pick a random tile from this cell's domain and remove all others
	var rand_tile = _wave[_current][_rng.randi_range(0, _wave[_current].size() - 1)]
	_wave[_current] = []
	_wave[_current].append(rand_tile)
	_last_added = _current
	
	# propagate the change to every other cell's domain, reducing possibility space
	_stack = []
	_stack.push_back(_current)
	
	return true


func _wfc_propagate(var i_cells, var i_prototypes):
	# get the current stack item
	var s = _stack.pop_back()
	var s_cell = i_cells[s]
		
	for n in range(0, s_cell.neighbors.size()):
		var n_cell = s_cell.neighbors[n]
		var n_idx = _cell_to_idx[n_cell]
		
		# for each possible tile in the neighbor domain, check if it matches with any tile
		# from the original tile and if not, remove it from the domain
		var incompatible = []
		for n_tile in _wave[n_idx]:
			var compatible = false
			for s_tile in _wave[s]:
				
				# get the side in stack cell that matches the neighbor side
				for sv in range(0, 4):
					for nv in range(0, 4):
						if s_cell.v[sv] == n_cell.v[(nv + 1) % 4] and s_cell.v[(sv + 1) % 4] == n_cell.v[(nv) % 4]:
							
							var s_v1 = i_prototypes[s_tile].corners[sv]
							var s_v2 = i_prototypes[s_tile].corners[(sv + 1) % 4]
							var n_v1 = i_prototypes[n_tile].corners[nv]
							var n_v2 = i_prototypes[n_tile].corners[(nv + 1) % 4]
							
							compatible = (s_v1 == n_v2 and s_v2 == n_v1)
							
				if compatible:
					break
			
			# remove cell if not compatible
			if not compatible:
				incompatible.append(n_tile)
		
		# if we changed the neighbors possibility space we need to propagate out to it's neighbors
		if incompatible.size() > 0:
			for i in range(0, incompatible.size()):
				_wfc_ban(_wave, n_idx, incompatible[i])
				
			_stack.push_back(n_idx)
		
			
func _wfc_ban(wave, cell : int, tile : int) -> void:
	wave[cell].erase(tile)
		
		
func _wfc_observe(wave) -> int:
	var lowest_entropy_value := 999.9
	var lowest_entropy_index := -1
	for i in range(0, wave.size()):
		if wave[i].size() == 1:
			continue
			
		var entropy = 0.0
		var sum_of_weights = 0.0
		var sum_of_weight_log_weights = 0.0
		for d in range(0, wave[i].size()):
			var p = 1.0
			sum_of_weights += p
			sum_of_weight_log_weights += p * log(p)
		
		entropy = log(sum_of_weights) - sum_of_weight_log_weights / sum_of_weights
			
		if entropy < lowest_entropy_value:
			lowest_entropy_value = entropy
			lowest_entropy_index = i
			
	return lowest_entropy_index
