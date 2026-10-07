extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.title_open = false
	game.help_open = false
	game.paused = false
	while game.units.size() < 5:
		game.add_unit("worker", game.player_hall_position + Vector2(game.units.size() * 24, 180), 0)
	var nearest: Vector2 = game.forest_positions[0]
	var next_nearest: Vector2 = Vector2.INF
	for tree_pos in game.forest_positions:
		if tree_pos.distance_to(game.player_hall_position) < nearest.distance_to(game.player_hall_position): nearest = tree_pos
	var first: int = game.hit_resource(nearest)
	for tree_pos in game.forest_positions:
		if tree_pos == nearest: continue
		if next_nearest == Vector2.INF or tree_pos.distance_to(game.player_hall_position) < next_nearest.distance_to(game.player_hall_position): next_nearest = tree_pos
	var second: int = game.hit_resource(next_nearest)
	game.resources[first].amount = 30
	for index in 5:
		var unit: Dictionary = game.units[index]
		unit.worker_state = game.WORKER_TO_RESOURCE
		unit.resource = first
		unit.carry = 0
		unit.carry_kind = ""
		unit.flow_key = ""
		unit.flow_target = Vector2.INF
		unit.pos = game.resources[first].block_center + Vector2(65 + index * 10, 0)
		(game.unit_nodes[index] as Node2D).position = unit.pos
	var initial_wood: int = game.wood
	var expected_wood: int = initial_wood + 130
	for frame in 3600:
		await physics_frame
		if frame in [300, 900, 1800, 3599]:
			print("HARVEST_TRACE frame=%s first=%s second=%s wood=%s states=%s" % [frame, game.resources[first].amount, game.resources[second].amount, game.wood, game.units.slice(0, 5).map(func(unit): var field = game.navigation_fields.get(unit.flow_key); return {"state":unit.worker_state, "res":unit.resource, "carry":unit.carry, "pos":unit.pos, "target":unit.target, "flow":unit.flow_target, "return":unit.return_point, "moving":unit.moving, "vector":field.get_vector(unit.pos) if field != null else Vector2.ZERO, "origin":field.field_origin if field != null else Vector2i.ZERO, "size":field.field_size if field != null else Vector2i.ZERO})])
	var returned: bool = game.wood == expected_wood and game.resources[second].amount <= 0
	var active := 0
	for index in 5:
		if game.units[index].worker_state != game.WORKER_IDLE: active += 1
	print("HARVEST_RESULT returned=%s active=%s wood=%s expected=%s" % [returned, active, game.wood, expected_wood])
	quit(0 if returned and active == 0 else 1)
