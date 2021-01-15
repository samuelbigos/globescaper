#ifndef CELL_H
#define CELL_H

#include <Godot.hpp>
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
    int layer;
    Array neighbors;
};

}

#endif