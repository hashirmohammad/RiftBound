class_name ChoiceController
extends RefCounted

var controller: Node
var state: GameState
var status_label: Label
var choice_a_button: Button
var choice_b_button: Button

var pending_play_choice: Dictionary = {}


func setup(
		_controller: Node,
		_state: GameState,
		_status_label: Label,
		_choice_a_button: Button,
		_choice_b_button: Button
	) -> void:
	controller = _controller
	state = _state
	status_label = _status_label
	choice_a_button = _choice_a_button
	choice_b_button = _choice_b_button


func try_play_card(card_uid: int, slot_index: int) -> String:
	var card := _find_hand_card(card_uid)
	if card == null:
		status_label.text = "Card not found in hand."
		return "failed"

	if _card_needs_play_choice(card):
		_show_choice_for_card(card, slot_index)
		return "choice"

	var played: bool = controller.try_play_card_to_slot(card_uid, slot_index)
	return "played" if played else "failed"


func resolve_pending_choice(choice: String) -> void:
	if state.awaiting_choice:
		var choice_type := str(state.pending_choice_data.get("type", ""))

		match choice_type:
			"qiyana_conquer":
				_resolve_qiyana_choice(choice)

			"udyr":
				_resolve_udyr_choice(choice)

			_:
				# Backward-compatible fallback.
				match state.pending_choice_card_id:
					"OGN-155/298":
						_resolve_qiyana_choice(choice)
					"OGN-157/298":
						_resolve_udyr_choice(choice)
					_:
						state.add_event("Unknown pending choice.")
						_clear_pending_choice()
						controller.refresh_all_ui()

		return

	if pending_play_choice.is_empty():
		return

	var card_uid: int = int(pending_play_choice.get("card_uid", -1))
	var slot_index: int = int(pending_play_choice.get("slot_index", -1))
	var choice_type: String = str(pending_play_choice.get("type", ""))

	if choice == "A":
		_hide_play_choice_ui()
		controller.try_play_card_to_slot(card_uid, slot_index)
		return

	var metadata: Dictionary = {}

	match choice_type:
		"accelerate":
			metadata["accelerate"] = true
			metadata["accelerate_cost"] = 1

		"extra_calm":
			metadata["extra_calm_paid"] = true

	_hide_play_choice_ui()
	controller.request_play_card(card_uid, slot_index, metadata)


func _resolve_qiyana_choice(choice: String) -> void:
	if choice == "A":
		EffectResolver.draw_cards(state, state.pending_choice_player_id, 1)
	else:
		EffectResolver.channel_runes_exhausted(state, state.pending_choice_player_id, 1)

	_clear_pending_choice()
	controller.refresh_all_ui()


func _resolve_udyr_choice(choice: String) -> void:
	var source_uid := state.pending_choice_source_uid
	var player_id := state.pending_choice_player_id

	match state.pending_choice_step:
		"udyr_category", "":
			if choice == "A":
				state.enter_choice(
					"OGN-157/298",
					source_uid,
					player_id,
					"udyr_combat",
					"",
					{"type": "udyr"}
				)
				state.add_event("Udyr: choose combat effect.")
			else:
				state.enter_choice(
					"OGN-157/298",
					source_uid,
					player_id,
					"udyr_self",
					"",
					{"type": "udyr"}
				)
				state.add_event("Udyr: choose self effect.")

			controller.refresh_all_ui()
			return

		"udyr_combat":
			if choice == "A":
				_begin_udyr_target_mode("UDYR_deal2")
			else:
				_begin_udyr_target_mode("UDYR_stun")
			return

		"udyr_self":
			if choice == "A":
				_resolve_udyr_ready()
			else:
				_resolve_udyr_ganking()
			return

		_:
			state.add_event("Udyr failed: unknown choice step %s." % state.pending_choice_step)
			_clear_pending_choice()
			controller.refresh_all_ui()


func _find_hand_card(card_uid: int) -> CardInstance:
	var player := state.get_priority_player()
	for card in player.hand:
		if card.uid == card_uid:
			return card
	return null


