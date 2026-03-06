extends Node
## CardDatabase — Autoload-friendly singleton for card data access.
##
## SETUP: Add to Project → Project Settings → Autoload as "CardDatabase"
## pointing to this file so Tests.gd and other scripts can call
## CardDatabase.get_all_cards() etc. without an instance.
##
## FIX: Added get_all_cards(), get_card(), get_cards_by_type(),
##      get_cards_by_domain() — all were called by Tests.gd but missing.

const DATA_PATH := "res://Data/cards.json"

## Internal cache — populated on first access
static var _cards: Array[CardData] = []
static var _loaded: bool = false

# ── Autoload entry-point ──────────────────────────────────────────────────────

## Called automatically when registered as an Autoload node.
func _ready() -> void:
	_ensure_loaded()

# ── Private helpers ───────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_cards = load_cards_from_json(DATA_PATH)
	_loaded = true

# ── Public API ────────────────────────────────────────────────────────────────

## Returns every card in the database.
static func get_all_cards() -> Array[CardData]:
	_ensure_loaded()
	return _cards

## Returns the first card matching card_id, or null.
## FIX: was missing — Tests.gd calls CardDatabase.get_card("OGN-001/298")
static func get_card(card_id: String) -> CardData:
	_ensure_loaded()
	for c in _cards:
		if c.card_id == card_id:
			return c
	return null

## Returns all cards whose type matches the given CardData.CardType enum value.
## FIX: was missing — Tests.gd calls CardDatabase.get_cards_by_type(CardData.CardType.UNIT)
static func get_cards_by_type(type: int) -> Array[CardData]:
	_ensure_loaded()
	var result: Array[CardData] = []
	for c in _cards:
		if c.type == type:
			result.append(c)
	return result

## Returns all cards whose domain matches the given CardData.Domain enum value.
## FIX: was missing — Tests.gd calls CardDatabase.get_cards_by_domain(CardData.Domain.FURY)
static func get_cards_by_domain(domain: int) -> Array[CardData]:
	_ensure_loaded()
	var result: Array[CardData] = []
	for c in _cards:
		if c.domain == domain:
			result.append(c)
	return result

## Low-level JSON loader. Prefer the static methods above for gameplay code.
static func load_cards_from_json(path: String = DATA_PATH) -> Array[CardData]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: Failed to open %s" % path)
		return []

	var text    := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Array):
		push_error("CardDatabase: JSON root must be an Array in %s" % path)
		return []

	var result: Array[CardData] = []
	for entry in parsed:
		if entry is Dictionary:
			result.append(CardData.from_dict(entry))
	return result
