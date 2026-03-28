class_name CardSlot
extends Node2D

const CARD_SPACING := 130.0

@export_enum("UNIT", "SPELL", "RUNE", "CHAMPION") var card_slot_type: int = 0

var cards: Array = []

var card_in_slot: bool:
	get: return cards.size() > 0

func _ready() -> void:
	if has_node("CardSlotImage"):
		$CardSlotImage.visible = false

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
	if count == 0:
		return

	var total_width := (count - 1) * CARD_SPACING
	var start_x := -total_width / 2.0

	for i in range(count):
		cards[i].position = Vector2(start_x + i * CARD_SPACING, 0.0)

func highlight(on: bool, valid: bool = true) -> void:
	pass
