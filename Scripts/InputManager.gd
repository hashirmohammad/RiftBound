extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_SLOT = 2
const COLLISION_MASK_HAND = 3
const COLLISION_MASK_DECK = 4

var card_manager_reference
var deck_reference
var board_reference
var game_controller

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference = $"../P0/P0_MainDeck"
	board_reference = $"../Board"
	game_controller = $"../GameController"

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

	var active_id: int = game_controller.state.get_active_player().id
	var hand_path := "../P0/P0_Hand" if active_id == 0 else "../P1/P1_Hand"
	var hand = get_node_or_null(hand_path)
	if hand == null or not hand.has_card(card_found):
		return

	if card_found.current_state != RiftCard.CardState.ON_BOARD:
		card_manager_reference.start_drag(card_found)

func _try_release_dragged_card() -> void:
	var dragged_card = card_manager_reference.get_dragged_card()
	if dragged_card == null:
		return

	var space = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_areas = true

	# Check slot collision (layer 2) — place card on board
	params.collision_mask = COLLISION_MASK_SLOT
	if space.intersect_point(params).size() > 0:
		var slot_index: int = board_reference.get_slot_index_under_mouse()
		if slot_index != -1:
			var success: bool = game_controller.try_play_card_to_slot(dragged_card.card_uid, slot_index)
			if success:
				card_manager_reference.clear_dragged_card()
				return

	# Check hand collision (layer 3) — return card to hand
	params.collision_mask = COLLISION_MASK_HAND
	if space.intersect_point(params).size() > 0:
		card_manager_reference.return_dragged_card_to_hand()
		return

	# Dropped outside both — still return to hand
	card_manager_reference.return_dragged_card_to_hand()

func _get_card_under_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
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
