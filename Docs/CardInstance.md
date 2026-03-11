Epic: Backend: Game Logic
Story: [Backend] 
Branch: scripts/card/card_instance.gd
Status: ✅ Complete

###Goal
The goal of this class is to wrap a CardData resource with the runtime state a card needs during an actual game
— which zone it is in, whether it is exhausted, and a unique instance ID so two copies of the same card can be 
tracked independently. It is a pure data object with no visual component.

###What Was Built
Enums

CardState — AWAKEN (ready to act) and EXHAUSTED (spent this turn)
Zone — DECK, HAND, BOARD, GRAVEYARD

Identity
Each instance carries a uid (unique integer assigned at creation) and a reference to its CardData. 
Two copies of the same card in the same deck will have different uid values, allowing them to be tracked 
and targeted individually.

Zone Tracking
zone is updated externally by game logic systems as cards move between deck, hand, board, and graveyard. 
CardInstance itself does not enforce zone transitions — that responsibility belongs to the game state manager.

Exhaust / Awaken
exhaust() and awaken() toggle the card's state. is_exhausted() provides a clean boolean check for use 
in attack and ability validation logic.

###File Structure
scripts/
└── card/
    └── card_instance.gd      # CardInstance class (this file)

###How to Test
Step 1 — Instantiate a card:
Expected result: Output shows the card name, uid=1, zone=0 (DECK), state=0 (AWAKEN).

###Important Notes for the Team
CardInstance extends RefCounted, not Node — it has no scene presence and should never be added to the scene tree
