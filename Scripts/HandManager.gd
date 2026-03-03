class_name HandManager
extends HBoxContainer
## HandManager — Manages the player's hand of cards at the bottom of the screen.
##
## Inherits from HBoxContainer so cards are automatically laid out
## horizontally and spacing adjusts when cards are added or removed.
##
## Responsibilities:
##   - Dealing cards into the hand via deal_card()
##   - Removing cards from the hand when played
##   - Returning cards back to hand when a drag fails via return_card()
##
## Dependencies:
##   - RiftCard   (scripts/card/card.gd) — the card node being managed
##   - CardData   (scripts/card/card_data.gd) — the data loaded into each card

## All cards currently in the player's hand
var cards_in_hand: Array[RiftCard] = []

## Preload the card scene so we can instantiate new cards
const CARD_SCENE = preload("res://Scenes/Card.tscn")

## Deals a new card into the hand from a CardData resource.
## Called by the game manager when drawing a card.
## @param data — A CardData .tres resource from resources/cards/
func deal_card(data: CardData) -> void:
	var card = CARD_SCENE.instantiate()
	card.load_from_resource(data)
	cards_in_hand.append(card)
	add_child(card)

## Removes a card from the hand when it is successfully played to the board.
## Called by Task 4 (BoardManager) on successful drop.
## @param card — The RiftCard node to remove
func remove_card(card: RiftCard) -> void:
	if cards_in_hand.has(card):
		cards_in_hand.erase(card)
		card.queue_free()

## Returns a card back to the hand after a failed drag.
## Called by Task 3 (mouse input) when card is dropped on invalid area.
## @param card — The RiftCard node to return
func return_card(card: RiftCard) -> void:
	if not cards_in_hand.has(card):
		cards_in_hand.append(card)
	card.set_card_state(RiftCard.CardState.IN_HAND)
	# TODO (Task 5): Add a Tween here to smoothly slide the card back into position
