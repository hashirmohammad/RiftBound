extends Node

const PORT               = 7777
const DISCOVERY_PORT     = 7778
const MAX_PEERS          = 1
const BROADCAST_INTERVAL = 1.0

var is_network_mode: bool = false
var local_player_id: int  = 0
var game_seed: int        = 0

signal game_ready(local_id: int)
signal connection_failed
signal peer_disconnected
signal host_discovered(ip: String)

var _udp_broadcaster: PacketPeerUDP = null
var _udp_listener:    PacketPeerUDP = null
var _broadcast_timer: float         = 0.0

# ─── Firewall setup (Windows only, runs once) ────────────────────────────────

func setup_firewall_rules() -> void:
	if OS.get_name() != "Windows":
		return
	var flag := "user://fw_done"
	if FileAccess.file_exists(flag):
		return

	var script_local := "user://riftbound_fw.ps1"
	var f := FileAccess.open(script_local, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(
		"New-NetFirewallRule -DisplayName 'RiftBound ENet' -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow -ErrorAction SilentlyContinue\r\n" +
		"New-NetFirewallRule -DisplayName 'RiftBound Discovery' -Direction Inbound -Protocol UDP -LocalPort 7778 -Action Allow -ErrorAction SilentlyContinue\r\n"
	)
	f.close()

	var abs_path: String = ProjectSettings.globalize_path(script_local).replace("/", "\\")
	OS.create_process("powershell", [
		"-Command",
		"Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList '-ExecutionPolicy Bypass -File \"%s\"'" % abs_path
	])

	var done := FileAccess.open(flag, FileAccess.WRITE)
	if done:
		done.close()

# ─── Local / Host / Join ──────────────────────────────────────────────────────

func start_local() -> void:
	is_network_mode = false
	local_player_id = 0

func start_host() -> void:
	_close_peer()
	is_network_mode = true
	local_player_id = 0
	game_seed       = randi()
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(PORT, MAX_PEERS)
	if err != OK:
		push_warning("NetworkManager: server creation failed (%d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_host(ip: String) -> void:
	_close_peer()
	is_network_mode = true
	local_player_id = 1
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, PORT)
	if err != OK:
		push_warning("NetworkManager: client connect failed (%d)" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _close_peer() -> void:
	stop_discovery()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

# ─── LAN Discovery ────────────────────────────────────────────────────────────

func start_broadcasting() -> void:
	if _udp_broadcaster != null:
		return
	_udp_broadcaster = PacketPeerUDP.new()
	_udp_broadcaster.set_broadcast_enabled(true)
	_udp_broadcaster.bind(0)
	_broadcast_timer = BROADCAST_INTERVAL  # fire immediately on first frame

func start_listening() -> void:
	if _udp_listener != null:
		return
	_udp_listener = PacketPeerUDP.new()
	var err := _udp_listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: discovery listen bind failed (%d)" % err)
		_udp_listener = null

func stop_discovery() -> void:
	if _udp_broadcaster != null:
		_udp_broadcaster.close()
		_udp_broadcaster = null
	if _udp_listener != null:
		_udp_listener.close()
		_udp_listener = null
	_broadcast_timer = 0.0

func _process(delta: float) -> void:
	if _udp_broadcaster != null:
		_broadcast_timer += delta
		if _broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_timer = 0.0
			_udp_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
			_udp_broadcaster.put_packet("riftbound".to_utf8_buffer())

	if _udp_listener != null:
		while _udp_listener.get_available_packet_count() > 0:
			_udp_listener.get_packet()
			var ip := _udp_listener.get_packet_ip()
			if ip != "" and ip != "0.0.0.0":
				host_discovered.emit(ip)

# ─── Peer callbacks ───────────────────────────────────────────────────────────

func _on_peer_connected(_id: int) -> void:
	_notify_game_ready.rpc(game_seed)

func _on_connected_to_server() -> void:
	pass

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_peer_disconnected(_id: int) -> void:
	peer_disconnected.emit()

@rpc("authority", "call_local")
func _notify_game_ready(seed_val: int) -> void:
	stop_discovery()
	game_seed = seed_val
	game_ready.emit(local_player_id)
