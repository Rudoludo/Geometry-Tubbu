extends GutTest
## GameStateMachine (CP 2.1): the legal-transition table and current-state
## tracking. Pure logic — the scene wiring it drives is GameFlow's, boot-tested.

const S := GameStateMachine.State


func test_starts_in_boot() -> void:
	var m := GameStateMachine.new()
	assert_eq(m.state(), S.BOOT)


func test_legal_transition_changes_state_and_signals() -> void:
	var m := GameStateMachine.new()
	watch_signals(m)
	assert_true(m.transition_to(S.TITLE))
	assert_eq(m.state(), S.TITLE)
	assert_signal_emitted_with_parameters(m, "state_changed", [S.BOOT, S.TITLE])


func test_illegal_transition_is_rejected() -> void:
	var m := GameStateMachine.new()
	watch_signals(m)
	assert_false(m.transition_to(S.DEATH), "BOOT cannot jump straight to DEATH")
	assert_eq(m.state(), S.BOOT, "state is unchanged after an illegal request")
	assert_signal_not_emitted(m, "state_changed")


func test_can_transition_to_matches_table() -> void:
	var m := GameStateMachine.new()
	assert_true(m.can_transition_to(S.TITLE))
	assert_false(m.can_transition_to(S.IN_RUN), "no skipping the title from boot")


func test_full_run_loop_path() -> void:
	# Boot -> Title -> run -> death -> retry: the CP 2.1 happy path.
	var m := GameStateMachine.new()
	assert_true(m.transition_to(S.TITLE))
	assert_true(m.transition_to(S.IN_RUN))
	assert_true(m.transition_to(S.DEATH))
	assert_true(m.transition_to(S.IN_RUN), "the death screen restarts into a run")
	assert_eq(m.state(), S.IN_RUN)


func test_room_transition_and_run_end_paths() -> void:
	# The transitions later checkpoints drive (rooms, victory) are legal now.
	var m := GameStateMachine.new()
	m.transition_to(S.TITLE)
	m.transition_to(S.IN_RUN)
	assert_true(m.transition_to(S.ROOM_TRANSITION))
	assert_true(m.transition_to(S.IN_RUN), "into the next room")
	m.transition_to(S.ROOM_TRANSITION)
	assert_true(m.transition_to(S.RUN_END), "last room -> victory")
	assert_true(m.transition_to(S.TITLE), "summary back to the title")
