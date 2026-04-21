class_name MightCalculator

# Pure static functions — no side effects, no state.
# All inputs are read-only; callers must not mutate them inside these calls.
#
# Order of operations (attack):
#   1. base Might from CardData
#   2. BUFF — non-stacking; only the highest value applies
#   3. ASSAULT — stackable; sum of all instances; attack role only
#   4. MIGHTY — conditional; each instance evaluated independently
#   5. LEGION — conditional; each instance evaluated independently
#   6. STUN override — if stunned, result is forced to 0
#
# Order of operations (defense):
#   1. base Might from CardData
#   2. BUFF — non-stacking; only the highest value applies
#   3. SHIELD — stackable; sum of all instances; defend role only
#   4. MIGHTY — conditional
#   5. LEGION — conditional
#   (STUN does not affect defense Might)

# ── Public API ────────────────────────────────────────────────────────────────

static func compute_attack_might(unit: UnitState, game_state: GameState) -> int:
	# STUN prevents dealing damage entirely — short-circuit before any bonus
	if unit.is_stunned():
		return 0

	var might: int = unit.card_instance.data.might
	might += unit.effects.max_of(EffectInstance.EffectType.BUFF)
	might += unit.effects.sum_of(EffectInstance.EffectType.ASSAULT)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.MIGHTY, game_state)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.LEGION, game_state)
	return maxi(might, 0)

static func compute_defense_might(unit: UnitState, game_state: GameState) -> int:
	var might: int = unit.card_instance.data.might
	might += unit.effects.max_of(EffectInstance.EffectType.BUFF)
	might += unit.effects.sum_of(EffectInstance.EffectType.SHIELD)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.MIGHTY, game_state)
	might += _evaluate_conditional(unit, EffectInstance.EffectType.LEGION, game_state)
	return maxi(might, 0)

# Returns the extra Power cost opponents must pay to target this unit with spells/abilities.
# DEFLECT is NOT a combat targeting mechanic — it is a spell/ability cost modifier only.
static func compute_deflect_cost(unit: UnitState) -> int:
	return unit.effects.sum_of(EffectInstance.EffectType.DEFLECT)

# ── Internal ──────────────────────────────────────────────────────────────────

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
