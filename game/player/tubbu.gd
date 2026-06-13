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
## glow refilling with the cooldown as the no-HUD readiness cue. CP 1.4: one-hit
## death (try_kill — the i-frame gate lives there, every killer goes through it)
## and revive() for the instant-restart loop.
##
## PlayerInput is updated by Game once per frame (parents process first), so a
## dead, non-processing ship still latches the restart edge; this node only
## reads.

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

# --- Death ------------------------------------------------------------------
## The kill hitbox — deliberately tiny vs the ~16 px body (bullet-hell
## convention, DESIGN.md hard-edge mitigation). Enemies add their own reach.
const HIT_RADIUS := 6.0
const DEATH_PARTICLES := 28
const DEATH_BURST_SPEED := 520.0

var player_index := 0
var input: PlayerInput
## Injected by Game; null disables the gun (headless logic tests don't need it).
var bullet_manager: BulletManager
## Injected by Game; muzzle FX read the bullet color from it (CP 1.6). Null in
## logic tests, which skip the particle emitters entirely.
var palette: PaletteResource
var velocity := Vector2.ZERO

var _alive := true
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
## Persistent particle emitters (CP 1.6), built only when their color source is
## injected (so headless logic tests stay node-light). World-space + top_level,
## like the trail. Bullets draw above them (z 5), so neither can hide a bullet.
var _muzzle: CPUParticles2D
var _dash_trail: CPUParticles2D


func _ready() -> void:
	_trail = Line2D.new()
	_trail.top_level = true  # points are world-space, free of the ship transform
	_trail.z_index = -1      # behind the body
	_trail.width = TRAIL_WIDTH
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)
	if palette != null:
		_muzzle = Fx.make_muzzle(palette.player_bullet_color)
		_muzzle.top_level = true
		add_child(_muzzle)
	if skin != null:
		_dash_trail = Fx.make_dash_trail(skin.trail_color)
		_dash_trail.top_level = true
		add_child(_dash_trail)
	_apply_skin()


func _process(delta: float) -> void:
	if input == null or not _alive:
		return
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


## Dash i-frames (CP 1.3). Killers don't check this directly — try_kill does.
func is_invulnerable() -> bool:
	return _dash.is_invulnerable()


## The dash impulse window (CP 1.7). The grid backdrop polls this rising edge to
## ripple on each dash; nothing about the kill gate routes through it.
func is_dashing() -> bool:
	return _dash.is_dashing()


func is_alive() -> bool:
	return _alive


## The one-hit death (CP 1.4). EVERY killer — chaser contact now, enemy
## bullets at CP 1.5 — goes through here, so the i-frame rule can never be
## forgotten at a call site. Reports whether the kill landed.
func try_kill() -> bool:
	if not _alive or is_invulnerable():
		return false
	_alive = false
	velocity = Vector2.ZERO
	visible = false  # hides the trail too (visibility is tree-wide; top_level only exempts transform)
	if _muzzle != null:
		_muzzle.emitting = false
	if _dash_trail != null:
		_dash_trail.emitting = false
	if is_inside_tree() and skin != null:
		Burst.spawn(get_parent(), global_position, skin.body_color,
				DEATH_PARTICLES, DEATH_BURST_SPEED)
	EventBus.player_died.emit(player_index)
	return true


## Back into play at `at`, fresh as spawned (instant-restart loop).
func revive(at: Vector2) -> void:
	_alive = true
	visible = true
	position = at
	velocity = Vector2.ZERO
	rotation = 0.0  # ships spawn facing +X
	skew = 0.0
	_last_move_dir = Vector2.RIGHT
	_weapon = Weapon.new()
	_dash = DashAbility.new()
	if _trail != null:
		_trail.clear_points()  # no ghost streak from the death spot


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
	if _muzzle != null:
		# Muzzle spray rides the exact aim at the muzzle point, not the slewing nose.
		_muzzle.emitting = firing
		if firing:
			_muzzle.global_position = global_position + dir * Weapon.MUZZLE_OFFSET
			_muzzle.rotation = dir.angle()


func _update_dash_visual() -> void:
	var dashing := _dash.is_dashing()
	if dashing:
		# Ghost: the body fades while the trail keeps burning.
		self_modulate = Color(1.0, 1.0, 1.0, DASH_GHOST_ALPHA)
	else:
		# Readiness without HUD: the body glow refills with the cooldown.
		var brightness := lerpf(DASH_REFILL_DIM, 1.0, _dash.cooldown_fraction())
		self_modulate = Color(brightness, brightness, brightness, 1.0)
	if _dash_trail != null:
		# Afterimage puffs left in world space as the ship rockets off.
		_dash_trail.emitting = dashing
		if dashing:
			_dash_trail.global_position = global_position


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
