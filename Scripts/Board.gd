extends Control

@onready var game_controller: Node = $"../GameController"

const SCREEN_W = 1920.0
const SCREEN_H = 1080.0
const COLOR_BG     = Color("#0d1b35")
const COLOR_BORDER = Color(0.83, 0.68, 0.21, 0.95)
const COLOR_DIV    = Color(1, 1, 1, 0.20)
const COLOR_HAND   = Color(1, 1, 1, 0.05)
const BORDER_W = 2
const GAP = 6
const FONT_SIZE = 11
const MANA_X = 8
const MANA_SIZE = 38
const MANA_COL_W = 52
const HAND_H = 130
const DIVIDER_H = 4
const ARENA_H = 200

const CARD_SCENE      = preload("res://Scenes/Card.tscn")
const CARD_SLOT_SCENE = preload("res://Scenes/CardSlot.tscn")
const NORMAL_SCALE = Vector2(0.4, 0.4)

var _player_battlefield_panel: Panel = null
var _opponent_battlefield_panel: Panel = null
var _player_base_panel: Panel = null
var _opponent_base_panel: Panel = null

var _board_cards: Array = []
var _battlefield_cards_visuals: Array = []
var _hand_panel: Panel = null
var _player_slot_nodes: Array = []
var _p1_slot_nodes: Array = []

# Battlefield halves
var _p0_battlefield_left: Panel = null
var _p0_battlefield_right: Panel = null
var _p1_battlefield_left: Panel = null
var _p1_battlefield_right: Panel = null

# One CardSlot per battlefield half
var _p0_bf_slot_left: CardSlot = null
var _p0_bf_slot_right: CardSlot = null
var _p1_bf_slot_left: CardSlot = null
var _p1_bf_slot_right: CardSlot = null

var _player_champion_legend: Panel = null
var _opponent_champion_legend: Panel = null
var _player_main_deck: Panel = null
var _player_rune_deck: Panel = null
var _opponent_main_deck: Panel = null
var _opponent_rune_deck: Panel = null

var _player_runes_panel: Panel = null
var _opponent_runes_panel: Panel = null
var _rune_cards_visuals: Array = []

const END_BTN_W = 160.0
var _arena_p0_panel: Panel = null
var _arena_p1_panel: Panel = null

func _ready() -> void:
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)

	var ph = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0, true, ph)
	add_rect(Vector2(0, ph), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)

	var half_w = (SCREEN_W - END_BTN_W) / 2.0
	var arena_y = ph + DIVIDER_H

	_arena_p0_panel = add_panel(
		"Arena_P0",
		Vector2(0, arena_y),
		Vector2(half_w, ARENA_H),
		make_style(),
		"Arena 1",
		18
	)
	add_rect(Vector2(half_w, arena_y), Vector2(DIVIDER_H, ARENA_H), COLOR_DIV)
	_arena_p1_panel = add_panel(
		"Arena_P1",
		Vector2(half_w + DIVIDER_H, arena_y),
		Vector2(half_w - DIVIDER_H, ARENA_H),
		make_style(),
		"Arena 2",
		18
	)
	add_rect(Vector2(SCREEN_W - END_BTN_W, arena_y), Vector2(1, ARENA_H), COLOR_DIV)

	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H, false, ph)

	_cache_player_slots()
	_setup_battlefield_halves()
	_spawn_battlefield_slots()

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
	_p0_battlefield_left = _create_battlefield_half(_player_battlefield_panel, "P0_LeftHalf", 0)
	_p0_battlefield_right = _create_battlefield_half(_player_battlefield_panel, "P0_RightHalf", 1)

	_p1_battlefield_left = _create_battlefield_half(_opponent_battlefield_panel, "P1_LeftHalf", 0)
	_p1_battlefield_right = _create_battlefield_half(_opponent_battlefield_panel, "P1_RightHalf", 1)

