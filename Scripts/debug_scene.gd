extends Node

const GameActionScript = preload("res://Scripts/action.gd")
const GameEngineScript = preload("res://Scripts/game_engine.gd")

func _ready():
	var cards = CardDatabase.load_cards_from_json()
	print("Loaded cards:", cards.size())
	if cards.size() > 0:
		print("First card:", cards[0].card_name, "cost=", cards[0].cost, "might=", cards[0].might)

	print("DEBUG SCENE RUNNING")

	var state = GameEngineScript.start_game()

	# Wait for P0 phases to auto-advance to MAIN
	await wait_until_main(state)

	print("Turn:", state.turn_number)
	print("Active Player:", state.active_player_index)
	print("Phase:", state.phase)

	print("P0 Hand Size:", state.players[0].hand.size())
	print("P1 Hand Size:", state.players[1].hand.size())

	print("P0 Rune Pool:", state.players[0].rune_count_in_pool())
	print("P1 Rune Pool:", state.players[1].rune_count_in_pool())

	# SAFE: top of deck
	if state.players[0].deck.is_empty():
		print("Top of P0 deck: <empty>")
	else:
		var top = state.players[0].deck[0]
		print("Top of P0 deck:", top.uid, top.data.card_name)

	print("=== End Turn ===")

	var end_action = GameActionScript.new(GameActionScript.ActionType.END_TURN, state.get_active_player().id)
	GameEngineScript.apply_action(state, end_action)

	# Wait for P1 phases to auto-advance to MAIN
	await wait_until_main(state)

	print("Turn:", state.turn_number)
	print("Active Player:", state.active_player_index)
	print("Phase:", state.phase)

	print("P0 Rune Pool:", state.players[0].rune_count_in_pool())
	print("P1 Rune Pool:", state.players[1].rune_count_in_pool())

	var ap = state.get_active_player()
	print("Before PLAY_CARD (Active P%d):" % ap.id)
	print("Hand:", ap.hand.size(), ", Board:", ap.board.size(), ", Runes:", ap.rune_count_in_pool())

	var play_action = GameActionScript.new(GameActionScript.ActionType.PLAY_CARD, ap.id, 0)
	GameEngineScript.apply_action(state, play_action)

	ap = state.get_active_player()
	print("After PLAY_CARD (Active P%d):" % ap.id)
	print("Hand:", ap.hand.size(), ", Board:", ap.board.size(), ", Runes:", ap.rune_count_in_pool())

	# SAFE: board card
	if ap.board.is_empty():
		print("Board card: <empty> (PLAY_CARD failed?)")
		if state.event_log.size() > 0:
			print("Last event:", state.event_log[state.event_log.size() - 1])
	else:
		var b = ap.board[0]
		print("Board card:", b.uid, b.data.card_name)

	print("Events:")
	print("Events count:", state.event_log.size())
	for e in state.event_log:
		print(e)

func wait_until_main(state: GameState) -> void:
	while state.phase != "MAIN":
		await get_tree().process_frame
