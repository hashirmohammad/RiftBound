class_name CardSlot
extends Node2D

@export_enum("UNIT", "SPELL", "RUNE", "CHAMPION") var card_slot_type: int = 0
var card_in_slot: bool = false

func highlight(on: bool, valid: bool = true) -> void:
	pass
