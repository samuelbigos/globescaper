#include "prototype.h"

using namespace godot;

void GDPrototype::_register_methods() {
    register_method("_process", &GDPrototype::_process);
    register_property<GDPrototype, int>("rot", &GDPrototype::rot, 0);
    register_property<GDPrototype, Array>("top", &GDPrototype::top, Array());
    register_property<GDPrototype, Array>("bot", &GDPrototype::bot, Array());
}

GDPrototype::GDPrototype() {
}

GDPrototype::~GDPrototype() {
}

void GDPrototype::_init() {
}

void GDPrototype::_process(float delta) {
}