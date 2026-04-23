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
func get_by_uid(uid: int) -> UnitState:
	return get_unit(uid)
	
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

func count_friendly_units_at_same_location(unit: UnitState, state: GameState) -> int:
	if unit == null:
		return 0

	var count := 0
	var unit_loc: Dictionary = _find_unit_location(unit.uid, state)
	if unit_loc.is_empty():
		return 0

	for other in get_units_for_player(unit.player_id):
		var other_loc: Dictionary = _find_unit_location(other.uid, state)
		if other_loc == unit_loc:
			count += 1

	return count


func _find_unit_location(uid: int, state: GameState) -> Dictionary:
	for player in state.players:
		for lane_index in range(player.battlefield_slots.size()):
			for card in player.battlefield_slots[lane_index]:
				if card.uid == uid:
					return {
						"player_id": player.id,
						"lane_index": lane_index
					}

		for slot_index in range(player.board_slots.size()):
			for card in player.board_slots[slot_index]:
				if card.uid == uid:
					return {
						"player_id": player.id,
						"slot_index": slot_index
					}

	return {}
