@tool
extends Control

const SCREEN_W = 1920.0;  const SCREEN_H = 1080.0
const COLOR_BG     = Color("#0d1b35")
const COLOR_BORDER = Color(0.83, 0.68, 0.21, 0.95)
const COLOR_DIV    = Color(1, 1, 1, 0.20)
const COLOR_HAND   = Color(1, 1, 1, 0.05)
const BORDER_W = 2;  const GAP = 6;  const FONT_SIZE = 11
const MANA_X = 8;   const MANA_SIZE = 38;  const MANA_COL_W = 52
const HAND_H = 130; const DIVIDER_H = 4;   const ARENA_H = 200
const CARD_SCENE := preload("res://Scenes/Card.tscn")
const NORMAL_SCALE := Vector2(0.4, 0.4)

var _player_battlefield: Panel = null
var _board_cards: Array = []
var _hand_panel: Panel = null
var _player_slot_nodes: Array = []
var _player_champion_legend: Panel = null
var _opponent_champion_legend: Panel = null
var _player_main_deck: Panel = null
var _player_rune_deck: Panel = null
var _opponent_main_deck: Panel = null
var _opponent_rune_deck: Panel = null

func _ready() -> void:
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)
	var ph = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0, true, ph)
	add_rect(Vector2(0, ph), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	var arena = add_panel("Arena", Vector2(0, ph + DIVIDER_H), Vector2(SCREEN_W, ARENA_H), make_style(), "ARENA", 18)
	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H, false, ph)

	_cache_player_slots()

func _cache_player_slots() -> void:
	_player_slot_nodes.clear()

	var slots_root = get_node_or_null("../CardSlots")
	if slots_root == null:
		push_warning("Board.gd: CardSlots node not found.")
		return

	if _player_battlefield == null:
		push_warning("Board.gd: _player_battlefield is null.")
		return

	var battlefield_center_y: float = _player_battlefield.global_position.y + (_player_battlefield.size.y / 2.0)
	var row_tolerance: float = 60.0

	for child in slots_root.get_children():
		if child is CardSlot:
			var slot_y: float = child.global_position.y

			if abs(slot_y - battlefield_center_y) <= row_tolerance:
				_player_slot_nodes.append(child)

	_player_slot_nodes.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)

	print("Cached battlefield slots: ", _player_slot_nodes.size())
	for i in range(_player_slot_nodes.size()):
		print("slot ", i, " -> ", _player_slot_nodes[i].global_position)

func get_slot_index_under_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	var slot_size := Vector2(140, 190)

	for i in range(_player_slot_nodes.size()):
		var slot = _player_slot_nodes[i]
		if slot == null:
			continue

		var rect = Rect2(slot.global_position - slot_size / 2.0, slot_size)
		if rect.has_point(mouse_pos):
			print("Detected slot index: ", i, " / total slots: ", _player_slot_nodes.size())
			return i

	return -1

func add_rect(pos: Vector2, size: Vector2, color: Color, parent: Node = self) -> void:
	var r = ColorRect.new()
	r.position = pos;  r.size = size;  r.color = color
	parent.add_child(r)

