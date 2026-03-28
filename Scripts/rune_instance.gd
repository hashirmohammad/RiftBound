class_name RuneInstance
extends RefCounted

enum State {
	AWAKEN,
	EXHAUSTED
}

enum Zone {
	RUNE_DECK,
	RUNE_POOL
}

var uid: int
var rune_type: CardData.Rune
var state: State = State.AWAKEN
var zone: Zone  = Zone.RUNE_DECK

func _init(_uid: int, _rune_type: CardData.Rune) -> void:
	uid = _uid
	rune_type = _rune_type

func exhaust() -> void:
	state = State.EXHAUSTED

func awaken() -> void:
	state = State.AWAKEN

func is_exhausted() -> bool:
	return state == State.EXHAUSTED
	
func type_name() -> String:
	return CardData.Rune.keys()[rune_type] 
