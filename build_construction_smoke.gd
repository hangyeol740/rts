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
	game.build_mode = "barracks"
	var before: int = game.buildings.size()
	var build_pos := Vector2.INF
	for y in range(-8, 9):
		for x in range(-8, 9):
			var candidate: Vector2 = game.player_hall_position + Vector2(x, y) * 128.0
			if game.can_place_building("barracks", candidate):
				build_pos = candidate
				break
		if build_pos != Vector2.INF: break
	game.issue_command(build_pos)
	for _frame in 10: await physics_frame
	var created: bool = game.buildings.size() == before + 1
	var building: Dictionary = game.buildings.back()
	var complete: bool = created and building.has("block_shape") and building.has("block_rect") and building.has("radius")
	print("BUILD_SMOKE created=%s complete_collision_data=%s kind=%s position=%s" % [created, complete, building.kind, build_pos])
	quit(0 if complete else 1)
