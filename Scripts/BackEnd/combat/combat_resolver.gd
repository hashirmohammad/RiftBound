class_name CombatResolver

# Resolves damage assignment and simultaneous application for one CombatContext.
#
# Damage model (rules-authoritative):
#   1. Sum all attacking units' Might -> attacker_pool
#   2. Sum all defending units' Might -> defender_pool
#   3. Attacker assigns damage from attacker_pool among defenders
#      - Must assign lethal to each TANK unit (in chosen order) before non-TANK units
#      - Any remaining damage after lethal assignments may be distributed freely
#   4. Defender assigns damage from defender_pool among attackers (retaliation)
#   5. All assigned damage is applied simultaneously after both assignments complete
#   6. Units with damage_taken >= base_health are collected as dead

# ── Might computation ─────────────────────────────────────────────────────────

static func compute_total_attacker_might(context: CombatContext) -> int:
	var total := 0
	for unit in context.attackers:
		total += MightCalculator.compute_attack_might(unit, context.game_state)
	return total

static func compute_total_defender_might(context: CombatContext) -> int:
	var total := 0
	for unit in context.defenders:
		total += MightCalculator.compute_defense_might(unit, context.game_state)
	return total

# ── Damage assignment ─────────────────────────────────────────────────────────

# Assigns attacker_pool damage among defenders.
# TANK units receive lethal damage first (in the order provided by tank_priority_order).
# Remaining pool is distributed to non-TANK units; if pool runs out, later units receive 0.
# This implements the simple (non-interactive) assignment: lethal-first, then overflow.
# For player-interactive assignment, replace this with an action-driven flow.
static func assign_attacker_damage(context: CombatContext, pool: int) -> void:
	var remaining := pool

	# Phase 1 — TANK units (must receive lethal before proceeding to non-TANK)
	var tank_order: Array[UnitState] = context.tank_priority_order.duplicate()
	for tank in tank_order:
		if remaining <= 0:
			break
		var lethal := tank.base_health - tank.damage_taken
		var assigned := mini(remaining, lethal)
		context.attacker_assignments[tank.uid] = \
			context.attacker_assignments.get(tank.uid, 0) + assigned
		remaining -= assigned

	# Phase 2 — non-TANK defenders receive remaining damage
	var tank_uids := tank_order.map(func(u: UnitState) -> int: return u.uid)
	for defender in context.defenders:
		if remaining <= 0:
			break
		if defender.uid in tank_uids:
			continue
		context.attacker_assignments[defender.uid] = \
			context.attacker_assignments.get(defender.uid, 0) + remaining
		remaining = 0

# Assigns defender_pool damage evenly among attackers (retaliation).
# Floor division applied to each attacker; remainder distributed one-per-unit
# from the front. Example: 7 might vs 2 attackers → 4 to first, 3 to second.
# Assigns attacker pool evenly across all defenders (no TANK ordering — for auto-resolve paths).
static func assign_attacker_damage_evenly(context: CombatContext, pool: int) -> void:
	if context.defenders.is_empty() or pool <= 0:
		return
	var count    := context.defenders.size()
	var base     := pool / count
	var remainder := pool % count
	for i in range(count):
		var dmg: int = base + (1 if i < remainder else 0)
		var defender: UnitState = context.defenders[i]
		context.attacker_assignments[defender.uid] = \
			context.attacker_assignments.get(defender.uid, 0) + dmg

static func assign_defender_damage(context: CombatContext, pool: int) -> void:
	if context.attackers.is_empty() or pool <= 0:
		return
	var count    := context.attackers.size()
	var base     := pool / count
	var remainder := pool % count
	for i in range(count):
		var dmg: int = base + (1 if i < remainder else 0)
		var attacker: UnitState = context.attackers[i]
		context.defender_assignments[attacker.uid] = \
			context.defender_assignments.get(attacker.uid, 0) + dmg

# ── Simultaneous application ──────────────────────────────────────────────────

# Writes assigned values into pending_damage on each unit.
# All pending_damage values are applied together in apply_all_damage().
static func stage_damage(context: CombatContext) -> void:
	for defender in context.defenders:
		defender.pending_damage += context.attacker_assignments.get(defender.uid, 0)
	for attacker in context.attackers:
		attacker.pending_damage += context.defender_assignments.get(attacker.uid, 0)

# Applies all staged damage simultaneously across all participants.
static func apply_all_damage(context: CombatContext) -> void:
	for unit in context.all_units():
		unit.apply_pending_damage()

# ── Full resolution ───────────────────────────────────────────────────────────

# Runs assignment → staging → application in the correct order.
# Called by CombatManager after the showdown phase closes.
static func resolve(context: CombatContext) -> void:
	context.total_attacker_might = compute_total_attacker_might(context)
	context.total_defender_might = compute_total_defender_might(context)

	assign_attacker_damage(context, context.total_attacker_might)
	assign_defender_damage(context, context.total_defender_might)

	stage_damage(context)
	apply_all_damage(context)

# ── Death collection ──────────────────────────────────────────────────────────

# Returns all units that have damage_taken >= base_health after apply_all_damage().
static func collect_dead(context: CombatContext) -> Array[UnitState]:
	var dead: Array[UnitState] = []
	for unit in context.all_units():
		if not unit.is_alive():
			dead.append(unit)
	return dead
