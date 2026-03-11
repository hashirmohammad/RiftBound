extends Node2D

## Deck — Draw pile. Deals cards directly into HandManager.

const STARTING_HAND_SIZE := 4

var player_deck: Array[String] = []
var drawn_card_this_turn := false
var _hand_manager: HandManager = null

func _ready() -> void:
	_hand_manager = get_node_or_null("../HandManager")
	print("=== DECK DEBUG ===")
	print("HandManager found: ", _hand_manager)
	print("CardDatabase total cards: ", CardDatabase.get_all_cards().size())
	if _hand_manager == null:
		push_error("Deck: HandManager not found!")
		return
	var all_cards = CardDatabase.get_all_cards()
	for card in all_cards:
		if card.image_url != "":
			player_deck.append(card.card_id)
	player_deck.shuffle()
	print("Deck size after shuffle: ", player_deck.size())
	$RichTextLabel.text = str(player_deck.size())
	for i in range(STARTING_HAND_SIZE):
		await draw_card()
		drawn_card_this_turn = false
	drawn_card_this_turn = false

func draw_card() -> void:
	if drawn_card_this_turn or player_deck.is_empty():
		return
	drawn_card_this_turn = true
	var card_id: String = player_deck.pop_front()
	print("Drawing card: ", card_id)
	if player_deck.is_empty():
		$Area2D/CollisionShape2D.disabled = true
		$Sprite2D.visible                 = false
		$RichTextLabel.visible            = false
	$RichTextLabel.text = str(player_deck.size())
	var data: CardData = CardDatabase.get_card(card_id)
	if data == null:
		push_error("Deck: card_id '%s' not found in CardDatabase" % card_id)
		drawn_card_this_turn = false
		return
	print("Card data found: ", data.card_id)
	var new_card: RiftCard = await _hand_manager.deal_card(data)
	if new_card == null:
		push_error("Deck: deal_card() returned null for card_id '%s'" % card_id)
		drawn_card_this_turn = false
		return
	print("Card dealt successfully: ", card_id)
	#var anim: AnimationPlayer = new_card.get_node_or_null("AnimationPlayer")
	#if anim:
		#anim.play("card_flip")
