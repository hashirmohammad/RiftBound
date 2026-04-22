extends Node

const GameEngine                  = preload("res://Scripts//BackEnd/core/game_engine.gd")
const PlayCardAction              = preload("res://Scripts/BackEnd/actions/play_card_action.gd")
const EndTurnAction               = preload("res://Scripts/BackEnd/actions/end_turn_action.gd")
const MoveToBattlefieldAction     = preload("res://Scripts/BackEnd/actions/move_to_battlefield_action.gd")
const ReturnFromBattlefieldAction = preload("res://Scripts/BackEnd/actions/return_from_battlefield_action.gd")
const CommitToBattlefieldAction   = preload("res://Scripts/BackEnd/actions/commit_to_battlefield_action.gd")
const PassPriorityAction          = preload("res://Scripts/BackEnd/actions/pass_priority_action.gd")
const ConfirmDamageAction         = preload("res://Scripts/BackEnd/actions/confirm_damage_action.gd")
const CARD_SCENE                  = preload("res://Scenes/Card.tscn")

var state: GameState

# UIDs of board cards currently selected for group commit; written by InputManager
var selected_board_uids: Array[int] = []

@onready var status_label          = $"../StatusLabel"
@onready var hand_manager          = $"../P0/P0_Hand"
@onready var hand_manager_p1       = $"../P1/P1_Hand"
@onready var board                 = $"../Board"
@onready var deck_ui               = $"../P0/P0_MainDeck"
@onready var cancel_payment_button = $"../CancelPaymentButton"
@onready var pass_priority_button  = $"../PassPriorityButton"
@onready var confirm_damage_button = $"../ConfirmDamageButton"

# Attacker's pending damage assignments during the assignment phase: uid -> damage
var _pending_assignments: Dictionary = {}

func _ready() -> void:
	state = GameEngine.start_game()
	await wait_until_main()
	refresh_all_ui()
	cancel_payment_button.pressed.connect(_on_cancel_payment_pressed)
	cancel_payment_button.visible  = false
	pass_priority_button.pressed.connect(_on_pass_priority_pressed)
	pass_priority_button.visible   = false
	confirm_damage_button.pressed.connect(_on_confirm_damage_pressed)
	confirm_damage_button.visible  = false

# ─── UI Refresh ───────────────────────────────────────────────────────────────

func refresh_all_ui() -> void:
	var p0 = state.players[0]
	var p1 = state.players[1]

	render_static_state(p0, p1)
	refresh_hand_ui()
	render_board()
	refresh_deck_ui()
	_update_status_label()

func refresh_hand_ui() -> void:
	hand_manager.render_hand(state.players[0].hand)
	hand_manager_p1.render_hand(state.players[1].hand)

func refresh_deck_ui() -> void:
	if deck_ui.has_method("set_count"):
		deck_ui.set_count(state.players[0].deck.size())

func refresh_payment_ui() -> void:
	render_rune_panels(state.players[0], state.players[1])
	_update_status_label()

# ─── Board Rendering ──────────────────────────────────────────────────────────

func render_board() -> void:
	_render_player_slots(state.players[0], board._player_slot_nodes)
	_render_player_slots(state.players[1], board._p1_slot_nodes)

	_render_battlefield_lane(state.players[1].battlefield_slots[0], board._p1_bf_slot_left)
	_render_battlefield_lane(state.players[1].battlefield_slots[1], board._p1_bf_slot_right)
	_render_battlefield_lane(state.players[0].battlefield_slots[0], board._p0_bf_slot_left)
	_render_battlefield_lane(state.players[0].battlefield_slots[1], board._p0_bf_slot_right)

func render_slot(player: PlayerState, slot_index: int) -> void:
	var slots = board._player_slot_nodes if player.id == 0 else board._p1_slot_nodes
	if slot_index >= slots.size() or slots[slot_index] == null:
		return
	var slot = slots[slot_index]
	slot.clear_cards()
	for ci in player.board_slots[slot_index]:
		_place_card(slot, ci, Vector2(0.35, 0.35))

func render_arena_slot(player: PlayerState) -> void:
	if player.id == 1:
		_render_battlefield_lane(player.battlefield_slots[0], board._p1_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], board._p1_bf_slot_right)
	else:
		_render_battlefield_lane(player.battlefield_slots[0], board._p0_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], board._p0_bf_slot_right)

func _render_player_slots(player: PlayerState, slots: Array) -> void:
	if player == null:
		return
	for slot in slots:
		if slot != null: slot.clear_cards()
	for i in range(player.board_slots.size()):
		if i >= slots.size() or slots[i] == null: continue
		for ci in player.board_slots[i]:
			_place_card(slots[i], ci, Vector2(0.35, 0.35))