func _create_battlefield_half(parent_panel: Panel, half_name: String, half_index: int) -> Panel:
	if parent_panel == null:
		return null

	var existing = parent_panel.get_node_or_null(half_name)
	if existing and existing is Panel:
		return existing

	var half_gap = 8.0
	var half_w = (parent_panel.size.x - half_gap) / 2.0

	var panel = Panel.new()
	panel.name = half_name
	panel.position = Vector2(0, 0) if half_index == 0 else Vector2(half_w + half_gap, 0)
	panel.size = Vector2(half_w, parent_panel.size.y)
	panel.add_theme_stylebox_override("panel", make_style())
	parent_panel.add_child(panel)

	return panel

func _spawn_battlefield_slots() -> void:
	_p1_bf_slot_left = _create_battlefield_slot(_p1_battlefield_left, "P1_Left")
	_p1_bf_slot_right = _create_battlefield_slot(_p1_battlefield_right, "P1_Right")

	_p0_bf_slot_left = _create_battlefield_slot(_p0_battlefield_left, "P0_Left")
	_p0_bf_slot_right = _create_battlefield_slot(_p0_battlefield_right, "P0_Right")

func _create_battlefield_slot(panel: Panel, slot_name: String) -> CardSlot:
	if panel == null:
		return null

	var existing = panel.get_node_or_null(slot_name)
	if existing and existing is CardSlot:
		return existing

	var slot: CardSlot = CARD_SLOT_SCENE.instantiate()
	slot.name = slot_name
	panel.add_child(slot)

	var usable_h = panel.size.y - 30.0
	var y_offset = 12.0
	slot.position = Vector2(panel.size.x / 2.0, usable_h / 2.0 + y_offset)

	var area = slot.get_node_or_null("Area2D")
	if area:
		area.collision_layer = 4
		area.collision_mask = 4

		var shape_node = area.get_node_or_null("CollisionShape2D")
		if shape_node and shape_node.shape is RectangleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.size = Vector2(panel.size.x - 16.0, usable_h)

	return slot

func get_slot_index_under_mouse() -> int:
	var active_id: int = get_parent().get_node("GameController").state.get_active_player().id
	var slots = _player_slot_nodes if active_id == 0 else _p1_slot_nodes
	var mouse_pos = get_global_mouse_position()

	for i in range(slots.size()):
		var slot = slots[i]
		if slot == null:
			continue
		var local_mouse: Vector2 = slot.to_local(mouse_pos)
		var half: Vector2 = slot._get_collision_size() / 2.0
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
		var half = slot._get_collision_size() / 2.0
		if abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y:
			return entry

	return {}

func get_all_battlefield_slots() -> Array:
	return [
		_p0_bf_slot_left,
		_p0_bf_slot_right,
		_p1_bf_slot_left,
		_p1_bf_slot_right
	]

func add_rect(pos: Vector2, size: Vector2, color: Color, parent: Node = self) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	parent.add_child(r)

func make_style(rounded := false, fill := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = COLOR_BORDER
	s.set_border_width_all(BORDER_W)
	if rounded:
		s.set_corner_radius_all(int(MANA_SIZE / 2))
	return s

func add_panel(
		pname: String,
		pos: Vector2,
		size: Vector2,
		style := make_style(),
		label_text := pname,
		font_size := FONT_SIZE,
		parent: Node = self
	) -> Panel:
	var p = Panel.new()
	p.name = pname
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)

	var l = Label.new()
	l.text = label_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size = Vector2(size.x - 8, 40)
	l.position = Vector2(6, size.y - 30)
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
		panel: Panel,
		tex: ImageTexture,
		al: float,
		at: float,
		ar: float,
		ab: float,
		ol := 0.0,
		ot := 0.0,
		orr := 0.0,
		ob := 0.0,
		mod := Color.WHITE
	) -> void:
	var tr = TextureRect.new()
	tr.texture = tex
	tr.anchor_left = al
	tr.anchor_top = at
	tr.anchor_right = ar
	tr.anchor_bottom = ab
	tr.offset_left = ol
	tr.offset_top = ot
	tr.offset_right = orr
	tr.offset_bottom = ob
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = mod
	panel.add_child(tr)

