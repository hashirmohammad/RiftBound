Epic: Backend: Data & Database
Story: [Backend]
Branch: scripts/card/card_data.gd
Status: ✅ Complete

###Goal
The goal of this resource is to define the data structure for every card in the game.
It declares all exported fields (name, cost, stats, type, domain, rarity, image URL), 
the shared enums used across the codebase, and a static from_dict() factory so JSON 
entries from cards.json can be converted into typed CardData resources cleanly.

###What Was Built
Enums
Three enums are defined here and used across the entire project:

-Rarity — COMMON, RARE, EPIC, LEGENDARY
-Domain — NONE, FURY, GRACE, CUNNING, DOMINION, WILD
-CardType — UNIT, SPELL, RUNE, CHAMPION

Exported Fields
All card properties are @export-annotated so they can be edited in the Godot Inspector and used in .tres resource files:

-Identity: card_id, set_code, card_name
-Stats: cost, might, health
-Classification: domain, type, rarity
-Content: keywords, rules_text, image_url, texture

Static Helpers

-rarity_from_string() — converts a rarity string from JSON to the enum value
-domain_from_string() — converts a domain string (e.g. "fury") to Domain enum
-type_from_string() — converts a type string (e.g. "unit") to CardType enum
-from_dict() — takes a raw JSON Dictionary and returns a fully populated CardData instance, 
-handling alternate key names (e.g. "power" → might, "defense" → health)

###File Structure
scripts/
└── card/
	└── card_data.gd          # CardData resource definition (this file)
Data/
└── cards.json                # Source JSON — one object per card

###How to Test
Step 1 — Verify JSON parsing:

Run the project and open the Output panel
CardDatabase._ready() will call load_cards_from_json() on startup

Expected result: No parse errors in the Output panel and CardDatabase.get_all_cards().size() 
returns the correct card count.

###Important Notes for the Team
domain and type are stored as int (not the enum type directly) to stay compatible with @export
and JSON parsing — always use the enum constants (e.g. CardData.Domain.FURY) when comparing, never raw integers
