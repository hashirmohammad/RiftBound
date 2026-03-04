# T6S-22 — Task 1: Base Card GDScript Class
**Epic:** Frontend: Board and Deck Creation  
**Story:** [Frontend] Implement Player Card Hand and Drag-to-Board Mechanics  
**Branch:** `T6S-22`  
**Status:** ✅ Complete

---

## Overview

This task establishes the GDScript foundation for the Riftbound card system. It introduces two core scripts — `CardData` and `RiftCard` — that every subsequent frontend task builds on. No game logic lives here. These scripts are purely responsible for holding data and displaying it.

---

## What Was Built

### 1. `CardData` — Resource Script
**File:** `scripts/card/card_data.gd`

`CardData` is a Godot `Resource` subclass that holds all static data for a single card. It is not a node and does not appear on screen. It gets saved as a `.tres` file under `resources/cards/` and assigned to a `RiftCard` node at runtime via `load_from_resource()`.

**Properties:**

| Property | Type | Description |
|---|---|---|
| `card_name` | String | Display name of the card |
| `cost` | int | Mana or energy cost to play |
| `power` | int | Attack or effect power value |
| `texture` | Texture2D | Card artwork |
| `rarity` | Rarity (enum) | Common / Rare / Epic / Legendary |

**To create a new card in the editor:**
1. Right click `resources/cards/` in the FileSystem
2. New Resource → `CardData`
3. Fill in the properties in the inspector
4. Save as `card_name.tres`

---

### 2. `RiftCard` — Node Script
**File:** `scripts/card/card.gd`  
**Class name:** `RiftCard` (renamed from `Card` to avoid conflict with Godot's built-in `Card` class)  
**Scene:** `scenes/cards/card.tscn`

`RiftCard` is a `Control` subclass that represents a single playable card on screen. It holds a reference to a `CardData` resource and manages its own interaction state.

**Why `Control` and not `TextureRect` or `Sprite2D`:**  
`Control` gives access to `_gui_input()` for mouse events, supports free positioning during drag via `set_as_top_level(true)`, and works within Godot's UI layout system. All of these are required by Tasks 3 and 4.

**Card State Machine:**

| State | Description |
|---|---|
| `IN_HAND` | Card is sitting in the player's hand container |
| `DRAGGING` | Card is following the mouse cursor |
| `ON_BOARD` | Card has been placed on a valid board tile |
| `RETURNING` | Card is animating back to hand after an invalid drop |

**`load_from_resource(data: CardData)`:**  
Called by `HandManager` (Task 2) when dealing cards. Stores the `CardData` reference and will populate visual child nodes once the card scene is built out in Task 2.

**Stubs for future tasks:**
- `_gui_input()` — fully implemented in Task 3
- `_process()` — used in Task 3 to follow the mouse while dragging

---

## File Structure

```
res://
├── scripts/
│   └── card/
│       ├── card.gd           # RiftCard node script
│       └── card_data.gd      # CardData resource script
├── scenes/
│   └── cards/
│       └── card.tscn         # Card scene with RiftCard script attached
├── resources/
│   └── cards/                # .tres CardData files go here
└── src/                      # C++ reference files (not compiled, kept for reference)
    └── card/
        ├── card.h
        ├── card.cpp
        ├── card_data.h
        └── card_data.cpp
```

---

## How to Create a New Card

```gdscript
# Example: creating a card programmatically
var data = CardData.new()
data.card_name = "Fire Drake"
data.cost = 3
data.power = 5
data.rarity = CardData.Rarity.RARE

var card = preload("res://scenes/cards/card.tscn").instantiate()
card.load_from_resource(data)
add_child(card)
```

---

## Notes for the Team

- `RiftCard` is the class name — not `Card` (conflicts with Godot built-in)
- New card `.tres` files go in `resources/cards/`
- New card scene files go in `scenes/cards/`
- `load_from_resource()` is the entry point — HandManager calls this in Task 2
- `CardState` enum is the backbone of drag and drop — Tasks 3 and 4 depend on it
- Never commit directly to `main` — always use the Jira ticket ID as branch name

---

## What's Next — Task 2

Task 2 (Layout the Player Hand Container) builds directly on this. It will:
- Create a `HandManager` GDScript node using `HBoxContainer`
- Call `load_from_resource()` on each `RiftCard` when dealing
- Handle card return logic when a drag fails
- Populate the visual child nodes that `load_from_resource()` currently stubs out
