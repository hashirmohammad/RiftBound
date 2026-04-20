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

	# Both players passed — close the showdown window and resolve reactions
	state.combat_manager.close_showdown(context, showdown)

	if context.is_cancelled:
		state.add_event("Combat cancelled by reaction.")
		state.combat_manager.combat_resolved.emit(context)
		state.combat_manager._cleanup(context)
		_clear_combat_state(state)
		return

	# Compute might totals and auto-assign defender retaliation
	context.total_attacker_might = CombatResolver.compute_total_attacker_might(context)
	context.total_defender_might = CombatResolver.compute_total_defender_might(context)
	CombatResolver.assign_defender_damage(context, context.total_defender_might)

	state.add_event("Showdown closed. Attacker might: %d, Defender might: %d." % [
		context.total_attacker_might, context.total_defender_might
	])

	if context.defenders.size() == 1:
		# Single defender — no split decision exists, auto-resolve immediately
		state.combat_manager.auto_resolve(context)
		_clear_combat_state(state)
	else:
		# Multiple defenders — attacker must choose how to distribute their might
		state.awaiting_showdown = false
		state.awaiting_damage_assignment = true
		state.active_showdown = null

func get_error_message() -> String:
	return _error_message

func _clear_combat_state(state: GameState) -> void:
	state.awaiting_showdown = false
	state.awaiting_damage_assignment = false
	state.active_combat_context = null
	state.active_showdown = null
