#T6S-20-creating-a-template-of-the-board
**Epic:** Frontend: Board and Deck Creation 
**Story:** [Frontend] Creating and designing the board
**Branch:** `T6S-20`  
**Status:** ✅ Complete

###Goal 
The goal of my first task and story was to create the board controlnode which was going to handle building
and displaying the full 1920 by 1080 board layout at run time  

###What Was Built
Board Layout
The screen is split vertically into three sections: Player 1's half, a central Arena, and Player 2's half. 
The two player halves are mirrored 
Each player's half contains the following zones, sized and positioned with proportional math based on 
screen dimensions:

- Battlefield — main play area for cards in play
- Champion Legend / Chosen Champion — dedicated champion card slots
- Base — displays the RiftBound logo 
- Main Deck — draw piles
- Runes — rune card zone 
- Trash — discard pile
- Hand — card hand strip for the players hand at any time
- Mana Track — 8 circular mana indicators along the left side

###File Structure
scripts/
└── board/
    └── board_layout.gd       #BoardLayout logic

scenes/
└── board/
    └── board_layout.tscn     #BoardLayout scene file

assets/
├── RiftBoundLogo.jpg         #Logo displayed in the Base zone
└── runes.jpg                 #Icon displayed in the Runes zone

###How to Test
Step 1 — Open the scene:

- In Godot open scenes/board/board_layout.tscn
- Hit Play Scene (F6)

The expected result when doing this should be the full board render and display on screen 

###Important Notes for the Team
- Uses add_panel() to create new zones this ensures consistent placments for the enitre board 
- To ensure correct postioning on the board make sure to never hard code values as this could differ
depening o the machine 
