class_name ReturnFromBattlefieldAction
extends GameAction

var card_uid: int = -1
var battlefield_index: int = -1
var board_slot_index: int = 0
var _error_message: String = "Invalid RETURN_FROM_BATTLEFIELD."

func _init(_player_id: int = -1, _card_uid: int = -1, _battlefield_index: int = -1, _board_slot_index: int = 0):
	super(_player_id)
	card_uid = _card_uid
	battlefield_index = _battlefield_index
	board_slot_index = _board_slot_index

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Not in MAIN phase."
		return false

	if state.awaiting_rune_payment:
		_error_message = "Cannot return from battlefield while paying runes."
		return false

	if state.awaiting_showdown:
		_error_message = "Cannot return from battlefield while a showdown is active."
		return false

	if state.awaiting_damage_assignment:
		_error_message = "Cannot return from battlefield while damage assignment is pending."
		return false

	var p := state.get_active_player()

	if battlefield_index < 0 or battlefield_index >= p.battlefield_slots.size():
		_error_message = "Invalid battlefield slot."
		return false

	if board_slot_index < 0 or board_slot_index >= p.board_slots.size():
		_error_message = "Board slot index out of range."
		return false

	if _find_card_in_battlefield(p) == null:
		_error_message = "Card uid %d not found in battlefield slot %d." % [card_uid, battlefield_index]
		return false

	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()
	var card := _find_card_in_battlefield(p)

	if card == null:
		state.add_event("RETURN_FROM_BATTLEFIELD failed: card disappeared from battlefield.")
		return

	var ok := GameEngine.move_card_from_battlefield_to_board(
		p,
		card,
		battlefield_index,
		board_slot_index
	)

	if not ok:
		state.add_event("RETURN_FROM_BATTLEFIELD failed for uid=%d." % card.uid)
		return

	state.add_event("P%d returned %s from battlefield slot %d to board slot %d." % [
		p.id, card.data.card_name, battlefield_index, board_slot_index
	])

func get_error_message() -> String:
	return _error_message

func _find_card_in_battlefield(player: PlayerState) -> CardInstance:
	if battlefield_index < 0 or battlefield_index >= player.battlefield_slots.size():
		return null

	for card in player.battlefield_slots[battlefield_index]:
		if card.uid == card_uid:
			return card
	return null
