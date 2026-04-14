class_name GameAction
extends RefCounted

var player_id: int

func _init(_player_id: int = -1):
	player_id = _player_id

func validate(state: GameState) -> bool:
	return true

func execute(state: GameState) -> void:
	pass

func get_error_message() -> String:
	return "Invalid action."
