#include "wfc.h"
#include <time.h>

using namespace godot;

void WFC::_register_methods() { 
    register_method("setup_wfc", &WFC::setup_wfc);
    register_method("step", &WFC::step);
    register_method("get_wave", &WFC::get_wave);
    register_method("reset", &WFC::reset);
    register_method("add_constraint", &WFC::add_constraint);
}

WFC::WFC() {
    _current = -1;
}

WFC::~WFC() {
}

void WFC::setup_wfc(int seed, Array cells, Array prototypes, int grid_height) {
    _cells = new Array2D<int16_t>(cells.size(), CELL_COUNT);
    _cell_neighbors = new Array2D<int16_t>(cells.size(), 6);
    _prototypes = new Array2D<int16_t>(prototypes.size(), PROT_COUNT);
    _wave = new Array2D<int16_t>(cells.size(), prototypes.size());
    _collapsed.resize(cells.size());
    _entropy.resize(cells.size());
    _cell_positions.resize(cells.size());
    _wave_final = Array();

    // create prototype array
    for (int i = 0; i < prototypes.size(); i++) {
        GDPrototype* prot = Object::cast_to<GDPrototype>(prototypes[i]);
        _prototypes->get(i, PROT_TOP_0) = prot->top[0];
        _prototypes->get(i, PROT_TOP_1) = prot->top[1];
        _prototypes->get(i, PROT_TOP_2) = prot->top[2];
        _prototypes->get(i, PROT_TOP_3) = prot->top[3];
        _prototypes->get(i, PROT_BOT_0) = prot->bot[0];
        _prototypes->get(i, PROT_BOT_1) = prot->bot[1];
        _prototypes->get(i, PROT_BOT_2) = prot->bot[2];
        _prototypes->get(i, PROT_BOT_3) = prot->bot[3];

        _prototypes->get(i, PROT_TOP) = _build_slot(prot->top[0], prot->top[1], prot->top[2], prot->top[3]);
        _prototypes->get(i, PROT_BOT) = _build_slot(prot->bot[0], prot->bot[1], prot->bot[2], prot->bot[3]);

        _prototypes->get(i, PROT_SIDE_0) = _build_slot(prot->top[0], prot->top[1], prot->bot[1], prot->bot[0]);
        _prototypes->get(i, PROT_SIDE_1) = _build_slot(prot->top[1], prot->top[2], prot->bot[2], prot->bot[1]);
        _prototypes->get(i, PROT_SIDE_2) = _build_slot(prot->top[2], prot->top[3], prot->bot[3], prot->bot[2]);
        _prototypes->get(i, PROT_SIDE_3) = _build_slot(prot->top[3], prot->top[0], prot->bot[0], prot->bot[3]);

        _prototypes->get(i, PROT_SIDE_0_INV) = _build_slot(prot->top[1], prot->top[0], prot->bot[0], prot->bot[1]);
        _prototypes->get(i, PROT_SIDE_1_INV) = _build_slot(prot->top[2], prot->top[1], prot->bot[1], prot->bot[2]);
        _prototypes->get(i, PROT_SIDE_2_INV) = _build_slot(prot->top[3], prot->top[2], prot->bot[2], prot->bot[3]);
        _prototypes->get(i, PROT_SIDE_3_INV) = _build_slot(prot->top[0], prot->top[3], prot->bot[3], prot->bot[0]);

        _prototypes->get(i, PROT_WEIGHT) = 1;
    }

    // create cell arrays
    for (int i = 0; i < cells.size(); i++) {
        GDCell* cell = Object::cast_to<GDCell>(cells[i]);
        _cells->get(i, CELL_TOP_0) = cell->top[0];
        _cells->get(i, CELL_TOP_1) = cell->top[1];
        _cells->get(i, CELL_TOP_2) = cell->top[2];
        _cells->get(i, CELL_TOP_3) = cell->top[3];
        _cells->get(i, CELL_BOT_0) = cell->bot[0];
        _cells->get(i, CELL_BOT_1) = cell->bot[1];
        _cells->get(i, CELL_BOT_2) = cell->bot[2];
        _cells->get(i, CELL_BOT_3) = cell->bot[3];
        _cells->get(i, CELL_LAYER) = cell->layer;

        for (int n = 0; n < 6; n++) {
            _cell_neighbors->get(i, n) = cell->neighbors[n];
        }

        _cell_positions[i] = cell->position;
        
        // pre-bake contraints
        int match_count = 0;
        for (int p = 0; p < prototypes.size(); p++) {
            if (cell->constrained) {
                _wave->get(i, p) = (int)_match(p, cell->constraint_top, cell->constraint_bot);
            }
            else {
                if (cell->layer == 0) {
                    if (_prototypes->get(p, PROT_BOT_0) > 0 &&
                        _prototypes->get(p, PROT_BOT_1) > 0 &&
                        _prototypes->get(p, PROT_BOT_2) > 0 &&
                        _prototypes->get(p, PROT_BOT_3) > 0) 
                    {
                         _wave->get(i, p) = 1;
                    }
                    else {
                        _wave->get(i, p) = 0;
                    }
                }
                else if (cell->layer == grid_height - 1) {
                    if (_prototypes->get(p, PROT_TOP_0) == 0 &&
                        _prototypes->get(p, PROT_TOP_1) == 0 &&
                        _prototypes->get(p, PROT_TOP_2) == 0 &&
                        _prototypes->get(p, PROT_TOP_3) == 0)
                    {
                        _wave->get(i, p) = 1; 
                    }
                    else {
                        _wave->get(i, p) = 0;
                    }
                }
                else {
                    _wave->get(i, p) = 1;
                }
            }
            if (_wave->get(i, p) == 1)
                match_count++;
        }
        if (match_count == 0) {
            printf("match failed: %d/%d/%d/%d-%d/%d/%d/%d\n", (uint8_t)cell->constraint_bot[0],
                (uint8_t)cell->constraint_bot[1],
                (uint8_t)cell->constraint_bot[2],
                (uint8_t)cell->constraint_bot[3],
                (uint8_t)cell->constraint_top[0],
                (uint8_t)cell->constraint_top[1],
                (uint8_t)cell->constraint_top[2],
                (uint8_t)cell->constraint_top[3]);
        }       

        _entropy[i] = 99999.9;
        _collapsed[i] = false;
        _wave_final.append(-1);
    }
    _cached_wave = _wave;
    _first_collapse = 0;

    srand(seed);
}

