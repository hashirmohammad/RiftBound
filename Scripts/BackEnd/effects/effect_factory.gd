class_name EffectFactory

static func make_assault(state: GameState, source_uid: int, value: int, expiry := EffectInstance.ExpiryTiming.PERMANENT) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.ASSAULT
	e.source_uid = source_uid
	e.value = value
	e.expiry = expiry
	return e

static func make_shield(state: GameState, source_uid: int, value: int, expiry := EffectInstance.ExpiryTiming.PERMANENT) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.SHIELD
	e.source_uid = source_uid
	e.value = value
	e.expiry = expiry
	return e

static func make_buff(state: GameState, source_uid: int, value: int, expiry := EffectInstance.ExpiryTiming.PERMANENT) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.BUFF
	e.source_uid = source_uid
	e.value = value
	e.expiry = expiry
	return e

static func make_stun(state: GameState, source_uid: int, expiry := EffectInstance.ExpiryTiming.END_OF_TURN) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.STUN
	e.source_uid = source_uid
	e.expiry = expiry
	return e

static func make_tank(state: GameState, source_uid: int) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.TANK
	e.source_uid = source_uid
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT
	return e

static func make_ganking(
		state: GameState,
		source_uid: int,
		expiry := EffectInstance.ExpiryTiming.PERMANENT
) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.GANKING
	e.source_uid = source_uid
	e.expiry = expiry
	return e

static func make_deflect(state: GameState, source_uid: int, value: int, expiry := EffectInstance.ExpiryTiming.PERMANENT) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.DEFLECT
	e.source_uid = source_uid
	e.value = value
	e.expiry = expiry
	return e

static func make_deathknell(state: GameState, source_uid: int, trigger_fn: Callable) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.DEATHKNELL
	e.source_uid = source_uid
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT
	e.trigger_event = EffectEvents.ON_DEATH
	e.trigger_fn = trigger_fn
	return e

static func make_vision(state: GameState, source_uid: int, trigger_event: String, trigger_fn: Callable) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.VISION
	e.source_uid = source_uid
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT
	e.trigger_event = trigger_event
	e.trigger_fn = trigger_fn
	return e

static func make_action_ability(state: GameState, source_uid: int, ability_fn: Callable) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.ACTION
	e.source_uid = source_uid
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT
	e.timing_window = "action"
	e.ability_fn = ability_fn
	return e

static func make_reaction_ability(state: GameState, source_uid: int, ability_fn: Callable) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = state.next_uid()
	e.effect_type = EffectInstance.EffectType.REACTION
	e.source_uid = source_uid
	e.expiry = EffectInstance.ExpiryTiming.PERMANENT
	e.timing_window = "reaction"
	e.ability_fn = ability_fn
	return e
	
