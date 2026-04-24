class_name BattlefieldAbilityRegistry

static var _triggers: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_register_all()


static func get_trigger_fn(card_id: String, event_name: String) -> Callable:
	_ensure_loaded()

	if _triggers.has(card_id) and _triggers[card_id].has(event_name):
		return _triggers[card_id][event_name]

	return Callable()


static func trigger(
	state: GameState,
	battlefield: BattlefieldInstance,
	event_name: String,
	player_id: int
) -> void:
	if battlefield == null:
		return

	if battlefield.battlefield == null:
		return

	var card_id := battlefield.battlefield.card_id
	var fn := get_trigger_fn(card_id, event_name)

	if fn.is_valid():
		fn.call(state, player_id, battlefield)


static func trigger_all_picked(
	state: GameState,
	event_name: String,
	player_id: int
) -> void:
	var seen := {}

	for p in state.players:
		if p.picked_battlefield == null:
			continue

		var bf: BattlefieldInstance = p.picked_battlefield
		if seen.has(bf.uid):
			continue

		seen[bf.uid] = true
		trigger(state, bf, event_name, player_id)


static func _register_all() -> void:
	_register_grove_of_the_god_willow()
	_register_monastery_of_hirana()
	_register_obelisk_of_power()
	
static func _register_grove_of_the_god_willow() -> void:
	_triggers["OGN-280/298"] = {
		BattlefieldEvents.ON_HOLD: func(
			state: GameState,
			player_id: int,
			battlefield: BattlefieldInstance
		) -> void:
			EffectResolver.draw_cards(state, player_id, 1)
			state.add_event("Grove of the God-Willow: P%d drew 1." % player_id)
	}

static func _register_monastery_of_hirana() -> void:
	_triggers["OGN-282/298"] = {
		BattlefieldEvents.ON_CONQUER: func(
			state: GameState,
			player_id: int,
			battlefield: BattlefieldInstance
		) -> void:
			var unit := EffectResolver.find_first_buffed_friendly_unit(state, player_id)

			if unit == null:
				state.add_event("Monastery of Hirana: P%d has no buff to spend." % player_id)
				return

			EffectResolver.spend_one_buff(state, unit)
			EffectResolver.draw_cards(state, player_id, 1)

			state.add_event("Monastery of Hirana: P%d spent a buff and drew 1." % player_id)
	}

static func _register_obelisk_of_power() -> void:
	_triggers["OGN-284/298"] = {
		BattlefieldEvents.ON_BEGINNING_PHASE: func(
			state: GameState,
			player_id: int,
			battlefield: BattlefieldInstance
		) -> void:
			var flag_key := "obelisk_first_beginning_p%d" % player_id

			if state.battlefield_flags.get(flag_key, false):
				return

			state.battlefield_flags[flag_key] = true

			var player: PlayerState = state.players[player_id]
			player.channel_runes(1)

			state.add_event("Obelisk of Power: P%d channeled 1 rune." % player_id)
	}
