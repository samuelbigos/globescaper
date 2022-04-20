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

    Array top;
    Array bot;
    int rot;
};

}

#endif