class_name SkinResource
extends Resource
## Tubbu's complete look. Asset rule (PLAN.md): the player scene is logic +
## a skin slot — body shape, colors, trail (and later: idle anim, reactions,
## death burst) all come from here, never from feature code.
##
## Fields are added by the checkpoint that first renders them (CP 1.1 draws
## body + trail; the cosmetics phase extends this), never speculatively.

@export var display_name := "Unnamed"

## Closed wireframe outline in local space, +X = facing direction.
@export var body_points: PackedVector2Array

## Overbright channels (>1.0) feed the HDR 2D bloom.
@export var body_color := Color(0.3, 1.5, 1.5)
@export var trail_color := Color(0.1, 0.7, 1.4)
