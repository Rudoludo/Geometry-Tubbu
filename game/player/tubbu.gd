class_name Tubbu
extends Node2D
## Player ship.
##
## CP 1.1: acceleration/friction movement, heading + banking, soft (slide) wall
## collision, and a wireframe body + engine trail drawn entirely from the
## SkinResource. CP 1.2: facing follows the aim vector (travel direction is the
## fallback) and the gun autofires per the design's trigger rule, spawning
## through the injected BulletManager. CP 1.3 adds the dash.

# --- Movement tuning ------------------------------------------------------
# One place on purpose (PLAN.md). CP 1.8 lifts these into a debug panel for the
# feel-gate tuning session; until then, edit here.
const MAX_SPEED := 560.0          ## px/s top speed
const ACCELERATION := 4200.0      ## px/s^2 toward the input target velocity
const FRICTION := 3000.0          ## px/s^2 toward rest when there's no input
const TURN_SPEED := 13.0          ## rad/s the heading slews toward travel dir
const HEADING_MIN_SPEED := 25.0   ## px/s below which heading is held (no spin)
const BANK_FROM_TURN := 0.05      ## skew (rad) per rad/s of turn rate
const BANK_MAX := 0.28            ## rad cap on the lean
const BANK_RESPONSE := 8.0        ## skew slew speed
const COLLISION_RADIUS := 16.0    ## body half-extent, for wall containment

# --- Engine trail ---------------------------------------------------------
# Feel/shape consts live here; the trail's colour comes from the skin layer.
const TRAIL_MAX_POINTS := 22
const TRAIL_REAR_OFFSET := 12.0   ## px the trail emits behind the ship centre
const TRAIL_WIDTH := 6.0

var player_index := 0
var input: PlayerInput
## Injected by Game; null disables the gun (headless logic tests don't need it).
var bullet_manager: BulletManager
var velocity := Vector2.ZERO

var _weapon := Weapon.new()

var skin: SkinResource:
	set(value):
		skin = value
		_apply_skin()
		queue_redraw()

## Full arena rect this ship is contained within (radius handled internally).
var move_bounds := Rect2()

var _trail: Line2D


func _ready() -> void:
	_trail = Line2D.new()
	_trail.top_level = true  # points are world-space, free of the ship transform
	_trail.z_index = -1      # behind the body
	_trail.width = TRAIL_WIDTH
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)
	_apply_skin()


func _process(delta: float) -> void:
	if input == null:
		return
	input.update()
	var aim := input.get_aim_vector(self)
	_move(delta)
	_update_heading(delta, aim)
	_update_fire(delta, aim)
	_update_trail()


func _move(delta: float) -> void:
	var move := input.get_move_vector()
	if move == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(move * MAX_SPEED, ACCELERATION * delta)
	position += velocity * delta
	if move_bounds.has_area():
		var resolved := Arena.slide_inside(
			move_bounds, position, velocity, COLLISION_RADIUS)
		position = resolved["position"]
		velocity = resolved["velocity"]


func _update_heading(delta: float, aim: Vector2) -> void:
	# Aim owns the facing (CP 1.2); travel direction is the fallback so a pad
	# with a neutral right stick still noses into its motion (CP 1.1 feel).
	# The slew is cosmetic — bullets fly along the exact aim, never the nose.
	var face := aim
	if face == Vector2.ZERO and velocity.length() > HEADING_MIN_SPEED:
		face = velocity
	if face != Vector2.ZERO:
		var diff := wrapf(face.angle() - rotation, -PI, PI)
		var step := TURN_SPEED * delta
		var prev := rotation
		rotation += clampf(diff, -step, step)
		# Bank into the turn, proportional to how fast the heading is changing.
		var turn_rate := wrapf(rotation - prev, -PI, PI) / delta
		var target_skew := clampf(-turn_rate * BANK_FROM_TURN, -BANK_MAX, BANK_MAX)
		skew = lerpf(skew, target_skew, minf(BANK_RESPONSE * delta, 1.0))
	else:
		skew = lerpf(skew, 0.0, minf(BANK_RESPONSE * delta, 1.0))


func _update_fire(delta: float, aim: Vector2) -> void:
	if bullet_manager == null:
		return
	var firing := input.is_fire_held(aim)
	# Shots leave from the muzzle along the exact aim direction — 1:1 with the
	# stick/cursor — regardless of where the slewing nose currently points.
	var dir := aim.normalized() if firing else Vector2.ZERO
	for _shot in _weapon.tick(delta, firing):
		bullet_manager.spawn_player_bullet(
			player_index, global_position + dir * Weapon.MUZZLE_OFFSET, dir)


func _update_trail() -> void:
	if _trail == null:
		return
	# Emit from the ship's rear so the trail reads as engine wash. When idle the
	# points pile on one spot and the trail collapses to a dot — fades for free.
	var rear := global_position - Vector2.RIGHT.rotated(rotation) * TRAIL_REAR_OFFSET
	_trail.add_point(rear, 0)
	while _trail.get_point_count() > TRAIL_MAX_POINTS:
		_trail.remove_point(_trail.get_point_count() - 1)


func _apply_skin() -> void:
	if _trail == null or skin == null:
		return
	var grad := Gradient.new()
	grad.set_color(0, skin.trail_color)                 # newest point: full
	grad.set_color(1, Color(skin.trail_color, 0.0))     # tail: faded out
	_trail.gradient = grad
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))                  # newest: full width
	taper.add_point(Vector2(1.0, 0.0))                  # tail: pinched to a point
	_trail.width_curve = taper


func _draw() -> void:
	if skin == null or skin.body_points.size() < 3:
		return
	var outline := skin.body_points.duplicate()
	outline.append(outline[0])  # close the loop
	draw_polyline(outline, skin.body_color, 2.0, true)
