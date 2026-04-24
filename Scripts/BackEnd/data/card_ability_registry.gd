class_name CardAbilityRegistry

static var _registry: Dictionary = {}         # card_id -> { event -> Callable }
static var _vision_events: Dictionary = {}    # card_id -> trigger_event
static var _on_play: Dictionary = {}          # card_id -> Callable
static var _extra_unit_effects: Dictionary = {}  # card_id -> Callable
static var _loaded := false

# ── Public API ────────────────────────────────────────────────────────────────
static func get_on_play_fn(card_id: String) -> Callable:
	_ensure_loaded()
	return _on_play.get(card_id, Callable())

static func get_extra_unit_effects_fn(card_id: String) -> Callable:
	_ensure_loaded()
	return _extra_unit_effects.get(card_id, Callable())
	
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
	
	# OGN-044/298 — Clockwork Keeper
	# As you play me, you may pay Calm as an additional cost. If you do, draw 1.
	_on_play["OGN-044/298"] = func(unit: UnitState, state: GameState, payload := {}) -> void:
		var extra_paid: bool = bool(payload.get("extra_calm_paid", false))
		if not extra_paid:
			return

		EffectResolver.draw_cards(state, unit.player_id, 1)
		state.add_event("Clockwork Keeper extra cost paid: P%d drew 1." % unit.player_id)
	
	# OGN-075/298 — Tasty Faefolk
	# [Deathknell] — Channel 2 runes exhausted and draw 1. (When I die, get the effect.)
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

	# OGN-110/298 — Ekko, Recurrent
	# [Deathknell] — Recycle me to ready your runes. (When I die, get the effect.)
	_registry["OGN-110/298"] = {
		"on_death": func(unit: UnitState, state: GameState) -> void:
			# TODO: recycle card + ready all runes (requires recycle + rune awaken logic)
			state.add_event(
				"Ekko deathknell: P%d (recycle + ready runes: TODO)." % unit.player_id
			)
	}
	
	# OGN-136/298 — Pit Rookie
	# When you play me, buff another friendly unit. (If it doesn't have a buff, it gets a +1 Might buff.)
	_on_play["OGN-136/298"] = func(unit: UnitState, state: GameState, payload := {}) -> void:
		state.awaiting_unit_target = true
		state.pending_target_source_uid = unit.uid
		state.pending_target_card_id = unit.card_instance.data.card_id
		state.add_event("Pit Rookie: choose another friendly unit to buff.")
	
	# OGN-157/298 — Udyr, Wildman
	_extra_unit_effects["OGN-157/298"] = func(unit: UnitState, state: GameState) -> Array[EffectInstance]:
		var ability_fn := func(source: UnitState, context: CombatContext, game_state: GameState) -> void:
			if not source.effects.has_any(EffectInstance.EffectType.BUFF):
				game_state.add_event("Udyr cannot use ability: no buff to spend.")
				return

			game_state.awaiting_choice = true
			game_state.pending_choice_card_id = "OGN-157/298"
			game_state.pending_choice_source_uid = source.uid
			game_state.pending_choice_player_id = source.player_id
			game_state.pending_choice_step = "udyr_category"
			game_state.pending_choice_mode = ""
			game_state.add_event("Udyr: choose a mode category.")
			print("DEBUG Udyr ability used")
			print("DEBUG awaiting_choice=", game_state.awaiting_choice)
			print("DEBUG pending_choice_card_id=", game_state.pending_choice_card_id)
		return [
			EffectFactory.make_action_ability(state, unit.uid, ability_fn)
		]
	
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

static func resolve_pending_unit_target(target_uid: int, state: GameState) -> void:
	_ensure_loaded()

	if not state.awaiting_unit_target:
		state.add_event("No unit target is currently being selected.")
		return

	var source: UnitState = state.unit_registry.get_unit(state.pending_target_source_uid)
	var target: UnitState = state.unit_registry.get_unit(target_uid)

	if source == null:
		state.add_event("Target resolution failed: source unit not found.")
		_clear_pending_target_state(state)
		return

	if target == null:
		state.add_event("Target resolution failed: target unit not found.")
		_clear_pending_target_state(state)
		return

	match state.pending_target_card_id:
		"OGN-136/298":
			if target.player_id != source.player_id:
				state.add_event("Pit Rookie target must be friendly.")
				return
			if target.uid == source.uid:
				state.add_event("Pit Rookie must target another friendly unit.")
				return

			EffectResolver.buff_unit(state, source.uid, target, 1, EffectInstance.ExpiryTiming.PERMANENT)
			state.add_event("Pit Rookie buffed %s." % target.card_instance.data.card_name)
			print("DEBUG Pit Rookie target uid=", target.uid, " buff=", target.effects.max_of(EffectInstance.EffectType.BUFF))
		"UDYR_deal2":
			if target.player_id == source.player_id:
				state.add_event("Udyr must target an enemy unit.")
				return

			if not _is_unit_at_battlefield(target, state):
				state.add_event("Udyr target must be at a battlefield.")
				return

			EffectResolver.deal_damage_to_unit(state, source.uid, target, 2)
			state.add_event("Udyr dealt 2 to %s." % target.card_instance.data.card_name)


		"UDYR_stun":
			if target.player_id == source.player_id:
				state.add_event("Udyr must target an enemy unit.")
				return

			if not _is_unit_at_battlefield(target, state):
				state.add_event("Udyr target must be at a battlefield.")
				return

			EffectResolver.stun_unit(state, source.uid, target)
			state.add_event("Udyr stunned %s." % target.card_instance.data.card_name)
		_:
			state.add_event("Unknown pending target card: %s" % state.pending_target_card_id)

	_clear_pending_target_state(state)

static func _clear_pending_target_state(state: GameState) -> void:
	state.awaiting_unit_target = false
	state.pending_target_source_uid = -1
	state.pending_target_card_id = ""

static func _is_unit_at_battlefield(unit: UnitState, state: GameState) -> bool:
	var loc := EffectResolver.find_unit_location(state, unit.uid)
	return not loc.is_empty() and str(loc["zone"]) == "BATTLEFIELD"
