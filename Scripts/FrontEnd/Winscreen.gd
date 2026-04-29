@tool
extends CanvasLayer

# ─── WinScreen.gd ─────────────────────────────────────────────────────────────
# Add this as a CanvasLayer child in your main scene (layer = 10 so it sits
# above Board and all game nodes). Call show_winner(player_id, scores) from
# game_controller after state.game_over is detected.
#
# Usage:
#   var win_screen = $WinScreen
#   win_screen.show_winner(state.winner_id, state.scores)
# ─────────────────────────────────────────────────────────────────────────────

signal rematch_requested
signal quit_requested

const GOLD        = Color(0.83, 0.68, 0.21, 1.0)
const GOLD_DIM    = Color(0.83, 0.68, 0.21, 0.18)
const GOLD_GLOW   = Color(0.95, 0.82, 0.30, 1.0)
const BG_DARK     = Color(0.05, 0.09, 0.18, 0.92)
const WHITE       = Color(1.0, 1.0, 1.0, 1.0)
const WHITE_DIM   = Color(1.0, 1.0, 1.0, 0.55)
const WHITE_FAINT = Color(1.0, 1.0, 1.0, 0.12)

const SCREEN_W    = 1920.0
const SCREEN_H    = 1080.0

var _winner_id:   int = 0
var _scores:      Array = [0, 0]
var _tween:       Tween = null
var _particles:   Array = []

# Nodes we build procedurally
var _overlay:     ColorRect
var _panel:       Panel
var _crown_draw:  Control
var _title_label: Label
var _sub_label:   Label
var _score_label: Label
var _divider:     ColorRect
var _rematch_btn: Button
var _quit_btn:    Button
var _particles_root: Control

func _ready() -> void:
	layer  = 10
	visible = false
	_build_ui()

# ─── Public API ───────────────────────────────────────────────────────────────

func show_winner(winner_id: int, scores: Array) -> void:
	_winner_id = winner_id
	_scores    = scores
	visible    = true
	_update_text()
	_animate_in()
	_spawn_particles()

func hide_screen() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0), 0.35)
	_tween.tween_property(_overlay, "color", Color(BG_DARK.r, BG_DARK.g, BG_DARK.b, 0.0), 0.35)
	_tween.tween_callback(func(): visible = false)

# ─── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dim overlay
	_overlay       = ColorRect.new()
	_overlay.color = Color(BG_DARK.r, BG_DARK.g, BG_DARK.b, 0.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Particle canvas (behind panel)
	_particles_root = Control.new()
	_particles_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particles_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particles_root)

	# Central panel
	var panel_w: float = 680.0
	var panel_h: float = 520.0
	_panel          = Panel.new()
	_panel.size     = Vector2(panel_w, panel_h)
	_panel.position = Vector2((SCREEN_W - panel_w) / 2.0, (SCREEN_H - panel_h) / 2.0)
	_panel.modulate = Color(1, 1, 1, 0)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color           = Color(0.06, 0.12, 0.22, 0.97)
	panel_style.border_color       = GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Corner accent lines (decorative — drawn as thin ColorRects)
	_add_corner_accents(_panel, panel_w, panel_h)

	# Crown drawing node
	_crown_draw          = Control.new()
	_crown_draw.position = Vector2(panel_w / 2.0 - 48.0, 28.0)
	_crown_draw.size     = Vector2(96.0, 72.0)
	_crown_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_crown_draw)
	_crown_draw.draw.connect(_draw_crown.bind(_crown_draw))
	_crown_draw.queue_redraw()

	# Title
	_title_label                        = Label.new()
	_title_label.position               = Vector2(0, 112)
	_title_label.size                   = Vector2(panel_w, 72)
	_title_label.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment     = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", GOLD)
	_panel.add_child(_title_label)

	# Subtitle
	_sub_label                          = Label.new()
	_sub_label.position                 = Vector2(0, 182)
	_sub_label.size                     = Vector2(panel_w, 36)
	_sub_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 20)
	_sub_label.add_theme_color_override("font_color", WHITE_DIM)
	_panel.add_child(_sub_label)

	# Gold divider
	_divider          = ColorRect.new()
	_divider.color    = GOLD_DIM
	_divider.size     = Vector2(panel_w - 80, 1)
	_divider.position = Vector2(40, 232)
	_panel.add_child(_divider)

	# Score display
	_score_label                        = Label.new()
	_score_label.position               = Vector2(0, 250)
	_score_label.size                   = Vector2(panel_w, 100)
	_score_label.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment     = VERTICAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 38)
	_score_label.add_theme_color_override("font_color", WHITE)
	_panel.add_child(_score_label)

	# Point pips row
	_build_point_pips(_panel, panel_w, panel_h)

	# Buttons
	var btn_y: float  = panel_h - 80.0
	var btn_w: float  = 220.0
	var btn_gap: float = 24.0
	var total_btn_w   = btn_w * 2 + btn_gap
	var btn_start_x   = (panel_w - total_btn_w) / 2.0

	_rematch_btn = _make_button("Rematch", btn_start_x, btn_y, btn_w, true)
	_panel.add_child(_rematch_btn)
	_rematch_btn.pressed.connect(_on_rematch_pressed)

	_quit_btn = _make_button("Quit to Menu", btn_start_x + btn_w + btn_gap, btn_y, btn_w, false)
	_panel.add_child(_quit_btn)
	_quit_btn.pressed.connect(_on_quit_pressed)

