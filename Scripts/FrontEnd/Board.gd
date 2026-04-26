@tool
extends Control

var game_controller: Node

const SCREEN_W     = 1920.0
const SCREEN_H     = 1080.0
const COLOR_BG     = Color("#0d1b35")
const COLOR_BORDER = Color(0.83, 0.68, 0.21, 0.95)
const COLOR_DIV    = Color(1, 1, 1, 0.20)
const COLOR_HAND   = Color(1, 1, 1, 0.05)
const BORDER_W     = 2
const GAP          = 6
const FONT_SIZE    = 11
const MANA_X       = 8
const MANA_SIZE    = 38
const MANA_COL_W   = 52
const HAND_H       = 180
const DIVIDER_H    = 4
const ARENA_H      = 100

# Gold fill for scored points
const COLOR_POINT_SCORED   = Color(0.83, 0.68, 0.21, 0.95)
# Dim fill for unscored points
const COLOR_POINT_UNSCORED = Color(0.08, 0.14, 0.26, 1.0)

const CARD_SLOT_SCENE = preload("res://Scenes/CardSlot.tscn")

var player_battlefield_panel:   Panel = null
var player_battlefield_right:   Panel = null
var opponent_battlefield_panel: Panel = null
var opponent_battlefield_right: Panel = null
var player_champion_legend:     Panel = null
var opponent_champion_legend:   Panel = null
var player_main_deck:           Panel = null
var player_rune_deck:           Panel = null
var opponent_main_deck:         Panel = null
var opponent_rune_deck:         Panel = null
var player_runes_panel:         Panel = null
var opponent_runes_panel:       Panel = null
var arena_p0_panel:             Panel = null
var arena_p1_panel:             Panel = null
var player_base_panel:          Panel = null
var opponent_base_panel:        Panel = null
var player_champion_panel:      Panel = null
var opponent_champion_panel:    Panel = null
var player_trash_panel:         Panel = null
var opponent_trash_panel:       Panel = null

var _player_slot_nodes: Array = []
var _p1_slot_nodes:     Array = []

var _p0_battlefield_left:  Panel = null
var _p0_battlefield_right: Panel = null
var _p1_battlefield_left:  Panel = null
var _p1_battlefield_right: Panel = null

var _p0_bf_slot_left:  CardSlot = null
var _p0_bf_slot_right: CardSlot = null
var _p1_bf_slot_left:  CardSlot = null
var _p1_bf_slot_right: CardSlot = null

# Stored refs to point circle panels — index 0 = point 1, index 7 = point 8
var _p0_point_panels: Array[Panel] = []  # bottom player
var _p1_point_panels: Array[Panel] = []  # top player

var _ph:        float = 0.0
var _bh:        float = 0.0
var _bfw:       float = 0.0
var _btn_x:     float = 0.0
var _logo_tex:  ImageTexture
var _runes_tex: ImageTexture

