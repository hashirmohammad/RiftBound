@tool
extends Control

var game_controller: Node

const SCREEN_W    = 1920.0
const SCREEN_H    = 1080.0
const COLOR_BG    = Color("#0d1b35")
const COLOR_BORDER = Color(0.83, 0.68, 0.21, 0.95)
const COLOR_DIV   = Color(1, 1, 1, 0.20)
const COLOR_HAND  = Color(1, 1, 1, 0.05)
const BORDER_W    = 2
const GAP         = 6
const FONT_SIZE   = 11
const MANA_X      = 8
const MANA_SIZE   = 38
const MANA_COL_W  = 52
const HAND_H      = 180   # increased from 130 — bigger hand area
const DIVIDER_H   = 4
const ARENA_H     = 100   # reduced to give player zones more height for cards
const END_BTN_W   = 160.0

const CARD_SLOT_SCENE = preload("res://Scenes/CardSlot.tscn")

# Public panel references — GameController renders card visuals into these
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

# Base panel references — used to fit slot collisions
var player_base_panel:   Panel = null
var opponent_base_panel: Panel = null

# Champion / Trash panel references — stored so _reposition_scene_nodes
# can call _move_to_panel instead of recalculating geometry manually.
var player_champion_panel:    Panel = null
var opponent_champion_panel:  Panel = null
var player_trash_panel:       Panel = null
var opponent_trash_panel:     Panel = null

# Slot nodes — used by CardManager for highlight routing
var _player_slot_nodes: Array = []
var _p1_slot_nodes:     Array = []

# Battlefield halves — internal structure
var _p0_battlefield_left:  Panel = null
var _p0_battlefield_right: Panel = null
var _p1_battlefield_left:  Panel = null
var _p1_battlefield_right: Panel = null

# Battlefield CardSlots — used by CardManager for highlight routing
var _p0_bf_slot_left:  CardSlot = null
var _p0_bf_slot_right: CardSlot = null
var _p1_bf_slot_left:  CardSlot = null
var _p1_bf_slot_right: CardSlot = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		game_controller = get_node_or_null("../GameController")
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)

	var ph      = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0, true, ph)
	add_rect(Vector2(0, ph), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)

	var half_w  = (SCREEN_W - END_BTN_W) / 2.0
	var arena_y = ph + DIVIDER_H

	arena_p0_panel = add_panel("Arena_P0", Vector2(0, arena_y),                   Vector2(half_w, ARENA_H),             make_style(), "Arena 1", 18)
	add_rect(Vector2(half_w, arena_y), Vector2(DIVIDER_H, ARENA_H), COLOR_DIV)
	arena_p1_panel = add_panel("Arena_P1", Vector2(half_w + DIVIDER_H, arena_y),  Vector2(half_w - DIVIDER_H, ARENA_H), make_style(), "Arena 2", 18)
	add_rect(Vector2(SCREEN_W - END_BTN_W, arena_y), Vector2(1, ARENA_H), COLOR_DIV)

	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H, false, ph)

	if not Engine.is_editor_hint():
		call_deferred("_post_ready_setup")

func _post_ready_setup() -> void:
	# Wait two frames so the Control layout pass fully resolves panel positions
	# before we read global_position for collision placement.
	await get_tree().process_frame
	await get_tree().process_frame
	_cache_player_slots()
	_setup_battlefield_halves()
	_spawn_battlefield_slots()
	_fit_zone_collisions()
	_reposition_scene_nodes()
	_debug_panels()

func _debug_panels() -> void:
	var checks = [
		["p0_bf1",    player_battlefield_panel],
		["p0_bf2",    player_battlefield_right],
		["p0_legend", player_champion_legend],
		["p0_base",   player_base_panel],
		["p0_runes",  player_runes_panel],
		["p1_bf1",    opponent_battlefield_panel],
		["p1_bf2",    opponent_battlefield_right],
		["p1_legend", opponent_champion_legend],
		["p1_base",   opponent_base_panel],
		["p1_runes",  opponent_runes_panel],
	]
	for c in checks:
		var p = c[1] as Panel
		if p:
			print("%s → gpos=%s size=%s centre=%s" % [c[0], str(p.global_position), str(p.size), str(p.global_position + p.size / 2.0)])
		else:
			print("%s → NULL" % c[0])

# ─── Scene Node Repositioning ─────────────────────────────────────────────────
# Uses stored panel references so every node lands exactly at its panel's centre.
# No manual geometry recalculation — the panels are the single source of truth.

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

	# Hand — centred horizontally in the hand strip
	var ph     = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	var p0_top = ph + DIVIDER_H * 2 + ARENA_H
	_move("../P0/P0_Hand", Vector2(SCREEN_W / 2.0, p0_top + (ph - HAND_H) + HAND_H / 2.0))

	# Mana points — evenly spaced inside P0's battlefield strip
	var bh = ph - HAND_H
	var p0_points = get_node_or_null("../P0/P0_Points")
	if p0_points:
		var rh = bh / 8.0
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
		var rh = bh / 8.0
		for i in range(1, 9):
			var pt = p1_points.get_node_or_null("P1_Point%d" % i)
			if pt:
				pt.position = Vector2(27.0, HAND_H + (i - 1) * rh + rh / 2.0)

	# ── Buttons — snap to arena strip ────────────────────────────────────────
	var arena_y = ph + DIVIDER_H
	var btn_h   = 50.0
	var btn_x   = SCREEN_W - END_BTN_W
	_move_control("../EndTurnButton",       btn_x, arena_y,           SCREEN_W, arena_y + btn_h)
	_move_control("../CancelPaymentButton", btn_x, arena_y + btn_h,   SCREEN_W, arena_y + btn_h * 2)
	_move_control("../PassPriorityButton",  btn_x, arena_y + btn_h,   SCREEN_W, arena_y + btn_h * 2)
	_move_control("../ConfirmDamageButton", btn_x, arena_y + btn_h,   SCREEN_W, arena_y + btn_h * 2)

