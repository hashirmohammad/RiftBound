class_name GameState

const POINTS_TO_WIN: int = 8

var players: Array = []              # [PlayerState, PlayerState]
var active_player_index: int = 0     # whose turn it is
var turn_number: int = 1
var phase: String = "START"          # keep as string for now (we'll enum later)
var flow: GameFlowController = GameFlowController.new()
var pending_choice_data: Dictionary = {}
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

var awaiting_choice: bool = false
var pending_choice_card_id: String = ""
var pending_choice_source_uid: int = -1
var pending_choice_player_id: int = -1

var pending_choice_step: String = ""
var pending_choice_mode: String = ""

var battlefield_flags: Dictionary = {}

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

# ── Flow helpers ──────────────────────────────────────────────────────────────

func enter_main_phase() -> void:
	phase = "MAIN"
	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)

	awaiting_rune_payment = false
	awaiting_showdown = false
	awaiting_damage_assignment = false
	awaiting_unit_target = false
	awaiting_spell_targets = false
	awaiting_spell_destination = false
	awaiting_choice = false


func enter_rune_payment(
		card_uid: int,
		slot_index: int,
		cost: int,
		player_id: int
	) -> void:
	flow.set_phase(GameFlowController.Phase.RUNE_PAYMENT)

	awaiting_rune_payment = true
	pending_card_uid = card_uid
	pending_slot_index = slot_index
	pending_card_cost = cost
	pending_payment_player_id = player_id
	selected_rune_uids.clear()


func exit_rune_payment() -> void:
	awaiting_rune_payment = false
	pending_card_uid = -1
	pending_slot_index = -1
	pending_card_cost = 0
	pending_payment_player_id = -1
	selected_rune_uids.clear()
	pending_play_metadata.clear()

	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)


func enter_showdown(context: CombatContext, showdown: ShowdownContext) -> void:
	flow.set_phase(GameFlowController.Phase.SHOWDOWN)

	awaiting_showdown = true
	active_combat_context = context
	active_showdown = showdown


func exit_showdown() -> void:
	awaiting_showdown = false
	active_showdown = null
	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)


func enter_damage_assignment(context: CombatContext) -> void:
	flow.set_phase(GameFlowController.Phase.DAMAGE_ASSIGNMENT)

	awaiting_damage_assignment = true
	active_combat_context = context


func exit_damage_assignment() -> void:
	awaiting_damage_assignment = false
	active_combat_context = null
	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)


func enter_unit_target(source_uid: int, card_id: String) -> void:
	flow.set_phase(GameFlowController.Phase.TARGETING)

	awaiting_unit_target = true
	pending_target_source_uid = source_uid
	pending_target_card_id = card_id


func exit_unit_target() -> void:
	awaiting_unit_target = false
	pending_target_source_uid = -1
	pending_target_card_id = ""

	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)


func enter_spell_targets(
		player_id: int,
		card_uid: int,
		card_id: String,
		required_targets: int
	) -> void:
	flow.set_phase(GameFlowController.Phase.TARGETING)

	awaiting_spell_targets = true
	pending_spell_player_id = player_id
	pending_spell_card_uid = card_uid
	pending_spell_card_id = card_id
	pending_spell_required_targets = required_targets
	pending_spell_target_uids.clear()


func enter_spell_destination() -> void:
	flow.set_phase(GameFlowController.Phase.TARGETING)

	awaiting_spell_targets = false
	awaiting_spell_destination = true


func exit_spell_targets() -> void:
	clear_pending_spell_target_state()
	awaiting_spell_destination = false
	pending_spell_card = null
	pending_spell_targets.clear()

	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)


func enter_choice(card_id: String, source_uid: int, player_id: int, step := "", mode := "", data := {}) -> void:
	flow.set_phase(GameFlowController.Phase.CHOICE)

	awaiting_choice = true
	pending_choice_card_id = card_id
	pending_choice_source_uid = source_uid
	pending_choice_player_id = player_id
	pending_choice_step = step
	pending_choice_mode = mode
	pending_choice_data = data.duplicate(true)


func exit_choice() -> void:
	awaiting_choice = false
	pending_choice_card_id = ""
	pending_choice_source_uid = -1
	pending_choice_player_id = -1
	pending_choice_step = ""
	pending_choice_mode = ""

	flow.set_phase(GameFlowController.Phase.MAIN_PHASE)

func get_priority_player_id() -> int:
	if awaiting_showdown and active_showdown != null:
		return active_showdown.priority_player_id
	return active_player_index

func get_priority_player() -> PlayerState:
	return players[get_priority_player_id()]
