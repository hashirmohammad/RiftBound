extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD  = 1
const COLLISION_MASK_SLOT  = 2
const COLLISION_MASK_HAND  = 3
const COLLISION_MASK_DECK  = 4
const COLLISION_MASK_ARENA = 4

var card_manager_reference
var deck_reference
var board_reference
var game_controller

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference         = $"../P0/P0_MainDeck"
	board_reference        = $"../Board"
	game_controller        = $"../GameController"

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			left_mouse_button_clicked.emit()
			_try_start_drag()
		else:
			left_mouse_button_released.emit()
			_try_release_dragged_card()

func _try_start_drag() -> void:
	var card_found = _get_card_under_cursor()
	if card_found == null:
		return
	var state : GameState = game_controller.state

	# If we are paying for a card, only rune clicks are allowed.
	if state.awaiting_rune_payment:
		var rune_instance := _get_payment_player_rune_instance(card_found.card_uid)
		if rune_instance != null:
			game_controller.try_pick_runes_to_spend(card_found.card_uid)
		else:
			game_controller.status_label.text = "Finish selecting runes first."
		return
		
	# FIRST: check whether this clicked visual is a rune
	var rune_instance := _get_payment_player_rune_instance(card_found.card_uid)
	if rune_instance != null:
		game_controller.try_pick_runes_to_spend(card_found.card_uid)
		return

	var zone := _get_active_player_card_zone(card_found.card_uid)

	# hand -> base is allowed
	if zone == "HAND":
		card_manager_reference.start_drag(card_found)
		return

	# base -> battlefield is only allowed if the card is AWAKEN
	if zone == "BOARD":
		var card_instance = _get_active_player_card_instance(card_found.card_uid)
		if card_instance == null:
			return
		if card_instance.is_exhausted():
			return
		card_manager_reference.start_drag(card_found)
		return

	# battlefield -> base is allowed only if the card is AWAKEN
	if zone == "ARENA":
		var card_instance = _get_active_player_card_instance(card_found.card_uid)
		if card_instance == null:
			return
		if card_instance.is_exhausted():
			return
		card_manager_reference.start_drag(card_found)
		return

func _try_release_dragged_card() -> void:
	var dragged_card = card_manager_reference.get_dragged_card()
	if dragged_card == null:
		return

	var origin_zone := _get_active_player_card_zone(dragged_card.card_uid)

	var space  = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position           = get_global_mouse_position()
	params.collide_with_areas = true

	# 1) hand -> base only
	if origin_zone == "HAND":
		params.collision_mask = COLLISION_MASK_SLOT
		if space.intersect_point(params).size() > 0:
			var slot_index: int = board_reference.get_slot_index_under_mouse()
			if slot_index != -1:
				var played: bool = game_controller.try_play_card_to_slot(dragged_card.card_uid, slot_index)
				if played:
					if game_controller.state.awaiting_rune_payment:
						card_manager_reference.return_dragged_card_to_hand()
						if game_controller.has_method("refresh_payment_ui"):
							game_controller.refresh_payment_ui()
						else:
							game_controller.refresh_all_ui()
					else:
						card_manager_reference.clear_dragged_card()
					return

		params.collision_mask = COLLISION_MASK_HAND
		if space.intersect_point(params).size() > 0:
			card_manager_reference.return_dragged_card_to_hand()
			return

		card_manager_reference.return_dragged_card_to_hand()
		return

# 2) base -> battlefield only
	if origin_zone == "BOARD":
		print("Trying BOARD -> BATTLEFIELD for card:", dragged_card.card_uid)

		params.collision_mask = COLLISION_MASK_ARENA
		var hits = space.intersect_point(params)
		print("Arena hits size:", hits.size())

		if hits.size() > 0:
			var bf_data = board_reference.get_battlefield_half_under_mouse()
			print("Battlefield under mouse:", bf_data)

			if not bf_data.is_empty():
				var battlefield_index = int(bf_data["lane"])
				print("Trying battlefield index:", battlefield_index)

				var moved = game_controller.try_move_to_battlefield(
					dragged_card.card_uid,
					battlefield_index
				)
				print("Move result:", moved)

				if moved:
					card_manager_reference.clear_dragged_card()
					return

		print("BOARD -> BATTLEFIELD failed, refreshing UI")
		game_controller.refresh_all_ui()
		card_manager_reference.clear_dragged_card()
		return

	# 3) battlefield -> base only
	if origin_zone == "ARENA":
		params.collision_mask = COLLISION_MASK_SLOT
		if space.intersect_point(params).size() > 0:
			var slot_index_2: int = board_reference.get_slot_index_under_mouse()
			if slot_index_2 != -1:
				var battlefield_index_2: int = _get_active_player_battlefield_index(dragged_card.card_uid)
				if battlefield_index_2 != -1:
					var returned: bool = game_controller.try_return_from_battlefield(
						dragged_card.card_uid,
						battlefield_index_2,
						slot_index_2
					)
					if returned:
						card_manager_reference.clear_dragged_card()
						return

		game_controller.refresh_all_ui()
		card_manager_reference.clear_dragged_card()
		return

func _get_active_player_card_zone(card_uid: int) -> String:
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

func _get_active_player_card_instance(card_uid: int):
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

func _get_active_player_battlefield_index(card_uid: int) -> int:
	var player = game_controller.state.get_active_player()

	for i in range(player.battlefield_slots.size()):
		for c in player.battlefield_slots[i]:
			if c.uid == card_uid:
				return i

	return -1

func _get_payment_player_rune_instance(rune_uid: int) -> RuneInstance:
	var state: GameState = game_controller.state
	var player: PlayerState

	if state.awaiting_rune_payment and state.pending_payment_player_id != -1:
		player = state.players[state.pending_payment_player_id]
	else:
		player = state.get_active_player()

	for rune in player.rune_pool:
		if rune.uid == rune_uid:
			return rune

	return null

func _get_card_under_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters  = PhysicsPointQueryParameters2D.new()
	parameters.position           = get_global_mouse_position()
	parameters.collide_with_areas = true

	var result = space_state.intersect_point(parameters)
	if result.size() == 0:
		return null

	for hit in result:
		var collider = hit.collider
		if collider == null:
			continue
		var parent = collider.get_parent()
		if parent is RiftCard:
			return parent

	return null
