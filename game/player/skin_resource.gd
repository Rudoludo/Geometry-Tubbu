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

# --- Personality / idle animation (CP 1.8) ----------------------------------
## Per-skin so each Tubbu variant emotes differently; the curves are computed by
## [IdleAnimation] and applied by Tubbu (faded out as it speeds up). Amplitudes
## are gentle on purpose — this is character, not a distraction from the bullets.
@export var idle_bob := 3.0             ## px of world-space hover at full idle
@export var idle_breathe := 0.06        ## squash/stretch as a fraction of size
@export var idle_cycle := 1.6           ## s per bob/breathe cycle
@export var blink_interval := 3.2       ## s between eye blinks
@export var eye_offset := Vector2(6.0, 0.0)  ## local eye position (+X = forward)
@export var eye_radius := 2.4           ## eye size; 0 disables the eye and blink
