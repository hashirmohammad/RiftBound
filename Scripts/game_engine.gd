class_name GameEngine

const OPENING_HAND_SIZE := 4
const DEFAULT_RUNE_DECK_SIZE := 12  # placeholder; adjust later

const GameActionScript = preload("res://Scripts/action.gd")

# -------------------------
# ACTION PIPELINE
# -------------------------
static func apply_action(state: GameState, action: GameAction) -> void:
	# Validate: correct player's turn
	if action.player_id != state.get_active_player().id:
		state.add_event("Invalid action: Not this player's turn.")
		return

	match action.type:
		GameActionScript.ActionType.END_TURN:
			# Only allow ending turn from MAIN phase
			if state.phase != "MAIN":
				state.add_event("Invalid END_TURN: not in MAIN phase.")
				return

			# Advance MAIN -> END (PlayerTurn handles END phase event)
			if state.turn_system != null:
				state.turn_system.next_phase()

			# Swap active player + increment turn + start next turn
			end_turn(state)

		GameActionScript.ActionType.PLAY_CARD:
			_play_card(state, action)

		_:
			state.add_event("Invalid action: Unknown action type.")


# -------------------------
# GAME LIFECYCLE
# -------------------------
static func start_game() -> GameState:
	var state := GameState.new()

	# Turn/phase controller
	state.turn_system = PlayerTurn.new()

	# Create players
	var p0 := PlayerState.new(0)
	var p1 := PlayerState.new(1)
	state.players = [p0, p1]
	
	# Load battlefields
	var p0_all_battlefields: Array[CardData] = CardDatabase._load_battlefields("Jinx")
	var p1_all_battlefields: Array[CardData] = CardDatabase._load_battlefields("Darius")
	for i in range(len(p0_all_battlefields)):
		var b0: CardData = p0_all_battlefields[i]
		p0.battlefields.append(CardInstance.new(state.next_uid(), b0))	
	for i in range(len(p1_all_battlefields)):
		var b1: CardData = p1_all_battlefields[i]
		p1.battlefields.append(CardInstance.new(state.next_uid(), b1))	
	# Load legend
	p0.legend = CardInstance.new(state.next_uid(), CardDatabase._load_legend("Jinx"))
	p1.legend = CardInstance.new(state.next_uid(), CardDatabase._load_legend("Darius"))
	
	# Load real cards
	var p0_all_cards: Array[CardData] = CardDatabase._load_cards("Jinx")
	var p1_all_cards: Array[CardData] = CardDatabase._load_cards("Darius")
	
	# TEMP: build a 40-card deck by sampling from all_cards
	for i in range(40):
		var d0: CardData = p0_all_cards[randi() % p0_all_cards.size()]
		var d1: CardData = p1_all_cards[randi() % p1_all_cards.size()]

		p0.deck.append(CardInstance.new(state.next_uid(), d0))
		p1.deck.append(CardInstance.new(state.next_uid(), d1))

	p0.deck.shuffle()
	p1.deck.shuffle()
	
	# Load runes
	var p0_all_runes: Array[CardData] = CardDatabase._load_runes("Jinx")
	var p1_all_runes: Array[CardData] = CardDatabase._load_runes("Darius")
	
	# TEMP rune decks (FIFO queue)
	for i in range(6):
		var p0_rune_0 := RuneInstance.new(state.next_uid(), p0_all_runes[0])
		p0_rune_0.zone = RuneInstance.Zone.RUNE_DECK
		p0.rune_deck.append(p0_rune_0)
		var p0_rune_1 := RuneInstance.new(state.next_uid(), p0_all_runes[1])
		p0_rune_1.zone = RuneInstance.Zone.RUNE_DECK
		p0.rune_deck.append(p0_rune_1)
		
		var p1_rune_0 := RuneInstance.new(state.next_uid(), p1_all_runes[0])
		p1_rune_0.zone = RuneInstance.Zone.RUNE_DECK
		p1.rune_deck.append(p1_rune_0)
		var p1_rune_1 := RuneInstance.new(state.next_uid(), p1_all_runes[1])
		p1_rune_1.zone = RuneInstance.Zone.RUNE_DECK
		p1.rune_deck.append(p1_rune_1)
	p0.rune_deck.shuffle()
	p1.rune_deck.shuffle()
	
	# Opening hands
	for i in range(OPENING_HAND_SIZE):
		state.turn_system._draw_card(p0)
		state.turn_system._draw_card(p1)

	# Start player 0 by default
	state.active_player_index = 0
	state.turn_number = 1
	state.phase = "START"

	# Start first turn (delegated to PlayerTurn)
	start_turn(state)

	state.add_event("Game started. P0 goes first.")
	return state


static func start_turn(state: GameState) -> void:
	# Delegate phase flow to PlayerTurn
	if state.turn_system == null:
		state.add_event("ERROR: turn_system not initialized.")
		return

	state.turn_system.start_turn(state)


static func end_turn(state: GameState) -> void:
	# GameEngine is the owner of switching turns
	state.active_player_index = 1 - state.active_player_index
	state.turn_number += 1

	# Start the next player's turn
	start_turn(state)
	
	
static func _play_card(state: GameState, action: GameAction) -> void:
	if state.phase != "MAIN":
		state.add_event("Invalid PLAY_CARD: not in MAIN phase.")
		return

	var p := state.get_active_player()

	var hand_index := -1
	
	for i in range(p.hand.size()):
		if p.hand[i].uid == action.card_uid:
			hand_index = i
			break

	if hand_index == -1:
		state.add_event("Invalid PLAY_CARD: card uid not found in hand.")
		return

	var card: CardInstance = p.hand[hand_index]
	var cost := card.data.cost

	if p.rune_count_in_pool() < cost:
		state.add_event("P%d cannot play card: not enough runes." % p.id)
		return

	card.zone = CardInstance.Zone.BOARD
	p.spend_runes(p.rune_pool.slice(0, cost))
	p.hand.remove_at(hand_index)
	card.exhaust()
	p.board.append(card)

	state.add_event("P%d played %s (cost %d)." % [p.id, card.data.card_name, cost])
	