func _ready() -> void:
	if not Engine.is_editor_hint():
		game_controller = get_node_or_null("../GameController")

	var self_style = StyleBoxFlat.new()
	self_style.bg_color = COLOR_BG
	self_style.set_border_width_all(0)
	add_theme_stylebox_override("panel", self_style)

	theme = null

	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)

	_ph        = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	_bh        = _ph - HAND_H
	_logo_tex  = tint_gold("res://Assets/RiftBoundLogo.jpg")
	_runes_tex = tint_gold("res://Assets/runes.jpg")

	build_player(0.0, true)

	# ── Arena strip ──────────────────────────────────────────────────────────
	var arena_y  = _ph
	var xl_arena = float(MANA_COL_W)
	var bf1_w    = _bfw
	var bf2_w    = _bfw
	_btn_x       = xl_arena + bf1_w + GAP + bf2_w + GAP

	arena_p0_panel = add_panel(
		"Arena_P0",
		Vector2(xl_arena, arena_y),
		Vector2(bf1_w, ARENA_H),
		make_style(), "", 18
	)
	add_rect(Vector2(xl_arena + bf1_w, arena_y), Vector2(GAP, ARENA_H), COLOR_BG)
	arena_p1_panel = add_panel(
		"Arena_P1",
		Vector2(xl_arena + bf1_w + GAP, arena_y),
		Vector2(bf2_w, ARENA_H),
		make_style(), "", 18
	)

	# ── Four button boxes ─────────────────────────────────────────────────────
	var btn_total = SCREEN_W - _btn_x
	var btn_h     = ARENA_H / 2.0
	var btn_mid_x = _btn_x + btn_total / 2.0

	add_rect(Vector2(_btn_x, arena_y), Vector2(btn_total, ARENA_H), COLOR_BG)

	# Outer border
	add_rect(Vector2(_btn_x,               arena_y),                      Vector2(btn_total, BORDER_W), COLOR_BORDER)
	add_rect(Vector2(_btn_x,               arena_y + ARENA_H - BORDER_W), Vector2(btn_total, BORDER_W), COLOR_BORDER)
	add_rect(Vector2(_btn_x,               arena_y),                      Vector2(BORDER_W,  ARENA_H),  COLOR_BORDER)
	add_rect(Vector2(SCREEN_W - BORDER_W,  arena_y),                      Vector2(BORDER_W,  ARENA_H),  COLOR_BORDER)

	# Inner dividers
	add_rect(Vector2(btn_mid_x - floor(BORDER_W / 2.0), arena_y), Vector2(BORDER_W, ARENA_H), COLOR_BORDER)
	add_rect(Vector2(_btn_x, arena_y + btn_h - floor(BORDER_W / 2.0)), Vector2(btn_total, BORDER_W), COLOR_BORDER)

	build_player(_ph + ARENA_H, false)

	if not Engine.is_editor_hint():
		call_deferred("_post_ready_setup")
	else:
		call_deferred("_editor_fit_collisions")

func _editor_fit_collisions() -> void:
	_setup_battlefield_halves()
	_fit_zone_collisions()
	_reposition_scene_nodes()
	_style_buttons()
	_hide_arena_visuals()

func _post_ready_setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_cache_player_slots()
	_setup_battlefield_halves()
	_spawn_battlefield_slots()
	_fit_zone_collisions()
	_reposition_scene_nodes()
	_style_buttons()
	_hide_arena_visuals()

func _hide_arena_visuals() -> void:
	for path in ["../P0_Arena", "../P1_Arena"]:
		var node = get_node_or_null(path)
		if node == null:
			continue
		for child in node.get_children():
			if child is CanvasItem:
				child.visible = false
		if node is CanvasItem:
			node.modulate = Color(1, 1, 1, 0)

# ─── Points Visualization ─────────────────────────────────────────────────────

## Call this from game_controller after any state change that may affect points.
## p0_points and p1_points are the raw integer point counts from PlayerState.
func refresh_points(p0_points: int, p1_points: int) -> void:
	_apply_points_to_circles(_p0_point_panels, p0_points, false)
	_apply_points_to_circles(_p1_point_panels, p1_points, true)

## panels array: index 0 = circle labelled "1", index 7 = circle labelled "8".
## For the bottom player (flip=false) point 1 is at the bottom, so we fill upward.
## For the top player    (flip=true)  point 1 is at the top,    so we fill downward.
func _apply_points_to_circles(panels: Array[Panel], points: int, top_player: bool) -> void:
	for i in range(panels.size()):
		var panel: Panel = panels[i]
		if panel == null:
			continue

		# circle_number is 1-based (matches the label text "1".."8")
		var circle_number: int = i + 1

		var is_scored: bool = circle_number <= points

		var style: StyleBoxFlat = make_style(true)

		if is_scored:
			style.bg_color     = COLOR_POINT_SCORED
			style.border_color = COLOR_BORDER
			# Brighten label so it reads on the gold fill
			var label: Label = panel.get_child(0) as Label
			if label:
				label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02, 1.0))
		else:
			style.bg_color     = COLOR_POINT_UNSCORED
			style.border_color = COLOR_BORDER
			var label: Label = panel.get_child(0) as Label
			if label:
				label.add_theme_color_override("font_color", COLOR_BORDER)

		panel.add_theme_stylebox_override("panel", style)

