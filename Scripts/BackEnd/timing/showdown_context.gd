class_name ShowdownContext
extends RefCounted

# Tracks per-player pass state during the SHOWDOWN phase.
# SHOWDOWN closes when both players pass consecutively without queuing new abilities.

var combat_context: CombatContext

# True once a player has indicated they are done acting for this round of showdown
var active_player_passed: bool = false
var opponent_passed: bool = false

func _init(ctx: CombatContext) -> void:
	combat_context = ctx

func pass_priority(player_id: int) -> void:
	var active_id: int = combat_context.game_state.active_player_index
	if player_id == active_id:
		active_player_passed = true
	else:
		opponent_passed = true

# If either player queues a new ability, reset both pass flags so the window stays open
func reset_passes() -> void:
	active_player_passed = false
	opponent_passed = false

func both_passed() -> bool:
	return active_player_passed and opponent_passed
