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

static var _hovered_card: RiftCard = null
# Blocks hover on all cards while any one card is being dragged.
static var _drag_active:  bool     = false

var card_uid:      int       = -1
var card_data:     CardData  = null
var current_state: CardState = CardState.IN_HAND
var is_hidden:     bool      = false
var _is_hovered:   bool      = false
var _hover_tween_active: bool = false
var _base_scale:         Vector2 = Vector2(0.55, 0.55)
var _hover_target_scale: Vector2 = Vector2.ZERO
var _original_z_index:   int     = 0
var _original_rotation:  float   = 0.0
var _original_position:  Vector2 = Vector2.ZERO
var _anchor_global:      Vector2 = Vector2.ZERO  # stable world-space hit-test origin, never touched by tweens
var _hover_tween:        Tween   = null

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
	if new_state == CardState.DRAGGING and _is_hovered:
		_exit_hover()
		if _hovered_card == self:
			_hovered_card = null
		scale = _base_scale

	current_state      = new_state
	_original_position = position
	_anchor_global     = global_position  # snapshot stable anchor whenever state changes
	_original_rotation = rotation_degrees  # resting rotation; used by hit-test and exit-hover tween

	if not _is_hovered:
		_base_scale = scale

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

# ─── Hover — hit-test uses _anchor_global only, never animated global_position ─

func _process(_delta: float) -> void:
	if current_state == CardState.DRAGGING:
		return
	if _drag_active:
		return
	if is_hidden:
		return
	if card_data != null and card_data.type == CardData.CardType.RUNE:
		return

	var mouse_global = get_global_mouse_position()
	# _anchor_global is set only in set_card_state()/refresh_slot_state() — tweens never touch it.
	var diff = mouse_global - _anchor_global
	# Use _original_rotation (resting state) so the hit-test bounding box stays stable
	# during the hover tween — prevents the feedback-loop flicker at card edges.
	var rot_rad  = deg_to_rad(_original_rotation)
	var cos_r    = cos(-rot_rad)
	var sin_r    = sin(-rot_rad)
	var local_diff = Vector2(diff.x * cos_r - diff.y * sin_r, diff.x * sin_r + diff.y * cos_r)
	var half_w = (CARD_WIDTH  * _base_scale.x) / 2.0
	var half_h = (CARD_HEIGHT * _base_scale.y) / 2.0
	var is_over = abs(local_diff.x) <= half_w and abs(local_diff.y) <= half_h

	if is_over and not _is_hovered:
		if _hovered_card == null or _hovered_card == self:
			_hovered_card = self
			_enter_hover()
		elif z_index > _hovered_card.z_index:
			# Steal hover from a lower card
			_hovered_card._exit_hover()
			_hovered_card = self
			_enter_hover()
	elif not is_over and _is_hovered:
		if _hovered_card == self:
			_hovered_card = null
		_exit_hover()

func _enter_hover() -> void:
	_is_hovered         = true
	_hover_tween_active = true
	_original_z_index   = z_index
	# _original_rotation is set in set_card_state/refresh_slot_state so it always
	# holds the true resting rotation, never a mid-tween value.

	if _hover_tween:
		_hover_tween.kill()

	_hover_target_scale = _base_scale * 3

	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tween.tween_property(self, "scale", _hover_target_scale, 0.15)
	_hover_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.15)
	z_index = 50

	var viewport_size = get_viewport_rect().size
	var half_w = (CARD_WIDTH  * _hover_target_scale.x) / 2.0
	var half_h = (CARD_HEIGHT * _hover_target_scale.y) / 2.0
	var gpos   = _anchor_global  # clamp relative to stable anchor, not animated position
	var needs_clamp = (
		gpos.x - half_w < 0 or
		gpos.x + half_w > viewport_size.x or
		gpos.y - half_h < 0 or
		gpos.y + half_h > viewport_size.y
	)
	if needs_clamp:
		var clamped_global: Vector2 = gpos
		clamped_global.x = clamp(gpos.x, half_w, viewport_size.x - half_w)
		clamped_global.y = clamp(gpos.y, half_h, viewport_size.y - half_h)
		# Convert global -> local for Control parents that lack to_local()
		var clamped_local: Vector2 = clamped_global - get_parent().global_position
		_hover_tween.parallel().tween_property(self, "position", clamped_local, 0.15)

func _exit_hover() -> void:
	_is_hovered         = false
	_hover_tween_active = false

	if _hover_tween:
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.15)
	_hover_tween.parallel().tween_property(self, "rotation_degrees", _original_rotation, 0.15)
	_hover_tween.parallel().tween_property(self, "position", _original_position, 0.15)
	z_index = _original_z_index

# Called after _reposition_cards moves a card so the hit-test anchor,
# base scale, and resting rotation stay in sync with the card's actual position.
func refresh_slot_state() -> void:
	if _is_hovered:
		return
	_original_position = position
	_anchor_global     = global_position
	_base_scale        = scale
	_original_rotation = rotation_degrees

# Keep Area2D signal stubs to avoid errors from scene connections
func _on_area_2d_mouse_entered() -> void:
	pass

func _on_area_2d_mouse_exited() -> void:
	pass
