class_name WarpGrid
extends RefCounted
## Spring-mass "warp grid" — the Geometry Wars signature stage presence (CP 1.7).
## A lattice of point masses: each is linked to its grid neighbours by a pull-only
## spring and to its home cell by a weak anchor pull, integrated with damping, so
## the mesh ripples on impulse and always settles back flat. Pure math — no nodes,
## no rendering, no Godot frame coupling — so the integration and the three force
## primitives are unit-tested; GridBackground owns the world wiring and draws it.
##
## Storage is struct-of-arrays (parallel Packed*Arrays), the same shape as the
## BulletManager pool: flat-indexable, allocation-free per frame, and cheap to
## walk in one draw pass. Border points are pinned (inv_mass 0) so the frame
## never sags inward and the lattice stays anchored to the arena walls.
##
## The step is FRAME-BASED (one step == one 60 fps frame), not dt-scaled: stiff
## explicit springs blow up under variable dt, and a background ripple slowing
## with the framerate is invisible anyway. GridBackground calls step() once per
## _process. Impulses add straight to velocity (an instantaneous kick fired
## between frames), per the Shape Blaster / Hoffman warp-grid model.

# --- Sim tuning (feel knobs; CP 1.8 may lift the look ones into the panel) ---
const SPRING_STIFFNESS := 0.28   ## neighbour pull when stretched past rest
const SPRING_DAMP := 0.06        ## damps relative motion along a neighbour spring
const ANCHOR_STIFFNESS := 0.012  ## weak pull toward home — guarantees it settles flat
const VEL_DAMP := 0.95           ## velocity retained per frame (bleeds ripples off)
## A point is snapped fully to rest only when it is BOTH crawling AND already
## near home — so the weak anchor never freezes a node parked off its cell.
const REST_VEL_EPS_SQ := 0.25    ## px²/frame² velocity threshold
const REST_POS_EPS_SQ := 1.0     ## px² distance-to-home threshold

var cols := 0
var rows := 0

# Parallel point arrays (flat index = row * cols + col).
var _home := PackedVector2Array()
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _inv_mass := PackedFloat32Array()  ## 0 == pinned border, 1 == free interior
var _acc := PackedVector2Array()        ## reused force accumulator (no per-frame alloc)

# Neighbour springs as flat edge lists (built once).
var _edge_a := PackedInt32Array()
var _edge_b := PackedInt32Array()
var _edge_len := PackedFloat32Array()


## Builds a lattice flush to `bounds`, spaced ~`spacing` px. The exact step is
## fitted so the border points land on the bounds (the arena walls); `spacing` is
## only the target density.
func _init(bounds: Rect2, spacing: float) -> void:
	cols = maxi(2, int(round(bounds.size.x / spacing)) + 1)
	rows = maxi(2, int(round(bounds.size.y / spacing)) + 1)
	var step := Vector2(bounds.size.x / (cols - 1), bounds.size.y / (rows - 1))
	var n := cols * rows
	_home.resize(n)
	_pos.resize(n)
	_vel.resize(n)
	_inv_mass.resize(n)
	_acc.resize(n)
	for r in rows:
		for c in cols:
			var i := r * cols + c
			var home := bounds.position + Vector2(c * step.x, r * step.y)
			_home[i] = home
			_pos[i] = home
			_vel[i] = Vector2.ZERO
			# Pin the border so the lattice can't drift off the arena walls.
			var pinned := c == 0 or c == cols - 1 or r == 0 or r == rows - 1
			_inv_mass[i] = 0.0 if pinned else 1.0
	# Structural springs: one to the right neighbour, one down. Each interior
	# edge is shared, so this covers the whole lattice without duplicates.
	for r in rows:
		for c in cols:
			var i := r * cols + c
			if c + 1 < cols:
				_add_edge(i, i + 1, step.x)
			if r + 1 < rows:
				_add_edge(i, i + cols, step.y)


func _add_edge(a: int, b: int, rest_len: float) -> void:
	_edge_a.append(a)
	_edge_b.append(b)
	_edge_len.append(rest_len)


