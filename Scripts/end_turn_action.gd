class_name EndTurnAction
extends GameAction

var _error_message: String = "Invalid END_TURN."

func _init(_player_id: int = -1):
	super(_player_id)

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Invalid END_TURN: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid END_TURN: not in MAIN phase."
		return false

	return true

func execute(state: GameState) -> void:
	if state.turn_system != null:
		state.turn_system.next_phase()

	GameEngine.end_turn(state)

func get_error_message() -> String:
	return _error_message
