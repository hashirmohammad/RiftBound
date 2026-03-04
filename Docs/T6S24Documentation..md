# T6S-24 — Integrate Drag-to-Board System with CardData Architecture
**Epic:** Frontend: Board and Deck Creation  
**Story:** [Frontend] Implement Player Card Hand and Drag-to-Board Mechanics  
**Branch:** `T6S-24`  
**Status:** ✅ Complete

---

## Goal

The goal of T6S-24 was to build a fully playable drag-to-board card interaction system and integrate it with our existing `RiftCard` and `CardData` architecture. This ticket combines Tasks 3 and 4 — mouse input/drag state and board interaction/drop zones — into one unified system, while also replacing hardcoded card data with a live JSON database.

---

## What Was Built

### `Card.gd` — Unified Card Script
**File:** `Scripts/Card.gd`

The core card node. Extends `Node2D` to work with `Area2D` collision-based hover and drag detection via `CardManager`.

Key responsibilities:
- Holds `CardState` enum (`IN_HAND`, `DRAGGING`, `ON_BOARD`, `RETURNING`)
- Emits `hovered` and `hovered_off` signals for `CardManager`
- Calls `load_from_resource()` to populate visuals from `CardData`
- Connects to `CardManager` via `connect_card_signals()` on ready

### `Card.tscn` — Updated Card Scene
**File:** `Scenes/Card.tscn`

Updated to include all nodes required by the interaction system:
- `CardBackImage` — Sprite2D for card back during flip animation
- `CardImage` — Sprite2D for card artwork
- `Area2D` + `CollisionShape2D` — collision detection for hover and drag
- `Attack` + `Health` — RichTextLabel nodes for card stats
- `AnimationPlayer` — for card flip animation on draw

### `CardData.gd` — Updated Resource Class
**File:** `Scripts/CardData.gd`

Updated to match the full JSON database schema. Now includes all fields from `data/cards.json`:

| Property | Type | Description |
|---|---|---|
| `card_id` | String | Unique card identifier e.g. `OGN-001/298` |
| `set_code` | String | Set name e.g. `Origins` |
| `card_name` | String | Display name |
| `cost` | int | Energy cost to play |
| `might` | int | Combat power |
| `domain` | Domain enum | Fury, Calm, Mind, Body, Chaos, Order, Colorless |
| `card_type` | CardType enum | Unit, Spell, Champion Unit, etc. |
| `keywords` | Array[String] | Tags like Dragon, Noxus, Pirate |
| `ability` | String | Rules text |
| `rarity` | Rarity enum | Common, Uncommon, Rare, Epic, Showcase |
| `image_url` | String | URL to card artwork |

Includes a `from_dict()` static method to create a `CardData` from a JSON dictionary.

### `CardDatabase.gd` — JSON Card Loader
**File:** `Scripts/CardDatabase.gd`  
**Registered as:** Autoload

Loads all cards from `data/cards.json` at game start and stores them in a dictionary keyed by `card_id`.

Available methods:
- `get_card(card_id)` — fetch a single card by ID
- `get_all_cards()` — returns all cards as an array
- `get_cards_by_type(type)` — filter by CardType enum
- `get_cards_by_domain(domain)` — filter by Domain enum

### `CardManager.gd` — Drag and Drop Logic
**File:** `Scripts/CardManager.gd`

Handles all drag, hover, and drop logic. Uses raycasting to detect which card slot a card is dropped on and validates the drop by card type.

### `InputManager.gd` — Mouse Input
**File:** `Scripts/InputManager.gd`

Dedicated node for mouse input. Emits signals for left click and release so `CardManager` can react to them cleanly.

### `PlayerHand.gd` — Hand Layout
**File:** `Scripts/PlayerHand.gd`

Manages the player's hand. Calculates card positions dynamically and animates cards to their positions using tweens.

### `Deck.gd` — Draw System
**File:** `Scripts/Deck.gd`

Manages the player's deck. Draws cards one at a time, loads card data, and deals them into the hand with a flip animation.

### `MagicCardSlot.gd` / `MonsterCardSlot.gd` — Drop Zones
**Files:** `Scripts/MagicCardSlot.gd`, `Scripts/MonsterCardSlot.gd`

Drop zones on the board. Each slot has a type that is checked against the card being dropped to validate placement.

---

## File Structure

```
Scripts/
├── Card.gd               # Unified card node
├── CardData.gd           # Resource class matching JSON schema
├── CardDatabase.gd       # Autoload — loads cards.json at startup
├── CardManager.gd        # Drag, hover, raycast drop detection
├── InputManager.gd       # Mouse input signals
├── PlayerHand.gd         # Hand layout with tweens
├── Deck.gd               # Draw system
├── MagicCardSlot.gd      # Magic drop zone
└── MonsterCardSlot.gd    # Monster drop zone
Scenes/
├── Card.tscn             # Updated card scene
├── CardSlot.tscn         # Board slot scene
├── EnemyCardSlot.tscn    # Enemy slot scene
└── main.tscn             # Full game board scene
data/
├── cards.json            # Card database — source of truth
└── cards.csv             # Card database — CSV version
```

---

## How to Test

**Step 1 — Register CardDatabase as Autoload:**
1. Go to **Project → Project Settings → Autoload**
2. Add `Scripts/CardDatabase.gd` with the name `CardDatabase`

**Step 2 — Set main.tscn as the main scene:**
1. Go to **Project → Project Settings → Application → Run**
2. Set Main Scene to `res://Scenes/main.tscn`

**Step 3 — Hit Play**

**Expected results:**
- Game window opens showing the board
- Cards are dealt from the deck into the player's hand at the bottom
- Cards play a flip animation when drawn
- Hovering over a card highlights it by scaling it up
- Clicking and dragging a card makes it follow the mouse
- Dropping a card on a valid slot plays it to the board
- Dropping a card on an invalid area returns it to hand with a tween animation
- Deck count updates as cards are drawn
- No errors in the Output panel

**Step 4 — Verify CardDatabase in Output panel:**

You should see:
```
CardDatabase loaded: X cards
```
This confirms `cards.json` was parsed and all cards are available.

---

## Important Notes for the Team

- `CardDatabase` must be registered as an **Autoload** — see Step 1 above
- Card images load from `image_url` in the JSON — no local PNG assets needed
- `Card.gd` must always be a child of `CardManager` — `_ready()` calls `get_parent().connect_card_signals(self)` which will crash if the parent is not `CardManager`
- `card_type` on a card now comes from `card_data.card_type` — do not set it manually

---

## Key Decisions Made

- **Switched from `Control` to `Node2D`** for the card base class to support `Area2D` collision detection for hover and drag
- **Replaced hardcoded card dictionary** with a JSON loader so all 300+ cards are available without hardcoding
- **Dropped local PNG assets** — card artwork loads from URLs in the JSON database
- **Combined Tasks 3 and 4** into this single ticket since drag and drop zone logic were tightly coupled

---

## What's Next — Task 5
- It will depend on the team
Task 5 (Visual Polish & Tweens) builds on this. It will:
- Polish the card flip animation on draw
- Polish the return-to-hand tween animation
- Add visual feedback when hovering over valid drop zones
- Display card name, domain, and ability text on the card face
- Load and display card artwork from `image_url`
