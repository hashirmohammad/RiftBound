class_name GameState

const POINTS_TO_WIN: int = 8

var players: Array = []              # [PlayerState, PlayerState]
var active_player_index: int = 0     # whose turn it is
var turn_number: int = 1
var phase: String = "START"          # keep as string for now (we'll enum later)

# Stores the randomly picked deck name for each player
var deck_names: Array[String] = ["", ""]

# Event log for debugging / later replays
var event_log: Array = []

# Turn/phase controller (manages phase order + phase logic)
var turn_system
# point System
var scores := [0, 0]
var winner_id: int = -1
var game_over: bool = false

# Arena control: index 0 = Arena 1, index 1 = Arena 2
# -1 = none, 0 = P0, 1 = P1
var arena_control := [-1, -1]

# For final-point rule (opponent turn win)
var final_point_ready := [false, false]
# ── Combat systems ────────────────────────────────────────────────────────────
var unit_registry: UnitRegistry
var timing_manager: TimingManager
var combat_manager: CombatManager

# ── Rune payment state ────────────────────────────────────────────────────────
var awaiting_rune_payment: bool = false
var pending_card_uid: int = -1
var pending_slot_index: int = -1
var pending_card_cost: int = 0
var selected_rune_uids: Array[int] = []
var pending_payment_player_id: int = -1

# ── Combat / showdown state ───────────────────────────────────────────────────
var awaiting_showdown: bool = false
var awaiting_damage_assignment: bool = false
var active_combat_context: CombatContext
var active_showdown: ShowdownContext

var awaiting_unit_target: bool = false
var pending_target_source_uid: int = -1
var pending_target_card_id: String = ""

var awaiting_spell_targets: bool = false
var pending_spell_player_id: int = -1
var pending_spell_card_uid: int = -1
var pending_spell_card_id: String = ""
var pending_spell_target_uids: Array[int] = []
var pending_spell_required_targets: int = 0

var awaiting_spell_destination := false
var pending_spell_card: CardInstance = null
var pending_spell_targets: Array[int] = []

var pending_play_metadata: Dictionary = {}

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

# Removes a CardInstance from any board or battlefield slot by uid and appends
# it to that player's trash. Called by CombatManager after a unit dies so that
# PlayerState stays in sync with UnitRegistry.
func remove_unit_from_board(uid: int) -> void:
	for player in players:
		for slot in player.board_slots:
			for i in range(slot.size() - 1, -1, -1):
				if slot[i].uid == uid:
					player.trash.append(slot[i])
					slot.remove_at(i)
					return
		for lane in player.battlefield_slots:
			for i in range(lane.size() - 1, -1, -1):
				if lane[i].uid == uid:
					player.trash.append(lane[i])
					lane.remove_at(i)
					return

func clear_pending_spell_target_state() -> void:
	awaiting_spell_targets = false
	pending_spell_player_id = -1
	pending_spell_card_uid = -1
	pending_spell_card_id = ""
	pending_spell_target_uids.clear()
	pending_spell_required_targets = 0
