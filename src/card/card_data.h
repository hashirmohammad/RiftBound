#ifndef CARD_DATA_H
#define CARD_DATA_H

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot
{

    /**
     * CardData — Resource class that holds all static data for a single card.
     *
     * This is NOT a node. It is a Godot Resource (.tres file) that gets
     * created in the editor and assigned to a Card node via load_from_resource().
     *
     * Each card in the game (e.g. "Fire Drake", "Shadow Rune") will have its
     * own .tres file saved under resources/cards/ that holds its stats.
     *
     * Other classes that depend on this:
     * - Card (src/card/card.h) — displays this data visually
     * - HandManager (src/hand/hand_manager.h) — creates cards from this data
     */
    class CardData : public Resource
    {
        GDCLASS(CardData, Resource)

    public:
        /**
         * Rarity tier of the card.
         * Affects visual styling (border color, glow, etc.) in the Card node.
         */
        enum Rarity
        {
            COMMON,
            RARE,
            EPIC,
            LEGENDARY
        };

    private:
        String card_name;       // Display name of the card
        int cost;               // Mana/energy cost to play the card
        int power;              // Attack or effect power value
        Ref<Texture2D> texture; // Card artwork
        Rarity rarity;          // Rarity tier (affects visual styling)

    protected:
        static void _bind_methods();

    public:
        CardData();
        ~CardData();

        // Getters and Setters — exposed to Godot editor via _bind_methods()
        void set_card_name(const String &p_name);
        String get_card_name() const;

        void set_cost(int p_cost);
        int get_cost() const;

        void set_power(int p_power);
        int get_power() const;

        void set_texture(const Ref<Texture2D> &p_texture);
        Ref<Texture2D> get_texture() const;

        void set_rarity(Rarity p_rarity);
        Rarity get_rarity() const;
    };

} // namespace godot

VARIANT_ENUM_CAST(godot::CardData::Rarity);

#endif // CARD_DATA_H