# ─── Scene Node Repositioning ─────────────────────────────────────────────────

func _style_buttons() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BG
	btn_style.set_border_width_all(0)

	var btn_paths = [
		"../EndTurnButton", "../CancelPaymentButton", "../PassPriorityButton",
		"../ConfirmDamageButton", "../ChoiceAButton", "../ChoiceBButton"
	]
	for path in btn_paths:
		var btn = get_node_or_null(path)
		if btn:
			btn.add_theme_stylebox_override("normal",   btn_style.duplicate())
			btn.add_theme_stylebox_override("hover",    btn_style.duplicate())
			btn.add_theme_stylebox_override("pressed",  btn_style.duplicate())
			btn.add_theme_stylebox_override("disabled", btn_style.duplicate())
			btn.add_theme_stylebox_override("focus",    btn_style.duplicate())

func _reposition_scene_nodes() -> void:
	# ── P0 (bottom player) ───────────────────────────────────────────────────
	_move_to_panel("../P0/P0_Battlefield1", player_battlefield_panel)
	_move_to_panel("../P0/P0_Battlefield2", player_battlefield_right)
	_move_to_panel("../P0/P0_Legend",       player_champion_legend)
	_move_to_panel("../P0/P0_Champion",     player_champion_panel)
	_move_to_panel("../P0/P0_Base",         player_base_panel)
	_move_to_panel("../P0/P0_MainDeck",     player_main_deck)
	_move_to_panel("../P0/P0_RuneDeck",     player_rune_deck)
	_move_to_panel("../P0/P0_Runes",        player_runes_panel)
	_move_to_panel("../P0/P0_Trash",        player_trash_panel)

	var p0_top = _ph + ARENA_H
	_move("../P0/P0_Hand", Vector2(SCREEN_W / 2.0, p0_top + _bh + HAND_H / 2.0))

	var p0_points = get_node_or_null("../P0/P0_Points")
	if p0_points:
		p0_points.position = Vector2.ZERO
		var rh = _bh / 8.0
		for i in range(1, 9):
			var pt = p0_points.get_node_or_null("P0_Point%d" % i)
			if pt:
				pt.position = Vector2(27.0, p0_top + (8 - i) * rh + rh / 2.0)

	# ── P1 (top player) ──────────────────────────────────────────────────────
	_move_to_panel("../P1/P1_Battlefield1", opponent_battlefield_panel)
	_move_to_panel("../P1/P1_Battlefield2", opponent_battlefield_right)
	_move_to_panel("../P1/P1_Legend",       opponent_champion_legend)
	_move_to_panel("../P1/P1_Champion",     opponent_champion_panel)
	_move_to_panel("../P1/P1_Base",         opponent_base_panel)
	_move_to_panel("../P1/P1_MainDeck",     opponent_main_deck)
	_move_to_panel("../P1/P1_RuneDeck",     opponent_rune_deck)
	_move_to_panel("../P1/P1_Runes",        opponent_runes_panel)
	_move_to_panel("../P1/P1_Trash",        opponent_trash_panel)

	_move("../P1/P1_Hand", Vector2(SCREEN_W / 2.0, HAND_H / 2.0))

	var p1_points = get_node_or_null("../P1/P1_Points")
	if p1_points:
		p1_points.position = Vector2.ZERO
		var rh = _bh / 8.0
		for i in range(1, 9):
			var pt = p1_points.get_node_or_null("P1_Point%d" % i)
			if pt:
				pt.position = Vector2(27.0, HAND_H + (i - 1) * rh + rh / 2.0)

	# ── Buttons — arena strip ─────────────────────────────────────────────────
	var arena_y   = _ph
	var btn_h     = ARENA_H / 2.0
	var btn_total = SCREEN_W - _btn_x
	var btn_mid_x = _btn_x + btn_total / 2.0

	# Right half — action buttons (inset by BORDER_W so they don't overlap the gold outline)
	_move_control("../EndTurnButton",       btn_mid_x,            arena_y + BORDER_W,         SCREEN_W - BORDER_W, arena_y + btn_h)
	_move_control("../CancelPaymentButton", btn_mid_x,            arena_y + btn_h,             SCREEN_W - BORDER_W, arena_y + btn_h * 2.0 - BORDER_W)
	_move_control("../PassPriorityButton",  btn_mid_x,            arena_y + btn_h,             SCREEN_W - BORDER_W, arena_y + btn_h * 2.0 - BORDER_W)
	_move_control("../ConfirmDamageButton", btn_mid_x,            arena_y + btn_h,             SCREEN_W - BORDER_W, arena_y + btn_h * 2.0 - BORDER_W)

	# Left half — choice buttons
	_move_control("../ChoiceAButton",       _btn_x + BORDER_W,    arena_y + BORDER_W,          btn_mid_x,           arena_y + btn_h)
	_move_control("../ChoiceBButton",       _btn_x + BORDER_W,    arena_y + btn_h,             btn_mid_x,           arena_y + btn_h * 2.0 - BORDER_W)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _move_to_panel(node_path: String, panel: Panel) -> void:
	if panel == null:
		return
	var node = get_node_or_null(node_path)
	if node == null:
		push_warning("Board.gd: _move_to_panel() could not find node: " + node_path)
		return
	node.global_position = panel.global_position + panel.size / 2.0

