extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	for zoom in [0.5, 1.0, 1.75]:
		game.zoom = zoom
		game.camera_pos = Vector2(9000, 8800)
		game.clamp_camera()
		game.get_node("Camera2D").position = game.camera_pos + game.visible_size() * 0.5
		game.get_node("Camera2D").zoom = Vector2.ONE * zoom
		await process_frame
		var world: Vector2 = Vector2(9600, 9600)
		var screen: Vector2 = game.get_canvas_transform() * world
		var restored: Vector2 = game.screen_to_world(screen)
		if restored.distance_to(world) > 0.1:
			print("MOUSE_TRANSFORM zoom=%s restored=%s expected=%s" % [zoom, restored, world])
			quit(1)
	print("MOUSE_TRANSFORM aligned=true")
	quit()
