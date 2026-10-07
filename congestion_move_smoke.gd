extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	while game.units.size() < 20:
		game.add_unit("worker", game.player_hall_position, 0)
	var starts: Array[Vector2] = []
	for index in game.units.size():
		game.units[index].pos = game.player_hall_position + Vector2(260 + (index % 5) * 3, 220 + (index / 5) * 3)
		(game.unit_nodes[index] as Node2D).position = game.units[index].pos
		starts.append(game.units[index].pos)
	game.selected_units.clear()
	for index in game.units.size(): game.selected_units.append(index)
	game.issue_command(game.player_hall_position + Vector2(900, 300))
	for _frame in 900: await physics_frame
	var moved := 0
	for index in game.units.size():
		if game.units[index].pos.distance_to(starts[index]) > 100.0: moved += 1
	print("CONGESTION_MOVE moved=%s total=%s" % [moved, game.units.size()])
	quit(0 if moved >= game.units.size() * 0.8 else 1)
