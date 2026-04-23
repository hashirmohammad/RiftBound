class_name SpellRegistry

static var _resolvers: Dictionary = {}
static var _loaded := false

static func get_resolver(card_id: String) -> Callable:
	_ensure_loaded()
	return _resolvers.get(card_id, Callable())

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_populate()

static func _populate() -> void:
	# OGN-047/298 — Find Your Center
	_resolvers["OGN-047/298"] = func(card: CardInstance, state: GameState, payload := {}) -> void:
		var player_id: int = state.get_active_player().id
		EffectResolver.draw_cards(state, player_id, 1)
		EffectResolver.channel_runes_exhausted(state, player_id, 1)
		state.add_event("Find Your Center resolved for P%d." % player_id)
