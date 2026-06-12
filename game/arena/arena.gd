class_name Arena
extends Node2D
## Bounded play space, centred on this node's origin.
##
## CP 1.1: a rect arena with neon walls (colour from the active PaletteResource)
## and soft — slide, never bounce — wall collision. CP 3.4 adds circle/oval
## shapes; each shape owns its own containment math, so [method slide_inside]
## lives here next to its siblings-to-be rather than in the player.

## Full arena extent; bounds are centred so the player spawns at world origin.
@export var size := Vector2(2000.0, 1300.0)

## Injected by Game so a real art pass is a .tres swap (asset rule, PLAN.md).
var palette: PaletteResource


func bounds() -> Rect2:
	return Rect2(-size * 0.5, size)


func _draw() -> void:
	if palette == null:
		return
	var r := bounds()
	# Double line: a bright inner edge over a dimmer outer one reads as a neon
	# tube once the HDR bloom (CP 1.6) is on, and is legible before then.
	draw_rect(r, palette.arena_wall_color, false, 3.0, true)
	draw_rect(r.grow(-4.0), palette.arena_wall_color * 0.45, false, 1.5, true)


## Keep a circle of `radius` inside `bounds_rect`, sliding along any wall it
## meets: clamp the centre per-axis, then cancel the velocity component pushing
## into a wall that was hit. Cancelling only the blocked axis preserves the
## tangential component, so the ship slides — and zeroing it stops the ship
## fighting the wall, which is what removes the snag. Pure; unit tested.
static func slide_inside(
		bounds_rect: Rect2, pos: Vector2, vel: Vector2, radius: float) -> Dictionary:
	var inner := bounds_rect.grow(-radius)
	var clamped := pos.clamp(inner.position, inner.end)
	if clamped.x != pos.x:
		vel.x = 0.0
	if clamped.y != pos.y:
		vel.y = 0.0
	return {"position": clamped, "velocity": vel}
