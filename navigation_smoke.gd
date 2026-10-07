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
	var resource_position: Vector2 = game.resources[0].pos
	game.issue_command(resource_position)
	# Drive a deterministic ten-second simulation instead of advancing render
	# frames as fast as headless mode can produce them.
	game.set_process(false)
	for _frame in 1800:
		await physics_frame
	var worker: Dictionary = game.units[0]
	var gathered: bool = worker.carry > 0 or game.gold > game.stats.start.gold
	var moved: bool = worker.pos.distance_to(start) > 40.0
	var near_resource: bool = worker.pos.distance_to(game.resources[0].gather_center) <= game.resources[0].gather_radius + game.UNIT_RADIUS + game.flow_field.cell_size * 1.5
	var field = game.navigation_fields.get(worker.flow_key)
	var vector: Vector2 = field.get_vector(worker.pos) if field != null else Vector2.ZERO
	print("NAV_SMOKE moved=%s gathered=%s near_resource=%s start=%s end=%s target=%s flow_target=%s vector=%s field_origin=%s field_size=%s" % [moved, gathered, near_resource, start, worker.pos, worker.target, worker.flow_target, vector, field.field_origin if field != null else Vector2i.ZERO, field.field_size if field != null else Vector2i.ZERO])
	quit(0 if moved and gathered else 1)
