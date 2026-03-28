## RiftBound Test Script
## Attach this to a Node2D in a temporary test scene.
##
## HOW TO USE:
##   1. Create a new scene with a Node2D as root
##   2. Attach this script to the root node
##   3. Hit Play
##   4. Check the Output panel
##   5. Delete this scene when done

extends Node2D

const TEST_DECK_NAME := "Jinx"

func _ready() -> void:
	print("=== RIFTBOUND TEST SUITE ===")

	test_load_cards()
	test_load_legend()
	test_load_battlefields()
	test_load_runes()
	test_card_data_fields_from_loaded_card()
	test_card_data_from_dict()

	print("=== TESTS COMPLETE ===")


# -------------------------------------------------------------------
# TEST 1 — CardDatabase loads normal cards from a deck folder
# -------------------------------------------------------------------
func test_load_cards() -> void:
	var cards: Array[CardData] = CardDatabase._load_cards(TEST_DECK_NAME)

	if cards.is_empty():
		print("[FAIL] _load_cards('%s') returned empty" % TEST_DECK_NAME)
		return

	print("[PASS] _load_cards('%s') loaded %d card(s)" % [TEST_DECK_NAME, cards.size()])


# -------------------------------------------------------------------
# TEST 2 — CardDatabase loads legend correctly
# -------------------------------------------------------------------
func test_load_legend() -> void:
	var legend: CardData = CardDatabase._load_legend(TEST_DECK_NAME)

	if legend == null:
		print("[FAIL] _load_legend('%s') returned null" % TEST_DECK_NAME)
		return

	if legend.card_name == "":
		print("[FAIL] _load_legend('%s') returned a legend with empty name" % TEST_DECK_NAME)
		return

	print("[PASS] _load_legend('%s') loaded legend: %s" % [TEST_DECK_NAME, legend.card_name])


# -------------------------------------------------------------------
# TEST 3 — CardDatabase loads battlefields correctly
# -------------------------------------------------------------------
func test_load_battlefields() -> void:
	var battlefields: Array[CardData] = CardDatabase._load_battlefields(TEST_DECK_NAME)

	if battlefields.is_empty():
		print("[FAIL] _load_battlefields('%s') returned empty" % TEST_DECK_NAME)
		return

	print("[PASS] _load_battlefields('%s') loaded %d battlefield card(s)" % [
		TEST_DECK_NAME, battlefields.size()
	])


# -------------------------------------------------------------------
# TEST 4 — CardDatabase loads runes correctly
# -------------------------------------------------------------------
func test_load_runes() -> void:
	var runes: Array[CardData] = CardDatabase._load_runes(TEST_DECK_NAME)

	if runes.is_empty():
		print("[FAIL] _load_runes('%s') returned empty" % TEST_DECK_NAME)
		return

	var passed := true

	for rune_card in runes:
		if rune_card == null:
			print("[FAIL] _load_runes('%s') returned a null entry" % TEST_DECK_NAME)
			passed = false
			continue

		if rune_card.type != CardData.CardType.RUNE:
			print("[FAIL] Rune card has wrong type. Name=%s Type=%s" % [
				rune_card.card_name, str(rune_card.type)
			])
			passed = false

	if passed:
		print("[PASS] _load_runes('%s') loaded %d rune card(s)" % [TEST_DECK_NAME, runes.size()])


# -------------------------------------------------------------------
# TEST 5 — Loaded CardData fields are populated correctly
# -------------------------------------------------------------------
func test_card_data_fields_from_loaded_card() -> void:
	var cards: Array[CardData] = CardDatabase._load_cards(TEST_DECK_NAME)

	if cards.is_empty():
		print("[SKIP] test_card_data_fields_from_loaded_card — no cards loaded")
		return

	var card: CardData = cards[0]
	var passed := true

	if card.card_id == "":
		print("[FAIL] Loaded card has empty card_id")
		passed = false

	if card.card_name == "":
		print("[FAIL] Loaded card has empty card_name")
		passed = false

	if card.cost < 0:
		print("[FAIL] Loaded card has negative cost: %d" % card.cost)
		passed = false

	if card.might < 0:
		print("[FAIL] Loaded card has negative might: %d" % card.might)
		passed = false

	if card.health < 0:
		print("[FAIL] Loaded card has negative health: %d" % card.health)
		passed = false

	if card.image_url == "":
		print("[WARN] Loaded card image_url is empty for %s" % card.card_name)

	if card.type < 0 or card.type > CardData.CardType.GEAR:
		print("[FAIL] Loaded card has invalid type enum value: %s" % str(card.type))
		passed = false

	if card.rune < 0 or card.rune > CardData.Rune.CHAOS:
		print("[FAIL] Loaded card has invalid rune enum value: %s" % str(card.rune))
		passed = false

	if passed:
		print("[PASS] Loaded CardData fields look valid for: %s" % card.card_name)


# -------------------------------------------------------------------
# TEST 6 — CardData.from_dict() creates a valid CardData object
# -------------------------------------------------------------------
func test_card_data_from_dict() -> void:
	var test_dict := {
		"card_id": "TEST-001",
		"set_code": "Test",
		"name": "Test Card",
		"cost": 3,
		"might": 4,
		"health": 2,
		"domain": "Fury",
		"type": "Unit",
		"keywords": ["Dragon", "Noxus"],
		"rules_text": "Test ability text",
		"rarity": "Common",
		"image_url": "https://example.com/test.png"
	}

	var card := CardData.from_dict(test_dict)

	if card == null:
		print("[FAIL] CardData.from_dict() returned null")
		return

	var passed := true

	if card.card_id != "TEST-001":
		print("[FAIL] from_dict() card_id wrong: %s" % card.card_id)
		passed = false

	if card.set_code != "Test":
		print("[FAIL] from_dict() set_code wrong: %s" % card.set_code)
		passed = false

	if card.card_name != "Test Card":
		print("[FAIL] from_dict() card_name wrong: %s" % card.card_name)
		passed = false

	if card.cost != 3:
		print("[FAIL] from_dict() cost wrong: %d" % card.cost)
		passed = false

	if card.might != 4:
		print("[FAIL] from_dict() might wrong: %d" % card.might)
		passed = false

	if card.health != 2:
		print("[FAIL] from_dict() health wrong: %d" % card.health)
		passed = false

	if card.rune != CardData.Rune.FURY:
		print("[FAIL] from_dict() rune wrong: %s" % str(card.rune))
		passed = false

	if card.type != CardData.CardType.UNIT:
		print("[FAIL] from_dict() type wrong: %s" % str(card.type))
		passed = false

	if card.keywords.size() != 2:
		print("[FAIL] from_dict() keywords wrong size: %d" % card.keywords.size())
		passed = false

	if card.rules_text != "Test ability text":
		print("[FAIL] from_dict() rules_text wrong: %s" % card.rules_text)
		passed = false

	if card.image_url != "https://example.com/test.png":
		print("[FAIL] from_dict() image_url wrong: %s" % card.image_url)
		passed = false

	if passed:
		print("[PASS] CardData.from_dict() creates a correct CardData object")
