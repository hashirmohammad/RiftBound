class_name EndTurnAction
extends GameAction

var _error_message: String = "Invalid END_TURN."

func _init(_player_id: int = -1):
	super(_player_id)

func validate(state: GameState) -> bool:
	if state.awaiting_rune_payment:
		_error_message = "Cannot end turn while paying runes."
		return false

	if player_id != state.get_active_player().id:
		_error_message = "Invalid END_TURN: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid END_TURN: not in MAIN phase."
		return false

	return true

func execute(state: GameState) -> void:
	# Advance from MAIN to END phase, which triggers the full end-of-turn
	# phase chain in PlayerTurn. That chain handles switching players and
	# calling start_turn() internally — do NOT call GameEngine.end_turn()
	# here as well or the turn will fire twice.
	if state.turn_system != null:
		state.turn_system.next_phase()

func get_error_message() -> String:
	return _error_message
