class_name CombatResolver

# -------------------------
# SHOWDOWN RESOLUTION
# -------------------------
# Called automatically during the SHOWDOWN phase for each battlefield slot.
# For each contested slot (0 and 1):
#   1. Collect units from both players in that slot.
#   2. If only one side has units, they win control uncontested.
#   3. If both sides have units, resolve combat:
#      - Each side deals its total might as damage spread across opposing units.
#      - Dead units (current_health <= 0) are sent to trash.
#      - The side with surviving units wins control.
#      - Ties (both wiped or equal survivors) leave the slot uncontested (NO_CONTROL).
#   4. Surviving units are returned exhausted to their owner's board.

static func resolve(state: GameState) -> void:
	var num_slots := 2
	for slot_index in range(num_slots):
		_resolve_slot(state, slot_index)


static func _resolve_slot(state: GameState, slot_index: int) -> void:
	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]

	var p0_units: Array = p0.battlefield_slots[slot_index].duplicate()
	var p1_units: Array = p1.battlefield_slots[slot_index].duplicate()

	# Nothing to resolve if both sides are empty
	if p0_units.is_empty() and p1_units.is_empty():
		return

	state.add_event("--- Showdown: battlefield slot %d ---" % slot_index)

	# Uncontested: only one side sent units
	if p0_units.is_empty():
		state.add_event("P1 wins slot %d uncontested." % slot_index)
		_return_survivors_to_board(state, p1, slot_index, p1_units)
		state.set_battlefield_control(slot_index, 1)
		return

	if p1_units.is_empty():
		state.add_event("P0 wins slot %d uncontested." % slot_index)
		_return_survivors_to_board(state, p0, slot_index, p0_units)
		state.set_battlefield_control(slot_index, 0)
		return

	# Contested: deal damage simultaneously then check survivors
	var p0_might := _total_might(p0_units)
	var p1_might := _total_might(p1_units)

	state.add_event("P0 might=%d vs P1 might=%d in slot %d." % [p0_might, p1_might, slot_index])

	_distribute_damage(p1_units, p0_might)
	_distribute_damage(p0_units, p1_might)

	var p0_survivors := _remove_dead(state, p0, p0_units)
	var p1_survivors := _remove_dead(state, p1, p1_units)

	# Return survivors to board
	_return_survivors_to_board(state, p0, slot_index, p0_survivors)
	_return_survivors_to_board(state, p1, slot_index, p1_survivors)

	# Determine control
	var p0_alive := not p0_survivors.is_empty()
	var p1_alive := not p1_survivors.is_empty()

	if p0_alive and not p1_alive:
		state.set_battlefield_control(slot_index, 0)
	elif p1_alive and not p0_alive:
		state.set_battlefield_control(slot_index, 1)
	else:
		# Both wiped or both have survivors — no change in control
		state.add_event("Slot %d: no control change (tie or mutual wipe)." % slot_index)


# -------------------------
# HELPERS
# -------------------------

static func _total_might(units: Array) -> int:
	var total := 0
	for unit in units:
		total += unit.data.might
	return total


# Distribute incoming damage across units in order until damage runs out.
static func _distribute_damage(units: Array, damage: int) -> void:
	var remaining := damage
	for unit in units:
		if remaining <= 0:
			break
		var dealt := min(remaining, unit.current_health)
		unit.take_damage(dealt)
		remaining -= dealt


# Remove dead units from the battlefield slot and send them to trash.
# Returns the array of surviving units.
static func _remove_dead(state: GameState, player: PlayerState, units: Array) -> Array:
	var survivors := []
	for unit in units:
		if unit.is_dead():
			unit.zone = CardInstance.Zone.TRASH
			player.trash.append(unit)
			state.add_event("%s died in showdown." % unit.data.card_name)
		else:
			survivors.append(unit)
	return survivors


# Clear the battlefield slot and return surviving units to the player's board exhausted.
static func _return_survivors_to_board(state: GameState, player: PlayerState, slot_index: int, survivors: Array) -> void:
	player.battlefield_slots[slot_index].clear()
	for unit in survivors:
		unit.zone = CardInstance.Zone.BOARD
		unit.exhaust()
		# Place back into first available board slot
		for i in range(player.board_slots.size()):
			if player.board_slots[i].is_empty():
				player.board_slots[i].append(unit)
				break
