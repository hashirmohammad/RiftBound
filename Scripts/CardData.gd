class_name CardData
extends Resource

## CardData — Holds all static data for a single Riftbound card.
##
## This is a Resource, not a node. It gets saved as a .tres file
## under resources/cards/ and assigned to a Card node at runtime
## via Card.load_from_resource().
##
## To create a new card:
##   1. Right click resources/cards/ in the FileSystem
##   2. New Resource → CardData
##   3. Fill in the properties in the inspector

## Rarity tier — controls visual styling on the card (border, glow, etc.)
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var card_name: String = ""        ## Display name of the card
@export var cost: int = 0                 ## Mana/energy cost to play
@export var power: int = 0               ## Attack or effect power value
@export var texture: Texture2D            ## Card artwork
@export var rarity: Rarity = Rarity.COMMON  ## Rarity tier
