class_name HandManager
extends Node2D

const CARD_SCENE   := preload("res://Scenes/Card.tscn")
const DEAL_SPEED   := 0.35
const RETURN_SPEED := 0.15
const NORMAL_SCALE := Vector2(0.4, 0.4)
const CARD_SPACING := 160
const SCREEN_W     = 1920.0
const SCREEN_H     = 1080.0
const HAND_H       = 130.0
const DIVIDER_H    = 4.0
const ARENA_H      = 200.0

var cards_in_hand: Array = []

func _ready() -> void:
	global_position = Vector2(SCREEN_W / 2.0, SCREEN_H - HAND_H / 2.0)

func deal_card(data: CardData) -> RiftCard:
	var card: RiftCard = CARD_SCENE.instantiate()
	card.scale    = NORMAL_SCALE
	card.modulate = Color.WHITE
	add_child(card)
	card.load_from_resource(data)
	cards_in_hand.append(card)
	_reposition_cards()
	_tween_deal(card)
	print("Card position: ", card.global_position)
	print("Card visible: ", card.visible)
	print("Card modulate: ", card.modulate)
	print("Card scale: ", card.scale)
	print("HandManager global_position: ", global_position)
	return card

func remove_card(card) -> void:
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		remove_child(card)
		_reposition_cards()

func return_card(card) -> void:
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
		add_child(card)
	card.set_card_state(RiftCard.CardState.IN_HAND)
	card.z_index = 1
	_reposition_cards()
	_tween_return(card)

func has_card(card) -> bool:
	return cards_in_hand.has(card)

func _reposition_cards() -> void:
	var count = cards_in_hand.size()
	if count == 0:
		return
	var total_width = (count - 1) * CARD_SPACING
	var start_x     = -total_width / 2.0
	for i in range(count):
		cards_in_hand[i].position = Vector2(start_x + i * CARD_SPACING, 40)

func _tween_deal(card) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Animate scale only — modulate is already WHITE, no invisible flash
	tween.tween_property(card, "scale", NORMAL_SCALE, DEAL_SPEED).from(NORMAL_SCALE * 0.6)

func _tween_return(card) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card, "scale", NORMAL_SCALE, RETURN_SPEED)
