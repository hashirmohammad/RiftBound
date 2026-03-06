class_name CardSlot
extends Node2D

@export_enum("UNIT", "SPELL", "RUNE", "CHAMPION") var card_slot_type: int = 0
var card_in_slot: bool = false

func highlight(on: bool, valid: bool = true) -> void:
	var img = get_node_or_null("CardSlotImage")
	if not img:
		return
	if on and valid:
		img.modulate = Color(0.0, 1.0, 0.0, 1.0)
	elif on and not valid:
		img.modulate = Color(1.0, 0.0, 0.0, 0.8)
	else:
		img.modulate = Color(1.0, 1.0, 1.0, 1.0)
