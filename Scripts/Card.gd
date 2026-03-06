class_name RiftCard
extends Node2D
## RiftCard — Visual node representing a single playable card on screen.
##
## Drag logic  → CardManager.gd
## Hand layout → PlayerHand.gd  (legacy tween system, still in use by Deck)
## Card data   → CardData.gd
signal hovered(card: RiftCard)
signal hovered_off(card: RiftCard)
enum CardState {
	IN_HAND,
	DRAGGING,
	ON_BOARD,
	RETURNING
}
var card_data: CardData = null
var current_state: CardState = CardState.IN_HAND
var starting_position: Vector2
var card_slot_card_is_in = null
var card_type: int = 0  ## 0=UNIT, 1=SPELL, 2=RUNE, 3=CHAMPION

func _ready() -> void:
	var parent = get_parent()
	if parent and parent.has_method("connect_card_signals"):
		parent.connect_card_signals(self)

func _process(_delta: float) -> void:
	pass

func load_from_resource(data: CardData) -> void:
	if data == null:
		return
	card_data = data
	card_type = data.type

	var attack_label = get_node_or_null("Attack")
	var health_label = get_node_or_null("Health")

	if attack_label:
		attack_label.text = str(card_data.might)
	if health_label:
		health_label.text = str(card_data.health)

func get_card_state() -> CardState:
	return current_state

func set_card_state(state: CardState) -> void:
	current_state = state

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
