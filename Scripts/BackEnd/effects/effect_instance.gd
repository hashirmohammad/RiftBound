class_name EffectInstance
extends RefCounted

enum EffectType {
	# Stackable numeric combat modifiers
	ASSAULT,    # +X Might when attacking only; stacks additively
	SHIELD,     # +X Might when defending only; stacks additively
	# Non-stackable persistent modifier
	BUFF,       # +X Might; only highest value applies; persists until removed
	# State flags
	STUN,       # prevents unit from dealing damage; unit still receives damage normally
	TANK,       # damage must be assigned to this unit before non-TANK units
	GANKING,    # unit may attack ignoring standard positioning rules
	# Spell/ability cost modifier — NOT a combat targeting redirect
	# When an opponent's spell or ability targets a permanent with DEFLECT,
	# that spell/ability costs extra Power equal to the summed DEFLECT value.
	DEFLECT,
	# Hidden zone state — not a combat keyword; see rules note on UnitState
	HIDDEN,
	# Conditional Might bonuses — re-evaluated dynamically each time combat resolves
	MIGHTY,     # +X Might if unit's current base Might exceeds a defined threshold
	LEGION,     # +X Might per ally on board (or similar; condition encoded in condition_fn)
	# Triggered abilities
	DEATHKNELL, # fires when this unit is killed and placed into the trash
	VISION,     # fires when a defined board or game event condition is met
	# Timing-window abilities
	ACTION,     # proactive ability; usable during the player's ACTION window in showdown
	REACTION,   # response ability; usable in response to an event during showdown
}

enum ExpiryTiming {
	PERMANENT,      # never expires automatically
	END_OF_COMBAT,  # removed after combat damage and death resolution complete
	END_OF_TURN,    # removed during the END phase cleanup
	END_OF_PHASE,   # removed when the current phase transitions
	CUSTOM,         # expiry_fn evaluated by EffectRegistry.expire_custom()
}

# Identity
var uid: int
var effect_type: EffectType
var source_uid: int          # uid of the card or ability that created this effect

# Numeric payload — used by ASSAULT, SHIELD, BUFF, DEFLECT, MIGHTY, LEGION
var value: int = 0

# Duration
var expiry: ExpiryTiming = ExpiryTiming.PERMANENT
# Only used when expiry == CUSTOM; returns true when this effect should be removed
# Signature: func(game_state: GameState) -> bool
var expiry_fn: Callable

# Conditional effects (MIGHTY, LEGION)
# Returns true when the bonus in `value` should be applied
# Signature: func(unit: UnitState, game_state: GameState) -> bool
var condition_fn: Callable

# Triggered abilities (DEATHKNELL, VISION)
# trigger_event is a string key matched by EffectRegistry.get_triggered()
# e.g. "on_death", "on_enter_play", "on_attack_declared"
var trigger_event: String = ""
# Signature: func(source_unit: UnitState, game_state: GameState) -> void
var trigger_fn: Callable

# Timing-window abilities (ACTION, REACTION)
# timing_window matches the window name: "action" or "reaction"
var timing_window: String = ""
# Signature: func(source_unit: UnitState, context: CombatContext, game_state: GameState) -> void
var ability_fn: Callable

static func make_triggered(
	p_uid: int,
	p_type: EffectType,
	p_source_uid: int,
	p_trigger_event: String,
	p_trigger_fn: Callable,
	p_expiry: ExpiryTiming = ExpiryTiming.PERMANENT,
	p_value: int = 0
) -> EffectInstance:
	var e := EffectInstance.new()
	e.uid = p_uid
	e.effect_type = p_type
	e.source_uid = p_source_uid
	e.trigger_event = p_trigger_event
	e.trigger_fn = p_trigger_fn
	e.expiry = p_expiry
	e.value = p_value
	return e
