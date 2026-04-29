class_name PlayerState

var id: int
var points: int = 0

var deck: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var board: Array[CardInstance] = []
var trash: Array[CardInstance] = []
var battlefields: Array[BattlefieldInstance] = []
var picked_battlefield: BattlefieldInstance
var rune_deck: Array[RuneInstance] = []
var rune_pool: Array[RuneInstance] = []
var legend: CardInstance
var champion: CardInstance
var board_slots: Array = [[], [], [], [], [], [], [], []]
var rune_slots: Array = [[], [], [], [], [], [], [], [], [], [], [], []]

# Two battlefield slots, one for each arena choice.
# battlefield_slots[0] = left / arena 1
# battlefield_slots[1] = right / arena 2
var battlefield_slots: Array = [[], []]

func _init(player_id: int):
	id = player_id

func pick_random_battlefield() -> void:
	var index = randi() % battlefields.size()
	battlefields[index].set_state(BattlefieldInstance.State.USED)
	picked_battlefield = battlefields[index]
	picked_battlefield = battlefields[1]


# ---------- Rune helpers ----------

func rune_count_in_deck() -> int:
	return rune_deck.size()

func rune_count_in_pool() -> int:
	return rune_pool.size()
	
func awaken_rune_count() -> int:
	var count = 0
	for r in rune_pool:
		if not r.is_exhausted():
			count += 1
	return count

func draw_rune() -> Variant:
	if rune_deck.is_empty():
		return null
	var rune: RuneInstance = rune_deck.pop_front()
	return rune

func channel_runes(n: int) -> void:
	for i in range(n):
		var r = draw_rune()
		if r == null:
			return
		r.zone = RuneInstance.Zone.RUNE_POOL
		rune_pool.append(r)

func spend_runes(rune: RuneInstance) -> bool:

	if rune == null:
		return false
	if not rune_pool.has(rune):
		return false

	rune.exhaust()
	return true

func recycle_runes_to_bottom(rune: RuneInstance) -> void:
	if rune_pool.has(rune):
		rune_pool.erase(rune)
	rune.awaken()
	rune.zone = RuneInstance.Zone.RUNE_DECK
	rune_deck.append(rune)
