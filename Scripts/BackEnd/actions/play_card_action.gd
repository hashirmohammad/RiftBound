class_name PlayCardAction
extends GameAction

var card_uid: int = -1
var slot_index: int = -1
var _error_message: String = "Invalid PLAY_CARD."

# Set to false when rune loading is confirmed working
const DEBUG_FREE_PLAY := false
const SpellRegistry = preload("res://Scripts/BackEnd/spell/spell_registry.gd")

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

	var total_cost: int = _get_total_play_cost(card, state)
	if p.awaken_rune_count() < total_cost:
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

	var total_cost: int = _get_total_play_cost(card, state)
	
	if total_cost <= 0:
		if card.data.type == CardData.CardType.SPELL:
			PlayCardAction.finalize_spell_play(state, p, card)
		else:
			PlayCardAction.finalize_play(state, p, card, slot_index)
		return

	state.awaiting_rune_payment = true
	state.pending_payment_player_id = p.id
	state.pending_card_uid = card.uid
	state.pending_slot_index = slot_index
	state.pending_card_cost = total_cost
	state.selected_rune_uids.clear()

	state.add_event("P%d started paying %d runes for %s." % [
		p.id, total_cost, card.data.card_name
	])

func _get_total_play_cost(card: CardInstance, state: GameState) -> int:
	var total: int = _get_modified_base_cost(card, state)

	if bool(state.pending_play_metadata.get("accelerate", false)):
		total += int(state.pending_play_metadata.get("accelerate_cost", 1))

	if bool(state.pending_play_metadata.get("extra_calm_paid", false)):
		total += 1

	return total

static func finalize_play(state: GameState, p: PlayerState, card: CardInstance, slot_index: int) -> void:
	var hand_index := -1
	for i in range(p.hand.size()):
		if p.hand[i].uid == card.uid:
			hand_index = i
			break

	if hand_index == -1:
		state.add_event("PLAY_CARD finalize failed: card disappeared from hand.")
		return

	p.hand.remove_at(hand_index)
	card.zone = CardInstance.Zone.BOARD

	var accelerated: bool = bool(state.pending_play_metadata.get("accelerate", false))
	print("DEBUG accelerated = %s" % [str(accelerated)])

	if accelerated:
		card.awaken()
		state.add_event("%s entered ready via Accelerate." % card.data.card_name)
	else:
		card.exhaust()

	p.board_slots[slot_index].append(card)

	state.add_event("P%d played %s into slot %d." % [
		p.id, card.data.card_name, slot_index
	])

	var created_unit: UnitState = null

	if card.data.type == CardData.CardType.UNIT or card.data.type == CardData.CardType.CHAMPION:
		var unit := UnitState.new(card, p.id)

		for effect in KeywordParser.parse(card.data, state):
			unit.effects.add(effect)

		var extra_fn := CardAbilityRegistry.get_extra_unit_effects_fn(card.data.card_id)
		if extra_fn.is_valid():
			var extra_effects: Array[EffectInstance] = extra_fn.call(unit, state)
			for e in extra_effects:
				unit.effects.add(e)

		state.unit_registry.register(unit)
		created_unit = unit

		state.add_event("P%d unit registered: %s (uid=%d)." % [
			p.id, card.data.card_name, card.uid
		])

	var on_play_fn := CardAbilityRegistry.get_on_play_fn(card.data.card_id)
	if on_play_fn.is_valid():
		var payload: Dictionary = state.pending_play_metadata.duplicate(true)
		if created_unit != null:
			on_play_fn.call(created_unit, state, payload)
		else:
			on_play_fn.call(card, state, payload)

	state.pending_play_metadata.clear()

static func finalize_spell_play(state: GameState, p: PlayerState, card: CardInstance) -> void:
	var hand_index := -1
	for i in range(p.hand.size()):
		if p.hand[i].uid == card.uid:
			hand_index = i
			break

	if hand_index == -1:
		state.add_event("SPELL finalize failed: card disappeared from hand.")
		return

	p.hand.remove_at(hand_index)

	var resolver := SpellRegistry.get_resolver(card.data.card_id)
	if resolver.is_valid():
		var payload: Dictionary = state.pending_play_metadata.duplicate(true)
		resolver.call(card, state, payload)
	else:
		state.add_event("No spell resolver found for %s." % card.data.card_name)

	card.zone = CardInstance.Zone.TRASH
	p.trash.append(card)

	state.add_event("P%d played %s and sent it to trash." % [
		p.id, card.data.card_name
	])

	state.pending_play_metadata.clear()
	
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

func _get_modified_base_cost(card: CardInstance, state: GameState) -> int:
	var cost: int = card.data.cost

	match card.data.card_id:
		"OGN-047/298": # Find Your Center
			var opponent_id: int = 1 - player_id
			var opponent: PlayerState = state.players[opponent_id]

			# Replace with your real victory-score field if named differently
			var victory_score: int = state.POINTS_TO_WIN
			if victory_score - opponent.points <= 3:
				cost -= 2

	return maxi(cost, 0)
