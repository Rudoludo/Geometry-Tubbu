extends Node
## Logical sound ID -> AudioStream registry. Autoload "AudioRegistry".
##
## Asset-abstraction rule (PLAN.md): gameplay code never loads audio files —
## it asks for a sound by *ID*. Swapping placeholder audio for Ludo's real
## assets means editing this registry only, nothing in feature code.
##
## Unknown IDs warn and return [member fallback_stream] (null for now): an
## audio lookup must never crash gameplay. Stub: the path table stays empty
## until CP 4.2 (SFX) / CP 4.3 (music) fill it.

## ID -> "res://..." stream path. Populated in CP 4.2 / CP 4.3.
const _STREAM_PATHS: Dictionary = {
	# &"sfx_fire": "res://assets/audio/sfx/fire.wav",
}

var _cache: Dictionary = {}             # StringName -> AudioStream (lazy-loaded)
var fallback_stream: AudioStream = null # returned for unknown IDs

## Returns the stream for an ID, or the fallback if unknown (never errors).
func get_stream(sound_id: StringName) -> AudioStream:
	if _cache.has(sound_id):
		return _cache[sound_id]
	if _STREAM_PATHS.has(sound_id):
		var stream: AudioStream = load(_STREAM_PATHS[sound_id])
		_cache[sound_id] = stream
		return stream
	push_warning("AudioRegistry: unknown sound id '%s' -> fallback" % sound_id)
	return fallback_stream

func has_sound(sound_id: StringName) -> bool:
	return _cache.has(sound_id) or _STREAM_PATHS.has(sound_id)

## Runtime registration: generated/placeholder audio, and tests.
func register(sound_id: StringName, stream: AudioStream) -> void:
	_cache[sound_id] = stream
