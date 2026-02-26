#include "card_data.h"

namespace godot
{

    CardData::CardData()
    {
        // Initialize all properties to safe default values
        card_name = "";
        cost = 0;
        power = 0;
        rarity = COMMON;
    }

    CardData::~CardData()
    {
        // Nothing to manually clean up — Godot handles reference counting
    }

    void CardData::_bind_methods()
    {
        // Expose properties to the Godot editor and GDScript
        // This is what makes CardData fields show up as fields in the .tres editor

        ClassDB::bind_method(D_METHOD("set_card_name", "p_name"), &CardData::set_card_name);
        ClassDB::bind_method(D_METHOD("get_card_name"), &CardData::get_card_name);
        ADD_PROPERTY(PropertyInfo(Variant::STRING, "card_name"), "set_card_name", "get_card_name");

        ClassDB::bind_method(D_METHOD("set_cost", "p_cost"), &CardData::set_cost);
        ClassDB::bind_method(D_METHOD("get_cost"), &CardData::get_cost);
        ADD_PROPERTY(PropertyInfo(Variant::INT, "cost"), "set_cost", "get_cost");

        ClassDB::bind_method(D_METHOD("set_power", "p_power"), &CardData::set_power);
        ClassDB::bind_method(D_METHOD("get_power"), &CardData::get_power);
        ADD_PROPERTY(PropertyInfo(Variant::INT, "power"), "set_power", "get_power");

        ClassDB::bind_method(D_METHOD("set_texture", "p_texture"), &CardData::set_texture);
        ClassDB::bind_method(D_METHOD("get_texture"), &CardData::get_texture);
        ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "texture", PROPERTY_HINT_RESOURCE_TYPE, "Texture2D"), "set_texture", "get_texture");

        ClassDB::bind_method(D_METHOD("set_rarity", "p_rarity"), &CardData::set_rarity);
        ClassDB::bind_method(D_METHOD("get_rarity"), &CardData::get_rarity);
        ADD_PROPERTY(PropertyInfo(Variant::INT, "rarity", PROPERTY_HINT_ENUM, "Common,Rare,Epic,Legendary"), "set_rarity", "get_rarity");

        // Register the Rarity enum so it shows as a dropdown in the editor
        BIND_ENUM_CONSTANT(COMMON);
        BIND_ENUM_CONSTANT(RARE);
        BIND_ENUM_CONSTANT(EPIC);
        BIND_ENUM_CONSTANT(LEGENDARY);
    }

    // --- Getters and Setters ---

    void CardData::set_card_name(const String &p_name) { card_name = p_name; }
    String CardData::get_card_name() const { return card_name; }

    void CardData::set_cost(int p_cost) { cost = p_cost; }
    int CardData::get_cost() const { return cost; }

    void CardData::set_power(int p_power) { power = p_power; }
    int CardData::get_power() const { return power; }

    void CardData::set_texture(const Ref<Texture2D> &p_texture) { texture = p_texture; }
    Ref<Texture2D> CardData::get_texture() const { return texture; }

    void CardData::set_rarity(Rarity p_rarity) { rarity = p_rarity; }
    CardData::Rarity CardData::get_rarity() const { return rarity; }

} // namespace godot