class_name CardAbilityRegistry

# Stores card-specific ability functions that cannot be expressed generically.
# Covers DEATHKNELL trigger_fns and VISION trigger_fns.
#
# All trigger callables share the same signature:
#   func(source_unit: UnitState, game_state: GameState) -> void
#
# Add new entries to _populate() as cards are implemented.
# Cards not yet implemented log a warning and no-op safely.

static var _registry: Dictionary = {}       # card_id -> { event -> Callable }
static var _vision_events: Dictionary = {}  # card_id -> trigger_event string
static var _loaded: bool = false

# ── Public API ────────────────────────────────────────────────────────────────

static func get_trigger_fn(card_id: String, event: String) -> Callable:
	_ensure_loaded()
	if _registry.has(card_id) and _registry[card_id].has(event):
		return _registry[card_id][event]
	push_warning(
		"CardAbilityRegistry: no '%s' trigger for card '%s' — ability is a no-op." \
		% [event, card_id]
	)
	return Callable()

# Returns the trigger_event string registered for a VISION effect on this card.
static func get_vision_event(card_id: String) -> String:
	_ensure_loaded()
	return _vision_events.get(card_id, "")

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