func _add_corner_accents(parent: Panel, w: float, h: float) -> void:
	var len: float = 28.0
	var thick: float = 2.0
	var corners = [
		[Vector2(0, 0),         Vector2(len, thick),   Vector2(0, 0),         Vector2(thick, len)],
		[Vector2(w - len, 0),   Vector2(len, thick),   Vector2(w - thick, 0), Vector2(thick, len)],
		[Vector2(0, h - thick), Vector2(len, thick),   Vector2(0, h - len),   Vector2(thick, len)],
		[Vector2(w - len, h - thick), Vector2(len, thick), Vector2(w - thick, h - len), Vector2(thick, len)],
	]
	for c in corners:
		var h_bar      = ColorRect.new()
		h_bar.color    = GOLD
		h_bar.position = c[0]
		h_bar.size     = c[1]
		parent.add_child(h_bar)

		var v_bar      = ColorRect.new()
		v_bar.color    = GOLD
		v_bar.position = c[2]
		v_bar.size     = c[3]
		parent.add_child(v_bar)

func _build_point_pips(parent: Panel, panel_w: float, panel_h: float) -> void:
	# 8 small pip circles showing both players' scores
	var pip_y_p0: float = 358.0
	var pip_y_p1: float = 398.0
	var pip_r: float    = 8.0
	var pip_gap: float  = 22.0
	var total_pip_w: float = 8 * pip_gap - (pip_gap - pip_r * 2)
	var pip_start_x: float = (panel_w - total_pip_w) / 2.0 + pip_r

	for i in range(8):
		var px = pip_start_x + i * pip_gap

		# P0 pip row label (leftmost pip only)
		if i == 0:
			var lbl_p0       = Label.new()
			lbl_p0.text      = "P1"
			lbl_p0.position  = Vector2(pip_start_x - 52, pip_y_p0 - pip_r - 2)
			lbl_p0.add_theme_font_size_override("font_size", 13)
			lbl_p0.add_theme_color_override("font_color", WHITE_DIM)
			parent.add_child(lbl_p0)

			var lbl_p1       = Label.new()
			lbl_p1.text      = "P2"
			lbl_p1.position  = Vector2(pip_start_x - 52, pip_y_p1 - pip_r - 2)
			lbl_p1.add_theme_font_size_override("font_size", 13)
			lbl_p1.add_theme_color_override("font_color", WHITE_DIM)
			parent.add_child(lbl_p1)

		# Draw pips as small Panels with rounded style
		for row in range(2):
			var pip_y = pip_y_p0 if row == 0 else pip_y_p1
			var pip   = Panel.new()
			pip.size     = Vector2(pip_r * 2, pip_r * 2)
			pip.position = Vector2(px - pip_r, pip_y - pip_r)
			pip.name     = "Pip_P%d_%d" % [row, i]

			var sty      = StyleBoxFlat.new()
			sty.set_corner_radius_all(pip_r as int)
			sty.bg_color     = GOLD if i < _scores[row] else WHITE_FAINT
			sty.border_color = GOLD if i < _scores[row] else Color(1, 1, 1, 0.25)
			sty.set_border_width_all(1)
			pip.add_theme_stylebox_override("panel", sty)
			parent.add_child(pip)

func _make_button(label: String, x: float, y: float, w: float, primary: bool) -> Button:
	var btn       = Button.new()
	btn.text      = label
	btn.position  = Vector2(x, y)
	btn.size      = Vector2(w, 48)
	btn.add_theme_font_size_override("font_size", 17)

	var normal_sty        = StyleBoxFlat.new()
	normal_sty.bg_color   = GOLD if primary else Color(0, 0, 0, 0)
	normal_sty.border_color = GOLD
	normal_sty.set_border_width_all(2)
	normal_sty.set_corner_radius_all(4)

	var hover_sty         = StyleBoxFlat.new()
	hover_sty.bg_color    = GOLD_GLOW if primary else Color(1, 1, 1, 0.08)
	hover_sty.border_color = GOLD_GLOW
	hover_sty.set_border_width_all(2)
	hover_sty.set_corner_radius_all(4)

	var pressed_sty        = StyleBoxFlat.new()
	pressed_sty.bg_color   = Color(0.6, 0.48, 0.12, 1.0) if primary else Color(1, 1, 1, 0.04)
	pressed_sty.border_color = GOLD
	pressed_sty.set_border_width_all(2)
	pressed_sty.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal",  normal_sty)
	btn.add_theme_stylebox_override("hover",   hover_sty)
	btn.add_theme_stylebox_override("pressed", pressed_sty)
	btn.add_theme_stylebox_override("focus",   normal_sty.duplicate())

	var font_color = Color(0.08, 0.06, 0.01, 1.0) if primary else GOLD
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_hover_color",   font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)

	return btn

