extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	while game.units.size() < 3:
		game.add_unit("worker", game.player_hall_position + Vector2(game.units.size() * 36, 180), 0)
	var sheep_index: int = game.resources.find_custom(func(resource): return resource.kind == "food")
	var sheep: Dictionary = game.resources[sheep_index]
	sheep.state = "meat"
	sheep.amount = 60
	sheep.hp = 0
	sheep.pos = game.player_hall_position + Vector2(280, 0)
	sheep.block_center = sheep.pos
	sheep.gather_center = sheep.pos
	for index in 3:
		var unit: Dictionary = game.units[index]
		unit.worker_state = game.WORKER_TO_RESOURCE
		unit.resource = sheep_index
		unit.flow_key = ""
		unit.flow_target = Vector2.INF
		unit.carry = 0
		unit.pos = sheep.pos + Vector2(70 + index * 10, 0)
		(game.unit_nodes[index] as Node2D).position = unit.pos
	await physics_frame
	var all_assigned := true
	for index in 3: all_assigned = all_assigned and game.units[index].worker_state != game.WORKER_IDLE and game.units[index].resource == sheep_index
	var start_food: int = game.food
	for _frame in 1800: await physics_frame
	var delivered: bool = game.food > start_food
	print("MULTI_MEAT assigned=%s delivered=%s food=%s" % [all_assigned, delivered, game.food])
	quit(0 if all_assigned and delivered else 1)
