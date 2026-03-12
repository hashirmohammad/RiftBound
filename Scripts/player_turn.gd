class_name PlayerTurn
# Emmits whenver a phase and player turn begins, also when the phase and player turn ends
signal phase_started(phase_name, player_id)
signal phase_ended(phase_name, player_id)
signal turn_started(player_id)
signal turn_ended(player_id)

# Defines all phases in order. Using enum prevents typos
enum Phase {
	AWAKEN,
	BEGINNING,
	CHANNEL,
	DRAW,
	MAIN,
	END
}

# List defining the order phases execute in.
var phase_order = [
	Phase.AWAKEN,
	Phase.BEGINNING,
	Phase.CHANNEL,
	Phase.DRAW,
	Phase.MAIN,
	Phase.END
]

# Index of current phase in the phase_order list
var phase_index := 0
var current_phase : int
var state : GameState


# -------------------------
# TURN FLOW
# -------------------------
# Starts a new turn for the active player
func start_turn(game_state:GameState):
	state = game_state
	phase_index = 0

	var player = state.get_active_player()

	emit_signal("turn_started", player.id)
	_enter_phase()  # entering first phase

# end turn function
func end_turn():
	var player = state.get_active_player()
	emit_signal("turn_ended", player.id)

func get_turn_number() -> int:
	return state.turn_number

# -------------------------
# PHASE EXECUTION
# -------------------------
# Enters the current phase and executes its logic
func _enter_phase():
	current_phase = phase_order[phase_index]
	var player = state.get_active_player()

	state.phase = _phase_name(current_phase)
	emit_signal("phase_started", state.phase, player.id)

	match current_phase:

		Phase.AWAKEN:
			_awaken_phase(player)

		Phase.BEGINNING:
			pass

		Phase.CHANNEL:
			var runes_to_channel := 2

			# Special rule: Player 1 channels 3 runes on their first turn.
			# With your engine: turn 1 = P0, turn 2 = P1, so this condition is correct.
			if state.turn_number == 2 and player.id == 1:
				runes_to_channel = 3

			player.channel_runes(runes_to_channel)
			state.add_event("P%d channels %d rune(s)." % [player.id, runes_to_channel])

		Phase.DRAW:
			_draw_card(player)
			state.add_event("P%d draws a card." % player.id)

		Phase.MAIN:
			pass

		Phase.END:
			_end_phase(player)
	
	# Auto-advance through non-interactive phases.
	# MAIN is where we wait for player actions (PLAY_CARD / END_TURN).
	if current_phase != Phase.MAIN and current_phase != Phase.END:
		call_deferred("next_phase")

# moves to next phase
func next_phase():
	var player = state.get_active_player()
	emit_signal("phase_ended", _phase_name(current_phase), player.id)

	phase_index += 1
	# end turn if all phases passed
	if phase_index >= phase_order.size():
		end_turn()
		return

	_enter_phase()
	
# -------------------------
# PHASE LOGIC
# -------------------------
# Handles awaken phase logic
func _awaken_phase(player:PlayerState):
	for c in player.board:
		c.awaken()
	var rune_count: int = 0
	for r in player.rune_pool:
		if r.is_exhausted():
			r.awaken()
			rune_count += 1

	state.add_event("P%d awakens %d cards." % [player.id, player.board.size()])
	state.add_event("P%d awakens %d runes." % [player.id, rune_count])

# Handles end phase logic
func _end_phase(player:PlayerState):
	state.add_event("P%d ends turn." % player.id)

# Draws a card from deck into hand if possible

func _draw_card(player:PlayerState):
	if player.deck.is_empty():
		return
	var card: CardInstance = player.deck.pop_back()
	player.hand.append(card)
	card.zone = CardInstance.Zone.HAND


# -------------------------
# MODIFIERS (future cards)
# -------------------------

func skip_phase(phase:int): # hey modify the phase order safely without altering core turn logic.
	phase_order.erase(phase)


func repeat_current_phase(): # drawing multiple times
	phase_order.insert(phase_index + 1, current_phase)


func insert_phase_after_current(phase:int): #
	phase_order.insert(phase_index + 1, phase)


# -------------------------
# UTIL
# -------------------------

func _phase_name(p:int)->String:
	match p:
		Phase.AWAKEN: return "AWAKEN"
		Phase.BEGINNING: return "BEGINNING"
		Phase.CHANNEL: return "CHANNEL"
		Phase.DRAW: return "DRAW"
		Phase.MAIN: return "MAIN"
		Phase.END: return "END"
	return "UNKNOWN"
