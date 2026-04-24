class_name SpellRegistry

static var _resolvers: Dictionary = {}
static var _loaded := false

static func get_resolver(card_id: String) -> Callable:
	_ensure_loaded()
	return _resolvers.get(card_id, Callable())


static func requires_targets(card_id: String) -> bool:
	_ensure_loaded()
	return required_target_count(card_id) > 0


static func required_target_count(card_id: String) -> int:
	_ensure_loaded()

	match card_id:
		"OGN-058/298": # Discipline
			return 1
		"OGN-046/298": # En Garde
			return 1
		"OGN-128/298": # Challenge
			return 2
		"OGN-043/298": # Charm
			return 1
		"OGN-258/298": # Dragon's Rage
			return 2
		"OGN-045/298": # Defy
			return 0
		_:
			return 0


static func can_select_target(
	card_id: String,
	state: GameState,
	caster_player_id: int,
	current_targets: Array[int],
	target_uid: int
) -> bool:
	_ensure_loaded()

	var target: UnitState = state.unit_registry.get_unit(target_uid)
	if target == null:
		return false

	if current_targets.has(target_uid):
		return false

	match card_id:
		"OGN-058/298": # Discipline -> any unit
			return true

		"OGN-046/298": # En Garde -> friendly unit only
			return target.player_id == caster_player_id

		"OGN-128/298": # Challenge -> first friendly, second enemy
			if current_targets.size() == 0:
				return target.player_id == caster_player_id
			elif current_targets.size() == 1:
				return target.player_id != caster_player_id
			return false
		
		"OGN-043/298": # Charm -> enemy unit
			return target.player_id != caster_player_id
		
		"OGN-258/298": # first enemy to move, second enemy at destination
			return target.player_id != caster_player_id
		
		_:
			return false


static func resolve(card: CardInstance, state: GameState, payload := {}) -> void:
	_ensure_loaded()

	var resolver: Callable = _resolvers.get(card.data.card_id, Callable())
	if not resolver.is_valid():
		state.add_event("No spell resolver found for %s." % card.data.card_name)
		return

	resolver.call(card, state, payload)
	
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_populate()


