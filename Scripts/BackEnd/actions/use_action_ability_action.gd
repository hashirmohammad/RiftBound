class_name UseActionAbilityAction
extends GameAction

var source_unit_uid: int = -1
var effect_uid: int = -1
var _error_message: String = "Invalid USE_ACTION."

func _init(_player_id: int = -1, _source_unit_uid: int = -1, _effect_uid: int = -1):
	super(_player_id)
	source_unit_uid = _source_unit_uid
	effect_uid = _effect_uid

func validate(state: GameState) -> bool:
	if not state.awaiting_showdown:
		_error_message = "Invalid USE_ACTION: no showdown is active."
		return false

	var source: UnitState = state.unit_registry.get_unit(source_unit_uid)
	if source == null:
		_error_message = "Invalid USE_ACTION: source unit not found in registry."
		return false

	if source.player_id != player_id:
		_error_message = "Invalid USE_ACTION: unit does not belong to this player."
		return false

	var effect: EffectInstance = _find_effect(source)
	if effect == null:
		_error_message = "Invalid USE_ACTION: effect uid not found on unit."
		return false

	if effect.timing_window != "action":
		_error_message = "Invalid USE_ACTION: effect is not an ACTION ability."
		return false

	if not effect.ability_fn.is_valid():
		_error_message = "Invalid USE_ACTION: effect has no ability function."
		return false

	return true

func execute(state: GameState) -> void:
	var source: UnitState = state.unit_registry.get_unit(source_unit_uid)
	var effect: EffectInstance = _find_effect(source)

	state.timing_manager.queue_action(effect, source, state.active_combat_context)

	# Reset pass flags so the opponent can respond to this action
	state.active_showdown.reset_passes()

	state.add_event("P%d used ACTION ability (effect_uid=%d) on unit uid=%d." % [
		player_id, effect_uid, source_unit_uid
	])

func get_error_message() -> String:
	return _error_message

func _find_effect(source: UnitState) -> EffectInstance:
	for e in source.effects.get_all():
		if e.uid == effect_uid:
			return e
	return null
