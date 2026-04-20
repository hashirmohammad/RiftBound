class_name PlayCardAction
extends GameAction

var card_uid: int = -1
var slot_index: int = -1
var _error_message: String = "Invalid PLAY_CARD."

# Set to false when rune loading is confirmed working
const DEBUG_FREE_PLAY := false

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

	if p.awaken_rune_count() < card.data.cost:
		_error_message = "P%d cannot play card: not enough runes." % p.id
		return false
	if slot_index < 0 or slot_index >= p.board_slots.size():
		_error_message = "Invalid PLAY_CARD: slot index out of range."
		return false
		
	if state.awaiting_rune_payment:
		_error_message = "Invalid PLAY_CARD: already waiting for rune payment."
		return false
	
	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()
	var card := _find_card_in_hand(p)

	if card == null:
		state.add_event("PLAY_CARD execute failed: card disappeared from hand.")
		return

	if card.data.cost <= 0:
		_finalize_play(state, p, card)
		return

	state.awaiting_rune_payment = true
	state.pending_payment_player_id = p.id
	state.pending_card_uid = card.uid
	state.pending_slot_index = slot_index
	state.pending_card_cost = card.data.cost
	state.selected_rune_uids.clear()

	state.add_event("P%d started paying %d runes for %s." % [
		p.id, card.data.cost, card.data.card_name
	])

func _finalize_play(state: GameState, p: PlayerState, card: CardInstance) -> void:
	var hand_index := _find_hand_index(p)
	if hand_index == -1:
		state.add_event("PLAY_CARD finalize failed: card disappeared from hand.")
		return

	p.hand.remove_at(hand_index)
	card.zone = CardInstance.Zone.BOARD
	card.exhaust()
	p.board_slots[slot_index].append(card)

	state.add_event("P%d played %s into slot %d." % [
		p.id, card.data.card_name, slot_index
	])

	if card.data.type == CardData.CardType.UNIT or card.data.type == CardData.CardType.CHAMPION:
		var unit := UnitState.new(card, p.id)
		for effect in KeywordParser.parse(card.data, state):
			unit.effects.add(effect)
		state.unit_registry.register(unit)
		state.add_event("P%d unit registered: %s (uid=%d)." % [p.id, card.data.card_name, card.uid])

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
