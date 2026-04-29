extends Node2D

const COLLISION_MASK_SLOT  := 2
const COLLISION_MASK_ARENA := 4
const DRAG_THRESHOLD       := 10.0

var board_reference
var game_controller

var screen_size: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var dragged_card = null

var _selected_uids: Array[int] = []
var _pending_board_card = null
var _press_position: Vector2 = Vector2.ZERO

var _legend_targeting := false
var _legend_player_id := -1


func _ready() -> void:
	screen_size = get_viewport_rect().size
	board_reference = $"../Board"
	game_controller = $"../GameController"


func _process(_delta: float) -> void:
	if game_controller.state.awaiting_spell_destination and dragged_card == null:
		highlight_spell_destinations()
	elif dragged_card == null and not _legend_targeting:
		_clear_slot_highlights()

	if _pending_board_card != null:
		var dist: float = get_global_mouse_position().distance_to(_press_position)
		if dist >= DRAG_THRESHOLD:
			var card = _pending_board_card
			_pending_board_card = null
			_start_drag(card)

	if dragged_card != null:
		_update_dragged_card()


func _input(event) -> void:
	if not event is InputEventMouseButton:
		return
	if not _is_local_turn():
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _legend_targeting:
			_cancel_legend_targeting()
		return

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


func _update_dragged_card() -> void:
	var mp: Vector2 = get_global_mouse_position()
	var target: Vector2 = mp + drag_offset

	var half_w: float = RiftCard.CARD_WIDTH * dragged_card.scale.x / 2.0
	var half_h: float = RiftCard.CARD_HEIGHT * dragged_card.scale.y / 2.0

	target.x = clamp(target.x, half_w, screen_size.x - half_w)
	target.y = clamp(target.y, half_h, screen_size.y - half_h)

	dragged_card.global_position = target
	_highlight_slots()


# ─── Press ───────────────────────────────────────────────────────────────────

func _try_start_drag() -> void:
	var state: GameState = game_controller.state

	if state.awaiting_spell_destination:
		_try_select_spell_destination()
		return

	var card_found: RiftCard = _get_card_under_cursor()
	if card_found == null:
		return

	if _legend_targeting:
		_try_select_legend_target(card_found)
		return

	var clicked_card: CardInstance = _get_card_instance_any_player(card_found.card_uid)
	if clicked_card != null and clicked_card.data.type == CardData.CardType.LEGEND:
		_try_start_legend_targeting(clicked_card)
		return
	
	if _is_active_player_champion(card_found.card_uid):
		game_controller.try_move_champion_to_base()
		return
	
	if state.awaiting_unit_target:
		game_controller.try_select_unit_target(card_found.card_uid)
		return

	if state.awaiting_spell_targets:
		game_controller.try_select_spell_target(card_found.card_uid)
		return

	var rune: RuneInstance = _get_rune_instance(card_found.card_uid)
	if rune != null:
		game_controller.try_pick_runes_to_spend(card_found.card_uid)
		return

	if state.awaiting_rune_payment:
		game_controller.status_label.text = "Finish selecting runes first."
		return

	var zone: String = _get_card_zone(card_found.card_uid)

	match zone:
		"HAND":
			_selected_uids.clear()
			game_controller.selected_board_uids.clear()
			_start_drag(card_found)

		"BOARD":
			var inst: CardInstance = _get_card_instance(card_found.card_uid)
			if inst != null and not inst.is_exhausted():
				_pending_board_card = card_found
				_press_position = get_global_mouse_position()

		"ARENA":
			_try_start_arena_drag(card_found)


func _try_start_arena_drag(card_found: RiftCard) -> void:
	var state: GameState = game_controller.state
	var inst: CardInstance = _get_card_instance(card_found.card_uid)
	var unit: UnitState = state.unit_registry.get_unit(card_found.card_uid)
	var actor_id: int = game_controller.get_actor_player().id

	if unit == null or unit.player_id != actor_id:
		game_controller.status_label.text = "You do not control this unit."
		return

	if inst != null and not inst.is_exhausted():
		_start_drag(card_found)


