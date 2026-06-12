class_name ArenaCamera
extends Camera2D
## Arena-clamped follow camera: a subtly smoothed follow with a small velocity
## lead so the view drifts toward where you're heading.
##
## Co-op note (PLAN.md): the camera is owned by the arena/game and accepts N
## players — v1 follows player 0, framing several (centroid + zoom-to-fit) is the
## co-op extension. It is never a child of a player (that would inherit the
## ship's heading/banking and spin the world).

## How far ahead the camera looks, expressed as seconds of travel — decoupled
## from the player's top speed so tuning either stays independent.
const LEAD_TIME := 0.16
const MAX_LEAD := 150.0
## Position smoothing speed; low enough to feel like a follow, not a snap.
const FOLLOW_SMOOTH := 6.0

var target: Node2D


func _ready() -> void:
	ignore_rotation = true
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SMOOTH


## Pin the view inside the arena so walls never reveal the void beyond them.
func setup_limits(bounds: Rect2) -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func _process(_delta: float) -> void:
	if target == null:
		return
	var lead := Vector2.ZERO
	if "velocity" in target:
		lead = (target.velocity * LEAD_TIME).limit_length(MAX_LEAD)
	global_position = target.global_position + lead
