class_name Tubbu
extends Node2D
## Player ship. CP 0.2 shell: wireframe body drawn from SkinResource, crude
## translation so the input spine is provable end-to-end. CP 1.1 replaces the
## movement with the real acceleration/friction model and soft wall collision.

const PLACEHOLDER_SPEED := 420.0  # px/s, throwaway until CP 1.1 tuning

var player_index := 0
var input: PlayerInput
var skin: SkinResource:
	set(value):
		skin = value
		queue_redraw()

## Crude keep-inside bound; real soft wall collision lands in CP 1.1.
var move_bounds := Rect2()


func _process(delta: float) -> void:
	if input == null:
		return
	input.update()
	position += input.get_move_vector() * PLACEHOLDER_SPEED * delta
	if move_bounds.has_area():
		position = position.clamp(move_bounds.position, move_bounds.end)


func _draw() -> void:
	if skin == null or skin.body_points.size() < 3:
		return
	var outline := skin.body_points.duplicate()
	outline.append(outline[0])  # close the loop
	draw_polyline(outline, skin.body_color, 2.0, true)
