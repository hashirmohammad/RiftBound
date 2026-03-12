class_name RuneInstance
extends RefCounted

enum RuneType {
	FURY,
	CALM,
	BODY,
	MIND,
	ORDER,
	CHAOS
}

enum State {
	AWAKEN,
	EXHAUSTED
}

enum Zone {
	RUNE_DECK,
	RUNE_POOL
}

var uid: int
var rune_type: RuneType
var state: State = State.AWAKEN
var zone: Zone  = Zone.RUNE_DECK

func _init(_uid: int, _rune_type: RuneType) -> void:
	uid = _uid
	rune_type = _rune_type

func exhaust() -> void:
	state = State.EXHAUSTED

func awaken() -> void:
	state = State.AWAKEN

func is_exhausted() -> bool:
	return state == State.EXHAUSTED
	
func type_name() -> String:
	return RuneType.keys()[rune_type] 
