class_name GameFlow
extends Node
## Top-level run flow (CP 2.1). Owns the pure GameStateMachine and turns its
## transitions into scene wiring: the Title stub, the live Game, the Death stub.
## Replaces the CP 0.2 "boot straight into Game" shim — Game is now built lazily
## when a run starts, not on boot.
##
## Menu input goes through a PlayerInput like everything else (co-op input rule):
## the `restart` action (R / Start) doubles as "advance" on the stub screens
## until CP 4.4 builds real, themed menus.

const GAME_SCENE: PackedScene = preload("res://game/game.tscn")

var _machine := GameStateMachine.new()
var _input := PlayerInput.for_keyboard_mouse()  # menu / advance input
var _game: Game = null            # built on the first run, reused across deaths
var _overlay: CanvasLayer = null  # the current stub screen (title / death)


func _ready() -> void:
	print("Geometry Tubbu — boot OK")
	_machine.state_changed.connect(_on_state_changed)
	# A `start-run` user flag boots straight into a run, so the headless smoke
	# test can exercise the live Game (boot otherwise rests on the Title stub).
	_machine.transition_to(GameStateMachine.State.TITLE)
	if "start-run" in OS.get_cmdline_user_args():
		_machine.transition_to(GameStateMachine.State.IN_RUN)


func _process(_delta: float) -> void:
	_input.update()
	if not _input.is_restart_just_pressed():
		return
	# On the stub screens the restart edge means "advance": Title begins a run,
	# Death restarts one. It does nothing mid-run (you must die to retry).
	match _machine.state():
		GameStateMachine.State.TITLE:
			_machine.transition_to(GameStateMachine.State.IN_RUN)
		GameStateMachine.State.DEATH:
			_machine.transition_to(GameStateMachine.State.IN_RUN)


func _on_state_changed(_from: GameStateMachine.State, to: GameStateMachine.State) -> void:
	match to:
		GameStateMachine.State.TITLE:
			_show_overlay("GEOMETRY TUBBU", "press  R / Start  to begin")
		GameStateMachine.State.IN_RUN:
			_clear_overlay()
			_enter_run()
		GameStateMachine.State.DEATH:
			_show_overlay("YOU DIED",
				"rooms cleared: %d\npress  R / Start  to retry" % RunState.room_index)
		_:
			pass  # ROOM_TRANSITION / RUN_END land in later checkpoints


## First run builds the Game; later runs (a death-screen retry) reset it in
## place, so retry stays instant (CP 1.4 feel) and live debug tuning survives.
func _enter_run() -> void:
	if _game == null:
		_game = GAME_SCENE.instantiate()
		_game.debug = OS.is_debug_build()  # the sandbox panel is debug-only now
		_game.run_lost.connect(_on_run_lost)
		add_child(_game)
	else:
		_game.reset_run()
	RunState.start_new_run()


func _on_run_lost() -> void:
	_machine.transition_to(GameStateMachine.State.DEATH)


## A dimmed full-screen stub with a title + hint. Lives under GameFlow (not
## Game), so it survives across runs and processes while the world is frozen
## behind it. Plain controls on purpose — CP 4.4 builds the real themed menus.
func _show_overlay(title: String, hint: String) -> void:
	_clear_overlay()
	_overlay = CanvasLayer.new()
	_overlay.layer = 50  # above the HUD and the debug panel
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	box.add_child(title_label)
	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)
	add_child(_overlay)


func _clear_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
