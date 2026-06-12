extends Node
## Persistent meta progress. Autoload "SaveStore".
##
## Cosmetics-only meta (DESIGN.md): high scores, unlocked skins/feats. Stub:
## a versioned in-memory schema so CP 3.7 (unlocks, per-skin scores) has a
## stable target; real user:// I/O, corrupt-file fallback and schema migration
## land in CP 3.8.

const SCHEMA_VERSION := 1

var _data: Dictionary = {
	"schema_version": SCHEMA_VERSION,
	"high_scores": {},  # skin_id (String) -> int — per-skin boards (CP 3.7)
	"unlocks": [],      # unlocked skin/feat ids (String)
}

func get_data() -> Dictionary:
	return _data

func load_game() -> void:
	pass  # CP 3.8

func save_game() -> void:
	pass  # CP 3.8
