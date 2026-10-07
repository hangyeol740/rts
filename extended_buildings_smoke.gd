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
	for kind in ["archery", "tower"]:
		var texture: Texture2D = game.SpriteLibrary.texture(game.SpriteLibrary.path_for_building(kind, 0))
		var pos: Vector2 = game.player_hall_position + (Vector2(600, 0) if kind == "archery" else Vector2(-600, 0))
		game.add_building(kind, pos, 0, true)
		var index: int = game.buildings.size() - 1
		game.selected_building = index
		if kind == "archery": game.perform_action("archer")
		if texture == null or game.building_radius(kind) <= 0.0:
			print("EXTENDED_BUILDINGS kind=%s valid=false" % kind)
			quit(1)
	var archer_created: bool = game.units.any(func(unit): return unit.kind == "archer")
	print("EXTENDED_BUILDINGS archer_created=%s" % archer_created)
	quit(0 if archer_created else 1)
