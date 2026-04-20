class_name PassPriorityAction
extends GameAction

var _error_message: String = "Invalid PASS_PRIORITY."

func _init(_player_id: int = -1):
	super(_player_id)

func validate(state: GameState) -> bool:
	if not state.awaiting_showdown:
		_error_message = "Invalid PASS_PRIORITY: no showdown is active."
		return false

	return true

func execute(state: GameState) -> void:
	var showdown: ShowdownContext = state.active_showdown
	var context: CombatContext = state.active_combat_context

	showdown.pass_priority(player_id)

	state.add_event("P%d passed priority." % player_id)

	if not showdown.both_passed():
		return

	# Both players passed — close showdown and resolve combat
	state.combat_manager.close_showdown(context, showdown)
	state.combat_manager.resolve_combat(context)

	state.add_event("Showdown closed. Combat resolved.")

	_clear_combat_state(state)

func get_error_message() -> String:
	return _error_message

func _clear_combat_state(state: GameState) -> void:
	state.awaiting_showdown = false
	state.active_combat_context = null
	state.active_showdown = null
