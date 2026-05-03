# RiftBound Multiplayer — LAN Setup Guide

## Requirements

- Both players on the **same local network (LAN/Wi-Fi)**
- Windows: network profile must be set to **Private** (not Public)
  - Settings → Network & Internet → Wi-Fi/Ethernet → [your network] → Network profile → **Private**
- UDP ports **7777** (game) and **7778** (discovery) must not be blocked by firewall
  - Use the **Setup Firewall** button in the Lobby to auto-add Windows Firewall rules

---

## How to Play

### Host
1. Open RiftBound → **Multiplayer Lobby**
2. Click **Host Game**
3. Share your displayed IP with the other player
4. Wait for opponent to join — game starts automatically

### Join
1. Open RiftBound → **Multiplayer Lobby**
2. Your opponent's game should appear in the host list — click **Join**
3. Or enter their IP manually and click **Join**

---

## Reconnect

If the connection drops mid-game, both players are returned to the Lobby after 3 seconds.  
The game will attempt to **auto-reconnect** using the last known IP:
- Host: automatically re-hosts on the same port
- Client: automatically attempts to rejoin

---

## Technical Overview

| Component | Role |
|---|---|
| `NetworkManager.gd` (autoload) | Manages ENet peer, LAN discovery, game seed, reconnect state |
| `GameController.gd` | Sends/receives actions via RPC, enforces local-turn guards |
| `BoardRender.gd` | Perspective-correct rendering (local hand visible, opponent hand face-down) |
| `HandManager.gd` | Renders opponent hand as black face-down cards in network mode |

### Sync Model
Lockstep deterministic replication:
- Both machines run `GameEngine.start_game()` with the same `game_seed`
- Only **actions** are sent over the network (not full state)
- Action types: `play`, `end`, `rune`, `move_bf`, `ret_bf`, `commit`, `pass`, `dmg`, `champ`, `legend`

### Turn Guards
All player inputs check `NetworkManager.local_player_id` against the active player before firing:
- Card drag (InputManager)
- End Turn button (main.gd)
- Pass Priority, Cancel Payment, Choice A/B (GameController)
- Confirm Damage (always checked)

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Host not appearing in list | Run **Setup Firewall**, switch Wi-Fi profile to Private |
| Connected but actions don't sync | Check console for `[NET] WARN: peer not connected` — reconnect |
| "Connection timed out" | Verify both on same network, same subnet |
| Black cards visible on own hand | Should not happen — report as bug |

---

## Known Limitations

- LAN only (no internet/relay)
- 2 players max
- No mid-game spectating
- Reconnect restarts from current lobby state (game progress not saved)
