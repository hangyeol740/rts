extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	game.gold = 500
	game.wood = 500
	game.selected_units.clear()
	game.selected_units.append(0)
	# Start a movement order, then place a barracks directly across the route.
	game.issue_command(Vector2(10100, 8800))
	for _frame in 60: await physics_frame
	game.build_mode = "barracks"
	game.issue_command(Vector2(9800, 9150))
	for _frame in 600: await physics_frame
	var worker: Dictionary = game.units[0]
	var barracks: Dictionary = game.buildings.back()
	var outside: bool = not barracks.block_rect.has_point(worker.pos)
	var moved: bool = worker.pos.distance_to(Vector2(9580, 9720)) > 80.0
	print("BUILD_ON_PATH moved=%s outside_new_building=%s worker=%s" % [moved, outside, worker.pos])
	quit(0 if moved and outside else 1)
