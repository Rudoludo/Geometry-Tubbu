class_name GridBackground
extends Node2D
## The reactive warp-grid stage backdrop (CP 1.7). Owns a pure WarpGrid sim and
## is the only thing that couples it to the world: it drives the player wake each
## frame, fires explosive ripples on dashes / kills / deaths, and renders the
## whole lattice in one draw_multiline_colors pass.
##
## Drawn far behind everything (z -10): the grid is backdrop, never foreground.
## The readability rule still holds with room to spare — every bullet is at z 5,
## the grid lines are thin and dim, and they only brighten (toward bloom) along a
## ripple front, which is the whole point: "ripples sell every explosion."
##
## Reactions are event-driven (EventBus.enemy_killed / player_died) plus a
## per-frame poll of each player's velocity and dash state, so nothing else has
## to know the grid exists.

const Z_BEHIND_ALL := -10

# --- Look (CP 1.8 may lift these into the debug panel) ----------------------
const SPACING := 56.0            ## target px between grid lines
const LINE_WIDTH := 1.5
## Displacement → extra brightness. A point pushed this far from home reaches the
## full boost; the blue channel of grid_color then crosses 1.0 and the ripple
## front blooms through the HDR glow. Calm grid stays dim backdrop.
const DISP_FULL := 26.0          ## px of displacement for max brightness
const MAX_BRIGHTNESS := 3.4      ## multiplier on grid_color at a peak ripple

# --- Reaction strengths (px/frame velocity kicks; radii in px) --------------
const WAKE_SCALE := 0.010        ## fraction of player px/s velocity pushed per frame
const WAKE_RADIUS := 110.0
const KILL_FORCE := 6.0
const KILL_RADIUS := 150.0
const DASH_FORCE := 15.0
const DASH_RADIUS := 200.0
const DEATH_FORCE := 28.0
const DEATH_RADIUS := 340.0

## Injected by Game (asset + co-op rules): grid color comes from the palette,
## players are an index-addressed array, never a singleton.
var palette: PaletteResource
var players: Array[Tubbu] = []

var _grid: WarpGrid
## Rising-edge latch per player so one dash fires exactly one ripple.
var _was_dashing: Array[bool] = []
## Preallocated draw buffers, sized once — the per-frame draw never reallocates.
## draw_multiline_colors wants ONE colour per segment (2 points per colour), so
## _seg_colors is half the length of _seg_points.
var _seg_points := PackedVector2Array()
var _seg_colors := PackedColorArray()
var _point_bright := PackedFloat32Array()


## Builds the lattice to fill `bounds`. Called by Game before play starts.
func setup(bounds: Rect2) -> void:
	_grid = WarpGrid.new(bounds, SPACING)
	# One segment == 2 endpoints, one colour; edges = right + down neighbour links.
	var edge_count := (_grid.cols - 1) * _grid.rows + _grid.cols * (_grid.rows - 1)
	_seg_points.resize(edge_count * 2)
	_seg_colors.resize(edge_count)
	_point_bright.resize(_grid.point_count())


func _ready() -> void:
	z_index = Z_BEHIND_ALL
	top_level = true  # lattice is authored in world space (arena-centred), like the trail
	# A kill ripples where the enemy popped; a death is the big slam at the ship.
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	if _grid == null:
		return
	_drive_players()
	_grid.step()
	queue_redraw()


## Per-frame player coupling: a velocity wake while flying, and a one-shot
## explosive on the rising edge of each dash (the design calls out dashes).
func _drive_players() -> void:
	# Game shares its _players array with us before it spawns into it, so the
	# latch is sized lazily here (new slots default to false = "wasn't dashing").
	if _was_dashing.size() != players.size():
		_was_dashing.resize(players.size())
	for index in players.size():
		var player := players[index]
		if player == null or not player.is_alive():
			_was_dashing[index] = false
			continue
		var dashing := player.is_dashing()
		if dashing and not _was_dashing[index]:
			_grid.apply_explosive_force(player.global_position, DASH_FORCE, DASH_RADIUS)
		_was_dashing[index] = dashing
		if player.velocity != Vector2.ZERO:
			_grid.apply_directed_force(
					player.global_position, player.velocity * WAKE_SCALE, WAKE_RADIUS)


func _on_enemy_killed(at: Vector2) -> void:
	if _grid != null:
		_grid.apply_explosive_force(at, KILL_FORCE, KILL_RADIUS)


## player_died carries only the index (co-op rule); read the death position off
## the ship, which is still where it fell at the moment the signal fires.
func _on_player_died(index: int) -> void:
	if _grid == null or index < 0 or index >= players.size():
		return
	var player := players[index]
	if player != null:
		_grid.apply_explosive_force(player.global_position, DEATH_FORCE, DEATH_RADIUS)


## Flatten the mesh — called by Game on restart so the revive starts clean.
func reset() -> void:
	if _grid != null:
		_grid.reset()
	_was_dashing.fill(false)


func _draw() -> void:
	if _grid == null or palette == null:
		return
	var base := palette.grid_color
	# Per-point brightness from how far each node is shoved off home — computed
	# once, then each segment takes the brighter of its two endpoints so a ripple
	# front lights the whole line (and crosses 1.0 into bloom at a peak).
	for i in _grid.point_count():
		var disp := _grid.point(i).distance_to(_grid.home(i))
		_point_bright[i] = 1.0 + minf(disp / DISP_FULL, 1.0) * (MAX_BRIGHTNESS - 1.0)
	# Lay every right- and down-edge into the preallocated buffers (2 points +
	# 1 colour per segment), in build order, then draw the lattice in one call.
	var p := 0
	var s := 0
	for r in _grid.rows:
		for c in _grid.cols:
			var i := _grid.idx(c, r)
			if c + 1 < _grid.cols:
				var j := i + 1
				_seg_points[p] = _grid.point(i)
				_seg_points[p + 1] = _grid.point(j)
				_seg_colors[s] = base * maxf(_point_bright[i], _point_bright[j])
				p += 2
				s += 1
			if r + 1 < _grid.rows:
				var j := i + _grid.cols
				_seg_points[p] = _grid.point(i)
				_seg_points[p + 1] = _grid.point(j)
				_seg_colors[s] = base * maxf(_point_bright[i], _point_bright[j])
				p += 2
				s += 1
	draw_multiline_colors(_seg_points, _seg_colors, LINE_WIDTH, true)
