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

var _player_battlefield_panel: Panel = null
var _opponent_battlefield_panel: Panel = null
var _player_base_panel: Panel = null
var _opponent_base_panel: Panel = null

var _board_cards: Array = []
var _battlefield_cards_visuals: Array = []
var _hand_panel: Panel = null
var _player_slot_nodes: Array = []

var _player_champion_legend: Panel = null
var _opponent_champion_legend: Panel = null
var _player_main_deck: Panel = null
var _player_rune_deck: Panel = null
var _opponent_main_deck: Panel = null
var _opponent_rune_deck: Panel = null

var _player_runes_panel: Panel = null
var _opponent_runes_panel: Panel = null
var _rune_cards_visuals: Array = []

const END_BTN_W := 160.0
var _arena_p0_panel: Panel = null
var _arena_p1_panel: Panel = null

func _ready() -> void:
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)
	var ph = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0, true, ph)
	add_rect(Vector2(0, ph), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)

	# --- Arena split ---
	var half_w = (SCREEN_W - END_BTN_W) / 2.0
	var arena_y = ph + DIVIDER_H

	# Labels start as P0 left, P1 right — they update dynamically each render
	_arena_p0_panel = add_panel("Arena_P0", Vector2(0, arena_y),
		Vector2(half_w, ARENA_H), make_style(), "P0 ARENA", 18)
	add_rect(Vector2(half_w, arena_y), Vector2(DIVIDER_H, ARENA_H), COLOR_DIV)
	_arena_p1_panel = add_panel("Arena_P1", Vector2(half_w + DIVIDER_H, arena_y),
		Vector2(half_w - DIVIDER_H, ARENA_H), make_style(), "P1 ARENA", 18)
	add_rect(Vector2(SCREEN_W - END_BTN_W, arena_y), Vector2(1, ARENA_H), COLOR_DIV)

	# --- End divider + bottom half ---
	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H, false, ph)

	_cache_player_slots()

func _cache_player_slots() -> void:
	_player_slot_nodes.clear()

	var slots_root = get_node_or_null("../CardSlots")
	if slots_root == null:
		push_warning("Board.gd: CardSlots node not found.")
		return

	if _player_base_panel == null:
		push_warning("Board.gd: _player_base_panel is null.")
		return

	var base_rect = Rect2(
		_player_base_panel.global_position,
		_player_base_panel.size
	)

	var base_center_y: float = base_rect.position.y + (base_rect.size.y / 2.0)
	var row_tolerance: float = 60.0

	for child in slots_root.get_children():
		if child is CardSlot:
			if child.name.begins_with("Enemy"):
				continue

			var pos: Vector2 = child.global_position
			var in_row: bool = abs(pos.y - base_center_y) <= row_tolerance
			var in_x_range: bool = pos.x >= base_rect.position.x and pos.x <= (base_rect.position.x + base_rect.size.x)

			if in_row and in_x_range:
				_player_slot_nodes.append(child)

	_player_slot_nodes.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)

	print("Cached base slots: ", _player_slot_nodes.size())
	for i in range(_player_slot_nodes.size()):
		print("slot ", i, " -> ", _player_slot_nodes[i].global_position)

func get_slot_index_under_mouse() -> int:
	var mouse_pos = get_global_mouse_position()

	for i in range(_player_slot_nodes.size()):
		var slot = _player_slot_nodes[i]
		if slot == null:
			continue

		var local_mouse: Vector2 = slot.to_local(mouse_pos)
		var half: Vector2 = slot._get_collision_size() / 2.0
		if abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y:
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
			_player_battlefield_panel = p
		elif flip and zname == "BATTLEFIELD":
			_opponent_battlefield_panel = p

		if not flip and zname == "BASE":
			_player_base_panel = p
		elif flip and zname == "BASE":
			_opponent_base_panel = p

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

		if not flip and zname == "RUNES":
			_player_runes_panel = p
		elif flip and zname == "RUNES":
			_opponent_runes_panel = p

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
		slot.clear_cards()

	# Now place cards based on board_slots
	for i in range(player.board_slots.size()):
		if i >= slots.size():
			continue

		var slot = slots[i]
		if slot == null:
			continue

		for card_instance in player.board_slots[i]:
			var card: RiftCard = CARD_SCENE.instantiate()
			card.scale = Vector2(0.8, 0.8)
			card.z_index = 5
			slot.add_card(card)
			card.setup_from_card_instance(card_instance)
			card.set_card_state(RiftCard.CardState.ON_BOARD)
			if card_instance.is_exhausted():
				card.rotation_degrees = 90.0
			else:
				card.rotation_degrees = 0.0

