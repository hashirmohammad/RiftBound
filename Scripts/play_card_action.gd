class_name PlayCardAction
extends GameAction

var card_uid: int = -1
var slot_index: int = -1
var _error_message: String = "Invalid PLAY_CARD."

func _init(_player_id: int = -1, _card_uid: int = -1, _slot_index: int = -1):
	super(_player_id)
	card_uid = _card_uid
	slot_index = _slot_index

func validate(state: GameState) -> bool:
	
	if player_id != state.get_active_player().id:
		_error_message = "Invalid PLAY_CARD: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid PLAY_CARD: not in MAIN phase."
		return false

	var p := state.get_active_player()
	var card := _find_card_in_hand(p)

	if card == null:
		_error_message = "Invalid PLAY_CARD: card uid not found in hand."
		return false

	if p.rune_count_in_pool() < card.data.cost:
		_error_message = "P%d cannot play card: not enough runes." % p.id
		return false

	if slot_index < 0 or slot_index >= p.board_slots.size():
		_error_message = "Invalid PLAY_CARD: slot index out of range."
		return false

	if p.board_slots[slot_index] != null:
		_error_message = "Invalid PLAY_CARD: target slot already occupied."
		return false
	print("slot_index=", slot_index, " board_slots.size()=", p.board_slots.size())
	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()
	var hand_index := _find_hand_index(p)

	if hand_index == -1:
		state.add_event("PLAY_CARD execute failed: card disappeared from hand.")
		return

	var card: CardInstance = p.hand[hand_index]
	var cost := card.data.cost

	card.zone = CardInstance.Zone.BOARD
	p.spend_runes(p.rune_pool.slice(0, cost))
	p.hand.remove_at(hand_index)
	card.exhaust()

	p.board_slots[slot_index] = card

	# Temporary compatibility with existing code
	if not p.board.has(card):
		p.board.append(card)

	state.add_event("P%d played %s into slot %d (cost %d)." % [
		p.id, card.data.card_name, slot_index, cost
	])

func get_error_message() -> String:
	return _error_message

func _find_hand_index(player: PlayerState) -> int:
	for i in range(player.hand.size()):
		if player.hand[i].uid == card_uid:
			return i
	return -1

func _find_card_in_hand(player: PlayerState) -> CardInstance:
	var idx := _find_hand_index(player)
	if idx == -1:
		return null
	return player.hand[idx]
