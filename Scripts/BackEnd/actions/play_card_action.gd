class_name PlayCardAction
extends GameAction

var card_uid: int = -1
var slot_index: int = -1
var _error_message: String = "Invalid PLAY_CARD."

# Set to false when rune loading is confirmed working
const DEBUG_FREE_PLAY := false

const DEADBLOOM_CARD_ID := "OGN-161/298"
const TARGET_ENEMY_BATTLEFIELD_LEFT  := -100
const TARGET_ENEMY_BATTLEFIELD_RIGHT := -101

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

	if state.awaiting_rune_payment:
		_error_message = "Invalid PLAY_CARD: already waiting for rune payment."
		return false

	var p := state.get_active_player()
	var card := _find_card_in_hand(p)

	if card == null:
		_error_message = "Invalid PLAY_CARD: card uid not found in hand."
		return false

	if _is_deadbloom_enemy_battlefield_target():
		if not _validate_deadbloom_target(state, p, card):
			return false
	else:
		if slot_index < 0 or slot_index >= p.board_slots.size():
			_error_message = "Invalid PLAY_CARD: slot index out of range."
			return false

	if p.awaken_rune_count() < card.data.cost:
		_error_message = "P%d cannot play card: not enough runes." % p.id
		return false

	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()
	var card := _find_card_in_hand(p)

	if card == null:
		state.add_event("PLAY_CARD execute failed: card disappeared from hand.")
		return

	if card.data.cost <= 0:
		if _is_deadbloom_enemy_battlefield_target():
			GameEngine.finalize_deadbloom_play(state, p, card, _deadbloom_battlefield_index())
		else:
			GameEngine.finalize_card_play(state, p, card, slot_index)
		return

	state.awaiting_rune_payment = true
	state.pending_payment_player_id = p.id
	state.pending_card_uid = card.uid
	state.pending_slot_index = slot_index
	state.pending_card_cost = card.data.cost
	state.selected_rune_uids.clear()

	if _is_deadbloom_enemy_battlefield_target():
		state.add_event("P%d started paying %d runes for %s to enemy battlefield %d." % [
			p.id, card.data.cost, card.data.card_name, _deadbloom_battlefield_index()
		])
	else:
		state.add_event("P%d started paying %d runes for %s." % [
			p.id, card.data.cost, card.data.card_name
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

func _is_deadbloom_enemy_battlefield_target() -> bool:
	return slot_index == TARGET_ENEMY_BATTLEFIELD_LEFT or slot_index == TARGET_ENEMY_BATTLEFIELD_RIGHT

func _deadbloom_battlefield_index() -> int:
	if slot_index == TARGET_ENEMY_BATTLEFIELD_LEFT:
		return 0
	if slot_index == TARGET_ENEMY_BATTLEFIELD_RIGHT:
		return 1
	return -1

func _validate_deadbloom_target(state: GameState, player: PlayerState, card: CardInstance) -> bool:
	if card.data.card_id != DEADBLOOM_CARD_ID:
		_error_message = "Only Deadbloom Predator can be played to an occupied enemy battlefield."
		return false

	var battlefield_index := _deadbloom_battlefield_index()
	if battlefield_index < 0 or battlefield_index >= player.battlefield_slots.size():
		_error_message = "Invalid Deadbloom battlefield target."
		return false

	var opponent := state.get_opponent()
	if opponent == null:
		_error_message = "Deadbloom target failed: opponent missing."
		return false

	if opponent.battlefield_slots[battlefield_index].is_empty():
		_error_message = "Deadbloom Predator can only be played to an occupied enemy battlefield."
		return false

	return true
