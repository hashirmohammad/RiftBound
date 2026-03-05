class_name CardData
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var card_id: String = ""
@export var set_code: String = ""

@export var card_name: String = ""
@export var cost: int = 0

@export var might: int = 0

@export var domain: String = ""
@export var type: String = ""              # "Unit", "Spell", etc.
@export var keywords: Array[String] = []
@export var rules_text: String = ""

@export var rarity: Rarity = Rarity.COMMON

# Optional: later you can load this from image_url
@export var image_url: String = ""
@export var texture: Texture2D


static func rarity_from_string(s: String) -> Rarity:
	match s.strip_edges().to_lower():
		"common": return Rarity.COMMON
		"rare": return Rarity.RARE
		"epic": return Rarity.EPIC
		"legendary": return Rarity.LEGENDARY
		_: return Rarity.COMMON


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()

	c.card_id = str(d.get("card_id", ""))
	c.set_code = str(d.get("set_code", ""))

	c.card_name = str(d.get("name", d.get("card_name", "")))
	c.cost = int(d.get("cost", 0))
	c.might = int(d.get("might", d.get("power", 0)))

	c.domain = str(d.get("domain", ""))
	c.type = str(d.get("type", ""))

	# keywords could be missing or not an array
	var kw = d.get("keywords", [])
	if kw is Array:
		c.keywords = []
		for k in kw:
			c.keywords.append(str(k))

	c.rules_text = str(d.get("rules_text", ""))
	c.image_url = str(d.get("image_url", ""))

	c.rarity = rarity_from_string(str(d.get("rarity", "Common")))

	return c
