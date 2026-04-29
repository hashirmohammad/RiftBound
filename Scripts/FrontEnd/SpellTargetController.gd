class_name SpellTargetController
extends RefCounted

const SpellRegistry = preload("res://Scripts/BackEnd/spell/spell_registry.gd")

var controller: Node
var state: GameState
var status_label: Label


func setup(_controller: Node, _state: GameState, _status_label: Label) -> void:
	controller = _controller
	state = _state
	status_label = _status_label


func try_select_spell_target(target_uid: int) -> bool:
	if not state.awaiting_spell_targets:
		return false

	if not SpellRegistry.can_select_target(
		state.pending_spell_card_id,
		state,
		state.pending_spell_player_id,
		state.pending_spell_target_uids,
		target_uid
	):
		status_label.text = "Invalid target."
		return false

	state.pending_spell_target_uids.append(target_uid)

	if state.pending_spell_target_uids.size() >= state.pending_spell_required_targets:
		match state.pending_spell_card_id:
			"OGN-043/298": # Charm
				state.enter_spell_destination()
				status_label.text = "Choose destination battlefield."
				controller.refresh_all_ui()
				return true

			_:
				resolve_pending_spell()
				return true

	controller.refresh_all_ui()
	return true


func resolve_pending_spell() -> void:
	var card := _get_pending_spell_card()
	if card == null:
		state.add_event("Pending spell failed: card not found.")
		state.exit_spell_targets()
		controller.refresh_all_ui()
		return

	var player_id: int = state.pending_spell_player_id
	var payload := _build_payload(player_id)

	var resolver := SpellRegistry.get_resolver(card.data.card_id)

	if state.awaiting_showdown and state.timing_manager != null:
		state.timing_manager.queue_spell(card, resolver, payload)
		state.add_event("P%d put %s on the spell stack." % [
			player_id,
			card.data.card_name
		])
	else:
		SpellRegistry.resolve(card, state, payload)
	_send_spell_to_trash(card, player_id)
	state.add_event("P%d used %s." % [player_id, card.data.card_name])

	state.pending_play_metadata.clear()
	state.exit_spell_targets()

	controller.refresh_all_ui()


func try_select_spell_destination(destination_zone: String, destination_player_id: int, destination_index: int) -> void:
	if not state.awaiting_spell_destination:
		return

	var card := _get_pending_spell_card()
	if card == null:
		state.add_event("Pending spell failed: card not found.")
		state.exit_spell_targets()
		controller.refresh_all_ui()
		return

	var player_id: int = state.pending_spell_player_id

	var payload := {
		"player_id": player_id,
		"target_uid": state.pending_spell_target_uids[0],
		"target_uids": state.pending_spell_target_uids,
		"destination_zone": destination_zone,
		"destination_player_id": destination_player_id,
		"destination_index": destination_index
	}

	SpellRegistry.resolve(card, state, payload)
	_send_spell_to_trash(card, player_id)

	state.pending_play_metadata.clear()
	state.exit_spell_targets()

	controller.refresh_all_ui()


func _get_pending_spell_card() -> CardInstance:
	var player_id: int = state.pending_spell_player_id
	var player: PlayerState = state.players[player_id]

	for card in player.hand:
		if card.uid == state.pending_spell_card_uid:
			return card

	return null


func _build_payload(player_id: int) -> Dictionary:
	var payload: Dictionary = {
		"player_id": player_id
	}

	match state.pending_spell_card_id:
		"OGN-128/298": # Challenge
			payload["friendly_uid"] = state.pending_spell_target_uids[0]
			payload["enemy_uid"] = state.pending_spell_target_uids[1]

		"OGN-258/298": # Dragon's Rage
			payload["moved_uid"] = state.pending_spell_target_uids[0]
			payload["other_uid"] = state.pending_spell_target_uids[1]
			payload["target_uids"] = state.pending_spell_target_uids

		_:
			payload["target_uid"] = state.pending_spell_target_uids[0]

	return payload


func _send_spell_to_trash(card: CardInstance, player_id: int) -> void:
	var player: PlayerState = state.players[player_id]

	for i in range(player.hand.size()):
		if player.hand[i].uid == card.uid:
			player.hand.remove_at(i)
			break

	card.zone = CardInstance.Zone.TRASH
	player.trash.append(card)

	state.add_event("P%d resolved %s and sent it to trash." % [
		player_id,
		card.data.card_name
	])
	
