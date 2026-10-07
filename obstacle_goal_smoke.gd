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
	var start: Vector2 = game.units[0].pos
	var closest_tree: Vector2 = game.forest_positions[0]
	for tree_pos in game.forest_positions:
		if tree_pos.distance_to(game.units[0].pos) < closest_tree.distance_to(game.units[0].pos): closest_tree = tree_pos
	var tree_index: int = game.hit_resource(closest_tree)
	var tree: Dictionary = game.resources[tree_index]
	# Aim behind the tree relative to the worker, forcing a genuine obstacle bypass.
	var goal: Vector2 = tree.block_center + (tree.block_center - start).normalized() * 180.0
	game.issue_command(goal)
	var min_distance := INF
	var blocked_frames := 0
	var stalled_at := Vector2.ZERO
	var stall_frame := -1
	for _frame in 1200:
		var before: Vector2 = game.units[0].pos
		await physics_frame
		min_distance = minf(min_distance, game.units[0].pos.distance_to(tree.block_center))
		if not game.units[0].moving: blocked_frames += 1
		if stall_frame < 0 and game.units[0].target.distance_to(game.units[0].pos) > 40.0 and game.units[0].pos.distance_to(before) < 0.01:
			stall_frame = _frame
			stalled_at = game.units[0].pos
	var worker: Dictionary = game.units[0]
	var body := game.unit_nodes[0] as CharacterBody2D
	var moved: bool = worker.pos.distance_to(start) > 60.0
	var outside: bool = worker.pos.distance_to(tree.block_center) >= tree.block_radius
	var direction := (game.navigation_fields[worker.flow_key] as FlowFieldManager).get_vector(worker.pos)
	var collisions: Array[String] = []
	for collision_index in body.get_slide_collision_count():
		var collision := body.get_slide_collision(collision_index)
		collisions.append("%s layer=%s" % [collision.get_collider().name, collision.get_collider().collision_layer])
	print("OBSTACLE_GOAL moved=%s outside=%s min_distance=%s blocked_frames=%s stall_frame=%s stalled_at=%s start=%s end=%s target=%s vector=%s body_collision=%s tree_center=%s radius=%s collisions=%s" % [moved, outside, min_distance, blocked_frames, stall_frame, stalled_at, start, worker.pos, worker.target, direction, worker.get("last_collision", ""), tree.block_center, tree.block_radius, collisions])
	quit(0 if moved and outside else 1)
