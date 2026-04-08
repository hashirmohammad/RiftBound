## BackendTests — Tests for all backend MVP changes.
##
## HOW TO LOAD IN GODOT:
##   1. In the FileSystem panel, right-click the Scenes/ folder → New Scene
##   2. Choose "Other Node" as root, select Node2D, name it "BackendTestScene"
##   3. Save as Scenes/BackendTestScene.tscn
##   4. With the root node selected, drag this script onto the Inspector → Script field
##      (or click the Script icon and choose "Load" → Scripts/backend_tests.gd)
##   5. Hit F6 (Play Scene) — do NOT use F5 (Play Project), that runs the main game
##   6. Check the Output panel at the bottom of the editor
##   7. All lines should show [PASS]. Any [FAIL] line shows what broke and why.

extends Node2D

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n==============================")
	print("  RIFTBOUND BACKEND TEST SUITE")
	print("==============================\n")

	# --- CardData ---
	test_card_type_enum_has_battlefield_and_legend()
	test_type_from_string_all_types()

	# --- CardInstance ---
	test_card_instance_health_init()
	test_card_instance_take_damage()
	test_card_instance_is_dead()
	test_card_instance_is_dead_ignores_zero_health_cards()
	test_card_instance_reset_health()

	# --- PlayerState runes ---
	test_spend_runes_exhausts_in_pool()
	test_spend_runes_rejects_already_exhausted()
	test_spend_runes_rejects_missing_rune()

	# --- GameState battlefield control ---
	test_init_battlefield_control()
	test_set_battlefield_control_awards_point()
	test_set_battlefield_control_no_double_point()

	# --- Full game setup ---
	test_start_game_initializes_state()
	test_start_game_reaches_main_phase()

	# --- PlayCardAction ---
	test_play_unit_goes_to_board()
	test_play_spell_goes_to_trash()
	test_play_blocked_types_rejected()

	# --- CombatResolver ---
	test_combat_uncontested_p0_wins()
	test_combat_uncontested_p1_wins()
	test_combat_damage_kills_weaker_unit()
	test_combat_tie_no_control_change()

	print("\n==============================")
	print("  RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	print("==============================\n")


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────

func pass_test(name: String) -> void:
	_pass_count += 1
	print("[PASS] %s" % name)


func fail_test(name: String, reason: String) -> void:
	_fail_count += 1
	print("[FAIL] %s — %s" % [name, reason])


func _make_card_data(type_str: String, might: int = 3, health: int = 4, cost: int = 1) -> CardData:
	var d := CardData.new()
	d.card_name = "Test_%s" % type_str
	d.type      = CardData.type_from_string(type_str)
	d.might     = might
	d.health    = health
	d.cost      = cost
	d.rune      = CardData.Rune.FURY
	return d


func _make_state_at_main() -> GameState:
	var state: GameState = GameEngine.start_game()
	# wait_until_main equivalent — synchronous spin (game starts at MAIN already in tests)
	var guard: int = 0
	while state.phase != "MAIN" and guard < 1000:
		guard += 1
	return state


# ─────────────────────────────────────────────
# CARD DATA TESTS
# ─────────────────────────────────────────────

func test_card_type_enum_has_battlefield_and_legend() -> void:
	var name := "CardType enum includes BATTLEFIELD and LEGEND"
	if CardData.CardType.BATTLEFIELD == null:
		fail_test(name, "BATTLEFIELD missing")
		return
	if CardData.CardType.LEGEND == null:
		fail_test(name, "LEGEND missing")
		return
	pass_test(name)


func test_type_from_string_all_types() -> void:
	var name := "type_from_string handles all JSON type strings"
	var cases := {
		"Unit":         CardData.CardType.UNIT,
		"Spell":        CardData.CardType.SPELL,
		"Rune":         CardData.CardType.RUNE,
		"Basic Rune":   CardData.CardType.RUNE,
		"Champion":     CardData.CardType.CHAMPION,
		"Champion Unit":CardData.CardType.CHAMPION,
		"Gear":         CardData.CardType.GEAR,
		"Battlefield":  CardData.CardType.BATTLEFIELD,
		"Legend":       CardData.CardType.LEGEND,
	}
	for input in cases:
		var expected: int = cases[input]
		var got: int = CardData.type_from_string(input)
		if got != expected:
			fail_test(name, '"%s" → %d, expected %d' % [input, got, expected])
			return
	pass_test(name)


# ─────────────────────────────────────────────
# CARD INSTANCE TESTS
# ─────────────────────────────────────────────

func test_card_instance_health_init() -> void:
	var name := "CardInstance initializes current_health from data.health"
	var data := _make_card_data("Unit", 3, 5)
	var inst  := CardInstance.new(1, data)
	if inst.current_health != 5:
		fail_test(name, "current_health=%d, expected 5" % inst.current_health)
	else:
		pass_test(name)


func test_card_instance_take_damage() -> void:
	var name := "CardInstance.take_damage() reduces health, floors at 0"
	var data := _make_card_data("Unit", 3, 4)
	var inst  := CardInstance.new(1, data)
	inst.take_damage(3)
	if inst.current_health != 1:
		fail_test(name, "after 3 dmg, health=%d expected 1" % inst.current_health)
		return
	inst.take_damage(10)
	if inst.current_health != 0:
		fail_test(name, "after excess dmg, health=%d expected 0" % inst.current_health)
	else:
		pass_test(name)


func test_card_instance_is_dead() -> void:
	var name := "CardInstance.is_dead() returns true only when health reaches 0"
	var data := _make_card_data("Unit", 3, 2)
	var inst  := CardInstance.new(1, data)
	if inst.is_dead():
		fail_test(name, "is_dead() true at full health")
		return
	inst.take_damage(2)
	if not inst.is_dead():
		fail_test(name, "is_dead() false after lethal damage")
	else:
		pass_test(name)


func test_card_instance_is_dead_ignores_zero_health_cards() -> void:
	var name := "CardInstance.is_dead() returns false for Spell (health=0)"
	var data := _make_card_data("Spell", 0, 0)
	var inst  := CardInstance.new(1, data)
	if inst.is_dead():
		fail_test(name, "Spell with health=0 reported as dead on creation")
	else:
		pass_test(name)


func test_card_instance_reset_health() -> void:
	var name := "CardInstance.reset_health() restores to data.health"
	var data := _make_card_data("Unit", 3, 6)
	var inst  := CardInstance.new(1, data)
	inst.take_damage(4)
	inst.reset_health()
	if inst.current_health != 6:
		fail_test(name, "after reset, health=%d expected 6" % inst.current_health)
	else:
		pass_test(name)


# ─────────────────────────────────────────────
# PLAYER STATE RUNE TESTS
# ─────────────────────────────────────────────

func _make_player_with_runes(count: int) -> PlayerState:
	var p := PlayerState.new(0)
	var rune_data := _make_card_data("Basic Rune", 0, 0, 0)
	for i in range(count):
		var r := RuneInstance.new(i + 100, rune_data)
		r.zone = RuneInstance.Zone.RUNE_POOL
		p.rune_pool.append(r)
	return p


func test_spend_runes_exhausts_in_pool() -> void:
	var name := "spend_runes() exhausts runes in place, keeps them in pool"
	var p := _make_player_with_runes(3)
	var to_spend: Array[RuneInstance] = [p.rune_pool[0], p.rune_pool[1]]
	var ok := p.spend_runes(to_spend)
	if not ok:
		fail_test(name, "spend_runes() returned false")
		return
	if p.rune_pool.size() != 3:
		fail_test(name, "rune_pool shrank to %d, expected 3" % p.rune_pool.size())
		return
	if not p.rune_pool[0].is_exhausted() or not p.rune_pool[1].is_exhausted():
		fail_test(name, "spent runes not exhausted")
	elif p.rune_pool[2].is_exhausted():
		fail_test(name, "unspent rune was exhausted")
	else:
		pass_test(name)


func test_spend_runes_rejects_already_exhausted() -> void:
	var name := "spend_runes() rejects an already-exhausted rune"
	var p := _make_player_with_runes(2)
	p.rune_pool[0].exhaust()
	var to_spend: Array[RuneInstance] = [p.rune_pool[0]]
	var ok := p.spend_runes(to_spend)
	if ok:
		fail_test(name, "spend_runes() accepted an exhausted rune")
	else:
		pass_test(name)


func test_spend_runes_rejects_missing_rune() -> void:
	var name := "spend_runes() rejects a rune not in the pool"
	var p := _make_player_with_runes(1)
	var rune_data := _make_card_data("Basic Rune", 0, 0, 0)
	var ghost := RuneInstance.new(999, rune_data)  # not added to pool
	var to_spend: Array[RuneInstance] = [ghost]
	var ok := p.spend_runes(to_spend)
	if ok:
		fail_test(name, "spend_runes() accepted a rune not in the pool")
	else:
		pass_test(name)


# ─────────────────────────────────────────────
# GAME STATE BATTLEFIELD CONTROL TESTS
# ─────────────────────────────────────────────

func test_init_battlefield_control() -> void:
	var name := "init_battlefield_control() creates correct-sized array of NO_CONTROL"
	var state := GameState.new()
	state.players = [PlayerState.new(0), PlayerState.new(1)]
	state.init_battlefield_control(2)
	if state.battlefield_control.size() != 2:
		fail_test(name, "size=%d expected 2" % state.battlefield_control.size())
		return
	for v in state.battlefield_control:
		if v != GameState.NO_CONTROL:
			fail_test(name, "slot not initialized to NO_CONTROL")
			return
	pass_test(name)


func test_set_battlefield_control_awards_point() -> void:
	var name := "set_battlefield_control() awards 1 point on capture"
	var state := GameState.new()
	state.players = [PlayerState.new(0), PlayerState.new(1)]
	state.init_battlefield_control(2)
	state.set_battlefield_control(0, 0)
	if state.players[0].points != 1:
		fail_test(name, "P0 points=%d expected 1" % state.players[0].points)
	else:
		pass_test(name)


func test_set_battlefield_control_no_double_point() -> void:
	var name := "set_battlefield_control() does not award point if already controlled"
	var state := GameState.new()
	state.players = [PlayerState.new(0), PlayerState.new(1)]
	state.init_battlefield_control(2)
	state.set_battlefield_control(0, 0)
	state.set_battlefield_control(0, 0)  # same player again
	if state.players[0].points != 1:
		fail_test(name, "P0 points=%d expected 1 (got double-awarded)" % state.players[0].points)
	else:
		pass_test(name)


# ─────────────────────────────────────────────
# FULL GAME SETUP TESTS
# ─────────────────────────────────────────────

func test_start_game_initializes_state() -> void:
	var name := "GameEngine.start_game() produces valid state"
	var state: GameState = GameEngine.start_game()
	if state == null:
		fail_test(name, "state is null")
		return
	if state.players.size() != 2:
		fail_test(name, "players.size()=%d expected 2" % state.players.size())
		return
	var p0: PlayerState = state.players[0]
	var p1: PlayerState = state.players[1]
	if p0.deck.is_empty():
		fail_test(name, "P0 deck is empty")
		return
	if p1.rune_deck.is_empty() and p1.rune_pool.is_empty():
		fail_test(name, "P1 has no runes at all")
		return
	if p0.legend == null:
		fail_test(name, "P0 legend is null")
		return
	pass_test(name)


func test_start_game_reaches_main_phase() -> void:
	var name := "Game starts and reaches MAIN phase"
	var state: GameState = GameEngine.start_game()
	if state.phase != "MAIN":
		fail_test(name, "phase='%s' expected 'MAIN'" % state.phase)
	else:
		pass_test(name)


# ─────────────────────────────────────────────
# PLAY CARD ACTION TESTS
# ─────────────────────────────────────────────

func _get_first_unit_in_hand(state: GameState) -> CardInstance:
	var p: PlayerState = state.get_active_player()
	for card in p.hand:
		if card.data.type == CardData.CardType.UNIT or card.data.type == CardData.CardType.CHAMPION:
			return card
	return null


func _inject_card_into_hand(state: GameState, type_str: String, might: int = 2, health: int = 3, cost: int = 0) -> CardInstance:
	var p: PlayerState = state.get_active_player()
	var data := _make_card_data(type_str, might, health, cost)
	var inst := CardInstance.new(state.next_uid(), data)
	inst.zone = CardInstance.Zone.HAND
	p.hand.append(inst)
	return inst


func test_play_unit_goes_to_board() -> void:
	var name := "PlayCardAction: Unit goes to board_slots, not trash"
	var state: GameState = GameEngine.start_game()
	var card := _inject_card_into_hand(state, "Unit", 2, 3, 0)
	var action := PlayCardAction.new(state.get_active_player().id, card.uid, 0)
	var ok := GameEngine.apply_action(state, action)
	if not ok:
		fail_test(name, "action rejected: %s" % action.get_error_message())
		return
	var p: PlayerState = state.players[0]
	if not p.board_slots[0].has(card):
		fail_test(name, "unit not found in board_slots[0]")
	elif p.trash.has(card):
		fail_test(name, "unit ended up in trash")
	else:
		pass_test(name)


func test_play_spell_goes_to_trash() -> void:
	var name := "PlayCardAction: Spell goes to trash, not board"
	var state: GameState = GameEngine.start_game()
	var card := _inject_card_into_hand(state, "Spell", 0, 0, 0)
	var action := PlayCardAction.new(state.get_active_player().id, card.uid, -1)
	var ok := GameEngine.apply_action(state, action)
	if not ok:
		fail_test(name, "action rejected: %s" % action.get_error_message())
		return
	var p: PlayerState = state.players[0]
	if not p.trash.has(card):
		fail_test(name, "spell not in trash")
	else:
		pass_test(name)


func test_play_blocked_types_rejected() -> void:
	var name := "PlayCardAction: Rune/Battlefield/Legend rejected from hand"
	var state: GameState = GameEngine.start_game()
	var blocked := ["Basic Rune", "Battlefield", "Legend"]
	for type_str in blocked:
		var card := _inject_card_into_hand(state, type_str, 0, 0, 0)
		var action := PlayCardAction.new(state.get_active_player().id, card.uid, 0)
		var ok := GameEngine.apply_action(state, action)
		if ok:
			fail_test(name, '"%s" was accepted but should be blocked' % type_str)
			return
		# Clean up injected card from hand
		state.get_active_player().hand.erase(card)
	pass_test(name)


# ─────────────────────────────────────────────
# COMBAT RESOLVER TESTS
# ─────────────────────────────────────────────

func _make_combat_state() -> GameState:
	var state := GameState.new()
	state.turn_system = PlayerTurn.new()
	state.players = [PlayerState.new(0), PlayerState.new(1)]
	state.init_battlefield_control(2)
	state.turn_number = 1
	state.phase = "SHOWDOWN"
	return state


func _add_unit_to_battlefield(state: GameState, player_id: int, slot: int, might: int, health: int) -> CardInstance:
	var data := _make_card_data("Unit", might, health, 0)
	var inst  := CardInstance.new(state.next_uid(), data)
	inst.zone = CardInstance.Zone.ARENA
	state.players[player_id].battlefield_slots[slot].append(inst)
	return inst


func test_combat_uncontested_p0_wins() -> void:
	var name := "CombatResolver: P0 wins slot 0 uncontested when P1 has no units"
	var state := _make_combat_state()
	_add_unit_to_battlefield(state, 0, 0, 3, 4)
	CombatResolver.resolve(state)
	if state.battlefield_control[0] != 0:
		fail_test(name, "control=%d expected 0" % state.battlefield_control[0])
	elif state.players[0].points != 1:
		fail_test(name, "P0 points=%d expected 1" % state.players[0].points)
	else:
		pass_test(name)


func test_combat_uncontested_p1_wins() -> void:
	var name := "CombatResolver: P1 wins slot 1 uncontested when P0 has no units"
	var state := _make_combat_state()
	_add_unit_to_battlefield(state, 1, 1, 2, 3)
	CombatResolver.resolve(state)
	if state.battlefield_control[1] != 1:
		fail_test(name, "control=%d expected 1" % state.battlefield_control[1])
	elif state.players[1].points != 1:
		fail_test(name, "P1 points=%d expected 1" % state.players[1].points)
	else:
		pass_test(name)


func test_combat_damage_kills_weaker_unit() -> void:
	var name := "CombatResolver: higher-might unit wins, weaker unit goes to trash"
	var state := _make_combat_state()
	var strong := _add_unit_to_battlefield(state, 0, 0, 5, 6)  # P0: 5 might, 6 health
	var weak   := _add_unit_to_battlefield(state, 1, 0, 1, 2)  # P1: 1 might, 2 health
	# P0 deals 5 dmg to P1's unit (health 2 → dead)
	# P1 deals 1 dmg to P0's unit (health 6 → 5, survives)
	CombatResolver.resolve(state)
	if not state.players[1].trash.has(weak):
		fail_test(name, "weak unit not in P1 trash")
		return
	if state.players[0].trash.has(strong):
		fail_test(name, "strong unit incorrectly sent to trash")
		return
	if state.battlefield_control[0] != 0:
		fail_test(name, "P0 should control slot 0, control=%d" % state.battlefield_control[0])
	else:
		pass_test(name)


func test_combat_tie_no_control_change() -> void:
	var name := "CombatResolver: mutual wipe leaves control unchanged"
	var state := _make_combat_state()
	# Both units kill each other exactly
	_add_unit_to_battlefield(state, 0, 0, 3, 3)
	_add_unit_to_battlefield(state, 1, 0, 3, 3)
	CombatResolver.resolve(state)
	if state.battlefield_control[0] != GameState.NO_CONTROL:
		fail_test(name, "control changed on mutual wipe, control=%d" % state.battlefield_control[0])
	elif state.players[0].points != 0 or state.players[1].points != 0:
		fail_test(name, "points awarded on mutual wipe")
	else:
		pass_test(name)
