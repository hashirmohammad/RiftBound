class_name HandManager
extends Node2D

const CARD_SCENE   := preload("res://Scenes/Card.tscn")
const DEAL_SPEED   := 0.35
const RETURN_SPEED := 0.15
const NORMAL_SCALE := Vector2(0.4, 0.4)
const CARD_SPACING := 160.0
const SCREEN_W     = 1920.0
const SCREEN_H     = 1080.0
const HAND_H       = 130.0

var cards_in_hand: Array = []


func render_hand(card_instances: Array) -> void:
	_clear_hand_visuals()

	for inst in card_instances:
		var card: RiftCard = CARD_SCENE.instantiate()
		card.scale = NORMAL_SCALE
		card.modulate = Color.WHITE
		add_child(card)

		card.setup_from_card_instance(inst)
		card.set_card_state(RiftCard.CardState.IN_HAND)

		cards_in_hand.append(card)

	_reposition_cards()

func _clear_hand_visuals() -> void:
	for card in cards_in_hand:
		if is_instance_valid(card):
			card.queue_free()
	cards_in_hand.clear()

func remove_card(card) -> void:
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		if card.get_parent() == self:
			remove_child(card)
		_reposition_cards()

func return_card(card) -> void:
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
		if card.get_parent() != self:
			card.get_parent().remove_child(card)
			add_child(card)

	card.set_card_state(RiftCard.CardState.IN_HAND)
	card.z_index = 1
	_reposition_cards()

func has_card(card) -> bool:
	return cards_in_hand.has(card)

func get_card_by_uid(uid: int) -> RiftCard:
	for card in cards_in_hand:
		if card.card_uid == uid:
			return card
	return null

func _get_card_target_position(index: int) -> Vector2:
	var count := cards_in_hand.size()
	var total_width := float(count - 1) * CARD_SPACING
	var start_x := -total_width / 2.0
	return Vector2(start_x + index * CARD_SPACING, 0.0)

func _reposition_all_except(skip_card) -> void:
	for i in range(cards_in_hand.size()):
		if cards_in_hand[i] == skip_card:
			continue
		cards_in_hand[i].position = _get_card_target_position(i)

func _reposition_cards() -> void:
	var count: int = cards_in_hand.size()
	if count == 0:
		return

	var total_width: float = float(count - 1) * float(CARD_SPACING)
	var start_x: float = -total_width / 2.0

	for i in range(count):
		cards_in_hand[i].position = Vector2(start_x + float(i) * float(CARD_SPACING), 0.0)

func _tween_deal(card) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "scale", NORMAL_SCALE, DEAL_SPEED).from(NORMAL_SCALE * 0.6)

func _tween_return_to(card, target: Vector2) -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "position", target, RETURN_SPEED)
	tween.tween_property(card, "scale", NORMAL_SCALE, RETURN_SPEED)

func _tween_return(card) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "scale", NORMAL_SCALE, RETURN_SPEED)
