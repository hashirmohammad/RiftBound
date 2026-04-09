class_name GameState

const POINTS_TO_WIN: int = 8

var players: Array = []              # [PlayerState, PlayerState]
var active_player_index: int = 0     # whose turn it is
var turn_number: int = 1
var awaiting_rune_payment: bool = false
var pending_card_uid: int = -1
var pending_slot_index: int = -1
var pending_card_cost: int = 0
var selected_rune_uids: Array[int] = []
var pending_payment_player_id: int = -1
var phase: String = "START"          # keep as string for now (we'll enum later)

# Stores the randomly picked deck name for each player
var deck_names: Array[String] = ["", ""]

# Event log for debugging / later replays
var event_log: Array = []

# Turn/phase controller (manages phase order + phase logic)
var turn_system

var _next_uid: int = 1

func next_uid() -> int:
	var id := _next_uid
	_next_uid += 1
	return id

func get_active_player() -> PlayerState:
	return players[active_player_index]

func get_opponent() -> PlayerState:
	return players[1 - active_player_index]

func add_event(msg: String) -> void:
	event_log.append(msg)

func get_winner_index() -> int:
	if players[0].points >= POINTS_TO_WIN:
		return 0
	if players[1].points >= POINTS_TO_WIN:
		return 1
	return -1

func is_game_over() -> bool:
	return get_winner_index() != -1