func _move_control(path: String, left: float, top: float, right: float, bottom: float) -> void:
	var node = get_node_or_null(path)
	if node == null:
		push_warning("Board.gd: _move_control() could not find node: " + path)
		return
	node.offset_left   = left
	node.offset_top    = top
	node.offset_right  = right
	node.offset_bottom = bottom

func _move(path: String, pos: Vector2) -> void:
	var node = get_node_or_null(path)
	if node:
		node.position = pos
	else:
		push_warning("Board.gd: _move() could not find node: " + path)

# ─── Slot Setup ───────────────────────────────────────────────────────────────

func _cache_player_slots() -> void:
	_player_slot_nodes.clear()
	_p1_slot_nodes.clear()

	var p0_base = get_node_or_null("../P0/P0_Base")
	if p0_base and p0_base is CardSlot:
		_player_slot_nodes.append(p0_base)
	else:
		push_warning("Board.gd: P0_Base not found.")

	var p1_base = get_node_or_null("../P1/P1_Base")
	if p1_base and p1_base is CardSlot:
		_p1_slot_nodes.append(p1_base)
	else:
		push_warning("Board.gd: P1_Base not found.")

func _fit_zone_collisions() -> void:
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Battlefield1"), player_battlefield_panel)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Battlefield2"), player_battlefield_right)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Battlefield1"), opponent_battlefield_panel)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Battlefield2"), opponent_battlefield_right)
	_fit_collision_to_panel(get_node_or_null("../P0_Arena"),           arena_p0_panel)
	_fit_collision_to_panel(get_node_or_null("../P1_Arena"),           arena_p1_panel)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Base"),         player_base_panel)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Base"),         opponent_base_panel)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Legend"),       player_champion_legend)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Legend"),       opponent_champion_legend)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Champion"),     player_champion_panel)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Champion"),     opponent_champion_panel)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_MainDeck"),     player_main_deck)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_MainDeck"),     opponent_main_deck)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Runes"),        player_runes_panel)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Runes"),        opponent_runes_panel)
	_fit_collision_to_panel(get_node_or_null("../P0/P0_Trash"),        player_trash_panel)
	_fit_collision_to_panel(get_node_or_null("../P1/P1_Trash"),        opponent_trash_panel)
	_fit_rune_deck_to_panel(get_node_or_null("../P0/P0_RuneDeck"),     player_rune_deck)
	_fit_rune_deck_to_panel(get_node_or_null("../P1/P1_RuneDeck"),     opponent_rune_deck)
	_resize_hand_collision(get_node_or_null("../P0/P0_Hand"))
	_resize_hand_collision(get_node_or_null("../P1/P1_Hand"))
	for i in range(1, 9):
		_fit_point_collision(get_node_or_null("../P0/P0_Points/P0_Point%d" % i))
		_fit_point_collision(get_node_or_null("../P1/P1_Points/P1_Point%d" % i))