func _render_battlefield_lane(cards: Array, slot: CardSlot) -> void:
	if slot == null: return
	slot.clear_cards()
	for ci in cards:
		_place_card(slot, ci, Vector2(0.35, 0.35))

func _place_card(slot: CardSlot, card_instance: CardInstance, scale: Vector2) -> void:
	var card: RiftCard = CARD_SCENE.instantiate()
	card.scale         = scale
	card.z_index       = 5
	slot.add_card(card)
	card.setup_from_card_instance(card_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)
	card.rotation_degrees = 90.0 if card_instance.is_exhausted() else 0.0
	if selected_board_uids.has(card_instance.uid):
		card.modulate = Color(0.55, 1.0, 0.55, 1.0)

# ─── Static State Rendering ───────────────────────────────────────────────────

func render_static_state(player: PlayerState, opponent: PlayerState) -> void:
	var deck_tex: Texture2D = load("res://Assets/Deck.jpg")

	if deck_tex != null:
		for panel in [board.player_main_deck, board.player_rune_deck, board.opponent_main_deck, board.opponent_rune_deck]:
			_clear_panel_images(panel)
			_add_panel_texture(panel, deck_tex)

	_render_legend_panel(board.player_champion_legend, player.legend)
	_render_legend_panel(board.opponent_champion_legend, opponent.legend)

	_render_battlefields(board.player_battlefield_panel, player.battlefields, player.picked_battlefield)
	_render_battlefields(board.opponent_battlefield_panel, opponent.battlefields, opponent.picked_battlefield)

	_render_arena_pick(board.arena_p0_panel, player.picked_battlefield, "Arena 1")
	_render_arena_pick(board.arena_p1_panel, opponent.picked_battlefield, "Arena 2")

	render_rune_panels(player, opponent)

func render_rune_panels(p0: PlayerState, p1: PlayerState) -> void:
	_render_runes(board.player_runes_panel, p0.rune_pool, p0.id)
	_render_runes(board.opponent_runes_panel, p1.rune_pool, p1.id)

func _render_legend_panel(panel: Panel, legend_instance: CardInstance) -> void:
	if panel == null or legend_instance == null or legend_instance.data == null:
		return

	_clear_panel_images(panel)
	if legend_instance.data.image_url == "":
		if legend_instance.data.texture != null:
			_add_panel_texture(panel, legend_instance.data.texture)
		return

	var card: RiftCard = CARD_SCENE.instantiate()
	panel.add_child(card)
	card.position = panel.size / 2.0
	card.scale    = Vector2(0.35, 0.35)
	card.setup_from_card_instance(legend_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)

func _render_battlefields(panel: Panel, battlefield_instances: Array, pick: BattlefieldInstance) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	if pick != null or battlefield_instances.is_empty():
		return

	var count: int        = battlefield_instances.size()
	var spacing: float    = 170.0
	var start_x: float    = (panel.size.x / 2.0) - (float(count - 1) * spacing / 2.0)

	for i in range(count):
		var inst: BattlefieldInstance = battlefield_instances[i]
		if inst == null:
			continue
		var card: RiftCard = CARD_SCENE.instantiate()
		panel.add_child(card)
		card.position = Vector2(start_x + i * spacing, panel.size.y / 2.0)
		card.scale    = Vector2(0.8, 0.8)
		card.z_index  = 5
		card.setup_from_battlefield_instance(inst)
		card.set_card_state(RiftCard.CardState.ON_BOARD)

func _render_arena_pick(panel: Panel, pick: BattlefieldInstance, player_label: String) -> void:
	if panel == null or pick == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	var label = panel.get_child(0) as Label
	if label:
		label.text = player_label

	var card: RiftCard = CARD_SCENE.instantiate()
	panel.add_child(card)
	card.position = panel.size / 2.0
	card.scale = Vector2(0.65, 0.65)

	card.z_index  = 5
	card.setup_from_battlefield_instance(pick)
	card.set_card_state(RiftCard.CardState.ON_BOARD)

