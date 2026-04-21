class_name UseReactionAbilityAction
extends GameAction

var source_unit_uid: int = -1
var effect_uid: int = -1
var _error_message: String = "Invalid USE_REACTION."

func _init(_player_id: int = -1, _source_unit_uid: int = -1, _effect_uid: int = -1):
	super(_player_id)
	source_unit_uid = _source_unit_uid
	effect_uid = _effect_uid

func validate(state: GameState) -> bool:
	if not state.awaiting_showdown:
		_error_message = "Invalid USE_REACTION: no showdown is active."
		return false

	if state.active_showdown == null:
		_error_message = "Invalid USE_REACTION: no active showdown."
		return false

	if player_id != state.active_showdown.priority_player_id:
		_error_message = "Invalid USE_REACTION: not this player's priority."
		return false

	var source: UnitState = state.unit_registry.get_unit(source_unit_uid)
	if source == null:
		_error_message = "Invalid USE_REACTION: source unit not found in registry."
		return false

	if source.player_id != player_id:
		_error_message = "Invalid USE_REACTION: unit does not belong to this player."
		return false

	var effect: EffectInstance = _find_effect(source)
	if effect == null:
		_error_message = "Invalid USE_REACTION: effect uid not found on unit."
		return false

	if effect.timing_window != "reaction":
		_error_message = "Invalid USE_REACTION: effect is not a REACTION ability."
		return false

	if not effect.ability_fn.is_valid():
		_error_message = "Invalid USE_REACTION: effect has no ability function."
		return false

	return true

func execute(state: GameState) -> void:
	var source: UnitState = state.unit_registry.get_unit(source_unit_uid)
	var effect: EffectInstance = _find_effect(source)

	state.timing_manager.queue_reaction(
		effect, source, state.active_combat_context, state.active_showdown
	)

	state.active_showdown.reset_passes()
	state.active_showdown.switch_priority()

	state.add_event("P%d queued REACTION ability (effect_uid=%d) on unit uid=%d." % [
		player_id, effect_uid, source_unit_uid
	])

func get_error_message() -> String:
	return _error_message

func _find_effect(source: UnitState) -> EffectInstance:
	for e in source.effects.get_all():
		if e.uid == effect_uid:
			return e
	return null
