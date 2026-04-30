class_name CombatUIController
extends RefCounted


var controller: Node
var state: GameState
var status_label: Label
var pending_assignments: Dictionary = {}

func setup(_controller: Node, _state: GameState, _status_label: Label) -> void:
	controller = _controller
	state = _state
	status_label = _status_label

func try_pass_priority() -> void:
	if not state.awaiting_showdown:
		return

	var showdown := state.active_showdown
	if showdown == null:
		return

	var player_id: int = state.get_priority_player_id()

	var action := PassPriorityAction.new(player_id)
	var success: bool = controller._apply_action(action)

	if not success:
		status_label.text = action.get_error_message()
		return

	controller.refresh_all_ui()

func try_commit_to_battlefield(card_uids: Array[int], battlefield_index: int) -> bool:
	var player := state.get_active_player()
	var action := CommitToBattlefieldAction.new(player.id, card_uids, battlefield_index)

	var success: bool = controller._apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	controller.selected_board_uids.clear()
	controller.refresh_all_ui()
	return true

func try_move_to_battlefield(card_uid: int, battlefield_index: int) -> bool:
	var player := state.get_active_player()
	var action := MoveToBattlefieldAction.new(player.id, card_uid, battlefield_index)

	var success: bool = controller._apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	controller.render_arena_slot(player)
	controller.render_board()
	return true

func try_return_from_battlefield(card_uid: int, battlefield_index: int, slot_index: int = 0) -> bool:
	var player := state.get_active_player()
	var action := ReturnFromBattlefieldAction.new(player.id, card_uid, battlefield_index, slot_index)

	var success: bool = controller._apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	controller.render_arena_slot(player)
	controller.render_slot(player, slot_index)
	return true

func confirm_damage() -> void:
	if not state.awaiting_damage_assignment:
		return

	var ctx := state.active_combat_context
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might

	var player_id: int = ctx.attackers[0].player_id if loser_is_attacker else ctx.defenders[0].player_id
	var action := ConfirmDamageAction.new(player_id, pending_assignments)

	var success: bool = controller._apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return

	pending_assignments.clear()
	controller.refresh_all_ui()

func try_return_from_any_battlefield(
		card_uid: int,
		source_player_id: int,
		battlefield_index: int,
		slot_index: int = 0
	) -> bool:
	var active_player := state.get_active_player()
	var unit: UnitState = state.unit_registry.get_unit(card_uid)

	if unit == null:
		status_label.text = "Return failed: unit not found."
		return false

	if unit.player_id != active_player.id:
		status_label.text = "Return failed: you do not control this unit."
		return false

	var source_player: PlayerState = state.players[source_player_id]
	var card: CardInstance = null

	for c in source_player.battlefield_slots[battlefield_index]:
		if c.uid == card_uid:
			card = c
			break

	if card == null:
		status_label.text = "Return failed: card not found in battlefield."
		return false

	source_player.battlefield_slots[battlefield_index].erase(card)

	card.zone = CardInstance.Zone.BOARD
	card.exhaust()
	active_player.board_slots[slot_index].append(card)

	state.add_event("P%d returned %s from P%d battlefield %d to board slot %d." % [
		active_player.id,
		card.data.card_name,
		source_player_id,
		battlefield_index,
		slot_index
	])

	controller.refresh_all_ui()
	return true

func adjust_damage_assignment(unit_uid: int, delta: int) -> void:
	if not state.awaiting_damage_assignment:
		return

	var ctx := state.active_combat_context
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	var pool: int = ctx.total_attacker_might if loser_is_attacker else ctx.total_defender_might

	var current: int = pending_assignments.get(unit_uid, 0)

	var total_assigned := 0
	for uid in pending_assignments:
		total_assigned += pending_assignments[uid]

	var remaining: int = pool - total_assigned

	if delta > 0:
		pending_assignments[unit_uid] = current + mini(delta, remaining)
	else:
		pending_assignments[unit_uid] = maxi(0, current + delta)

	controller.refresh_all_ui()

func get_pending_assignments() -> Dictionary:
	return pending_assignments
	
