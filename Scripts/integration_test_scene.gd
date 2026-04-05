extends Node2D

@onready var game_controller: GameController = $GameController
@onready var status_label = $LabelStatus
@onready var end_turn_button = $ButtonEndTurn

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	update_status()

func _process(_delta: float) -> void:
	update_status()

func update_status() -> void:
	if game_controller == null or game_controller.state == null:
		status_label.text = "State not ready"
		return

	var state = game_controller.state
	var player = state.get_active_player()
	var opponent = state.players[1 - state.active_player_index]

	status_label.text = (
		"P0 Deck: %s | P1 Deck: %s\nTurn: %d\nActive Player: P%d\nPhase: %s\nHand: %d\nBoard: %d\nDeck: %d\nRunes: %d"
		% [
			state.deck_names[0],
			state.deck_names[1],
			state.turn_number,
			state.active_player_index,
			state.phase,
			player.hand.size(),
			player.board.size(),
			player.deck.size(),
			player.rune_count_in_pool()
		]
	)

func _on_end_turn_pressed() -> void:
	await game_controller.try_end_turn()
	update_status()
