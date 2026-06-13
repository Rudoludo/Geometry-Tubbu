extends GutTest
## RunState (CP 2.1): a fresh-run reset and a serialize round-trip. RunState is
## an autoload (one instance), so each test sets its own values first — there's
## no cross-test bleed.


func test_start_new_run_resets_fields() -> void:
	RunState.room_index = 7
	RunState.shields = 3
	RunState.taken_upgrades = [&"old"]
	RunState.start_new_run(12345)
	assert_eq(RunState.run_seed, 12345)
	assert_eq(RunState.room_index, 0)
	assert_eq(RunState.shields, 0)
	assert_eq(RunState.taken_upgrades.size(), 0)


func test_serialize_round_trip_preserves_state() -> void:
	RunState.start_new_run(999)
	RunState.room_index = 4
	RunState.shields = 2
	RunState.taken_upgrades = [&"spread", &"pierce"]
	var snapshot := RunState.to_dict()

	# Clobber, then restore from the snapshot.
	RunState.start_new_run(0)
	RunState.from_dict(snapshot)
	assert_eq(RunState.run_seed, 999)
	assert_eq(RunState.room_index, 4)
	assert_eq(RunState.shields, 2)
	assert_eq(RunState.taken_upgrades, [&"spread", &"pierce"] as Array[StringName])


func test_to_dict_carries_schema_version() -> void:
	RunState.start_new_run(1)
	assert_eq(RunState.to_dict()["schema_version"], RunState.SCHEMA_VERSION)


func test_to_dict_upgrades_are_plain_strings() -> void:
	# The disk format (CP 3.8) is JSON: ids must serialize as String, not StringName.
	RunState.start_new_run(1)
	RunState.taken_upgrades = [&"homing"]
	var ids: Array = RunState.to_dict()["taken_upgrades"]
	assert_eq(typeof(ids[0]), TYPE_STRING)


func test_from_dict_tolerates_missing_keys() -> void:
	RunState.start_new_run(5)
	RunState.from_dict({})  # defaults, no crash
	assert_eq(RunState.run_seed, 0)
	assert_eq(RunState.room_index, 0)
	assert_eq(RunState.taken_upgrades.size(), 0)
