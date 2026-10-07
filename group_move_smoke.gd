extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	game.selected_units.clear()
	game.selected_units.append(0)
	game.selected_units.append(1)
	game.selected_units.append(2)
	var starts: Array[Vector2] = []
	for unit in game.units: starts.append(unit.pos)
	game.issue_command(Vector2(9800, 8800))
	game.set_process(false)
	for _frame in 720: await physics_frame
	var moved_all := true
	for i in game.units.size(): moved_all = moved_all and game.units[i].pos.distance_to(starts[i]) > 40.0
	print("GROUP_MOVE moved_all=%s ends=%s" % [moved_all, game.units.map(func(u): return u.pos)])
	quit(0 if moved_all else 1)