func render_slot(player: PlayerState, slot_index: int) -> void:
	if slot_index >= _player_slot_nodes.size():
		return
	var slot = _player_slot_nodes[slot_index]
	if slot == null:
		return
	slot.clear_cards()
	for card_instance in player.board_slots[slot_index]:
		var card: RiftCard = CARD_SCENE.instantiate()
		card.scale = Vector2(0.8, 0.8)
		card.z_index = 5
		slot.add_card(card)
		card.setup_from_card_instance(card_instance)
		card.set_card_state(RiftCard.CardState.ON_BOARD)
		if card_instance.is_exhausted():
			card.rotation_degrees = 90.0
		else:
			card.rotation_degrees = 0.0

func _clear_board_visuals() -> void:
	for card in _board_cards:
		if is_instance_valid(card):
			card.queue_free()
	_board_cards.clear()

func is_mouse_over_player_battlefield() -> bool:
	if _player_battlefield_panel == null:
		return false

	var mouse_pos = get_global_mouse_position()
	var rect = Rect2(
		_player_battlefield_panel.global_position,
		_player_battlefield_panel.size
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

# player is always the active player, opponent is always the other.
# GameController passes state.players[0] as player on P0's turn and
# state.players[1] as player on P1's turn, so the labels follow the cards.
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

	_render_battlefields(_player_battlefield_panel, player.battlefields, player.picked_battlefield)
	_render_battlefields(_opponent_battlefield_panel, opponent.battlefields, opponent.picked_battlefield)

	# Pass the correct player label so it travels with the card each turn
	_render_arena_pick(_arena_p0_panel, player.picked_battlefield, "P%d ARENA" % player.id)
	_render_arena_pick(_arena_p1_panel, opponent.picked_battlefield, "P%d ARENA" % opponent.id)

	_render_runes(_player_runes_panel, player.rune_pool)
	_render_runes(_opponent_runes_panel, opponent.rune_pool)

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
	card.setup_from_card_instance(legend_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)

func _clear_battlefield_visuals() -> void:
	for card in _battlefield_cards_visuals:
		if is_instance_valid(card):
			card.queue_free()
	_battlefield_cards_visuals.clear()

func _render_battlefields(panel: Panel, battlefield_instances: Array, pick: BattlefieldInstance) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	# If a pick has been made, battlefield panel stays empty
	if pick != null:
		return

	if battlefield_instances.is_empty():
		return

	var count: int = battlefield_instances.size()
	var spacing: float = 170.0
	var total_width: float = float(count - 1) * spacing
	var start_x: float = (panel.size.x / 2.0) - (total_width / 2.0)

	for i in range(count):
		var inst: BattlefieldInstance = battlefield_instances[i]
		if inst == null:
			continue
		var card: RiftCard = CARD_SCENE.instantiate()
		panel.add_child(card)
		card.position = Vector2(start_x + i * spacing, panel.size.y / 2.0)
		card.scale = Vector2(0.8, 0.8)
		card.z_index = 5
		card.setup_from_battlefield_instance(inst)
		card.set_card_state(RiftCard.CardState.ON_BOARD)
		_battlefield_cards_visuals.append(card)

# Render a picked battlefield card centred in its arena panel.
# player_label is passed in so the label always matches whichever
# player's card is currently shown in this panel.
func _render_arena_pick(panel: Panel, pick: BattlefieldInstance, player_label: String) -> void:
	if panel == null or pick == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	# Update the panel label to follow the card
	var label = panel.get_child(0) as Label
	if label:
		label.text = player_label

	var card: RiftCard = CARD_SCENE.instantiate()
	panel.add_child(card)
	card.position = panel.size / 2.0
	card.scale = Vector2(0.8, 0.8)
	card.z_index = 5
	card.setup_from_battlefield_instance(pick)
	card.set_card_state(RiftCard.CardState.ON_BOARD)
	_battlefield_cards_visuals.append(card)

func _clear_rune_visuals() -> void:
	for card in _rune_cards_visuals:
		if is_instance_valid(card):
			card.queue_free()
	_rune_cards_visuals.clear()

func _render_runes(panel: Panel, runes: Array) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	if runes.is_empty():
		return

	var count: int = runes.size()
	var spacing: float = 120.0
	var total_width: float = float(count - 1) * spacing
	var start_x: float = (panel.size.x / 2.0) - (total_width / 2.0)

	for i in range(count):
		var rune_inst = runes[i]
		if rune_inst == null:
			continue
		if rune_inst.rune == null:
			continue

		var card: RiftCard = CARD_SCENE.instantiate()
		panel.add_child(card)

		card.position = Vector2(start_x + i * spacing, panel.size.y / 2.0)
		card.scale = Vector2(0.35, 0.35)
		card.z_index = 5

		card.card_uid = rune_inst.uid
		card.card_data = rune_inst.rune
		card.update_visuals()
		card.set_card_state(RiftCard.CardState.ON_BOARD)

		if rune_inst.is_exhausted():
			card.modulate = Color(0.7, 0.7, 0.7, 1.0)
		else:
			card.modulate = Color.WHITE

		_rune_cards_visuals.append(card)
