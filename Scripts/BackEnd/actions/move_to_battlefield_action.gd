class_name MoveToBattlefieldAction
extends GameAction

var card_uid: int = -1
var battlefield_index: int = -1
var _error_message: String = "Invalid MOVE_TO_BATTLEFIELD."

func _init(_player_id: int = -1, _card_uid: int = -1, _battlefield_index: int = -1):
	super(_player_id)
	card_uid = _card_uid
	battlefield_index = _battlefield_index

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Not in MAIN phase."
		return false

	if state.awaiting_rune_payment:
		_error_message = "Cannot move to battlefield while paying runes."
		return false

	if state.awaiting_showdown:
		_error_message = "Cannot move to battlefield while a showdown is active."
		return false

	if state.awaiting_damage_assignment:
		_error_message = "Cannot move to battlefield while damage assignment is pending."
		return false

	if battlefield_index < 0 or battlefield_index >= state.get_active_player().battlefield_slots.size():
		_error_message = "Invalid battlefield slot."
		return false

	var p := state.get_active_player()
	var card := _find_card_on_board(p)

	if card == null:
		_error_message = "Card uid %d not found on board." % card_uid
		return false

	if card.is_exhausted():
		_error_message = "Card must be AWAKEN to move to battlefield."
		return false

	var board_slot_index := _find_board_slot_index(p, card)
	if board_slot_index == -1:
		_error_message = "Card uid %d is not in a valid board slot." % card_uid
		return false

	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()
	var card := _find_card_on_board(p)

	if card == null:
		state.add_event("MOVE_TO_BATTLEFIELD failed: card disappeared from board.")
		return

	var board_slot_index := _find_board_slot_index(p, card)
	if board_slot_index == -1:
		state.add_event("MOVE_TO_BATTLEFIELD failed: card not found in any board slot.")
		return

	var ok := GameEngine.move_card_from_board_to_battlefield(
		p,
		card,
		board_slot_index,
		battlefield_index
	)

	if not ok:
		state.add_event("MOVE_TO_BATTLEFIELD failed for uid=%d." % card.uid)
		return

	state.add_event(
		"P%d moved %s from board slot %d to battlefield slot %d." % [
			p.id,
			card.data.card_name,
			board_slot_index,
			battlefield_index
		]
	)

func get_error_message() -> String:
	return _error_message

func _find_card_on_board(player: PlayerState) -> CardInstance:
	for slot in player.board_slots:
		for card in slot:
			if card.uid == card_uid:
				return card
	return null

func _find_board_slot_index(player: PlayerState, target_card: CardInstance) -> int:
	for i in range(player.board_slots.size()):
		if player.board_slots[i].has(target_card):
			return i
	return -1