## Advances the whole mesh one frame: neighbour springs propagate ripples, then
## each free point gets a weak pull home, velocity damping, and integration.
func step() -> void:
	_acc.fill(Vector2.ZERO)
	for e in _edge_a.size():
		var a := _edge_a[e]
		var b := _edge_b[e]
		var rest := _edge_len[e]
		var delta := _pos[a] - _pos[b]
		var dist := delta.length()
		# Pull-only: a stretched spring tugs its ends together; the home anchor
		# handles compression. dist == 0 can't be stretched, so skip it.
		if dist <= rest or dist == 0.0:
			continue
		var x := delta * ((dist - rest) / dist)        # displacement beyond rest
		var dv := _vel[b] - _vel[a]
		var force := x * SPRING_STIFFNESS - dv * SPRING_DAMP
		_acc[a] -= force * _inv_mass[a]
		_acc[b] += force * _inv_mass[b]
	for i in _pos.size():
		if _inv_mass[i] == 0.0:
			continue  # pinned border never moves
		_acc[i] += (_home[i] - _pos[i]) * ANCHOR_STIFFNESS
		var v := (_vel[i] + _acc[i]) * VEL_DAMP
		_pos[i] += v
		# Latch fully flat once it's both slow and home, else keep creeping in.
		if v.length_squared() < REST_VEL_EPS_SQ \
				and _pos[i].distance_squared_to(_home[i]) < REST_POS_EPS_SQ:
			_pos[i] = _home[i]
			v = Vector2.ZERO
		_vel[i] = v


## Push free points away from `at`, strongest at the centre, zero past `radius`.
## The discrete kill/dash/death ripple. Adds to velocity (instantaneous kick).
func apply_explosive_force(at: Vector2, force: float, radius: float) -> void:
	if radius <= 0.0:
		return
	var r_sq := radius * radius
	for i in _pos.size():
		if _inv_mass[i] == 0.0:
			continue
		var off := _pos[i] - at
		var d_sq := off.length_squared()
		if d_sq >= r_sq or d_sq == 0.0:
			continue  # outside the blast, or exactly on it (no direction)
		var dist := sqrt(d_sq)
		_vel[i] += (off / dist) * force * (1.0 - dist / radius)


## Pull free points toward `at` (the inverse of explosive) — kept for symmetry
## and future black-hole-style wells; not wired to an event yet.
func apply_implosive_force(at: Vector2, force: float, radius: float) -> void:
	if radius <= 0.0:
		return
	var r_sq := radius * radius
	for i in _pos.size():
		if _inv_mass[i] == 0.0:
			continue
		var off := _pos[i] - at
		var d_sq := off.length_squared()
		if d_sq >= r_sq or d_sq == 0.0:
			continue
		var dist := sqrt(d_sq)
		_vel[i] -= (off / dist) * force * (1.0 - dist / radius)


## Shove free points near `at` along `force_vec` — the player's wake. No
## direction singularity (the push is the supplied vector), so it's safe to apply
## every frame as the ship flies through.
func apply_directed_force(at: Vector2, force_vec: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var r_sq := radius * radius
	for i in _pos.size():
		if _inv_mass[i] == 0.0:
			continue
		var d_sq := (_pos[i] - at).length_squared()
		if d_sq >= r_sq:
			continue
		_vel[i] += force_vec * (1.0 - sqrt(d_sq) / radius)


## Snap the whole mesh flat and still — used on restart so a revive starts clean.
func reset() -> void:
	for i in _pos.size():
		_pos[i] = _home[i]
		_vel[i] = Vector2.ZERO


# --- Read access (drawing + tests) ------------------------------------------

func point_count() -> int:
	return _pos.size()


func idx(col: int, row: int) -> int:
	return row * cols + col


func point(i: int) -> Vector2:
	return _pos[i]


func home(i: int) -> Vector2:
	return _home[i]


func velocity(i: int) -> Vector2:
	return _vel[i]


func is_pinned(i: int) -> bool:
	return _inv_mass[i] == 0.0
