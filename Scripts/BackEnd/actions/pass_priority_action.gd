class_name PassPriorityAction
extends GameAction

var _error_message: String = "Invalid PASS_PRIORITY."

func _init(_player_id: int = -1):
	super(_player_id)

func validate(state: GameState) -> bool:
	if not state.awaiting_showdown:
		_error_message = "Invalid PASS_PRIORITY: no showdown is active."
		return false

	if state.active_showdown == null:
		_error_message = "Invalid PASS_PRIORITY: showdown context missing."
		return false

	if not state.active_showdown.can_player_act(player_id):
		_error_message = "Invalid PASS_PRIORITY: it is P%d's priority, not P%d's." % [
			state.active_showdown.priority_player_id,
			player_id
		]
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

	context.total_attacker_might = CombatResolver.compute_total_attacker_might(context)
	context.total_defender_might = CombatResolver.compute_total_defender_might(context)

	state.add_event("Showdown closed. Attacker might: %d, Defender might: %d." % [
		context.total_attacker_might, context.total_defender_might
	])

	var atk := context.total_attacker_might
	var def := context.total_defender_might

	if atk == def:
		# Equal — auto-resolve, even distribution both sides
		CombatResolver.assign_attacker_damage_evenly(context, atk)
		CombatResolver.assign_defender_damage(context, def)
		state.combat_manager.complete_resolve(context)
		_clear_combat_state(state)

	elif atk > def:
		# Attacker wins — DEFENDER is the loser.
		# Auto-assign attacker's damage to defenders (winner's damage, auto).
		CombatResolver.assign_attacker_damage_evenly(context, atk)
		if context.attackers.size() == 1:
			# Single target for defender's retaliation — trivial, auto-assign
			CombatResolver.assign_defender_damage(context, def)
			state.combat_manager.complete_resolve(context)
			_clear_combat_state(state)
		else:
			# Multiple attackers — DEFENDER (loser) distributes their own damage to attacker units
			state.awaiting_showdown = false
			state.awaiting_damage_assignment = true
			state.active_showdown = null

	else:
		# Defender wins — ATTACKER is the loser.
		# Auto-assign defender's damage to attackers (winner's damage, auto).
		CombatResolver.assign_defender_damage(context, def)
		if context.defenders.size() == 1:
			# Single target for attacker's damage — trivial, auto-assign
			CombatResolver.assign_attacker_damage_evenly(context, atk)
			state.combat_manager.complete_resolve(context)
			_clear_combat_state(state)
		else:
			# Multiple defenders — ATTACKER (loser) distributes their own damage to defender units
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
