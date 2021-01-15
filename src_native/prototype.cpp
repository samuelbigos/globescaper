#include "prototype.h"

using namespace godot;

void GDPrototype::_register_methods() {
    register_method("_process", &GDPrototype::_process);
    register_property<GDPrototype, int>("top_slot", &GDPrototype::top_slot, 0);
    register_property<GDPrototype, int>("bot_slot", &GDPrototype::bot_slot, 0);
    register_property<GDPrototype, Array>("h_slots", &GDPrototype::h_slots, Array());
    register_property<GDPrototype, Array>("h_slots_inv", &GDPrototype::h_slots_inv, Array());
    register_property<GDPrototype, int>("rot", &GDPrototype::rot, 0);
}

GDPrototype::GDPrototype() {
}

GDPrototype::~GDPrototype() {
}

void GDPrototype::_init() {
}

void GDPrototype::_process(float delta) {
}