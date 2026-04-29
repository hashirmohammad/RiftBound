class_name GameFlowController
extends RefCounted

enum Phase {
	TURN_START,
	MAIN_PHASE,
	RUNE_PAYMENT,
	TARGETING,
	CHOICE,
	SHOWDOWN,
	DAMAGE_ASSIGNMENT,
	TURN_END
}

var phase: Phase = Phase.TURN_START


func set_phase(new_phase: Phase) -> void:
	phase = new_phase


func is_main_phase() -> bool:
	return phase == Phase.MAIN_PHASE


func is_targeting() -> bool:
	return phase == Phase.TARGETING


func is_showdown() -> bool:
	return phase == Phase.SHOWDOWN


func is_rune_payment() -> bool:
	return phase == Phase.RUNE_PAYMENT


func is_choice() -> bool:
	return phase == Phase.CHOICE
	