func build_player(y: float, flip: bool, ph: float) -> void:
	var PAD = 8.0
	var bh = ph - HAND_H
	var by = y + HAND_H if flip else y
	var hy = y if flip else y + bh

	var hand_panel = add_panel(
		"Hand",
		Vector2(0, hy),
		Vector2(SCREEN_W, HAND_H),
		make_style(false, COLOR_HAND)
	)

	if not flip:
		_hand_panel = hand_panel

	var rh = bh / 8.0
	for i in range(1, 9):
		var cy = by + ((i - 1) if flip else (8 - i)) * rh + (rh - MANA_SIZE) / 2.0
		var c = add_panel(
			"Mana%d" % i,
			Vector2(MANA_X, cy),
			Vector2(MANA_SIZE, MANA_SIZE),
			make_style(true),
			str(i),
			13
		)
		var ml = c.get_child(0) as Label
		ml.position = Vector2.ZERO
		ml.size = Vector2(MANA_SIZE, MANA_SIZE)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var tw = SCREEN_W - MANA_COL_W - GAP
	var cw = floor(tw * 0.14)
	var lw = tw - cw * 2 - GAP * 2
	var rdw = floor(lw * 0.15)
	var xl = float(MANA_COL_W)
	var xc = xl + lw + GAP
	var xr = xc + cw + GAP
	var inn = bh - PAD * 2
	var re = floor((inn - GAP * 2) / 3.0)
	var y1 = PAD
	var y2 = PAD + re + GAP
	var y3 = PAD + re * 2 + GAP * 2
	var rb = inn - re * 2 - GAP * 2

	var zones = [
		["BATTLEFIELD",     xl,         y1, lw,                 re],
		["CHAMPION LEGEND", xc,         y1, cw,                 re],
		["CHOSEN CHAMPION", xr,         y1, cw,                 re],
		["BASE",            xl,         y2, lw + cw + GAP,      re],
		["MAIN DECK",       xr,         y2, cw,                 re],
		["RUNE DECK",       xl,         y3, rdw,                rb],
		["RUNES",           xl+rdw+GAP, y3, lw-rdw-GAP+cw+GAP,  rb],
		["TRASH",           xr,         y3, cw,                 rb],
	]

	var runes_ref: Panel = null
	for z in zones:
		var zname := z[0] as String
		var zx := float(z[1])
		var zy := float(z[2])
		var zw := float(z[3])
		var zh := float(z[4])
		var fy = by + zy if not flip else by + (bh - zy - zh)

		var p = add_panel(
			zname.replace(" ", "_"),
			Vector2(zx, fy),
			Vector2(zw, zh),
			make_style(),
			zname
		)

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
			add_image(
				p,
				tint_gold("res://Assets/RiftBoundLogo.jpg"),
				-0.2, -0.5, 1.2, 1.5,
				0.0, 0.0, 0.0, 0.0,
				Color(0.83, 0.68, 0.21, 0.55)
			)

	if runes_ref:
		add_image(
			runes_ref,
			tint_gold("res://Assets/runes.jpg"),
			0.05, 0.2, 0.25, 1.0,
			6.0, 1.0, 0.0, 0.0
		)

func render_board() -> void:
	var state = get_parent().get_node("GameController").state

	_render_player_slots(state.players[0], _player_slot_nodes)
	_render_player_slots(state.players[1], _p1_slot_nodes)

	_render_battlefield_lane(state.players[1].battlefield_slots[0], _p1_bf_slot_left)
	_render_battlefield_lane(state.players[1].battlefield_slots[1], _p1_bf_slot_right)

	_render_battlefield_lane(state.players[0].battlefield_slots[0], _p0_bf_slot_left)
	_render_battlefield_lane(state.players[0].battlefield_slots[1], _p0_bf_slot_right)

func _render_player_slots(player: PlayerState, slots: Array) -> void:
	if player == null:
		return

	for slot in slots:
		if slot != null:
			slot.clear_cards()

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
			card.rotation_degrees = 90.0 if card_instance.is_exhausted() else 0.0

func _render_battlefield_lane(cards: Array, slot: CardSlot) -> void:
	if slot == null:
		return

	slot.clear_cards()

	for card_instance in cards:
		var card: RiftCard = CARD_SCENE.instantiate()
		card.scale = Vector2(0.35, 0.35)
		card.z_index = 5
		slot.add_card(card)
		card.setup_from_card_instance(card_instance)
		card.set_card_state(RiftCard.CardState.ON_BOARD)
		card.rotation_degrees = 90.0 if card_instance.is_exhausted() else 0.0

