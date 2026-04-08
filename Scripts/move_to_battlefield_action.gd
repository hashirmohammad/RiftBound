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

	if battlefield_index < 0 or battlefield_index > 1:
		_error_message = "Invalid battlefield slot."
		return false

	var card := _find_card_on_board(state.get_active_player())
	if card == null:
		_error_message = "Card uid %d not found on board." % card_uid
		return false

	if card.is_exhausted():
		_error_message = "Card must be AWAKEN to move to battlefield."
		return false

	return true

func execute(state: GameState) -> void:
	var p = state.get_active_player()
	var card = _find_card_on_board(p)
	if card == null:
		return

	for slot in p.board_slots:
		if slot.has(card):
			slot.erase(card)
			break

	card.zone = CardInstance.Zone.ARENA
	card.exhaust()
	p.battlefield_slots[battlefield_index].append(card)

	state.add_event(
		"P%d moved %s to battlefield slot %d." % [p.id, card.data.card_name, battlefield_index]
	)

func get_error_message() -> String:
	return _error_message

func _find_card_on_board(player: PlayerState) -> CardInstance:
	for slot in player.board_slots:
		for card in slot:
			if card.uid == card_uid:
				return card
	return null
