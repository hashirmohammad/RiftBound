class_name PlayerTurn
signal phase_started(phase_name, player_id)
signal phase_ended(phase_name, player_id)
signal turn_started(player_id)
signal turn_ended(player_id)

enum Phase {
	AWAKEN,
	BEGINNING,
	CHANNEL,
	DRAW,
	MAIN,
	END
}

var phase_order = [
	Phase.AWAKEN,
	Phase.BEGINNING,
	Phase.CHANNEL,
	Phase.DRAW,
	Phase.MAIN,
	Phase.END
]

var phase_index := 0
var current_phase : int
var state : GameState


# -------------------------
# TURN FLOW
# -------------------------
func start_turn(game_state: GameState):
	state = game_state
	phase_index = 0
	var player = state.get_active_player()
	emit_signal("turn_started", player.id)
	_enter_phase()

func end_turn():
	var player = state.get_active_player()
	print("[PlayerTurn] end_turn() | switching away from P", player.id)
	emit_signal("turn_ended", player.id)
	# Hand off to GameEngine to switch active player and start next turn
	GameEngine.end_turn(state)

func get_turn_number() -> int:
	return state.turn_number


# -------------------------
# PHASE EXECUTION
# -------------------------
func _enter_phase():
	current_phase = phase_order[phase_index]
	var player = state.get_active_player()
	state.phase = _phase_name(current_phase)
	print("[PlayerTurn] _enter_phase() | phase=", state.phase, " | player=P", player.id, " | phase_index=", phase_index)
	emit_signal("phase_started", state.phase, player.id)

	match current_phase:

		Phase.AWAKEN:
			_awaken_phase(player)

		Phase.BEGINNING:
			pass

		Phase.CHANNEL:
			var runes_to_channel := 2
			if state.turn_number == 2 and player.id == 1:
				runes_to_channel = 3
			player.channel_runes(runes_to_channel)
			state.add_event("P%d channels %d rune(s)." % [player.id, runes_to_channel])

		Phase.DRAW:
			_draw_card(player)
			state.add_event("P%d draws a card." % player.id)

		Phase.MAIN:
			print("[PlayerTurn] Reached MAIN phase — waiting for player input")

		Phase.END:
			_end_phase(player)

	# Only MAIN waits for player input — everything else auto-advances
	if current_phase != Phase.MAIN:
		print("[PlayerTurn] auto-advancing past phase=", state.phase, " via call_deferred")
		call_deferred("next_phase")
	else:
		print("[PlayerTurn] stopping at MAIN — waiting for EndTurnAction")

func next_phase():
	var player = state.get_active_player()
	print("[PlayerTurn] next_phase() called | current=", _phase_name(current_phase), " | phase_index=", phase_index)
	emit_signal("phase_ended", _phase_name(current_phase), player.id)

	phase_index += 1
	if phase_index >= phase_order.size():
		print("[PlayerTurn] all phases done — calling end_turn()")
		end_turn()
		return

	_enter_phase()


# -------------------------
# PHASE LOGIC
# -------------------------
func _awaken_phase(player: PlayerState):
	var card_count: int = 0
	for slot in player.board_slots:
		for c in slot:
			c.awaken()
			card_count += 1

	var rune_count: int = 0
	for r in player.rune_pool:
		if r.is_exhausted():
			r.awaken()
			rune_count += 1

	print("[PlayerTurn] _awaken_phase() | awakened cards=", card_count, " runes=", rune_count)
	state.add_event("P%d awakens %d cards." % [player.id, card_count])
	state.add_event("P%d awakens %d runes." % [player.id, rune_count])

func _end_phase(player: PlayerState):
	print("[PlayerTurn] _end_phase() for P", player.id)
	state.add_event("P%d ends turn." % player.id)

func _draw_card(player: PlayerState):
	if player.deck.is_empty():
		return
	var card: CardInstance = player.deck.pop_back()
	player.hand.append(card)
	card.zone = CardInstance.Zone.HAND


# -------------------------
# MODIFIERS (future cards)
# -------------------------
func skip_phase(phase: int):
	phase_order.erase(phase)

func repeat_current_phase():
	phase_order.insert(phase_index + 1, current_phase)

func insert_phase_after_current(phase: int):
	phase_order.insert(phase_index + 1, phase)


# -------------------------
# UTIL
# -------------------------
func _phase_name(p: int) -> String:
	match p:
		Phase.AWAKEN:    return "AWAKEN"
		Phase.BEGINNING: return "BEGINNING"
		Phase.CHANNEL:   return "CHANNEL"
		Phase.DRAW:      return "DRAW"
		Phase.MAIN:      return "MAIN"
		Phase.END:       return "END"
	return "UNKNOWN"
