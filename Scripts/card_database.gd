class_name CardDatabase
extends RefCounted

static func load_cards_from_json(path: String = "res://Data/cards.json") -> Array[CardData]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: Failed to open %s" % path)
		return []

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or !(parsed is Array):
		push_error("CardDatabase: JSON root must be an Array in %s" % path)
		return []

	var result: Array[CardData] = []
	for entry in parsed:
		if entry is Dictionary:
			result.append(CardData.from_dict(entry))

	return result
