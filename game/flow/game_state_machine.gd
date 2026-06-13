class_name GameStateMachine
extends RefCounted
## The pure game-flow state machine (CP 2.1). Holds the current high-level state
## and the table of legal transitions; emits [signal state_changed] when one is
## taken. No nodes, no scene knowledge — GameFlow owns that wiring and reacts to
## the signal. Kept pure so the whole transition graph is unit-tested (the
## project's testing rule), exactly like WarpGrid / IdleAnimation / ScreenShake.
##
## States:
##   BOOT             - first frame, before anything is shown
##   TITLE            - title / menu (a stub until CP 4.4)
##   IN_RUN           - a run is being played (the Game scene is live)
##   ROOM_TRANSITION  - between rooms (door pick / hand-off; driven CP 2.2-2.3)
##   DEATH            - run lost; death screen (you restart from here)
##   RUN_END          - run finished (victory / summary; driven CP 2.8 / 3.6)

enum State { BOOT, TITLE, IN_RUN, ROOM_TRANSITION, DEATH, RUN_END }

signal state_changed(from: State, to: State)

## Legal next states per state. The flow controller may only request these;
## anything else is a programmer error (rejected, state unchanged). Permissive
## where the design needs it, closed everywhere else — later checkpoints drive
## the transitions whose triggers don't exist yet (rooms, victory).
const _TRANSITIONS := {
	State.BOOT: [State.TITLE],
	State.TITLE: [State.IN_RUN],
	State.IN_RUN: [State.ROOM_TRANSITION, State.DEATH, State.RUN_END],
	State.ROOM_TRANSITION: [State.IN_RUN, State.RUN_END],
	State.DEATH: [State.IN_RUN, State.TITLE, State.RUN_END],
	State.RUN_END: [State.TITLE, State.IN_RUN],
}

var _state: State = State.BOOT


func state() -> State:
	return _state


func can_transition_to(to: State) -> bool:
	return to in _TRANSITIONS[_state]


## Requests a transition. Returns whether it was legal (and thus taken); an
## illegal request is a no-op so a wiring bug can't silently corrupt the state.
func transition_to(to: State) -> bool:
	if not can_transition_to(to):
		push_warning("GameStateMachine: illegal transition %s -> %s" % [
			State.keys()[_state], State.keys()[to]])
		return false
	var from := _state
	_state = to
	state_changed.emit(from, to)
	return true
