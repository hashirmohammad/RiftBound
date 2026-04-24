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
	
	#rig_card_to_top_of_deck(p0, "OGN-052/298") # Stalwart Poro
	#rig_card_to_top_of_deck(p0, "OGN-054/298") # Sunlit Guardian
	#rig_card_to_top_of_deck(p0, "OGN-065/298") # Wizened Elder
	#rig_card_to_top_of_deck(p0, "OGN-075/298") # Tasty Faefolk
	#rig_card_to_top_of_deck(p0, "OGN-136/298") # Pit Rookie
	rig_card_to_top_of_deck(p0, "OGN-044/298") # Clockwork Keeper
	rig_card_to_top_of_deck(p0, "OGN-047/298") # Clockwork Keeper
	
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
	var ending_player := state.active_player_index

	_score_end_turn(state, ending_player)

	if state.game_over:
		return

	_check_opponent_win(state, ending_player)

	if state.game_over:
		return

	state.active_player_index = 1 - state.active_player_index
	state.turn_number += 1
	start_turn(state)
	
static func rig_card_to_top_of_deck(player: PlayerState, card_id: String) -> void:
	var found_index := -1

	for i in range(player.deck.size()):
		if player.deck[i].data.card_id == card_id:
			found_index = i
			break

	if found_index == -1:
		push_warning("Rig failed: card_id %s not found in deck." % card_id)
		return

	var card: CardInstance = player.deck[found_index]
	player.deck.remove_at(found_index)
	player.deck.append(card) # top of deck if draw uses pop_back()

static func _get_arena_controller(state: GameState, arena_index: int) -> int:
	var p0 = state.players[0].battlefield_slots[arena_index].size() > 0
	var p1 = state.players[1].battlefield_slots[arena_index].size() > 0

	if p0 and not p1:
		return 0
	if p1 and not p0:
		return 1
	return -1

static func _update_arena_control(state: GameState) -> void:
	state.arena_control[0] = _get_arena_controller(state, 0)
	state.arena_control[1] = _get_arena_controller(state, 1)

static func _count_controlled(state: GameState, player_id: int) -> int:
	var count := 0
	for c in state.arena_control:
		if c == player_id:
			count += 1
	return count
	
static func _score_end_turn(state: GameState, player_id: int) -> void:
	_update_arena_control(state)

	var controlled := _count_controlled(state, player_id)

	if controlled == 0:
		state.add_event("P%d controls no arenas and gains no points." % player_id)
		return

	# BOTH arenas → +2 and can win, even from 6 or 7
	if controlled == 2:
		state.scores[player_id] += 2
		state.add_event("P%d controls both arenas (+2). Total: %d" % [
			player_id, state.scores[player_id]
		])
		_check_win(state, player_id)
		return

	# ONE arena
	var current = state.scores[player_id]

	if current < 7:
		state.scores[player_id] += 1
		state.add_event("P%d controls 1 arena (+1). Total: %d" % [
			player_id, state.scores[player_id]
		])
		_check_win(state, player_id)
		return

	# At 7 → cannot win from 1 arena on your own end turn
	state.add_event("P%d controls 1 arena, but cannot claim the final point on their own turn." % player_id)

static func _check_opponent_win(state: GameState, ending_player_id: int) -> void:
	_update_arena_control(state)

	var opponent := 1 - ending_player_id

	# Only check opponent — NOT the player who just ended turn
	if state.scores[opponent] != 7:
		return

	var controlled := _count_controlled(state, opponent)

	# Opponent must control at least one arena
	if controlled >= 1:
		state.scores[opponent] += 1
		state.add_event("P%d gains the final point at the end of P%d's turn!" % [
			opponent, ending_player_id
		])
		_check_win(state, opponent)

static func _check_win(state: GameState, player_id: int) -> void:
	if state.scores[player_id] >= 8:
		state.scores[player_id] = 8
		state.winner_id = player_id
		state.game_over = true
		state.add_event("P%d WINS THE GAME!" % player_id)
