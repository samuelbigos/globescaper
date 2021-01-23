#include "cell.h"

using namespace godot;

void GDCell::_register_methods() {
    register_method("_process", &GDCell::_process);
    register_property<GDCell, Array>("top", &GDCell::top, Array());
    register_property<GDCell, Array>("bot", &GDCell::bot, Array());
    register_property<GDCell, bool>("constrained", &GDCell::constrained, false);
    register_property<GDCell, Array>("constraint_top", &GDCell::constraint_top, Array());
    register_property<GDCell, Array>("constraint_bot", &GDCell::constraint_bot, Array());
    register_property<GDCell, int>("layer", &GDCell::layer, 0);
    register_property<GDCell, Array>("neighbors", &GDCell::neighbors, Array());
    register_property<GDCell, Vector3>("position", &GDCell::position, Vector3());
}

GDCell::GDCell() {
}

GDCell::~GDCell() {
}

void GDCell::_init() {
}

void GDCell::_process(float delta) {
}