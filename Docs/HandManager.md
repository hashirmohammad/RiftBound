Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/board/hand_manager.gd
Status: ✅ Complete

###Goal
The goal of this script is to manage everything about the player's hand: instantiating card scenes, 
positioning them evenly along the bottom of the screen, and animating cards when they are dealt or returned. 
It acts as the visual parent for all in-hand cards and keeps the layout responsive as cards are added or removed.

###What Was Built
Hand Positioning
HandManager positions itself at the bottom-centre of the screen (SCREEN_W / 2, SCREEN_H - HAND_H / 2) in _ready(). Cards are laid out symmetrically around this centre point using CARD_SPACING (160px) between each card.

Card Dealing
deal_card(data) instantiates Card.tscn, loads the CardData resource onto it, appends it to cards_in_hand, repositions all cards, then plays the deal tween. It returns the new RiftCard node so Deck can track it.

Card Removal and Return
remove_card() — removes a card from the hand array and scene, then repositions remaining cards
return_card() — re-adds a card to the hand (e.g. after a failed drag) and tweens it back into place
has_card() — convenience check used by CardManager

###File Structure
scripts/
└── board/
    └── hand_manager.gd       # HandManager logic (this file)
scenes/
└── card/
    └── Card.tscn             # Preloaded card scene
scenes/
└── board/
    └── board_layout.tscn     # Parent scene — HandManager node lives here
	
###How to Test
Step 1 — Deal starting hand:

Run the board scene (F5)

Expected result: Four cards appear at the bottom of the screen, evenly spaced and centred. 
Each card animates in with a scale pop.

###Important Notes for the Team
SCREEN_W and SCREEN_H are hardcoded constants (1920 × 1080) — if the target resolution changes, 
update these values here and in board_layout.gd
