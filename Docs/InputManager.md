Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/board/input_manager.gd
Status: ✅ Complete

###Goal
The goal of this script is to be the single entry point for all mouse input in the board scene. 
It listens for left mouse button press and release events, emits signals for other systems to react to, 
and raycasts at the cursor position to determine what was clicked — routing the result to either CardManager 
(to start a drag) or Deck (to draw a card).

###What Was Built
Signals
Two signals are emitted by this script:
left_mouse_button_clicked — fired on press
left_mouse_button_released — fired on release

CardManager connects to left_mouse_button_released to trigger finish_drag(), keeping drag resolution decoupled from input detection.
Raycasting
On each left-click, raycast_at_cursor() fires a PhysicsPointQueryParameters2D query at the global mouse position.
The result's collision mask is inspected to determine what was hit:
	
###File Structure
scripts/
└── board/
    └── input_manager.gd      # InputManager logic (this file)
scenes/
└── board/
    └── board_layout.tscn     # Parent scene — InputManager lives here
                              # alongside CardManager and Deck

###How to Test
Step 1 — Click a card:

Run the board scene
Left-click a card in the hand

Expected result: The card begins following the mouse (drag starts).
Step 2 — Release the mouse:

Drag a card, then release the mouse button

Expected result: CardManager.finish_drag() fires and the card either snaps to a slot or returns to hand.

###Important Notes for the Team
Collision masks must match exactly: cards must be on layer 1, the deck on layer 4. 
If a new clickable object is added to the board, add a new mask constant here and a corresponding elif 
branch in raycast_at_cursor()
