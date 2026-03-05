class_name PlayerState

var id: int
var points: int = 0

var deck: Array[CardInstance] = [] #cards that are not drawnn
var hand: Array[CardInstance] = [] #cards on hand
var board: Array[CardInstance] = [] #cards currently in play
var graveyard: Array[CardInstance] = [] #cards removed from play
var battlefields: Array[CardInstance] = [] #battlefield cards
var rune_deck: Array = [] #runes that are not drawnn
var rune_pool: Array = [] #runes currently availablee

func _init(player_id: int):
	id = player_id

# ---------- Rune helpers (FIFO queue behavior) ----------

func rune_count_in_deck() -> int:
	return rune_deck.size()

func rune_count_in_pool() -> int:
	return rune_pool.size()

# Take the "top/front" rune (FIFO). Returns null if empty.
func draw_rune() -> Variant:
	if rune_deck.is_empty():
		return null
	return rune_deck.pop_front()

# Channel N runes from rune_deck into rune_pool
func channel_runes(n: int) -> void:
	for i in range(n):
		var r = draw_rune()
		if r == null:
			return
		rune_pool.append(r)

# Spend N runes from the pool (simple version: remove from end)
func spend_runes(n: int) -> bool:
	if rune_pool.size() < n:
		return false
	for i in range(n):
		rune_pool.pop_back()
	return true

# Recycle runes to the bottom of the rune deck (FIFO "bottom")
func recycle_runes_to_bottom(runes: Array) -> void:
	for r in runes:
		rune_deck.append(r)
