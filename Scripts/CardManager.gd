extends Node2D
## CardManager — Drag, drop, hover highlight, and slot placement.

const COLLISION_MASK_CARD      := 1
const COLLISION_MASK_CARD_SLOT := 2
const DEFAULT_SCALE := Vector2(0.4, 0.4)
const HOVER_SCALE   := Vector2(0.45, 0.45)
const BOARD_SCALE   := Vector2(0.35, 0.35)

var screen_size:           Vector2
var card_being_dragged              = null
var is_hovering_on_card:   bool     = false
var hand_manager:          Node     = null
var played_card_this_turn: bool     = false
var drag_offset:           Vector2  = Vector2.ZERO
var all_slots:             Array    = []

func _ready() -> void:
	screen_size  = get_viewport_rect().size
	hand_manager = $"../HandManager"
	var slots_container = get_node_or_null("../CardSlots")
	if slots_container:
		all_slots = slots_container.get_children()
	else:
		push_error("CardManager: CardSlots node not found!")
	var input_mgr = get_node_or_null("../InputManager")
	if input_mgr:
		if not input_mgr.left_mouse_button_released.is_connected(_on_release):
			input_mgr.connect("left_mouse_button_released", _on_release)
	else:
		push_error("CardManager: InputManager node not found!")

func _process(_delta: float) -> void:
	if card_being_dragged:
		var mp = get_global_mouse_position()
		card_being_dragged.global_position = Vector2(
			clamp(mp.x - drag_offset.x, 0, screen_size.x),
			clamp(mp.y - drag_offset.y, 0, screen_size.y)
		)
		_highlight_slots(card_being_dragged)

func start_drag(card) -> void:
	card_being_dragged = card
	card.set_card_state(RiftCard.CardState.DRAGGING)
	if card.get_parent() != self:
		var saved_global_pos = card.global_position
		if card.card_slot_card_is_in:
			card.card_slot_card_is_in.remove_card(card)
			card.card_slot_card_is_in = null
		else:
			card.get_parent().remove_child(card)
		add_child(card)
		card.global_position = saved_global_pos
		if hand_manager.cards_in_hand.has(card):
			hand_manager.cards_in_hand.erase(card)
			hand_manager._reposition_cards()
	drag_offset = get_global_mouse_position() - card.global_position
	card.scale   = DEFAULT_SCALE
	card.z_index = 10

func finish_drag() -> void:
	if not card_being_dragged:
		return

	var slot = _raycast_slot()

	if slot:
		var card = card_being_dragged
		card_being_dragged = null

		remove_child(card)
		card.z_index              = 100
		card.card_slot_card_is_in = slot
		card.get_node("Area2D/CollisionShape2D").disabled = true
		card.set_card_state(RiftCard.CardState.ON_BOARD)
		slot.add_card(card)
		is_hovering_on_card       = false
	else:
		var card = card_being_dragged
		card_being_dragged = null

		if card.get_parent() != hand_manager:
			card.get_parent().remove_child(card)
			hand_manager.add_child(card)

		if not hand_manager.cards_in_hand.has(card):
			hand_manager.cards_in_hand.append(card)

		card.set_card_state(RiftCard.CardState.IN_HAND)
		card.z_index = 1
		hand_manager._reposition_cards()
		hand_manager._tween_return(card)

	_clear_slot_highlights()
	drag_offset = Vector2.ZERO

func _highlight_slots(_card) -> void:
	for slot in all_slots:
		slot.highlight(true, true)

func _clear_slot_highlights() -> void:
	for slot in all_slots:
		slot.highlight(false)

func connect_card_signals(card) -> void:
	card.connect("hovered",     _on_hovered)
	card.connect("hovered_off", _on_hovered_off)

func _on_release() -> void:
	if card_being_dragged:
		finish_drag()

func _on_hovered(card) -> void:
	if not is_hovering_on_card:
		is_hovering_on_card = true
		_highlight(card, true)

func _on_hovered_off(card) -> void:
	if card_being_dragged:
		return
	if not card.card_slot_card_is_in:
		_highlight(card, false)
		var next = _raycast_card()
		if next:
			_highlight(next, true)
		else:
			is_hovering_on_card = false

func _highlight(card, on: bool) -> void:
	card.scale   = HOVER_SCALE  if on else DEFAULT_SCALE
	card.z_index = 2            if on else 1

func _raycast_slot():
	var p = PhysicsPointQueryParameters2D.new()
	p.position           = get_global_mouse_position()
	p.collide_with_areas = true
	p.collision_mask     = COLLISION_MASK_CARD_SLOT
	var result = get_world_2d().direct_space_state.intersect_point(p)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func _raycast_card():
	var p = PhysicsPointQueryParameters2D.new()
	p.position           = get_global_mouse_position()
	p.collide_with_areas = true
	p.collision_mask     = COLLISION_MASK_CARD
	var result = get_world_2d().direct_space_state.intersect_point(p)
	if result.size() == 0:
		return null
	var best = result[0].collider.get_parent()
	for i in range(1, result.size()):
		var c = result[i].collider.get_parent()
		if c.z_index > best.z_index:
			best = c
	return best
