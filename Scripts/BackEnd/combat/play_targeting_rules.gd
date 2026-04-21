class_name PlayTargetingRules

const TARGET_ENEMY_BATTLEFIELD_LEFT  := -100
const TARGET_ENEMY_BATTLEFIELD_RIGHT := -101

static func get_special_play_targets(card: CardInstance, state: GameState, player_id: int) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []

	if card == null or card.data == null:
		return targets

	match card.data.card_id:
		"OGN-161/298": # Deadbloom Predator
			var opponent := state.players[1 - player_id]

			if not opponent.battlefield_slots[0].is_empty():
				targets.append({
					"type": "enemy_battlefield",
					"player": 1 - player_id,
					"lane": 0,
					"slot_code": TARGET_ENEMY_BATTLEFIELD_LEFT,
					"label": "Enemy Left Battlefield"
				})

			if not opponent.battlefield_slots[1].is_empty():
				targets.append({
					"type": "enemy_battlefield",
					"player": 1 - player_id,
					"lane": 1,
					"slot_code": TARGET_ENEMY_BATTLEFIELD_RIGHT,
					"label": "Enemy Right Battlefield"
				})

	return targets

static func find_matching_special_target(
	card: CardInstance,
	state: GameState,
	player_id: int,
	board_hit: Dictionary
) -> Dictionary:
	if board_hit.is_empty():
		return {}

	var targets := get_special_play_targets(card, state, player_id)

	for t in targets:
		if str(t.get("type", "")) == str(board_hit.get("type", "enemy_battlefield")) \
		and int(t.get("player", -1)) == int(board_hit.get("player", -1)) \
		and int(t.get("lane", -1)) == int(board_hit.get("lane", -1)):
			return t

	return {}
