extends GutTest
## Arena (CP 1.1): soft wall containment math. Pure logic only per testing rules
## (feel is untested) — the guarantee here is "slides along walls, never snags".

# Usable inner edge after the radius inset is grow(-10) -> [-90 .. 90] each axis.
const BOUNDS := Rect2(-100.0, -100.0, 200.0, 200.0)
const R := 10.0


func test_inside_is_left_alone() -> void:
	var out := Arena.slide_inside(BOUNDS, Vector2(0, 0), Vector2(50, -30), R)
	assert_eq(out["position"], Vector2(0, 0))
	assert_eq(out["velocity"], Vector2(50, -30))


func test_wall_clamps_and_slides() -> void:
	# Driven past the right wall: x pins to the inner edge and the into-wall
	# x-velocity cancels, but the along-wall y-velocity survives -> slide.
	var out := Arena.slide_inside(BOUNDS, Vector2(200, 20), Vector2(300, 80), R)
	assert_almost_eq(out["position"].x, 90.0, 0.001)
	assert_eq(out["position"].y, 20.0, "along-wall axis is not clamped")
	assert_eq(out["velocity"].x, 0.0, "into-wall velocity cancelled (no snag)")
	assert_eq(out["velocity"].y, 80.0, "along-wall velocity preserved (slide)")


func test_corner_cancels_both_axes() -> void:
	var out := Arena.slide_inside(BOUNDS, Vector2(500, -500), Vector2(120, -90), R)
	assert_almost_eq(out["position"].x, 90.0, 0.001)
	assert_almost_eq(out["position"].y, -90.0, 0.001)
	assert_eq(out["velocity"], Vector2.ZERO)


func test_radius_keeps_the_body_off_the_wall() -> void:
	# A larger radius pulls the containment line further inward.
	var out := Arena.slide_inside(BOUNDS, Vector2(200, 0), Vector2.ZERO, 40.0)
	assert_almost_eq(out["position"].x, 60.0, 0.001)  # 100 - 40
