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

	# Load real cards
	var all_cards: Array[CardData] = CardDatabase.load_cards_from_json()

	# TEMP: build a 40-card deck by sampling from all_cards
	for i in range(40):
		var d0: CardData = all_cards[randi() % all_cards.size()]
		var d1: CardData = all_cards[randi() % all_cards.size()]

		p0.deck.append(CardInstance.new(state.next_uid(), d0))
		p1.deck.append(CardInstance.new(state.next_uid(), d1))

	p0.deck.shuffle()
	p1.deck.shuffle()

	# TEMP rune decks (FIFO queue)
	for i in range(DEFAULT_RUNE_DECK_SIZE):
		p0.rune_deck.append("Rune_%d" % i)
		p1.rune_deck.append("Rune_%d" % i)

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
	# Only allow playing cards in MAIN phase
	if state.phase != "MAIN":
		state.add_event("Invalid PLAY_CARD: not in MAIN phase.")
		return

	var p := state.get_active_player()

	# Validate index
	if action.card_index < 0 or action.card_index >= p.hand.size():
		state.add_event("Invalid PLAY_CARD: card_index out of range.")
		return	

	var card: CardInstance = p.hand[action.card_index]
	var cost := card.data.cost   # instead of 1
	if p.rune_count_in_pool() < cost:
		state.add_event("P%d cannot play card: not enough runes." % p.id)
		return
	card.zone = CardInstance.Zone.BOARD
	# Spend and move card from hand -> board
	p.spend_runes(cost)
	p.hand.remove_at(action.card_index)
	card.exhaust()
	p.board.append(card)
	state.add_event("P%d played %s (cost %d)." % [p.id, card.data.card_name, cost])