func _card_needs_play_choice(card: CardInstance) -> bool:
	if card == null or card.data == null:
		return false

	match card.data.card_id:
		"OGN-075/298": # Tasty Faefolk
			return true
		"OGN-044/298": # Clockwork Keeper
			return true
		"OGN-151/298": # Lee Sin, Centered
			return true
		_:
			return false


func _show_choice_for_card(card: CardInstance, slot_index: int) -> void:
	var player := state.get_priority_player()

	match card.data.card_id:
		"OGN-075/298":
			var accelerate_total_cost: int = card.data.cost + 1
			var disable_b: bool = player.awaken_rune_count() < accelerate_total_cost

			_show_play_choice_ui(
				"Choose how to play %s" % card.data.card_name,
				"Play Normally",
				"Accelerate (+1 Calm)",
				{
					"type": "accelerate",
					"card_uid": card.uid,
					"slot_index": slot_index
				},
				disable_b
			)

		"OGN-044/298":
			var extra_total_cost: int = card.data.cost + 1
			var disable_b: bool = player.awaken_rune_count() < extra_total_cost

			_show_play_choice_ui(
				"Choose how to play %s" % card.data.card_name,
				"Play Normally",
				"Pay extra Calm and draw 1",
				{
					"type": "extra_calm",
					"card_uid": card.uid,
					"slot_index": slot_index
				},
				disable_b
			)
		
		"OGN-151/298": # Lee Sin, Centered
			var accelerate_total_cost: int = card.data.cost + 1
			var disable_b: bool = player.awaken_rune_count() < accelerate_total_cost

			_show_play_choice_ui(
				"Choose how to play %s" % card.data.card_name,
				"Play Normally",
				"Accelerate (+1 Calm)",
				{
					"type": "accelerate",
					"card_uid": card.uid,
					"slot_index": slot_index
				},
				disable_b
			)


func _show_play_choice_ui(
		label_text: String,
		a_text: String,
		b_text: String,
		context: Dictionary,
		disable_b := false
	) -> void:
	status_label.text = label_text

	choice_a_button.text = a_text
	choice_b_button.text = b_text
	choice_a_button.visible = true
	choice_b_button.visible = true
	choice_a_button.disabled = false
	choice_b_button.disabled = disable_b

	pending_play_choice = context.duplicate(true)


func _hide_play_choice_ui() -> void:
	choice_a_button.visible = false
	choice_b_button.visible = false
	choice_a_button.disabled = false
	choice_b_button.disabled = false
	pending_play_choice.clear()


func _clear_pending_choice() -> void:
	state.exit_choice()

	choice_a_button.visible = false
	choice_b_button.visible = false
	choice_a_button.disabled = false
	choice_b_button.disabled = false


func _begin_udyr_target_mode(card_id: String) -> void:
	var source_uid := state.pending_choice_source_uid

	state.exit_choice()
	state.enter_unit_target(source_uid, card_id)

	if card_id == "UDYR_deal2":
		state.add_event("Udyr: choose enemy battlefield unit to deal 2.")
	else:
		state.add_event("Udyr: choose enemy battlefield unit to stun.")

	controller.refresh_all_ui()


func _resolve_udyr_ready() -> void:
	var unit := state.unit_registry.get_unit(state.pending_choice_source_uid)
	if unit == null:
		state.add_event("Udyr failed: source not found.")
		_clear_pending_choice()
		controller.refresh_all_ui()
		return

	unit.card_instance.awaken()
	state.add_event("Udyr readied himself.")

	_clear_pending_choice()
	controller.refresh_all_ui()


func _resolve_udyr_ganking() -> void:
	var unit := state.unit_registry.get_unit(state.pending_choice_source_uid)
	if unit == null:
		state.add_event("Udyr failed: source not found.")
		_clear_pending_choice()
		controller.refresh_all_ui()
		return

	unit.effects.add(
		EffectFactory.make_ganking(
			state,
			unit.uid,
			EffectInstance.ExpiryTiming.END_OF_TURN
		)
	)

	state.add_event("Udyr gained Ganking this turn.")

	_clear_pending_choice()
	controller.refresh_all_ui()
