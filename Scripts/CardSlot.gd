class_name CardSlot
extends Node2D

const CARD_SPACING := 180.0
const CARD_W := 144.0
const CARD_H := 213.0

@export_enum("UNIT", "SPELL", "RUNE", "CHAMPION") var card_slot_type: int = 0

var cards: Array = []
var _glow_on: bool = false
var _glow_color: Color = Color.GREEN
var _glow_card_count: int = 0

var card_in_slot: bool:
	get: return cards.size() > 0

func _ready() -> void:
	if has_node("CardSlotImage"):
		$CardSlotImage.visible = false

func _process(_delta: float) -> void:
	if _glow_on:
		queue_redraw()

func _draw() -> void:
	if not _glow_on:
		return
	var size := _get_collision_size()
	var rect := Rect2(-size / 2.0, size)
	draw_rect(rect, _glow_color, false, 4.0)
	draw_rect(rect, Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.15), true)

func _get_collision_size() -> Vector2:
	var area = get_node_or_null("Area2D")
	if area:
		var s = area.get_node_or_null("CollisionShape2D")
		if s and s.shape is RectangleShape2D:
			return s.shape.size
	return Vector2(CARD_W, CARD_H)

func add_card(card: RiftCard) -> void:
	if card in cards:
		return
	cards.append(card)
	add_child(card)
	_reposition_cards()

	if has_node("CardSlotImage"):
		$CardSlotImage.visible = false

func remove_card(card: RiftCard) -> void:
	if not card in cards:
		return
	cards.erase(card)
	remove_child(card)
	_reposition_cards()

	if has_node("CardSlotImage"):
		$CardSlotImage.visible = false

func _reposition_cards() -> void:
	var count := cards.size()

	var total_width := CARD_W if count <= 1 else (count - 1) * CARD_SPACING + CARD_W
	var start_x := -total_width / 2.0 + CARD_W / 2.0

	for i in range(count):
		cards[i].position = Vector2(start_x + i * CARD_SPACING, 0.0)

func _update_collision(width: float) -> void:
	var area = get_node_or_null("Area2D")
	if area == null:
		return
	var shape_node = area.get_node_or_null("CollisionShape2D")
	if shape_node == null:
		return
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		return
	rect.size = Vector2(width, CARD_H)
	queue_redraw()

func clear_cards() -> void:
	for card in cards:
		if is_instance_valid(card):
			card.queue_free()
	cards.clear()

func highlight(on: bool, valid: bool = true, card_count: int = -1) -> void:
	_glow_on = on
	_glow_color = Color(0, 1, 0, 0.9) if valid else Color(1, 0, 0, 0.9)
	_glow_card_count = card_count if card_count >= 0 else cards.size()
	queue_redraw()
