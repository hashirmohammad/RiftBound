Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/board/deck.gd
Status: ✅ Complete

###Goal
The goal of this script is to manage the player's draw pile. 
On startup it builds a deck from all cards in CardDatabase that have artwork, shuffles it, 
and deals a starting hand. During play it handles click-to-draw, enforces the one-draw-per-turn rule, 
and hides the deck visual when the pile is empty.

###What Was Built
-Deck Building
On _ready(), all cards with a non-empty image_url are added to player_deck as card ID strings. 
The deck is then shuffled with Array.shuffle(). Cards without artwork are excluded to avoid blank card visuals.
-Starting Hand
After shuffling, draw_card() is called STARTING_HAND_SIZE (4) times with await so each deal animation 
completes before the next card is drawn. drawn_card_this_turn is reset to false after each starting draw so the full hand is dealt correctly.
-Draw Card
draw_card() pops the front ID from player_deck, looks it up in CardDatabase, and passes the CardData to 
HandManager.deal_card(). The deck counter label is updated after each draw. If the deck runs out, the deck's 
Area2D collision is disabled and the visual is hidden.

File Structure
scripts/
└── board/
	└── deck.gd               # Deck logic (this file)
scenes/
└── board/
	└── board_layout.tscn     # Parent scene — Deck node lives here
							  # alongside HandManager

###How to Test
Step 1 — Run the board scene:

Open scenes/board/board_layout.tscn
Hit Play Scene (F5)

Expected result: Four cards are dealt into the hand on startup. 
The deck counter label shows the remaining card count.

###Important Notes for the Team
The drawn_card_this_turn flag must be reset externally at the start of each turn — 
the Deck script does not know when a new turn begins. 
