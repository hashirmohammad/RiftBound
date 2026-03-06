extends Control
## Board — Draws all UI zones procedurally and wires HandManager into the
## player's Hand panel so cards are laid out inside the board automatically.
##
## CHANGE: Board now calls _setup_hand_manager() after building the layout,
## which finds the Hand panel and adds HandManager as a sized child.
## This means you do NOT need a separate HandManager node in the scene root —
## Board creates and positions it for you.
##
## Other nodes that need a HandManager reference (Deck, CardManager) should
## use $HandManager on the scene root OR rely on the autoload approach.
## The simplest wiring: keep HandManager as a sibling node in the scene
## and let Board just size/anchor it to the hand panel's rect.

const SCREEN_W = 1920.0;  const SCREEN_H = 1080.0
const COLOR_BG     = Color("#0d1b35")
const COLOR_BORDER = Color(0.83, 0.68, 0.21, 0.95)
const COLOR_DIV    = Color(1, 1, 1, 0.20)
const COLOR_HAND   = Color(1, 1, 1, 0.05)
const BORDER_W = 2;  const GAP = 6;  const FONT_SIZE = 11
const MANA_X = 8;   const MANA_SIZE = 38;  const MANA_COL_W = 52
const HAND_H = 130; const DIVIDER_H = 4;   const ARENA_H = 200

## Keeps a reference to the player's Hand panel so we can anchor HandManager
var _hand_panel: Panel = null

func _ready() -> void:
	add_rect(Vector2.ZERO, Vector2(SCREEN_W, SCREEN_H), COLOR_BG)
	var ph = floor((SCREEN_H - DIVIDER_H * 2 - ARENA_H) / 2.0)
	build_player(0.0,                              true,  ph)
	add_rect(Vector2(0, ph),                       Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	add_panel("Arena", Vector2(0, ph + DIVIDER_H), Vector2(SCREEN_W, ARENA_H), make_style(), "ARENA", 18)
	add_rect(Vector2(0, ph + DIVIDER_H + ARENA_H), Vector2(SCREEN_W, DIVIDER_H), COLOR_DIV)
	build_player(ph + DIVIDER_H * 2 + ARENA_H,    false, ph)
	_anchor_hand_manager()

## After the board is built, find the sibling HandManager and fit it inside
## the Hand panel that build_player() created for the local player (flip=false).
func _anchor_hand_manager() -> void:
	if _hand_panel == null:
		return
	var hm: HandManager = get_parent().get_node_or_null("HandManager")
	if hm == null:
		push_warning("Board: No HandManager sibling found. Add one to the scene root.")
		return
	# Re-parent HandManager into the Hand panel so it sits inside the board zone
	_hand_panel.add_child(hm)
	hm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Give some padding so cards don't hug the panel edge
	hm.add_theme_constant_override("separation", 12)
	hm.alignment = BoxContainer.ALIGNMENT_CENTER

func add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var r = ColorRect.new()
	r.position = pos;  r.size = size;  r.color = color
	add_child(r)

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

	## Store a reference to the LOCAL player's hand panel (flip == false)
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
		var p = add_panel(zname.replace(" ", "_"), Vector2(zx, fy), Vector2(zw, zh))
		if zname == "RUNES": runes_ref = p
		if zname == "BASE":
			add_image(p, tint_gold("res://Assets/RiftBoundLogo.jpg"),
				-0.2, -0.5, 1.2, 1.5, 0.0, 0.0, 0.0, 0.0, Color(0.83, 0.68, 0.21, 0.55))

	if runes_ref:
		add_image(runes_ref, tint_gold("res://Assets/runes.jpg"),
			0.05, 0.2, 0.25, 1.0, 6.0, 1.0, 0.0, 0.0)