void WFC::reset() {
    _wave = _cached_wave;
    _wave_final.clear();
    for (int i = 0; i < _cells->height; i++) {
        _entropy[i] = _wfc_calc_entropy_distance(i);
        _collapsed[i] = false;
        _wave_final.append(-1);
    }
}

void WFC::add_constraint(int cell_idx, Array top, Array bot) {
    for (int p = 0; p < _prototypes->height; p++) {
        _wave->get(cell_idx, p) = (int)_match(p, top, bot);
        _cached_wave->get(cell_idx, p) = (int)_match(p, top, bot);
    }
    _first_collapse = cell_idx;
}

uint16_t WFC::_build_slot(int c1, int c2, int c3, int c4) {
    uint16_t slot = 0;
    slot = slot | ((c1 & 0xF) << 0);
    slot = slot | ((c2 & 0xF) << 4);
    slot = slot | ((c3 & 0xF) << 8);
    slot = slot | ((c4 & 0xF) << 12);
    return slot;
}

bool WFC::_match(int p, Array top, Array bot) {
    bool match = true;
    // bot
    if (_prototypes->get(p, PROT_BOT_0) != static_cast<uint8_t>(bot[0])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_BOT_1) != static_cast<uint8_t>(bot[1])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_BOT_2) != static_cast<uint8_t>(bot[2])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_BOT_3) != static_cast<uint8_t>(bot[3])) {
        match = false;
    }
    // top
    if (_prototypes->get(p, PROT_TOP_0) != static_cast<uint8_t>(top[0])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_TOP_1) != static_cast<uint8_t>(top[1])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_TOP_2) != static_cast<uint8_t>(top[2])) {
        match = false;
    }
    if (_prototypes->get(p, PROT_TOP_3) != static_cast<uint8_t>(top[3])) {
        match = false;
    }
    if (match) {
        return true;
    } 
    return false;
}

int WFC::step(Array wave_final) {
    int steps = 0;
    while (_stack.size() > 0) {
        if (!_wfc_propagate()) {
            return -1;
        }
    }
    return _wfc_collapse();
}

Array WFC::get_wave() {
    return _wave_final;
}

void WFC::_init() {
}

