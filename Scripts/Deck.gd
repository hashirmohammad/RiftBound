extends Node2D

var current_count: int = 0

func _ready() -> void:
	if has_node("RichTextLabel"):
		$RichTextLabel.text = str(current_count)

func set_count(count: int) -> void:
	current_count = count
	if has_node("RichTextLabel"):
		$RichTextLabel.text = str(current_count)
