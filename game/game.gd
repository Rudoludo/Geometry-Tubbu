extends Node2D
## Game scene shell (CP 0.2): a placeholder rect arena and player 0 with a
## bound PlayerInput — proves the input/skin/palette spine end-to-end.
## CP 1.1 makes the arena real; CP 2.1 puts the run state machine above this.

const TUBBU_SCENE: PackedScene = preload("res://game/player/tubbu.tscn")
const DEFAULT_SKIN: SkinResource = preload("res://assets/skins/default_skin.tres")
const PALETTE: PaletteResource = preload("res://assets/palettes/default_palette.tres")

## Placeholder: viewport-sized with a margin. CP 1.1 owns real arena bounds.
const ARENA_RECT := Rect2(40, 40, 1200, 640)


func _ready() -> void:
	_spawn_player(0)


## Co-op rule: players are spawned and addressed by index. Nothing here is
## player-0-specific except the device choice below.
func _spawn_player(player_index: int) -> void:
	var tubbu: Tubbu = TUBBU_SCENE.instantiate()
	tubbu.player_index = player_index
	# kb+m binding. The move/dash actions also carry device -1 joypad events
	# (project.godot), so in single-player a connected pad drives this binding
	# too; true per-device assignment is the co-op feature, not v1.
	tubbu.input = PlayerInput.for_keyboard_mouse()
	tubbu.skin = DEFAULT_SKIN
	tubbu.move_bounds = ARENA_RECT.grow(-12.0)
	tubbu.position = ARENA_RECT.get_center()
	add_child(tubbu)
	EventBus.player_spawned.emit(player_index)


func _draw() -> void:
	draw_rect(ARENA_RECT, PALETTE.arena_wall_color, false, 2.0)
