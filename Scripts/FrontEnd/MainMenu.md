# MainMenu

Entry point scene. Two buttons: start local game or go to multiplayer lobby.

---

## Nodes

| Node path | Variable | Type |
|---|---|---|
| `VBox/LocalButton` | `local_btn` | `Button` |
| `VBox/MultiplayerButton` | `multi_btn` | `Button` |

---

## Functions

### `_on_local_pressed() -> void`
Calls `NetworkManager.start_local()` (sets `is_network_mode = false`, `local_player_id = 0`), then loads `main.tscn` directly.

### `_on_multi_pressed() -> void`
Loads `Lobby.tscn`. No NetworkManager state set here — Lobby handles host/join.

---

## Scene Flow

```
MainMenu
  ├── Local button → main.tscn  (local 2-player, same machine)
  └── Multiplayer button → Lobby.tscn → main.tscn  (LAN)
```
