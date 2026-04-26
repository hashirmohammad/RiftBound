extends Node2D
 
@onready var end_turn_button = $EndTurnButton
@onready var game_controller = $GameController
@onready var win_screen      = $WinScreen
 
func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	win_screen.rematch_requested.connect(_on_rematch)
	win_screen.quit_requested.connect(_on_quit)
 
func _on_end_turn_pressed() -> void:
	await game_controller.try_end_turn()

func _on_rematch() -> void:
	game_controller.state = GameEngine.start_game()
	await game_controller.wait_until_main()
	game_controller.refresh_all_ui()

func _on_quit() -> void:
	get_tree().quit()
