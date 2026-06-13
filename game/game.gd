extends Node2D
## Game scene shell.
##
## CP 1.1: a real bounded arena with neon walls, player 0 flying with the
## acceleration/friction model, and an arena-clamped follow camera. CP 1.4:
## chaser sandbox (spawner + debug panel) and the death → instant-restart
## loop. CP 2.1 puts the run state machine above this.
##
## Input ownership: Game binds devices to players, so Game calls each
## PlayerInput.update() once per frame. Parents process before children, so
## every child (ships, chasers) reads fresh latches — and a dead, non-ticking
## ship still gets its restart edge latched.

const TUBBU_SCENE: PackedScene = preload("res://game/player/tubbu.tscn")
const DEFAULT_SKIN: SkinResource = preload("res://assets/skins/default_skin.tres")
const PALETTE: PaletteResource = preload("res://assets/palettes/default_palette.tres")

var arena: Arena
var camera: ArenaCamera
var bullet_manager: BulletManager
var spawner: SandboxSpawner
var pattern_spawner: PatternSpawner

## Players by index (co-op rule: an array, never a singleton).
var _players: Array[Tubbu] = []


func _ready() -> void:
	arena = Arena.new()
	arena.palette = PALETTE
	add_child(arena)

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

	var debug_panel := DebugPanel.new()
	debug_panel.spawner = spawner
	debug_panel.pattern_spawner = pattern_spawner
	debug_panel.bullet_manager = bullet_manager
	add_child(debug_panel)


func _process(_delta: float) -> void:
	var any_dead := false
	var restart_wanted := false
	for player in _players:
		player.input.update()
		any_dead = any_dead or not player.is_alive()
		restart_wanted = restart_wanted or player.input.is_restart_just_pressed()
	# Restart is only armed by death — no accidental mid-surf wipes. Any
	# player's button restarts everyone (the sandbox is shared).
	if any_dead and restart_wanted:
		_restart()


## The instant-restart loop (CP 1.4): wipe the board, ships fresh at center.
func _restart() -> void:
	bullet_manager.clear()  # wipes both bands — no stray enemy orb kills the revive
	spawner.clear()
	pattern_spawner.clear()
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
	tubbu.move_bounds = arena.bounds()
	tubbu.position = arena.bounds().get_center()
	add_child(tubbu)
	_players.append(tubbu)
	EventBus.player_spawned.emit(player_index)
	return tubbu
