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
	#rig_card_to_top_of_deck(p0, "OGN-044/298") # Clockwork Keeper
	#rig_card_to_top_of_deck(p0, "OGN-047/298") # Find Your Center
	#rig_card_to_top_of_deck(p0, "OGN-058/298") # Discipline
	#rig_card_to_top_of_deck(p0, "OGN-046/298") # En Garde
	#rig_card_to_top_of_deck(p0, "OGN-128/298") # Challenge
	rig_card_to_top_of_deck(p0, "OGN-043/298") # Charm
	rig_card_to_top_of_deck(p0, "OGN-258/298") # Dragon's Rage
	
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
