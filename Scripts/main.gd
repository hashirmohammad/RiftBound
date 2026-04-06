extends Node2D
 
@onready var end_turn_button = $EndTurnButton
@onready var game_controller = $GameController
 
func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn_pressed)
 
func _on_end_turn_pressed() -> void:
	await game_controller.try_end_turn()
 
