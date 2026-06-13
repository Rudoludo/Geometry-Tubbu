extends GutTest
## Chaser targeting (CP 1.4): pure nearest-alive-player selection. Steering
## feel, jitter and the swarm read are Ludo's playtest, not tests.


## In-tree ships so global_position is valid; no input bound, so their
## _process is inert during the test.
func _ship_at(at: Vector2) -> Tubbu:
	var tubbu := Tubbu.new()
	tubbu.position = at
	add_child_autofree(tubbu)
	return tubbu


func test_picks_the_nearest_alive_player() -> void:
	var players: Array[Tubbu] = [_ship_at(Vector2.ZERO), _ship_at(Vector2(100.0, 0.0))]
	assert_same(Chaser.nearest_alive_player(players, Vector2(90.0, 0.0)), players[1])
	assert_same(Chaser.nearest_alive_player(players, Vector2(10.0, 0.0)), players[0])


func test_dead_players_are_not_targets() -> void:
	# Co-op-shaped from day one: the swarm retargets the survivor.
	var players: Array[Tubbu] = [_ship_at(Vector2.ZERO), _ship_at(Vector2(100.0, 0.0))]
	players[1].try_kill()
	assert_same(Chaser.nearest_alive_player(players, Vector2(90.0, 0.0)), players[0],
		"nearest ship is dead — chase the living one")


func test_no_alive_players_means_no_target() -> void:
	var players: Array[Tubbu] = [_ship_at(Vector2.ZERO)]
	players[0].try_kill()
	assert_null(Chaser.nearest_alive_player(players, Vector2(50.0, 0.0)))
	var nobody: Array[Tubbu] = []
	assert_null(Chaser.nearest_alive_player(nobody, Vector2.ZERO))
