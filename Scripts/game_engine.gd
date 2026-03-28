class_name GameEngine

const OPENING_HAND_SIZE := 4
const DEFAULT_RUNE_DECK_SIZE := 12  # placeholder; adjust later
const DEBUG_FREE_RUNES := true
const DEBUG_STARTING_RUNES := 3

static func _grant_debug_runes(player: PlayerState, amount: int) -> void:
	for i in range(amount):
		if player.rune_deck.is_empty():
			return

		var rune: RuneInstance = player.rune_deck.pop_back()
		rune.zone = RuneInstance.Zone.RUNE_POOL
		rune.awaken()
		player.rune_pool.append(rune)

# -------------------------
# ACTION PIPELINE
# -------------------------
static func apply_action(state: GameState, action: GameAction) -> bool:
	if action == null:
		state.add_event("Invalid action: null action.")
		return false

	if not action.validate(state):
		state.add_event(action.get_error_message())
		return false

	action.execute(state)
	return true


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
	var player := state.get_active_player()

	if DEBUG_FREE_RUNES and player.rune_pool.is_empty():
		_grant_debug_runes(player, DEBUG_STARTING_RUNES)
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