# ─── Legend Targeting ─────────────────────────────────────────────────────────

func _try_start_legend_targeting(clicked_card: CardInstance) -> void:
	var state: GameState = game_controller.state
	var owner: int = _find_legend_owner(clicked_card.uid)

	if owner == -1:
		game_controller.status_label.text = "Invalid legend."
		return

	var actor: PlayerState = game_controller.get_actor_player()
	if owner != actor.id:
		game_controller.status_label.text = "You can only use your own legend."
		return

	_legend_player_id = owner
	_legend_targeting = true
	_pending_board_card = null

	game_controller.start_legend_mode(owner)
	game_controller.status_label.text = "Choose a friendly unit for legend ability."
	_highlight_friendly_units_for_legend(owner)


func _try_select_legend_target(card_found: RiftCard) -> void:
	var state: GameState = game_controller.state
	var unit: UnitState = state.unit_registry.get_unit(card_found.card_uid)

	if unit == null:
		game_controller.status_label.text = "Choose a friendly unit."
		return

	if unit.player_id != _legend_player_id:
		game_controller.status_label.text = "Choose a friendly unit."
		return

	var used: bool = game_controller.try_use_legend_ability(unit.uid)

	_legend_targeting = false
	_legend_player_id = -1
	_clear_unit_highlights()
	_clear_slot_highlights()

	if not used:
		game_controller.status_label.text = "Could not use legend ability."


func _cancel_legend_targeting() -> void:
	_legend_targeting = false
	_legend_player_id = -1
	_clear_unit_highlights()
	_clear_slot_highlights()
	game_controller.cancel_legend_mode()
	game_controller.status_label.text = "Legend ability cancelled."


func _find_legend_owner(legend_uid: int) -> int:
	for player: PlayerState in game_controller.state.players:
		if player.legend != null and player.legend.uid == legend_uid:
			return player.id
	return -1


# ─── Spell Destination ────────────────────────────────────────────────────────

func _try_select_spell_destination() -> void:
	var state: GameState = game_controller.state

	var target: UnitState = null
	if state.pending_spell_target_uids.size() > 0:
		target = state.unit_registry.get_unit(state.pending_spell_target_uids[0])

	if target == null:
		return

	var space = get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true

	params.collision_mask = COLLISION_MASK_SLOT
	if space.intersect_point(params).size() > 0:
		var slot_data: Dictionary = board_reference.get_board_slot_data_under_mouse()
		if not slot_data.is_empty():
			var destination_player_id: int = int(slot_data["player"])
			var slot_index: int = int(slot_data["slot"])

			if destination_player_id == target.player_id:
				game_controller.try_select_spell_destination(
					"BOARD",
					destination_player_id,
					slot_index
				)
			else:
				game_controller.status_label.text = "Choose the target unit's board."
			return

	params.collision_mask = COLLISION_MASK_ARENA
	if space.intersect_point(params).size() > 0:
		var bf_data: Dictionary = board_reference.get_battlefield_half_under_mouse()
		if not bf_data.is_empty() and int(bf_data["player"]) == target.player_id:
			game_controller.try_select_spell_destination(
				"BATTLEFIELD",
				target.player_id,
				int(bf_data["lane"])
			)


# ─── Release ─────────────────────────────────────────────────────────────────

func _try_release() -> void:
	if _legend_targeting:
		return

	if _pending_board_card != null:
		_toggle_board_selection(_pending_board_card.card_uid)
		_pending_board_card = null
		return

	if dragged_card == null:
		return

	var origin_zone: String = _get_card_zone(dragged_card.card_uid)

	match origin_zone:
		"HAND":
			_release_hand_card()

		"BOARD":
			_release_board_card()

		"ARENA":
			_release_arena_card()

		_:
			_clear_drag()


