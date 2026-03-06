extends Node2D
## Deck — Draw pile. Deals cards directly into HandManager.
const STARTING_HAND_SIZE := 4

var player_deck: Array[String] = [
	"OGN-001/298", "OGN-002/298", "OGN-003/298",
	"OGN-001/298", "OGN-001/298", "OGN-001/298",
	"OGN-001/298", "OGN-001/298",
]

var drawn_card_this_turn := false
var _hand_manager: HandManager = null

func _ready() -> void:
	_hand_manager = get_node_or_null("../HandManager")
	print("=== DECK DEBUG ===")
	print("HandManager found: ", _hand_manager)
	print("CardDatabase total cards: ", CardDatabase.get_all_cards().size())
	var test = CardDatabase.get_card("OGN-001/298")
	print("Test card lookup 'OGN-001/298': ", test)
	if _hand_manager == null:
		push_error("Deck: HandManager not found!")
		return
	player_deck.shuffle()
	$RichTextLabel.text = str(player_deck.size())
	for i in range(STARTING_HAND_SIZE):
		draw_card()
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
	var new_card: RiftCard = _hand_manager.deal_card(data)
	if new_card == null:
		push_error("Deck: deal_card() returned null for card_id '%s'" % card_id)
		drawn_card_this_turn = false
		return
	print("Card dealt successfully: ", card_id)
	var anim: AnimationPlayer = new_card.get_node_or_null("AnimationPlayer")
	if anim:
		anim.play("card_flip")
