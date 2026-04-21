class_name CombatContext
extends RefCounted

# Snapshot of a single combat encounter.
# Holds all state needed from declaration through resolution and cleanup.
# Supports multi-unit combat: one or more attackers vs one or more defenders.

# ── Participants ──────────────────────────────────────────────────────────────

var attackers: Array[UnitState] = []
var defenders: Array[UnitState] = []

# Game references (set at declaration)
var game_state: GameState
var unit_registry: UnitRegistry

# ── Flow state ────────────────────────────────────────────────────────────────

var showdown_complete: bool = false
# Set by a REACTION ability to cancel combat before damage resolves
var is_cancelled: bool = false

# ── Resolved Might totals (computed after showdown closes) ────────────────────

var total_attacker_might: int = -1
var total_defender_might: int = -1

# ── Damage assignment (written by CombatResolver) ─────────────────────────────
# Maps uid -> damage to be dealt; all applied simultaneously after assignment.

var attacker_assignments: Dictionary = {}  # defender uid -> int
var defender_assignments: Dictionary = {}  # attacker uid -> int

# ── TANK assignment tracking ──────────────────────────────────────────────────
# Ordered list of defenders that must receive lethal damage before non-TANK units.
# Populated by TargetingRules; consumed by CombatResolver during assignment.
# Multiple TANK units share first priority; assigning player may choose their order.

var tank_priority_order: Array[UnitState] = []

# ── Deflect depth guard ───────────────────────────────────────────────────────
# Not used for combat targeting — DEFLECT is a spell/ability cost modifier only.
# Reserved here as a safety field if future mechanics need chain depth tracking.
const MAX_CHAIN_DEPTH: int = 16

# ── Convenience ───────────────────────────────────────────────────────────────

func get_attacker() -> UnitState:
	return attackers[0] if not attackers.is_empty() else null

func get_defender() -> UnitState:
	return defenders[0] if not defenders.is_empty() else null

func all_units() -> Array[UnitState]:
	var result: Array[UnitState] = []
	result.append_array(attackers)
	result.append_array(defenders)
	return result
