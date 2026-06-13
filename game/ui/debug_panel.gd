class_name DebugPanel
extends CanvasLayer
## Sandbox tuning surface (CP 1.4): spawn-rate slider + live readouts.
## Debug-only chrome — CP 2.1 moves it behind a debug flag, CP 1.8 grows it
## into the feel-tuning panel. Plain default controls on purpose: the one-Theme
## UI rule applies to real game UI, and this never ships.

var spawner: SandboxSpawner  # injected by Game

var _rate_label: Label
var _count_label: Label


func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.8)
	add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(220.0, 0.0)
	panel.add_child(column)

	_rate_label = Label.new()
	column.add_child(_rate_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 40.0
	slider.step = 0.5
	slider.value = spawner.spawn_rate
	slider.value_changed.connect(_on_rate_changed)
	column.add_child(slider)
	_count_label = Label.new()
	column.add_child(_count_label)
	var hint := Label.new()
	hint.text = "death: R / Start restarts"
	column.add_child(hint)
	_refresh_rate_label()


func _process(_delta: float) -> void:
	_count_label.text = "chasers: %d" % spawner.live_count()


func _on_rate_changed(value: float) -> void:
	spawner.spawn_rate = value
	_refresh_rate_label()


func _refresh_rate_label() -> void:
	_rate_label.text = "spawn rate: %.1f/s" % spawner.spawn_rate
