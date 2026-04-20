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
	if player_id != state.get_active_player().id:
		_error_message = "Invalid RUNE_PICKED: not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid RUNE_PICKED: not in MAIN phase."
		return false

	if not state.awaiting_rune_payment:
		_error_message = "Invalid RUNE_PICKED: no card is waiting for payment."
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

	if state.selected_rune_uids.has(rune.uid):
		_error_message = "Invalid RUNE_PICKED: rune already selected."
		return false

	return true

func execute(state: GameState) -> void:
	var p: PlayerState = state.players[state.pending_payment_player_id]
	var rune: RuneInstance = _find_rune_in_pool(p)

	if rune == null:
		state.add_event("RUNE_PICKED execute failed: rune disappeared from pool.")
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
	p.runes_spent_this_turn += 1

	state.add_event("P%d spends rune %s (uid=%d)." % [
		p.id, rune.name(), rune.uid
	])

	# Still not enough runes selected yet
	if state.selected_rune_uids.size() < state.pending_card_cost:
		state.add_event("P%d has paid %d / %d runes for pending card." % [
			p.id,
			state.selected_rune_uids.size(),
			state.pending_card_cost
		])
		return

	# Enough runes selected: finalize the pending card play
	var card := GameEngine.find_card_in_hand_by_uid(p, state.pending_card_uid)
	if card == null:
		state.add_event("Finalize pending play failed: card not found in hand.")
		state.clear_rune_payment_state()
		return

	var paid_cost := state.pending_card_cost
	var pending_slot := state.pending_slot_index

	GameEngine.finalize_card_play(state, p, card, pending_slot)

	state.add_event("P%d finished paying %d runes for %s." % [
		p.id,
		paid_cost,
		card.data.card_name
	])

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
