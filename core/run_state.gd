extends Node
## The serializable state of one run. Autoload "RunState" (named in the project
## layout, Conventions). One run = one seed plus everything earned in it; kept
## serializable from the start so save/resume (CP 3.8) and the run summary
## (CP 2.8) have a stable shape to read. Reset + round-trip are unit-tested.
##
## Co-op note: shields are a single pool for v1 (player 0). Per-player shields
## are a CP 2.7 / co-op concern; this becomes player-indexed when that lands.

const SCHEMA_VERSION := 1

## The run's RNG seed — feeds the room/reward sequencer (CP 2.3) so a run is
## reproducible. Named run_seed, not seed: seed() is a GDScript built-in.
var run_seed: int = 0
var room_index: int = 0
## Upgrade ids taken this run, in pick order (UpgradeDef ids land CP 2.4).
var taken_upgrades: Array[StringName] = []
## Shield charges carried — earned via upgrades, spent on hits (CP 2.7).
var shields: int = 0


## Begins a fresh run. An explicit seed keeps tests deterministic; the flow
## passes a random one when starting from the title.
func start_new_run(seed_value: int = randi()) -> void:
	run_seed = seed_value
	room_index = 0
	taken_upgrades = []
	shields = 0


## Serializable snapshot — plain types only, so it survives a JSON round-trip to
## disk (CP 3.8). StringName upgrade ids degrade to String there and come back
## as StringNames via [method from_dict].
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"run_seed": run_seed,
		"room_index": room_index,
		"taken_upgrades": _upgrades_as_strings(),
		"shields": shields,
	}


func from_dict(data: Dictionary) -> void:
	run_seed = int(data.get("run_seed", 0))
	room_index = int(data.get("room_index", 0))
	shields = int(data.get("shields", 0))
	taken_upgrades.clear()
	for id in data.get("taken_upgrades", []):
		taken_upgrades.append(StringName(id))


func _upgrades_as_strings() -> Array:
	var out: Array = []
	for id in taken_upgrades:
		out.append(String(id))
	return out
