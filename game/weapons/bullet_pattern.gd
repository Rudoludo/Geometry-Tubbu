class_name BulletPattern
extends RefCounted
## Pure pattern math (CP 1.5): turns pattern parameters into unit fire
## directions. Stateless and static — the pattern shooter asks for directions,
## then spawns enemy bullets along them at its chosen speed. The boss (CP 3.5)
## grows its dense choreography from these same primitives, so this stays a
## thin, unit-testable math library with no scene knowledge (testing rule:
## pure logic only).

## A full evenly-spaced ring of `count` unit directions, the first at `phase`
## radians. Rotating `phase` between volleys interleaves successive rings into a
## slow, readable spiral. count <= 0 yields nothing.
static func ring(count: int, phase: float = 0.0) -> PackedVector2Array:
	var dirs := PackedVector2Array()
	if count <= 0:
		return dirs
	var step := TAU / count
	for i in count:
		dirs.append(Vector2.from_angle(phase + step * i))
	return dirs


## `count` unit directions fanned symmetrically across `spread` radians, centred
## on `aim`. count == 1 fires straight down `aim`; a zero `aim` has no direction
## to centre on, so it yields nothing (the caller skips a degenerate burst).
static func aimed_burst(aim: Vector2, count: int, spread: float) -> PackedVector2Array:
	var dirs := PackedVector2Array()
	if count <= 0 or aim == Vector2.ZERO:
		return dirs
	var center := aim.angle()
	if count == 1:
		dirs.append(Vector2.from_angle(center))
		return dirs
	var step := spread / (count - 1)
	var start := center - spread * 0.5
	for i in count:
		dirs.append(Vector2.from_angle(start + step * i))
	return dirs
