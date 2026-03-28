class_name GameController
extends Node

const GameEngine = preload("res://Scripts/game_engine.gd")
const PlayCardAction = preload("res://Scripts/play_card_action.gd")
const EndTurnAction = preload("res://Scripts/end_turn_action.gd")

var state: GameState

@onready var hand_manager = $"../HandManager"
@onready var board = $"../Board"
@onready var deck_ui = $"../Deck"

func _ready() -> void:
	state = GameEngine.start_game()
	await wait_until_main()
	refresh_all_ui()

func refresh_all_ui() -> void:
	var player = state.get_active_player()
	var opponent = state.players[1 - state.active_player_index]

	print(
		"Turn: ", state.turn_number,
		" | Active Player: P", player.id,
		" | Phase: ", state.phase,
		" | Hand: ", player.hand.size(),
		" | Board: ", player.board.size(),
		" | Deck: ", player.deck.size()
	)

	if board.has_method("render_static_state"):
		board.render_static_state(player, opponent)

	refresh_hand_ui()
	refresh_board_ui()
	refresh_deck_ui()

func refresh_hand_ui() -> void:
	var player = state.get_active_player()
	hand_manager.render_hand(player.hand)

func refresh_board_ui() -> void:
	var player = state.get_active_player()
	board.render_board(player.board)

func refresh_deck_ui() -> void:
	var player = state.get_active_player()
	if deck_ui.has_method("set_count"):
		deck_ui.set_count(player.deck.size())

func print_state_summary() -> void:
	var player = state.get_active_player()
	print("Turn: %d | Active Player: P%d | Phase: %s" % [
		state.turn_number,
		player.id,
		state.phase
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
	var action = PlayCardAction.new(player.id, card_uid)
	apply_backend_action(action)

func try_play_card_to_slot(card_uid: int, slot_index: int) -> void:
	var player = state.get_active_player()
	var action = PlayCardAction.new(player.id, card_uid, slot_index)
	apply_backend_action(action)

func try_end_turn() -> void:
	var player = state.get_active_player()
	var action = EndTurnAction.new(player.id)
	await apply_backend_action_and_wait(action)

func wait_until_main() -> void:
	var max_frames := 300
	var frames := 0

	while state.phase != "MAIN" and frames < max_frames:
		await get_tree().process_frame
		frames += 1

	if state.phase != "MAIN":
		push_warning("wait_until_main() timed out. Current phase: %s" % state.phase)
