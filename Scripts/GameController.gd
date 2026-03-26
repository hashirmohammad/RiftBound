class_name GameController
extends Node

const GameEngine = preload("res://Scripts/game_engine.gd")
const GameAction = preload("res://Scripts/action.gd")

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
	print(
		"Turn: ", state.turn_number,
		" | Active Player: P", state.active_player_index,
		" | Phase: ", state.phase,
		" | Hand: ", player.hand.size(),
		" | Board: ", player.board.size(),
		" | Deck: ", player.deck.size()
	)

	refresh_hand_ui()
	refresh_board_ui()
	refresh_deck_ui()
	print_state_summary()

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
	print("Turn: %d | Active Player: P%d | Phase: %s" % [
		state.turn_number,
		state.active_player_index,
		state.phase
	])

func apply_backend_action(action: GameAction) -> void:
	GameEngine.apply_action(state, action)
	refresh_all_ui()

func apply_backend_action_and_wait(action: GameAction) -> void:
	GameEngine.apply_action(state, action)
	await wait_until_main()
	refresh_all_ui()

func try_play_card(card_uid: int) -> void:
	var player = state.get_active_player()
	var action = GameAction.new(GameAction.ActionType.PLAY_CARD, player.id)
	action.card_uid = card_uid
	apply_backend_action(action)

func try_end_turn() -> void:
	var player = state.get_active_player()
	var action = GameAction.new(GameAction.ActionType.END_TURN, player.id)
	await apply_backend_action_and_wait(action)

func wait_until_main() -> void:
	while state.phase != "MAIN":
		await get_tree().process_frame
