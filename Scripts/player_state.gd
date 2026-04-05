class_name PlayerState

var id: int
var points: int = 0

var deck: Array[CardInstance] = [] #cards that are not drawnn
var hand: Array[CardInstance] = [] #cards on hand
var board: Array[CardInstance] = [] #cards currently in play
var trash: Array[CardInstance] = [] #cards removed from play
var battlefields: Array[BattlefieldInstance] = [] #battlefield cards
var picked_battlefield: BattlefieldInstance
var rune_deck: Array[RuneInstance] = [] #runes that are not drawnn
var rune_pool: Array[RuneInstance] = [] #runes currently availablee
var legend: CardInstance #legend card
var champion: CardInstance #champion card
var arena_0: Array[CardInstance] = [] #fighting arena
var arena_1: Array[CardInstance] = []
var board_slots: Array = [null, null, null, null, null, null, null, null]

func _init(player_id: int):
	id = player_id
	
func pick_battlefield(index: int) -> void:
	if not battlefields[index].is_picked():
		for battlefield in battlefields:
			battlefield.set_state(BattlefieldInstance.State.UNUSED)
		battlefields[index].set_state(BattlefieldInstance.State.USED)
		picked_battlefield = battlefields[index]
# ---------- Rune helpers (FIFO queue behavior) ----------

func rune_count_in_deck() -> int:
	return rune_deck.size()

func rune_count_in_pool() -> int:
	return rune_pool.size()
	
func awaken_runes_count() -> int:
	var count: int = 0
	for i in range(len(rune_pool)):
		if not rune_pool[i].is_exhausted():
			count+=1
	return count

# Take the "top/front" rune (FIFO). Returns null if empty.
func draw_rune() -> Variant:
	if rune_deck.is_empty():
		return null
	var rune: RuneInstance = rune_deck.pop_front()
	return rune

# Channel N runes from rune_deck into rune_pool
func channel_runes(n: int) -> void:
	for i in range(n):
		var r = draw_rune()
		if r == null:
			return
		r.zone = RuneInstance.Zone.RUNE_POOL
		#r.exhaust()
		rune_pool.append(r)

# Spend N runes from the pool
func spend_runes(selected_runes: Array[RuneInstance]) -> bool:
	for rune in selected_runes:
		if rune == null:
			return false
		if not rune_pool.has(rune):
			return false

	for rune in selected_runes:
		rune_pool.erase(rune)
		rune.zone = RuneInstance.Zone.RUNE_DECK
		rune_deck.append(rune)

	return true

# Recycle runes to the bottom of the rune deck (FIFO "bottom")
func recycle_runes_to_bottom(rune: RuneInstance) -> void:
	if rune_pool.has(rune):
		rune_pool.erase(rune)

	rune.awaken()
	rune.zone = RuneInstance.Zone.RUNE_DECK
	rune_deck.append(rune)
