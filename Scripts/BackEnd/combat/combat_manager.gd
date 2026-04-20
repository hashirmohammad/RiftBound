class_name CombatManager
extends RefCounted

# Orchestrates the full combat sequence from attack declaration through cleanup.
#
# Full sequence:
#   1. declare_attack()      — validate, resolve targeting, create CombatContext
#   2. begin_showdown()      — open timing window for ACTIONs and REACTIONs
#   3. [players act]         — via queue_action() and queue_reaction() on TimingManager
#   4. close_showdown()      — resolve REACTION stack LIFO
#   5. resolve_combat()      — compute Might, assign damage, apply simultaneously
#   6. process_deaths()      — DEATHKNELL triggers, then move dead units to trash
#   7. _cleanup()            — expire END_OF_COMBAT effects, clear combat roles
#
# DEATHKNELL ordering (rules-authoritative):
#   - Triggers are queued BEFORE units move to trash
#   - If multiple triggers fire simultaneously, each controller orders their own
#   - Turn player's triggers resolve before opponent's triggers
#   - Multiple DEATHKNELL on one unit are ordered by the controlling player
#     (simple implementation: registration order; swap via reorder_deathknell() if needed)

signal combat_declared(context: CombatContext)
signal showdown_opened(showdown: ShowdownContext)
signal showdown_closed(context: CombatContext)
signal combat_resolved(context: CombatContext)
signal unit_died(unit: UnitState)

var timing_manager: TimingManager
var unit_registry: UnitRegistry

func _init(registry: UnitRegistry, timing: TimingManager) -> void:
	unit_registry = registry
	timing_manager = timing

# ── Step 1: Declaration ───────────────────────────────────────────────────────

# Declares an attack from `attacker_uid` against `target_uid`.
# Returns null if the declaration is invalid (wrong phase, illegal target, etc.).
# Phase validation (MAIN phase, active player check) is handled by the calling Action.
func declare_attack(
		attacker_uid: int,
		target_uid: int,
		game_state: GameState) -> CombatContext:

	var attacker: UnitState = unit_registry.get_unit(attacker_uid)
	var intended: UnitState = unit_registry.get_unit(target_uid)

	if attacker == null or intended == null:
		push_warning("CombatManager: unknown unit uid in declare_attack")
		return null

	if not TargetingRules.validate_target(attacker, intended, unit_registry):
		game_state.event_log.append({
			"event": "attack_illegal",
			"attacker": attacker_uid,
			"intended_target": target_uid,
			"reason": "TANK enforcement or invalid target"
		})
		return null

	var context := CombatContext.new()
	context.game_state = game_state
	context.unit_registry = unit_registry
	context.attackers.append(attacker)
	context.defenders.append(intended)

	# Populate TANK priority order for the defender side
	context.tank_priority_order = TargetingRules.get_tank_priority(
		1 - attacker.player_id, unit_registry
	)

	attacker.combat_role = UnitState.CombatRole.ATTACKER
	intended.combat_role = UnitState.CombatRole.DEFENDER

	game_state.event_log.append({
		"event": "combat_declared",
		"attacker": attacker_uid,
		"defender": intended.uid,
		"tank_priority_count": context.tank_priority_order.size()
	})

	combat_declared.emit(context)
	return context

# ── Step 2: Open Showdown ─────────────────────────────────────────────────────

func begin_showdown(context: CombatContext) -> ShowdownContext:
	var showdown := timing_manager.open_showdown(context)
	context.game_state.event_log.append({"event": "showdown_opened"})
	showdown_opened.emit(showdown)
	return showdown

# ── Step 4: Close Showdown ────────────────────────────────────────────────────

func close_showdown(context: CombatContext, showdown: ShowdownContext) -> void:
	timing_manager.close_showdown(showdown)
	context.showdown_complete = true
	context.game_state.event_log.append({"event": "showdown_closed"})
	showdown_closed.emit(context)

# ── Step 5: Combat Resolution ─────────────────────────────────────────────────

func resolve_combat(context: CombatContext) -> void:
	assert(context.showdown_complete, "resolve_combat called before showdown closed")

	if context.is_cancelled:
		context.game_state.event_log.append({"event": "combat_cancelled"})
		_cleanup(context)
		combat_resolved.emit(context)
		return

	CombatResolver.resolve(context)

	context.game_state.event_log.append({
		"event": "combat_damage_applied",
		"attacker_might": context.total_attacker_might,
		"defender_might": context.total_defender_might,
		"attacker_assignments": context.attacker_assignments,
		"defender_assignments": context.defender_assignments,
	})

	var dead: Array[UnitState] = CombatResolver.collect_dead(context)
	_process_deaths(dead, context)
	_cleanup(context)
	combat_resolved.emit(context)

# ── Step 6: Death processing ──────────────────────────────────────────────────

func _process_deaths(dead: Array[UnitState], context: CombatContext) -> void:
	if dead.is_empty():
		return

	# Collect all DEATHKNELL triggers BEFORE any unit moves to trash
	# Ordering: turn player's triggers first, then opponent's, registration order within
	var pending_triggers: Array[Dictionary] = _collect_deathknell_triggers(dead, context)

	# Move dead units to trash
	for unit in dead:
		unit.card_instance.zone = CardInstance.Zone.TRASH
		unit_registry.unregister(unit.uid)
		context.game_state.event_log.append({
			"event": "unit_died",
			"uid": unit.uid,
			"name": unit.card_instance.data.card_name
		})
		unit_died.emit(unit)

	# Fire DEATHKNELL triggers after all units are removed
	for entry in pending_triggers:
		var effect: EffectInstance = entry["effect"]
		var source_unit: UnitState = entry["source"]
		if effect.trigger_fn.is_valid():
			effect.trigger_fn.call(source_unit, context.game_state)
		context.game_state.event_log.append({
			"event": "deathknell_triggered",
			"source_uid": source_unit.uid,
			"effect_uid": effect.uid
		})

# Returns DEATHKNELL triggers sorted by DEATHKNELL ordering rules:
#   turn player's triggers first, then opponent's, registration order within each group.
func _collect_deathknell_triggers(
		dead: Array[UnitState],
		context: CombatContext) -> Array[Dictionary]:

	var turn_player_triggers: Array[Dictionary] = []
	var opponent_triggers: Array[Dictionary] = []
	var turn_player_id: int = context.game_state.active_player_index

	for unit in dead:
		var triggers: Array[EffectInstance] = unit.effects.get_triggered("on_death")
		# If this unit's controller has multiple DEATHKNELLs, registration order applies.
		# (Player-interactive reordering is a future enhancement.)
		for t in triggers:
			var entry := {"effect": t, "source": unit}
			if unit.player_id == turn_player_id:
				turn_player_triggers.append(entry)
			else:
				opponent_triggers.append(entry)

	var result: Array[Dictionary] = []
	result.append_array(turn_player_triggers)
	result.append_array(opponent_triggers)
	return result

# ── Step 7: Cleanup ───────────────────────────────────────────────────────────

func _cleanup(context: CombatContext) -> void:
	for unit in context.all_units():
		unit.effects.expire_by_timing(EffectInstance.ExpiryTiming.END_OF_COMBAT, context.game_state)
		unit.combat_role = UnitState.CombatRole.NONE
