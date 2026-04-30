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
const MoveToBattlefieldAction     = preload("res://Scripts/BackEnd/actions/move_to_battlefield_action.gd")
const ReturnFromBattlefieldAction = preload("res://Scripts/BackEnd/actions/return_from_battlefield_action.gd")
const CommitToBattlefieldAction   = preload("res://Scripts/BackEnd/actions/commit_to_battlefield_action.gd")
const PassPriorityAction          = preload("res://Scripts/BackEnd/actions/pass_priority_action.gd")
const ConfirmDamageAction         = preload("res://Scripts/BackEnd/actions/confirm_damage_action.gd")
const MoveChampionToBaseAction    = preload("res://Scripts/BackEnd/actions/move_champion_to_base_action.gd")
const UseLegendAbilityAction      = preload("res://Scripts/BackEnd/actions/use_legend_ability_action.gd")

var state: GameState
var board_renderer: BoardRenderer
var status_presenter: StatusPresenter
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
	if NetworkManager.is_network_mode:
		seed(NetworkManager.game_seed)
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
	spell_target_controller.setup(self, state, status_label)

	choice_controller = ChoiceController.new()
	choice_controller.setup(self, state, status_label, choice_a_button, choice_b_button)

	unit_target_controller = UnitTargetController.new()
	unit_target_controller.setup(self, state, status_label)

	combat_ui_controller = CombatUIController.new()
	combat_ui_controller.setup(self, state, status_label)

	turn_ui_controller = TurnUIController.new()
	turn_ui_controller.setup(self, state, status_label)

	legend_ui_controller = LegendUIController.new()
	legend_ui_controller.setup(self, state, status_label)

	win_screen.rematch_requested.connect(_on_rematch_requested)
	win_screen.quit_requested.connect(_on_quit_requested)

	if NetworkManager.is_network_mode:
		NetworkManager.peer_disconnected.connect(_on_peer_disconnected)

	_connect_buttons()
	refresh_all_ui()

func _connect_buttons() -> void:
	cancel_payment_button.pressed.connect(_on_cancel_payment_pressed)
	pass_priority_button.pressed.connect(_on_pass_priority_pressed)
	confirm_damage_button.pressed.connect(_on_confirm_damage_pressed)
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)

	cancel_payment_button.visible = false
	pass_priority_button.visible  = false
	confirm_damage_button.visible = false
	choice_a_button.visible       = false
	choice_b_button.visible       = false

# ─── UI Refresh ───────────────────────────────────────────────────────────────

func refresh_all_ui() -> void:
	board_renderer.refresh_all_ui()
	_update_status_label()
	board.refresh_points(state.scores[0], state.scores[1])

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

# ─── Status Label ─────────────────────────────────────────────────────────────

func _update_status_label() -> void:
	if state.awaiting_damage_assignment and combat_ui_controller != null:
		status_presenter.update(state, combat_ui_controller.get_pending_assignments())
	else:
		status_presenter.update(state)

# ─── Actions ──────────────────────────────────────────────────────────────────

func _apply_action(action: GameAction) -> bool:
	var success := GameEngine.apply_action(state, action)
	if success and NetworkManager.is_network_mode:
		var data := _serialize_action(action)
		print("[NET] sending action t=%s pid=%s" % [data.get("t","?"), data.get("pid","?")])
		_receive_action.rpc(data)
	return success

func apply_backend_action(action: GameAction) -> void:
	var success := _apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
	refresh_all_ui()

func apply_backend_action_and_wait(action: GameAction) -> void:
	var success := _apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		refresh_all_ui()
		return
	await wait_until_main()
	refresh_all_ui()

func try_play_card(card_uid: int, slot_index: int) -> String:
	return choice_controller.try_play_card(card_uid, slot_index)

func _on_choice_a_pressed() -> void:
	if not _is_local_active():
		return
	choice_controller.resolve_pending_choice("A")

func _on_choice_b_pressed() -> void:
	if not _is_local_active():
		return
	choice_controller.resolve_pending_choice("B")

func try_play_card_to_slot(card_uid: int, slot_index: int) -> bool:
	var player := get_actor_player()
	var action := PlayCardAction.new(player.id, card_uid, slot_index)
	var success: bool = _apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_all_ui()

	return true

