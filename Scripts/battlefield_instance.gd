class_name BattlefieldInstance
extends RefCounted

enum State {
	UNUSED,
	USED
}

var uid: int
var battlefield: CardData
var state: State  = State.UNUSED

func _init(_uid: int, _battlefield: CardData) -> void:
	uid = _uid
	battlefield = _battlefield

func set_state(_state: State) -> void:
	state = _state
	
func is_picked() -> bool:
	if state == State.USED:
		return true
	return false

func name() -> String:
	return battlefield.card_name
