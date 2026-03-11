Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/card/card_slot.gd
Status: ✅ Complete

###Goal
The goal of this script is to represent a single placement slot on the board. 
Each slot knows its type (Unit, Spell, Rune, or Champion), whether it is currently occupied, 
and how to visually signal to the player whether it is a valid drop target during a drag.

##What Was Built
-Slot Type
An @export_enum field card_slot_type lets each slot be assigned its type directly in the Godot Inspector 
without touching code. The four types map to the CardType values defined in CardData.
-Occupied State
card_in_slot is a simple boolean flag. CardManager sets it to true when a card is successfully dropped 
and reads it to prevent double-filling a slot.

###File Structure
scripts/
└── card/
	└── card_slot.gd          # CardSlot logic (this file)
scenes/
└── board/
	└── CardSlots/            # Container node holding all CardSlot instances
		└── cardSlot.tscn            # Individual slot scenes

###How to Test
Step 1 — Drag a card over a slot:

Run the board scene and begin dragging a card

Expected result: Occupied slots show no highlight you can drag and drop you card to an empty slot

###Important Notes for the Team
card_in_slot is never automatically reset to false — future card removal logic will need to 
explicitly clear this flag when a card leaves a slot
