extends Node2D

const COLLISION_MASK_CARD := 1
const COLLISION_MASK_CARD_SLOT := 2
const DEFAULT_SCALE := Vector2(0.4, 0.4)
const HOVER_SCALE := Vector2(0.45, 0.45)
const BOARD_SCALE := Vector2(0.35, 0.35)

var game_controller: Node = null
var screen_size: Vector2
var is_hovering_on_card: bool = false
var hand_manager: Node = null
var played_card_this_turn: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var all_slots: Array = []
var dragged_card: RiftCard = null
var board_reference: Node = null

func _ready() -> void:
	screen_size = get_viewport_rect().size
	hand_manager = $"../HandManager"
	game_controller = $"../GameController"
	board_reference = $"../Board"

	if game_controller == null:
		push_error("CardManager: GameController node not found!")

	var slots_container = get_node_or_null("../CardSlots")
	if slots_container:
		all_slots = slots_container.get_children()
	else:
		push_error("CardManager: CardSlots node not found!")

func _process(_delta: float) -> void:
	if dragged_card:
		var mp = get_global_mouse_position()
		dragged_card.global_position = Vector2(
			clamp(mp.x - drag_offset.x, 0, screen_size.x),
			clamp(mp.y - drag_offset.y, 0, screen_size.y)
		)
		_highlight_slots(dragged_card)

func start_drag(card: RiftCard) -> void:
	dragged_card = card
	drag_offset = get_global_mouse_position() - card.global_position
	card.set_card_state(RiftCard.CardState.DRAGGING)
	card.z_index = 100

func get_dragged_card() -> RiftCard:
	return dragged_card

func return_dragged_card_to_hand() -> void:
	if dragged_card == null:
		return

	var card = dragged_card
	dragged_card = null

	_clear_slot_highlights()
	drag_offset = Vector2.ZERO
	hand_manager.return_card(card)

func clear_dragged_card() -> void:
	dragged_card = null
	_clear_slot_highlights()
	drag_offset = Vector2.ZERO

func _highlight_slots(_card) -> void:
	if board_reference == null:
		return

	var slots = board_reference._player_slot_nodes
	var player = game_controller.state.get_active_player()

	for i in range(slots.size()):
		var slot = slots[i]
		var count: int = player.board_slots[i].size() if i < player.board_slots.size() else 0
		slot.highlight(true, true, count)

func _clear_slot_highlights() -> void:
	if board_reference == null:
		return

	var slots = board_reference._player_slot_nodes

	for slot in slots:
		slot.highlight(false)

func connect_card_signals(card) -> void:
	card.connect("hovered", _on_hovered)
	card.connect("hovered_off", _on_hovered_off)

func _on_hovered(card) -> void:
	if not is_hovering_on_card:
		is_hovering_on_card = true
		_highlight(card, true)

func _on_hovered_off(card) -> void:
	if dragged_card:
		return
	if not card.card_slot_card_is_in:
		_highlight(card, false)
		var next = _raycast_card()
		if next:
			_highlight(next, true)
		else:
			is_hovering_on_card = false

func _highlight(card, on: bool) -> void:
	card.scale = HOVER_SCALE if on else DEFAULT_SCALE
	card.z_index = 2 if on else 1

func _raycast_slot():
	var p = PhysicsPointQueryParameters2D.new()
	p.position = get_global_mouse_position()
	p.collide_with_areas = true
	p.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = get_world_2d().direct_space_state.intersect_point(p)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func _raycast_card():
	var p = PhysicsPointQueryParameters2D.new()
	p.position = get_global_mouse_position()
	p.collide_with_areas = true
	p.collision_mask = COLLISION_MASK_CARD
	var result = get_world_2d().direct_space_state.intersect_point(p)
	if result.size() == 0:
		return null
	var best = result[0].collider.get_parent()
	for i in range(1, result.size()):
		var c = result[i].collider.get_parent()
		if c.z_index > best.z_index:
			best = c
	return best