func _resize_hand_collision(hand: Node) -> void:
	if hand == null:
		return
	var area = hand.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = Vector2(SCREEN_W, HAND_H)

func _fit_rune_deck_to_panel(node: Node2D, panel: Panel) -> void:
	if node == null or panel == null:
		return
	node.global_position = panel.global_position + panel.size / 2.0
	var area = node.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.position   = Vector2.ZERO
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = panel.size / node.scale

func _fit_point_collision(node: Node2D) -> void:
	if node == null:
		return
	var area = node.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is CircleShape2D:
			shape_node.shape        = shape_node.shape.duplicate()
			shape_node.shape.radius = MANA_SIZE / 2.0

func _fit_collision_to_panel(node: Node2D, panel: Panel) -> void:
	if node == null or panel == null:
		return
	node.global_position = panel.global_position + panel.size / 2.0
	var area = node.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = panel.size

func _setup_battlefield_halves() -> void:
	_p0_battlefield_left  = player_battlefield_panel
	_p0_battlefield_right = player_battlefield_right
	_p1_battlefield_left  = opponent_battlefield_panel
	_p1_battlefield_right = opponent_battlefield_right

func _spawn_battlefield_slots() -> void:
	_p1_bf_slot_left  = _create_battlefield_slot(_p1_battlefield_left,  "P1_Left")
	_p1_bf_slot_right = _create_battlefield_slot(_p1_battlefield_right, "P1_Right")
	_p0_bf_slot_left  = _create_battlefield_slot(_p0_battlefield_left,  "P0_Left")
	_p0_bf_slot_right = _create_battlefield_slot(_p0_battlefield_right, "P0_Right")

func _create_battlefield_slot(panel: Panel, slot_name: String) -> CardSlot:
	if panel == null:
		return null

	var existing = panel.get_node_or_null(slot_name)
	if existing and existing is CardSlot:
		return existing

	var slot: CardSlot = CARD_SLOT_SCENE.instantiate()
	slot.name          = slot_name
	panel.add_child(slot)
	slot.position      = panel.size / 2.0

	var area = slot.get_node_or_null("Area2D")
	if area:
		area.collision_layer = 4
		area.collision_mask  = 4
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = panel.size

	return slot

# ─── Slot Detection ───────────────────────────────────────────────────────────

func get_slot_index_under_mouse() -> int:
	if game_controller == null:
		return -1
	var active_id: int = game_controller.state.get_active_player().id
	var slots          = _player_slot_nodes if active_id == 0 else _p1_slot_nodes
	var mouse_pos      = get_global_mouse_position()

	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null:
			continue
		var local_mouse: Vector2 = slot.to_local(mouse_pos)
		var half: Vector2        = slot._get_collision_size() / 2.0
		if abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y:
			return i

	return -1

func get_battlefield_half_under_mouse() -> Dictionary:
	var mouse_pos = get_global_mouse_position()

	var entries = [
		{"player": 1, "lane": 0, "slot": _p1_bf_slot_left},
		{"player": 1, "lane": 1, "slot": _p1_bf_slot_right},
		{"player": 0, "lane": 0, "slot": _p0_bf_slot_left},
		{"player": 0, "lane": 1, "slot": _p0_bf_slot_right},
	]

	for entry in entries:
		var slot = entry["slot"]
		if slot == null:
			continue
		var local_mouse = slot.to_local(mouse_pos)
		var half        = slot._get_collision_size() / 2.0
		if abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y:
			return entry

	return {}

