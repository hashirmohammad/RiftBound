class_name LegendAbilityRegistry

static var _abilities: Dictionary = {}
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_register_all()


static func has_ability(card_id: String) -> bool:
	_ensure_loaded()
	return _abilities.has(card_id)


static func can_use(state: GameState, player_id: int, target_uid: int = -1) -> bool:
	_ensure_loaded()

	var p: PlayerState = state.players[player_id]
	if p.legend == null or p.legend.data == null:
		return false

	var card_id := p.legend.data.card_id
	if not _abilities.has(card_id):
		return false

	var ability: Dictionary = _abilities[card_id]

	if ability.has("can_use"):
		return ability["can_use"].call(state, player_id, target_uid)

	return true


static func use(state: GameState, player_id: int, target_uid: int = -1) -> void:
	_ensure_loaded()

	var p: PlayerState = state.players[player_id]
	var card_id := p.legend.data.card_id

	if not _abilities.has(card_id):
		state.add_event("This legend has no registered ability.")
		return

	var ability: Dictionary = _abilities[card_id]
	ability["use"].call(state, player_id, target_uid)


static func _register_all() -> void:
	_register_blind_monk()
	# Later:
	# _register_garen_legend()
	# _register_jinx_legend()
	# _register_ahri_legend()

static func _register_blind_monk() -> void:
	_abilities["OGN-257/298"] = {
		"name": "Blind Monk",
		"requires_target": true,

		"can_use": func(state: GameState, player_id: int, target_uid: int) -> bool:
			if player_id != state.active_player_id:
				return false

			var p: PlayerState = state.players[player_id]

			if p.legend == null:
				return false

			if p.legend.is_exhausted():
				return false

			if not EffectResolver.has_awake_rune(p, 1):
				return false

			var target: UnitState = state.unit_registry.get_by_uid(target_uid)
			if target == null:
				return false

			if target.player_id != player_id:
				return false

			return true,

		"use": func(state: GameState, player_id: int, target_uid: int) -> void:
			var p: PlayerState = state.players[player_id]
			var target: UnitState = state.unit_registry.get_by_uid(target_uid)

			if target == null:
				state.add_event("Blind Monk failed: invalid target.")
				return

			EffectResolver.spend_awake_runes(p, 1)
			p.legend.exhaust()

			EffectResolver.buff_unit_if_unbuffed(
				state,
				p.legend.uid,
				target,
				1,
				EffectInstance.ExpiryTiming.PERMANENT
			)

			state.add_event("Blind Monk buffed %s." % target.card_instance.data.card_name)
	}
