class_name GameEngine

const OPENING_HAND_SIZE := 4
const DEBUG_FREE_RUNES := true
const DEBUG_STARTING_RUNES := 3

static func apply_action(state: GameState, action: GameAction) -> bool:
	if action == null:
		state.add_event("Invalid action: null action.")
		return false
	if not action.validate(state):
		state.add_event(action.get_error_message())
		return false
	action.execute(state)
	return true

static func start_game() -> GameState:
	var state := GameState.new()
	state.turn_system = PlayerTurn.new()
	state.unit_registry = UnitRegistry.new()
	state.timing_manager = TimingManager.new()
	state.combat_manager = CombatManager.new(state.unit_registry, state.timing_manager)

	var p0 := PlayerState.new(0)
	var p1 := PlayerState.new(1)
	state.players = [p0, p1]

	#var p0_deck_name: String = CardDatabase._random_deck_name()
	#var p1_deck_name: String = CardDatabase._random_deck_name()
	var p0_deck_name: String = "Lee Sin"
	var p1_deck_name: String = "Kai'Sa"
	
	state.deck_names[0] = p0_deck_name
	state.deck_names[1] = p1_deck_name
	state.add_event("P0 deck: %s | P1 deck: %s" % [p0_deck_name, p1_deck_name])

	var p0_legend_data := CardDatabase._load_legend(p0_deck_name)
	var p1_legend_data := CardDatabase._load_legend(p1_deck_name)
	if p0_legend_data:
		p0.legend = CardInstance.new(state.next_uid(), p0_legend_data)
	if p1_legend_data:
		p1.legend = CardInstance.new(state.next_uid(), p1_legend_data)

	# ── Load battlefields and pick 1 of 3 ─────────────────────────────────────
	for b in CardDatabase._load_battlefields_from_deck(p0_deck_name):
		p0.battlefields.append(BattlefieldInstance.new(state.next_uid(), b))
	for b in CardDatabase._load_battlefields_from_deck(p1_deck_name):
		p1.battlefields.append(BattlefieldInstance.new(state.next_uid(), b))

	p0.pick_random_battlefield()
	p1.pick_random_battlefield()

	for cd in CardDatabase._load_cards_from_deck(p0_deck_name):
		p0.deck.append(CardInstance.new(state.next_uid(), cd))
	for cd in CardDatabase._load_cards_from_deck(p1_deck_name):
		p1.deck.append(CardInstance.new(state.next_uid(), cd))

	p0.deck.shuffle()
	p1.deck.shuffle()

	for rd in CardDatabase._load_runes_from_deck(p0_deck_name):
		var rune := RuneInstance.new(state.next_uid(), rd)
		rune.zone = RuneInstance.Zone.RUNE_DECK
		p0.rune_deck.append(rune)
	for rd in CardDatabase._load_runes_from_deck(p1_deck_name):
		var rune := RuneInstance.new(state.next_uid(), rd)
		rune.zone = RuneInstance.Zone.RUNE_DECK
		p1.rune_deck.append(rune)

	p0.rune_deck.shuffle()
	p1.rune_deck.shuffle()
	
	#_give_debug_card_to_hand(p0, "OGN-151/298") # Lee Sin, Centered
	#_give_debug_card_to_hand(p0, "OGN-155/298")  # Qiyana, Victorious
	_give_debug_card_to_hand(p0, "OGN-161/298")  # Deadbloom Predator
	for i in range(OPENING_HAND_SIZE):
		state.turn_system._draw_card(p0)
		state.turn_system._draw_card(p1)

	state.active_player_index = 0
	state.turn_number = 1
	state.phase = "START"

	start_turn(state)

	state.add_event("Game started. P0 goes first.")
	return state

static func start_turn(state: GameState) -> void:
	if state.turn_system == null:
		state.add_event("ERROR: turn_system not initialized.")
		return
	state.turn_system.start_turn(state)

static func end_turn(state: GameState) -> void:
	state.active_player_index = 1 - state.active_player_index
	state.turn_number += 1
	start_turn(state)

static func finalize_card_play(state: GameState, player: PlayerState, card: CardInstance, slot_index: int) -> void:
	if state == null or player == null or card == null:
		return

	if _is_deadbloom_enemy_battlefield_target(card, slot_index):
		finalize_deadbloom_play(state, player, card, _deadbloom_battlefield_index(slot_index))
		return

	# Remove from hand
	if player.hand.has(card):
		player.hand.erase(card)

	# Update card state
	card.zone = CardInstance.Zone.BOARD
	card.exhaust()

	# Add to the player's board list
	if not player.board.has(card):
		player.board.append(card)

	# Place into the chosen board slot
	if slot_index >= 0 and slot_index < player.board_slots.size():
		if not player.board_slots[slot_index].has(card):
			player.board_slots[slot_index].append(card)

	# Count as a successful play
	player.cards_played_this_turn += 1

	# Clear temporary payment state
	state.clear_rune_payment_state()

	# Log event
	state.add_event("P%d played %s into board slot %d." % [player.id, card.data.card_name, slot_index])

	# Register runtime unit if this card is a unit/champion
	if card.data.type == CardData.CardType.UNIT or card.data.type == CardData.CardType.CHAMPION:
		var unit := UnitState.new(card, player.id)
		for effect in KeywordParser.parse(card.data, state):
			unit.effects.add(effect)
		state.unit_registry.register(unit)
		CardAbilityRegistry.attach_abilities(unit, state)
		state.add_event("P%d unit registered: %s (uid=%d)." % [player.id, card.data.card_name, card.uid])

