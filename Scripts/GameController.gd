extends Node

const GameEngine                  = preload("res://Scripts/game_engine.gd")
const PlayCardAction              = preload("res://Scripts/play_card_action.gd")
const EndTurnAction               = preload("res://Scripts/end_turn_action.gd")
const MoveToBattlefieldAction     = preload("res://Scripts/move_to_battlefield_action.gd")
const ReturnFromBattlefieldAction = preload("res://Scripts/return_from_battlefield_action.gd")

var state: GameState
@onready var status_label = $"../StatusLabel"
@onready var hand_manager    = $"../P0/P0_Hand"
@onready var hand_manager_p1 = $"../P1/P1_Hand"
@onready var board    = $"../Board"
@onready var deck_ui  = $"../P0/P0_MainDeck"
@onready var cancel_payment_button = $"../CancelPaymentButton"

func _ready() -> void:
	state = GameEngine.start_game()
	await wait_until_main()
	refresh_all_ui()
	cancel_payment_button.pressed.connect(_on_cancel_payment_pressed)
	cancel_payment_button.visible = false

func refresh_all_ui() -> void:
	var p0 = state.players[0]
	var p1 = state.players[1]

	print("P0: ", state.deck_names[0], " | P1: ", state.deck_names[1])
	print(" | Turn: ", state.turn_number,
		" | Active Player: P", state.get_active_player().id,
		" | Phase: ", state.phase)

	if board.has_method("render_static_state"):
		board.render_static_state(p0, p1)

	refresh_hand_ui()
	refresh_board_ui()
	refresh_deck_ui()
	_update_status_label()

func print_rune_array(runes: Array) -> void:
	if runes.is_empty():
		print("    <empty>")
		return
	for rune in runes:
		print("    uid=%d | type=%s | state=%s | zone=%s" % [
			rune.uid, rune.name(), rune_state_name(rune.state), rune_zone_name(rune.zone)
		])

func print_board_array(cards: Array) -> void:
	if cards.is_empty():
		print("    <empty>")
		return
	for card in cards:
		print("    uid=%d | name=%s | cost=%d | state=%s | zone=%s" % [
			card.uid, card.data.card_name, card.data.cost,
			card_state_name(card.state), card_zone_name(card.zone)
		])

func print_hand_array(cards: Array) -> void:
	if cards.is_empty():
		print("    <empty>")
		return
	for i in range(cards.size()):
		var card = cards[i]
		print("    [%d] uid=%d | name=%s | cost=%d | state=%s | zone=%s" % [
			i, card.uid, card.data.card_name, card.data.cost,
			card_state_name(card.state), card_zone_name(card.zone)
		])

func refresh_hand_ui() -> void:
	hand_manager.render_hand(state.players[0].hand)
	hand_manager_p1.render_hand(state.players[1].hand)

func refresh_board_ui() -> void:
	board.render_board()

func refresh_deck_ui() -> void:
	if deck_ui.has_method("set_count"):
		deck_ui.set_count(state.players[0].deck.size())

func refresh_payment_ui() -> void:
	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]

	board.render_rune_panels(p0, p1)
	_update_status_label()

func print_state_summary() -> void:
	var player = state.get_active_player()
	print("Turn: %d | Active Player: P%d | Phase: %s" % [
		state.turn_number, player.id, state.phase
	])

func apply_backend_action(action: GameAction) -> void:
	var success := GameEngine.apply_action(state, action)
	if not success:
		print("Action failed: ", action.get_error_message())
	refresh_all_ui()

func apply_backend_action_and_wait(action: GameAction) -> void:
	var success := GameEngine.apply_action(state, action)
	if not success:
		print("Action failed: ", action.get_error_message())
		refresh_all_ui()
		return
	await wait_until_main()
	refresh_all_ui()

func try_play_card(card_uid: int) -> void:
	var player = state.get_active_player()
	var action = PlayCardAction.new()
	action.player_id = player.id
	action.card_uid  = card_uid
	apply_backend_action(action)

