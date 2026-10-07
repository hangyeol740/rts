extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var worker_sprite := game.unit_nodes[0].get_node("Sprite") as Sprite2D
	var worker_texture := worker_sprite.texture
	var worker_region := worker_sprite.region_rect
	var worker_scale := worker_sprite.scale
	game.units[0].target += Vector2(200, 0)
	for _frame in 20: await physics_frame
	var preserved_worker := worker_sprite.texture == worker_texture and worker_sprite.region_rect == worker_region and worker_sprite.scale == worker_scale
	var gold_index: int = game.resources.find_custom(func(resource): return resource.kind == "gold")
	var gold: Dictionary = game.resources[gold_index]
	var scaled_collision := is_equal_approx(gold.block_radius, 16.0) and is_equal_approx(gold.gather_radius, 16.0)
	var resolution := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var resolution_ok: bool = resolution == Vector2(960, 540) and game.VIEW == Vector2(960, 540)
	print("AUTHORED_ASSET worker_preserved=%s scaled_collision=%s resolution=%s" % [preserved_worker, scaled_collision, resolution_ok])
	quit(0 if preserved_worker and scaled_collision and resolution_ok else 1)
