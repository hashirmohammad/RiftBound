class_name RiftCard
extends Node2D

@onready var card_image:    Sprite2D    = $CardImage
@onready var http_request:  HTTPRequest = $HTTPRequest

enum CardState {
	IN_HAND,
	DRAGGING,
	ON_BOARD,
}

const CARD_WIDTH  := 180.0
const CARD_HEIGHT := 266.0

var card_uid:      int      = -1
var card_data:     CardData = null
var current_state: CardState = CardState.IN_HAND

func _ready() -> void:
	if http_request == null:
		push_error("Card.gd: HTTPRequest node missing.")
	else:
		if not http_request.request_completed.is_connected(_on_image_request_completed):
			http_request.request_completed.connect(_on_image_request_completed)

	if card_image != null:
		card_image.visible = true
		card_image.z_index = 10

func setup_from_card_instance(instance: CardInstance) -> void:
	if instance == null:
		push_error("RiftCard.setup_from_instance: instance is null")
		return
	card_uid  = instance.uid
	card_data = instance.data
	update_visuals()

func setup_from_battlefield_instance(instance: BattlefieldInstance) -> void:
	if instance == null:
		push_error("RiftCard.setup_from_instance: instance is null")
		return
	card_uid  = instance.uid
	card_data = instance.battlefield
	update_visuals()

func set_card_state(new_state: CardState) -> void:
	current_state = new_state

func update_visuals() -> void:
	if card_data == null:
		push_error("RiftCard.update_visuals: card_data is null")
		return

	if card_data.texture != null:
		_set_card_texture(card_data.texture)
		return

	if card_data.image_url != "":
		load_card_image_from_url(card_data.image_url)
		return

	push_error("RiftCard.update_visuals: no texture or image_url for card_uid %s" % card_uid)

func load_card_image_from_url(url: String) -> void:
	if http_request == null:
		push_error("Card.gd: HTTPRequest node not found.")
		return
	var err = http_request.request(url)
	if err != OK:
		push_error("Failed to request image URL: %s" % url)

func _on_image_request_completed(result, response_code, headers, body) -> void:
	if response_code != 200:
		push_error("Image request failed: %s" % response_code)
		return

	var image := Image.new()
	var err    = image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		push_error("Failed to decode image")
		return

	_set_card_texture(ImageTexture.create_from_image(image))

func _set_card_texture(tex: Texture2D) -> void:
	if card_image == null:
		push_error("CardImage node missing")
		return

	card_image.texture  = tex
	card_image.visible  = true
	card_image.centered = true
	card_image.position = Vector2.ZERO
	card_image.z_index  = 10

	var tex_size: Vector2 = tex.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		push_error("Invalid texture size")
		return

	var scale_factor: float = min(CARD_WIDTH / tex_size.x, CARD_HEIGHT / tex_size.y)
	card_image.scale = Vector2(scale_factor, scale_factor)
