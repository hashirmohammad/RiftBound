class_name RiftCard
extends Node2D

## Card — The visual node that represents a single playable card on screen.
##
## Extends Node2D to work with Kajbaso's Area2D collision-based
## hover and drag detection system via CardManager.
##
## Card stat data lives in CardData (Scripts/CardData.gd)
## Drag logic lives in CardManager (Scripts/CardManager.gd)
## Hand layout lives in PlayerHand (Scripts/PlayerHand.gd)

signal hovered(card: RiftCard)
signal hovered_off(card: RiftCard)

## Tracks what the card is currently doing.
## Read and written by CardManager and PlayerHand.
enum CardState {
	IN_HAND,    ## Sitting in the hand
	DRAGGING,   ## Following the mouse cursor
	ON_BOARD,   ## Placed on a valid board slot
	RETURNING   ## Animating back to hand after invalid drop
}

var card_data: CardData = null
var current_state: CardState = CardState.IN_HAND
var starting_position: Vector2
var card_slot_card_is_in = null

func _ready() -> void:
	# CardManager connects hover signals on all cards
	get_parent().connect_card_signals(self)

func _process(delta: float) -> void:
	pass

## Called by PlayerHand or Deck when dealing a card.
## Populates visuals from CardData loaded via CardDatabase.
func load_from_resource(data: CardData) -> void:
	if data == null:
		return
	card_data = data
	get_node("Attack").text = str(card_data.might)
	get_node("Health").text = str(card_data.cost)
	# TODO (T6S-24): load card image from card_data.image_url

func get_card_state() -> CardState:
	return current_state

func set_card_state(state: CardState) -> void:
	current_state = state

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
