extends Node

const PORT               = 7777
const DISCOVERY_PORT     = 7778
const MAX_PEERS          = 1
const BROADCAST_INTERVAL = 1.0

var is_network_mode: bool   = false
var local_player_id: int    = 0
var game_seed: int          = 0
var last_connected_ip: String = ""
var pending_reconnect: bool = false

signal game_ready(local_id: int)
signal connection_failed
signal peer_disconnected
signal host_discovered(ip: String)
signal connected_to_host

var _udp_broadcaster: PacketPeerUDP = null
var _udp_listener:    PacketPeerUDP = null
var _broadcast_timer: float         = 0.0

# ─── Firewall setup (Windows only, runs once) ────────────────────────────────

func setup_firewall_rules(force: bool = false) -> void:
	if OS.get_name() != "Windows":
		return
	var flag := "user://fw_done"
	if not force and FileAccess.file_exists(flag):
		return

	var script_local := "user://riftbound_fw.ps1"
	var flag_abs: String = ProjectSettings.globalize_path(flag).replace("/", "\\")
	var f := FileAccess.open(script_local, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(
		"New-NetFirewallRule -DisplayName 'RiftBound ENet' -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow -ErrorAction SilentlyContinue\r\n" +
		"New-NetFirewallRule -DisplayName 'RiftBound Discovery' -Direction Inbound -Protocol UDP -LocalPort 7778 -Action Allow -ErrorAction SilentlyContinue\r\n" +
		"New-Item -ItemType File -Path '%s' -Force | Out-Null\r\n" % flag_abs
	)
	f.close()

	var abs_path: String = ProjectSettings.globalize_path(script_local).replace("/", "\\")
	OS.create_process("powershell", [
		"-Command",
		"Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList '-ExecutionPolicy Bypass -File \"%s\"'" % abs_path
	])

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
		print("[NET] ERROR: server creation failed (err=%d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[NET] Hosting on %s:%d" % [get_local_ip(), PORT])

func join_host(ip: String) -> void:
	_close_peer()
	is_network_mode  = true
	local_player_id  = 1
	last_connected_ip = ip
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, PORT)
	if err != OK:
		print("[NET] ERROR: client creation failed (err=%d)" % err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[NET] Attempting to connect to %s:%d" % [ip, PORT])

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
		print("[NET] ERROR: discovery listen bind failed (err=%d) — port %d may be in use" % [err, DISCOVERY_PORT])
		_udp_listener = null
	else:
		print("[NET] Listening for hosts on port %d" % DISCOVERY_PORT)

func stop_discovery() -> void:
	if _udp_broadcaster != null:
		_udp_broadcaster.close()
		_udp_broadcaster = null
	if _udp_listener != null:
		_udp_listener.close()
		_udp_listener = null
	_broadcast_timer = 0.0

func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue
		var parts := addr.split(".")
		if parts.size() != 4:
			continue
		if parts[0] == "127" or (parts[0] == "169" and parts[1] == "254"):
			continue
		return addr
	return "unknown"

func _get_broadcast_addresses() -> Array[String]:
	var result: Array[String] = []
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue
		var parts := addr.split(".")
		if parts.size() != 4:
			continue
		if parts[0] == "127" or (parts[0] == "169" and parts[1] == "254"):
			continue
		result.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	if result.is_empty():
		result.append("255.255.255.255")
	return result

func _process(delta: float) -> void:
	if _udp_broadcaster != null:
		_broadcast_timer += delta
		if _broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_timer = 0.0
			var packet := "riftbound".to_utf8_buffer()
			for addr in _get_broadcast_addresses():
				_udp_broadcaster.set_dest_address(addr, DISCOVERY_PORT)
				_udp_broadcaster.put_packet(packet)

	if _udp_listener != null:
		while _udp_listener.get_available_packet_count() > 0:
			var packet := _udp_listener.get_packet()
			var ip     := _udp_listener.get_packet_ip()
			if ip != "" and ip != "0.0.0.0" and packet.get_string_from_utf8() == "riftbound":
				print("[NET] Host discovered: %s" % ip)
				host_discovered.emit(ip)

# ─── Peer callbacks ───────────────────────────────────────────────────────────

func _on_peer_connected(_id: int) -> void:
	print("[NET] Peer connected (id=%d) — sending game ready" % _id)
	_notify_game_ready.rpc(game_seed)

func _on_connected_to_server() -> void:
	print("[NET] Connected to host!")
	connected_to_host.emit()

func _on_connection_failed() -> void:
	print("[NET] Connection FAILED — host unreachable or port blocked")
	connection_failed.emit()

func _on_peer_disconnected(_id: int) -> void:
	print("[NET] Peer disconnected (id=%d)" % _id)
	peer_disconnected.emit()

@rpc("authority", "call_local")
func _notify_game_ready(seed_val: int) -> void:
	stop_discovery()
	game_seed = seed_val
	game_ready.emit(local_player_id)
