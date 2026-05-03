# NetworkManager

Autoload singleton (`/root/NetworkManager`). Manages all LAN multiplayer state: ENet peer lifecycle, UDP host discovery, game seed distribution, and reconnect tracking.

---

## Constants

| Name | Value | Purpose |
|---|---|---|
| `PORT` | `7777` | ENet game traffic (UDP) |
| `DISCOVERY_PORT` | `7778` | LAN host broadcast/listen |
| `MAX_PEERS` | `1` | 2-player only |
| `BROADCAST_INTERVAL` | `1.0` | Seconds between host beacon packets |

---

## State Variables

| Variable | Type | Set by | Purpose |
|---|---|---|---|
| `is_network_mode` | `bool` | `start_host` / `start_local` | Gates all network logic in GameController/BoardRender |
| `local_player_id` | `int` | `start_host` (0) / `join_host` (1) | Which player index this machine controls |
| `game_seed` | `int` | `start_host` (random) / `_notify_game_ready` (synced) | Shared RNG seed — keeps both machines deterministic |
| `last_connected_ip` | `String` | `join_host` | Stored for auto-reconnect after disconnect |
| `pending_reconnect` | `bool` | `GameController._on_peer_disconnected` | Tells Lobby to auto-reconnect on next `_ready()` |

---

## Signals

| Signal | Args | Emitted when |
|---|---|---|
| `game_ready` | `local_id: int` | Both machines should load the game scene |
| `connection_failed` | — | ENet client could not reach host |
| `peer_disconnected` | — | Remote peer dropped (wraps `multiplayer.peer_disconnected`) |
| `host_discovered` | `ip: String` | UDP beacon received from a host on LAN |
| `connected_to_host` | — | Client successfully connected to ENet server |

---

## Public Functions

### `start_local() -> void`
Marks session as local (no network). Sets `is_network_mode = false`, `local_player_id = 0`.

### `start_host() -> void`
Creates ENet server on `PORT`. Generates random `game_seed`. Assigns `local_player_id = 0`.  
Connects `peer_connected` → `_on_peer_connected` which broadcasts game_ready to all peers.

### `join_host(ip: String) -> void`
Creates ENet client connecting to `ip:PORT`. Sets `local_player_id = 1`, saves `last_connected_ip` for reconnect.

### `setup_firewall_rules(force: bool = false) -> void`
**Windows only.** Writes and runs a PowerShell script (elevated) that adds inbound UDP rules for ports 7777 and 7778. Runs once per install (flag stored in `user://fw_done`). Pass `force = true` to re-run.

### `start_broadcasting() -> void`
Starts sending `"riftbound"` UDP packets to all LAN broadcast addresses every `BROADCAST_INTERVAL` seconds. Call on host after `start_host()`.

### `start_listening() -> void`
Binds UDP listener on `DISCOVERY_PORT`. Emits `host_discovered(ip)` when a valid beacon is received. Call on clients in Lobby.

### `stop_discovery() -> void`
Closes both broadcaster and listener sockets. Called automatically on `_close_peer()` and `_notify_game_ready`.

### `get_local_ip() -> String`
Returns first non-loopback, non-APIPA IPv4 address. Used to display host IP in Lobby UI.

---

## RPC

### `_notify_game_ready(seed_val: int)`
`@rpc("authority", "call_local")` — called by host when client connects.  
Sets `game_seed` on both machines and emits `game_ready(local_player_id)`.  
This is the trigger for both Lobby scenes to call `change_scene_to_file("res://Scenes/main.tscn")`.

---

## Reconnect Flow

```
game drops
    └── GameController._on_peer_disconnected()
            ├── NetworkManager.pending_reconnect = true
            ├── wait 3s
            ├── NetworkManager._close_peer()
            └── change_scene → Lobby

Lobby._ready()
    └── if pending_reconnect:
            ├── pending_reconnect = false
            ├── host → _on_host_pressed() → start_host()
            └── client → _connect_to(last_connected_ip) → join_host()
```

---

## Notes

- **Network profile must be Private** on Windows. Public profile blocks UDP discovery and ENet traffic.
- `_close_peer()` is called at the start of both `start_host()` and `join_host()` to safely tear down any previous connection before creating a new one.
- `multiplayer.multiplayer_peer` is set at the SceneTree root level (via the autoload) so it persists across scene changes.
- `local_player_id` is always `0` for the host and `1` for the client. Player 0 always goes first.
