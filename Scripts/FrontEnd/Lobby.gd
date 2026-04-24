extends Control

@onready var host_button    = $VBox/HostButton
@onready var host_list      = $VBox/HostList
@onready var no_hosts_label = $VBox/HostList/NoHostsLabel
@onready var ip_input       = $VBox/JoinRow/IPInput
@onready var join_button    = $VBox/JoinRow/JoinButton
@onready var status_label   = $VBox/StatusLabel
@onready var back_button    = $VBox/BackButton

var _discovered: Array[String] = []
var _connect_timer: SceneTreeTimer = null

func _ready() -> void:
	NetworkManager.setup_firewall_rules()
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	NetworkManager.game_ready.connect(_on_game_ready)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.start_listening()

func _on_host_discovered(ip: String) -> void:
	if _discovered.has(ip):
		return
	_discovered.append(ip)
	no_hosts_label.visible = false

	var btn := Button.new()
	btn.text = "Join  %s" % ip
	btn.custom_minimum_size = Vector2(440, 46)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func(): _connect_to(ip))
	host_list.add_child(btn)

func _connect_to(ip: String) -> void:
	NetworkManager.stop_discovery()
	NetworkManager.join_host(ip)
	status_label.text    = "Connecting to %s..." % ip
	host_button.disabled = true
	join_button.disabled = true
	_connect_timer = get_tree().create_timer(8.0)
	_connect_timer.timeout.connect(_on_connect_timeout)

func _on_host_pressed() -> void:
	NetworkManager.stop_discovery()
	NetworkManager.start_host()
	NetworkManager.start_broadcasting()
	status_label.text    = "Waiting for opponent..."
	host_button.disabled = true
	join_button.disabled = true

func _on_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_connect_to(ip)

func _on_connect_timeout() -> void:
	_connect_timer = null
	status_label.text    = "Connection timed out. Check firewall / IP."
	host_button.disabled = false
	join_button.disabled = false
	NetworkManager._close_peer()
	NetworkManager.start_listening()

func _on_game_ready(_local_id: int) -> void:
	_connect_timer = null
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_connection_failed() -> void:
	_connect_timer = null
	status_label.text    = "Connection failed. Try again."
	host_button.disabled = false
	join_button.disabled = false
	NetworkManager.start_listening()

func _on_back_pressed() -> void:
	NetworkManager._close_peer()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
