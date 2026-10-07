extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var gold_count: int = game.resources.filter(func(r): return r.kind == "gold").size()
	var wood_count: int = game.resources.filter(func(r): return r.kind == "wood").size()
	var forest_count: int = game.forest_positions.size()
	var center: Vector2 = game.map_size * 0.5
	var clear_start := true
	for resource in game.resources:
		if resource.pos.distance_to(center) < 700.0: clear_start = false
	print("RESOURCE_MAP gold=%s harvestable_wood=%s visual_forest=%s clear_start=%s" % [gold_count, wood_count, forest_count, clear_start])
	quit(0 if gold_count >= 10 and forest_count >= 7000 and clear_start else 1)
