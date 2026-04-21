class_name GameState

const POINTS_TO_WIN: int = 8

var players: Array[PlayerState] = []              # [PlayerState, PlayerState]
var active_player_index: int = 0     # whose turn it is
var turn_number: int = 1
var phase: String = "START"          # keep as string for now (we'll enum later)

# Stores the randomly picked deck name for each player
var deck_names: Array[String] = ["", ""]

# Event log for debugging / later replays
var event_log: Array[String] = []

# Turn/phase controller (manages phase order + phase logic)
var turn_system: PlayerTurn

# ── Combat systems ────────────────────────────────────────────────────────────
var unit_registry: UnitRegistry
var timing_manager: TimingManager
var combat_manager: CombatManager

# ── Rune payment state ────────────────────────────────────────────────────────
var awaiting_rune_payment: bool = false  # True while the player is currently selecting runes to pay for a card
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

# ── Pending effect-choice state ───────────────────────────────────────────────
var awaiting_effect_choice: bool = false
var pending_effect_choice: Dictionary = {}

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

func clear_rune_payment_state() -> void:
	awaiting_rune_payment = false
	pending_card_uid = -1
	pending_slot_index = -1
	pending_card_cost = 0
	selected_rune_uids.clear()
	pending_payment_player_id = -1

func set_pending_effect_choice(choice_type: String, player_id: int, source_uid: int = -1) -> void:
	awaiting_effect_choice = true
	pending_effect_choice = {
		"type": choice_type,
		"player_id": player_id,
		"source_uid": source_uid
	}

func clear_effect_choice_state() -> void:
	awaiting_effect_choice = false
	pending_effect_choice.clear()

func clear_combat_state() -> void:
	awaiting_showdown = false
	awaiting_damage_assignment = false
	active_combat_context = null
	active_showdown = null
	
func clear_temporary_state() -> void:
	clear_rune_payment_state()
	clear_combat_state()
