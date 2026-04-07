extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const DEFAULT_SCALE = Vector2(0.4, 0.4)
const HOVER_SCALE = Vector2(0.45, 0.45)
const BOARD_SCALE = Vector2(0.35, 0.35)

var game_controller = null
var screen_size = Vector2()
var is_hovering_on_card = false
var hand_manager = null
var played_card_this_turn = false
var drag_offset = Vector2.ZERO
var all_slots = []
var dragged_card = null
var board_reference = null

func _ready():
	screen_size = get_viewport_rect().size
	hand_manager = $"../P0/P0_Hand"
	game_controller = $"../GameController"
	board_reference = $"../Board"

func _process(_delta):
	if dragged_card:
		var mp = get_global_mouse_position()
		dragged_card.global_position = Vector2(
			clamp(mp.x - drag_offset.x, 0, screen_size.x),
			clamp(mp.y - drag_offset.y, 0, screen_size.y)
		)
		_highlight_slots(dragged_card)

func start_drag(card):
	dragged_card = card
	drag_offset = get_global_mouse_position() - card.global_position
	card.set_card_state(RiftCard.CardState.DRAGGING)
	card.z_index = 100

func get_dragged_card():
	return dragged_card

func return_dragged_card_to_hand():
	if dragged_card == null:
		return

	var card = dragged_card
	dragged_card = null

	_clear_slot_highlights()
	drag_offset = Vector2.ZERO

	var active_id = game_controller.state.get_active_player().id
	var active_hand = $"../P0/P0_Hand" if active_id == 0 else $"../P1/P1_Hand"
	if active_hand:
		active_hand.return_card(card)

func clear_dragged_card():
	if dragged_card != null:
		var active_id = game_controller.state.get_active_player().id
		var active_hand = $"../P0/P0_Hand" if active_id == 0 else $"../P1/P1_Hand"
		if active_hand and active_hand.has_method("remove_card"):
			active_hand.remove_card(dragged_card)

	dragged_card = null
	_clear_slot_highlights()
	drag_offset = Vector2.ZERO

# =========================
# 🔥 FIXED HIGHLIGHT LOGIC
# =========================
func _highlight_slots(_card):
	if board_reference == null or dragged_card == null:
		return

	_clear_slot_highlights()

	var player = game_controller.state.get_active_player()
	var base_slots = board_reference._player_slot_nodes if player.id == 0 else board_reference._p1_slot_nodes

	var battlefield_slots = []
	if player.id == 0:
		battlefield_slots = [
			board_reference._p0_bf_slot_left,
			board_reference._p0_bf_slot_right
		]
	else:
		battlefield_slots = [
			board_reference._p1_bf_slot_left,
			board_reference._p1_bf_slot_right
		]

	var origin_zone = _get_active_player_card_zone(dragged_card.card_uid)

	# HAND → BASE
	if origin_zone == "HAND":
		for i in range(base_slots.size()):
			var slot = base_slots[i]
			var count = player.board_slots[i].size() if i < player.board_slots.size() else 0
			slot.highlight(true, true, count)
		return

	# BASE → BATTLEFIELD
	if origin_zone == "BOARD":
		var card_instance = _get_active_player_card_instance(dragged_card.card_uid)
		if card_instance != null and not card_instance.is_exhausted():
			for bf_slot in battlefield_slots:
				if bf_slot != null:
					bf_slot.highlight(true, true)
		return

	# BATTLEFIELD → BASE
	if origin_zone == "ARENA":
		for i in range(base_slots.size()):
			var slot2 = base_slots[i]
			var count2 = player.board_slots[i].size() if i < player.board_slots.size() else 0
			slot2.highlight(true, true, count2)
		return

# =========================
# 🔥 FIXED CLEAR LOGIC
# =========================
func _clear_slot_highlights():
	if board_reference == null:
		return

	var player = game_controller.state.get_active_player()
	var base_slots = board_reference._player_slot_nodes if player.id == 0 else board_reference._p1_slot_nodes

	for slot in base_slots:
		slot.highlight(false)

	var battlefield_slots = [
		board_reference._p0_bf_slot_left,
		board_reference._p0_bf_slot_right,
		board_reference._p1_bf_slot_left,
		board_reference._p1_bf_slot_right
	]

	for bf_slot in battlefield_slots:
		if bf_slot != null:
			bf_slot.highlight(false)

# =========================
# 🔥 FIXED ZONE LOOKUP
# =========================
func _get_active_player_card_zone(card_uid):
	var player = game_controller.state.get_active_player()

	for c in player.hand:
		if c.uid == card_uid:
			return "HAND"

	for slot in player.board_slots:
		for c in slot:
			if c.uid == card_uid:
				return "BOARD"

	for lane in player.battlefield_slots:
		for c in lane:
			if c.uid == card_uid:
				return "ARENA"

	return "NONE"

func _get_active_player_card_instance(card_uid):
	var player = game_controller.state.get_active_player()

	for c in player.hand:
		if c.uid == card_uid:
			return c

	for slot in player.board_slots:
		for c in slot:
			if c.uid == card_uid:
				return c

	for lane in player.battlefield_slots:
		for c in lane:
			if c.uid == card_uid:
				return c

	return null
