class_name MightCalculator

static func compute_attack_might(unit: UnitState, game_state: GameState) -> int:
	if unit.is_stunned():
		return 0

	var might: int = unit.card_instance.data.might
	might += unit.effects.sum_of(EffectInstance.EffectType.BUFF)
	might += unit.effects.sum_of(EffectInstance.EffectType.ASSAULT)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.MIGHTY, game_state)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.LEGION, game_state)
	might += _lee_sin_aura_bonus(unit, game_state)

	if _is_wizened_elder(unit) and _has_any_buff(unit):
		might += 1

	return maxi(might, 0)


static func compute_defense_might(unit: UnitState, game_state: GameState) -> int:
	if unit.is_stunned():
		return 0
	
	var might: int = unit.card_instance.data.might
	might += unit.effects.sum_of(EffectInstance.EffectType.BUFF)
	might += unit.effects.sum_of(EffectInstance.EffectType.SHIELD)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.MIGHTY, game_state)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.LEGION, game_state)
	might += _lee_sin_aura_bonus(unit, game_state)

	if _is_wizened_elder(unit) and _has_any_buff(unit):
		might += 1

	return maxi(might, 0)


static func compute_deflect_cost(unit: UnitState) -> int:
	return unit.effects.sum_of(EffectInstance.EffectType.DEFLECT)


static func _evaluate_conditional(
		unit: UnitState,
		type: EffectInstance.EffectType,
		game_state: GameState) -> int:
	var total := 0
	for e in unit.effects.get_all():
		if e.effect_type == type and e.condition_fn.is_valid():
			if e.condition_fn.call(unit, game_state):
				total += e.value
	return total

static func _lee_sin_aura_bonus(unit: UnitState, game_state: GameState) -> int:
	print("DEBUG Lee aura check for ", unit.card_instance.data.card_name)

	if unit.card_instance.data.card_id == "OGN-151/298":
		return 0

	if not unit.effects.has_any(EffectInstance.EffectType.BUFF):
		return 0

	var unit_loc := EffectResolver.find_unit_location(game_state, unit.uid)
	if unit_loc.is_empty() or unit_loc["zone"] != "BATTLEFIELD":
		return 0

	for other in game_state.unit_registry.get_units_for_player(unit.player_id):
		if other.card_instance.data.card_id != "OGN-151/298":
			continue

		var lee_loc := EffectResolver.find_unit_location(game_state, other.uid)
		if lee_loc.is_empty():
			continue

		if lee_loc["zone"] == "BATTLEFIELD" and int(lee_loc["index"]) == int(unit_loc["index"]):
			print("DEBUG Lee aura active: +2 for ", unit.card_instance.data.card_name)
			return 2

	return 0

static func _is_wizened_elder(unit: UnitState) -> bool:
	return unit.card_instance.data.card_id == "OGN-065/298"

static func compute_max_health(unit: UnitState) -> int:
	var hp: int = unit.base_health
	hp += unit.effects.sum_of(EffectInstance.EffectType.BUFF)
	return maxi(hp, 0)
	
static func _has_any_buff(unit: UnitState) -> bool:
	return unit.effects.max_of(EffectInstance.EffectType.BUFF) > 0

static func get_total_might(unit: UnitState, game_state: GameState) -> int:
	if unit.is_stunned():
		return 0

	var might: int = unit.card_instance.data.might
	might += unit.effects.sum_of(EffectInstance.EffectType.BUFF)
	might += unit.effects.sum_of(EffectInstance.EffectType.ASSAULT)
	might += unit.effects.sum_of(EffectInstance.EffectType.SHIELD)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.MIGHTY, game_state)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.LEGION, game_state)
	might += _lee_sin_aura_bonus(unit, game_state)

	if _is_wizened_elder(unit) and _has_any_buff(unit):
		might += 1

	return maxi(might, 0)
