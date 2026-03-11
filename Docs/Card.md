Epic: Frontend: Board and Deck Creation
Story: [Frontend] 
Branch: scripts/card/Card.gd
Status: ✅ Complete

###Goal 
The goal of this script is to serve as the base visual node for every card in the game. 
It handles how a card looks on screen, manages its current state (in hand, being dragged, on board, 
or returning), and is responsible for fetching and caching card artwork from a remote URL.

###What Was Built
-Card States
Each card tracks a CardState enum with four values: IN_HAND, DRAGGING, ON_BOARD, and RETURNING.
State changes are managed through set_card_state() which also resets the enlarge toggle if the card
leaves the board.
-Image Loading & Caching
Card artwork is fetched from a URL provided by CardData. Images are cached locally to 
user://card_cache/ as .png files so they are only downloaded once. On subsequent loads the cached version
is applied immediately. The cache path sanitises the card ID to remove filesystem-unsafe characters.
-Enlarge on Right-Click
When a card is on the board, right-clicking it smoothly scales it up to 1.5x via a tween and clamps its position
so it stays fully within the viewport. Right-clicking again restores the original position and scale.
-Signal Emission
The card emits hovered and hovered_off signals via its Area2D so CardManager can handle hover highlights
without coupling. It also emits texture_loaded once artwork is applied.
-Parent Auto-Connection
On _ready() the card checks whether its parent has a connect_card_signals() method and calls it automatically, 
so signal wiring happens without manual setup in the scene tree.

###File Structure
scripts/
└── card/
	└── rift_card.gd          # Card logic (this file)
scenes/
└── card/
	└── Card.tscn             # Scene containing CardImage, CardBackImage, Area2D
user://
└── card_cache/               # Runtime image cache (auto-created)

###How to Test
Open any scene that uses Card.tscn
Assign a CardData resource with a valid image_url
Hit Play Scene (F5)

Expected result: The card back shows briefly, then flips to the card artwork once the download completes.
On subsequent runs the image loads instantly from cache.
Step 2 — Right-click enlarge:

Place a card on the board during play
Right-click it

Expected result: The card smoothly scales up and centres itself on screen. Right-clicking again restores it.

###Important Notes for the Team
-Never hard-code CARD_WIDTH / CARD_HEIGHT elsewhere — always reference the constants defined here to keep 
resize logic consistent
-The _pending_image_url and _pending_card_id fields exist to handle cases where load_from_resource() 
is called before the node enters the scene tree — the deferred call in _ready() picks them up safely
