class_name EffectRegistry
extends RefCounted

var _effects: Array[EffectInstance] = []

# ── Mutation ──────────────────────────────────────────────────────────────────

func add(effect: EffectInstance) -> void:
	_effects.append(effect)

func remove_by_uid(effect_uid: int) -> void:
	_effects = _effects.filter(func(e): return e.uid != effect_uid)

func remove_by_source(source_uid: int) -> void:
	_effects = _effects.filter(func(e): return e.source_uid != source_uid)

# Removes one instance of `type`; used by systems that consume charges (e.g. DEFLECT)
func consume_one(type: EffectInstance.EffectType) -> bool:
	for i in range(_effects.size()):
		if _effects[i].effect_type == type:
			_effects.remove_at(i)
			return true
	return false

# ── Stacking queries ──────────────────────────────────────────────────────────

func has_any(type: EffectInstance.EffectType) -> bool:
	for e in _effects:
		if e.effect_type == type:
			return true
	return false

# Additive sum — for ASSAULT, SHIELD, DEFLECT
func sum_of(type: EffectInstance.EffectType) -> int:
	var total := 0
	for e in _effects:
		if e.effect_type == type:
			total += e.value
	return total

# Instance count — used for TANK presence checks and debugging
func count_of(type: EffectInstance.EffectType) -> int:
	var n := 0
	for e in _effects:
		if e.effect_type == type:
			n += 1
	return n

# Non-stacking max — for BUFF (only the highest value contributes)
func max_of(type: EffectInstance.EffectType) -> int:
	var best := 0
	for e in _effects:
		if e.effect_type == type:
			best = maxi(best, e.value)
	return best

# ── Trigger queries ───────────────────────────────────────────────────────────

# Returns all effects whose trigger_event matches `event`
func get_triggered(event: String) -> Array[EffectInstance]:
	var result: Array[EffectInstance] = []
	for e in _effects:
		if e.trigger_event == event:
			result.append(e)
	return result

# ── Expiry ────────────────────────────────────────────────────────────────────

func expire_by_timing(timing: EffectInstance.ExpiryTiming, game_state: GameState) -> void:
	_effects = _effects.filter(func(e): return e.expiry != timing)

# Evaluates CUSTOM expiry predicates; removes effects whose expiry_fn returns true
func expire_custom(game_state: GameState) -> void:
	_effects = _effects.filter(func(e: EffectInstance) -> bool:
		if e.expiry != EffectInstance.ExpiryTiming.CUSTOM:
			return true
		if not e.expiry_fn.is_valid():
			return true
		return not e.expiry_fn.call(game_state)
	)

# ── Inspection ────────────────────────────────────────────────────────────────

func get_all() -> Array[EffectInstance]:
	return _effects.duplicate()

func is_empty() -> bool:
	return _effects.is_empty()
