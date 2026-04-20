class_name UnitRegistry
extends RefCounted

# Board-wide runtime index of all face-up units currently in play.
# Hidden (facedown) cards are NOT registered here until played face-up.

var _units: Dictionary = {}   # uid (int) -> UnitState

# ── Mutation ──────────────────────────────────────────────────────────────────

func register(unit: UnitState) -> void:
	_units[unit.uid] = unit

func unregister(uid: int) -> void:
	_units.erase(uid)

# ── Lookup ────────────────────────────────────────────────────────────────────

func get_unit(uid: int) -> UnitState:
	return _units.get(uid, null)

func has_unit(uid: int) -> bool:
	return _units.has(uid)

# ── Filtered queries ──────────────────────────────────────────────────────────

func get_units_for_player(player_id: int) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit in _units.values():
		if unit.player_id == player_id:
			result.append(unit)
	return result

func get_units_with_effect(player_id: int, type: EffectInstance.EffectType) -> Array[UnitState]:
	return get_units_for_player(player_id).filter(
		func(u: UnitState) -> bool: return u.has_effect(type)
	)

func get_tank_units(player_id: int) -> Array[UnitState]:
	return get_units_with_effect(player_id, EffectInstance.EffectType.TANK)

func get_allied_count(player_id: int) -> int:
	return get_units_for_player(player_id).size()

func get_all() -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit in _units.values():
		result.append(unit)
	return result
