extends Node
## CardDatabase — Autoload-friendly singleton for card data access.
##
## SETUP: Add to Project → Project Settings → Autoload as "CardDatabase"
## pointing to this file so Tests.gd and other scripts can call
## CardDatabase.get_all_cards() etc. without an instance.

# ── Constants ─────────────────────────────────────────────────────────────────

const CARDS_FOLDER := "res://Data/Cards"
const DECKS_FOLDER := "res://Data/decks"

# All 16 preset deck names — must match filenames in res://Data/decks/
const PRESET_DECKS: Array[String] = [
	"Ahri", "Annie", "Darius", "Garen", "Jinx",
	"Kai'Sa", "Lee Sin", "Leona", "Lux", "Master Yi",
	"Miss Fortune", "Sett", "Teemo", "Viktor", "Volibear", "Yasuo"
]

# ── Internal cache ────────────────────────────────────────────────────────────

## All cards indexed by card_id. Populated once on first access.
static var _all_cards: Dictionary = {}
static var _cache_built: bool = false

# ── Autoload entry-point ──────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_cache()

# ── Cache ─────────────────────────────────────────────────────────────────────

## Loads every JSON file from the flat Cards folder into _all_cards (once).
func _ensure_cache() -> void:
	if _cache_built:
		return
	_cache_built = true

	var dir := DirAccess.open(CARDS_FOLDER)
	if dir == null:
		push_error("CardDatabase: Could not open Cards folder at '%s'" % CARDS_FOLDER)
		return

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if not file_name.ends_with(".json"):
			continue
		var full_path := CARDS_FOLDER.path_join(file_name)
		var dict := _load_json_file_as_dictionary(full_path)
		if dict.is_empty():
			continue
		var card := CardData.from_dict(dict)
		if card.card_id != "":
			_all_cards[card.card_id] = card
	dir.list_dir_end()

# ── Preset Deck API ───────────────────────────────────────────────────────────

## Returns a random deck name from the 16 presets.
func _random_deck_name() -> String:
	return PRESET_DECKS[randi() % PRESET_DECKS.size()]

## Loads the raw deck JSON for a given deck name.
func _load_deck_json(deck_name: String) -> Dictionary:
	var path := "%s/%s.json" % [DECKS_FOLDER, deck_name]
	var result := _load_json_file_as_dictionary(path)
	if result.is_empty():
		push_error("CardDatabase: Could not load deck JSON for '%s'" % deck_name)
	return result

## Returns an Array[CardData] of the draw deck cards for a preset deck.
## Expands each entry by its "count" field. Excludes runes and champion.
func _load_cards_from_deck(deck_name: String) -> Array[CardData]:
	_ensure_cache()
	var deck_json := _load_deck_json(deck_name)
	if deck_json.is_empty():
		return []

	var result: Array[CardData] = []
	for entry in deck_json.get("cards", []):
		var card_id := str(entry.get("card_id", ""))
		var count := int(entry.get("count", 1))
		if card_id == "":
			continue
		if not _all_cards.has(card_id):
			push_warning("CardDatabase: card_id '%s' not found in Cards folder (deck: %s)" % [card_id, deck_name])
			continue
		for i in range(count):
			result.append(_all_cards[card_id])
	return result

## Returns an Array[CardData] of the rune deck cards for a preset deck.
## Expands each entry by its "count" field.
func _load_runes_from_deck(deck_name: String) -> Array[CardData]:
	_ensure_cache()
	var deck_json := _load_deck_json(deck_name)
	if deck_json.is_empty():
		return []

	var result: Array[CardData] = []
	for entry in deck_json.get("runes", []):
		var card_id := str(entry.get("card_id", ""))
		var count := int(entry.get("count", 1))
		if card_id == "":
			continue
		if not _all_cards.has(card_id):
			push_warning("CardDatabase: rune card_id '%s' not found in Cards folder (deck: %s)" % [card_id, deck_name])
			continue
		for i in range(count):
			result.append(_all_cards[card_id])
	return result

## Returns an Array[CardData] of the battlefields for a preset deck.
func _load_battlefields_from_deck(deck_name: String) -> Array[CardData]:
	_ensure_cache()
	var deck_json := _load_deck_json(deck_name)
	if deck_json.is_empty():
		return []

	var result: Array[CardData] = []
	for entry in deck_json.get("battlefields", []):
		var card_id := str(entry.get("card_id", ""))
		if card_id == "":
			continue
		if not _all_cards.has(card_id):
			push_warning("CardDatabase: battlefield card_id '%s' not found in Cards folder (deck: %s)" % [card_id, deck_name])
			continue
		result.append(_all_cards[card_id])
	return result

## Returns the legend CardData for a preset deck.
func _load_legend(deck_name: String) -> CardData:
	_ensure_cache()
	var deck_json := _load_deck_json(deck_name)
	if deck_json.is_empty():
		return null

	var legend_id := str(deck_json.get("legend_card", ""))
	if legend_id == "":
		push_warning("CardDatabase: no legend_card in deck '%s'" % deck_name)
		return null
	if not _all_cards.has(legend_id):
		push_warning("CardDatabase: legend card_id '%s' not found in Cards folder (deck: %s)" % [legend_id, deck_name])
		return null
	return _all_cards[legend_id]

# ── Low-level helpers ─────────────────────────────────────────────────────────

func _load_json_file_as_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: Failed to open '%s'" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("CardDatabase: Failed to parse JSON at '%s'" % path)
		return {}
	return parsed

func _find_path(id: String) -> String:
	var card_id = id.replace("/", "")
	var path = "res://Data/Cards/"
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.begins_with(card_id):
				dir.list_dir_end()
				return path.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""
