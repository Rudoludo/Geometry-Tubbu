class_name Game
extends Node2D
## The in-run play scene: arena, player(s), enemies, juice. Built by GameFlow
## when a run starts (CP 2.1) — it no longer self-runs from main.tscn.
##
## CP 1.1: a real bounded arena with neon walls, player 0 flying with the
## acceleration/friction model, and an arena-clamped follow camera. CP 1.4:
## chaser sandbox (spawner + debug panel) and the instant-restart loop. CP 2.1:
## GameFlow owns the run state above this — Game reports the run lost
## ([signal run_lost]) and resets in place on retry ([method reset_run]); the
## sandbox debug panel is gated behind [member debug].
##
## Input ownership: Game binds devices to players, so Game calls each
## PlayerInput.update() once per frame. Parents process before children, so
## every child (ships, chasers) reads fresh latches — and a dead, non-ticking
## ship still gets its restart edge latched.

const TUBBU_SCENE: PackedScene = preload("res://game/player/tubbu.tscn")
const DEFAULT_SKIN: SkinResource = preload("res://assets/skins/default_skin.tres")
const PALETTE: PaletteResource = preload("res://assets/palettes/default_palette.tres")

var arena: Arena
var grid: GridBackground
var camera: ArenaCamera
var bullet_manager: BulletManager
var spawner: SandboxSpawner
var pattern_spawner: PatternSpawner

## Emitted once when the last player dies — GameFlow turns this into the Death
## state. Game itself no longer restarts; the flow drives that (CP 2.1).
signal run_lost

## Debug-only chrome (the sandbox tuning panel). GameFlow sets it from
## OS.is_debug_build(), so it shows in dev and vanishes in release builds.
var debug := false

## Players by index (co-op rule: an array, never a singleton).
var _players: Array[Tubbu] = []
var _run_lost_emitted := false


func _ready() -> void:
	_setup_glow()

	arena = Arena.new()
	arena.palette = PALETTE
	add_child(arena)

	# Reactive warp-grid backdrop (CP 1.7): a spring mesh drawn far behind
	# everything (z -10). It shares the same _players array reference Game fills
	# below — by the time it ripples on a wake/dash/death, player 0 is in it.
	grid = GridBackground.new()
	grid.palette = PALETTE
	grid.players = _players
	grid.setup(arena.bounds())
	add_child(grid)

	# One manager for every projectile in the scene — player shots and (CP 1.5)
	# enemy bullets. It self-sets a high z_index so bullets draw ABOVE the ships:
	# an incoming enemy orb must never hide under your own sprite (one-hit rule).
	bullet_manager = BulletManager.new()
	bullet_manager.palette = PALETTE
	bullet_manager.bounds = arena.bounds()
	add_child(bullet_manager)

	var player := _spawn_player(0)

	# After the players in tree order: chasers steer at (and contact-check)
	# positions the ships updated this same frame.
	spawner = SandboxSpawner.new()
	spawner.players = _players
	spawner.bullet_manager = bullet_manager
	spawner.palette = PALETTE
	spawner.bounds = arena.bounds()
	add_child(spawner)

	# Pattern shooters (Enemy 2): a steady few, weaving patterns under the swarm.
	# Also after the players, so its enemy-bullet→player pass reads fresh ship
	# positions (and fresh bullet positions, since the manager ticked first).
	pattern_spawner = PatternSpawner.new()
	pattern_spawner.players = _players
	pattern_spawner.bullet_manager = bullet_manager
	pattern_spawner.palette = PALETTE
	pattern_spawner.bounds = arena.bounds()
	add_child(pattern_spawner)

	# Camera is arena-owned and follows player 0 (co-op frames N players later).
	camera = ArenaCamera.new()
	camera.target = player
	camera.setup_limits(arena.bounds())
	add_child(camera)
	camera.make_current()

	# Juice (CP 1.6): the crunch on kills/death. Shake lives on the camera; this
	# owns the global time-freeze. Both are settings-scaled and event-driven.
	add_child(HitStop.new())

	# Debug-only sandbox panel (spawn rate + feel knobs). CP 2.1 gates it behind
	# the debug flag so it never shows in a real run / release build.
	if debug:
		var debug_panel := DebugPanel.new()
		debug_panel.spawner = spawner
		debug_panel.pattern_spawner = pattern_spawner
		debug_panel.bullet_manager = bullet_manager
		debug_panel.grid = grid
		debug_panel.players = _players  # CP 1.8 feel knobs write to the live players
		add_child(debug_panel)


func _process(_delta: float) -> void:
	# Game binds the devices, so it ticks every player's PlayerInput here (parents
	# process before children → ships read fresh latches, even a dead one). The
	# flow above owns restart now; Game only reports when the run is lost.
	var any_alive := false
	for player in _players:
		player.input.update()
		any_alive = any_alive or player.is_alive()
	if not any_alive and not _run_lost_emitted and not _players.is_empty():
		_run_lost_emitted = true
		run_lost.emit()


## The instant-restart loop (CP 1.4): wipe the board, ships fresh at center —
## same nodes (so live debug tuning survives), now driven by GameFlow on a
## death-screen retry instead of a sandbox R press.
func reset_run() -> void:
	_run_lost_emitted = false
	bullet_manager.clear()  # wipes both bands — no stray enemy orb kills the revive
	spawner.clear()
	pattern_spawner.clear()
	grid.reset()  # flatten the mesh so the revive starts on a calm board
	for player in _players:
		player.revive(arena.bounds().get_center())


## Co-op rule: players are spawned and addressed by index. Nothing here is
## player-0-specific except the device choice below.
func _spawn_player(player_index: int) -> Tubbu:
	var tubbu: Tubbu = TUBBU_SCENE.instantiate()
	tubbu.player_index = player_index
	# kb+m binding. The move/dash actions also carry device -1 joypad events
	# (project.godot), so in single-player a connected pad drives this binding
	# too; true per-device assignment is the co-op feature, not v1.
	tubbu.input = PlayerInput.for_keyboard_mouse()
	tubbu.skin = DEFAULT_SKIN
	tubbu.bullet_manager = bullet_manager
	tubbu.palette = PALETTE  # muzzle FX reads the bullet color (CP 1.6)
	tubbu.move_bounds = arena.bounds()
	tubbu.position = arena.bounds().get_center()
	add_child(tubbu)
	_players.append(tubbu)
	EventBus.player_spawned.emit(player_index)
	return tubbu


## Neon bloom (CP 1.6): HDR 2D is on (project setting), so only the overbright
## (>1.0) palette/skin colors cross the glow threshold and bloom — the dark
## background and UI stay crisp. First-pass tuning; final look is Ludo's call.
func _setup_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS  # keep the 2D scene as the backdrop
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.0  # only neon (>1.0) blooms
	env.glow_hdr_scale = 2.0
	for level in [1, 2, 3, 4]:
		env.set_glow_level(level, true)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
