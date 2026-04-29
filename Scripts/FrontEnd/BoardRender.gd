class_name BoardRenderer
extends RefCounted

const SpellRegistry = preload("res://Scripts/BackEnd/spell/spell_registry.gd")
const CARD_SCENE = preload("res://Scenes/Card.tscn")

var controller: Node
var board: Node
var state: GameState
var hand_manager: Node
var hand_manager_p1: Node
var deck_ui: Node


func setup(
		_controller: Node,
		_board: Node,
		_state: GameState,
		_hand_manager: Node,
		_hand_manager_p1: Node,
		_deck_ui: Node
	) -> void:
	controller = _controller
	board = _board
	state = _state
	hand_manager = _hand_manager
	hand_manager_p1 = _hand_manager_p1
	deck_ui = _deck_ui


func _local_id() -> int:
	return NetworkManager.local_player_id


func refresh_all_ui() -> void:
	render_static_state(state.players[_local_id()], state.players[1 - _local_id()])
	refresh_hand_ui()
	render_board()
	refresh_deck_ui()


func refresh_hand_ui() -> void:
	hand_manager.render_hand(state.players[_local_id()].hand)
	hand_manager_p1.render_hand(state.players[1 - _local_id()].hand)


func refresh_deck_ui() -> void:
	if deck_ui != null and deck_ui.has_method("set_count"):
		deck_ui.set_count(state.players[_local_id()].deck.size())


func refresh_payment_ui() -> void:
	render_rune_panels(state.players[_local_id()], state.players[1 - _local_id()])


func render_board() -> void:
	var local  := state.players[_local_id()]
	var remote := state.players[1 - _local_id()]
	_render_player_slots(local,  board._player_slot_nodes)
	_render_player_slots(remote, board._p1_slot_nodes)

	_render_battlefield_lane(remote.battlefield_slots[0], board._p1_bf_slot_left)
	_render_battlefield_lane(remote.battlefield_slots[1], board._p1_bf_slot_right)
	_render_battlefield_lane(local.battlefield_slots[0],  board._p0_bf_slot_left)
	_render_battlefield_lane(local.battlefield_slots[1],  board._p0_bf_slot_right)


func render_slot(player: PlayerState, slot_index: int) -> void:
	var slots = board._player_slot_nodes if player.id == _local_id() else board._p1_slot_nodes
	if slot_index >= slots.size() or slots[slot_index] == null:
		return

	var slot = slots[slot_index]
	slot.clear_cards()

	for ci in player.board_slots[slot_index]:
		_place_card(slot, ci, Vector2(0.35, 0.35))


func render_arena_slot(player: PlayerState) -> void:
	if player.id != _local_id():
		_render_battlefield_lane(player.battlefield_slots[0], board._p1_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], board._p1_bf_slot_right)
	else:
		_render_battlefield_lane(player.battlefield_slots[0], board._p0_bf_slot_left)
		_render_battlefield_lane(player.battlefield_slots[1], board._p0_bf_slot_right)


func render_static_state(player: PlayerState, opponent: PlayerState) -> void:
	var deck_tex: Texture2D = load("res://Assets/Deck.jpg")

	if deck_tex != null:
		for panel in [
			board.player_main_deck,
			board.player_rune_deck,
			board.opponent_main_deck,
			board.opponent_rune_deck
		]:
			_clear_panel_visuals(panel)
			_add_panel_texture(panel, deck_tex)

	_render_static_card_panel(board.player_champion_legend, player.legend)
	_render_static_card_panel(board.opponent_champion_legend, opponent.legend)

	_render_static_card_panel(board.player_champion_panel, player.champion)
	_render_static_card_panel(board.opponent_champion_panel, opponent.champion)

	_render_battlefields(board.player_battlefield_panel, player.battlefields, player.picked_battlefield)
	_render_battlefields(board.opponent_battlefield_panel, opponent.battlefields, opponent.picked_battlefield)

	_render_arena_pick(board.arena_p0_panel, player.picked_battlefield, "Arena 1")
	_render_arena_pick(board.arena_p1_panel, opponent.picked_battlefield, "Arena 2")

	render_rune_panels(player, opponent)


func render_rune_panels(p0: PlayerState, p1: PlayerState) -> void:
	_render_runes(board.player_runes_panel, p0.rune_pool, p0.id)
	_render_runes(board.opponent_runes_panel, p1.rune_pool, p1.id)