func _render_runes(panel: Panel, runes: Array, player_id: int) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	if runes.is_empty():
		return

	var count: int     = runes.size()
	var spacing: float = 120.0
	var start_x: float = (panel.size.x / 2.0) - (float(count - 1) * spacing / 2.0)

	var active_player_id: int       = state.get_active_player().id
	var is_current_player: bool     = (player_id == active_player_id)

	for i in range(count):
		var rune_inst: RuneInstance = runes[i]
		if rune_inst == null or rune_inst.rune == null:
			continue

		var card: RiftCard = CARD_SCENE.instantiate()
		panel.add_child(card)
		card.position  = Vector2(start_x + i * spacing, panel.size.y / 2.0)
		card.scale     = Vector2(0.35, 0.35)
		card.z_index   = 5
		card.card_uid  = rune_inst.uid
		card.card_data = rune_inst.rune
		card.update_visuals()

		var is_exhausted: bool = rune_inst.is_exhausted()
		var is_selected: bool  = is_current_player and state.selected_rune_uids.has(rune_inst.uid)
		var can_select: bool   = is_current_player and state.awaiting_rune_payment and not is_exhausted and not is_selected

		card.rotation_degrees = 90.0 if is_exhausted else 0.0

		if is_exhausted:    card.modulate = Color(0.7, 0.7, 0.7, 1.0)
		elif is_selected:   card.modulate = Color(0.6, 1.0, 0.6, 1.0)
		elif can_select:    card.modulate = Color(1.15, 1.15, 0.75, 1.0)
		else:               card.modulate = Color.WHITE

		card.set_card_state(RiftCard.CardState.ON_BOARD)

func _clear_panel_images(panel: Panel) -> void:
	if panel == null:
		return
	for child in panel.get_children():
		if child is TextureRect:
			child.queue_free()

func _add_panel_texture(panel: Panel, tex: Texture2D, modulate_color := Color.WHITE) -> void:
	if panel == null or tex == null:
		return

	var tr           = TextureRect.new()
	tr.texture       = tex
	tr.anchor_left   = 0.0
	tr.anchor_top    = 0.0
	tr.anchor_right  = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left   = 4.0
	tr.offset_top    = 4.0
	tr.offset_right  = -4.0
	tr.offset_bottom = -4.0
	tr.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	tr.modulate      = modulate_color
	panel.add_child(tr)

# ─── Actions ──────────────────────────────────────────────────────────────────

func apply_backend_action(action: GameAction) -> void:
	var success := GameEngine.apply_action(state, action)
	if not success:
		print("Action failed: ", action.get_error_message())
	refresh_all_ui()

func apply_backend_action_and_wait(action: GameAction) -> void:
	var success := GameEngine.apply_action(state, action)
	if not success:
		print("Action failed: ", action.get_error_message())
		refresh_all_ui()
		return
	await wait_until_main()
	refresh_all_ui()

func try_play_card_to_slot(card_uid: int, slot_index: int) -> bool:
	var player = state.get_active_player()
	var action = PlayCardAction.new()
	action.player_id  = player.id
	action.card_uid   = card_uid
	action.slot_index = slot_index

	var success: bool = GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_hand_ui()
		render_slot(player, slot_index)
		_update_status_label()

	return true

func try_pick_runes_to_spend(rune_uid: int) -> bool:
	var player  = state.get_active_player()
	var action  = PickRuneAction.new(player.id, rune_uid)
	var success: bool = GameEngine.apply_action(state, action)

	if not success:
		status_label.text = action.get_error_message()
		return false

	if state.awaiting_rune_payment:
		refresh_payment_ui()
	else:
		refresh_all_ui()

	return true

func try_commit_to_battlefield(card_uids: Array[int], battlefield_index: int) -> bool:
	var player  = state.get_active_player()
	var action  = CommitToBattlefieldAction.new(player.id, card_uids, battlefield_index)
	var success = GameEngine.apply_action(state, action)

	if not success:
		status_label.text = action.get_error_message()
		return false

	refresh_all_ui()
	return true

func try_pass_priority() -> void:
	if not state.awaiting_showdown:
		return

	var showdown := state.active_showdown
	var player_id: int
	if not showdown.active_player_passed:
		player_id = state.active_player_index
	else:
		player_id = 1 - state.active_player_index

	var action := PassPriorityAction.new(player_id)
	apply_backend_action(action)

func adjust_damage_assignment(unit_uid: int, delta: int) -> void:
	if not state.awaiting_damage_assignment:
		return
	var ctx := state.active_combat_context
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	# Pool = loser's own might (what they are distributing)
	var pool: int = ctx.total_attacker_might if loser_is_attacker else ctx.total_defender_might
	var current: int = _pending_assignments.get(unit_uid, 0)
	var total_assigned: int = 0
	for uid in _pending_assignments:
		total_assigned += _pending_assignments[uid]
	var remaining: int = pool - total_assigned
	if delta > 0:
		_pending_assignments[unit_uid] = current + mini(delta, remaining)
	else:
		_pending_assignments[unit_uid] = maxi(0, current + delta)
	_update_status_label()

