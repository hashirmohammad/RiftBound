extends Node

const GameActionScript = preload("res://Scripts/action.gd")
const GameEngineScript = preload("res://Scripts/game_engine.gd")

func _ready() -> void:
	print_header("DEBUG SCENE START")

	var cards = CardDatabase.get_all_cards()
	print("Loaded cards: ", cards.size())
	if cards.size() > 0:
		print("First card: %s | cost=%d | might=%d" % [
			cards[0].card_name,
			cards[0].cost,
			cards[0].might
		])

	var state = GameEngineScript.start_game()

	# Wait for Player 0 to reach MAIN
	await wait_until_main(state)

	print_header("SNAPSHOT: START OF P0 MAIN")
	print_turn_snapshot(state)
	print_all_players(state)

	print_header("END TURN: P0 -> P1")
	var end_action = GameActionScript.new(
		GameActionScript.ActionType.END_TURN,
		state.get_active_player().id
	)
	GameEngineScript.apply_action(state, end_action)

	# Wait for Player 1 to reach MAIN
	await wait_until_main(state)

	print_header("SNAPSHOT: START OF P1 MAIN")
	print_turn_snapshot(state)
	print_all_players(state)

	var ap = state.get_active_player()

	print_header("TRY PLAY_CARD")
	print("Active Player: P%d" % ap.id)

	if ap.hand.is_empty():
		print("Cannot test PLAY_CARD: active player hand is empty.")
	else:
		var hand_card = ap.hand[0]
		print("Selected hand card: uid=%d | name=%s | cost=%d | state=%s | zone=%s" % [
			hand_card.uid,
			hand_card.data.card_name,
			hand_card.data.cost,
			card_state_name(hand_card.state),
			card_zone_name(hand_card.zone)
		])

		print("Before PLAY_CARD:")
		print_player_snapshot(ap)

		var play_action = GameActionScript.new(
			GameActionScript.ActionType.PLAY_CARD,
			ap.id,
			0
		)
		GameEngineScript.apply_action(state, play_action)

		ap = state.get_active_player()

		print("After PLAY_CARD:")
		print_player_snapshot(ap)

		if ap.board.is_empty():
			print("Board card: <empty> (PLAY_CARD may have failed)")
			print_last_event(state)
		else:
			var board_card = ap.board[0]
			print("Board card placed: uid=%d | name=%s | state=%s | zone=%s" % [
				board_card.uid,
				board_card.data.card_name,
				card_state_name(board_card.state),
				card_zone_name(board_card.zone)
			])

	print_header("FINAL EVENT LOG")
	print("Events count: ", state.event_log.size())
	for e in state.event_log:
		print(" - ", e)

	print_header("DEBUG SCENE END")


func wait_until_main(state: GameState) -> void:
	while state.phase != "MAIN":
		await get_tree().process_frame


func print_turn_snapshot(state: GameState) -> void:
	print("Turn: ", state.turn_number)
	print("Active Player: P", state.active_player_index)
	print("Phase: ", state.phase)


func print_all_players(state: GameState) -> void:
	for player in state.players:
		print_player_snapshot(player)
		print("")


func print_player_snapshot(player) -> void:
	print("Player P%d" % player.id)
	print("  Hand Size: ", player.hand.size())
	print("  Board Size: ", player.board.size())
	print("  Deck Size: ", player.deck.size())
	print("  Graveyard Size: ", player.graveyard.size())
	print("  Rune Deck Size: ", player.rune_deck.size())
	print("  Rune Pool Count: ", player.rune_count_in_pool())

	print("  Rune Pool:")
	print_rune_array(player.rune_pool)

	print("  Board:")
	print_board_array(player.board)

	print("  Hand:")
	print_hand_array(player.hand)


func print_rune_array(runes: Array) -> void:
	if runes.is_empty():
		print("    <empty>")
		return

	for rune in runes:
		print("    uid=%d | type=%s | state=%s | zone=%s" % [
			rune.uid,
			rune.type_name(),
			rune_state_name(rune.state),
			rune_zone_name(rune.zone)
		])


func print_board_array(cards: Array) -> void:
	if cards.is_empty():
		print("    <empty>")
		return

	for card in cards:
		print("    uid=%d | name=%s | cost=%d | state=%s | zone=%s" % [
			card.uid,
			card.data.card_name,
			card.data.cost,
			card_state_name(card.state),
			card_zone_name(card.zone)
		])


func print_hand_array(cards: Array) -> void:
	if cards.is_empty():
		print("    <empty>")
		return

	for i in range(cards.size()):
		var card = cards[i]
		print("    [%d] uid=%d | name=%s | cost=%d | state=%s | zone=%s" % [
			i,
			card.uid,
			card.data.card_name,
			card.data.cost,
			card_state_name(card.state),
			card_zone_name(card.zone)
		])


func print_last_event(state: GameState) -> void:
	if state.event_log.is_empty():
		print("Last event: <none>")
	else:
		print("Last event: ", state.event_log[state.event_log.size() - 1])


func print_header(title: String) -> void:
	print("")
	print("==================================================")
	print(title)
	print("==================================================")


func rune_state_name(state_value: int) -> String:
	return RuneInstance.State.keys()[state_value]


func rune_zone_name(zone_value: int) -> String:
	return RuneInstance.Zone.keys()[zone_value]


func card_state_name(state_value: int) -> String:
	return CardInstance.CardState.keys()[state_value]


func card_zone_name(zone_value: int) -> String:
	return CardInstance.Zone.keys()[zone_value]
