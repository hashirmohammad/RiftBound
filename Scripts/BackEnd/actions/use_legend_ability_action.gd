class_name UseLegendAbilityAction
extends GameAction

var target_uid: int = -1
var _error_message := "Invalid legend ability."

func _init(_player_id: int = -1, _target_uid: int = -1):
	super(_player_id)
	target_uid = _target_uid

func validate(state: GameState) -> bool:
	if not LegendAbilityRegistry.can_use(state, player_id, target_uid):
		_error_message = "Cannot use legend ability."
		return false

	return true

func execute(state: GameState) -> void:
	LegendAbilityRegistry.use(state, player_id, target_uid)

func get_error_message() -> String:
	return _error_message
