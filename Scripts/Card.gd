class_name RiftCard
extends Node2D

signal hovered(card: RiftCard)
signal hovered_off(card: RiftCard)
signal texture_loaded

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

var card_data:          CardData     = null
var current_state:      CardState    = CardState.IN_HAND
var starting_position:  Vector2
var card_slot_card_is_in              = null
var card_type:          int          = 0
var _pending_image_url: String       = ""
var _pending_card_id:   String       = ""
var _is_enlarged:       bool         = false
var _cached_texture:    ImageTexture = null
var _original_scale:    Vector2      = Vector2.ONE
var _original_position: Vector2      = Vector2.ZERO
var _is_tapped:         bool         = false
var _last_click_time:   float        = 0.0
const DOUBLE_CLICK_TIME := 0.35

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	modulate = Color.WHITE

	var parent = get_parent()
	if parent and parent.has_method("connect_card_signals"):
		parent.connect_card_signals(self)

	if _cached_texture != null:
		call_deferred("_reapply_cached_texture")
	elif _pending_image_url != "" and _pending_card_id != "":
		call_deferred("_load_or_download_image", _pending_card_id, _pending_image_url)

func _reapply_cached_texture() -> void:
	var card_image = get_node_or_null("CardImage")
	if card_image:
		card_image.texture = _cached_texture
		card_image.visible = true
	var card_back = get_node_or_null("CardBackImage")
	if card_back:
		card_back.visible = false
	emit_signal("texture_loaded")

func _process(_delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if current_state == CardState.DRAGGING or current_state == CardState.RETURNING:
		return
	if event is InputEventMouseButton and event.pressed:
		var local_pos = to_local(get_global_mouse_position())
		var half_w = (CARD_WIDTH * scale.x) / 2.0
		var half_h = (CARD_HEIGHT * scale.y) / 2.0
		if abs(local_pos.x) <= half_w and abs(local_pos.y) <= half_h:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_toggle_enlarge()
			elif event.button_index == MOUSE_BUTTON_LEFT and current_state == CardState.ON_BOARD:
				var now := Time.get_ticks_msec() / 1000.0
				if now - _last_click_time < DOUBLE_CLICK_TIME:
					_toggle_tap()
					_last_click_time = 0.0
				else:
					_last_click_time = now

func _toggle_tap() -> void:
	_is_tapped = !_is_tapped
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation", deg_to_rad(90.0) if _is_tapped else 0.0, 0.2)

func _toggle_enlarge() -> void:
	_is_enlarged = !_is_enlarged
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _is_enlarged:
		_original_scale    = scale
		_original_position = global_position
		var half_w = CARD_WIDTH  * ENLARGED_SCALE.x / 2.0
		var half_h = CARD_HEIGHT * ENLARGED_SCALE.y / 2.0
		var screen = get_viewport_rect().size
		var clamped = Vector2(
			clamp(global_position.x, half_w, screen.x - half_w),
			clamp(global_position.y, half_h, screen.y - half_h)
		)
	# Use a larger scale for board cards to compensate for slot's 0.55 scale
		var target_scale = ENLARGED_SCALE if current_state != CardState.ON_BOARD else ENLARGED_SCALE / 0.55
		tween.tween_property(self, "global_position", clamped, 0.2)
		tween.parallel().tween_property(self, "scale", target_scale, 0.2)
		tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.1)
		z_index = 200
	else:
		# Bug fix 2: restore to whatever scale the card had before enlarging,
		# not the hardcoded NORMAL_SCALE (which was shrinking board cards to 0.4)
		tween.tween_property(self, "global_position", _original_position, 0.2)
		tween.parallel().tween_property(self, "scale", _original_scale, 0.2)
		# Bug fix 1: restore inherited tint from parent slot
		tween.parallel().tween_property(self, "self_modulate", Color.WHITE, 0.1)
		z_index = 100 if current_state == CardState.ON_BOARD else 1
		
func set_card_state(new_state: CardState) -> void:
	current_state = new_state
	if new_state != CardState.ON_BOARD and _is_enlarged:
		_is_enlarged = false
		scale = _original_scale  # was NORMAL_SCALE
		global_position = _original_position

func load_from_resource(data: CardData) -> void:
	if data == null:
		return
	card_data = data
	card_type  = data.type

	var attack_label = get_node_or_null("Attack")
	var health_label = get_node_or_null("Health")
	if attack_label:
		attack_label.visible = false
	if health_label:
		health_label.visible = false

	var card_back = get_node_or_null("CardBackImage")
	if card_back:
		card_back.visible = true

	var card_image = get_node_or_null("CardImage")
	if card_image:
		card_image.visible = false

	if data.image_url != "":
		_pending_image_url = data.image_url
		_pending_card_id   = data.card_id
		if is_inside_tree():
			_load_or_download_image(data.card_id, data.image_url)

func _get_cache_path(card_id: String) -> String:
	var safe_id = card_id \
		.replace("/",  "_").replace(":",  "_").replace("*", "_") \
		.replace("?",  "_").replace("<",  "_").replace(">", "_") \
		.replace("|",  "_").replace("\\", "_")
	return CACHE_DIR + safe_id + ".png"

func _load_or_download_image(card_id: String, url: String) -> void:
	var cache_path = _get_cache_path(card_id)
	if FileAccess.file_exists(cache_path):
		var image = Image.new()
		if image.load(cache_path) == OK:
			_apply_texture(image)
			return
	_download_image(url)

func _download_image(url: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_image_downloaded)
	http.request(url)

func _on_image_downloaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("Card: failed to download image, code: %d" % response_code)
		return
	var image = Image.new()
	var err = image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		push_error("Card: failed to decode image for %s" % card_data.card_id)
		return
	image.save_png(_get_cache_path(card_data.card_id))
	_apply_texture(image)

func _apply_texture(image: Image) -> void:
	image.resize(CARD_WIDTH, CARD_HEIGHT, Image.INTERPOLATE_LANCZOS)
	var tex = ImageTexture.create_from_image(image)
	_cached_texture = tex

	var card_image = get_node_or_null("CardImage")
	if card_image:
		card_image.texture = tex
		card_image.visible = true

	var card_back = get_node_or_null("CardBackImage")
	if card_back:
		card_back.visible = false

	emit_signal("texture_loaded")

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
