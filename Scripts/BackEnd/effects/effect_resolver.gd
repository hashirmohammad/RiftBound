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

static func units_strike_each_other(state: GameState, unit_a: UnitState, unit_b: UnitState) -> void:
	if unit_a == null or unit_b == null:
		return

	var a_might: int = MightCalculator.get_total_might(unit_a, state)
	var b_might: int = MightCalculator.get_total_might(unit_b, state)

	state.add_event("%s and %s strike each other." % [
		unit_a.card_instance.data.card_name,
		unit_b.card_instance.data.card_name
	])

	# Store damage first (simulate simultaneous damage)
	var damage_to_b := a_might
	var damage_to_a := b_might

	# Apply both damages
	EffectResolver.deal_damage_to_unit(state, unit_a.uid, unit_b, damage_to_b)
	EffectResolver.deal_damage_to_unit(state, unit_b.uid, unit_a, damage_to_a)

static func find_unit_location(state: GameState, unit_uid: int) -> Dictionary:
	for player in state.players:
		for slot_i in range(player.board_slots.size()):
			for card in player.board_slots[slot_i]:
				if card.uid == unit_uid:
					return {
						"player_id": player.id,
						"zone": "BOARD",
						"index": slot_i
					}

		for lane_i in range(player.battlefield_slots.size()):
			for card in player.battlefield_slots[lane_i]:
				if card.uid == unit_uid:
					return {
						"player_id": player.id,
						"zone": "BATTLEFIELD",
						"index": lane_i
					}

	return {}


static func move_unit_to_battlefield(
	state: GameState,
	unit: UnitState,
	destination_player_id: int,
	destination_lane: int
) -> bool:
	if unit == null:
		state.add_event("Move failed: unit is null.")
		return false

	if destination_lane < 0 or destination_lane >= state.players[destination_player_id].battlefield_slots.size():
		state.add_event("Move failed: invalid destination lane.")
		return false

	var source_location := find_unit_location(state, unit.uid)
	if source_location.is_empty():
		state.add_event("Move failed: source unit location not found.")
		return false

	var source_player: PlayerState = state.players[int(source_location["player_id"])]
	var card: CardInstance = unit.card_instance

	if source_location["zone"] == "BOARD":
		source_player.board_slots[int(source_location["index"])].erase(card)
	elif source_location["zone"] == "BATTLEFIELD":
		source_player.battlefield_slots[int(source_location["index"])].erase(card)

	var destination_player: PlayerState = state.players[destination_player_id]
	card.zone = CardInstance.Zone.ARENA
	destination_player.battlefield_slots[destination_lane].append(card)

	state.add_event("%s moved to P%d battlefield lane %d." % [
		card.data.card_name,
		destination_player_id,
		destination_lane
	])

	return true

static func move_unit_to_location(
	state: GameState,
	unit: UnitState,
	destination_player_id: int,
	destination_zone: String,
	destination_index: int
) -> bool:
	if unit == null:
		state.add_event("Move failed: unit is null.")
		return false

	var loc := find_unit_location(state, unit.uid)
	if loc.is_empty():
		state.add_event("Move failed: source not found.")
		return false

	var source_player: PlayerState = state.players[int(loc["player_id"])]
	var card := unit.card_instance

	if loc["zone"] == "BOARD":
		source_player.board_slots[int(loc["index"])].erase(card)
	elif loc["zone"] == "BATTLEFIELD":
		source_player.battlefield_slots[int(loc["index"])].erase(card)

	var dest_player: PlayerState = state.players[destination_player_id]

	if destination_zone == "BOARD":
		if destination_index < 0 or destination_index >= dest_player.board_slots.size():
			state.add_event("Move failed: invalid board slot.")
			return false
		card.zone = CardInstance.Zone.BOARD
		dest_player.board_slots[destination_index].append(card)

	elif destination_zone == "BATTLEFIELD":
		if destination_index < 0 or destination_index >= dest_player.battlefield_slots.size():
			state.add_event("Move failed: invalid battlefield lane.")
			return false
		card.zone = CardInstance.Zone.ARENA
		dest_player.battlefield_slots[destination_index].append(card)

	else:
		state.add_event("Move failed: invalid destination zone.")
		return false

	state.add_event("%s moved to P%d %s %d." % [
		card.data.card_name,
		destination_player_id,
		destination_zone,
		destination_index
	])

	return true

static func get_units_at_battlefield(
	state: GameState,
	player_id: int,
	lane: int
) -> Array[UnitState]:
	var result: Array[UnitState] = []

	if player_id < 0 or player_id >= state.players.size():
		return result

	var player: PlayerState = state.players[player_id]
	if lane < 0 or lane >= player.battlefield_slots.size():
		return result

	for card in player.battlefield_slots[lane]:
		var unit: UnitState = state.unit_registry.get_unit(card.uid)
		if unit != null:
			result.append(unit)

	return result
	
static func recall_unit_exhausted(state: GameState, unit: UnitState, slot_index: int = 0) -> void:
	var loc := find_unit_location(state, unit.uid)
	if loc.is_empty():
		state.add_event("Recall failed: unit location not found.")
		return

	var player: PlayerState = state.players[unit.player_id]
	var card: CardInstance = unit.card_instance

	if loc["zone"] == "BOARD":
		player.board_slots[int(loc["index"])].erase(card)
	elif loc["zone"] == "BATTLEFIELD":
		player.battlefield_slots[int(loc["index"])].erase(card)

	card.zone = CardInstance.Zone.BOARD
	card.exhaust()

	var safe_slot := clampi(slot_index, 0, player.board_slots.size() - 1)
	player.board_slots[safe_slot].append(card)

	state.add_event("%s was recalled exhausted." % card.data.card_name)

static func spend_one_buff(state: GameState, unit: UnitState) -> bool:
	for effect in unit.effects.get_all():
		if effect.effect_type == EffectInstance.EffectType.BUFF and effect.value > 0:
			unit.effects.remove(effect)
			state.add_event("%s spent a buff." % unit.card_instance.data.card_name)
			return true

	state.add_event("%s has no buff to spend." % unit.card_instance.data.card_name)
	return false