func make_style(rounded := false, fill := Color(0,0,0,0)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill;  s.border_color = COLOR_BORDER
	s.set_border_width_all(BORDER_W)
	if rounded:
		s.set_corner_radius_all(int(MANA_SIZE / 2))
	return s

func add_panel(pname: String, pos: Vector2, size: Vector2,
		style := make_style(), label_text := pname, font_size := FONT_SIZE,
		parent: Node = self) -> Panel:
	var p = Panel.new()
	p.name = pname;  p.position = pos;  p.size = size
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	var l = Label.new()
	l.text = label_text;  l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size = Vector2(size.x - 8, 40);  l.position = Vector2(6, size.y - 30)
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

func add_image(panel: Panel, tex: ImageTexture, al: float, at: float, ar: float, ab: float,
		ol := 0.0, ot := 0.0, orr := 0.0, ob := 0.0, mod := Color.WHITE) -> void:
	var tr = TextureRect.new()
	tr.texture = tex
	tr.anchor_left = al;  tr.anchor_top = at;  tr.anchor_right = ar;  tr.anchor_bottom = ab
	tr.offset_left = ol;  tr.offset_top = ot;  tr.offset_right = orr; tr.offset_bottom = ob
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = mod
	panel.add_child(tr)

func build_player(y: float, flip: bool, ph: float) -> void:
	var PAD = 8.0
	var bh  = ph - HAND_H
	var by  = y + HAND_H if flip else y
	var hy  = y          if flip else y + bh

	var hand_panel = add_panel("Hand", Vector2(0, hy), Vector2(SCREEN_W, HAND_H),
		make_style(false, COLOR_HAND))

	if not flip:
		_hand_panel = hand_panel

	var rh = bh / 8.0
	for i in range(1, 9):
		var cy = by + ((i-1) if flip else (8-i)) * rh + (rh - MANA_SIZE) / 2.0
		var c = add_panel("Mana%d" % i, Vector2(MANA_X, cy), Vector2(MANA_SIZE, MANA_SIZE), make_style(true), str(i), 13)
		var ml = c.get_child(0) as Label
		ml.position = Vector2.ZERO
		ml.size = Vector2(MANA_SIZE, MANA_SIZE)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	var tw  = SCREEN_W - MANA_COL_W - GAP
	var cw  = floor(tw * 0.14)
	var lw  = tw - cw * 2 - GAP * 2
	var rdw = floor(lw * 0.15)
	var xl  = float(MANA_COL_W);  var xc = xl + lw + GAP;  var xr = xc + cw + GAP
	var inn = bh - PAD * 2;  var re = floor((inn - GAP * 2) / 3.0)
	var y1 = PAD;  var y2 = PAD + re + GAP;  var y3 = PAD + re * 2 + GAP * 2
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
		var zx := float(z[1]);  var zy := float(z[2])
		var zw := float(z[3]);  var zh := float(z[4])
		var fy = by + zy if not flip else by + (bh - zy - zh)
		var p = add_panel(zname.replace(" ", "_"), Vector2(zx, fy), Vector2(zw, zh), make_style(), zname)

		if zname == "RUNES":
			runes_ref = p

		if not flip and zname == "BATTLEFIELD":
			_player_battlefield = p

		if not flip and zname == "CHAMPION LEGEND":
			_player_champion_legend = p
		elif flip and zname == "CHAMPION LEGEND":
			_opponent_champion_legend = p

		if not flip and zname == "MAIN DECK":
			_player_main_deck = p
		elif flip and zname == "MAIN DECK":
			_opponent_main_deck = p

		if not flip and zname == "RUNE DECK":
			_player_rune_deck = p
		elif flip and zname == "RUNE DECK":
			_opponent_rune_deck = p
		if zname == "BASE":
			add_image(p, tint_gold("res://Assets/RiftBoundLogo.jpg"),
				-0.2, -0.5, 1.2, 1.5, 0.0, 0.0, 0.0, 0.0, Color(0.83, 0.68, 0.21, 0.55))

	if runes_ref:
		add_image(runes_ref, tint_gold("res://Assets/runes.jpg"),
			0.05, 0.2, 0.25, 1.0, 6.0, 1.0, 0.0, 0.0)

func render_board(card_instances: Array) -> void:
	var player = get_parent().get_node("GameController").state.get_active_player()

	if player == null:
		return

	var slots = _player_slot_nodes

	# Clear all slot visuals first
	for slot in slots:
		if slot == null:
			continue

		# Remove existing cards from slot
		for child in slot.get_children():
			if child is RiftCard:
				child.queue_free()

	# Now place cards based on board_slots
	for i in range(player.board_slots.size()):
		var card_instance = player.board_slots[i]
		if card_instance == null:
			continue

		if i >= slots.size():
			continue

		var slot = slots[i]
		if slot == null:
			continue

		var card: RiftCard = CARD_SCENE.instantiate()
		slot.add_child(card)

		card.position = Vector2.ZERO
		card.scale = Vector2(0.6, 0.6)

		card.setup_from_instance(card_instance)
		card.set_card_state(RiftCard.CardState.ON_BOARD)

func _clear_board_visuals() -> void:
	for card in _board_cards:
		if is_instance_valid(card):
			card.queue_free()
	_board_cards.clear()

func is_mouse_over_player_battlefield() -> bool:
	if _player_battlefield == null:
		return false

	var mouse_pos = get_global_mouse_position()
	var rect = Rect2(
		_player_battlefield.global_position,
		_player_battlefield.size
	)

	return rect.has_point(mouse_pos)
	
func _clear_panel_images(panel: Panel) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is TextureRect:
			child.queue_free()

func _add_panel_texture(panel: Panel, tex: Texture2D, modulate_color := Color.WHITE) -> void:
	if panel == null or tex == null:
		return

	var tr := TextureRect.new()
	tr.texture = tex
	tr.anchor_left = 0.0
	tr.anchor_top = 0.0
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	tr.offset_left = 4.0
	tr.offset_top = 4.0
	tr.offset_right = -4.0
	tr.offset_bottom = -4.0
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = modulate_color
	panel.add_child(tr)

func render_static_state(player: PlayerState, opponent: PlayerState) -> void:
	var deck_tex: Texture2D = load("res://Assets/Deck.jpg")

	if deck_tex != null:
		_clear_panel_images(_player_main_deck)
		_add_panel_texture(_player_main_deck, deck_tex)

		_clear_panel_images(_player_rune_deck)
		_add_panel_texture(_player_rune_deck, deck_tex)

		_clear_panel_images(_opponent_main_deck)
		_add_panel_texture(_opponent_main_deck, deck_tex)

		_clear_panel_images(_opponent_rune_deck)
		_add_panel_texture(_opponent_rune_deck, deck_tex)

	_render_legend_panel(_player_champion_legend, player.legend)
	_render_legend_panel(_opponent_champion_legend, opponent.legend)

func _render_legend_panel(panel: Panel, legend_instance: CardInstance) -> void:
	if panel == null or legend_instance == null or legend_instance.data == null:
		return

	_clear_panel_images(panel)

	var url := legend_instance.data.image_url
	if url == "":
		if legend_instance.data.texture != null:
			_add_panel_texture(panel, legend_instance.data.texture)
		return

	var card: RiftCard = CARD_SCENE.instantiate()
	panel.add_child(card)
	card.position = panel.size / 2.0
	card.scale = Vector2(0.35, 0.35)
	card.setup_from_instance(legend_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)