func _render_player_slots(player: PlayerState, slots: Array) -> void:
	if player == null:
		return

	for slot in slots:
		if slot != null:
			slot.clear_cards()

	for i in range(player.board_slots.size()):
		if i >= slots.size() or slots[i] == null:
			continue

		for ci in player.board_slots[i]:
			_place_card(slots[i], ci, Vector2(0.35, 0.35))


func _render_battlefield_lane(cards: Array, slot: CardSlot) -> void:
	if slot == null:
		return

	slot.clear_cards()

	for ci in cards:
		_place_card(slot, ci, Vector2(0.35, 0.35))


func _place_card(slot: CardSlot, card_instance: CardInstance, scale: Vector2) -> void:
	var card: RiftCard = CARD_SCENE.instantiate()
	card.scale = scale
	card.z_index = 5
	slot.add_card(card)

	card.setup_from_card_instance(card_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)
	card.rotation_degrees = 90.0 if card_instance.is_exhausted() else 0.0
	card.refresh_slot_state()

	if controller.selected_board_uids.has(card_instance.uid):
		card.modulate = Color(0.55, 1.0, 0.55, 1.0)

	_apply_target_highlight(card, card_instance)


func _apply_target_highlight(card: RiftCard, card_instance: CardInstance) -> void:
	if state.awaiting_unit_target:
		var source_uid: int = state.pending_target_source_uid
		var source_unit: UnitState = state.unit_registry.get_by_uid(source_uid)
		var current_unit: UnitState = state.unit_registry.get_by_uid(card_instance.uid)

		if source_unit != null and current_unit != null:
			match state.pending_target_card_id:
				"OGN-136/298":
					if current_unit.player_id == source_unit.player_id and current_unit.uid != source_unit.uid:
						card.modulate = Color(0.6, 1.0, 0.6, 1.0)

				"UDYR_deal2", "UDYR_stun":
					if current_unit.player_id != source_unit.player_id and _is_card_on_battlefield(card_instance.uid):
						card.modulate = Color(0.6, 1.0, 0.6, 1.0)

	if state.awaiting_spell_targets:
		var current_unit: UnitState = state.unit_registry.get_by_uid(card_instance.uid)
		if current_unit != null:
			if SpellRegistry.can_select_target(
				state.pending_spell_card_id,
				state,
				state.pending_spell_player_id,
				state.pending_spell_target_uids,
				current_unit.uid
			):
				card.modulate = Color(0.6, 1.0, 0.6, 1.0)


func _render_static_card_panel(panel: Panel, card_instance: CardInstance) -> void:
	if panel == null:
		return

	_clear_panel_visuals(panel)

	if card_instance == null or card_instance.data == null:
		return

	var card: RiftCard = CARD_SCENE.instantiate()
	panel.add_child(card)
	card.position = panel.size / 2.0
	card.scale = Vector2(0.35, 0.35)
	card.setup_from_card_instance(card_instance)
	card.set_card_state(RiftCard.CardState.ON_BOARD)

	# Legend/champion display should not rotate visually.
	card.rotation_degrees = 0.0
	card.refresh_slot_state()


func _render_battlefields(panel: Panel, battlefield_instances: Array, pick: BattlefieldInstance) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is RiftCard:
			child.queue_free()

	if pick != null or battlefield_instances.is_empty():
		return

	var count: int = battlefield_instances.size()
	var spacing: float = 170.0
	var start_x: float = (panel.size.x / 2.0) - (float(count - 1) * spacing / 2.0)

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
	card.scale = Vector2(0.65, 0.65)
	card.z_index = 5
	card.setup_from_battlefield_instance(pick)
	card.set_card_state(RiftCard.CardState.ON_BOARD)


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
	var start_x: float = (panel.size.x / 2.0) - (float(count - 1) * spacing / 2.0)

	var active_player_id: int = state.get_active_player().id
	var is_current_player: bool = player_id == active_player_id

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
		var is_selected: bool = is_current_player and state.selected_rune_uids.has(rune_inst.uid)
		var can_select: bool = is_current_player and state.awaiting_rune_payment and not is_exhausted and not is_selected

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


func _clear_panel_visuals(panel: Panel) -> void:
	if panel == null:
		return

	for child in panel.get_children():
		if child is TextureRect or child is RiftCard:
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


func _is_card_on_battlefield(card_uid: int) -> bool:
	for player in state.players:
		for lane in player.battlefield_slots:
			for card in lane:
				if card.uid == card_uid:
					return true
	return false