static func _populate() -> void:
	# OGN-043/298 — Charm
	_resolvers["OGN-043/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = payload.get("player_id", state.get_active_player().id)
		var target_uid: int = payload.get("target_uid", -1)

		var target: UnitState = state.unit_registry.get_unit(target_uid)
		if target == null:
			state.add_event("Charm failed: target not found.")
			return

		if target.player_id == player_id:
			state.add_event("Charm failed: target must be enemy.")
			return

		var destination_zone: String = payload.get("destination_zone", "BATTLEFIELD")
		var destination_player_id: int = payload.get("destination_player_id", target.player_id)
		var destination_index: int = payload.get("destination_index", payload.get("destination_lane", -1))

		if destination_index == -1:
			state.add_event("Charm failed: no destination chosen.")
			return

		var ok := EffectResolver.move_unit_to_location(
			state,
			target,
			destination_player_id,
			destination_zone,
			destination_index
		)

		if ok:
			state.add_event("Charm resolved on %s." % target.card_instance.data.card_name)
	
	# OGN-045/298 — Defy
	_resolvers["OGN-045/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var countered: bool = false

		if state.timing_manager != null:
			countered = state.timing_manager.counter_top_spell_with_limit(4)

		if countered:
			state.add_event("Defy countered a spell.")
		else:
			state.add_event("Defy found no valid spell to counter.")
	
	# OGN-047/298 — Find Your Center
	_resolvers["OGN-047/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = payload.get("player_id", state.get_active_player().id)
		EffectResolver.draw_cards(state, player_id, 1)
		EffectResolver.channel_runes_exhausted(state, player_id, 1)
		state.add_event("Find Your Center resolved for P%d." % player_id)

	# OGN-058/298 — Discipline
	_resolvers["OGN-058/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = payload.get("player_id", state.get_active_player().id)
		var target_uid: int = payload.get("target_uid", -1)
		var target: UnitState = state.unit_registry.get_unit(target_uid)
		if target == null:
			state.add_event("Discipline failed: target not found.")
			return

		EffectResolver.buff_unit(
			state,
			card.uid,
			target,
			2,
			EffectInstance.ExpiryTiming.END_OF_TURN
		)
		EffectResolver.draw_cards(state, player_id, 1)
		state.add_event("Discipline resolved on %s." % target.card_instance.data.card_name)

	# OGN-046/298 — En Garde
	_resolvers["OGN-046/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = payload.get("player_id", state.get_active_player().id)
		var target_uid: int = payload.get("target_uid", -1)
		var target: UnitState = state.unit_registry.get_unit(target_uid)
		if target == null:
			state.add_event("En Garde failed: target not found.")
			return

		if target.player_id != player_id:
			state.add_event("En Garde failed: target must be friendly.")
			return

		EffectResolver.buff_unit(
			state,
			card.uid,
			target,
			1,
			EffectInstance.ExpiryTiming.END_OF_TURN
		)

		if state.unit_registry.count_friendly_units_at_same_location(target, state) == 1:
			EffectResolver.buff_unit(
				state,
				card.uid,
				target,
				1,
				EffectInstance.ExpiryTiming.END_OF_TURN
			)

		state.add_event("En Garde resolved on %s." % target.card_instance.data.card_name)

	# OGN-128/298 — Challenge
	_resolvers["OGN-128/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var friendly_uid: int = payload.get("friendly_uid", -1)
		var enemy_uid: int = payload.get("enemy_uid", -1)

		var friendly: UnitState = state.unit_registry.get_unit(friendly_uid)
		var enemy: UnitState = state.unit_registry.get_unit(enemy_uid)

		if friendly == null or enemy == null:
			state.add_event("Challenge failed: target missing.")
			return

		if friendly.player_id == enemy.player_id:
			state.add_event("Challenge failed: must target friendly then enemy.")
			return

		EffectResolver.units_strike_each_other(state, friendly, enemy)
		state.add_event("Challenge resolved.")
	
	# OGN-258/298 — Dragon's Rage
	_resolvers["OGN-258/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = payload.get("player_id", state.get_active_player().id)

		var moved_uid: int = payload.get("moved_uid", -1)
		var other_uid: int = payload.get("other_uid", -1)

		if payload.has("target_uids"):
			var target_uids: Array = payload["target_uids"]
			if target_uids.size() >= 2:
				moved_uid = int(target_uids[0])
				other_uid = int(target_uids[1])

		var moved_unit: UnitState = state.unit_registry.get_unit(moved_uid)
		var other_unit: UnitState = state.unit_registry.get_unit(other_uid)

		if moved_unit == null or other_unit == null:
			state.add_event("Dragon's Rage failed: target missing.")
			return

		if moved_unit.player_id == player_id or other_unit.player_id == player_id:
			state.add_event("Dragon's Rage failed: both targets must be enemies.")
			return

		if moved_unit.player_id != other_unit.player_id:
			state.add_event("Dragon's Rage failed: targets must belong to same opponent.")
			return

		var other_loc := EffectResolver.find_unit_location(state, other_unit.uid)
		if other_loc.is_empty():
			state.add_event("Dragon's Rage failed: second target location missing.")
			return

		var destination_zone: String = str(other_loc["zone"])
		var destination_player_id: int = int(other_loc["player_id"])
		var destination_index: int = int(other_loc["index"])

		var ok := EffectResolver.move_unit_to_location(
			state,
			moved_unit,
			destination_player_id,
			destination_zone,
			destination_index
		)

		if not ok:
			return

		EffectResolver.units_strike_each_other(state, moved_unit, other_unit)
		state.add_event("Dragon's Rage resolved.")
