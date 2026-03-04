# T6S-23 — Task 2: Layout the Player Hand Container
**Epic:** Frontend: Board and Deck Creation  
**Story:** [Frontend] Implement Player Card Hand and Drag-to-Board Mechanics  
**Branch:** `T6S-22`  
**Status:** ✅ Complete

---

## Goal

The goal of Task 2 was to create the `HandManager` node that organizes the player's cards at the bottom of the screen. It is responsible for dealing cards into the hand, removing cards when they are played, and returning cards back to hand when a drag fails. This task bridges Task 1 (the card itself) and Task 3 (mouse input and dragging).

---

## What Was Built

### `HandManager` — Node Script
**File:** `scripts/hand/hand_manager.gd`  
**Scene:** `scenes/hand/hand_manager.tscn`  
**Inherits:** `HBoxContainer`

`HandManager` uses `HBoxContainer` as its base so Godot automatically handles horizontal card layout and spacing. No manual positioning is needed — when cards are added or removed the container adjusts itself.

---

## Functions

| Function | Parameters | Description |
|---|---|---|
| `deal_card()` | `data: CardData` | Instantiates a new `RiftCard`, loads data into it, adds it to the hand |
| `remove_card()` | `card: RiftCard` | Removes a card from the hand when successfully played to the board |
| `return_card()` | `card: RiftCard` | Returns a card to hand after a failed drag, resets state to `IN_HAND` |

---

## File Structure

```
scripts/
└── hand/
    └── hand_manager.gd       # HandManager logic
scenes/
└── hand/
    └── hand_manager.tscn     # HandManager scene file
```

---

## How to Test

Follow these steps to verify `HandManager` is working correctly:

**Step 1 — Create a test scene:**
1. In Godot go to **Scene → New Scene**
2. Add a `Node2D` as the root node
3. Click the chain link icon to instantiate `scenes/hand/hand_manager.tscn` as a child

**Step 2 — Attach a test script to the `Node2D` root:**
```gdscript
extends Node2D

func _ready() -> void:
    var hand = $HandManager

    # Create a test CardData resource
    var data = CardData.new()
    data.card_name = "Fire Drake"
    data.cost = 3
    data.power = 5
    data.rarity = CardData.Rarity.RARE

    # Deal it into the hand
    hand.deal_card(data)
```

**Step 3 — Hit Play**

**Expected result:**
- Game runs with no errors in the Output panel
- A grey rectangle appears on screen representing the HandManager
- The card is instantiated and held in `cards_in_hand` array

**Note:** The card won't have artwork or labels yet — that visual layer is built out in Task 3. This test confirms the logic is working correctly, not the visuals.

---

## How HandManager Connects to Other Tasks

- **Task 1 (RiftCard / CardData)** — `deal_card()` calls `load_from_resource()` on each card
- **Task 3 (Mouse Input)** — calls `return_card()` when a drag is dropped on an invalid area
- **Task 4 (Drop Zones)** — calls `remove_card()` when a card is successfully played to the board
- **Task 5 (Polish)** — `return_card()` has a TODO stub ready for a Tween slide animation

---

## Important Notes for the Team

- `HandManager` inherits `HBoxContainer` — never manually position cards, let the container handle layout
- `CARD_SCENE` is preloaded at the top of the script — if the card scene path ever changes, update it there
- Always use `deal_card()` and `remove_card()` to modify the hand — never modify `cards_in_hand` directly
- `return_card()` is the entry point for failed drags — Task 3 calls this function
- Do not set `hand_manager.tscn` as the main scene in Project Settings — it is a child scene only

---

## What's Next — Task 3

Task 3 (Implement Mouse Input & Drag State) builds directly on this. It will:
- Build out the full card visual scene with artwork, name label, cost and power labels
- Override `_gui_input()` in `card.gd` to detect mouse clicks and releases
- Implement follow mouse logic in `_process()`
- Use `set_as_top_level(true)` while dragging so the card floats above the hand
- Call `HandManager.return_card()` when a card is dropped on an invalid area
