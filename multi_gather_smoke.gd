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
	var first_tree_index: int = game.hit_resource(game.forest_positions[0])
	var second_tree_index: int = game.hit_resource(game.forest_positions[1])
	game.resources[first_tree_index].amount = 1
	for index in 3:
		var unit: Dictionary = game.units[index]
		unit.task = "gather"
		unit.resource = first_tree_index
		unit.carry = 0
		unit.flow_key = ""
		unit.flow_target = Vector2.INF
		unit.pos = game.resources[first_tree_index].block_center + Vector2(65 + index * 8, 0)
		(game.unit_nodes[index] as Node2D).position = unit.pos
	for _frame in 1200: await physics_frame
	var retargeted := true
	for index in 3:
		retargeted = retargeted and (game.units[index].resource != first_tree_index or game.units[index].carry > 0)
	print("MULTI_GATHER first=%s second=%s depleted=%s retargeted=%s resources=%s carry=%s tasks=%s" % [first_tree_index, second_tree_index, game.resources[first_tree_index].amount <= 0, retargeted, game.units.slice(0, 3).map(func(unit): return unit.resource), game.units.slice(0, 3).map(func(unit): return unit.carry), game.units.slice(0, 3).map(func(unit): return unit.task)])
	quit(0 if game.resources[first_tree_index].amount <= 0 and retargeted else 1)
