#ifndef CARD_H
#define CARD_H

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/tween.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "card_data.h"

namespace godot
{

    /**
     * Card — The visual node that represents a single card on screen.
     *
     * Inherits from Control so it can:
     *   - Receive mouse input via _gui_input()
     *   - Be positioned freely during drag (set_as_top_level)
     *   - Participate in Godot's UI layout system
     *
     * This class is purely visual and interactive — it holds no game logic.
     * All card stat data lives in CardData (card_data.h).
     *
     * State machine:
     *   IN_HAND    → card is sitting in the player's hand container
     *   DRAGGING   → card is following the mouse cursor
     *   ON_BOARD   → card has been placed on a valid board tile
     *   RETURNING  → card is sliding back to hand after an invalid drop
     *
     * Dependencies:
     *   - CardData (card_data.h) — provides stat data
     *   - HandManager (task 2) — manages card layout in hand
     *   - BoardManager (task 4) — handles drop zone detection
     */
    class Card : public Control
    {
        GDCLASS(Card, Control)

    public:
        /**
         * Tracks what the card is currently doing.
         * Used by HandManager, BoardManager, and mouse input logic.
         */
        enum CardState
        {
            IN_HAND,  // Sitting in the hand container
            DRAGGING, // Following the mouse cursor
            ON_BOARD, // Placed on a valid board tile
            RETURNING // Animating back to hand after invalid drop
        };

    private:
        Ref<CardData> card_data; // The data resource powering this card
        CardState current_state; // Current state of the card

    protected:
        static void _bind_methods();

    public:
        Card();
        ~Card();

        /**
         * Populates the card visuals from a CardData resource.
         * Called by HandManager when dealing cards to the player.
         *
         * @param data — A CardData .tres resource loaded from resources/cards/
         */
        void load_from_resource(const Ref<CardData> &data);

        // State management
        void set_card_state(CardState p_state);
        CardState get_card_state() const;

        // Data access
        Ref<CardData> get_card_data() const;

        /**
         * Stub for mouse input — fully implemented in Task 3.
         * Detects clicks, hover, and releases on this card.
         */
        void _gui_input(const Ref<InputEvent> &event) override;

        /**
         * Called every frame by Godot.
         * Used in Task 3 to make the card follow the mouse while DRAGGING.
         */
        void _process(double delta) override;
    };

} // namespace godot

VARIANT_ENUM_CAST(godot::Card::CardState);

#endif // CARD_H