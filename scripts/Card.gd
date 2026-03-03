class_name RiftCard
extends Control

## Card — The visual node that represents a single playable card on screen.
##
## Inherits from Control so it can:
##   - Receive mouse input via _gui_input()
##   - Be positioned freely during drag
##   - Participate in Godot's UI layout system
##
## This node is purely visual and interactive — no game logic lives here.
## All card stat data lives in CardData (scripts/card/card_data.gd)
##
## Dependencies:
##   - CardData        (scripts/card/card_data.gd) — provides stat data
##   - HandManager     (Task 2) — manages card layout in hand
##   - BoardManager    (Task 4) — handles drop zone detection

## Tracks what the card is currently doing.
## Read and written by HandManager, BoardManager, and mouse input logic.
enum CardState {
	IN_HAND,    ## Sitting in the hand container
	DRAGGING,   ## Following the mouse cursor
	ON_BOARD,   ## Placed on a valid board tile
	RETURNING   ## Animating back to hand after invalid drop
}

var card_data: CardData = null
var current_state: CardState = CardState.IN_HAND

## Called by HandManager when dealing cards to the player.
## Stores the CardData reference and populates visuals.
## @param data — A CardData .tres resource from resources/cards/
func load_from_resource(data: CardData) -> void:
	if data == null:
		return

	card_data = data

	# TODO (Task 2): Once Card scene has Label and TextureRect child nodes,
	# populate them here. Example:
	#   $CardName.text = card_data.card_name
	#   $Cost.text = str(card_data.cost)
	#   $Power.text = str(card_data.power)
	#   $CardTexture.texture = card_data.texture

## Returns the current card state
func get_card_state() -> CardState:
	return current_state

## Sets the current card state
func set_card_state(state: CardState) -> void:
	current_state = state

## Entry point for all mouse interaction — fully implemented in Task 3
func _gui_input(event: InputEvent) -> void:
	pass # TODO (Task 3): detect clicks, hover, and releases

## Used in Task 3 to make the card follow the mouse while DRAGGING
func _process(delta: float) -> void:
	pass # TODO (Task 3): if DRAGGING, follow mouse position
