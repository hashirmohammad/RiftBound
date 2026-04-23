class_name CardAbilityRegistry

static var _registry: Dictionary = {}         # card_id -> { event -> Callable }
static var _vision_events: Dictionary = {}    # card_id -> trigger_event
static var _on_play: Dictionary = {}          # card_id -> Callable
static var _extra_unit_effects: Dictionary = {}  # card_id -> Callable
static var _loaded := false

# ── Public API ────────────────────────────────────────────────────────────────

static func get_trigger_fn(card_id: String, event: String) -> Callable:
	_ensure_loaded()
	if _registry.has(card_id) and _registry[card_id].has(event):
		return _registry[card_id][event]
	return Callable()

static func get_vision_event(card_id: String) -> String:
	_ensure_loaded()
	return _vision_events.get(card_id, "")

static func get_on_play_fn(card_id: String) -> Callable:
	_ensure_loaded()
	return _on_play.get(card_id, Callable())

static func get_extra_unit_effects_fn(card_id: String) -> Callable:
	_ensure_loaded()
	return _extra_unit_effects.get(card_id, Callable())

# ── Init ──────────────────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_populate()

# ── Ability definitions ───────────────────────────────────────────────────────
# Each entry is: _registry["card_id"] = { "event_name": Callable }
# Complex effects that aren't yet fully supported are stubbed with a TODO log.

static func _populate() -> void:
	
	# OGN-075/298 — Tasty Faefolk
	# [Deathknell] — Channel 2 runes exhausted and draw 1.
	_registry["OGN-075/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			EffectResolver.resolve_tasty_faefolk_deathknell(unit, state)
	}
	
	# OGN-096/298 — Watchful Sentry
	# [Deathknell] — Draw 1. (When I die, get the effect.)
	_registry["OGN-096/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			_draw_cards(unit.player_id, 1, state)
			state.add_event("Watchful Sentry deathknell: P%d drew 1." % unit.player_id)
	}

	# OGN-075/298 — Tasty Faefolk
	# [Deathknell] — Channel 2 runes exhausted and draw 1. (When I die, get the effect.)
	_registry["OGN-075/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			# TODO: channel 2 runes exhausted (requires rune channel logic)
			_draw_cards(unit.player_id, 1, state)
			state.add_event(
				"Tasty Faefolk deathknell: P%d drew 1 (channel runes: TODO)." % unit.player_id
			)
	}

	# OGN-110/298 — Ekko, Recurrent
	# [Deathknell] — Recycle me to ready your runes. (When I die, get the effect.)
	_registry["OGN-110/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			# TODO: recycle card + ready all runes (requires recycle + rune awaken logic)
			state.add_event(
				"Ekko deathknell: P%d (recycle + ready runes: TODO)." % unit.player_id
			)
	}

	# OGN-178/298 — Undercover Agent
	# [Deathknell] — Discard 2, then draw 2. (When I die, get the effect.)
	_registry["OGN-178/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			# TODO: discard 2 (requires player choice / discard logic)
			_draw_cards(unit.player_id, 2, state)
			state.add_event(
				"Undercover Agent deathknell: P%d drew 2 (discard 2: TODO)." % unit.player_id
			)
	}

# ── Shared helpers ────────────────────────────────────────────────────────────

static func _draw_cards(player_id: int, count: int, state: GameState) -> void:
	var player: PlayerState = state.players[player_id]
	for i in range(count):
		if player.deck.is_empty():
			state.add_event("P%d deck empty — cannot draw." % player_id)
			return
		var card: CardInstance = player.deck.pop_back()
		player.hand.append(card)
		card.zone = CardInstance.Zone.HAND
