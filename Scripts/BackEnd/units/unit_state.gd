class_name UnitState
extends RefCounted

# Runtime state of a unit on the board.
# Wraps CardInstance (the zone/exhaust tracker) without replacing it.
# CardInstance is still the authoritative record for zone and exhaust state.

# RULES PLACEHOLDER: Hidden cards do not apply combat keywords like Tank until
# played face-up as units. A hidden card is not present in UnitRegistry and
# does not participate in combat resolution in any way. Once played face-up,
# the unit enters UnitRegistry and all its keywords apply normally from that point.

# RULES PLACEHOLDER: Hidden and Ganking do not interact until the hidden card
# is played as a unit. Ganking applies to the unit's positioning rules on the board;
# it has no effect while the card is still in the hidden zone.

enum CombatRole { NONE, ATTACKER, DEFENDER }

# ── Identity ──────────────────────────────────────────────────────────────────

var uid: int                       # mirrors card_instance.uid
var card_instance: CardInstance
var player_id: int

# ── Health tracking ───────────────────────────────────────────────────────────

var base_health: int               # set from CardData.health at unit creation
var damage_taken: int = 0          # accumulates; unit dies when damage_taken >= base_health

# ── Effect engine ─────────────────────────────────────────────────────────────

var effects: EffectRegistry

# ── Combat state ──────────────────────────────────────────────────────────────

# Set by CombatContext at declaration; cleared after combat resolves.
var combat_role: CombatRole = CombatRole.NONE

# Pending damage assigned during the damage assignment step.
# Written by CombatResolver; applied simultaneously with all other assignments.
var pending_damage: int = 0

# ── Init ──────────────────────────────────────────────────────────────────────

func _init(instance: CardInstance, p_id: int) -> void:
	card_instance = instance
	uid = instance.uid
	player_id = p_id
	base_health = instance.data.health
	effects = EffectRegistry.new()

# ── Health ────────────────────────────────────────────────────────────────────

func is_alive() -> bool:
	return damage_taken < base_health

func apply_pending_damage() -> void:
	damage_taken += pending_damage
	pending_damage = 0

# ── Effect convenience ────────────────────────────────────────────────────────

func has_effect(type: EffectInstance.EffectType) -> bool:
	return effects.has_any(type)

func is_stunned() -> bool:
	return effects.has_any(EffectInstance.EffectType.STUN)

func is_tank() -> bool:
	return effects.has_any(EffectInstance.EffectType.TANK)

func has_ganking() -> bool:
	return effects.has_any(EffectInstance.EffectType.GANKING)

# Returns the extra Power cost to target this unit with spells/abilities.
func deflect_cost() -> int:
	return MightCalculator.compute_deflect_cost(self)

# ── Debug ─────────────────────────────────────────────────────────────────────

func debug_string() -> String:
	return "UnitState(uid=%d, name=%s, hp=%d/%d, role=%d, stunned=%s)" % [
		uid, card_instance.data.card_name,
		base_health - damage_taken, base_health,
		combat_role, str(is_stunned())
	]
