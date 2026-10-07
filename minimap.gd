class_name GameMinimap
extends Control

var game: Node
var redraw_time := 0.0

func _process(delta: float) -> void:
	redraw_time -= delta
	if redraw_time <= 0.0:
		redraw_time = 0.10
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if game == null or not event is InputEventMouseButton: return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	var target: Vector2 = event.position / size * game.map_size
	game.camera_pos = target - game.visible_size() * 0.5
	game.clamp_camera()
	game.get_node("Camera2D").position = game.camera_pos + game.visible_size() * 0.5
	accept_event()

func _draw() -> void:
	if game == null or game.map_size == Vector2.ZERO: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("39492a"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("e5e1d8"), false, 2)
	var map_scale := Vector2(size.x / game.map_size.x, size.y / game.map_size.y)
	for resource in game.resources:
		if resource.amount > 0: draw_circle(resource.pos * map_scale, 2.0, Color("d9a63a"))
	for unit in game.units:
		draw_circle(unit.pos * map_scale, 2.0, Color("3f8f7a") if unit.team == 0 else Color("a8322d"))
	draw_rect(Rect2(game.camera_pos * map_scale, game.visible_size() * map_scale), Color.WHITE, false, 1)