func get_all_battlefield_slots() -> Array:
	return [_p0_bf_slot_left, _p0_bf_slot_right, _p1_bf_slot_left, _p1_bf_slot_right]

# ─── Drawing Utilities ────────────────────────────────────────────────────────

func add_rect(pos: Vector2, size: Vector2, color: Color, parent: Node = self) -> void:
	var r      = ColorRect.new()
	r.position = pos
	r.size     = size
	r.color    = color
	parent.add_child(r)

func make_style(rounded := false, fill := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s          = StyleBoxFlat.new()
	s.bg_color     = fill
	s.border_color = COLOR_BORDER
	s.set_border_width_all(BORDER_W)
	if rounded:
		s.set_corner_radius_all(int(MANA_SIZE / 2))
	return s

func add_panel(
		pname: String, pos: Vector2, size: Vector2,
		style := make_style(), label_text := pname,
		font_size := FONT_SIZE, parent: Node = self
	) -> Panel:
	var p      = Panel.new()
	p.name     = pname
	p.position = pos
	p.size     = size
	style.bg_color = COLOR_BG
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)

	var l           = Label.new()
	l.text          = label_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size          = Vector2(size.x - 8, 40)
	l.position      = Vector2(6, size.y - 30)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", COLOR_BORDER)
	p.add_child(l)

	return p