func render_slot(player: PlayerState, slot_index: int) -> void:
	var slots = _player_slot_nodes if player.id == 0 else _p1_slot_nodes
	if slot_index >= slots.size():
		return

	var slot = slots[slot_index]
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
		card.rotation_degrees = 90.0 if card_instance.is_exhausted() else 0.0

func render_arena_slot(player: PlayerState) -> void:
	if player.id == 1:
		_render_battlefield_lane(player.battlefield_slots[0], _p1_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], _p1_bf_slot_right)
	else:
		_render_battlefield_lane(player.battlefield_slots[0], _p0_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], _p0_bf_slot_right)

func _clear_board_visuals() -> void:
	for card in _board_cards:
		if is_instance_valid(card):
			card.queue_free()
	_board_cards.clear()

func is_mouse_over_player_battlefield() -> bool:
	if _player_battlefield_panel == null:
		return false
	var mouse_pos = get_global_mouse_position()
	var rect = Rect2(_player_battlefield_panel.global_position, _player_battlefield_panel.size)
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

	var tr = TextureRect.new()
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

	_render_battlefields(_player_battlefield_panel, player.battlefields, player.picked_battlefield)
	_render_battlefields(_opponent_battlefield_panel, opponent.battlefields, opponent.picked_battlefield)

	_render_arena_pick(_arena_p0_panel, player.picked_battlefield, "Arena 1")
	_render_arena_pick(_arena_p1_panel, opponent.picked_battlefield, "Arena 2")

	_render_runes(_player_runes_panel, player.rune_pool, player.id)
	_render_runes(_opponent_runes_panel, opponent.rune_pool, opponent.id)

func _render_legend_panel(panel: Panel, legend_instance: CardInstance) -> void:
	if panel == null or legend_instance == null or legend_instance.data == null:
		return

	_clear_panel_images(panel)
	var url = legend_instance.data.image_url
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

func _render_arena_pick(panel: Panel, pick: BattlefieldInstance, player_label: String) -> void:
	if panel == null or pick == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

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

func _render_runes(panel: Panel, runes: Array, player_id: int) -> void:
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

	var gs: GameState = game_controller.state as GameState
	var active_player_id: int = gs.get_active_player().id
	var is_current_player_panel: bool = (player_id == active_player_id)

	for i in range(count):
		var rune_inst: RuneInstance = runes[i]
		if rune_inst == null or rune_inst.rune == null:
			continue

		var card: RiftCard = CARD_SCENE.instantiate()
		panel.add_child(card)
		card.position = Vector2(start_x + i * spacing, panel.size.y / 2.0)
		card.scale = Vector2(0.35, 0.35)
		card.z_index = 5
		card.card_uid = rune_inst.uid
		card.card_data = rune_inst.rune
		card.update_visuals()

		var is_exhausted: bool = rune_inst.is_exhausted()
		var is_selected: bool = is_current_player_panel and gs.selected_rune_uids.has(rune_inst.uid)
		var can_select: bool = is_current_player_panel and gs.awaiting_rune_payment and (not is_exhausted) and (not is_selected)

		card.rotation_degrees = 90.0 if is_exhausted else 0.0

		if is_exhausted:
			card.modulate = Color(0.7, 0.7, 0.7, 1.0)
		elif is_selected:
			card.modulate = Color(0.6, 1.0, 0.6, 1.0)
		elif can_select:
			card.modulate = Color(1.15, 1.15, 0.75, 1.0)
		else:
			card.modulate = Color.WHITE

		card.set_card_state(RiftCard.CardState.ON_BOARD)
		_rune_cards_visuals.append(card)
		
func render_rune_panels(p0: PlayerState, p1: PlayerState) -> void:
	_render_runes(_player_runes_panel, p0.rune_pool, p0.id)
	_render_runes(_opponent_runes_panel, p1.rune_pool, p1.id)
