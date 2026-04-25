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
var _pending_board_card              = null
var _press_position:     Vector2    = Vector2.ZERO

func _ready() -> void:
	screen_size     = get_viewport_rect().size
	board_reference = $"../Board"
	game_controller = $"../GameController"

func _process(_delta) -> void:
	# Promote a pending board card to a real drag once the mouse moves far enough
	if _pending_board_card != null:
		var dist: float = get_global_mouse_position().distance_to(_press_position)
		if dist >= DRAG_THRESHOLD:
			var card = _pending_board_card
			_pending_board_card = null
			_start_drag(card)

	if dragged_card:
		var mp: Vector2 = get_global_mouse_position()
		var target: Vector2 = mp + drag_offset

		# 🔑 account for card size
		var half_w = RiftCard.CARD_WIDTH  * dragged_card.scale.x / 2.0
		var half_h = RiftCard.CARD_HEIGHT * dragged_card.scale.y / 2.0

		target.x = clamp(target.x, half_w, screen_size.x - half_w)
		target.y = clamp(target.y, half_h, screen_size.y - half_h)

		dragged_card.global_position = target
		_highlight_slots()
		return

func _input(event) -> void:
	if not _is_local_turn():
		return
	if event is InputEventMouseButton:
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
	
	if state.awaiting_unit_target:
		game_controller.try_select_unit_target(card_found.card_uid)
		return
	
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
			_pending_board_card = card_found
			_press_position = get_global_mouse_position()

	elif zone == "ARENA":
		var inst = _get_card_instance(card_found.card_uid)
		if inst != null and not inst.is_exhausted():
			_start_drag(card_found)

# ─── Release: place card or toggle selection ──────────────────────────────────

func _try_release() -> void:
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
				var result: String = game_controller.try_play_card(dragged_card.card_uid, slot_index)

				if result == "choice":
					# Keep the dragged card alive for now, but return it visually to hand
					# so the player can click a choice button.
					_return_to_hand()
					return

				if result == "played":
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

func _start_drag(card: RiftCard) -> void:
	var mouse: Vector2 = get_global_mouse_position()

	# 🛑 Kill hover + snap back to original state
	if card._is_hovered:
		if card._hover_tween:
			card._hover_tween.kill()

		card._is_hovered = false
		RiftCard._hovered_card = null

		# 🔑 Snap back instantly (no tween)
		card.scale = card._base_scale
		card.rotation_degrees = card._original_rotation
		card.position = card._original_position
		card.z_index = card._original_z_index

	# 🟢 Now everything is stable → compute offset
	var local_click: Vector2 = card.to_local(mouse)

	# 🟢 Reparent
	var old_parent = card.get_parent()
	if old_parent != get_parent():
		old_parent.remove_child(card)
		get_parent().add_child(card)

	# 🟢 Apply offset
	drag_offset  = -local_click
	dragged_card = card

	RiftCard._drag_active = true  # prevent other cards from entering hover while this card is dragged
	card.set_card_state(RiftCard.CardState.DRAGGING)
	card.z_index = 100

func _return_to_hand() -> void:
	var card     = dragged_card
	dragged_card = null
	RiftCard._drag_active = false
	_clear_slot_highlights()
	drag_offset      = Vector2.ZERO
	card._base_scale = card.scale
	# return_card() calls add_child(), which re-parents back to the hand node.
	_active_hand().return_card(card)

func _clear_drag() -> void:
	if dragged_card != null:
		var zone := _get_card_zone(dragged_card.card_uid)
		if zone == "HAND":
			# Hand card that wasn't placed — let HandManager clean it up
			_active_hand().remove_card(dragged_card)
		else:
			# Board/Arena card — just free the node; game state and re-render handle the rest
			dragged_card.queue_free()
	dragged_card = null
	RiftCard._drag_active = false
	_clear_slot_highlights()
	drag_offset  = Vector2.ZERO

func _active_hand():
	var id = game_controller.state.get_active_player().id
	return $"../P0/P0_Hand" if id == NetworkManager.local_player_id else $"../P1/P1_Hand"

# ─── Slot highlights ──────────────────────────────────────────────────────────

func _highlight_slots() -> void:
	_clear_slot_highlights()
	var player     = game_controller.state.get_active_player()
	var local_id   = NetworkManager.local_player_id
	var base_slots = board_reference._player_slot_nodes if player.id == local_id else board_reference._p1_slot_nodes
	var bf_slots   = [board_reference._p0_bf_slot_left, board_reference._p0_bf_slot_right] if player.id == local_id \
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
	var base_slots = board_reference._player_slot_nodes if player.id == NetworkManager.local_player_id else board_reference._p1_slot_nodes
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
	# HAND and BOARD: active player only — prevents opponent from acting out of turn
	var active = game_controller.state.get_active_player()
	for c in active.hand:
		if c.uid == card_uid: return "HAND"
	for slot in active.board_slots:
		for c in slot:
			if c.uid == card_uid: return "BOARD"
	# ARENA: search both players — needed to identify opponent units during combat
	for player in game_controller.state.players:
		for lane in player.battlefield_slots:
			for c in lane:
				if c.uid == card_uid: return "ARENA"
	return "NONE"

func _get_card_instance(card_uid: int):
	# HAND and BOARD: active player only
	var active = game_controller.state.get_active_player()
	for c in active.hand:
		if c.uid == card_uid: return c
	for slot in active.board_slots:
		for c in slot:
			if c.uid == card_uid: return c
	# ARENA: both players — needed during combat interactions
	for player in game_controller.state.players:
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
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	var target_units = ctx.defenders if loser_is_attacker else ctx.attackers
	for unit in target_units:
		if unit.uid == card_found.card_uid:
			game_controller.adjust_damage_assignment(unit.uid, delta)
			return

func _get_rune_instance(rune_uid: int) -> RuneInstance:
	var state: GameState = game_controller.state
	var player: PlayerState = state.players[state.pending_payment_player_id] \
		if state.awaiting_rune_payment and state.pending_payment_player_id != -1 \
		else state.get_active_player()
	for rune in player.rune_pool:
		if rune.uid == rune_uid: return rune
	return null

func _is_local_turn() -> bool:
	if not NetworkManager.is_network_mode:
		return true
	var gstate: GameState = game_controller.state
	if gstate.awaiting_damage_assignment:
		var ctx := gstate.active_combat_context
		if ctx == null:
			return false
		var loser_is_attacker := ctx.total_defender_might > ctx.total_attacker_might
		var assigner_id: int = ctx.attackers[0].player_id if loser_is_attacker else ctx.defenders[0].player_id
		return assigner_id == NetworkManager.local_player_id
	return NetworkManager.local_player_id == gstate.get_active_player().id