# Sets a Node2D's position to the centre of a panel (global coords).
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
	_resize_hand_collision(get_node_or_null("../P0/P0_Hand"))
	_resize_hand_collision(get_node_or_null("../P1/P1_Hand"))

func _resize_hand_collision(hand: Node) -> void:
	if hand == null:
		return
	var area = hand.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = Vector2(SCREEN_W - BORDER_W * 2, HAND_H - BORDER_W * 2)

func _fit_collision_to_panel(node: Node2D, panel: Panel) -> void:
	if node == null or panel == null:
		return
	node.global_position = panel.global_position + panel.size / 2.0
	var area = node.get_node_or_null("Area2D")
	if area:
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = panel.size - Vector2(BORDER_W * 2, BORDER_W * 2)

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
			shape_node.shape.size = panel.size - Vector2(BORDER_W * 2, BORDER_W * 2)

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
	var p = Panel.new()
	p.name     = pname
	p.position = pos
	p.size     = size
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

func build_player(y: float, flip: bool, ph: float) -> void:
	var PAD = 8.0
	var bh  = ph - HAND_H
	var by  = y + HAND_H if flip else y
	var hy  = y if flip else y + bh

	add_panel("Hand", Vector2(0, hy), Vector2(SCREEN_W, HAND_H), make_style(false, COLOR_HAND))

	var rh = bh / 8.0
	for i in range(1, 9):
		var cy = by + ((i - 1) if flip else (8 - i)) * rh + (rh - MANA_SIZE) / 2.0
		var c  = add_panel("Mana%d" % i, Vector2(MANA_X, cy), Vector2(MANA_SIZE, MANA_SIZE), make_style(true), str(i), 13)
		var ml = c.get_child(0) as Label
		ml.position             = Vector2.ZERO
		ml.size                 = Vector2(MANA_SIZE, MANA_SIZE)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

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

	var zones = [
		["BATTLEFIELD 1", xl,         y1, bfw,                        re],
		["BATTLEFIELD 2", xl+bfw+GAP, y1, bfw,                        re],
		["LEGEND",        xc,         y1, cw,                         re],
		["CHAMPION",      xr,         y1, cw,                         re],
		["BASE",          xl,         y2, lw + cw + GAP,              re],
		["MAIN DECK",     xr,         y2, cw,                         re],
		["RUNE DECK",     xl,         y3, rdw,                        rb],
		["RUNES",         xl+rdw+GAP, y3, lw-rdw-GAP+cw+GAP,         rb],
		["TRASH",         xr,         y3, cw,                         rb],
	]

	var runes_ref: Panel = null
	for z in zones:
		var zname := z[0] as String
		var fy     = by + float(z[2]) if not flip else by + (bh - float(z[2]) - float(z[4]))
		var p      = add_panel(zname.replace(" ", "_"), Vector2(float(z[1]), fy), Vector2(float(z[3]), float(z[4])), make_style(), zname)

		if zname == "RUNES": runes_ref = p

		if   not flip and zname == "BATTLEFIELD 1": player_battlefield_panel   = p
		elif flip     and zname == "BATTLEFIELD 1": opponent_battlefield_panel = p
		if   not flip and zname == "BATTLEFIELD 2": player_battlefield_right   = p
		elif flip     and zname == "BATTLEFIELD 2": opponent_battlefield_right = p
		if   not flip and zname == "LEGEND":        player_champion_legend     = p
		elif flip     and zname == "LEGEND":        opponent_champion_legend   = p
		if   not flip and zname == "CHAMPION":      player_champion_panel      = p
		elif flip     and zname == "CHAMPION":      opponent_champion_panel    = p
		if   not flip and zname == "MAIN DECK":     player_main_deck           = p
		elif flip     and zname == "MAIN DECK":     opponent_main_deck         = p
		if   not flip and zname == "RUNE DECK":     player_rune_deck           = p
		elif flip     and zname == "RUNE DECK":     opponent_rune_deck         = p
		if   not flip and zname == "RUNES":         player_runes_panel         = p
		elif flip     and zname == "RUNES":         opponent_runes_panel       = p
		if   not flip and zname == "BASE":          player_base_panel          = p
		elif flip     and zname == "BASE":          opponent_base_panel        = p
		if   not flip and zname == "TRASH":         player_trash_panel         = p
		elif flip     and zname == "TRASH":         opponent_trash_panel       = p

		if zname == "BASE":
			add_image(p, tint_gold("res://Assets/RiftBoundLogo.jpg"), -0.2, -0.5, 1.2, 1.5, 0.0, 0.0, 0.0, 0.0, Color(0.83, 0.68, 0.21, 0.55))

	if runes_ref:
		add_image(runes_ref, tint_gold("res://Assets/runes.jpg"), 0.05, 0.2, 0.25, 1.0, 6.0, 1.0, 0.0, 0.0)