func _release_hand_card() -> void:
	var space = get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true

	params.collision_mask = COLLISION_MASK_ARENA
	if space.intersect_point(params).size() > 0:
		var bf_data: Dictionary = board_reference.get_battlefield_half_under_mouse()
		if not bf_data.is_empty():
			var actor_id: int = game_controller.get_actor_player().id
			var card: CardInstance = _get_card_instance(dragged_card.card_uid)

			if card != null and card.data.card_id == "OGN-161/298" and int(bf_data["player"]) != actor_id:
				var played_enemy_bf: bool = game_controller.try_play_card_to_enemy_battlefield(
					dragged_card.card_uid,
					int(bf_data["player"]),
					int(bf_data["lane"])
				)

				if played_enemy_bf:
					_clear_drag()
					return

	params.collision_mask = COLLISION_MASK_SLOT
	if space.intersect_point(params).size() > 0:
		var slot_index: int = board_reference.get_slot_index_under_mouse()
		if slot_index != -1:
			var result: String = game_controller.try_play_card(dragged_card.card_uid, slot_index)

			if result == "choice":
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


func _release_board_card() -> void:
	var space = get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_ARENA

	if space.intersect_point(params).size() > 0:
		var bf_data: Dictionary = board_reference.get_battlefield_half_under_mouse()
		if not bf_data.is_empty():
			var actor_id: int = game_controller.get_actor_player().id
			if int(bf_data["player"]) == actor_id:
				var lane: int = int(bf_data["lane"])
				var uids: Array[int] = _get_commit_uids()
				var committed: bool = game_controller.try_commit_to_battlefield(uids, lane)

				if committed:
					_selected_uids.clear()
					game_controller.selected_board_uids.clear()
					_clear_drag()
					return

	game_controller.refresh_all_ui()
	_clear_drag()


func _release_arena_card() -> void:
	var space = get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true
	params.collision_mask = COLLISION_MASK_SLOT

	if space.intersect_point(params).size() > 0:
		var slot_index: int = board_reference.get_slot_index_under_mouse()
		var bf_location: Dictionary = _get_battlefield_location(dragged_card.card_uid)

		if slot_index != -1 and not bf_location.is_empty():
			var returned: bool = game_controller.try_return_from_any_battlefield(
				dragged_card.card_uid,
				int(bf_location["player_id"]),
				int(bf_location["battlefield_index"]),
				slot_index
			)

			if returned:
				_clear_drag()
				return

	game_controller.refresh_all_ui()
	_clear_drag()


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

	return [dragged_card.card_uid]


# ─── Drag State ───────────────────────────────────────────────────────────────

func _start_drag(card: RiftCard) -> void:
	var mouse: Vector2 = get_global_mouse_position()

	if card._is_hovered:
		if card._hover_tween:
			card._hover_tween.kill()

		card._is_hovered = false
		RiftCard._hovered_card = null
		card.scale = card._base_scale
		card.rotation_degrees = card._original_rotation
		card.position = card._original_position
		card.z_index = card._original_z_index

	var local_click: Vector2 = card.to_local(mouse)

	var old_parent = card.get_parent()
	if old_parent != get_parent():
		old_parent.remove_child(card)
		get_parent().add_child(card)

	drag_offset = -local_click
	dragged_card = card

	RiftCard._drag_active = true
	card.set_card_state(RiftCard.CardState.DRAGGING)
	card.z_index = 100


func _return_to_hand() -> void:
	var card = dragged_card
	dragged_card = null
	RiftCard._drag_active = false
	_clear_slot_highlights()
	drag_offset = Vector2.ZERO

	if card != null:
		card._base_scale = card.scale
		_active_hand().return_card(card)


func _clear_drag() -> void:
	if dragged_card != null:
		var zone: String = _get_card_zone(dragged_card.card_uid)
		if zone == "HAND":
			_active_hand().remove_card(dragged_card)
		else:
			dragged_card.queue_free()

	dragged_card = null
	RiftCard._drag_active = false
	_clear_slot_highlights()
	drag_offset = Vector2.ZERO


