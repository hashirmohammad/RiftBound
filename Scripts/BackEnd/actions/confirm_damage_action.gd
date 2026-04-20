class_name ConfirmDamageAction
extends GameAction

# assignments: Dictionary of { defender_uid (int) -> damage_amount (int) }
var assignments: Dictionary = {}
var _error_message: String = "Invalid CONFIRM_DAMAGE."

func _init(_player_id: int = -1, _assignments: Dictionary = {}):
	super(_player_id)
	assignments = _assignments.duplicate()

func validate(state: GameState) -> bool:
	if not state.awaiting_damage_assignment:
		_error_message = "Not in damage assignment phase."
		return false

	var context := state.active_combat_context

	# All assignment values must be non-negative
	var total_assigned: int = 0
	for uid in assignments:
		var dmg: int = assignments[uid]
		if dmg < 0:
			_error_message = "Damage amounts cannot be negative."
			return false
		total_assigned += dmg

	if total_assigned > context.total_attacker_might:
		_error_message = "Total assigned (%d) exceeds attacker might (%d)." % [
			total_assigned, context.total_attacker_might
		]
		return false

	# TANK rule: each TANK defender must receive lethal before non-TANK units
	# (only enforced when the attacker has enough might to deal lethal)
	for tank in context.tank_priority_order:
		var lethal: int = tank.base_health - tank.damage_taken
		var assigned: int = assignments.get(tank.uid, 0)
		if assigned < lethal and context.total_attacker_might >= lethal:
			_error_message = "Must assign lethal damage (%d) to TANK unit '%s' before non-TANK." % [
				lethal, tank.card_instance.data.card_name
			]
			return false

	return true

func execute(state: GameState) -> void:
	var context := state.active_combat_context
	state.combat_manager.apply_player_assignments(context, assignments)
	state.add_event("Damage applied. Combat resolved.")
	state.awaiting_damage_assignment = false
	state.active_combat_context = null
	state.active_showdown = null

func get_error_message() -> String:
	return _error_message
