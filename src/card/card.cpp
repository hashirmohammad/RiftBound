#include "card.h"

namespace godot
{

    Card::Card()
    {
        // Initialize to default state — card starts in hand
        current_state = IN_HAND;
    }

    Card::~Card()
    {
        // Nothing to manually clean up — Godot handles memory
    }

    void Card::_bind_methods()
    {
        // Expose CardState enum to the editor and GDScript
        BIND_ENUM_CONSTANT(IN_HAND);
        BIND_ENUM_CONSTANT(DRAGGING);
        BIND_ENUM_CONSTANT(ON_BOARD);
        BIND_ENUM_CONSTANT(RETURNING);

        // Expose load_from_resource so it can be called from GDScript if needed
        ClassDB::bind_method(D_METHOD("load_from_resource", "data"), &Card::load_from_resource);

        // Expose state getter and setter
        ClassDB::bind_method(D_METHOD("set_card_state", "p_state"), &Card::set_card_state);
        ClassDB::bind_method(D_METHOD("get_card_state"), &Card::get_card_state);
        ADD_PROPERTY(PropertyInfo(Variant::INT, "card_state", PROPERTY_HINT_ENUM, "InHand,Dragging,OnBoard,Returning"), "set_card_state", "get_card_state");

        // Expose card data reference
        ClassDB::bind_method(D_METHOD("get_card_data"), &Card::get_card_data);
    }

    void Card::load_from_resource(const Ref<CardData> &data)
    {
        // Guard against null resource being passed in
        if (data.is_null())
        {
            return;
        }

        // Store the reference
        card_data = data;

        // TODO (Task 2): Once Card scene has Label and TextureRect child nodes,
        // populate them here using card_data->get_card_name(), get_cost(), etc.
        // Example:
        //   name_label->set_text(card_data->get_card_name());
        //   cost_label->set_text(String::num_int64(card_data->get_cost()));
        //   card_texture->set_texture(card_data->get_texture());
    }

    void Card::set_card_state(CardState p_state)
    {
        current_state = p_state;
    }

    Card::CardState Card::get_card_state() const
    {
        return current_state;
    }

    Ref<CardData> Card::get_card_data() const
    {
        return card_data;
    }

    void Card::_gui_input(const Ref<InputEvent> &event)
    {
        // TODO (Task 3): Implement mouse click, hover, and release detection
        // This is the entry point for all card mouse interactions
    }

    void Card::_process(double delta)
    {
        // TODO (Task 3): If current_state == DRAGGING, follow the mouse cursor
        // Example:
        // if (current_state == DRAGGING) {
        // set_global_position(get_global_mouse_position() - size / 2);
        //
    }

} 