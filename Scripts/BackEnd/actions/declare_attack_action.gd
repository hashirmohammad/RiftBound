class_name DeclareAttackAction
extends GameAction

var attacker_uid: int = -1
var target_uid: int = -1
var _error_message: String = "Invalid DECLARE_ATTACK."

func _init(_player_id: int = -1, _attacker_uid: int = -1, _target_uid: int = -1):
	super(_player_id)
	attacker_uid = _attacker_uid
	target_uid = _target_uid

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Invalid DECLARE_ATTACK: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid DECLARE_ATTACK: not in MAIN phase."
		return false

	if state.awaiting_rune_payment:
		_error_message = "Invalid DECLARE_ATTACK: rune payment is pending."
		return false

	if state.awaiting_showdown:
		_error_message = "Invalid DECLARE_ATTACK: a combat is already in progress."
		return false

	var attacker: UnitState = state.unit_registry.get_unit(attacker_uid)
	if attacker == null:
		_error_message = "Invalid DECLARE_ATTACK: attacker uid not found in registry."
		return false

	if attacker.player_id != player_id:
		_error_message = "Invalid DECLARE_ATTACK: attacker does not belong to this player."
		return false

	if attacker.card_instance.is_exhausted():
		_error_message = "Invalid DECLARE_ATTACK: attacker is exhausted."
		return false

	var target: UnitState = state.unit_registry.get_unit(target_uid)
	if target == null:
		_error_message = "Invalid DECLARE_ATTACK: target uid not found in registry."
		return false

	if target.player_id == player_id:
		_error_message = "Invalid DECLARE_ATTACK: cannot attack your own unit."
		return false

	if not TargetingRules.validate_target(attacker, target, state.unit_registry):
		_error_message = "Invalid DECLARE_ATTACK: illegal target (TANK unit must be attacked first)."
		return false

	return true

func execute(state: GameState) -> void:
	var context: CombatContext = state.combat_manager.declare_attack(
		attacker_uid, target_uid, state
	)

	if context == null:
		state.add_event("DECLARE_ATTACK failed: combat_manager returned no context.")
		return

	# Exhaust the attacker — attacking is a committed action
	var attacker: UnitState = state.unit_registry.get_unit(attacker_uid)
	attacker.card_instance.exhaust()

	var showdown: ShowdownContext = state.combat_manager.begin_showdown(context)

	state.active_combat_context = context
	state.active_showdown = showdown
	state.awaiting_showdown = true

	state.add_event("P%d declared attack: uid=%d → uid=%d. Showdown open." % [
		player_id, attacker_uid, target_uid
	])

func get_error_message() -> String:
	return _error_message
