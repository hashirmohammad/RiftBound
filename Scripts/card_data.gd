class_name CardData
extends Resource

# ── Enums ────────────────────────────────────────────────────────────────────

enum Rarity   { COMMON, UNCOMMON, RARE, EPIC, OVERNUMBER }

## FIX: Added Domain enum — was missing, causing Tests.gd & card_database.gd to error
enum Rune   { NONE, FURY, CALM, BODY, MIND, ORDER, CHAOS }

## FIX: Added CardType enum — was missing, CardManager and Tests.gd referenced it
enum CardType { UNIT, SPELL, RUNE, CHAMPION, GEAR, BATTLEFIELD, LEGEND }

# ── Exported fields ───────────────────────────────────────────────────────────

@export var card_id:     String = ""
@export var set_code:    String = ""
@export var card_name:   String = ""
@export var cost:        int    = 0
@export var might:       int    = 0
@export var health:      int    = 0   ## FIX: added health so Card.gd Health label maps correctly

@export var rune:        int = 0   ## 0=NONE,1=FURY,2=CALM,3=BODY,4=MIND,5=ORDER,6=CHAOS
@export var type:        int = 0   ## 0=UNIT,1=SPELL,2=RUNE,3=CHAMPION

@export var keywords:    Array[String] = []
@export var rules_text:  String = ""
@export var rarity:      Rarity = Rarity.COMMON
@export var image_url:   String = ""
@export var texture:     Texture2D

# ── Static helpers ────────────────────────────────────────────────────────────

static func rarity_from_string(s: String) -> int:
	match s.strip_edges().to_lower():
		"common":    return Rarity.COMMON
		"rare":      return Rarity.RARE
		"epic":      return Rarity.EPIC
		"uncommon": return Rarity.UNCOMMON
		_:           return Rarity.COMMON

## FIX: new helper used by from_dict() and card_database.gd filtering
static func rune_from_string(s: String) -> int:
	match s.strip_edges().to_lower():
		"fury":     return Rune.FURY
		"body":    	return Rune.BODY
		"mind":  	return Rune.MIND
		"calm": 	return Rune.CALM
		"order":    return Rune.ORDER
		"chaos":	return Rune.CHAOS
		_:          return Rune.NONE

## FIX: new helper used by from_dict() and card_database.gd filtering
static func type_from_string(s: String) -> int:
	match s.strip_edges().to_lower():
		"unit":                      return CardType.UNIT
		"spell":                     return CardType.SPELL
		"rune", "basic rune":        return CardType.RUNE
		"champion", "champion unit": return CardType.CHAMPION
		"gear":                      return CardType.GEAR
		"battlefield":               return CardType.BATTLEFIELD
		"legend":                    return CardType.LEGEND
		_:                           return CardType.UNIT

static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.card_id   = str(d.get("card_id",  ""))
	c.set_code  = str(d.get("set_code", ""))
	c.card_name = str(d.get("name",     d.get("card_name", "")))
	c.cost      = int(d.get("cost",   0))
	c.might     = int(d.get("might",  d.get("power", 0)))
	c.health    = int(d.get("health", d.get("defense", 0)))

	## FIX: parse to enum values instead of storing raw strings
	c.rune    	= rune_from_string(str(d.get("domain", "")))
	c.type      = type_from_string(str(d.get("type", "")))

	var kw = d.get("keywords", [])
	if kw is Array:
		c.keywords = []
		for k in kw:
			c.keywords.append(str(k))

	c.rules_text = str(d.get("rules_text", ""))
	c.image_url  = str(d.get("image_url",  ""))
	c.rarity     = rarity_from_string(str(d.get("rarity", "Common")))
	return c
