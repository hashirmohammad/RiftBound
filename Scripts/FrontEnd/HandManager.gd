extends Node2D

const CARD_SCENE = preload("res://Scenes/Card.tscn")

var _cards: Array[RiftCard] = []
var _face_down: bool = false

func render_hand(hand_cards: Array, face_down: bool = false) -> void:
	_face_down = face_down
	_clear_cards()

	var count := hand_cards.size()
	if count == 0:
		return

	var spacing := 140.0
	var start_x := -((count - 1) * spacing) / 2.0

	for i in range(count):
		var card_instance = hand_cards[i]
		var card: RiftCard = CARD_SCENE.instantiate()
		add_child(card)

		card.setup_from_card_instance(card_instance)
		if _face_down:
			card.is_hidden = true
			card.modulate  = Color(0.0, 0.0, 0.0, 1.0)

		card.position = Vector2(start_x + i * spacing, 0)
		card.scale    = Vector2(0.6, 0.6)
		card.z_index  = i
		card.set_card_state(RiftCard.CardState.IN_HAND)

		_cards.append(card)

func has_card(card: RiftCard) -> bool:
	return card in _cards

func return_card(card: RiftCard) -> void:
	if card == null:
		return

	if card.get_parent() != self:
		if card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)

	if not (card in _cards):
		_cards.append(card)

	_relayout()

func remove_card(card: RiftCard) -> void:
	if card in _cards:
		_cards.erase(card)
	_relayout()

func _relayout() -> void:
	var count := _cards.size()
	if count == 0:
		return

	var spacing := 140.0
	var start_x := -((count - 1) * spacing) / 2.0

	for i in range(count):
		var card = _cards[i]
		if is_instance_valid(card):
			card.position = Vector2(start_x + i * spacing, 0)
			card.scale    = Vector2(0.6, 0.6)
			card.z_index  = i
			card.set_card_state(RiftCard.CardState.IN_HAND)
			if _face_down:
				card.is_hidden = true
				card.modulate  = Color(0.0, 0.0, 0.0, 1.0)

func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
