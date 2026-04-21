class_name ChoiceRules

static func get_choice_definition(choice_type: String) -> Dictionary:
	match choice_type:
		"qiyana_conquer":
			return {
				"title": "Choose an effect.",
				"options": [
					{"id": "draw", "label": "Draw 1 Card"},
					{"id": "channel", "label": "Channel 1 Rune"}
				]
			}
	return {}

static func resolve_choice(choice_type: String, player_id: int, option_id: String, state: GameState) -> void:
	match choice_type:
		"qiyana_conquer":
			_resolve_qiyana_conquer(player_id, option_id, state)
		_:
			state.add_event("Unknown choice type: %s" % choice_type)

static func _resolve_qiyana_conquer(player_id: int, option_id: String, state: GameState) -> void:
	var player: PlayerState = state.players[player_id]

	match option_id:
		"draw":
			for i in range(1):
				if player.deck.is_empty():
					state.add_event("P%d deck empty — cannot draw." % player_id)
					return
				var card: CardInstance = player.deck.pop_back()
				player.hand.append(card)
				card.zone = CardInstance.Zone.HAND
			state.add_event("Qiyana, Victorious conquer: P%d chose draw 1." % player_id)

		"channel":
			player.channel_runes_exhausted(1)
			state.add_event("Qiyana, Victorious conquer: P%d chose channel 1 rune exhausted." % player_id)

		_:
			state.add_event("Qiyana, Victorious conquer: invalid choice '%s'." % option_id)
