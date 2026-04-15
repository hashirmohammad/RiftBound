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
const HOVER_SCALE    := Vector2(0.65, 0.65)
const NORMAL_SCALE   := Vector2(0.4, 0.4)

var card_uid:      int      = -1
var card_data:     CardData = null
var current_state: CardState = CardState.IN_HAND
var _is_hovered: bool = false
var _original_scale: Vector2 = Vector2.ONE
var _original_z_index: int = 0
var _original_rotation: float = 0.0
var _hover_tween: Tween = null
var _original_position: Vector2 = Vector2.ZERO
var _original_global_position: Vector2 = Vector2.ZERO

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

	var tex = ImageTexture.create_from_image(image)
	if card_data != null:
		card_data.texture = tex
	_set_card_texture(tex)

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

func _on_mouse_entered() -> void:
	if current_state == CardState.DRAGGING:
		return
	if card_data != null and card_data.type == CardData.CardType.RUNE:
		return
	_is_hovered = true
	_original_scale    = scale
	_original_z_index  = z_index
	_original_rotation = rotation_degrees
	_original_global_position = global_position

	if _hover_tween:
		_hover_tween.kill()

	# Scale up by 2.7x from whatever the current scale is
	var target_scale = _original_scale * 2.7

	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_hover_tween.tween_property(self, "scale", target_scale, 0.15)
	_hover_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.15)
	z_index = 50

	# Clamp position only for hand cards so they stay within the viewport at full scale
	if current_state == CardState.IN_HAND:
		var viewport_size = get_viewport_rect().size
		var half_w = (CARD_WIDTH  * target_scale.x) / 2.0
		var half_h = (CARD_HEIGHT * target_scale.y) / 2.0
		var clamped := global_position
		clamped.x = clamp(clamped.x, half_w, viewport_size.x - half_w)
		clamped.y = clamp(clamped.y, half_h, viewport_size.y - half_h)
		if clamped != global_position:
			_hover_tween.parallel().tween_property(self, "global_position", clamped, 0.15)

func _on_mouse_exited() -> void:
	if not _is_hovered:
		return
	_is_hovered = false

	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_hover_tween.tween_property(self, "scale", _original_scale, 0.15)
	_hover_tween.parallel().tween_property(self, "rotation_degrees", _original_rotation, 0.15)
	z_index = _original_z_index

	# Restore original position for hand cards that were nudged by clamping
	if current_state == CardState.IN_HAND:
		_hover_tween.parallel().tween_property(self, "global_position", _original_global_position, 0.15)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos = to_local(get_global_mouse_position())
		var half_w = (CARD_WIDTH * scale.x) / 2.0
		var half_h = (CARD_HEIGHT * scale.y) / 2.0
		var is_over = abs(local_pos.x) <= half_w and abs(local_pos.y) <= half_h

		if is_over and not _is_hovered:
			_on_mouse_entered()
		elif not is_over and _is_hovered:
			_on_mouse_exited()
