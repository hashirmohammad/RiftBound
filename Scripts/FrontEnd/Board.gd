extends Control

@onready var game_controller: Node = $"../GameController"

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
const HAND_H       = 130
const DIVIDER_H    = 4
const ARENA_H      = 200
const END_BTN_W    = 160.0

const CARD_SLOT_SCENE = preload("res://Scenes/CardSlot.tscn")

# Public panel references — GameController renders card visuals into these
var player_battlefield_panel:   Panel = null
var opponent_battlefield_panel: Panel = null
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
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)

	var ph      = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0, true, ph)
	add_rect(Vector2(0, ph), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)

	var half_w  = (SCREEN_W - END_BTN_W) / 2.0
	var arena_y = ph + DIVIDER_H

	arena_p0_panel = add_panel("Arena_P0", Vector2(0, arena_y),                    Vector2(half_w, ARENA_H),            make_style(), "Arena 1", 18)
	add_rect(Vector2(half_w, arena_y), Vector2(DIVIDER_H, ARENA_H), COLOR_DIV)
	arena_p1_panel = add_panel("Arena_P1", Vector2(half_w + DIVIDER_H, arena_y),   Vector2(half_w - DIVIDER_H, ARENA_H), make_style(), "Arena 2", 18)
	add_rect(Vector2(SCREEN_W - END_BTN_W, arena_y), Vector2(1, ARENA_H), COLOR_DIV)

	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H, false, ph)

	_cache_player_slots()
	_setup_battlefield_halves()
	_spawn_battlefield_slots()

# ─── Slot Setup ───────────────────────────────────────────────────────────────

func _cache_player_slots() -> void:
	_player_slot_nodes.clear()
	_p1_slot_nodes.clear()

	var p0_base = get_node_or_null("../P0/P0_Base")
	if p0_base and p0_base is CardSlot:
		_player_slot_nodes.append(p0_base)
	else:
		push_warning("Board.gd: P0_Base not found or not a CardSlot.")

	var p1_base = get_node_or_null("../P1/P1_Base")
	if p1_base and p1_base is CardSlot:
		_p1_slot_nodes.append(p1_base)
	else:
		push_warning("Board.gd: P1_Base not found or not a CardSlot.")

func _setup_battlefield_halves() -> void:
	_p0_battlefield_left  = _create_battlefield_half(player_battlefield_panel,   "P0_LeftHalf",  0)
	_p0_battlefield_right = _create_battlefield_half(player_battlefield_panel,   "P0_RightHalf", 1)
	_p1_battlefield_left  = _create_battlefield_half(opponent_battlefield_panel, "P1_LeftHalf",  0)
	_p1_battlefield_right = _create_battlefield_half(opponent_battlefield_panel, "P1_RightHalf", 1)

func _create_battlefield_half(parent_panel: Panel, half_name: String, half_index: int) -> Panel:
	if parent_panel == null:
		return null

	var existing = parent_panel.get_node_or_null(half_name)
	if existing and existing is Panel:
		return existing

	var half_gap = 8.0
	var half_w   = (parent_panel.size.x - half_gap) / 2.0

	var panel          = Panel.new()
	panel.name         = half_name
	panel.position     = Vector2(0, 0) if half_index == 0 else Vector2(half_w + half_gap, 0)
	panel.size         = Vector2(half_w, parent_panel.size.y)
	panel.add_theme_stylebox_override("panel", make_style())
	parent_panel.add_child(panel)

	return panel

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

	var usable_h  = panel.size.y - 30.0
	slot.position = Vector2(panel.size.x / 2.0, usable_h / 2.0 + 12.0)

	var area = slot.get_node_or_null("Area2D")
	if area:
		area.collision_layer = 4
		area.collision_mask  = 4
		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape      = shape_node.shape.duplicate()
			shape_node.shape.size = Vector2(panel.size.x - 16.0, usable_h)

	return slot

# ─── Slot Detection ───────────────────────────────────────────────────────────

func get_slot_index_under_mouse() -> int:
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
		["BATTLEFIELD",     xl,         y1, lw,                  re],
		["CHAMPION LEGEND", xc,         y1, cw,                  re],
		["CHOSEN CHAMPION", xr,         y1, cw,                  re],
		["BASE",            xl,         y2, lw + cw + GAP,       re],
		["MAIN DECK",       xr,         y2, cw,                  re],
		["RUNE DECK",       xl,         y3, rdw,                 rb],
		["RUNES",           xl+rdw+GAP, y3, lw-rdw-GAP+cw+GAP,  rb],
		["TRASH",           xr,         y3, cw,                  rb],
	]

	var runes_ref: Panel = null
	for z in zones:
		var zname := z[0] as String
		var fy     = by + float(z[2]) if not flip else by + (bh - float(z[2]) - float(z[4]))
		var p      = add_panel(zname.replace(" ", "_"), Vector2(float(z[1]), fy), Vector2(float(z[3]), float(z[4])), make_style(), zname)

		if zname == "RUNES": runes_ref = p

		if   not flip and zname == "BATTLEFIELD":     player_battlefield_panel   = p
		elif flip     and zname == "BATTLEFIELD":     opponent_battlefield_panel = p
		if   not flip and zname == "CHAMPION LEGEND": player_champion_legend     = p
		elif flip     and zname == "CHAMPION LEGEND": opponent_champion_legend   = p
		if   not flip and zname == "MAIN DECK":       player_main_deck           = p
		elif flip     and zname == "MAIN DECK":       opponent_main_deck         = p
		if   not flip and zname == "RUNE DECK":       player_rune_deck           = p
		elif flip     and zname == "RUNE DECK":       opponent_rune_deck         = p
		if   not flip and zname == "RUNES":           player_runes_panel         = p
		elif flip     and zname == "RUNES":           opponent_runes_panel       = p

		if zname == "BASE":
			add_image(p, tint_gold("res://Assets/RiftBoundLogo.jpg"), -0.2, -0.5, 1.2, 1.5, 0.0, 0.0, 0.0, 0.0, Color(0.83, 0.68, 0.21, 0.55))

	if runes_ref:
		add_image(runes_ref, tint_gold("res://Assets/runes.jpg"), 0.05, 0.2, 0.25, 1.0, 6.0, 1.0, 0.0, 0.0)
