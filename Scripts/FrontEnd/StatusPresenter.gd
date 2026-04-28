class_name StatusPresenter
extends RefCounted

var status_label: Label
var cancel_payment_button: Button
var pass_priority_button: Button
var confirm_damage_button: Button
var choice_a_button: Button
var choice_b_button: Button


func setup(
		_status_label: Label,
		_cancel_payment_button: Button,
		_pass_priority_button: Button,
		_confirm_damage_button: Button,
		_choice_a_button: Button,
		_choice_b_button: Button
	) -> void:
	status_label = _status_label
	cancel_payment_button = _cancel_payment_button
	pass_priority_button = _pass_priority_button
	confirm_damage_button = _confirm_damage_button
	choice_a_button = _choice_a_button
	choice_b_button = _choice_b_button


func update(state: GameState, pending_assignments = null) -> void:
	if status_label == null:
		return

	if pending_assignments == null:
		pending_assignments = {}

	_hide_all_buttons()

	if state.awaiting_choice:
		choice_a_button.visible = true
		choice_b_button.visible = true
		_update_choice_buttons(state)
		status_label.text = "Choose an effect." + _game_info_text(state)
		return

	if state.awaiting_unit_target:
		status_label.text = _unit_target_text(state) + _game_info_text(state)
		return

	if state.awaiting_spell_destination:
		status_label.text = "Choose destination battlefield." + _game_info_text(state)
		return

	if state.awaiting_spell_targets:
		status_label.text = _spell_target_text(state) + _game_info_text(state)
		return

	if state.awaiting_rune_payment:
		var remaining: int = state.pending_card_cost - state.selected_rune_uids.size()
		status_label.text = "Select %d more rune(s)." % remaining + _game_info_text(state)
		cancel_payment_button.visible = true
		return

	if state.awaiting_showdown:
		status_label.text = "Showdown! Pass or use an ability." + _game_info_text(state)
		pass_priority_button.visible = true
		return

	if state.awaiting_damage_assignment:
		status_label.text = _damage_assignment_text(state, pending_assignments) + _game_info_text(state)
		confirm_damage_button.visible = true
		return

	status_label.text = "" + _game_info_text(state)


func _hide_all_buttons() -> void:
	cancel_payment_button.visible = false
	pass_priority_button.visible = false
	confirm_damage_button.visible = false
	choice_a_button.visible = false
	choice_b_button.visible = false


func _update_choice_buttons(state: GameState) -> void:
	match state.pending_choice_card_id:
		"OGN-155/298": # Qiyana
			choice_a_button.text = "Draw 1"
			choice_b_button.text = "Channel 1 exhausted"

		"OGN-157/298": # Udyr
			choice_a_button.visible = true
			choice_b_button.visible = true
			choice_a_button.disabled = false
			choice_b_button.disabled = false

			match state.pending_choice_step:
				"udyr_category", "":
					choice_a_button.text = "Combat Effect"
					choice_b_button.text = "Self Effect"

				"udyr_combat":
					choice_a_button.text = "Deal 2"
					choice_b_button.text = "Stun"

				"udyr_self":
					choice_a_button.text = "Ready Udyr"
					choice_b_button.text = "Gain Ganking"

				_:
					choice_a_button.text = "Combat Effect"
					choice_b_button.text = "Self Effect"

		_:
			choice_a_button.text = "Option A"
			choice_b_button.text = "Option B"


func _unit_target_text(state: GameState) -> String:
	match state.pending_target_card_id:
		"OGN-136/298":
			return "Choose another friendly unit for Pit Rookie."
		"UDYR_deal2":
			return "Choose an enemy battlefield unit to deal 2 damage."
		"UDYR_stun":
			return "Choose an enemy battlefield unit to stun."
		_:
			return "Choose a unit target."


func _spell_target_text(state: GameState) -> String:
	var chosen: int = state.pending_spell_target_uids.size()
	var needed: int = state.pending_spell_required_targets

	match state.pending_spell_card_id:
		"OGN-058/298":
			return "Choose a unit for Discipline (%d/%d)." % [chosen, needed]
		"OGN-046/298":
			return "Choose a friendly unit for En Garde (%d/%d)." % [chosen, needed]
		"OGN-128/298":
			if chosen == 0:
				return "Choose a friendly unit for Challenge (1/2)."
			return "Choose an enemy unit for Challenge (2/2)."
		"OGN-043/298":
			return "Choose an enemy unit for Charm."
		"OGN-258/298":
			if chosen == 0:
				return "Choose enemy unit to move for Dragon's Rage."
			return "Choose another enemy unit at destination."
		_:
			return "Choose spell target(s) (%d/%d)." % [chosen, needed]

func _damage_assignment_text(state: GameState, pending_assignments: Dictionary) -> String:
	var ctx: CombatContext = state.active_combat_context
	if ctx == null:
		return "Assign combat damage."

	var loser_is_attacker: bool = ctx.total_defender_might > ctx.total_attacker_might
	var pool: int = ctx.total_attacker_might if loser_is_attacker else ctx.total_defender_might
	var target_units: Array = ctx.defenders if loser_is_attacker else ctx.attackers
	var loser_player_id: int = ctx.attackers[0].player_id if loser_is_attacker else ctx.defenders[0].player_id

	var total_assigned := 0
	for uid in pending_assignments:
		total_assigned += int(pending_assignments[uid])

	var remaining := pool - total_assigned

	var parts: Array[String] = []
	for unit in target_units:
		var assigned := int(pending_assignments.get(unit.uid, 0))
		var lethal : int = max(0, unit.base_health - unit.damage_taken)
		var tag := " [TANK]" if unit.is_tank() else ""

		parts.append("%s%s: %d assigned / lethal %d" % [
			unit.card_instance.data.card_name,
			tag,
			assigned,
			lethal
		])

	var text := "P%d assign %d damage, left: %d\n%s" % [
		loser_player_id,
		pool,
		remaining,
		"\n".join(parts)
	]

	print(text)
	return text

func _event_log_text(state: GameState, max_lines := 5) -> String:
	if state.event_log.is_empty():
		return ""

	var important: Array[String] = []

	for e in state.event_log:
		var line := str(e)

		if line.contains("spends rune"):
			continue
		if line.contains("unit registered"):
			continue
		if line.contains("started paying"):
			continue

		important.append(line)

	var start: int = max(0, important.size() - max_lines)
	var lines: Array[String] = []

	for i in range(start, important.size()):
		lines.append(important[i])

	if lines.is_empty():
		return ""

	return "\n\nLog:\n" + "\n".join(lines)

func _game_info_text(state: GameState) -> String:
	var active_id: int = state.active_player_index
	var priority_id: int = state.get_priority_player_id()

	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]

	var text := "\n\n--- Game Info ---"
	text += "\nTurn: %d" % state.turn_number
	text += "\nPhase: %s" % state.phase
	text += "\nCurrent Player: P%d" % active_id

	if state.awaiting_showdown:
		text += "\nPriority: P%d" % priority_id

	text += "\nPoints: P0 %d / %d | P1 %d / %d" % [
		int(state.scores[0]),
		state.POINTS_TO_WIN,
		int(state.scores[1]),
		state.POINTS_TO_WIN
	]

	return text