# ─── Crown drawing ────────────────────────────────────────────────────────────

func _draw_crown(node: Control) -> void:
	# Simple geometric crown drawn with polygons — no textures needed
	var w: float = node.size.x
	var h: float = node.size.y
	var col      = GOLD

	# Crown base band
	var band_h: float = h * 0.28
	var band_y: float = h - band_h
	node.draw_rect(Rect2(0, band_y, w, band_h), col)

	# Three crown points
	var points_top = PackedVector2Array([
		Vector2(0,       band_y),
		Vector2(0,       h * 0.10),
		Vector2(w * 0.22, band_y),
		Vector2(w * 0.50, 0),
		Vector2(w * 0.78, band_y),
		Vector2(w,       h * 0.10),
		Vector2(w,       band_y),
	])
	node.draw_colored_polygon(points_top, col)

	# Gem circles on each point
	var gem_col = Color(0.95, 0.90, 0.55, 1.0)
	node.draw_circle(Vector2(w * 0.50, h * 0.06), 5.0, gem_col)
	node.draw_circle(Vector2(w * 0.08, h * 0.17), 4.0, gem_col)
	node.draw_circle(Vector2(w * 0.92, h * 0.17), 4.0, gem_col)

# ─── Text update ──────────────────────────────────────────────────────────────

func _update_text() -> void:
	var winner_num = _winner_id + 1
	_title_label.text = "Player %d Wins" % winner_num
	_sub_label.text   = "Victory claimed — well played."
	_score_label.text = "%d  —  %d" % [_scores[0], _scores[1]]

# ─── Animation ────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	if _tween:
		_tween.kill()

	# Start panel offscreen slightly below and transparent
	_panel.position.y += 40
	_panel.modulate    = Color(1, 1, 1, 0)
	_overlay.color     = Color(BG_DARK.r, BG_DARK.g, BG_DARK.b, 0.0)

	_tween = create_tween()
	_tween.set_parallel(true)

	# Fade in overlay
	_tween.tween_property(_overlay, "color",
		Color(BG_DARK.r, BG_DARK.g, BG_DARK.b, BG_DARK.a), 0.45
	).set_trans(Tween.TRANS_CUBIC)

	# Slide + fade in panel
	var target_y = (SCREEN_H - _panel.size.y) / 2.0
	_tween.tween_property(_panel, "position:y", target_y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate",   Color(1, 1, 1, 1), 0.35).set_trans(Tween.TRANS_CUBIC)

	# Pulse the title gold after panel settles
	_tween.chain().tween_property(
		_title_label, "modulate", Color(1.15, 1.05, 0.6, 1.0), 0.3
	).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_property(
		_title_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3
	).set_trans(Tween.TRANS_SINE)

# ─── Particles ────────────────────────────────────────────────────────────────

func _spawn_particles() -> void:
	# Clear old particles
	for p in _particles:
		if is_instance_valid(p):
			p.queue_free()
	_particles.clear()

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for _i in range(38):
		var p = _make_particle(rng)
		_particles_root.add_child(p)
		_particles.append(p)
		_animate_particle(p, rng)

func _make_particle(rng: RandomNumberGenerator) -> ColorRect:
	var p      = ColorRect.new()
	var sz     = rng.randf_range(3.0, 9.0)
	p.size     = Vector2(sz, sz)
	p.color    = GOLD if rng.randf() > 0.35 else Color(1, 1, 1, 0.7)
	p.position = Vector2(rng.randf_range(0, SCREEN_W), SCREEN_H + 20)
	p.modulate = Color(1, 1, 1, 0)
	return p

func _animate_particle(p: ColorRect, rng: RandomNumberGenerator) -> void:
	var target_y   = rng.randf_range(SCREEN_H * 0.05, SCREEN_H * 0.85)
	var target_x   = p.position.x + rng.randf_range(-120, 120)
	var duration   = rng.randf_range(1.2, 2.6)
	var delay      = rng.randf_range(0.0, 0.9)

	var t = create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(p, "position", Vector2(target_x, target_y), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate", Color(1, 1, 1, 0.85), duration * 0.4).set_trans(Tween.TRANS_CUBIC)
	t.chain().tween_property(p, "modulate", Color(1, 1, 1, 0.0), duration * 0.5).set_trans(Tween.TRANS_CUBIC)

# ─── Button handlers ──────────────────────────────────────────────────────────

func _on_rematch_pressed() -> void:
	hide_screen()
	rematch_requested.emit()

func _on_quit_pressed() -> void:
	hide_screen()
	quit_requested.emit()
