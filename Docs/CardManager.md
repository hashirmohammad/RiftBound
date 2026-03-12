Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/card/card_manager.gd
Status: ✅ Complete

###Goal
The goal of this script is to act as the central controller for all card interactions during play. 
It owns the drag loop, resolves where a dragged card lands (a valid slot or back to hand), handles
hover highlight scaling, and coordinates with HandManager to keep the hand layout in sync.

###What Was Built
-Drag Loop
start_drag() is called by InputManager when a card's collider is clicked. 
The card is reparented to CardManager so it renders above everything else during the drag. Each _process() 
frame the card follows the mouse, clamped to screen bounds.
-Slot Placement
On mouse release, _raycast_slot() fires a physics point query on collision layer 2 (card slots).
If a free slot is found, the card is locked to it, its collision is disabled, and it transitions to ON_BOARD. 
If no valid slot is found the card is returned to the hand.
-Return to Hand
When a drop fails, the card is reparented back into HandManager, appended to cards_in_hand, and 
tweened back into position via HandManager._tween_return().

###File Structure
scripts/
└── card/
    └── card_manager.gd       # CardManager logic (this file)
scenes/
└── board/
    └── board_layout.tscn     # Parent scene — CardManager lives here
                              # alongside HandManager, InputManager, CardSlots
###How to Test
Step 1 — Drag a card:

Run the main board scene
Click and hold a card in the hand

Expected result: The card follows the mouse. 
Step 2 — Drop on a valid slot:

Drag the card over a slot and release

Expected result: The card snaps to the slot, scales down slightly, and stays on the board.
Step 3 — Drop on an invalid area:

Drag a card and release over empty board space

Expected result: The card tweens back to its original position in the hand.

###Important Notes for the Team

-COLLISION_MASK_CARD = 1 and COLLISION_MASK_CARD_SLOT = 2 must match the collision layer settings on 
Area2D nodes in the scene — mismatches will silently break drag and drop
-Reparenting during drag is intentional — it ensures correct render order without manually managing 
z_index across multiple parent nodes
