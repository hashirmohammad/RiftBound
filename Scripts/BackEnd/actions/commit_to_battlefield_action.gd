class_name CommitToBattlefieldAction
extends GameAction

var card_uids: Array[int] = []
var battlefield_index: int = -1
var _error_message: String = "Invalid COMMIT_TO_BATTLEFIELD."

func _init(_player_id: int = -1, _card_uids: Array[int] = [], _battlefield_index: int = -1):
	super(_player_id)
	card_uids = _card_uids.duplicate()
	battlefield_index = _battlefield_index

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Not this player's turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Not in MAIN phase."
		return false

	if state.awaiting_rune_payment:
		_error_message = "Finish rune payment first."
		return false

	if state.awaiting_showdown:
		_error_message = "A showdown is already active."
		return false

	if battlefield_index < 0 or battlefield_index > 1:
		_error_message = "Invalid battlefield index."
		return false

	if card_uids.is_empty():
		_error_message = "No cards selected to commit."
		return false

	var player := state.get_active_player()
	for uid in card_uids:
		var card := _find_on_board(player, uid)
		if card == null:
			_error_message = "Card uid %d not found on board." % uid
			return false
		if card.is_exhausted():
			_error_message = "Card uid %d is exhausted and cannot commit." % uid
			return false

	return true

func execute(state: GameState) -> void:
	var p := state.get_active_player()

	for uid in card_uids:
		var card := _find_on_board(p, uid)
		if card == null:
			continue
		for slot in p.board_slots:
			if slot.has(card):
				slot.erase(card)
				break
		card.zone = CardInstance.Zone.ARENA
		card.exhaust()
		p.battlefield_slots[battlefield_index].append(card)
		state.add_event("P%d committed %s to battlefield lane %d." % [
			p.id, card.data.card_name, battlefield_index
		])

	# If opponent already has units at this lane, open a showdown immediately
	var opponent := state.get_opponent()
	if not opponent.battlefield_slots[battlefield_index].is_empty():
		_open_showdown(state, p, opponent)

func _open_showdown(state: GameState, attacker_player: PlayerState, defender_player: PlayerState) -> void:
	var attackers: Array[UnitState] = []
	for card in attacker_player.battlefield_slots[battlefield_index]:
		var unit := state.unit_registry.get_unit(card.uid)
		if unit != null:
			unit.combat_role = UnitState.CombatRole.ATTACKER
			attackers.append(unit)

	var defenders: Array[UnitState] = []
	for card in defender_player.battlefield_slots[battlefield_index]:
		var unit := state.unit_registry.get_unit(card.uid)
		if unit != null:
			unit.combat_role = UnitState.CombatRole.DEFENDER
			defenders.append(unit)

	if attackers.is_empty() or defenders.is_empty():
		state.add_event("No registered units at lane %d — showdown skipped." % battlefield_index)
		return

	var context := CombatContext.new()
	context.game_state = state
	context.unit_registry = state.unit_registry
	context.attackers = attackers
	context.defenders = defenders
	context.tank_priority_order = TargetingRules.get_tank_priority(
		defender_player.id, state.unit_registry
	)

	var showdown := state.timing_manager.open_showdown(context)
	state.active_combat_context = context
	state.active_showdown = showdown
	state.awaiting_showdown = true

	state.add_event("Showdown opened at lane %d — %d attacker(s) vs %d defender(s)." % [
		battlefield_index, attackers.size(), defenders.size()
	])

func get_error_message() -> String:
	return _error_message

func _find_on_board(player: PlayerState, uid: int) -> CardInstance:
	for slot in player.board_slots:
		for card in slot:
			if card.uid == uid:
				return card
	return null
