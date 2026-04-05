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
static func start_game(p0_deck: String, p1_deck: String) -> GameState:
	var state := GameState.new()

	# Turn/phase controller
	state.turn_system = PlayerTurn.new()

	# Create players
	var p0 := PlayerState.new(0)
	var p1 := PlayerState.new(1)
	state.players = [p0, p1]

	# Pick a random preset deck for each player and store in state
	var p0_deck_name: String = CardDatabase._random_deck_name()
	var p1_deck_name: String = CardDatabase._random_deck_name()
	state.deck_names[0] = p0_deck_name
	state.deck_names[1] = p1_deck_name
	state.add_event("P0 deck: %s | P1 deck: %s" % [p0_deck_name, p1_deck_name])

	# ── Load legends ───────────────────────────────────────────────────────────
	var p0_legend_data := CardDatabase._load_legend(p0_deck_name)
	var p1_legend_data := CardDatabase._load_legend(p1_deck_name)
	if p0_legend_data:
		p0.legend = CardInstance.new(state.next_uid(), p0_legend_data)
	if p1_legend_data:
		p1.legend = CardInstance.new(state.next_uid(), p1_legend_data)

	# ── Load battlefields ──────────────────────────────────────────────────────
	for b in CardDatabase._load_battlefields_from_deck(p0_deck_name):
		p0.battlefields.append(CardInstance.new(state.next_uid(), b))
	for b in CardDatabase._load_battlefields_from_deck(p1_deck_name):
		p1.battlefields.append(CardInstance.new(state.next_uid(), b))

	# ── Build draw decks ───────────────────────────────────────────────────────
	# Loads only the "cards" section of the deck JSON (no runes, no legend).
	# count field is respected — e.g. count:3 adds 3 copies.
	for cd in CardDatabase._load_cards_from_deck(p0_deck_name):
		p0.deck.append(CardInstance.new(state.next_uid(), cd))
	for cd in CardDatabase._load_cards_from_deck(p1_deck_name):
		p1.deck.append(CardInstance.new(state.next_uid(), cd))

	p0.deck.shuffle()
	p1.deck.shuffle()

	# ── Build rune decks ───────────────────────────────────────────────────────
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

	# ── Opening hands ──────────────────────────────────────────────────────────
	# Draws 4 cards each from the draw deck only (runes are separate)
	for i in range(OPENING_HAND_SIZE):
		state.turn_system._draw_card(p0)
		state.turn_system._draw_card(p1)

	# Start player 0 by default
	state.active_player_index = 1
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
	# NOTE: Do NOT awaken cards here. Awakening is handled at the start of the
	# next player's turn by _awaken_phase() in PlayerTurn, which iterates
	# board_slots — the authoritative card store. Doing it here as well would
	# cause a double-awaken and would use the stale `player.board` flat list.

	# Switch active player
	state.active_player_index = 1 - state.active_player_index
	state.turn_number += 1

	# Start the next player's turn
	start_turn(state)