func try_play_card_to_slot(card_uid: int, slot_index: int) -> bool:
	var player = state.get_active_player()
	var action = PlayCardAction.new()
	action.player_id = player.id
	action.card_uid = card_uid
	action.slot_index = slot_index

	var success: bool = GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		print("Action failed: ", action.get_error_message())
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_all_ui()

	return true

func try_pick_runes_to_spend(rune_uid: int) -> bool:
	var player = state.get_active_player()
	print("GameController.try_pick_runes_to_spend")
	print("  player:", player.id)
	print("  rune_uid:", rune_uid)

	var action = PickRuneAction.new(player.id, rune_uid)
	var success: bool = GameEngine.apply_action(state, action)

	print("  success:", success)
	if not success:
		print("PickRuneAction failed: ", action.get_error_message())
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_all_ui()

	return true

## Drag a card from the board into the active player's arena battlefield slot.
func try_move_to_battlefield(card_uid: int, battlefield_index: int) -> bool:
	var player = state.get_active_player()
	print("GameController.try_move_to_battlefield")
	print("  player:", player.id)
	print("  card_uid:", card_uid)
	print("  battlefield_index:", battlefield_index)

	var action = MoveToBattlefieldAction.new(player.id, card_uid, battlefield_index)
	var success = GameEngine.apply_action(state, action)

	print("  success:", success)
	if not success:
		print("MoveToBattlefield failed: ", action.get_error_message())
		return false

	board.render_arena_slot(player)
	board.render_board()
	return true

func try_return_from_battlefield(card_uid: int, battlefield_index: int, slot_index: int = 0) -> bool:
	var player = state.get_active_player()
	var action = ReturnFromBattlefieldAction.new(player.id, card_uid, battlefield_index, slot_index)
	var success: bool = GameEngine.apply_action(state, action)
	if not success:
		print("ReturnFromBattlefield failed: ", action.get_error_message())
		return false

	board.render_arena_slot(player)
	board.render_slot(player, slot_index)
	return true

func try_end_turn() -> void:
	if state.awaiting_rune_payment:
		status_label.text = "Finish or cancel rune payment first."
		return

	var player = state.get_active_player()
	var action = EndTurnAction.new()
	action.player_id = player.id
	await apply_backend_action_and_wait(action)

func wait_until_main() -> void:
	var max_frames := 300
	var frames := 0
	while state.phase != "MAIN" and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	if state.phase != "MAIN":
		push_warning("wait_until_main() timed out. Current phase: %s" % state.phase)

func rune_state_name(state_value: int) -> String:
	return RuneInstance.State.keys()[state_value]

func rune_zone_name(zone_value: int) -> String:
	return RuneInstance.Zone.keys()[zone_value]

func card_state_name(state_value: int) -> String:
	return CardInstance.CardState.keys()[state_value]

func card_zone_name(zone_value: int) -> String:
	return CardInstance.Zone.keys()[zone_value]
	
func _update_status_label() -> void:
	var state: GameState = self.state

	if state.awaiting_rune_payment:
		var remaining: int = state.pending_card_cost - state.selected_rune_uids.size()
		var card_name: String = _get_pending_card_name()

		status_label.text = "Select %d more rune(s) to play %s" % [remaining, card_name]
		cancel_payment_button.visible = true
		return

	status_label.text = ""
	cancel_payment_button.visible = false

func _on_cancel_payment_pressed() -> void:
	if not state.awaiting_rune_payment:
		return

	var player := state.get_active_player()

	# Un-exhaust runes that were selected during this payment.
	for rune_uid in state.selected_rune_uids:
		for rune in player.rune_pool:
			if rune.uid == rune_uid:
				rune.awaken()

	_clear_pending_payment_ui_state()
	refresh_all_ui()

func _clear_pending_payment_ui_state() -> void:
	state.awaiting_rune_payment = false
	state.pending_card_uid = -1
	state.pending_slot_index = -1
	state.pending_card_cost = 0
	state.selected_rune_uids.clear()

func _get_pending_card_name() -> String:
	var player = state.get_active_player()

	for card in player.hand:
		if card.uid == state.pending_card_uid:
			return card.data.card_name

	return "card"
