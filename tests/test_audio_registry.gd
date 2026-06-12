extends GutTest
## AudioRegistry (CP 0.2): unknown-ID lookups warn and fall back — an audio
## lookup must never crash gameplay. Tests instance the script fresh rather
## than poking the autoload singleton.

const AudioRegistryScript := preload("res://core/audio_registry.gd")

var _registry: Node


func before_each() -> void:
	_registry = autofree(AudioRegistryScript.new())


func test_unknown_id_returns_null_fallback() -> void:
	assert_null(_registry.get_stream(&"definitely_not_a_sound"))


func test_unknown_id_returns_custom_fallback() -> void:
	var fallback := AudioStreamGenerator.new()
	_registry.fallback_stream = fallback
	assert_eq(_registry.get_stream(&"definitely_not_a_sound"), fallback)


func test_registered_stream_round_trips() -> void:
	var stream := AudioStreamGenerator.new()
	_registry.register(&"sfx_test", stream)
	assert_true(_registry.has_sound(&"sfx_test"))
	assert_eq(_registry.get_stream(&"sfx_test"), stream)


func test_has_sound_false_for_unknown() -> void:
	assert_false(_registry.has_sound(&"definitely_not_a_sound"))
