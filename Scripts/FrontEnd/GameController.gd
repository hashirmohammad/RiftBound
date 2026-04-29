extends Node

const GameEngine                  = preload("res://Scripts/BackEnd/core/game_engine.gd")
const PlayCardAction              = preload("res://Scripts/BackEnd/actions/play_card_action.gd")
const EndTurnAction               = preload("res://Scripts/BackEnd/actions/end_turn_action.gd")
const BoardRenderer               = preload("res://Scripts/FrontEnd/BoardRender.gd")
const PickRuneAction              = preload("res://Scripts/BackEnd/actions/pick_runes_to_spend_action.gd")
const StatusPresenter             = preload("res://Scripts/FrontEnd/StatusPresenter.gd")
const SpellTargetController       = preload("res://Scripts/FrontEnd/SpellTargetController.gd")
const ChoiceController            = preload("res://Scripts/FrontEnd/ChoiceController.gd")
const UnitTargetController        = preload("res://Scripts/FrontEnd/UnitTargetController.gd")
const CombatUIController          = preload("res://Scripts/FrontEnd/CombatUIController.gd")
const TurnUIController            = preload("res://Scripts/FrontEnd/TurnUIController.gd")
const LegendUIController          = preload("res://Scripts/FrontEnd/LegendUIController.gd")
const MoveChampionToBaseAction    = preload("res://Scripts/BackEnd/actions/move_champion_to_base_action.gd")

var state: GameState
var board_renderer: BoardRenderer
var status_presenter : StatusPresenter
var selected_board_uids: Array[int] = []
var spell_target_controller: SpellTargetController
var choice_controller: ChoiceController
var unit_target_controller: UnitTargetController
var combat_ui_controller: CombatUIController
var turn_ui_controller: TurnUIController
var legend_ui_controller: LegendUIController

@onready var status_label          = $"../StatusLabel"
@onready var hand_manager          = $"../P0/P0_Hand"
@onready var hand_manager_p1       = $"../P1/P1_Hand"
@onready var board                 = $"../Board"
@onready var deck_ui               = $"../P0/P0_MainDeck"
@onready var cancel_payment_button = $"../CancelPaymentButton"
@onready var pass_priority_button  = $"../PassPriorityButton"
@onready var confirm_damage_button = $"../ConfirmDamageButton"
@onready var choice_a_button       = $"../ChoiceAButton"
@onready var choice_b_button       = $"../ChoiceBButton"
@onready var win_screen            = $"../WinScreen"


func _ready() -> void:
	state = GameEngine.start_game()
	await get_tree().process_frame

	board_renderer = BoardRenderer.new()
	board_renderer.setup(
		self,
		board,
		state,
		hand_manager,
		hand_manager_p1,
		deck_ui
	)

	status_presenter = StatusPresenter.new()
	status_presenter.setup(
		status_label,
		cancel_payment_button,
		pass_priority_button,
		confirm_damage_button,
		choice_a_button,
		choice_b_button
	)

	spell_target_controller = SpellTargetController.new()
	spell_target_controller.setup(
		self,
		state,
		status_label
	)

	choice_controller = ChoiceController.new()
	choice_controller.setup(
		self,
		state,
		status_label,
		choice_a_button,
		choice_b_button
	)

	unit_target_controller = UnitTargetController.new()
	unit_target_controller.setup(
		self,
		state,
		status_label
	)

	combat_ui_controller = CombatUIController.new()
	combat_ui_controller.setup(
		self,
		state,
		status_label
	)

	turn_ui_controller = TurnUIController.new()
	turn_ui_controller.setup(
		self,
		state,
		status_label
	)

	legend_ui_controller = LegendUIController.new()
	legend_ui_controller.setup(
		self,
		state,
		status_label
	)

	win_screen.rematch_requested.connect(_on_rematch_requested)
	win_screen.quit_requested.connect(_on_quit_requested)

	_connect_buttons()
	refresh_all_ui()

func _connect_buttons() -> void:
	cancel_payment_button.pressed.connect(_on_cancel_payment_pressed)
	pass_priority_button.pressed.connect(_on_pass_priority_pressed)
	confirm_damage_button.pressed.connect(_on_confirm_damage_pressed)
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)

	cancel_payment_button.visible = false
	pass_priority_button.visible = false
	confirm_damage_button.visible = false
	choice_a_button.visible = false
	choice_b_button.visible = false

# ─── UI Refresh ───────────────────────────────────────────────────────────────

func refresh_all_ui() -> void:
	board_renderer.refresh_all_ui()
	_update_status_label()
	# ── Points visualization ──────────────────────────────────────────────────
	# Scores live in state.scores[], NOT PlayerState.points
	board.refresh_points(state.scores[0], state.scores[1])

	# ── Game over ─────────────────────────────────────────────────────────────
	if state.game_over and win_screen and not win_screen.visible:
		win_screen.show_winner(state.winner_id, state.scores)

func refresh_hand_ui() -> void:
	board_renderer.refresh_hand_ui()

func refresh_deck_ui() -> void:
	board_renderer.refresh_deck_ui()

func refresh_payment_ui() -> void:
	board_renderer.refresh_payment_ui()
	_update_status_label()

func render_board() -> void:
	board_renderer.render_board()

func render_slot(player: PlayerState, slot_index: int) -> void:
	board_renderer.render_slot(player, slot_index)

func render_arena_slot(player: PlayerState) -> void:
	board_renderer.render_arena_slot(player)

func render_static_state(player: PlayerState, opponent: PlayerState) -> void:
	board_renderer.render_static_state(player, opponent)

