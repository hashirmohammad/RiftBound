class_name GameAction

enum ActionType {
	END_TURN,
	PLAY_CARD
}

var type: ActionType
var player_id: int
var card_uid: int = -1  # which card in hand to play

func _init(t: ActionType, pid: int, idx: int = -1):
	type = t
	player_id = pid
	card_uid = idx
