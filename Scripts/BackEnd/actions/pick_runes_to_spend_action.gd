class_name PickRuneAction
extends GameAction

var rune_uid: int = -1
var _error_message: String = "Invalid RUNE_PICKED."
var slot_index: int = -1

# Set to false when rune loading is confirmed working
const DEBUG_FREE_PLAY := false

func _init(_player_id: int = -1, _rune_uid: int = -1, _slot_index: int = -1):
	super(_player_id)
	rune_uid = _rune_uid
	slot_index = _slot_index

func validate(state: GameState) -> bool:
	if not state.awaiting_rune_payment:
		_error_message = "Invalid RUNE_PICKED: no card is waiting for payment."
		return false

	if state.pending_payment_player_id < 0 or state.pending_payment_player_id >= state.players.size():
		_error_message = "Invalid RUNE_PICKED: invalid paying player."
		return false

	if player_id != state.pending_payment_player_id:
		_error_message = "Invalid RUNE_PICKED: wrong paying player."
		return false

	var p: PlayerState = state.players[state.pending_payment_player_id]
	var rune := _find_rune_in_pool(p)

	if rune == null:
		_error_message = "Invalid RUNE_PICKED: rune uid not found in pool."
		return false

	if rune.is_exhausted():
		_error_message = "P%d cannot pick rune: rune is already exhausted." % p.id
		return false

	return true

func execute(state: GameState) -> void:
	var p : PlayerState = state.players[state.pending_payment_player_id]

	var rune: RuneInstance = _find_rune_in_pool(p)
	if rune == null:
		return

	if not state.awaiting_rune_payment:
		state.add_event("RUNE_PICKED ignored: no pending card payment.")
		return

	if state.selected_rune_uids.has(rune.uid):
		state.add_event("RUNE_PICKED ignored: rune already selected.")
		return

	var ok := p.spend_runes(rune)
	if not ok:
		state.add_event("P%d failed to spend rune %d." % [p.id, rune.uid])
		return

	state.selected_rune_uids.append(rune.uid)

	state.add_event("P%d spends rune %s (uid=%d)." % [
		p.id, rune.name(), rune.uid
	])

	if state.selected_rune_uids.size() >= state.pending_card_cost:
		_finalize_pending_card_play(state)

func _finalize_pending_card_play(state: GameState) -> void:
	var p: PlayerState = state.players[state.pending_payment_player_id]

	var hand_index := _find_pending_card_index(p, state.pending_card_uid)
	if hand_index == -1:
		state.add_event("Finalize pending play failed: card not found in hand.")
		_clear_pending_payment(state)
		return

	var card: CardInstance = p.hand[hand_index]

	if card.data.type == CardData.CardType.SPELL:
		PlayCardAction.finalize_spell_play(state, p, card)
	else:
		PlayCardAction.finalize_play(state, p, card, state.pending_slot_index)

	_clear_pending_payment(state)

func _find_pending_card_index(player: PlayerState, target_uid: int) -> int:
	for i in range(player.hand.size()):
		if player.hand[i].uid == target_uid:
			return i
	return -1

func _clear_pending_payment(state: GameState) -> void:
	state.exit_rune_payment()

func get_error_message() -> String:
	return _error_message

func _find_rune_index(player: PlayerState) -> int:
	for i in range(player.rune_pool.size()):
		if player.rune_pool[i].uid == rune_uid:
			return i
	return -1

func _find_rune_in_pool(player: PlayerState) -> RuneInstance:
	var idx := _find_rune_index(player)
	if idx == -1:
		return null
	return player.rune_pool[idx]
