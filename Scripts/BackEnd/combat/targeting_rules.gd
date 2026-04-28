class_name TargetingRules

# Validates and resolves which defenders a given attacker may legally engage.
#
# TANK rule:
#   If any non-hidden TANK units exist on the defending side, the assigning player
#   must assign lethal damage to at least one TANK unit before assigning to non-TANK units.
#   Among multiple same-priority TANK units, the assigning player chooses order.
#
# DEFLECT is NOT a combat targeting mechanic.
#   DEFLECT adds extra Power cost to spells/abilities that target a permanent.
#   It has no effect on which units can be attacked or how combat damage is assigned.
#
# HIDDEN:
#   Hidden cards are not on-board units and are never in UnitRegistry.
#   They cannot be targeted or affected by combat rules until played face-up.
#   See UnitState for the full rules placeholder comment.

# Returns true if `attacker` may legally declare an attack against any unit
# on the opposing side given the current board state.
# A false result means the attack declaration itself is invalid.
static func can_declare_attack(
		attacker: UnitState,
		game_state: GameState,
		registry: UnitRegistry) -> bool:
	# Attacker must be awake (not exhausted)
	if attacker.card_instance.is_exhausted():
		return false
	# Attacker must have a valid target
	return _has_valid_targets(attacker, game_state, registry)

# Returns the ordered list of defenders that must receive lethal damage first (TANK units).
# Non-empty only when TANK units are present among the defending side.
# The assigning player may process these in any order within the priority group.
static func get_tank_priority(
		defending_player_id: int,
		registry: UnitRegistry) -> Array[UnitState]:
	# All TANK units on the defending side are equal priority.
	# Order within this list is determined by the assigning player during damage assignment.
	return registry.get_tank_units(defending_player_id)

# Returns all legal defender targets for `attacker`.
# When TANK units are present, only TANK units are legal initial targets
# (the assigning player must clear lethal on TANKs before assigning elsewhere).
static func get_legal_targets(
		attacker: UnitState,
		defending_player_id: int,
		registry: UnitRegistry) -> Array[UnitState]:

	var all_defenders: Array[UnitState] = registry.get_units_for_player(defending_player_id)
	if all_defenders.is_empty():
		return []

	var tank_units: Array[UnitState] = registry.get_tank_units(defending_player_id)
	if tank_units.is_empty():
		return all_defenders

	# TANK present — attacker must target TANK units first
	return tank_units

# Checks whether `intended_target` is a legal declaration target given current board state.
# Used by CombatManager before creating a CombatContext.
static func validate_target(attacker: UnitState, target: UnitState, registry: UnitRegistry) -> bool:
	if attacker == null or target == null:
		return false

	if attacker.player_id == target.player_id:
		return false

	if attacker.is_stunned():
		return false

	# Ganking ignores Tank targeting restriction.
	if attacker.effects.has_any(EffectInstance.EffectType.GANKING):
		return true

	var tanks: Array[UnitState] = registry.get_tank_units(target.player_id)

	if tanks.is_empty():
		return true

	return target.effects.has_any(EffectInstance.EffectType.TANK)

# ── Internal ──────────────────────────────────────────────────────────────────

static func _has_valid_targets(
		attacker: UnitState,
		_game_state: GameState,
		registry: UnitRegistry) -> bool:
	var opponents: Array[UnitState] = registry.get_units_for_player(1 - attacker.player_id)
	return not opponents.is_empty()
