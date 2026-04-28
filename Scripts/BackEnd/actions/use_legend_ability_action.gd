class_name UseLegendAbilityAction
extends GameAction

var target_uid: int = -1
var _error_message := "Invalid legend ability."

func _init(_player_id: int = -1, _target_uid: int = -1):
	super(_player_id)
	target_uid = _target_uid

func validate(state: GameState) -> bool:
	var p: PlayerState = state.players[player_id]

	if p.legend == null:
		_error_message = "No legend."
		return false

	if p.legend.is_exhausted():
		_error_message = "Legend is exhausted."
		return false

	if not EffectResolver.has_awake_rune(p, 1):
		_error_message = "Need 1 awake rune."
		return false

	var target := state.unit_registry.get_by_uid(target_uid)
	if target == null:
		_error_message = "Invalid target."
		return false

	if target.player_id != player_id:
		_error_message = "Target must be friendly."
		return false

	if not LegendAbilityRegistry.can_use(state, player_id, target_uid):
		_error_message = "Cannot use legend ability."
		return false

	return true

func execute(state: GameState) -> void:
	LegendAbilityRegistry.use(state, player_id, target_uid)

func get_error_message() -> String:
	return _error_message
