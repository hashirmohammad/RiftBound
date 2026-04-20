class_name TimingManager
extends RefCounted

# Manages timing windows (ACTION, REACTION, SHOWDOWN) and the REACTION stack.
#
# SHOWDOWN flow:
#   open_showdown() -> players queue ACTIONs and/or REACTIONs
#   -> each queued ACTION executes immediately in the action window
#   -> REACTIONs are pushed onto a LIFO stack
#   -> when both players pass, close_showdown() resolves remaining REACTIONs LIFO
#   -> CombatManager then calls CombatResolver.resolve()
#
# REACTION ordering:
#   Last queued REACTION resolves first (LIFO).
#   A REACTION may set context.is_cancelled = true to prevent combat damage.

enum TimingWindow { NONE, SHOWDOWN }

signal window_opened(window: TimingWindow)
signal window_closed(window: TimingWindow)

var current_window: TimingWindow = TimingWindow.NONE

# LIFO reaction stack — entries: { effect: EffectInstance, source: UnitState, context: CombatContext }
var _reaction_stack: Array[Dictionary] = []

# ── Showdown ──────────────────────────────────────────────────────────────────

func open_showdown(context: CombatContext) -> ShowdownContext:
	assert(current_window == TimingWindow.NONE, "Cannot open showdown: another window is active")
	current_window = TimingWindow.SHOWDOWN
	_reaction_stack.clear()
	var sc := ShowdownContext.new(context)
	window_opened.emit(TimingWindow.SHOWDOWN)
	return sc

func close_showdown(showdown: ShowdownContext) -> void:
	assert(current_window == TimingWindow.SHOWDOWN, "close_showdown called outside of showdown")
	_resolve_reaction_stack(showdown.combat_context)
	current_window = TimingWindow.NONE
	window_closed.emit(TimingWindow.SHOWDOWN)

# ── Action window ─────────────────────────────────────────────────────────────

# Executes an ACTION ability immediately within the current showdown window.
# ACTIONs are proactive — they execute when queued, not on stack resolution.
func queue_action(
		effect: EffectInstance,
		source: UnitState,
		context: CombatContext) -> void:
	assert(current_window == TimingWindow.SHOWDOWN, "ACTION used outside of showdown window")
	assert(effect.timing_window == "action", "Effect is not an ACTION ability")
	if effect.ability_fn.is_valid():
		effect.ability_fn.call(source, context, context.game_state)

# ── Reaction stack ────────────────────────────────────────────────────────────

# Pushes a REACTION onto the stack for LIFO resolution when the showdown closes.
# Resetting the showdown pass state allows the opponent to respond.
func queue_reaction(
		effect: EffectInstance,
		source: UnitState,
		context: CombatContext,
		showdown: ShowdownContext) -> void:
	assert(current_window == TimingWindow.SHOWDOWN, "REACTION used outside of showdown window")
	assert(effect.timing_window == "reaction", "Effect is not a REACTION ability")
	_reaction_stack.push_back({
		"effect": effect,
		"source": source,
		"context": context,
	})
	# A new REACTION reopens the priority window
	showdown.reset_passes()

# ── End-of-turn expiry ────────────────────────────────────────────────────────

func expire_end_of_turn(all_units: Array[UnitState], game_state: GameState) -> void:
	for unit in all_units:
		unit.effects.expire_by_timing(EffectInstance.ExpiryTiming.END_OF_TURN, game_state)

func expire_end_of_phase(all_units: Array[UnitState], game_state: GameState) -> void:
	for unit in all_units:
		unit.effects.expire_by_timing(EffectInstance.ExpiryTiming.END_OF_PHASE, game_state)

# ── Internal ──────────────────────────────────────────────────────────────────

func _resolve_reaction_stack(context: CombatContext) -> void:
	while not _reaction_stack.is_empty():
		var entry: Dictionary = _reaction_stack.pop_back()
		var e: EffectInstance = entry["effect"]
		if e.ability_fn.is_valid():
			e.ability_fn.call(entry["source"], entry["context"], context.game_state)
	_reaction_stack.clear()
