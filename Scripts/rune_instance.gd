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
var rune: CardData
var state: State = State.AWAKEN
var zone: Zone  = Zone.RUNE_DECK

func _init(_uid: int, _rune: CardData) -> void:
	uid = _uid
	rune = _rune

func exhaust() -> void:
	state = State.EXHAUSTED

func awaken() -> void:
	state = State.AWAKEN

func is_exhausted() -> bool:
	return state == State.EXHAUSTED
	
func name() -> String:
	return rune.card_name