func try_confirm_damage() -> void:
	if not state.awaiting_damage_assignment:
		return
	var ctx := state.active_combat_context
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	# Loser is the one submitting: attacker if they lost, defender if they lost
	var player_id: int = ctx.attackers[0].player_id if loser_is_attacker \
		else ctx.defenders[0].player_id
	var action := ConfirmDamageAction.new(player_id, _pending_assignments)
	var success := GameEngine.apply_action(state, action)
	if not success:
		status_label.text = action.get_error_message()
		return
	_pending_assignments.clear()
	refresh_all_ui()

func try_move_to_battlefield(card_uid: int, battlefield_index: int) -> bool:
	var player  = state.get_active_player()
	var action  = MoveToBattlefieldAction.new(player.id, card_uid, battlefield_index)
	var success = GameEngine.apply_action(state, action)

	if not success:
		print("MoveToBattlefield failed: ", action.get_error_message())
		return false

	render_arena_slot(player)
	render_board()
	return true

func try_return_from_battlefield(card_uid: int, battlefield_index: int, slot_index: int = 0) -> bool:
	var player  = state.get_active_player()
	var action  = ReturnFromBattlefieldAction.new(player.id, card_uid, battlefield_index, slot_index)
	var success: bool = GameEngine.apply_action(state, action)

	if not success:
		print("ReturnFromBattlefield failed: ", action.get_error_message())
		return false

	render_arena_slot(player)
	render_slot(player, slot_index)
	return true

func try_end_turn() -> void:
	if state.awaiting_rune_payment:
		status_label.text = "Finish or cancel rune payment first."
		return

	var player = state.get_active_player()
	var action = EndTurnAction.new()
	action.player_id = player.id
	await apply_backend_action_and_wait(action)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func wait_until_main() -> void:
	var max_frames := 300
	var frames     := 0
	while state.phase != "MAIN" and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	if state.phase != "MAIN":
		push_warning("wait_until_main() timed out. Current phase: %s" % state.phase)

func _update_status_label() -> void:
	if state.awaiting_rune_payment:
		var remaining: int    = state.pending_card_cost - state.selected_rune_uids.size()
		var card_name: String = _get_pending_card_name()
		status_label.text             = "Select %d more rune(s) to play %s" % [remaining, card_name]
		cancel_payment_button.visible = true
		pass_priority_button.visible = false
		return

	if state.awaiting_showdown:
		var ctx: CombatContext = state.active_combat_context
		var atk := ctx.attackers.size()
		var def := ctx.defenders.size()
		var showdown := state.active_showdown
		var whose: String = "P%d" % (state.active_player_index if not showdown.active_player_passed \
			else 1 - state.active_player_index)
		status_label.text             = "Showdown! %d vs %d — %s: Pass or use ability." % [atk, def, whose]
		pass_priority_button.visible  = true
		cancel_payment_button.visible = false
		confirm_damage_button.visible = false
		return

	if state.awaiting_damage_assignment:
		var ctx: CombatContext = state.active_combat_context
		# loser_is_attacker: attacker had less might, distributes their own damage to defenders
		# else: defender had less might, distributes their own damage to attackers
		var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
		var pool: int = ctx.total_attacker_might if loser_is_attacker else ctx.total_defender_might
		# target_units = the winner's units receiving the loser's damage
		var target_units: Array = ctx.defenders if loser_is_attacker else ctx.attackers
		var loser_player_id: int = ctx.attackers[0].player_id if loser_is_attacker \
			else ctx.defenders[0].player_id
		for unit in target_units:
			if not _pending_assignments.has(unit.uid):
				_pending_assignments[unit.uid] = 0
		var total_assigned: int = 0
		for uid in _pending_assignments:
			total_assigned += _pending_assignments[uid]
		var remaining: int = pool - total_assigned
		var parts: Array = []
		for unit in target_units:
			parts.append("%s: %d" % [unit.card_instance.data.card_name, _pending_assignments.get(unit.uid, 0)])
		status_label.text             = "P%d assign %d dmg (left: %d) — L-click +1, R-click -1\n%s" % [
			loser_player_id, pool, remaining, "  |  ".join(parts)
		]
		pass_priority_button.visible  = false
		cancel_payment_button.visible = false
		confirm_damage_button.visible = true
		return

	status_label.text             = ""
	cancel_payment_button.visible = false
	pass_priority_button.visible  = false
	confirm_damage_button.visible = false

func _get_pending_card_name() -> String:
	for card in state.get_active_player().hand:
		if card.uid == state.pending_card_uid:
			return card.data.card_name
	return "card"

func _on_pass_priority_pressed() -> void:
	try_pass_priority()

func _on_confirm_damage_pressed() -> void:
	try_confirm_damage()

func _on_cancel_payment_pressed() -> void:
	if not state.awaiting_rune_payment:
		return

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
