extends GutTest
## WarpGrid spring-mesh sim (CP 1.7): the pure lattice math behind the reactive
## backdrop. Tested here — lattice build, the three force primitives, ripple
## propagation through the neighbour springs, border pinning, and settling back
## flat. The rendering, colours and per-frame wiring are feel/visual and live in
## GridBackground (testing rule: pure logic only).

const EPS := 0.0001


## A small interior-rich lattice: 400x400 at 50 px → 9x9, so c,r in 1..7 are
## genuinely interior (neighbours on all sides also interior).
func _grid() -> WarpGrid:
	return WarpGrid.new(Rect2(0, 0, 400, 400), 50.0)


func test_builds_lattice_flush_to_bounds() -> void:
	var g := _grid()
	assert_eq(g.cols, 9, "round(400/50)+1")
	assert_eq(g.rows, 9)
	assert_eq(g.point_count(), 81)
	# Corner home sits exactly on the bounds corner (border flush to the walls).
	assert_almost_eq(g.home(g.idx(0, 0)).x, 0.0, EPS)
	assert_almost_eq(g.home(g.idx(8, 8)).x, 400.0, EPS)
	assert_almost_eq(g.home(g.idx(8, 8)).y, 400.0, EPS)


func test_border_pinned_interior_free() -> void:
	var g := _grid()
	assert_true(g.is_pinned(g.idx(0, 0)), "corner pinned")
	assert_true(g.is_pinned(g.idx(4, 0)), "top edge pinned")
	assert_true(g.is_pinned(g.idx(0, 4)), "left edge pinned")
	assert_true(g.is_pinned(g.idx(8, 4)), "right edge pinned")
	assert_false(g.is_pinned(g.idx(4, 4)), "centre free")


func test_flat_grid_stays_flat() -> void:
	# No impulse → nothing should ever move (or the calm backdrop would crawl).
	var g := _grid()
	for _i in 10:
		g.step()
	var c := g.idx(4, 4)
	assert_almost_eq(g.point(c).distance_to(g.home(c)), 0.0, EPS)
	assert_almost_eq(g.velocity(c).length(), 0.0, EPS)


func test_explosive_pushes_point_away_from_centre() -> void:
	var g := _grid()
	var at := g.home(g.idx(4, 4))
	var p := g.idx(6, 4)  # to the right of the blast
	g.apply_explosive_force(at, 20.0, 200.0)
	var away := g.home(p) - at
	assert_gt(g.velocity(p).dot(away), 0.0, "kicked away from the blast")


func test_explosive_falls_off_with_distance() -> void:
	var g := _grid()
	var at := g.home(g.idx(4, 4))
	var near := g.idx(5, 4)
	var far := g.idx(7, 4)
	g.apply_explosive_force(at, 20.0, 300.0)
	assert_gt(g.velocity(near).length(), g.velocity(far).length(),
			"closer point is shoved harder")


func test_explosive_spares_points_beyond_radius() -> void:
	var g := _grid()
	var at := g.home(g.idx(1, 1))
	var outside := g.idx(7, 7)  # ~424 px away
	g.apply_explosive_force(at, 50.0, 100.0)
	assert_almost_eq(g.velocity(outside).length(), 0.0, EPS, "outside the blast")


func test_implosive_pulls_toward_centre() -> void:
	var g := _grid()
	var at := g.home(g.idx(4, 4))
	var p := g.idx(6, 4)
	g.apply_implosive_force(at, 20.0, 200.0)
	var toward := at - g.home(p)
	assert_gt(g.velocity(p).dot(toward), 0.0, "pulled toward the centre")


func test_directed_force_adds_along_vector() -> void:
	var g := _grid()
	var p := g.idx(4, 4)
	g.apply_directed_force(g.home(p), Vector2(10.0, 0.0), 120.0)
	assert_gt(g.velocity(p).x, 0.0, "gains velocity along the push")
	assert_almost_eq(g.velocity(p).y, 0.0, EPS)


func test_border_stays_pinned_under_a_blast() -> void:
	# A point-blank explosion on a border node must not tear the frame off the wall.
	var g := _grid()
	var b := g.idx(0, 4)
	g.apply_explosive_force(g.home(b), 80.0, 200.0)
	assert_almost_eq(g.velocity(b).length(), 0.0, EPS, "border absorbs no impulse")
	for _i in 5:
		g.step()
	assert_almost_eq(g.point(b).distance_to(g.home(b)), 0.0, EPS, "border held home")


func test_ripple_propagates_to_a_neighbour() -> void:
	# Kick exactly one interior node (radius < spacing), then the spring should
	# drag an initially-still interior neighbour off its home — coupling works.
	var g := _grid()
	var p := g.idx(4, 4)
	var neighbour := g.idx(3, 4)
	g.apply_directed_force(g.home(p), Vector2(25.0, 0.0), 30.0)
	assert_almost_eq(g.velocity(neighbour).length(), 0.0, EPS, "neighbour starts still")
	for _i in 6:
		g.step()
	assert_gt(g.point(neighbour).distance_to(g.home(neighbour)), 0.1,
			"the spring pulled the neighbour along")


func test_ripple_settles_back_flat() -> void:
	# Damping + the home anchor must return the mesh to rest, or ripples pile up.
	var g := _grid()
	var p := g.idx(4, 4)
	g.apply_explosive_force(g.home(p) - Vector2(5, 0), 30.0, 200.0)
	for _i in 400:
		g.step()
	assert_lt(g.point(p).distance_to(g.home(p)), 1.0, "ripple has died down")
	assert_almost_eq(g.velocity(p).length(), 0.0, EPS, "and come fully to rest")


func test_reset_flattens_a_disturbed_mesh() -> void:
	var g := _grid()
	g.apply_explosive_force(g.home(g.idx(4, 4)), 40.0, 300.0)
	g.step()
	g.reset()
	var c := g.idx(4, 4)
	assert_almost_eq(g.point(c).distance_to(g.home(c)), 0.0, EPS, "snapped home")
	assert_almost_eq(g.velocity(c).length(), 0.0, EPS, "and stilled")
