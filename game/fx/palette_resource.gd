class_name PaletteResource
extends Resource
## Colors for everything that is not Tubbu: enemies, bullets, arena, grid.
## Asset rule (PLAN.md): feature code never hard-codes a color — it reads the
## active palette, so a real art pass is a .tres swap.
##
## Readability rule (one-hit game): enemy_bullet_color must out-contrast
## every other color in the palette. Fields are added by the checkpoint that
## first renders them.

@export var background_color := Color(0.04, 0.04, 0.06)
@export var grid_color := Color(0.15, 0.1, 0.35)
@export var arena_wall_color := Color(0.2, 1.2, 1.4)

## Overbright channels (>1.0) feed the HDR 2D bloom.
@export var player_bullet_color := Color(1.4, 1.2, 0.4)
@export var enemy_color := Color(1.3, 0.3, 1.2)
@export var enemy_bullet_color := Color(1.6, 0.2, 0.4)
