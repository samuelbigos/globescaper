#ifndef CELL_H
#define CELL_H

#include <godot.hpp>
#include <vector>

namespace godot {

class GDCell : public Reference {
    GODOT_CLASS(GDCell, Reference)

public:
    static void _register_methods();

    GDCell();
    ~GDCell();

    void _init();
    void _process(float delta);

    Array top;
    Array bot;
    bool constrained;
    Array constraint_top;
    Array constraint_bot;
    int layer;
    Array neighbors;
    Vector3 position;
};

}

#endif