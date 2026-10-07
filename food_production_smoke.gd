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
	game.food = 0
	game.selected_building = 0
	var before: int = game.units.size()
	game.perform_action("worker")
	var blocked: bool = game.units.size() == before
	game.food = 40
	game.perform_action("worker")
	var produced: bool = game.units.size() == before + 1 and game.food == 20
	print("FOOD_PRODUCTION blocked=%s produced=%s food=%s" % [blocked, produced, game.food])
	quit(0 if blocked and produced else 1)
