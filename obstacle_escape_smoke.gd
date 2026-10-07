extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var closest_tree: Vector2 = game.forest_positions[0]
	for tree_pos in game.forest_positions:
		if tree_pos.distance_to(game.units[0].pos) < closest_tree.distance_to(game.units[0].pos): closest_tree = tree_pos
	var tree_index: int = game.hit_resource(closest_tree)
	var tree: Dictionary = game.resources[tree_index]
	var worker: Dictionary = game.units[0]
	# Start just outside the physical tree blocker but inside the expanded Flow
	# Field clearance, then issue an order to the far side of the tree.
	worker.pos = tree.block_center + Vector2(-tree.block_radius - 3.0, 0)
	(game.unit_nodes[0] as CharacterBody2D).global_position = worker.pos
	game.selected_units.clear()
	game.selected_units.append(0)
	var start: Vector2 = worker.pos
	game.issue_command(tree.block_center + Vector2(160, 0))
	var escaped := false
	for _frame in 360:
		await physics_frame
		if game.units[0].pos.distance_to(start) > 24.0: escaped = true
	print("OBSTACLE_ESCAPE escaped=%s start=%s end=%s vector=%s" % [escaped, start, game.units[0].pos, (game.navigation_fields[game.units[0].flow_key] as FlowFieldManager).get_vector(game.units[0].pos)])
	quit(0 if escaped else 1)