func _active_hand():
	var id: int = game_controller.get_actor_player().id
	return $"../P0/P0_Hand" if id == NetworkManager.local_player_id else $"../P1/P1_Hand"


# ─── Highlights ───────────────────────────────────────────────────────────────

func _highlight_slots() -> void:
	_clear_slot_highlights()

	if dragged_card == null:
		return

	var actor: PlayerState = game_controller.get_actor_player()
	var actor_id: int      = actor.id
	var local_id: int      = NetworkManager.local_player_id

	var base_slots: Array = board_reference._player_slot_nodes if actor_id == local_id else board_reference._p1_slot_nodes
	var bf_slots: Array = [
		board_reference._p0_bf_slot_left,
		board_reference._p0_bf_slot_right
	] if actor_id == local_id else [
		board_reference._p1_bf_slot_left,
		board_reference._p1_bf_slot_right
	]

	var zone: String = _get_card_zone(dragged_card.card_uid)

	if zone == "HAND" or zone == "ARENA":
		for slot in base_slots:
			if slot != null:
				slot.highlight(true, true)

		_highlight_enemy_battlefields_for_deadbloom(actor_id)

	elif zone == "BOARD":
		var inst: CardInstance = _get_card_instance(dragged_card.card_uid)
		if inst != null and not inst.is_exhausted():
			for bf_slot in bf_slots:
				if bf_slot != null:
					bf_slot.highlight(true, true)


func _highlight_enemy_battlefields_for_deadbloom(actor_id: int) -> void:
	var card: CardInstance = _get_card_instance(dragged_card.card_uid)
	if card == null or card.data.card_id != "OGN-161/298":
		return

	var enemy_id: int = 1 - actor_id
	var local_id: int = NetworkManager.local_player_id
	var enemy_player: PlayerState = game_controller.state.players[enemy_id]
	var enemy_bf_slots: Array = [
		board_reference._p1_bf_slot_left,
		board_reference._p1_bf_slot_right
	] if enemy_id != local_id else [
		board_reference._p0_bf_slot_left,
		board_reference._p0_bf_slot_right
	]

	for i in range(enemy_bf_slots.size()):
		if enemy_bf_slots[i] != null and not enemy_player.battlefield_slots[i].is_empty():
			enemy_bf_slots[i].highlight(true, true)


func _highlight_friendly_units_for_legend(player_id: int) -> void:
	_clear_slot_highlights()
	await get_tree().process_frame 

	for unit: UnitState in game_controller.state.unit_registry.get_units_for_player(player_id):
		var card_node := _find_visible_card_node(unit.uid)
		if card_node != null:
			card_node.modulate = Color(0.6, 1.0, 0.6, 1.0)

func _find_visible_card_node(card_uid: int) -> RiftCard:
	return _find_visible_card_node_recursive(get_tree().current_scene, card_uid)


func _find_visible_card_node_recursive(node: Node, card_uid: int) -> RiftCard:
	if node is RiftCard and node.card_uid == card_uid:
		return node

	for child in node.get_children():
		var found := _find_visible_card_node_recursive(child, card_uid)
		if found != null:
			return found

	return null
	
func _clear_slot_highlights() -> void:
	for slot in board_reference._player_slot_nodes:
		if slot != null:
			slot.highlight(false)

	for slot in board_reference._p1_slot_nodes:
		if slot != null:
			slot.highlight(false)

	for bf_slot in [
		board_reference._p0_bf_slot_left,
		board_reference._p0_bf_slot_right,
		board_reference._p1_bf_slot_left,
		board_reference._p1_bf_slot_right
	]:
		if bf_slot != null:
			bf_slot.highlight(false)


