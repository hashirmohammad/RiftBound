## T6S-24 Test Script
## Attach this to a Node2D in a new test scene to verify
## the card system is working correctly.
##
## HOW TO USE:
##   1. Create a new scene with a Node2D as root
##   2. Attach this script to the root node
##   3. Hit Play — results will print to the Output panel
##   4. Delete this scene when done — do NOT commit it

extends Node2D

func _ready() -> void:
	print("=== T6S-24 TEST SUITE ===")
	test_card_database_loaded()
	test_get_card_by_id()
	test_get_cards_by_type()
	test_get_cards_by_domain()
	test_card_data_fields()
	test_card_data_from_dict()
	print("=== TESTS COMPLETE ===")


## TEST 1 — CardDatabase loads cards from JSON
func test_card_database_loaded() -> void:
	var all_cards = CardDatabase.get_all_cards()
	if all_cards.size() > 0:
		print("[PASS] CardDatabase loaded ", all_cards.size(), " cards from cards.json")
	else:
		print("[FAIL] CardDatabase is empty — check Autoload is registered and cards.json exists")


## TEST 2 — Fetch a specific card by ID
func test_get_card_by_id() -> void:
	var card = CardDatabase.get_card("OGN-001/298")
	if card != null:
		print("[PASS] get_card() — found card: ", card.card_name)
	else:
		print("[FAIL] get_card() — could not find OGN-001/298")


## TEST 3 — Filter cards by type
func test_get_cards_by_type() -> void:
	var units = CardDatabase.get_cards_by_type(CardData.CardType.UNIT)
	if units.size() > 0:
		print("[PASS] get_cards_by_type(UNIT) — found ", units.size(), " units")
	else:
		print("[FAIL] get_cards_by_type(UNIT) — returned empty")


## TEST 4 — Filter cards by domain
func test_get_cards_by_domain() -> void:
	var fury_cards = CardDatabase.get_cards_by_domain(CardData.Domain.FURY)
	if fury_cards.size() > 0:
		print("[PASS] get_cards_by_domain(FURY) — found ", fury_cards.size(), " Fury cards")
	else:
		print("[FAIL] get_cards_by_domain(FURY) — returned empty")


## TEST 5 — CardData fields are populated correctly
func test_card_data_fields() -> void:
	var card = CardDatabase.get_card("OGN-001/298")
	if card == null:
		print("[SKIP] test_card_data_fields — card not found")
		return

	var passed = true

	if card.card_name != "Blazing Scorcher":
		print("[FAIL] card_name expected 'Blazing Scorcher', got: ", card.card_name)
		passed = false

	if card.cost != 5:
		print("[FAIL] cost expected 5, got: ", card.cost)
		passed = false

	if card.might != 5:
		print("[FAIL] might expected 5, got: ", card.might)
		passed = false

	if card.domain != CardData.Domain.FURY:
		print("[FAIL] domain expected FURY, got: ", card.domain)
		passed = false

	if card.image_url == "":
		print("[FAIL] image_url is empty")
		passed = false

	if passed:
		print("[PASS] CardData fields all populated correctly for OGN-001/298")


## TEST 6 — CardData.from_dict() creates a valid CardData object
func test_card_data_from_dict() -> void:
	var test_dict = {
		"card_id": "TEST-001",
		"set_code": "Test",
		"name": "Test Card",
		"cost": 3,
		"might": 4,
		"domain": "Fury",
		"type": "Unit",
		"keywords": ["Dragon", "Noxus"],
		"rules_text": "Test ability text",
		"rarity": "Common",
		"artist": "Test Artist",
		"image_url": "https://example.com/test.png"
	}

	var card = CardData.from_dict(test_dict)

	if card == null:
		print("[FAIL] from_dict() returned null")
		return

	var passed = true

	if card.card_name != "Test Card":
		print("[FAIL] from_dict() card_name wrong: ", card.card_name)
		passed = false

	if card.cost != 3:
		print("[FAIL] from_dict() cost wrong: ", card.cost)
		passed = false

	if card.keywords.size() != 2:
		print("[FAIL] from_dict() keywords wrong size: ", card.keywords.size())
		passed = false

	if card.domain != CardData.Domain.FURY:
		print("[FAIL] from_dict() domain wrong: ", card.domain)
		passed = false

	if passed:
		print("[PASS] CardData.from_dict() creates correct CardData object")
