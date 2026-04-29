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
	# loser_is_attacker = attacker had less might; they assign their own (lesser) damage to defenders
	# not loser_is_attacker = defender had less might; they assign their own damage to attackers
	var loser_is_attacker: bool = context.total_defender_might > context.total_attacker_might
	var pool: int = context.total_attacker_might if loser_is_attacker else context.total_defender_might

	var total_assigned: int = 0
	for uid in assignments:
		var dmg: int = assignments[uid]
		if dmg < 0:
			_error_message = "Damage amounts cannot be negative."
			return false
		total_assigned += dmg

	if total_assigned > pool:
		_error_message = "Total assigned (%d) exceeds damage pool (%d)." % [total_assigned, pool]
		return false

	# TANK rule applies when the attacker is the loser (assigning their damage to defenders)
	if loser_is_attacker and not _attackers_have_ganking(context):
		for tank in context.tank_priority_order:
			var lethal: int = tank.base_health - tank.damage_taken
			var assigned: int = assignments.get(tank.uid, 0)
			if assigned < lethal and pool >= lethal:
				_error_message = "Must assign lethal damage (%d) to TANK unit '%s' before non-TANK." % [
					lethal, tank.card_instance.data.card_name
				]
				return false

	return true

func execute(state: GameState) -> void:
	var context := state.active_combat_context
	var loser_is_attacker: bool = context.total_defender_might > context.total_attacker_might
	state.combat_manager.apply_player_assignments(context, assignments, loser_is_attacker)
	state.add_event("Damage applied. Combat resolved.")
	state.awaiting_damage_assignment = false
	state.active_combat_context = null
	state.active_showdown = null

func get_error_message() -> String:
	return _error_message

func _attackers_have_ganking(context: CombatContext) -> bool:
	for attacker in context.attackers:
		if attacker.effects.has_any(EffectInstance.EffectType.GANKING):
			return true
	return false
