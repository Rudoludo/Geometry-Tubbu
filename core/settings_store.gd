extends Node
## Player-facing settings. Autoload "SettingsStore".
##
## Readability rule (PLAN.md): screenshake / flash / CRT intensities are
## settings-scaled from the moment each effect exists, never retrofitted — so
## the knobs exist before the effects do. Stub: in-memory defaults; disk
## persistence and the settings menu land in CP 3.8 / CP 4.4.
##
## Emits its own [signal changed] rather than relaying via EventBus, so this
## autoload depends on nothing (no autoload->autoload coupling).

signal changed(key: StringName, value: Variant)

# Effect intensities (0..1 scalars; 1.0 = full as authored).
var screenshake_intensity: float = 1.0
var flash_intensity: float = 1.0
var crt_enabled: bool = true
var crt_intensity: float = 0.5

# Audio (0..1). Wired to buses and sliders in CP 4.2 / CP 4.4.
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.9

## Key-based access so menu/persistence code can stay data-driven.
## Keys are the property names above; unknown keys are a programmer error.
func get_value(key: StringName) -> Variant:
	if not key in self:
		push_error("SettingsStore: unknown setting '%s'" % key)
		return null
	return get(key)

func set_value(key: StringName, value: Variant) -> void:
	if not key in self:
		push_error("SettingsStore: unknown setting '%s'" % key)
		return
	if get(key) == value:
		return
	set(key, value)
	changed.emit(key, value)
