class_name GameState

const POINTS_TO_WIN: int = 8

# -1 = no controller, 0 = P0 controls, 1 = P1 controls
# Index matches battlefield slot: battlefield_control[0] is the first battlefield
const NO_CONTROL: int = -1

var players: Array = []              # [PlayerState, PlayerState]
var active_player_index: int = 0     # whose turn it is
var turn_number: int = 1
var phase: String = "START"          # keep as string for now (we'll enum later)

# Who controls each contested battlefield. Size = number of battlefields in play.
# Populated by CombatResolver after each showdown.
var battlefield_control: Array[int] = []

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

# Call once during setup to register how many battlefields are in play.
func init_battlefield_control(count: int) -> void:
	battlefield_control.clear()
	for i in range(count):
		battlefield_control.append(NO_CONTROL)

# Set controller for a battlefield slot and award 1 point if control changed.
func set_battlefield_control(slot: int, player_index: int) -> void:
	if slot < 0 or slot >= battlefield_control.size():
		return
	var previous: int = battlefield_control[slot]
	battlefield_control[slot] = player_index
	if previous != player_index:
		players[player_index].points += 1
		add_event("P%d captured battlefield %d (+1 point, total: %d)" % [
			player_index, slot, players[player_index].points
		])

func get_winner_index() -> int:
	if players[0].points >= POINTS_TO_WIN:
		return 0
	if players[1].points >= POINTS_TO_WIN:
		return 1
	return -1

func is_game_over() -> bool:
	return get_winner_index() != -1
