class_name GameAction
extends RefCounted

var player_id: int

func _init(_player_id: int = -1):
	player_id = _player_id

func validate(_state: GameState) -> bool:
	return true

func execute(_state: GameState) -> void:
	pass

func get_error_message() -> String:
	return "Invalid action."