static func finalize_deadbloom_play(state: GameState, player: PlayerState, card: CardInstance, battlefield_index: int) -> void:
	if state == null or player == null or card == null:
		return
	if battlefield_index < 0 or battlefield_index >= player.battlefield_slots.size():
		state.add_event("Deadbloom play failed: invalid battlefield index.")
		return

	# Remove from hand
	if player.hand.has(card):
		player.hand.erase(card)

	# Deadbloom enters battlefield directly
	card.zone = CardInstance.Zone.ARENA
	card.exhaust()

	if not player.battlefield_slots[battlefield_index].has(card):
		player.battlefield_slots[battlefield_index].append(card)

	# Count as a successful play
	player.cards_played_this_turn += 1

	# Clear temporary payment state
	state.clear_rune_payment_state()

	state.add_event("P%d played %s directly to battlefield %d." % [
		player.id, card.data.card_name, battlefield_index
	])

	# Register runtime unit if this card is a unit/champion
	if card.data.type == CardData.CardType.UNIT or card.data.type == CardData.CardType.CHAMPION:
		var unit := UnitState.new(card, player.id)
		for effect in KeywordParser.parse(card.data, state):
			unit.effects.add(effect)
		state.unit_registry.register(unit)
		CardAbilityRegistry.attach_abilities(unit, state)
		state.add_event("P%d unit registered: %s (uid=%d)." % [player.id, card.data.card_name, card.uid])

static func _is_deadbloom_enemy_battlefield_target(card: CardInstance, slot_index: int) -> bool:
	if card == null or card.data == null:
		return false
	return card.data.card_id == "OGN-161/298" and (
		slot_index == -100 or slot_index == -101
	)

static func _deadbloom_battlefield_index(slot_index: int) -> int:
	if slot_index == -100:
		return 0
	if slot_index == -101:
		return 1
	return -1
	
static func find_card_in_hand_by_uid(player: PlayerState, card_uid: int) -> CardInstance:
	for card in player.hand:
		if card.uid == card_uid:
			return card
	return null
		

static func move_card_from_board_to_battlefield(
	player: PlayerState,
	card: CardInstance,
	board_slot_index: int,
	battlefield_slot_index: int
) -> bool:
	if player == null or card == null:
		return false

	if board_slot_index < 0 or board_slot_index >= player.board_slots.size():
		return false

	if battlefield_slot_index < 0 or battlefield_slot_index >= player.battlefield_slots.size():
		return false

	# Remove from flat board list
	if player.board.has(card):
		player.board.erase(card)

	# Remove from board slot
	if player.board_slots[board_slot_index].has(card):
		player.board_slots[board_slot_index].erase(card)

	# Add to battlefield slot
	if not player.battlefield_slots[battlefield_slot_index].has(card):
		player.battlefield_slots[battlefield_slot_index].append(card)

	# Update card state
	card.zone = CardInstance.Zone.ARENA
	card.exhaust()

	player.units_moved_this_turn += 1
	return true

static func move_card_from_battlefield_to_board(
	player: PlayerState,
	card: CardInstance,
	battlefield_slot_index: int,
	board_slot_index: int
) -> bool:
	if player == null or card == null:
		return false

	if battlefield_slot_index < 0 or battlefield_slot_index >= player.battlefield_slots.size():
		return false

	if board_slot_index < 0 or board_slot_index >= player.board_slots.size():
		return false

	# Remove from battlefield
	if player.battlefield_slots[battlefield_slot_index].has(card):
		player.battlefield_slots[battlefield_slot_index].erase(card)

	# Add back to flat board list
	if not player.board.has(card):
		player.board.append(card)

	# Add back to board slot
	if not player.board_slots[board_slot_index].has(card):
		player.board_slots[board_slot_index].append(card)

	# Update card state
	card.zone = CardInstance.Zone.BOARD
	card.exhaust()

	player.units_moved_this_turn += 1
	return true

static func _give_debug_card_to_hand(player: PlayerState, card_id: String) -> void:
	for i in range(player.deck.size()):
		if player.deck[i].data.card_id == card_id:
			var card := player.deck[i]
			player.deck.remove_at(i)
			player.hand.append(card)
			card.zone = CardInstance.Zone.HAND
			return
