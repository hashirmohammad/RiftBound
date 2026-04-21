class_name ShowdownContext
extends RefCounted

var combat_context: CombatContext
var priority_player_id: int
var active_player_passed: bool = false
var opponent_passed: bool = false

func _init(ctx: CombatContext) -> void:
	combat_context = ctx
	priority_player_id = combat_context.game_state.active_player_index

func pass_priority(player_id: int) -> void:
	var active_id: int = combat_context.game_state.active_player_index
	if player_id == active_id:
		active_player_passed = true
	else:
		opponent_passed = true

	switch_priority()

func switch_priority() -> void:
	var active_id: int = combat_context.game_state.active_player_index
	if priority_player_id == active_id:
		priority_player_id = 1 - active_id
	else:
		priority_player_id = active_id

func reset_passes() -> void:
	active_player_passed = false
	opponent_passed = false

func both_passed() -> bool:
	return active_player_passed and opponent_passed
