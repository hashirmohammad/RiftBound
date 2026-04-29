class_name MoveChampionToBaseAction
extends GameAction

var _error_message := "Invalid MOVE_CHAMPION_TO_BASE."

func _init(_player_id: int = -1) -> void:
	super(_player_id)

func validate(state: GameState) -> bool:
	if player_id != state.get_active_player().id:
		_error_message = "Invalid MOVE_CHAMPION_TO_BASE: not your turn."
		return false

	if state.phase != "MAIN":
		_error_message = "Invalid MOVE_CHAMPION_TO_BASE: not in MAIN phase."
		return false

	var p: PlayerState = state.players[player_id]

	if p.champion == null:
		_error_message = "Invalid MOVE_CHAMPION_TO_BASE: no champion in champion slot."
		return false

	return true

func execute(state: GameState) -> void:
	var p: PlayerState = state.players[player_id]
	var card: CardInstance = p.champion

	p.champion = null

	card.zone = CardInstance.Zone.BOARD
	card.exhaust()
	p.board_slots[0].append(card)

	var unit := UnitState.new(card, p.id)

	for effect in KeywordParser.parse(card.data, state):
		unit.effects.add(effect)

	var extra_fn := CardAbilityRegistry.get_extra_unit_effects_fn(card.data.card_id)
	if extra_fn.is_valid():
		var extra_effects: Array = extra_fn.call(unit, state)
		for e in extra_effects:
			unit.effects.add(e)

	state.unit_registry.register(unit)

	state.add_event("P%d moved champion %s to BASE exhausted." % [
		p.id,
		card.data.card_name
	])

func get_error_message() -> String:
	return _error_message
