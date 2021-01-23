#ifndef WFC_H
#define WFC_H

#include <cstdlib>
#include <vector>

#include <Godot.hpp>
#include "prototype.h"
#include "cell.h"
#include "utils/array2d.hpp"

namespace godot {

class WFC : public Reference {
    GODOT_CLASS(WFC, Reference)

private:

    enum c_data {
        CELL_TOP_0,
        CELL_TOP_1,
        CELL_TOP_2,
        CELL_TOP_3,
        CELL_BOT_0,
        CELL_BOT_1,
        CELL_BOT_2,
        CELL_BOT_3,
        CELL_LAYER,
        CELL_COUNT
    };

    enum p_data {
        PROT_TOP,
        PROT_BOT,
        PROT_SIDE_0,
        PROT_SIDE_1,
        PROT_SIDE_2,
        PROT_SIDE_3,
        PROT_SIDE_0_INV,
        PROT_SIDE_1_INV,
        PROT_SIDE_2_INV,
        PROT_SIDE_3_INV,
        PROT_WEIGHT,
        PROT_COUNT
    };

    int _wfc_collapse();
    bool _wfc_propagate();
    double _wfc_calc_entropy_shannon(int cell);
    double _wfc_calc_entropy_distance(int cell);
    bool _wfc_compatible(int prot_1, int prot_2, int sv, int nv);
    void _wfc_ban(int cell, int tile);
    int _wfc_observe();
    bool _match(int prototype, Array top, Array bot);
    float _randf();

    Array2D<int16_t>* _cells;
    Array2D<int16_t>* _cell_neighbors;
    Array2D<int16_t>* _prototypes;
    Array2D<int16_t>* _wave;
    std::vector<bool> _collapsed;
    std::vector<double> _entropy;
    std::vector<int16_t> _stack;
    std::vector<Vector3> _cell_positions;
    Array _wave_final;
    int _current;
    int _first_collapse;

    Array2D<int16_t>* _cached_wave;

public:
    static void _register_methods();

    WFC();
    ~WFC();

    void setup_wfc(int seed, Array cells, Array prototypes, int grid_height);
    int step(Array wave);
    Array get_wave();
    void add_constraint(int cell_idx, Array top, Array bot);
    void reset();

    void _init();
};

}

#endif