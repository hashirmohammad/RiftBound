class_name KeywordParser

# Parses a UNIT or CHAMPION card's rules_text and produces a list of
# EffectInstance objects representing the card's static, intrinsic effects.
#
# Only self-property keywords are extracted — those that describe what THIS
# unit permanently has while it is on the board. References to keywords in
# other units' text (e.g. "your [Mighty] units") are ignored.
#
# Self-property detection rule:
#   A keyword at position 0 in rules_text, or a keyword that immediately
#   follows a closing ')' (with optional '_' formatting characters between),
#   is treated as a self-property. All other keyword mentions are references.
#
# Example — Volibear, Imposing:
#   rules_text = "[Shield 3] (+3 Might while I'm a defender.)[Tank] (...)"
#   → SHIELD value=3, TANK flag — both self-properties
#
# Example — Taric, Protector:
#   rules_text = "[Shield] (...)[Tank] (...)Other friendly units here have [Shield]."
#   → SHIELD, TANK — self-properties
#   → last [Shield] is a reference (preceded by space) — ignored
#
# Keywords NOT parsed here (handled elsewhere or future systems):
#   [Accelerate]  — cost modifier, not a unit effect
#   [Action]      — timing tag on Spell cards; Spell cards never create UnitState
#   [Reaction]    — timing tag on Spell cards
#   [Temporary]   — applied by spells/abilities, not a static self-property
#   [Mighty]      — game-state reference ("a unit IS Mighty if it has 5+ Might")
#   [Legion]      — conditional trigger for effects; not a static Might bonus
#   [Hidden]      — zone state managed outside the effect system

static func parse(data: CardData, game_state: GameState) -> Array[EffectInstance]:
	var result: Array[EffectInstance] = []

	var regex := RegEx.new()
	# Matches [KeywordName] or [KeywordName N] where N is a positive integer
	regex.compile("\\[([A-Za-z]+)(?:\\s+(\\d+))?\\]")

	for m in regex.search_all(data.rules_text):
		if not _is_self_property(data.rules_text, m.get_start()):
			continue

		var keyword: String = m.get_string(1).to_lower()
		var value_str: String = m.get_string(2)
		var value: int = int(value_str) if value_str != "" else 1

		var effect: EffectInstance = _make_effect(keyword, value, data, game_state)
		if effect != null:
			result.append(effect)

	return result

# ── Self-property detection ───────────────────────────────────────────────────

static func _is_self_property(text: String, pos: int) -> bool:
	if pos == 0:
		return true
	# Walk backwards past any '_' formatting characters
	var i: int = pos - 1
	while i >= 0 and text[i] == "_":
		i -= 1
	# Self-property if the preceding non-underscore char closes a parenthetical
	return i >= 0 and text[i] == ")"

# ── Effect construction ───────────────────────────────────────────────────────

static func _make_effect(
		keyword: String,
		value: int,
		data: CardData,
		game_state: GameState) -> EffectInstance:

	var e := EffectInstance.new()
	e.uid = game_state.next_uid()
	e.source_uid = -1  # intrinsic to the card; no external source
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT

	match keyword:
		"assault":
			e.effect_type = EffectInstance.EffectType.ASSAULT
			e.value = value

		"shield":
			e.effect_type = EffectInstance.EffectType.SHIELD
			e.value = value

		"deflect":
			e.effect_type = EffectInstance.EffectType.DEFLECT
			e.value = value

		"tank":
			e.effect_type = EffectInstance.EffectType.TANK
			e.value = 0  # flag; presence checked via has_any(), value unused

		"ganking":
			e.effect_type = EffectInstance.EffectType.GANKING
			e.value = 0  # flag

		"deathknell":
			e.effect_type = EffectInstance.EffectType.DEATHKNELL
			e.trigger_event = "on_death"
			e.trigger_fn = CardAbilityRegistry.get_trigger_fn(data.card_id, "on_death")

		"vision":
			e.effect_type = EffectInstance.EffectType.VISION
			e.trigger_event = CardAbilityRegistry.get_vision_event(data.card_id)
			e.trigger_fn = CardAbilityRegistry.get_trigger_fn(data.card_id, e.trigger_event)

		_:
			return null  # not a unit-level static effect; skip silently

	return e