func request_play_card(card_uid: int, slot_index: int, metadata := {}) -> void:
	state.pending_play_metadata = metadata.duplicate(true)

	var actor := get_actor_player()
	var action := PlayCardAction.new(actor.id, card_uid, slot_index)
	if action.validate(state):
		action.execute(state)
		if NetworkManager.is_network_mode:
			var data := _serialize_action(action)
			data["meta"] = metadata.duplicate(true)
			_receive_action.rpc(data)
	else:
		state.add_event(action.get_error_message())
		status_label.text = action.get_error_message()
		state.pending_play_metadata.clear()

	refresh_all_ui()

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
	var ok := unit_target_controller.try_select_unit_target(target_uid)
	if ok and NetworkManager.is_network_mode:
		_receive_unit_target.rpc(target_uid)
	return ok

func _on_pass_priority_pressed() -> void:
	if NetworkManager.is_network_mode and state.get_priority_player_id() != NetworkManager.local_player_id:
		return
	combat_ui_controller.try_pass_priority()

func try_pass_priority() -> void:
	combat_ui_controller.try_pass_priority()

func try_commit_to_battlefield(card_uids: Array[int], battlefield_index: int) -> bool:
	return combat_ui_controller.try_commit_to_battlefield(card_uids, battlefield_index)

func try_move_to_battlefield(card_uid: int, battlefield_index: int) -> bool:
	return combat_ui_controller.try_move_to_battlefield(card_uid, battlefield_index)

func try_return_from_battlefield(card_uid: int, battlefield_index: int, slot_index: int = 0) -> bool:
	return combat_ui_controller.try_return_from_battlefield(card_uid, battlefield_index, slot_index)

func try_return_from_any_battlefield(card_uid: int, source_player_id: int, battlefield_index: int, slot_index: int = 0) -> bool:
	var ok := combat_ui_controller.try_return_from_any_battlefield(card_uid, source_player_id, battlefield_index, slot_index)
	if ok and NetworkManager.is_network_mode:
		_receive_return_any_battlefield.rpc(card_uid, source_player_id, battlefield_index, slot_index)
	return ok

func _on_confirm_damage_pressed() -> void:
	if not _is_local_assigner():
		return
	combat_ui_controller.confirm_damage()

func _on_cancel_payment_pressed() -> void:
	if not _is_local_active():
		return
	turn_ui_controller.cancel_payment()

func try_pick_runes_to_spend(rune_uid: int) -> bool:
	return turn_ui_controller.try_pick_runes_to_spend(rune_uid)

func try_end_turn() -> void:
	turn_ui_controller.try_end_turn()

func adjust_damage_assignment(unit_uid: int, delta: int) -> void:
	combat_ui_controller.adjust_damage_assignment(unit_uid, delta)

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

	if NetworkManager.is_network_mode:
		var data := _serialize_action(action)
		data["meta"] = state.pending_play_metadata.duplicate(true)
		_receive_action.rpc(data)

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
	var success := _apply_action(action)
	if not success:
		status_label.text = action.get_error_message()
		return false
	refresh_all_ui()
	return true

func get_actor_player() -> PlayerState:
	if state.awaiting_showdown and state.active_showdown != null:
		return state.get_priority_player()
	return state.get_active_player()

# ─── Network ──────────────────────────────────────────────────────────────────

@rpc("any_peer")
func _receive_action(data: Dictionary) -> void:
	print("[NET] received action t=%s from peer %s" % [data.get("t","?"), multiplayer.get_remote_sender_id()])
	if data.get("t") == "play" and data.has("meta"):
		state.pending_play_metadata = (data["meta"] as Dictionary).duplicate(true)
	var action := _deserialize_action(data)
	if action == null:
		return
	var ok := GameEngine.apply_action(state, action)
	if not ok:
		push_error("[NET] _receive_action: remote action '%s' failed — state may have diverged" % data.get("t", "?"))
	print("[NET] action applied ok=%s, refreshing UI" % ok)
	refresh_all_ui()
	if state.phase != "MAIN":
		await wait_until_main()
		refresh_all_ui()

@rpc("any_peer")
func _receive_cancel_payment() -> void:
	var player := state.get_active_player()
	for rune_uid in state.selected_rune_uids:
		for rune in player.rune_pool:
			if rune.uid == rune_uid:
				rune.awaken()
	state.awaiting_rune_payment = false
	state.pending_card_uid      = -1
	state.pending_slot_index    = -1
	state.pending_card_cost     = 0
	state.selected_rune_uids.clear()
	refresh_all_ui()

@rpc("any_peer")
func _receive_unit_target(target_uid: int) -> void:
	unit_target_controller.try_select_unit_target(target_uid)

