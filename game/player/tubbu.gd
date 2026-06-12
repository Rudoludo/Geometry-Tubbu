class_name Tubbu
extends Node2D
## Player ship.
##
## CP 1.1: acceleration/friction movement, heading + banking, soft (slide) wall
## collision, and a wireframe body + engine trail drawn entirely from the
## SkinResource. CP 1.2: facing follows the aim vector (travel direction is the
## fallback) and the gun autofires per the design's trigger rule, spawning
## through the injected BulletManager. CP 1.3: dash — control-suspending
## impulse with i-frames (DashAbility), ghost body while dashing, and the body
## glow refilling with the cooldown as the no-HUD readiness cue.

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

# --- Dash visuals -----------------------------------------------------------
# Brightness/alpha scaling of the skin's own colors — no new colors here
# (asset rule). The trail is a separate canvas item, so the body ghosts while
# the trail stays vivid: unmistakably "dashing". CP 1.6 adds particles.
const DASH_GHOST_ALPHA := 0.4     ## body alpha during the dash window
const DASH_REFILL_DIM := 0.55     ## body brightness right after a dash; 1 = ready

var player_index := 0
var input: PlayerInput
## Injected by Game; null disables the gun (headless logic tests don't need it).
var bullet_manager: BulletManager
var velocity := Vector2.ZERO

var _weapon := Weapon.new()
var _dash := DashAbility.new()
## Dash fallback when the move stick is neutral: the last travel intent, never
## the aim ("aim-neutral" per plan — you dodge along your motion, not your
## gun). Ships spawn facing +X, hence the default.
var _last_move_dir := Vector2.RIGHT

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
	var move := input.get_move_vector()
	var aim := input.get_aim_vector(self)
	_dash.tick(delta)
	if input.is_dash_just_pressed():
		_dash.try_dash(move if move != Vector2.ZERO else _last_move_dir)
	_move(delta, move)
	_update_heading(delta, aim)
	_update_fire(delta, aim)
	_update_dash_visual()
	_update_trail()


## CP 1.4's contact kill (and CP 1.5's bullets) check this before killing.
func is_invulnerable() -> bool:
	return _dash.is_invulnerable()


func _move(delta: float, move: Vector2) -> void:
	if move != Vector2.ZERO:
		_last_move_dir = move.normalized()
	if _dash.is_dashing():
		# Control is suspended for the burst. On exit the high velocity stays
		# and friction/accel reclaims it, which reads as a glide out.
		velocity = _dash.direction() * DashAbility.DASH_SPEED
	elif move == Vector2.ZERO:
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


func _update_dash_visual() -> void:
	if _dash.is_dashing():
		# Ghost: the body fades while the trail keeps burning.
		self_modulate = Color(1.0, 1.0, 1.0, DASH_GHOST_ALPHA)
	else:
		# Readiness without HUD: the body glow refills with the cooldown.
		var brightness := lerpf(DASH_REFILL_DIM, 1.0, _dash.cooldown_fraction())
		self_modulate = Color(brightness, brightness, brightness, 1.0)


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