int WFC::_wfc_collapse() {
    _current = _wfc_observe();

    if (_current == -1)
        return -1;
    
    double sum_of_weights = 0.0;
    for (int i = 0; i < _wave->width; i++) {
        if (_wave->get(_current, i) == 0)
            continue;

        sum_of_weights += 1.0;
    }

    if (sum_of_weights < 0.00001)
    {
        _collapsed[_current] = true;
        _wave_final[_current] = 0;
        return -2;
    }

    int rand_tile = -1;
    double rng = (double)_randf();
    double rnd = rng * sum_of_weights;
    for (int i = 0; i < _wave->width; i++) {
        if (_wave->get(_current, i) == 0)
            continue;

        if (rnd < (double)_prototypes->get(i, PROT_WEIGHT)) {
            rand_tile = i;
            break;
        }
        rnd -= (double)_prototypes->get(i, PROT_WEIGHT);
    }

    if (rand_tile == -1) {
        return -1;
    }

    for (int i = 0; i < _wave->width; i++) {
        _wave->get(_current, i) = 0;
    }
    _wave->get(_current, rand_tile) = 1;
    _collapsed[_current] = true;
    _wave_final[_current] = rand_tile;
    _stack.push_back(_current);

    return _current;
}

bool WFC::_wfc_propagate() {    
    int s_cell = _stack.back();
    _stack.pop_back();

    for (int n = 0; n < 6; n++) {
        int n_cell = _cell_neighbors->get(s_cell, n);
        if (n_cell == -1)
            continue;

        std::vector<int16_t> incompatible;
        for (int nt = 0; nt < _wave->width; nt++) {
            if (_wave->get(n_cell, nt) == 0)
                    continue;

            int nv = 0;
            if (n < 4) {
                for (int i = 0; i < 4; i++) {
                    if (_cells->get(s_cell, CELL_BOT_0 + n) == _cells->get(n_cell, CELL_BOT_0 + ((i + 1) % 4))) {
                        nv = i;
                    }
                }
            }

            bool compatible = false;
            for (int st = 0; st < _wave->width; st++) {
                if (_wave->get(s_cell, st) == 0)
                    continue;

                if (n == 5) {
                    compatible = _prototypes->get(st, PROT_BOT) == _prototypes->get(nt, PROT_TOP);
                }
                else if (n == 4) {
                    compatible = _prototypes->get(st, PROT_TOP) == _prototypes->get(nt, PROT_BOT);
                }
                else {
                    compatible = _wfc_compatible(st, nt, n, nv);
                }

                if (compatible)
                    break;
            }

            if (!compatible)
                incompatible.push_back(nt);            
        }
        if (incompatible.size() > 0) {

            int count = 0;
            for (int i = 0; i < _wave->width; i++) {
                if (_wave->get(n_cell, i) == 1)
                    count++;
            }

            for (int i = 0; i < incompatible.size(); i++) {
                _wfc_ban(n_cell, incompatible[i]);
            }

            count = 0;
            for (int i = 0; i < _wave->width; i++) {
                if (_wave->get(n_cell, i) == 1)
                    count++;
            }

            if (count == 0) {
                printf("IMPOSSIBRU!\n");
                return false;
            }
            
            _entropy[n_cell] = _wfc_calc_entropy_distance(n_cell);
            _stack.push_back(n_cell);
        }
    }
    return true;
}

double WFC::_wfc_calc_entropy_shannon(int cell) {
    double sum_of_weights = 0.0;
    double sum_of_weights_log_weights = 0.0;
    for (int i = 0; i < _prototypes->height; i++) {
        if (_wave->get(cell, i) == 0) 
            continue;
        double p = 1.0;
        sum_of_weights += p;
        sum_of_weights_log_weights += p * log(p);
    }
    double entropy = log(sum_of_weights) - sum_of_weights_log_weights / sum_of_weights;
    return entropy;
}

double WFC::_wfc_calc_entropy_distance(int cell) {
    double entropy = _cell_positions[cell].distance_to(_cell_positions[_first_collapse]);
    return entropy;
}

bool WFC::_wfc_compatible(int prot_1, int prot_2, int sv, int nv) {
    uint16_t s_slot = _prototypes->get(prot_1, PROT_SIDE_0 + sv);
    uint16_t n_slot = _prototypes->get(prot_2, PROT_SIDE_0_INV + nv);
    return s_slot == n_slot;
}

void WFC::_wfc_ban(int cell, int tile) {
    _wave->get(cell, tile) = 0;
}

int WFC::_wfc_observe() {
    double lowest_entropy = 9999999.9;
    int lowest_inx = -1;
    for (int i = 0; i < _wave->height; i++) {
        if (_collapsed[i])
            continue;

        if (_entropy[i] == 0.0) {
            lowest_inx = i;
            break;
        }
        if (_entropy[i] < lowest_entropy) {
            lowest_entropy = _entropy[i];
            lowest_inx = i;
        }
    }
    return lowest_inx;
}

float WFC::_randf() {
    return static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
}