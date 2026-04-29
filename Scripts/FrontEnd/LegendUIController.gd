class_name LegendUIController
extends RefCounted

const GameEngine = preload("res://Scripts/BackEnd/core/game_engine.gd")
const UseLegendAbilityAction = preload("res://Scripts/BackEnd/actions/use_legend_ability_action.gd")

var controller: Node
var state: GameState
var status_label: Label

var legend_mode := false
var legend_player_id := -1


func setup(_controller: Node, _state: GameState, _status_label: Label) -> void:
	controller = _controller
	state = _state
	status_label = _status_label


func start_legend_mode(player_id: int = -1) -> void:
	var player: PlayerState

	if player_id == -1:
		player = controller.get_actor_player()
	else:
		player = state.players[player_id]

	if player.legend == null:
		status_label.text = "No legend available."
		return

	legend_mode = true
	legend_player_id = player.id
	status_label.text = "Select a friendly unit for legend ability."


func cancel_legend_mode() -> void:
	legend_mode = false
	legend_player_id = -1


func try_use_legend_ability(target_uid: int) -> bool:
	if not legend_mode:
		status_label.text = "Legend mode is not active."
		return false

	if legend_player_id < 0:
		status_label.text = "No legend player selected."
		return false

	var action := UseLegendAbilityAction.new(legend_player_id, target_uid)

	var success := controller._apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	legend_mode = false
	legend_player_id = -1
	controller.refresh_all_ui()
	return true
