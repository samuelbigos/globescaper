#ifndef PROTOTYPE_H
#define PROTOTYPE_H

#include <Godot.hpp>

namespace godot {

class GDPrototype : public Reference {
    GODOT_CLASS(GDPrototype, Reference)

public:
    static void _register_methods();

    GDPrototype();
    ~GDPrototype();

    void _init();
    void _process(float delta);

    int top_slot;
    int bot_slot;
    Array h_slots;
    Array h_slots_inv;
    int rot;
};

}

#endif