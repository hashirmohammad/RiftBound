class_name PickRuneAction
extends GameAction

var card_uid: int = -1
var slot_index: int = -1
var _error_message: String = "Invalid RUNE_PICKED."

# Set to false when rune loading is confirmed working
const DEBUG_FREE_PLAY := false

func _init(_player_id: int = -1, _card_uid: int = -1, _slot_index: int = -1):
	super(_player_id)
	card_uid = _card_uid
	slot_index = _slot_index

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Invalid RUNE_PICKED: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid RUNE_PICKED: not in MAIN phase."
		return false

	var p := state.get_active_player()
	var rune := _find_card_in_hand(p)

	if rune == null:
		_error_message = "Invalid RUNE_PICKED: rune uid not found in pool."
		return false

	if rune.is_exhausted():
		_error_message = "P%d cannot pick rune: rune is already exhausted." % p.id
		return false

	return true

func execute(state: GameState) -> void:
	pass

func get_error_message() -> String:
	return _error_message

func _find_hand_index(player: PlayerState) -> int:
	for i in range(player.rune_pool.size()):
		if player.rune_pool[i].uid == card_uid:
			return i
	return -1

func _find_card_in_hand(player: PlayerState) -> RuneInstance:
	var idx := _find_hand_index(player)
	if idx == -1:
		return null
	return player.rune_pool[idx]
