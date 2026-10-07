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
	var before: int = game.population_cap
	var pos := Vector2.INF
	for y in range(-8, 9):
		for x in range(-8, 9):
			var candidate: Vector2 = game.player_hall_position + Vector2(x, y) * 128.0
			if game.can_place_building("house", candidate):
				pos = candidate
				break
		if pos != Vector2.INF: break
	game.build_mode = "house"
	game.issue_command(pos)
	var expected: int = before + game.stats.house.population
	var label := game.get_node("UIInterface/HUD/ResourcePanel/PopulationLabel") as Label
	var updated: bool = game.population_cap == expected and label.text.ends_with("/ %d" % expected)
	print("HOUSE_POPULATION before=%s after=%s expected=%s updated=%s" % [before, game.population_cap, expected, updated])
	quit(0 if updated else 1)