func render_rune_panels(p0: PlayerState, p1: PlayerState) -> void:
	board_renderer.render_rune_panels(p0, p1)

# ─── Button Handlers ─────────────────────────────────────────────────────────

func try_play_card(card_uid: int, slot_index: int) -> String:
	return choice_controller.try_play_card(card_uid, slot_index)

func _on_choice_a_pressed() -> void:
	choice_controller.resolve_pending_choice("A")

func _on_choice_b_pressed() -> void:
	choice_controller.resolve_pending_choice("B")

func _update_status_label() -> void:
	if state.awaiting_damage_assignment and combat_ui_controller != null:
		status_presenter.update(state, combat_ui_controller.get_pending_assignments())
	else:
		status_presenter.update(state)

func apply_backend_action(action: GameAction) -> void:
	var success := GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
	refresh_all_ui()

func request_play_card(card_uid: int, slot_index: int, metadata := {}) -> void:
	state.pending_play_metadata = metadata.duplicate(true)

	var actor := get_actor_player()
	var action := PlayCardAction.new(actor.id, card_uid, slot_index)
	if action.validate(state):
		action.execute(state)
	else:
		state.add_event(action.get_error_message())
		status_label.text = action.get_error_message()
		state.pending_play_metadata.clear()

	refresh_all_ui()

func try_play_card_to_slot(card_uid: int, slot_index: int) -> bool:
	var player = get_actor_player()
	var action = PlayCardAction.new(player.id, card_uid, slot_index)

	var success: bool = GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_all_ui()

	return true

func try_select_spell_target(target_uid: int) -> bool:
	return spell_target_controller.try_select_spell_target(target_uid)

func resolve_pending_spell() -> void:
	spell_target_controller.resolve_pending_spell()

func try_select_spell_destination(destination_zone: String, destination_player_id: int, destination_index: int) -> void:
	spell_target_controller.try_select_spell_destination(
		destination_zone,
		destination_player_id,
		destination_index
	)

func try_select_unit_target(target_uid: int) -> bool:
	return unit_target_controller.try_select_unit_target(target_uid)

func _on_pass_priority_pressed() -> void:
	combat_ui_controller.try_pass_priority()

func _on_confirm_damage_pressed() -> void:
	combat_ui_controller.confirm_damage()

func try_pass_priority() -> void:
	combat_ui_controller.try_pass_priority()

func try_commit_to_battlefield(card_uids: Array[int], battlefield_index: int) -> bool:
	return combat_ui_controller.try_commit_to_battlefield(card_uids, battlefield_index)

func try_move_to_battlefield(card_uid: int, battlefield_index: int) -> bool:
	return combat_ui_controller.try_move_to_battlefield(card_uid, battlefield_index)

func try_return_from_battlefield(card_uid: int, battlefield_index: int, slot_index: int = 0) -> bool:
	return combat_ui_controller.try_return_from_battlefield(card_uid, battlefield_index, slot_index)

func try_return_from_any_battlefield(card_uid: int, source_player_id: int, battlefield_index: int, slot_index: int = 0) -> bool:
	return combat_ui_controller.try_return_from_any_battlefield(card_uid, source_player_id, battlefield_index, slot_index)

func _on_cancel_payment_pressed() -> void:
	turn_ui_controller.cancel_payment()

func try_pick_runes_to_spend(rune_uid: int) -> bool:
	return turn_ui_controller.try_pick_runes_to_spend(rune_uid)

func try_end_turn() -> void:
	turn_ui_controller.try_end_turn()

func adjust_damage_assignment(unit_uid: int, delta: int) -> void:
	combat_ui_controller.adjust_damage_assignment(unit_uid, delta)

func get_actor_player() -> PlayerState:
	if state.awaiting_showdown and state.active_showdown != null:
		return state.get_priority_player()
	return state.get_active_player()

func try_play_card_to_enemy_battlefield(card_uid: int, enemy_player_id: int, battlefield_index: int) -> bool:
	var player := get_actor_player()

	state.pending_play_metadata = {
		"play_to_enemy_battlefield": true,
		"enemy_player_id": enemy_player_id,
		"battlefield_index": battlefield_index
	}

	var action := PlayCardAction.new(player.id, card_uid, 0)
	var success := GameEngine.apply_action(state, action)

	if not success:
		status_label.text = action.get_error_message()
		state.pending_play_metadata.clear()
		return false

	refresh_all_ui()
	return true

func start_legend_mode(player_id: int = -1) -> void:
	legend_ui_controller.start_legend_mode(player_id)

func cancel_legend_mode() -> void:
	legend_ui_controller.cancel_legend_mode()

func try_use_legend_ability(target_uid: int) -> bool:
	return legend_ui_controller.try_use_legend_ability(target_uid)

func try_move_champion_to_base() -> bool:
	var player := state.get_active_player()
	var action := MoveChampionToBaseAction.new(player.id)

	var success := GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	refresh_all_ui()
	return true

# ─── Rematch / Quit ──────────────────────────────────────────────────────────

func _on_rematch_requested() -> void:
	state = GameEngine.start_game()
	board_renderer.setup(
		self,
		board,
		state,
		hand_manager,
		hand_manager_p1,
		deck_ui
	)
	spell_target_controller.setup(self, state, status_label)
	choice_controller.setup(self, state, status_label, choice_a_button, choice_b_button)
	unit_target_controller.setup(self, state, status_label)
	combat_ui_controller.setup(self, state, status_label)
	turn_ui_controller.setup(self, state, status_label)
	legend_ui_controller.setup(self, state, status_label)
	await get_tree().process_frame
	refresh_all_ui()

func _on_quit_requested() -> void:
	get_tree().quit()
