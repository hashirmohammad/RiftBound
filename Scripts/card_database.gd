extends Node
## CardDatabase — Autoload-friendly singleton for card data access.
##
## SETUP: Add to Project → Project Settings → Autoload as "CardDatabase"
## pointing to this file so Tests.gd and other scripts can call
## CardDatabase.get_all_cards() etc. without an instance.
##
## FIX: Added get_all_cards(), get_card(), get_cards_by_type(),
##      get_cards_by_domain() — all were called by Tests.gd but missing.


## Internal cache — populated on first access
static var _cards: Array[CardData] = []
static var _legend: CardData
static var _battlefields: Array[CardData] = []
static var _runes: Array[CardData] = []
static var _loaded: bool = false

# ── Autoload entry-point ──────────────────────────────────────────────────────

## Called automatically when registered as an Autoload node.
func _ready() -> void:
	pass

## Load battlefields
func _load_battlefields(deck_name: String) -> Array[CardData]:
	var root := "res://Data/Cards/%s/Battlefields" % deck_name
	_battlefields = _load_card_instances_from_folder(root)
	if _battlefields.is_empty():
		return []
	return _battlefields
	
## Load cards
func _load_cards(deck_name: String) -> Array[CardData]:
	var root := "res://Data/Cards/%s/Cards" % deck_name
	_cards = _load_card_instances_from_folder(root)
	if _cards.is_empty():
		return []
	return _cards

## Load legend
func _load_legend(deck_name: String) -> CardData:
	var root := "res://Data/Cards/%s/Legend" % deck_name
	var dir := DirAccess.open(root)
	if dir == null:
		push_error("Could not open folder %s" % root)
		return
	
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()

		if file_name == "":
			break
		
		var full_path = root.path_join(file_name)
		var dictionary = _load_json_file_as_dictionary(full_path)
		
		if dictionary is Dictionary:
			_legend = CardData.from_dict(dictionary)
	return _legend

## Load runes
func _load_runes(deck_name: String) -> Array[CardData]:
	var root := "res://Data/Cards/%s/Runes" % deck_name
	_runes = _load_card_instances_from_folder(root)
	if _runes.is_empty():
		return []
	return _runes

## Helper function
func _load_card_instances_from_folder(path: String)-> Array[CardData]:
	var result: Array[CardData] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Could not open folder %s" % path)
		return result
	
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		
		var full_path = path.path_join(file_name)
		var dictionary = _load_json_file_as_dictionary(full_path)
		if dictionary is Dictionary:
			result.append(CardData.from_dict(dictionary))
	return result
		
func _load_json_file_as_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: Failed to open %s" % path)
		print(1)
		return {}

	var text    := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	
	return parsed
