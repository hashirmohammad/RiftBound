class_name EffectResolver

static func draw_cards(state: GameState, player_id: int, count: int) -> void:
	var player: PlayerState = state.players[player_id]
	var drawn := 0

	for i in range(count):
		if player.deck.is_empty():
			state.add_event("P%d deck empty — cannot draw." % player_id)
			break

		var card: CardInstance = player.deck.pop_back()
		player.hand.append(card)
		card.zone = CardInstance.Zone.HAND
		drawn += 1

	if drawn > 0:
		state.add_event("P%d drew %d card(s)." % [player_id, drawn])


static func channel_runes_exhausted(state: GameState, player_id: int, count: int) -> void:
	var player: PlayerState = state.players[player_id]
	var channeled := 0

	for i in range(count):
		if player.rune_deck.is_empty():
			state.add_event("P%d rune deck empty — cannot channel more runes." % player_id)
			break

		var rune: RuneInstance = player.rune_deck.pop_back()
		rune.zone = RuneInstance.Zone.RUNE_POOL
		rune.exhaust()
		player.rune_pool.append(rune)
		channeled += 1

	if channeled > 0:
		state.add_event("P%d channeled %d rune(s) exhausted." % [player_id, channeled])


static func add_effect_to_unit(state: GameState, target: UnitState, effect: EffectInstance, log_text := "") -> void:
	target.effects.add(effect)
	if log_text != "":
		state.add_event(log_text)


static func stun_unit(state: GameState, source_uid: int, target: UnitState, expiry := EffectInstance.ExpiryTiming.END_OF_TURN) -> void:
	target.effects.add(EffectFactory.make_stun(state, source_uid, expiry))
	state.add_event("%s was stunned." % target.card_instance.data.card_name)


static func buff_unit(state: GameState, source_uid: int, target: UnitState, value: int, expiry := EffectInstance.ExpiryTiming.END_OF_TURN) -> void:
	target.effects.add(EffectFactory.make_buff(state, source_uid, value, expiry))
	state.add_event("%s got +%d BUFF." % [target.card_instance.data.card_name, value])


static func assault_unit(state: GameState, source_uid: int, target: UnitState, value: int, expiry := EffectInstance.ExpiryTiming.END_OF_TURN) -> void:
	target.effects.add(EffectFactory.make_assault(state, source_uid, value, expiry))
	state.add_event("%s got Assault %d." % [target.card_instance.data.card_name, value])


static func shield_unit(state: GameState, source_uid: int, target: UnitState, value: int, expiry := EffectInstance.ExpiryTiming.END_OF_TURN) -> void:
	target.effects.add(EffectFactory.make_shield(state, source_uid, value, expiry))
	state.add_event("%s got Shield %d." % [target.card_instance.data.card_name, value])


static func deal_damage_to_unit(state: GameState, source_uid: int, target: UnitState, amount: int) -> void:
	target.damage_taken += amount
	state.add_event("%s took %d damage." % [target.card_instance.data.card_name, amount])

	if not target.is_alive():
		_handle_unit_death(state, target)


static func heal_unit(state: GameState, target: UnitState, amount: int) -> void:
	target.damage_taken = maxi(0, target.damage_taken - amount)
	state.add_event("%s healed %d." % [target.card_instance.data.card_name, amount])


static func resolve_tasty_faefolk_deathknell(unit: UnitState, state: GameState) -> void:
	channel_runes_exhausted(state, unit.player_id, 2)
	draw_cards(state, unit.player_id, 1)
	state.add_event("%s Deathknell resolved." % unit.card_instance.data.card_name)


static func _handle_unit_death(state: GameState, unit: UnitState) -> void:
	for effect in unit.effects.get_triggered(EffectEvents.ON_DEATH):
		if effect.trigger_fn.is_valid():
			effect.trigger_fn.call(unit, state)

	state.unit_registry.unregister(unit.uid)
	state.remove_unit_from_board(unit.uid)
	unit.card_instance.zone = CardInstance.Zone.TRASH
	state.add_event("%s died and was moved to trash." % unit.card_instance.data.card_name)


static func summon_unit_to_board(state: GameState, player_id: int, card_data: CardData, slot_index: int) -> UnitState:
	var player: PlayerState = state.players[player_id]
	if slot_index < 0 or slot_index >= player.board_slots.size():
		state.add_event("Summon failed: slot index out of range.")
		return null

	var card := CardInstance.new(state.next_uid(), card_data)
	card.zone = CardInstance.Zone.BOARD
	card.exhaust()
	player.board_slots[slot_index].append(card)

	var unit := UnitState.new(card, player_id)
	for effect in KeywordParser.parse(card_data, state):
		unit.effects.add(effect)
	state.unit_registry.register(unit)

	state.add_event("P%d summoned %s into slot %d." % [player_id, card_data.card_name, slot_index])
	return unit
