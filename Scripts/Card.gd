class_name RiftCard
extends Node2D

signal hovered(card: RiftCard)
signal hovered_off(card: RiftCard)
signal texture_loaded

@onready var card_back_image = $CardBackImage
@onready var card_image = $CardImage
@onready var attack_label = $Attack
@onready var health_label = $Health
@onready var name_label = $NameLabel
@onready var cost_label = $CostLabel

enum CardState {
	IN_HAND,
	DRAGGING,
	ON_BOARD,
	RETURNING
}

const CARD_WIDTH     = 180
const CARD_HEIGHT    = 266
const CACHE_DIR      = "user://card_cache/"
const NORMAL_SCALE   = Vector2(0.4, 0.4)
const ENLARGED_SCALE = Vector2(1.5, 1.5)

var card_uid: int = -1
var card_data: CardData = null
var current_state: CardState = CardState.IN_HAND
var starting_position: Vector2
var card_slot_card_is_in = null
var card_type: int = 0
var _pending_image_url: String = ""
var _pending_card_id: String = ""
var _is_enlarged: bool = false
var _cached_texture: ImageTexture = null
var _original_scale: Vector2 = Vector2.ONE
var _original_position: Vector2 = Vector2.ZERO
var _is_tapped: bool = false
var _last_click_time: float = 0.0
const DOUBLE_CLICK_TIME := 0.35

func _draw() -> void:
	draw_rect(Rect2(Vector2(-90, -133), Vector2(180, 266)), Color(0.8, 0.2, 0.2, 0.9), true)
	draw_rect(Rect2(Vector2(-90, -133), Vector2(180, 266)), Color(1, 1, 1, 1), false, 3.0)
	
func setup_from_instance(instance: CardInstance) -> void:
	if instance == null:
		push_error("RiftCard.setup_from_instance: instance is null")
		return

	card_uid = instance.uid
	card_data = instance.data

	update_visuals()
	queue_redraw()

func set_card_state(new_state: CardState) -> void:
	current_state = new_state

func update_visuals() -> void:
	if card_data == null:
		push_error("RiftCard.update_visuals: card_data is null")
		return

	name_label.text = str(card_data.card_name)
	cost_label.text = str(card_data.cost)
	attack_label.text = str(card_data.might)
	health_label.text = str(card_data.health)

	# Prefer preloaded texture from CardData if available
	if card_data.texture != null:
		if "texture" in card_image:
			card_image.texture = card_data.texture