func highlight_spell_destinations() -> void:
	_clear_slot_highlights()

	if not game_controller.state.awaiting_spell_destination:
		return

	var state: GameState = game_controller.state
	var destination_player_id: int = -1

	if state.pending_spell_target_uids.size() > 0:
		var target_uid: int = state.pending_spell_target_uids[0]
		var target: UnitState = state.unit_registry.get_unit(target_uid)
		if target != null:
			destination_player_id = target.player_id

	if destination_player_id == -1:
		return

	var local_id: int = NetworkManager.local_player_id
	var bf_slots: Array = [
		board_reference._p0_bf_slot_left,
		board_reference._p0_bf_slot_right
	] if destination_player_id == local_id else [
		board_reference._p1_bf_slot_left,
		board_reference._p1_bf_slot_right
	]

	for bf_slot in bf_slots:
		if bf_slot != null:
			bf_slot.highlight(true, true)

	var board_slots: Array = board_reference._player_slot_nodes if destination_player_id == local_id else board_reference._p1_slot_nodes
	for slot in board_slots:
		if slot != null:
			slot.highlight(true, true)


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _get_card_under_cursor() -> RiftCard:
	var space = get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true

	for hit in space.intersect_point(params):
		var parent = hit.collider.get_parent() if hit.collider else null
		if parent is RiftCard:
			return parent

	return null


func _get_card_zone(card_uid: int) -> String:
	var actor: PlayerState = game_controller.get_actor_player()

	for c in actor.hand:
		if c.uid == card_uid:
			return "HAND"

	for slot in actor.board_slots:
		for c in slot:
			if c.uid == card_uid:
				return "BOARD"

	for player in game_controller.state.players:
		for lane in player.battlefield_slots:
			for c in lane:
				if c.uid == card_uid:
					return "ARENA"

	return "NONE"


func _get_card_instance(card_uid: int):
	var actor: PlayerState = game_controller.get_actor_player()

	for c in actor.hand:
		if c.uid == card_uid:
			return c

	for slot in actor.board_slots:
		for c in slot:
			if c.uid == card_uid:
				return c

	for player in game_controller.state.players:
		for lane in player.battlefield_slots:
			for c in lane:
				if c.uid == card_uid:
					return c

	return null


func _get_card_instance_any_player(card_uid: int):
	for player in game_controller.state.players:
		if player.legend != null and player.legend.uid == card_uid:
			return player.legend

		for c in player.hand:
			if c.uid == card_uid:
				return c

		for slot in player.board_slots:
			for c in slot:
				if c.uid == card_uid:
					return c

		for lane in player.battlefield_slots:
			for c in lane:
				if c.uid == card_uid:
					return c

	return null


func _get_battlefield_location(card_uid: int) -> Dictionary:
	for player in game_controller.state.players:
		for i in range(player.battlefield_slots.size()):
			for c in player.battlefield_slots[i]:
				if c.uid == card_uid:
					return {
						"player_id": player.id,
						"battlefield_index": i
					}

	return {}


func _get_rune_instance(rune_uid: int) -> RuneInstance:
	var state: GameState = game_controller.state
	var player: PlayerState = state.players[state.pending_payment_player_id] if state.awaiting_rune_payment and state.pending_payment_player_id != -1 else game_controller.get_actor_player()

	for rune in player.rune_pool:
		if rune.uid == rune_uid:
			return rune

	return null


func _try_assign_damage(delta: int) -> void:
	var card_found: RiftCard = _get_card_under_cursor()
	if card_found == null:
		return

	var ctx: CombatContext = game_controller.state.active_combat_context
	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	var target_units: Array = ctx.defenders if loser_is_attacker else ctx.attackers

	for unit: UnitState in target_units:
		if unit.uid == card_found.card_uid:
			game_controller.adjust_damage_assignment(unit.uid, delta)
			return

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

func _is_active_player_champion(card_uid: int) -> bool:
	var player: PlayerState = game_controller.get_actor_player()
	return player.champion != null and player.champion.uid == card_uid

func _clear_unit_highlights() -> void:
	_clear_unit_highlights_recursive(get_tree().current_scene)


func _clear_unit_highlights_recursive(node: Node) -> void:
	if node is RiftCard:
		node.modulate = Color.WHITE

	for child in node.get_children():
		_clear_unit_highlights_recursive(child)
