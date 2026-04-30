extends Control

@onready var local_btn = $VBox/LocalButton
@onready var multi_btn = $VBox/MultiplayerButton

func _ready() -> void:
	local_btn.pressed.connect(_on_local_pressed)
	multi_btn.pressed.connect(_on_multi_pressed)

func _on_local_pressed() -> void:
	NetworkManager.start_local()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_multi_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")