@rpc("any_peer")
func _receive_return_any_battlefield(card_uid: int, source_player_id: int, battlefield_index: int, slot_index: int) -> void:
	combat_ui_controller.try_return_from_any_battlefield(card_uid, source_player_id, battlefield_index, slot_index)

func _serialize_action(action: GameAction) -> Dictionary:
	if action is EndTurnAction:
		return {"t": "end", "pid": action.player_id}
	if action is PlayCardAction:
		return {"t": "play", "pid": action.player_id, "uid": action.card_uid, "slot": action.slot_index}
	if action is PickRuneAction:
		return {"t": "rune", "pid": action.player_id, "uid": action.rune_uid}
	if action is MoveToBattlefieldAction:
		return {"t": "move_bf", "pid": action.player_id, "uid": action.card_uid, "bf": action.battlefield_index}
	if action is ReturnFromBattlefieldAction:
		return {"t": "ret_bf", "pid": action.player_id, "uid": action.card_uid, "bf": action.battlefield_index, "slot": action.board_slot_index}
	if action is CommitToBattlefieldAction:
		var uids: Array = []
		for u in action.card_uids: uids.append(u)
		return {"t": "commit", "pid": action.player_id, "uids": uids, "bf": action.battlefield_index}
	if action is PassPriorityAction:
		return {"t": "pass", "pid": action.player_id}
	if action is ConfirmDamageAction:
		return {"t": "dmg", "pid": action.player_id, "asgn": action.assignments.duplicate()}
	if action is MoveChampionToBaseAction:
		return {"t": "champ", "pid": action.player_id}
	if action is UseLegendAbilityAction:
		return {"t": "legend", "pid": action.player_id, "uid": action.target_uid}
	push_warning("GameController: unknown action type for serialization")
	return {}

func _deserialize_action(data: Dictionary) -> GameAction:
	var pid: int = int(data.get("pid", -1))
	match data.get("t", ""):
		"end":
			return EndTurnAction.new(pid)
		"play":
			return PlayCardAction.new(pid, int(data["uid"]), int(data["slot"]))
		"rune":
			return PickRuneAction.new(pid, int(data["uid"]))
		"move_bf":
			return MoveToBattlefieldAction.new(pid, int(data["uid"]), int(data["bf"]))
		"ret_bf":
			return ReturnFromBattlefieldAction.new(pid, int(data["uid"]), int(data["bf"]), int(data["slot"]))
		"commit":
			var uids: Array[int] = []
			for u in data["uids"]: uids.append(int(u))
			return CommitToBattlefieldAction.new(pid, uids, int(data["bf"]))
		"pass":
			return PassPriorityAction.new(pid)
		"dmg":
			var asgn: Dictionary = {}
			for k in data["asgn"]: asgn[int(k)] = int(data["asgn"][k])
			return ConfirmDamageAction.new(pid, asgn)
		"champ":
			return MoveChampionToBaseAction.new(pid)
		"legend":
			return UseLegendAbilityAction.new(pid, int(data["uid"]))
	push_warning("GameController: unknown action type '%s'" % data.get("t", "?"))
	return null

func _is_local_active() -> bool:
	if not NetworkManager.is_network_mode:
		return true
	return NetworkManager.local_player_id == state.get_active_player().id

func _is_local_assigner() -> bool:
	if not NetworkManager.is_network_mode:
		return true
	var ctx := state.active_combat_context
	if ctx == null:
		return false
	var loser_is_attacker := ctx.total_defender_might > ctx.total_attacker_might
	var assigner_id: int = ctx.attackers[0].player_id if loser_is_attacker else ctx.defenders[0].player_id
	return assigner_id == NetworkManager.local_player_id

func _local_id() -> int:
	return NetworkManager.local_player_id

# ─── Helpers ──────────────────────────────────────────────────────────────────

func wait_until_main() -> void:
	var max_frames := 600
	var frames     := 0
	while state.phase != "MAIN" and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	if state.phase != "MAIN":
		push_warning("wait_until_main() timed out. Current phase: %s" % state.phase)

# ─── Rematch / Quit ──────────────────────────────────────────────────────────

func _on_rematch_requested() -> void:
	state = GameEngine.start_game()
	board_renderer.setup(self, board, state, hand_manager, hand_manager_p1, deck_ui)
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

func _on_peer_disconnected(_id: int) -> void:
	if state.game_over:
		return
	NetworkManager.pending_reconnect = true
	status_label.text = "Connection lost. Returning to lobby..."
	await get_tree().create_timer(3.0).timeout
	NetworkManager._close_peer()
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")
