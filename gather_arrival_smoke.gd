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
	var checks: Array[bool] = []
	for resource_index in [0, game.hit_resource(game.forest_positions[0])]:
		var resource: Dictionary = game.resources[resource_index]
		var before: int = resource.amount
		game.units[0].pos = resource.block_center + Vector2(resource.block_radius + game.UNIT_RADIUS + game.flow_field.cell_size, 0)
		(game.unit_nodes[0] as Node2D).position = game.units[0].pos
		game.units[0].carry = 0
		game.units[0].flow_key = ""
		game.issue_command(resource.pos)
		for _frame in 300: await physics_frame
		checks.append(game.resources[resource_index].amount < before)
	print("GATHER_ARRIVAL gold=%s wood=%s" % [checks[0], checks[1]])
	quit(0 if checks.all(func(value): return value) else 1)
