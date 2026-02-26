#ifndef REGISTER_TYPES_H
#define REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

/**
 * register_types.h — GDExtension entry point.
 *
 * These two functions are called automatically by Godot when it
 * loads and unloads the compiled .dylib library.
 *
 * initialize_riftbound_module() — registers all C++ classes with Godot
 * deinitialize_riftbound_module() — cleans up when Godot shuts down
 *
 * Every new C++ class you create (Card, HandManager, BoardManager, etc.)
 * must be registered inside initialize_riftbound_module() in register_types.cpp
 * or Godot will not know it exists.
 */

void initialize_riftbound_module(ModuleInitializationLevel p_level);
void deinitialize_riftbound_module(ModuleInitializationLevel p_level);

#endif // REGISTER_TYPES_H