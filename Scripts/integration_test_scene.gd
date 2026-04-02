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

	var player = game_controller.state.get_active_player()

	status_label.text = (
		"Turn: %d\nActive Player: P%d\nPhase: %s\nHand: %d\nBoard: %d\nDeck: %d\nRunes: %d"
		% [
			game_controller.state.turn_number,
			game_controller.state.active_player_index,
			game_controller.state.phase,
			player.hand.size(),
			player.board.size(),
			player.deck.size(),
			player.rune_count_in_pool()
		]
	)

func _on_end_turn_pressed() -> void:
	await game_controller.try_end_turn()
	update_status()
