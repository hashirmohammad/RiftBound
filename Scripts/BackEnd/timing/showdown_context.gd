class_name ShowdownContext
extends RefCounted

var combat_context: CombatContext

var active_player_passed: bool = false
var opponent_passed: bool = false

# The player currently allowed to act during showdown.
var priority_player_id: int = -1

func _init(ctx: CombatContext) -> void:
	combat_context = ctx
	priority_player_id = ctx.game_state.active_player_index

func get_turn_player_id() -> int:
	return combat_context.game_state.active_player_index

func get_opponent_player_id() -> int:
	return 1 - get_turn_player_id()

func pass_priority(player_id: int) -> void:
	var turn_player_id := get_turn_player_id()

	if player_id == turn_player_id:
		active_player_passed = true
	else:
		opponent_passed = true

	priority_player_id = 1 - player_id

func reset_passes(new_priority_player_id := -1) -> void:
	active_player_passed = false
	opponent_passed = false

	if new_priority_player_id != -1:
		priority_player_id = new_priority_player_id

func both_passed() -> bool:
	return active_player_passed and opponent_passed

func can_player_act(player_id: int) -> bool:
	return player_id == priority_player_id
