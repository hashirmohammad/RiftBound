class_name CardInstance
extends RefCounted

enum CardState { AWAKEN, EXHAUSTED }
enum Zone { DECK, HAND, BOARD, TRASH, ARENA }

var uid: int
var data: CardData

var zone: Zone = Zone.DECK
var state: CardState = CardState.EXHAUSTED
var current_health: int = 0


func _init(_uid: int, _data: CardData):
	uid = _uid
	data = _data
	current_health = _data.health


func exhaust() -> void:
	state = CardState.EXHAUSTED


func awaken() -> void:
	state = CardState.AWAKEN


func is_exhausted() -> bool:
	return state == CardState.EXHAUSTED


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)


func is_dead() -> bool:
	return data.health > 0 and current_health <= 0


func reset_health() -> void:
	current_health = data.health


func name() -> String:
	return data.card_name


func debug_string() -> String:
	return "%s(uid=%d, zone=%d, state=%d)" % [data.card_name, uid, zone, state]