func tint_gold(path: String) -> ImageTexture:
	var img = (load(path) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	for py in img.get_height():
		for px in img.get_width():
			var b = img.get_pixel(px, py)
			img.set_pixel(px, py, Color(0.83, 0.68, 0.21, min(maxf(b.r, maxf(b.g, b.b)) * 3.0, 1.0)))
	return ImageTexture.create_from_image(img)

func add_image(
		panel: Panel, tex: ImageTexture,
		al: float, at: float, ar: float, ab: float,
		ol := 0.0, ot := 0.0, orr := 0.0, ob := 0.0, mod := Color.WHITE
	) -> void:
	var tr           = TextureRect.new()
	tr.texture       = tex
	tr.anchor_left   = al
	tr.anchor_top    = at
	tr.anchor_right  = ar
	tr.anchor_bottom = ab
	tr.offset_left   = ol
	tr.offset_top    = ot
	tr.offset_right  = orr
	tr.offset_bottom = ob
	tr.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	tr.modulate      = mod
	panel.add_child(tr)

func build_player(y: float, flip: bool) -> void:
	var PAD = 8.0
	var bh  = _bh
	var by  = y + HAND_H if flip else y
	var hy  = y if flip else y + bh

	_draw_border_box(Vector2(0, hy), Vector2(SCREEN_W, HAND_H))

	var rh = bh / 8.0

	# ── Point circles ─────────────────────────────────────────────────────────
	# Collect into the correct array as we create them so refresh_points() has
	# direct refs without any tree search. Index 0 = point label "1", index 7 = "8".
	var point_panel_array: Array[Panel] = []

	for i in range(1, 9):
		var cy = by + ((i - 1) if flip else (8 - i)) * rh + (rh - MANA_SIZE) / 2.0
		var c  = add_panel("Mana%d" % i, Vector2(MANA_X, cy), Vector2(MANA_SIZE, MANA_SIZE), make_style(true), str(i), 13)
		var ml = c.get_child(0) as Label
		ml.position             = Vector2.ZERO
		ml.size                 = Vector2(MANA_SIZE, MANA_SIZE)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

		# Store at index i-1 so index 0 == point 1
		point_panel_array.append(c)

	# Assign to the correct player's array.
	# flip=true  → this is the top (opponent / P1) player
	# flip=false → this is the bottom (local / P0) player
	if flip:
		_p1_point_panels = point_panel_array
	else:
		_p0_point_panels = point_panel_array

	var tw  = SCREEN_W - MANA_COL_W - GAP
	var cw  = floor(tw * 0.14)
	var lw  = tw - cw * 2 - GAP * 2
	var bfw = floor((lw - GAP) / 2.0)
	var rdw = floor(lw * 0.15)
	var xl  = float(MANA_COL_W)
	var xc  = xl + lw + GAP
	var xr  = xc + cw + GAP
	var inn = bh - PAD * 2
	var re  = floor((inn - GAP * 2) / 3.0)
	var y1  = PAD
	var y2  = PAD + re + GAP
	var y3  = PAD + re * 2 + GAP * 2
	var rb  = inn - re * 2 - GAP * 2

	if _bfw == 0.0:
		_bfw = bfw

	var zones = [
		["BATTLEFIELD 1", xl,         y1, bfw,                    re],
		["BATTLEFIELD 2", xl+bfw+GAP, y1, bfw,                    re],
		["LEGEND",        xc,         y1, cw,                     re],
		["CHAMPION",      xr,         y1, cw,                     re],
		["BASE",          xl,         y2, lw + cw + GAP,          re],
		["MAIN DECK",     xr,         y2, cw,                     re],
		["RUNE DECK",     xl,         y3, rdw,                    rb],
		["RUNES",         xl+rdw+GAP, y3, lw-rdw-GAP+cw+GAP,     rb],
		["TRASH",         xr,         y3, cw,                     rb],
	]

	var zone_panel_keys := {
		"BATTLEFIELD 1": ["player_battlefield_panel",   "opponent_battlefield_panel"],
		"BATTLEFIELD 2": ["player_battlefield_right",   "opponent_battlefield_right"],
		"LEGEND":        ["player_champion_legend",     "opponent_champion_legend"],
		"CHAMPION":      ["player_champion_panel",      "opponent_champion_panel"],
		"MAIN DECK":     ["player_main_deck",           "opponent_main_deck"],
		"RUNE DECK":     ["player_rune_deck",           "opponent_rune_deck"],
		"RUNES":         ["player_runes_panel",         "opponent_runes_panel"],
		"BASE":          ["player_base_panel",          "opponent_base_panel"],
		"TRASH":         ["player_trash_panel",         "opponent_trash_panel"],
	}

	for z in zones:
		var zname := z[0] as String
		var fy     = by + float(z[2]) if not flip else by + (bh - float(z[2]) - float(z[4]))
		var p      = add_panel(zname.replace(" ", "_"), Vector2(float(z[1]), fy), Vector2(float(z[3]), float(z[4])), make_style(), zname)

		if zname in zone_panel_keys:
			set(zone_panel_keys[zname][1 if flip else 0], p)

		if zname == "BASE":
			add_image(p, _logo_tex, -0.2, -0.5, 1.2, 1.5, 0.0, 0.0, 0.0, 0.0, Color(0.83, 0.68, 0.21, 0.55))
		elif zname == "RUNES":
			add_image(p, _runes_tex, 0.05, 0.2, 0.25, 1.0, 6.0, 1.0, 0.0, 0.0)

func _draw_border_box(pos: Vector2, size: Vector2) -> void:
	add_rect(Vector2(pos.x,                      pos.y),                     Vector2(size.x,  BORDER_W), COLOR_BORDER)
	add_rect(Vector2(pos.x,                      pos.y + size.y - BORDER_W), Vector2(size.x,  BORDER_W), COLOR_BORDER)
	add_rect(Vector2(pos.x,                      pos.y),                     Vector2(BORDER_W, size.y),  COLOR_BORDER)
	add_rect(Vector2(pos.x + size.x - BORDER_W,  pos.y),                     Vector2(BORDER_W, size.y),  COLOR_BORDER)
