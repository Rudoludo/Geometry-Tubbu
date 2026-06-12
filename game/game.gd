extends Node2D
## Game scene shell.
##
## CP 1.1: a real bounded arena with neon walls, player 0 flying with the
## acceleration/friction model, and an arena-clamped follow camera. CP 2.1 puts
## the run state machine above this.

const TUBBU_SCENE: PackedScene = preload("res://game/player/tubbu.tscn")
const DEFAULT_SKIN: SkinResource = preload("res://assets/skins/default_skin.tres")
const PALETTE: PaletteResource = preload("res://assets/palettes/default_palette.tres")

var arena: Arena
var camera: ArenaCamera


func _ready() -> void:
	arena = Arena.new()
	arena.palette = PALETTE
	add_child(arena)

	var player := _spawn_player(0)

	# Camera is arena-owned and follows player 0 (co-op frames N players later).
	camera = ArenaCamera.new()
	camera.target = player
	camera.setup_limits(arena.bounds())
	add_child(camera)
	camera.make_current()


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
	tubbu.move_bounds = arena.bounds()
	tubbu.position = arena.bounds().get_center()
	add_child(tubbu)
	EventBus.player_spawned.emit(player_index)
	return tubbu
