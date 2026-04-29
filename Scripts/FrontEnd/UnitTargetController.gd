class_name UnitTargetController
extends RefCounted

const CardAbilityRegistry = preload("res://Scripts/BackEnd/data/card_ability_registry.gd")

var controller: Node
var state: GameState
var status_label: Label


func setup(_controller: Node, _state: GameState, _status_label: Label) -> void:
	controller = _controller
	state = _state
	status_label = _status_label


func try_select_unit_target(target_uid: int) -> bool:
	if not state.awaiting_unit_target:
		return false

	CardAbilityRegistry.resolve_pending_unit_target(target_uid, state)

	controller.refresh_all_ui()
	return true
