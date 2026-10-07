extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	var tower_pos: Vector2 = game.player_hall_position + Vector2(500, 0)
	game.add_building("tower", tower_pos, 0, true)
	game.add_unit("sword", tower_pos + Vector2(120, 0), 1)
	var enemy_index: int = game.units.size() - 1
	var before: int = game.units[enemy_index].hp
	for _frame in 120: await physics_frame
	var attacked: bool = game.units[enemy_index].hp < before
	print("TOWER_ATTACK before=%s after=%s attacked=%s" % [before, game.units[enemy_index].hp, attacked])
	quit(0 if attacked else 1)
