Epic: Backend: Data & Database
Story: [Backend] 
Branch: scripts/card/card_database.gd
Status: ✅ Complete

###Goal
The goal of this script is to provide a single, globally accessible source of truth for all card data in the game.
It loads cards.json once on startup, caches the result, and exposes a clean static API so any script can query 
cards by ID, type, or domain without re-reading the file or passing references around.

###What Was Built
-Autoload Singleton
CardDatabase is designed to be registered under Project → Project Settings → Autoload. Once registered, 
any script can call CardDatabase.get_all_cards() etc. directly — no instance or get_node() needed.

-Lazy Loading
_ensure_loaded() is called at the top of every public method. The JSON file is only read once; after that,
all calls return from the in-memory _cards cache. This keeps startup fast and avoids repeated disk reads.

-JSON Loader
load_cards_from_json() is a low-level static method that opens the JSON file, parses it as an Array, 
and converts each Dictionary entry into a CardData resource via CardData.from_dict(). It pushes descriptive
errors if the file is missing or malformed.

###File Structure
scripts/
└── card/
	└── card_database.gd      # CardDatabase singleton (this file)
Data/
└── cards.json                # Card data source — Array of card objects

###How to Test
Step 1 — Verify autoload:

Confirm CardDatabase is listed in Project → Project Settings → Autoload
Run the project

Step 2 — Query a specific card:

In any script, call CardDatabase.get_card("OGN-001/298")


###Important Notes for the Team
The JSON root must be an Array — a Dictionary root will cause a parse error and return an empty database
get_card() returns the first match by card ID — card IDs in cards.json should be unique to avoid 
unexpected results
