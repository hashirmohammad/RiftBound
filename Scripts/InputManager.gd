extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released

const COLLISION_MASK_CARD = 1
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

	if card_found.current_state != RiftCard.CardState.ON_BOARD:
		card_manager_reference.start_drag(card_found)

func _try_release_dragged_card() -> void:
	var dragged_card = card_manager_reference.get_dragged_card()
	if dragged_card == null:
		return

	var slot_index : int = board_reference.get_slot_index_under_mouse()

	if slot_index != -1:
		var success: bool = game_controller.try_play_card_to_slot(dragged_card.card_uid, slot_index)
		if success:
			card_manager_reference.clear_dragged_card()
		else:
			card_manager_reference.return_dragged_card_to_hand()
	else:
		card_manager_reference.return_dragged_card_to_hand()

func _get_card_under_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true

	var result = space_state.intersect_point(parameters)
	if result.size() == 0:
		return null

	var collider = result[0].collider
	if collider == null:
		return null

	if collider.collision_mask == COLLISION_MASK_CARD:
		return collider.get_parent()

	return null
