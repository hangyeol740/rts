extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	for count in [10, 25, 50, 100]:
		var game = MAIN_SCENE.instantiate()
		root.add_child(game)
		await process_frame
		game.title_open = false
		game.help_open = false
		game.paused = false
		game.set_process(false)
		game.set_physics_process(false)
		while game.units.size() < count:
			game.add_unit("worker", game.player_hall_position + Vector2(game.units.size() * 4, 220), 0)
		for unit in game.units:
			unit.target = unit.pos + Vector2(360, 160)
			unit.flow_key = ""
		var unit_start := Time.get_ticks_usec()
		for _frame in 30: game.update_units(1.0 / 60.0)
		var unit_us := Time.get_ticks_usec() - unit_start
		var visual_start := Time.get_ticks_usec()
		for _frame in 30: game.update_visual_nodes(1.0 / 60.0)
		var visual_us := Time.get_ticks_usec() - visual_start
		var forest := game.get_node("ForestRenderer") as ForestRenderer
		var forest_start := Time.get_ticks_usec()
		for _frame in 10: forest.refresh_visible_trees()
		var forest_us := Time.get_ticks_usec() - forest_start
		print("WORKER_BENCH count=%s units_us=%s visual_us=%s forest_us=%s active_trees=%s" % [count, unit_us, visual_us, forest_us, forest.active.size()])
		game.queue_free()
		await process_frame
	quit()
