extends Node2D

const COLLISION_MASK_SLOT  = 2
const COLLISION_MASK_ARENA = 4
const DRAG_THRESHOLD       = 10.0

var board_reference
var game_controller
var screen_size  = Vector2()
var drag_offset  = Vector2.ZERO
var dragged_card = null

# Multi-select state for board cards
var _selected_uids:      Array[int] = []
var _pending_board_card              = null   # board card pressed but not yet dragged
var _press_position:     Vector2    = Vector2.ZERO

func _ready() -> void:
	screen_size     = get_viewport_rect().size
	board_reference = $"../Board"
	game_controller = $"../GameController"

func _process(_delta) -> void:
	if dragged_card:
		var mp = get_global_mouse_position()
		dragged_card.global_position = Vector2(
			clamp(mp.x - drag_offset.x, 0, screen_size.x),
			clamp(mp.y - drag_offset.y, 0, screen_size.y)
		)
		_highlight_slots()
		return

	# Threshold-based drag start for board cards
	if _pending_board_card != null:
		if get_global_mouse_position().distance_to(_press_position) > DRAG_THRESHOLD:
			_start_drag(_pending_board_card)
			_pending_board_card = null

func _input(event) -> void:
	if event is InputEventMouseButton:
		# Damage assignment mode — left-click adds, right-click removes
		if game_controller.state.awaiting_damage_assignment:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_try_assign_damage(1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				_try_assign_damage(-1)
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_start_drag()
			else:
				_try_release()

# ─── Press: pick up a card or begin selection ─────────────────────────────────

func _try_start_drag() -> void:
	var card_found = _get_card_under_cursor()
	if card_found == null:
		return

	var state: GameState = game_controller.state

	# Rune tap — handled separately, not a drag
	var rune := _get_rune_instance(card_found.card_uid)
	if rune != null:
		game_controller.try_pick_runes_to_spend(card_found.card_uid)
		return

	if state.awaiting_rune_payment:
		game_controller.status_label.text = "Finish selecting runes first."
		return

	var zone := _get_card_zone(card_found.card_uid)

	if zone == "HAND":
		_selected_uids.clear()
		game_controller.selected_board_uids.clear()
		_start_drag(card_found)

	elif zone == "BOARD":
		var inst = _get_card_instance(card_found.card_uid)
		if inst != null and not inst.is_exhausted():
			# Record press; actual drag starts only after threshold movement
			_pending_board_card = card_found
			_press_position = get_global_mouse_position()

	elif zone == "ARENA":
		var inst = _get_card_instance(card_found.card_uid)
		if inst != null and not inst.is_exhausted():
			_start_drag(card_found)

# ─── Release: place card or toggle selection ──────────────────────────────────

func _try_release() -> void:
	# Click on board card (no drag started) → toggle selection
	if _pending_board_card != null:
		_toggle_board_selection(_pending_board_card.card_uid)
		_pending_board_card = null
		return

	if dragged_card == null:
		return

	var origin_zone := _get_card_zone(dragged_card.card_uid)
	var space        = get_world_2d().direct_space_state
	var params       = PhysicsPointQueryParameters2D.new()
	params.position           = get_global_mouse_position()
	params.collide_with_areas = true

	if origin_zone == "HAND":
		params.collision_mask = COLLISION_MASK_SLOT
		if space.intersect_point(params).size() > 0:
			var slot_index: int = board_reference.get_slot_index_under_mouse()
			if slot_index != -1:
				var played: bool = game_controller.try_play_card_to_slot(dragged_card.card_uid, slot_index)
				if played:
					if game_controller.state.awaiting_rune_payment:
						_return_to_hand()
						game_controller.refresh_payment_ui()
					else:
						_clear_drag()
					return
		_return_to_hand()
		return

	if origin_zone == "BOARD":
		params.collision_mask = COLLISION_MASK_ARENA
		if space.intersect_point(params).size() > 0:
			var bf_data = board_reference.get_battlefield_half_under_mouse()
			if not bf_data.is_empty():
				var active_id: int = game_controller.state.get_active_player().id
				if int(bf_data["player"]) == active_id:
					var lane := int(bf_data["lane"])
					var uids := _get_commit_uids()
					var committed: bool = game_controller.try_commit_to_battlefield(uids, lane)
					if committed:
						_selected_uids.clear()
						game_controller.selected_board_uids.clear()
						_clear_drag()
						return
		game_controller.refresh_all_ui()
		_clear_drag()
		return

	if origin_zone == "ARENA":
		params.collision_mask = COLLISION_MASK_SLOT
		if space.intersect_point(params).size() > 0:
			var slot_index: int = board_reference.get_slot_index_under_mouse()
			var bf_index:   int = _get_battlefield_index(dragged_card.card_uid)
			if slot_index != -1 and bf_index != -1:
				var returned: bool = game_controller.try_return_from_battlefield(dragged_card.card_uid, bf_index, slot_index)
				if returned:
					_clear_drag()
					return
		game_controller.refresh_all_ui()
		_clear_drag()
		return

# ─── Selection ────────────────────────────────────────────────────────────────

func _toggle_board_selection(uid: int) -> void:
	if _selected_uids.has(uid):
		_selected_uids.erase(uid)
	else:
		_selected_uids.append(uid)
	game_controller.selected_board_uids.assign(_selected_uids)
	game_controller.render_board()

func _get_commit_uids() -> Array[int]:
	if not _selected_uids.is_empty() and _selected_uids.has(dragged_card.card_uid):
		return _selected_uids.duplicate()
	var result: Array[int] = [dragged_card.card_uid]
	return result

# ─── Drag state ───────────────────────────────────────────────────────────────

func _start_drag(card) -> void:
	dragged_card = card
	drag_offset  = get_global_mouse_position() - card.global_position
	card.set_card_state(RiftCard.CardState.DRAGGING)
	card.z_index = 100

func _return_to_hand() -> void:
	var card     = dragged_card
	dragged_card = null
	_clear_slot_highlights()
	drag_offset  = Vector2.ZERO
	_active_hand().return_card(card)

func _clear_drag() -> void:
	if dragged_card != null:
		_active_hand().remove_card(dragged_card)
	dragged_card = null
	_clear_slot_highlights()
	drag_offset  = Vector2.ZERO

func _active_hand():
	var id = game_controller.state.get_active_player().id
	return $"../P0/P0_Hand" if id == 0 else $"../P1/P1_Hand"

# ─── Slot highlights ──────────────────────────────────────────────────────────

func _highlight_slots() -> void:
	_clear_slot_highlights()
	var player     = game_controller.state.get_active_player()
	var base_slots = board_reference._player_slot_nodes if player.id == 0 else board_reference._p1_slot_nodes
	var bf_slots   = [board_reference._p0_bf_slot_left, board_reference._p0_bf_slot_right] if player.id == 0 \
				   else [board_reference._p1_bf_slot_left, board_reference._p1_bf_slot_right]
	var zone       = _get_card_zone(dragged_card.card_uid)

	if zone == "HAND" or zone == "ARENA":
		for slot in base_slots:
			slot.highlight(true, true)
	elif zone == "BOARD":
		var inst = _get_card_instance(dragged_card.card_uid)
		if inst != null and not inst.is_exhausted():
			for bf_slot in bf_slots:
				if bf_slot != null:
					bf_slot.highlight(true, true)

func _clear_slot_highlights() -> void:
	var player     = game_controller.state.get_active_player()
	var base_slots = board_reference._player_slot_nodes if player.id == 0 else board_reference._p1_slot_nodes
	for slot in base_slots:
		slot.highlight(false)
	for bf_slot in [board_reference._p0_bf_slot_left, board_reference._p0_bf_slot_right,
					board_reference._p1_bf_slot_left, board_reference._p1_bf_slot_right]:
		if bf_slot != null:
			bf_slot.highlight(false)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_card_under_cursor() -> RiftCard:
	var space  = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position           = get_global_mouse_position()
	params.collide_with_areas = true
	for hit in space.intersect_point(params):
		var parent = hit.collider.get_parent() if hit.collider else null
		if parent is RiftCard:
			return parent
	return null

func _get_card_zone(card_uid: int) -> String:
	var player = game_controller.state.get_active_player()
	for c in player.hand:
		if c.uid == card_uid: return "HAND"
	for slot in player.board_slots:
		for c in slot:
			if c.uid == card_uid: return "BOARD"
	for lane in player.battlefield_slots:
		for c in lane:
			if c.uid == card_uid: return "ARENA"
	return "NONE"

func _get_card_instance(card_uid: int):
	var player = game_controller.state.get_active_player()
	for c in player.hand:
		if c.uid == card_uid: return c
	for slot in player.board_slots:
		for c in slot:
			if c.uid == card_uid: return c
	for lane in player.battlefield_slots:
		for c in lane:
			if c.uid == card_uid: return c
	return null

func _get_battlefield_index(card_uid: int) -> int:
	var player = game_controller.state.get_active_player()
	for i in range(player.battlefield_slots.size()):
		for c in player.battlefield_slots[i]:
			if c.uid == card_uid: return i
	return -1

func _try_assign_damage(delta: int) -> void:
	var card_found = _get_card_under_cursor()
	if card_found == null:
		return
	var ctx: CombatContext = game_controller.state.active_combat_context
	for defender in ctx.defenders:
		if defender.uid == card_found.card_uid:
			game_controller.adjust_damage_assignment(defender.uid, delta)
			return

func _get_rune_instance(rune_uid: int) -> RuneInstance:
	var state: GameState = game_controller.state
	var player: PlayerState = state.players[state.pending_payment_player_id] \
		if state.awaiting_rune_payment and state.pending_payment_player_id != -1 \
		else state.get_active_player()
	for rune in player.rune_pool:
		if rune.uid == rune_uid: return rune
	return null
