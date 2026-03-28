class_name CardInstance
extends RefCounted

enum CardState { AWAKEN, EXHAUSTED }
enum Zone { DECK, HAND, BOARD, TRASH, ARENA }

var uid: int
var data: CardData

var zone: Zone = Zone.DECK
var state: CardState = CardState.AWAKEN


func _init(_uid: int, _data: CardData):
	uid = _uid
	data = _data


func exhaust() -> void:
	state = CardState.EXHAUSTED


func awaken() -> void:
	state = CardState.AWAKEN


func is_exhausted() -> bool:
	return state == CardState.EXHAUSTED


func name() -> String:
	return data.card_name


func debug_string() -> String:
	return "%s(uid=%d, zone=%d, state=%d)" % [data.card_name, uid, zone, state]
