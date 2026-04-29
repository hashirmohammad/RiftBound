class_name TurnUIController
extends RefCounted

const GameEngine = preload("res://Scripts/BackEnd/core/game_engine.gd")
const EndTurnAction = preload("res://Scripts/BackEnd/actions/end_turn_action.gd")
const PickRuneAction = preload("res://Scripts/BackEnd/actions/pick_runes_to_spend_action.gd")

var controller: Node
var state: GameState
var status_label: Label


func setup(_controller: Node, _state: GameState, _status_label: Label) -> void:
	controller = _controller
	state = _state
	status_label = _status_label


func cancel_payment() -> void:
	if not state.awaiting_rune_payment:
		return

	var player := state.get_active_player()

	for rune_uid in state.selected_rune_uids:
		for rune in player.rune_pool:
			if rune.uid == rune_uid:
				rune.awaken()

	state.exit_rune_payment()

	controller.refresh_all_ui()


func try_pick_runes_to_spend(rune_uid: int) -> bool:
	var player_id := state.pending_payment_player_id
	var action = PickRuneAction.new(player_id, rune_uid)

	var success: bool = GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		controller.refresh_payment_ui()
	else:
		controller.refresh_all_ui()

	return true


func try_end_turn() -> void:
	if state.awaiting_rune_payment:
		status_label.text = "Finish or cancel rune payment first."
		return

	var action = EndTurnAction.new()
	action.player_id = state.get_active_player().id

	var success := GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		controller.refresh_all_ui()
		return

	_deferred_refresh()


func _deferred_refresh() -> void:
	await controller.get_tree().process_frame
	await controller.get_tree().process_frame
	controller.refresh_all_ui()
