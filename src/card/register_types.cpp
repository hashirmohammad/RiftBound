#include "register_types.h"
#include "card/card_data.h"
#include "card/card.h"

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_riftbound_module(ModuleInitializationLevel p_level)
{
    // Only register classes at the scene level
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE)
    {
        return;
    }

    // Register CardData first — Card depends on it
    ClassDB::register_class<CardData>();

    // Register Card node
    ClassDB::register_class<Card>();
}

void deinitialize_riftbound_module(ModuleInitializationLevel p_level)
{
    // Nothing to clean up manually — Godot handles it
}

// GDExtension entry point — Godot calls this when loading the .dylib
extern "C"
{
    GDExtensionBool GDE_EXPORT riftbound_library_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        const GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization)
    {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_riftbound_module);
        init_obj.register_terminator(deinitialize_riftbound_module);
        init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}