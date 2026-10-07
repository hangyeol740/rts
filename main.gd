extends Node2D

const SpriteLibrary = preload("res://scripts/sprite_library.gd")
const FlowFieldManager = preload("res://scripts/flow_field_manager.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const ForestRenderer = preload("res://scripts/forest_renderer.gd")
const ASSET_SCENES := {
	"worker": "res://scenes/assets/worker.tscn", "sword": "res://scenes/assets/sword.tscn", "archer": "res://scenes/assets/archer.tscn",
	"hall": "res://scenes/assets/hall.tscn", "barracks": "res://scenes/assets/barracks.tscn", "house": "res://scenes/assets/house.tscn", "archery": "res://scenes/assets/archery.tscn", "tower": "res://scenes/assets/tower.tscn",
	"gold": "res://scenes/assets/gold.tscn", "wood": "res://scenes/assets/tree.tscn", "food": "res://scenes/assets/sheep.tscn"
}
const VIEW := Vector2(960, 540)
const UNIT_RADIUS := 20.0
const UNIT_BUCKET_SIZE := 96.0
const WORKER_IDLE := "IDLE"
const WORKER_TO_RESOURCE := "TO_RESOURCE"
const WORKER_HARVESTING := "HARVESTING"
const WORKER_TO_HALL := "TO_HALL"
const WORKER_DEPOSITING := "DEPOSITING"
const WORKER_RETARGETING := "RETARGETING"
const PAPER := Color("cabba6")
const LEATHER := Color("5e4f40")
const EDGE := Color("3d2c22")
const ALLY := Color("3f8f7a")
const ENEMY := Color("a8322d")
const GOLD := Color("d9a63a")

var stats: Dictionary
@export_category("Map Settings")
@export var map_size := Vector2(19200, 19200)
@export var starting_camera := Vector2(8960, 9040)
@export var player_hall_position := Vector2(9400, 9600)
@export var enemy_hall_position := Vector2(23600, 17200)
@export_category("Visual Settings")
@export_range(0.5, 2.0, 0.05) var tree_scale := 1.3
@export_range(0.5, 2.0, 0.05) var unit_scale := 0.75
var camera_pos := Vector2(0, 420)
var units: Array = []
var buildings: Array = []
var resources: Array = []
var selected_units: Array[int] = []
var selected_building := -1
var selected_resource := -1
var gold := 150
var wood := 50
var food := 0
var population_cap := 8
var build_mode := ""
var message := "일꾼을 골라 금광에 오른쪽 클릭하세요."
var title_open := true
var help_open := false
var paused := false
var dragging := false
var drag_start := Vector2.ZERO
var animation_time := 0.0
var world_redraw_time := 0.0
var command_ping := {"pos": Vector2.ZERO, "type": "", "time": 0.0}
var floating: Array = []
var zoom := 1.0
var flow_field := FlowFieldManager.new()
var navigation_fields: Dictionary = {}
var navigation_field_serial := 0
var navigation_obstacle_index: Dictionary = {}
var reroute_queue: Array[int] = []
var reroutes_this_frame := 0
var unit_nodes: Array[Node2D] = []
var unit_buckets: Dictionary = {}
var building_nodes: Array[Node2D] = []
var resource_nodes: Array[Node2D] = []
var generated_resource_nodes: Array[Node2D] = []
var forest_positions: Array[Vector2] = []
var forest_navigation_buckets: Dictionary = {}
var harvested_forest_positions: Dictionary = {}
var activated_forest_positions: Dictionary = {}
var map_noise := FastNoiseLite.new()
var map_rng := RandomNumberGenerator.new()

func _ready() -> void:
	stats = JSON.parse_string(FileAccess.get_file_as_string("res://data/stats.json"))
	$UIInterface.game = self
	var minimap := $UIInterface.get_node("HUD/Minimap") as GameMinimap
	minimap.game = self
	$UIInterface.action_requested.connect(perform_action)
	$UIInterface.start_requested.connect(func(): title_open = false; help_open = true; $UIInterface.refresh(self))
	$UIInterface.help_closed.connect(func(): help_open = false; $UIInterface.refresh(self))
	$UIInterface.pause_closed.connect(func(): paused = false; $UIInterface.refresh(self))
	reset_game()

func skin_texture(name: String) -> Texture2D:
	return load("res://assets/generated_ui/" + name) as Texture2D

func sl_tex(path: String) -> Texture2D:
	return SpriteLibrary.texture(path)

func reset_game() -> void:
	for node in generated_resource_nodes:
		if is_instance_valid(node): node.queue_free()
	generated_resource_nodes.clear()
	forest_positions.clear()
	forest_navigation_buckets.clear()
	harvested_forest_positions.clear()
	activated_forest_positions.clear()
	unit_nodes.clear(); building_nodes.clear(); resource_nodes.clear()
	units.clear(); buildings.clear(); resources.clear(); selected_units.clear(); selected_building = -1; selected_resource = -1
	gold = stats.start.gold; wood = stats.start.wood; food = stats.start.food; population_cap = stats.start.population_limit
	zoom = 1.0
	camera_pos = starting_camera
	sync_camera()
	load_editor_placed_objects()
	generate_starting_map()
	flow_field.configure(map_size)
	refresh_navigation_obstacle_index()
	navigation_fields.clear()
	message = "일꾼을 골라 금광에 오른쪽 클릭하세요."
	$UIInterface.refresh(self)
	queue_redraw()

func generate_starting_map() -> void:
	# Start area remains open. Resources form readable veins and forest clusters,
	# not isolated dots scattered around the player.
	map_rng.randomize()
	map_noise.seed = map_rng.randi()
	map_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	map_noise.frequency = 0.0018
	var layout: Dictionary = WorldGenerator.generate_resource_layout(map_size, map_rng, map_noise)
	var center: Vector2 = layout.center
	var hall_index := nearest_building(center, 0, "hall")
	if hall_index >= 0:
		var hall_offset: Vector2 = buildings[hall_index].block_center - buildings[hall_index].pos
		var hall_delta: Vector2 = center - buildings[hall_index].pos
		buildings[hall_index].pos = center
		buildings[hall_index].block_center = center + hall_offset
		buildings[hall_index].block_rect.position += hall_delta
		buildings[hall_index].block_shape.center += hall_delta
		$PlayerHall.position = center
		# Re-read the authored Marker2D after moving the hall. Both X and Y
		# remain fully controlled by hall.tscn > DropOffPoint.
		var drop_marker := $PlayerHall.get_node_or_null("DropOffPoint") as Marker2D
		buildings[hall_index].drop_point = center + (drop_marker.position if drop_marker != null else Vector2.ZERO)
	for i in units.size():
		units[i].pos = center + Vector2(150 + i * 48, 120 + (i % 2) * 42)
		units[i].target = units[i].pos
		(unit_nodes[i] as CharacterBody2D).global_position = units[i].pos
	for i in resources.size():
		var resource: Dictionary = resources[i]
		if resource.kind == "wood":
			# Authored starter trees become visual forest data instead of duplicate
			# Sprite/StaticBody/Area nodes.
			resource_nodes[i].queue_free()
			continue
		var block_offset: Vector2 = resource.block_center - resource.pos
		var gather_offset: Vector2 = resource.gather_center - resource.pos
		var angle := map_rng.randf_range(0.0, TAU)
		var distance := map_rng.randf_range(900.0, 1400.0)
		var pos := center + Vector2.RIGHT.rotated(angle) * distance
		resource.pos = pos
		resource.block_center = pos + block_offset
		resource.gather_center = pos + gather_offset
		resource_nodes[i].position = pos
	# Keep only gold from authored resource scenes. Wood is represented by forest
	# data and becomes a real resource node only after a player targets it.
	var kept_resources: Array = []
	var kept_nodes: Array[Node2D] = []
	for i in resources.size():
		if resources[i].kind != "wood":
			kept_resources.append(resources[i])
			kept_nodes.append(resource_nodes[i])
	resources = kept_resources
	resource_nodes = kept_nodes
	for gold_pos in layout.gold:
		add_resource("gold", gold_pos, 1000, true)
	for sheep_pos in layout.sheep:
		add_resource("food", sheep_pos, int(stats.sheep.food), true)
	forest_positions = layout.wood
	rebuild_forest_navigation_buckets()
	($ForestRenderer as ForestRenderer).setup(forest_positions, self)
	navigation_fields.clear()

func load_editor_placed_objects() -> void:
	for node in get_children():
		if not node.has_meta("asset_kind"): continue
		var kind: String = node.get_meta("asset_kind")
		if kind in ["worker", "sword", "archer"]:
			var unit_stats: Dictionary = stats[kind]
			var body := collision_data(node, 20.0, "")
			units.append(new_unit_data(kind, node.position, 0 if String(node.get_meta("team", "Blue")) == "Blue" else 1, unit_stats, body.radius))
			unit_nodes.append(node)
			node.set_meta("asset_base_scale", node.scale)
		elif kind in ["hall", "barracks", "house", "archery", "tower"]:
			var building_stats: Dictionary = stats[kind]
			var block := collision_data(node, 100.0, "Blocker")
			var drop_marker := node.get_node_or_null("DropOffPoint") as Marker2D
			var drop_point: Vector2 = node.position + drop_marker.position if drop_marker != null else node.position
			buildings.append({"kind":kind, "pos":node.position, "team":0 if String(node.get_meta("team", "Blue")) == "Blue" else 1, "hp":building_stats.health, "max_hp":building_stats.health, "done":true, "progress":1.0, "queue":[], "queue_time":0.0, "attack_cooldown":0.0, "radius":block.radius, "block_center":node.position + block.offset, "block_rect":block.rect, "block_shape":block.shape, "drop_point":drop_point})
			if kind == "house" and String(node.get_meta("team", "Blue")) == "Blue": population_cap += building_stats.population
			building_nodes.append(node)
			node.set_meta("asset_base_scale", node.scale)
		elif kind in ["gold", "wood", "food"]:
			var block := collision_data(node, 40.0, "Blocker")
			var gather := collision_data(node, 80.0, "GatherRange")
			resources.append({"pos":node.position, "kind":kind, "amount":int(node.get_meta("amount", 100)), "stump":false, "state":"sheep" if kind == "food" else "resource", "hp":int(stats.sheep.health) if kind == "food" else 0, "max_hp":int(stats.sheep.health) if kind == "food" else 0, "wander_target":node.position, "wander_time":map_rng.randf_range(0.25, 0.75), "sheep_walking":false, "block_radius":block.radius, "block_center":node.position + block.offset, "block_rect":block.rect, "block_shape":block.shape, "gather_radius":gather.radius, "gather_center":node.position + gather.offset})
			resource_nodes.append(node)
			node.set_meta("asset_base_scale", node.scale)

func collision_data(node: Node2D, fallback: float, area_name := "Blocker") -> Dictionary:
	var shape_path := "CollisionShape2D" if area_name == "" else area_name + "/CollisionShape2D"
	var shape_node := node.get_node_or_null(shape_path) as CollisionShape2D
	if shape_node == null:
		return {"radius":fallback, "offset":Vector2.ZERO, "rect":Rect2(node.position - Vector2(fallback, fallback), Vector2(fallback * 2, fallback * 2)), "shape":{"type":"circle", "center":node.position, "radius":fallback}}
	# Read-only: gameplay never changes the authored CollisionShape2D resource.
	# Radius is only a navigation approximation of the existing shape.
	var radius := fallback
	var size := Vector2(radius * 2, radius * 2)
	if shape_node.shape is CircleShape2D:
		radius = (shape_node.shape as CircleShape2D).radius
		size = Vector2(radius * 2, radius * 2)
	elif shape_node.shape is CapsuleShape2D:
		var capsule := shape_node.shape as CapsuleShape2D
		radius = capsule.radius
		size = Vector2(radius * 2, capsule.height)
		if absf(shape_node.rotation) > PI * 0.25: size = Vector2(size.y, size.x)
	elif shape_node.shape is RectangleShape2D:
		size = (shape_node.shape as RectangleShape2D).size
		radius = maxf(size.x, size.y) * 0.5
	var root_scale := node.scale.abs()
	var center := node.position + shape_node.position * root_scale
	size *= root_scale
	radius *= maxf(root_scale.x, root_scale.y)
	var shape_data := {"type":"circle", "center":center, "radius":radius}
	if shape_node.shape is RectangleShape2D:
		shape_data = {"type":"rectangle", "center":center, "size":size, "rotation":shape_node.rotation}
	elif shape_node.shape is CapsuleShape2D:
		shape_data = {"type":"capsule", "center":center, "radius":radius, "height":(shape_node.shape as CapsuleShape2D).height * root_scale.y, "rotation":shape_node.rotation}
	return {"radius":radius, "offset":shape_node.position * root_scale, "rect":Rect2(center - size * 0.5, size), "shape":shape_data}

func add_unit(kind: String, pos: Vector2, team: int) -> void:
	var s: Dictionary = stats[kind]
	var visual := load(ASSET_SCENES[kind]).instantiate() as Node2D
	visual.set_meta("asset_kind", kind)
	visual.position = pos
	var body := collision_data(visual, 20.0, "")
	units.append(new_unit_data(kind, pos, team, s, body.radius))
	add_child(visual); unit_nodes.append(visual)

func new_unit_data(kind: String, pos: Vector2, team: int, unit_stats: Dictionary, body_radius: float) -> Dictionary:
	return {"kind":kind, "pos":pos, "target":pos, "resume_target":Vector2.INF, "resume_flow_target":Vector2.INF, "team":team, "hp":unit_stats.health, "max_hp":unit_stats.health, "worker_state":WORKER_IDLE, "resource":-1, "queued_resource":-1, "slaughter_resource":-1, "return_point":Vector2.INF, "carry":0, "carry_kind":"", "attack_type":"", "attack_index":-1, "cooldown":0.0, "repath_cooldown":0.0, "direction":Vector2.DOWN, "flow_target":pos, "flow_key":"", "moving":false, "body_radius":body_radius, "gather_progress":0.0}

func add_building(kind: String, pos: Vector2, team: int, done := false) -> void:
	var s: Dictionary = stats[kind]
	var visual := load(ASSET_SCENES[kind]).instantiate() as Node2D
	visual.set_meta("asset_kind", kind)
	visual.position = pos
	add_child(visual)
	var block := collision_data(visual, 100.0, "Blocker")
	var drop_marker := visual.get_node_or_null("DropOffPoint") as Marker2D
	var drop_point: Vector2 = pos + drop_marker.position if drop_marker != null else pos
	buildings.append({"kind":kind, "pos":pos, "team":team, "hp":s.health, "max_hp":s.health, "done":done, "progress":1.0 if done else 0.0, "queue":[], "queue_time":0.0, "attack_cooldown":0.0, "radius":block.radius, "block_center":pos + block.offset, "block_rect":block.rect, "block_shape":block.shape, "drop_point":drop_point})
	if kind == "house" and team == 0 and done: population_cap += s.population
	building_nodes.append(visual)
	refresh_navigation_obstacle_index()

func add_resource(kind: String, pos: Vector2, amount: int, generated := false, forest_visual := false) -> void:
	var visual := load(ASSET_SCENES[kind]).instantiate() as Node2D
	visual.set_meta("asset_kind", kind)
	visual.set_meta("amount", amount)
	visual.position = pos
	add_child(visual)
	# ForestRenderer remains the visible tree while this node provides only
	# harvesting/collision data. Do not make a clicked tree disappear.
	if forest_visual:
		var sprite := visual.get_node_or_null("Sprite") as Sprite2D
		if sprite != null: sprite.visible = false
	var block := collision_data(visual, 40.0, "Blocker")
	var gather := collision_data(visual, 80.0, "GatherRange")
	resources.append({"pos":pos, "kind":kind, "amount":amount, "stump":false, "state":"sheep" if kind == "food" else "resource", "hp":int(stats.sheep.health) if kind == "food" else 0, "max_hp":int(stats.sheep.health) if kind == "food" else 0, "wander_target":pos, "wander_time":map_rng.randf_range(0.25, 0.75), "sheep_walking":false, "forest_visual":forest_visual, "block_radius":block.radius, "block_center":pos + block.offset, "block_rect":block.rect, "block_shape":block.shape, "gather_radius":gather.radius, "gather_center":pos + gather.offset})
	resource_nodes.append(visual)
	if generated: generated_resource_nodes.append(visual)

func _process(delta: float) -> void:
	if title_open or help_open or paused: return
	animation_time += delta; command_ping.time = maxf(0.0, command_ping.time - delta)
	move_camera(delta)
	update_buildings(delta)
	update_enemy(delta)
	update_visual_nodes(delta)
	for i in range(floating.size() - 1, -1, -1):
		floating[i].time -= delta; floating[i].pos.y -= 24.0 * delta
		if floating[i].time <= 0: floating.remove_at(i)
	world_redraw_time -= delta
	if world_redraw_time <= 0.0 or build_mode != "" or dragging:
		world_redraw_time = 1.0 / 30.0
		queue_redraw()

func _physics_process(delta: float) -> void:
	if title_open or help_open or paused: return
	update_sheep(delta)
	eject_embedded_units()
	update_units(delta)

func eject_embedded_units() -> void:
	for unit_index in units.size():
		var unit: Dictionary = units[unit_index]
		if unit.hp <= 0: continue
		for building_index in buildings.size():
			var building: Dictionary = buildings[building_index]
			if building.hp <= 0 or not flow_field.shape_contains(building.block_shape, unit.pos, unit.body_radius): continue
			var delivering: bool = unit.get("worker_state", WORKER_IDLE) == WORKER_TO_HALL and unit.carry > 0 and building.kind == "hall" and unit.return_point != Vector2.INF and unit.flow_target.distance_to(unit.return_point) <= 4.0
			if delivering: continue
			var escape := nearest_building_exit(building_index, unit.pos, unit.body_radius, unit_index)
			unit.resume_target = unit.target
			unit.resume_flow_target = unit.flow_target
			unit.pos = escape
			(unit_nodes[unit_index] as CharacterBody2D).global_position = escape
			unit.target = escape
			unit.flow_target = escape
			unit.flow_key = ""
			unit.repath_cooldown = 0.10
			break

func nearest_building_exit(building_index: int, from: Vector2, unit_radius: float, seed := 0) -> Vector2:
	var building: Dictionary = buildings[building_index]
	var blocker_extent: float = maxf(building.block_rect.size.x, building.block_rect.size.y) * 0.5
	var best: Vector2 = building.block_center + Vector2.DOWN * (blocker_extent + unit_radius + 16.0)
	var best_distance := INF
	for ring in range(1, 4):
		var distance: float = blocker_extent + unit_radius + 12.0 + ring * 24.0
		for step in 16:
			var angle := TAU * float(step + seed * 5) / 16.0
			var candidate: Vector2 = building.block_center + Vector2.RIGHT.rotated(angle) * distance
			if flow_field.shape_contains(building.block_shape, candidate, unit_radius): continue
			if movement_blocked_except(candidate, unit_radius, building_index): continue
			var candidate_distance: float = candidate.distance_squared_to(from)
			if candidate_distance < best_distance:
				best = candidate
				best_distance = candidate_distance
	return best

func update_sheep(delta: float) -> void:
	for resource in resources:
		if resource.kind != "food" or resource.state != "sheep": continue
		if not resource.sheep_walking:
			resource.wander_time -= delta
			if resource.wander_time > 0.0: continue
			resource.wander_target = resource.pos + Vector2.RIGHT.rotated(map_rng.randf_range(0.0, TAU)) * map_rng.randf_range(48.0, 120.0)
			resource.wander_target.x = clampf(resource.wander_target.x, 48.0, map_size.x - 48.0)
			resource.wander_target.y = clampf(resource.wander_target.y, 48.0, map_size.y - 48.0)
			resource.sheep_walking = true
		var direction: Vector2 = resource.pos.direction_to(resource.wander_target)
		resource.pos += direction * minf(36.0 * delta, resource.pos.distance_to(resource.wander_target))
		if resource.pos.distance_to(resource.wander_target) < 1.0:
			resource.pos = resource.wander_target
			resource.sheep_walking = false
			resource.wander_time = map_rng.randf_range(0.35, 1.0)
		var delta_pos: Vector2 = resource.pos - resource.block_center
		resource.block_center += delta_pos
		resource.gather_center += delta_pos
		resource.block_rect.position += delta_pos
		resource.block_shape.center += delta_pos

func move_camera(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
	camera_pos += move.normalized() * 600.0 * delta / zoom
	clamp_camera()
	sync_camera()

func update_units(delta: float) -> void:
	reroutes_this_frame = 0
	rebuild_unit_buckets()
	for i in units.size():
		var u: Dictionary = units[i]
		if u.hp <= 0: continue
		u.cooldown = maxf(0.0, u.cooldown - delta)
		u.repath_cooldown = maxf(0.0, float(u.get("repath_cooldown", 0.0)) - delta)
		if u.get("worker_state", WORKER_IDLE) != WORKER_IDLE: update_gather(i, delta)
		elif u.attack_type != "": update_attack(i, delta)
		else: move_unit(u, u.target, stats[u.kind].speed * delta)
	for i in range(units.size() - 1, -1, -1):
		if units[i].hp <= 0:
			for selection_index in range(selected_units.size() - 1, -1, -1):
				if selected_units[selection_index] == i: selected_units.remove_at(selection_index)
				elif selected_units[selection_index] > i: selected_units[selection_index] -= 1
			for survivor in units:
				if survivor.attack_type == "unit":
					if survivor.attack_index == i: survivor.attack_type = ""
					elif survivor.attack_index > i: survivor.attack_index -= 1
			units.remove_at(i)
			unit_nodes[i].queue_free(); unit_nodes.remove_at(i)

func rebuild_unit_buckets() -> void:
	unit_buckets.clear()
	for index in units.size():
		var unit: Dictionary = units[index]
		if unit.hp <= 0: continue
		var key := Vector2i(floori(unit.pos.x / UNIT_BUCKET_SIZE), floori(unit.pos.y / UNIT_BUCKET_SIZE))
		if not unit_buckets.has(key): unit_buckets[key] = []
		unit_buckets[key].append(index)

func update_visual_nodes(delta: float) -> void:
	for i in units.size():
		var u: Dictionary = units[i]
		# CharacterBody2D owns its physical world position; never overwrite it
		# from the visual update loop after move_and_slide().
		unit_nodes[i].scale = unit_nodes[i].get_meta("asset_base_scale", Vector2.ONE)
		unit_nodes[i].z_index = clampi(int(u.pos.y / 8.0), -4000, 4000)
		var gathering: bool = u.get("worker_state", WORKER_IDLE) == WORKER_HARVESTING
		var moving: bool = u.moving
		var slaughtering: bool = u.attack_type == "sheep" and u.attack_index >= 0 and u.cooldown > 0.45
		var visual_carry: String = u.carry_kind if u.carry > 0 else ("food" if slaughtering else (String(resources[u.resource].kind) if gathering else ""))
		var animation := "gather_%s" % visual_carry if gathering or slaughtering else ("attack" if u.attack_type != "" and u.cooldown > 0.45 else ("carry_%s" % visual_carry if visual_carry != "" else ("walk" if moving else "idle")))
		update_asset_sprite(unit_nodes[i], animation, u.direction)
		var health_bar := unit_nodes[i].get_node_or_null("HealthBar") as Node2D
		if health_bar != null:
			health_bar.visible = i in selected_units
			var fill := health_bar.get_node_or_null("Fill") as TextureProgressBar
			if fill != null: fill.value = fill.max_value * float(u.hp) / float(u.max_hp)
	for i in buildings.size():
		var b: Dictionary = buildings[i]
		building_nodes[i].visible = b.hp > 0
		building_nodes[i].position = b.pos
		building_nodes[i].scale = building_nodes[i].get_meta("asset_base_scale", Vector2.ONE)
		building_nodes[i].z_index = clampi(int(b.block_center.y / 8.0), -4000, 4000)
	var resource_view := Rect2(camera_pos - Vector2(360, 360), visible_size() + Vector2(720, 720))
	for i in resources.size():
		var r: Dictionary = resources[i]
		var on_screen: bool = resource_view.has_point(r.pos)
		resource_nodes[i].visible = on_screen and (r.amount > 0 or r.stump)
		if not on_screen: continue
		resource_nodes[i].position = r.pos
		resource_nodes[i].scale = resource_nodes[i].get_meta("asset_base_scale", Vector2.ONE)
		resource_nodes[i].z_index = clampi(int(r.block_center.y / 8.0), -4000, 4000)
		resource_nodes[i].modulate.a = 0.42 if resource_is_in_front_of_unit(r) else 1.0
		if r.stump: update_resource_sprite(resource_nodes[i], r)
		if r.kind == "food": update_sheep_sprite(resource_nodes[i], r)

func update_asset_sprite(node: Node2D, animation: String, direction: Vector2) -> void:
	var sprite := node.get_node_or_null("Animation") as AnimatedSprite2D
	if sprite == null: return
	if not sprite.sprite_frames.has_animation(animation): animation = "idle"
	if sprite.animation != animation or not sprite.is_playing(): sprite.play(animation)
	if absf(direction.x) > 0.1: sprite.flip_h = direction.x < 0.0

func update_resource_sprite(node: Node2D, resource: Dictionary) -> void:
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	if sprite == null: return
	if resource.kind == "wood" and resource.stump:
		var stump := node.get_node_or_null("RuntimeStump") as Sprite2D
		if stump == null:
			stump = Sprite2D.new()
			stump.name = "RuntimeStump"
			stump.texture = SpriteLibrary.texture(SpriteLibrary.stump_path(1))
			stump.position = sprite.position
			stump.offset = sprite.offset
			stump.centered = sprite.centered
			stump.scale = sprite.scale
			node.add_child(stump)
		sprite.visible = false
		stump.visible = true

func update_sheep_sprite(node: Node2D, resource: Dictionary) -> void:
	var sheep := node.get_node_or_null("Sprite") as Sprite2D
	var moving_sheep := node.get_node_or_null("MoveSprite") as AnimatedSprite2D
	var meat := node.get_node_or_null("MeatSprite") as Sprite2D
	var walking: bool = resource.state == "sheep" and resource.get("sheep_walking", false)
	if sheep != null: sheep.visible = resource.state == "sheep" and not walking
	if moving_sheep != null:
		moving_sheep.visible = walking
		moving_sheep.flip_h = resource.wander_target.x < resource.pos.x
		if walking and not moving_sheep.is_playing(): moving_sheep.play("move")
		elif not walking: moving_sheep.stop()
	if meat != null: meat.visible = resource.state == "meat" and resource.amount > 0

func resource_is_in_front_of_unit(resource: Dictionary) -> bool:
	if resource.kind != "wood": return false
	for unit in units:
		if unit.pos.y < resource.pos.y and absf(unit.pos.x - resource.pos.x) < 54.0 and unit.pos.distance_to(resource.pos) < 150.0: return true
	return false

func update_gather(index: int, delta: float) -> void:
	var u: Dictionary = units[index]
	u.is_harvesting = false
	if u.resource < 0 or u.resource >= resources.size():
		if u.carry > 0:
			u.worker_state = WORKER_TO_HALL
			u.return_point = Vector2.INF
			u.flow_key = ""
			move_unit(u, u.target, stats[u.kind].speed * delta)
		else:
			set_worker_idle(u)
		return
	var r: Dictionary = resources[u.resource] as Dictionary
	# Carry capacity or depletion is an explicit state transition, never an
	# inferred side effect inside the harvesting branch.
	if u.worker_state != WORKER_TO_HALL and u.worker_state != WORKER_DEPOSITING and u.carry > 0 and (u.carry >= 10 or r.amount <= 0):
		u.worker_state = WORKER_TO_HALL
		u.return_point = Vector2.INF
		u.flow_key = ""
	if u.worker_state == WORKER_TO_HALL or u.worker_state == WORKER_DEPOSITING:
		var hall := nearest_building(u.pos, u.team, "hall")
		if hall < 0: set_worker_idle(u); return
		if u.return_point == Vector2.INF:
			u.return_point = hall_return_point(hall, u.pos, u.body_radius, index)
		var return_pos: Vector2 = u.return_point
		var drop_range: float = u.body_radius + flow_field.cell_size * 2.0
		if u.flow_target.distance_to(return_pos) > 4.0:
			var key := navigation_field_key(return_pos, [u.pos])
			set_navigation_target(u, navigation_field_target(key), return_pos, key)
			u.worker_state = WORKER_TO_HALL
		if u.pos.distance_to(return_pos) <= drop_range:
			u.worker_state = WORKER_DEPOSITING
			if u.team == 0:
				if u.carry_kind == "gold": gold += u.carry
				elif u.carry_kind == "wood": wood += u.carry
				else: food += u.carry
				floating.append({"pos":buildings[hall].pos + Vector2(0, -90), "text":"+%d" % u.carry, "color":GOLD if u.carry_kind == "gold" else (Color("6f9d62") if u.carry_kind == "wood" else Color("d66b50")), "time":0.8})
				# Resource values changed: immediately update the top-left UI labels.
				$UIInterface.refresh(self)
			var next_resource: int = u.queued_resource if resource_is_harvestable(u.queued_resource) else (-1)
			if next_resource < 0 and resource_is_harvestable(u.resource): next_resource = u.resource
			if next_resource < 0: next_resource = nearest_resource(u.pos, r.kind)
			u.carry = 0; u.carry_kind = ""; u.return_point = Vector2.INF; u.queued_resource = -1
			if next_resource >= 0:
				u.resource = next_resource
				u.worker_state = WORKER_TO_RESOURCE
				u.flow_target = Vector2.INF
				u.flow_key = ""
			else:
				set_worker_idle(u)
	else:
		if not resource_is_harvestable(u.resource):
			begin_return_or_retarget(u, r.kind)
			move_unit(u, u.target, stats[u.kind].speed * delta)
			return
		if u.worker_state == WORKER_RETARGETING: u.worker_state = WORKER_TO_RESOURCE
		# Field positions are cell centers. Add only half a cell diagonal as
		# quantization tolerance, not an arbitrary enlarged hitbox.
		# The unit stops on an 8px cell center. This is interaction tolerance only;
		# it does not alter the Blocker collision radius used for movement.
		# Tree sprites have a wide canopy but a narrow authored GatherRange shape.
		# Accepting the obstacle-edge approach prevents a worker from idling at a
		# valid path cell just outside that narrow interaction shape.
		var gather_range: float = maxf(r.gather_radius + UNIT_RADIUS + flow_field.cell_size * 1.5, r.block_radius + UNIT_RADIUS + flow_field.cell_size * 3.0)
		if u.flow_key == "" or not navigation_fields.has(u.flow_key) or u.flow_target.distance_to(r.gather_center) > 4.0:
			# Buildings are kept outside the GatherRange at placement time, so the
			# current-facing approach remains a stable reachable gathering point.
			var approach: Vector2 = (u.pos - r.block_center).normalized()
			if approach.length() < 0.1: approach = Vector2.RIGHT
			var approach_target: Vector2 = r.block_center + approach * (r.block_radius + UNIT_RADIUS)
			var key := navigation_field_key(approach_target, [u.pos])
			set_navigation_target(u, navigation_field_target(key), r.gather_center, key)
		var reached_path_goal: bool = u.pos.distance_to(u.target) <= flow_field.cell_size and u.target.distance_to(r.block_center) <= r.block_radius + UNIT_RADIUS + flow_field.cell_size * 2.0
		if u.pos.distance_to(r.gather_center) <= gather_range or reached_path_goal:
			u.worker_state = WORKER_HARVESTING
			u.is_harvesting = true
			# Meat is collected in one short but visible interaction, then carried.
			var gather_rate := 12.0 if r.kind == "food" else 4.0
			u.gather_progress = float(u.get("gather_progress", 0.0)) + gather_rate * delta
			var amount: int = mini(10 - int(u.carry), mini(r.amount, floori(u.gather_progress)))
			u.gather_progress -= amount
			u.carry += amount; u.carry_kind = r.kind; r.amount -= amount
			if r.amount <= 0:
				r.stump = r.kind == "wood"
				if r.stump:
					harvested_forest_positions[r.pos] = true
					if r.forest_visual:
						($ForestRenderer as ForestRenderer).hide_tree(r.pos)
						var sprite := resource_nodes[u.resource].get_node_or_null("Sprite") as Sprite2D
						if sprite != null: sprite.visible = true
					var blocker := resource_nodes[u.resource].get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
					if blocker != null: blocker.set_deferred("disabled", true)
					navigation_fields.clear()
					refresh_navigation_obstacle_index()
				assign_next_resource_to_gatherers(u.resource, r.kind)
	move_unit(u, u.target, stats[u.kind].speed * delta)

func resource_is_harvestable(index: int) -> bool:
	return index >= 0 and index < resources.size() and resources[index].amount > 0 and (resources[index].kind != "food" or resources[index].state == "meat")

func begin_return_or_retarget(unit: Dictionary, kind: String) -> void:
	if unit.carry > 0:
		unit.worker_state = WORKER_TO_HALL
		unit.return_point = Vector2.INF
		unit.flow_key = ""
	else:
		var replacement := nearest_resource(unit.pos, kind)
		if replacement >= 0:
			unit.resource = replacement
			unit.worker_state = WORKER_RETARGETING
			unit.flow_target = Vector2.INF
			unit.flow_key = ""
		else:
			set_worker_idle(unit)

func set_worker_idle(unit: Dictionary) -> void:
	unit.worker_state = WORKER_IDLE
	unit.resource = -1
	unit.queued_resource = -1
	unit.return_point = Vector2.INF
	unit.flow_key = ""
	unit.flow_target = unit.pos
	unit.gather_progress = 0.0

func assign_next_resource_to_gatherers(depleted_index: int, kind: String) -> void:
	for unit in units:
		if unit.get("worker_state", WORKER_IDLE) == WORKER_IDLE or unit.resource != depleted_index: continue
		# Carriers complete their current load first; empty workers retarget now.
		if unit.carry > 0:
			unit.worker_state = WORKER_TO_HALL
			unit.return_point = Vector2.INF
			unit.flow_key = ""
			continue
		begin_return_or_retarget(unit, kind)

func hall_return_point(hall_index: int, from: Vector2, unit_radius: float, unit_index := 0) -> Vector2:
	var hall: Dictionary = buildings[hall_index]
	var marker: Vector2 = hall.drop_point
	# The authored marker can sit inside the visual/Blocker footprint. Route to
	# the nearest outside point facing the carrier, then deposit there.
	if not flow_field.shape_contains(hall.block_shape, marker, unit_radius): return marker
	var extent: float = maxf(hall.block_rect.size.x, hall.block_rect.size.y) * 0.5
	# Spread carriers over authored hall-front approaches instead of forcing every
	# worker through one point.
	var angle := PI * 0.25 + TAU * float(unit_index % 7) / 7.0
	return hall.block_center + Vector2.RIGHT.rotated(angle) * (extent + unit_radius + flow_field.cell_size)

func nearest_resource(from: Vector2, kind: String) -> int:
	var nearest := -1
	var best_distance := INF
	for i in resources.size():
		if resources[i].kind != kind or not resource_is_harvestable(i): continue
		var distance := from.distance_to(resources[i].pos)
		if distance < best_distance:
			best_distance = distance
			nearest = i
	return nearest

func update_attack(index: int, delta: float) -> void:
	var u: Dictionary = units[index]
	var target_pos := Vector2.ZERO; var valid := false
	if u.attack_type == "unit" and u.attack_index >= 0 and u.attack_index < units.size() and units[u.attack_index].hp > 0:
		target_pos = units[u.attack_index].pos; valid = true
	elif u.attack_type == "building" and u.attack_index >= 0 and u.attack_index < buildings.size() and buildings[u.attack_index].hp > 0:
		target_pos = buildings[u.attack_index].pos; valid = true
	elif u.attack_type == "sheep" and u.attack_index >= 0 and u.attack_index < resources.size() and resources[u.attack_index].kind == "food" and resources[u.attack_index].state == "sheep":
		target_pos = resources[u.attack_index].block_center; valid = true
	if not valid: u.attack_type = ""; return
	var reach: float = stats[u.kind].range + 35.0
	if u.attack_type == "building": reach += building_radius(buildings[u.attack_index].kind) + 30.0
	if u.pos.distance_to(target_pos) > reach:
		var attack_target: Vector2 = attack_position(target_pos, u.pos, reach)
		if u.flow_target.distance_to(attack_target) > flow_field.cell_size:
			var key := navigation_field_key(attack_target, [u.pos])
			set_navigation_target(u, navigation_field_target(key), attack_target, key)
		move_unit(u, u.target, stats[u.kind].speed * delta)
	elif u.cooldown <= 0:
		u.direction = (target_pos - u.pos).normalized()
		var damage: int = stats[u.kind].attack
		if u.attack_type == "unit": units[u.attack_index].hp -= damage
		elif u.attack_type == "building": buildings[u.attack_index].hp -= damage
		else:
			resources[u.attack_index].hp -= damage
			if resources[u.attack_index].hp <= 0: slaughter_sheep(u.attack_index)
		floating.append({"pos":target_pos + Vector2(0, -50), "text":str(damage), "color":Color.WHITE, "time":0.6})
		u.cooldown = 0.8

func slaughter_sheep(index: int) -> void:
	var sheep: Dictionary = resources[index]
	if sheep.kind != "food" or sheep.state != "sheep": return
	sheep.state = "meat"
	sheep.hp = 0
	var blocker := resource_nodes[index].get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
	if blocker != null: blocker.set_deferred("disabled", true)
	for unit in units:
		if unit.slaughter_resource != index: continue
		unit.attack_type = ""
		unit.attack_index = -1
		unit.slaughter_resource = -1
		if unit.kind == "worker":
			unit.resource = index
			unit.worker_state = WORKER_TO_RESOURCE
			unit.flow_key = ""
			unit.flow_target = Vector2.INF
	navigation_fields.clear()
	refresh_navigation_obstacle_index()

func update_buildings(delta: float) -> void:
	for b in buildings:
		if b.hp <= 0: continue
		b.attack_cooldown = maxf(0.0, float(b.get("attack_cooldown", 0.0)) - delta)
		if not b.done:
			b.progress += delta / 4.0
			if b.progress >= 1.0:
				b.done = true
				if b.kind == "house" and b.team == 0: population_cap += stats.house.population
		if b.kind == "tower" and b.done and b.attack_cooldown <= 0.0:
			var target := nearest_enemy_unit(b.block_center, b.team, stats.tower.range)
			if target >= 0:
				units[target].hp -= stats.tower.attack
				b.attack_cooldown = stats.tower.cooldown
				floating.append({"pos":units[target].pos + Vector2(0, -50), "text":str(stats.tower.attack), "color":Color("f2d16b"), "time":0.6})
	for building in buildings:
		if building.kind != "hall" or building.hp > 0: continue
		message = "패배! 본진이 무너졌어요. R 키로 다시 시작" if building.team == 0 else "승리! 적 본진을 무너뜨렸어요. R 키로 다시 시작"
		paused = true

func update_enemy(delta: float) -> void:
	return

func nearest_enemy_unit(from: Vector2, team: int, attack_range: float) -> int:
	var nearest := -1
	var best_distance := attack_range
	for index in units.size():
		var unit: Dictionary = units[index]
		if unit.team == team or unit.hp <= 0: continue
		var distance := from.distance_to(unit.pos)
		if distance <= best_distance:
			best_distance = distance
			nearest = index
	return nearest

func move_unit(unit: Dictionary, destination: Vector2, distance: float) -> void:
	if unit.pos.distance_to(destination) <= maxf(unit.body_radius * 0.5, flow_field.cell_size):
		if unit.get("resume_target", Vector2.INF) != Vector2.INF:
			unit.target = unit.resume_target
			unit.flow_target = unit.resume_flow_target
			unit.resume_target = Vector2.INF
			unit.resume_flow_target = Vector2.INF
			unit.flow_key = ""
			return
		unit.moving = false
		(unit_nodes[units.find(unit)] as CharacterBody2D).velocity = Vector2.ZERO
		return
	if unit.flow_key == "" and float(unit.get("repath_cooldown", 0.0)) > 0.0:
		unit.moving = false
		return
	if unit.flow_key == "" or not navigation_fields.has(unit.flow_key):
		if reroutes_this_frame >= 4:
			unit.moving = false
			return
		reroutes_this_frame += 1
		unit.flow_key = navigation_field_key(destination, [unit.pos])
	var field: FlowFieldManager = navigation_fields.get(unit.flow_key) as FlowFieldManager
	if field == null:
		unit.moving = false
		return
	var direction := field.get_vector(unit.pos)
	if direction == Vector2.ZERO and unit.pos.distance_to(destination) <= flow_field.cell_size:
		# Only use the direct final approach inside the same grid cell. At larger
		# distances it could cut across an authored building blocker.
		direction = (destination - unit.pos).normalized()
	if direction == Vector2.ZERO:
		# A local field can become stale once a carrier or crowd moves outside its
		# source window. Discard it so the next update builds a field from here.
		unit.flow_key = ""
		unit.repath_cooldown = 0.05
		unit.moving = false
		return
	# Local steering only needs nearby units. The spatial hash replaces the
	# previous all-units scan for every mover.
	var separation := Vector2.ZERO
	var unit_index := units.find(unit)
	var bucket := Vector2i(floori(unit.pos.x / UNIT_BUCKET_SIZE), floori(unit.pos.y / UNIT_BUCKET_SIZE))
	for y in range(bucket.y - 1, bucket.y + 2):
		for x in range(bucket.x - 1, bucket.x + 2):
			for other_index in unit_buckets.get(Vector2i(x, y), []):
				if other_index == unit_index: continue
				var other: Dictionary = units[other_index]
				if other.team != unit.team: continue
				var offset: Vector2 = unit.pos - other.pos
				var gap := offset.length()
				var minimum_gap: float = unit.body_radius + other.body_radius
				if gap < minimum_gap:
					var away := offset.normalized() if gap > 0.01 else Vector2.RIGHT.rotated(float(unit_index + other_index))
					separation += away * (1.0 - gap / minimum_gap)
	# Flow-field movement must win in a dense worker pack. Allowing brief visual
	# overlap is preferable to a crowd cancelling its own route and stalling.
	direction = direction.normalized()
	unit.direction = direction
	var next_pos: Vector2 = unit.pos + direction * distance
	var delivering: bool = unit.get("worker_state", WORKER_IDLE) == WORKER_TO_HALL and unit.return_point != Vector2.INF and unit.flow_target.distance_to(unit.return_point) <= 4.0
	if not delivering and movement_blocked(next_pos, unit.body_radius):
		# The field is cell-based while motion is continuous. Never allow the
		# final sub-cell step to cut through an authored building blocker.
		unit.flow_key = ""
		unit.repath_cooldown = 0.20
		unit.moving = false
		return
	unit.pos = next_pos
	(unit_nodes[units.find(unit)] as CharacterBody2D).global_position = unit.pos
	unit.moving = true

func movement_blocked(pos: Vector2, radius: float) -> bool:
	return movement_blocked_except(pos, radius, -1)

func movement_blocked_except(pos: Vector2, radius: float, ignored_building: int) -> bool:
	for building_index in buildings.size():
		if building_index == ignored_building: continue
		var building: Dictionary = buildings[building_index]
		if building.hp <= 0: continue
		if flow_field.shape_contains(building.block_shape, pos, radius): return true
	for resource in resources:
		if resource.amount <= 0 or (resource.kind == "food" and resource.state == "sheep"): continue
		if flow_field.shape_contains(resource.block_shape, pos, radius): return true
	return false


func rebuild_forest_navigation_buckets() -> void:
	forest_navigation_buckets.clear()
	for tree_pos in forest_positions:
		var key := Vector2i(floori(tree_pos.x / FlowFieldManager.BUCKET_SIZE), floori(tree_pos.y / FlowFieldManager.BUCKET_SIZE))
		if not forest_navigation_buckets.has(key): forest_navigation_buckets[key] = []
		forest_navigation_buckets[key].append(tree_pos)

func navigation_circles(bounds := Rect2()) -> Array:
	var shapes: Array = []
	for building in buildings:
		if building.hp > 0: shapes.append(building.block_shape)
	for resource in resources:
		if resource.amount > 0 and not (resource.kind == "food" and resource.state == "sheep"): shapes.append(resource.block_shape)
	if bounds.has_area():
		var minimum := Vector2i(floori(bounds.position.x / FlowFieldManager.BUCKET_SIZE), floori(bounds.position.y / FlowFieldManager.BUCKET_SIZE))
		var maximum := Vector2i(floori(bounds.end.x / FlowFieldManager.BUCKET_SIZE), floori(bounds.end.y / FlowFieldManager.BUCKET_SIZE))
		for y in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				for tree_pos in forest_navigation_buckets.get(Vector2i(x, y), []):
					if not harvested_forest_positions.has(tree_pos): shapes.append({"type":"circle", "center":tree_pos, "radius":15.0})
	return shapes

func navigation_rectangles() -> Array:
	return []

func refresh_navigation_obstacle_index() -> void:
	# Fields build a bounded, command-local obstacle index in navigation_field_key.
	# Keeping a second full-map forest index here only caused activation hitches.
	navigation_obstacle_index.clear()

func navigation_field_key(target: Vector2, origins: Array) -> String:
	# Units headed to the same 24px target cell share one field. This prevents a
	# mass order from rebuilding identical cost/integration/vector fields.
	if navigation_fields.size() > 96:
		navigation_fields.clear()
	var cell := flow_field.world_to_cell(target)
	var source := flow_field.world_to_cell(origins[0]) if not origins.is_empty() else cell
	# Fields can only guide positions inside their local bounds. Include a coarse
	# source bucket so a field built near the hall is never reused by a worker
	# returning from the opposite side of the map.
	var key := "target:%d:%d:source:%d:%d" % [cell.x, cell.y, source.x / 16, source.y / 16]
	if navigation_fields.has(key): return key
	navigation_field_serial += 1
	var field := FlowFieldManager.new()
	field.configure(map_size)
	var field_bounds := Rect2(target, Vector2.ZERO)
	for origin in origins: field_bounds = field_bounds.expand(origin)
	field_bounds = field_bounds.grow(FlowFieldManager.BUCKET_SIZE)
	field.rebuild(target, navigation_circles(field_bounds), navigation_rectangles(), origins, UNIT_RADIUS)
	navigation_fields[key] = field
	return key

func navigation_field_target(key: String) -> Vector2:
	return (navigation_fields[key] as FlowFieldManager).target_world

func set_navigation_target(unit: Dictionary, target: Vector2, flow_goal: Vector2, key: String) -> void:
	unit.target = target
	unit.flow_target = flow_goal
	unit.flow_key = key

func assign_formation(indices: Array[int], center: Vector2) -> void:
	var valid: Array[int] = []
	for index in indices:
		if index >= 0 and index < units.size(): valid.append(index)
	if valid.is_empty(): return
	# A compact grid gives every unit a real destination. Slots scale with the
	# selected formation instead of relying on a large "close enough" radius.
	var columns := ceili(sqrt(float(valid.size())))
	var rows := ceili(float(valid.size()) / columns)
	var widest := 0.0
	for index in valid: widest = maxf(widest, units[index].body_radius * 2.0)
	var spacing := maxf(48.0, widest + 10.0)
	var origins: Array = []
	for index in valid: origins.append(units[index].pos)
	var shared_key := navigation_field_key(center, origins)
	var shared_target := navigation_field_target(shared_key)
	for slot in valid.size():
		var row := slot / columns
		var column := slot % columns
		var slot_target := center + Vector2((column - (columns - 1) * 0.5) * spacing, (row - (rows - 1) * 0.5) * spacing)
		var index := valid[slot]
		units[index].task = ""
		units[index].attack_type = ""
		set_navigation_target(units[index], slot_target if not point_blocked(slot_target, units[index].team) else shared_target, shared_target, shared_key)

func point_blocked(pos: Vector2, team: int) -> bool:
	if pos.x < 35 or pos.y < 35 or pos.x > map_size.x - 35 or pos.y > map_size.y - 35: return true
	for b in buildings:
		if b.hp > 0 and b.block_rect.has_point(pos): return true
	for r in resources:
		if r.amount > 0 and pos.distance_to(r.block_center) < r.block_radius: return true
	return false

func can_place_building(kind: String, pos: Vector2) -> bool:
	var visual := load(ASSET_SCENES[kind]).instantiate() as Node2D
	visual.position = pos
	var block := collision_data(visual, 100.0, "Blocker")
	visual.queue_free()
	var rect: Rect2 = block.rect.grow(8)
	for building in buildings:
		if building.hp > 0 and rect.intersects(building.block_rect.grow(8)): return false
	for resource in resources:
		if resource.amount <= 0: continue
		if rect.intersects(resource.block_rect): return false
		# Reserve the authored GatherRange as usable standing space, rather than
		# allowing a building to leave a resource visible but unreachable.
		if rect.grow(resource.gather_radius + UNIT_RADIUS).has_point(resource.gather_center): return false
	for tree_pos in forest_positions:
		if harvested_forest_positions.has(tree_pos): continue
		# Match tree.tscn's authored Blocker footprint without instantiating a node
		# for every visual forest tree.
		var tree_block := Rect2(tree_pos + Vector2(-15, -5), Vector2(30, 42))
		if rect.intersects(tree_block): return false
	return true

func building_radius(kind: String) -> float:
	return {"hall":145.0, "barracks":115.0, "house":90.0, "archery":110.0, "tower":64.0}.get(kind, 100.0)

func resource_radius(kind: String) -> float:
	return 46.0 if kind == "gold" else 38.0

func attack_position(target: Vector2, attacker: Vector2, range_size: float) -> Vector2:
	return target + (attacker - target).normalized() * range_size

func nearest_building(pos: Vector2, team: int, kind: String) -> int:
	var nearest := -1; var best := INF
	for i in buildings.size():
		if buildings[i].team == team and buildings[i].kind == kind and buildings[i].hp > 0 and pos.distance_to(buildings[i].pos) < best: nearest = i; best = pos.distance_to(buildings[i].pos)
	return nearest

func set_attack(index: int, target_type: String, target_index: int) -> void:
	set_worker_idle(units[index]); units[index].attack_type = target_type; units[index].attack_index = target_index

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H: help_open = true
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_P: paused = not paused
		elif event.keycode == KEY_R and paused: paused = false; reset_game()
		queue_redraw(); return
	if not event is InputEventMouseButton: return
	var mouse: Vector2 = event.position
	if event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom + 0.15, mouse); return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom - 0.15, mouse); return
		if title_open or help_open or paused: return
		if event.button_index == MOUSE_BUTTON_LEFT and mouse.y < VIEW.y:
			dragging = true; drag_start = screen_to_world(mouse)
		if event.button_index == MOUSE_BUTTON_RIGHT and mouse.y < VIEW.y: issue_command(screen_to_world(mouse))
	elif event.button_index == MOUSE_BUTTON_LEFT and dragging:
		select_at(Rect2(drag_start, screen_to_world(mouse) - drag_start).abs()); dragging = false

func action_buttons() -> Array:
	if selected_building >= 0 and selected_building < buildings.size():
		var building_kind: String = buildings[selected_building].kind
		if building_kind == "hall": return ["worker"]
		if building_kind == "barracks": return ["sword"]
		if building_kind == "archery": return ["archer"]
		return []
	if selected_units.size() > 0 and units[selected_units[0]].kind == "worker": return ["barracks", "house", "archery", "tower"]
	# Construction is globally available; selecting a worker is optional.
	return ["barracks", "house", "archery", "tower"]

func perform_action(kind: String) -> void:
	var s: Dictionary = stats[kind]
	var count := units.filter(func(u): return u.team == 0).size()
	if gold < s.gold: tell("금이 부족해요"); return
	if wood < s.wood: tell("나무가 부족해요"); return
	if food < s.get("food", 0): tell("고기가 부족해요"); return
	if kind in ["worker", "sword", "archer"] and count >= population_cap: tell("집을 더 지어야 해요"); return
	if kind in ["barracks", "house", "archery", "tower"]: build_mode = kind; tell("땅에 오른쪽 클릭해서 %s을 놓으세요" % korean_name(kind)); return
	if selected_building < 0: tell("유닛을 만들 건물을 먼저 선택해주세요."); return
	gold -= s.gold; wood -= s.wood; food -= s.get("food", 0)
	var building: Dictionary = buildings[selected_building]
	var spawn: Vector2 = building.pos + Vector2(0, 180)
	add_unit(kind, spawn, building.team)
	$UIInterface.refresh(self)
	tell("%s이(가) 바로 나왔어요.")

func issue_command(pos: Vector2) -> void:
	if build_mode != "":
		var s: Dictionary = stats[build_mode]
		var build_pos := snap_building_to_grid(build_mode, pos)
		if gold >= s.gold and wood >= s.wood and can_place_building(build_mode, build_pos):
			# Construction is immediate: no worker walk/build phase is required.
			gold -= s.gold; wood -= s.wood; add_building(build_mode, build_pos, 0, true)
			eject_units_from_new_building(buildings.back())
			navigation_fields.clear()
			reroute_queue.clear()
			for unit_index in units.size():
				if units[unit_index].pos.distance_to(units[unit_index].target) > flow_field.cell_size:
					units[unit_index].flow_key = ""
					if units[unit_index].get("worker_state", WORKER_IDLE) != WORKER_IDLE: units[unit_index].flow_target = Vector2.INF
					reroute_queue.append(unit_index)
			# Keep existing fields during this frame. Units that actually touch the
			# new StaticBody2D reroute individually in move_unit(), avoiding a
			# large synchronous rebuild for every moving unit.
			build_mode = ""; command_ping = {"pos":pos, "type":"build", "time":0.6}; tell("건물이 바로 완성됐어요")
		else:
			tell("건물, 나무, 금광과 겹치지 않는 곳에 설치하세요.")
		return
	for i in selected_units:
		if i >= units.size(): continue
		var enemy := hit_unit(pos, 1)
		var enemy_building := hit_building(pos, 1)
		var sheep := hit_sheep(pos)
		var resource := hit_resource(pos)
		if enemy >= 0:
			cancel_pending_move()
			set_attack(i, "unit", enemy); command_ping = {"pos":pos, "type":"attack", "time":0.6}
		elif enemy_building >= 0:
			cancel_pending_move()
			set_attack(i, "building", enemy_building); command_ping = {"pos":pos, "type":"attack", "time":0.6}
		elif sheep >= 0:
			cancel_pending_move()
			set_worker_idle(units[i])
			units[i].slaughter_resource = sheep
			units[i].attack_type = "sheep"
			units[i].attack_index = sheep
			units[i].flow_key = ""
			units[i].flow_target = Vector2.INF
			tell("양을 도축합니다")
		elif resource >= 0 and units[i].kind == "worker":
			cancel_pending_move()
			units[i].attack_type = ""
			units[i].attack_index = -1
			units[i].slaughter_resource = -1
			if units[i].carry > 0:
				# Never abandon a carried load. Deposit first, then follow the new order.
				units[i].queued_resource = resource
				units[i].worker_state = WORKER_TO_HALL
				units[i].return_point = Vector2.INF
				units[i].flow_key = ""
				tell("들고 있는 자원을 먼저 반납한 뒤 새 자원으로 갈게요.")
			else:
				units[i].resource = resource
				units[i].queued_resource = -1
				units[i].worker_state = WORKER_TO_RESOURCE
				units[i].flow_key = ""
				units[i].flow_target = Vector2.INF
				tell("자원을 캐기 시작했어요")
			command_ping = {"pos":pos, "type":"gather", "time":0.6}
		else:
			set_worker_idle(units[i])
			units[i].attack_type = ""
			units[i].attack_index = -1
			units[i].slaughter_resource = -1
			units[i].flow_target = Vector2.INF
			command_ping = {"pos":pos, "type":"move", "time":0.6}
	if not selected_units.is_empty() and hit_unit(pos, 1) < 0 and hit_building(pos, 1) < 0 and hit_sheep(pos) < 0 and hit_resource(pos) < 0:
		assign_formation(selected_units, pos)

func cancel_pending_move() -> void:
	return

func eject_units_from_new_building(building: Dictionary) -> void:
	for i in units.size():
		var unit: Dictionary = units[i]
		if not building.block_rect.has_point(unit.pos): continue
		var offset: Vector2 = unit.pos - building.block_center
		if offset.length() < 1.0: offset = Vector2.DOWN
		var escape: Vector2 = building.block_center + offset.normalized() * (building.radius + unit.body_radius + 12.0)
		unit.pos = escape
		(unit_nodes[i] as CharacterBody2D).global_position = escape
		unit.flow_key = ""

func select_at(area: Rect2) -> void:
	selected_units.clear(); selected_building = -1; selected_resource = -1
	for i in units.size(): if units[i].team == 0 and (area.size.length() < 10 and units[i].pos.distance_to(area.position) < 55 or area.grow(4).has_point(units[i].pos)): selected_units.append(i)
	if selected_units.is_empty() and area.size.length() < 10:
		var building := hit_building(area.position, 0)
		if building >= 0: selected_building = building
		else:
			var sheep := hit_sheep(area.position)
			if sheep >= 0: selected_resource = sheep
	if selected_units.size() > 0:
		if units[selected_units[0]].kind == "worker": tell("금광이나 나무에 오른쪽 클릭해서 자원을 캐세요.")
		else: tell("적을 오른쪽 클릭하면 공격합니다.")
	elif selected_building >= 0:
		$UIInterface.refresh(self)
		tell("아래 생산 버튼을 눌러 유닛을 만드세요.")
	elif selected_resource >= 0:
		tell("양입니다. 일꾼이나 전투 유닛을 선택한 뒤 오른쪽 클릭해서 도축하세요.")
	queue_redraw()

func hit_unit(pos: Vector2, team: int) -> int:
	for i in units.size(): if units[i].team == team and units[i].hp > 0 and units[i].pos.distance_to(pos) < 70: return i
	return -1

func hit_building(pos: Vector2, team: int) -> int:
	for i in buildings.size(): if buildings[i].team == team and buildings[i].hp > 0 and buildings[i].pos.distance_to(pos) < 150: return i
	return -1

func hit_resource(pos: Vector2) -> int:
	for resource in resources:
		# A visible stump consumes its own click. Do not silently redirect the
		# worker to a different live tree hidden nearby in a dense forest.
		if resource.stump and resource.pos.distance_to(pos) < 100: return -1
	for i in resources.size():
		if resources[i].kind == "food" and resources[i].state == "sheep": continue
		if resources[i].amount > 0 and resources[i].pos.distance_to(pos) < 100: return i
	for tree_pos in harvested_forest_positions:
		if tree_pos.distance_to(pos) < 100: return -1
	var forest_tree := nearest_forest_tree(pos, 120.0)
	if forest_tree != Vector2.INF:
		add_resource("wood", forest_tree, 100, true, true)
		activated_forest_positions[forest_tree] = true
		refresh_navigation_obstacle_index()
		return resources.size() - 1
	return -1

func hit_sheep(pos: Vector2) -> int:
	for i in resources.size():
		if resources[i].kind == "food" and resources[i].state == "sheep" and resources[i].pos.distance_to(pos) < 100: return i
	return -1

func nearest_forest_tree(pos: Vector2, radius: float) -> Vector2:
	var best := Vector2.INF
	var best_distance := radius
	for tree_pos in forest_positions:
		if harvested_forest_positions.has(tree_pos): continue
		var distance := tree_pos.distance_to(pos)
		if distance < best_distance:
			best_distance = distance
			best = tree_pos
	return best

func tell(text: String) -> void:
	message = text
	$UIInterface.refresh(self)

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / 64.0) * 64.0, round(pos.y / 64.0) * 64.0)

func snap_building_to_grid(kind: String, world_pos: Vector2) -> Vector2:
	# Align the visible Sprite2D bottom, not the collision shape. Different
	# building images can have different collision footprints but must share a
	# visual ground line when the player places them side by side.
	var visual := load(ASSET_SCENES[kind]).instantiate() as Node2D
	var bottom_offset := building_visual_bottom_offset(visual)
	visual.queue_free()
	var snapped_bottom: float = round((world_pos.y + bottom_offset) / 64.0) * 64.0
	var snapped_x: float = round(world_pos.x / 64.0) * 64.0
	return Vector2(snapped_x, snapped_bottom - bottom_offset)

func building_visual_bottom_offset(visual: Node2D) -> float:
	var sprite := visual.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null: return 0.0
	var image_height: float = sprite.region_rect.size.y if sprite.region_enabled else float(sprite.texture.get_height())
	var scale_y := absf(sprite.scale.y)
	var bottom := sprite.position.y + sprite.offset.y
	if sprite.centered: bottom += image_height * scale_y * 0.5
	else: bottom += image_height * scale_y
	return bottom

func korean_name(kind: String) -> String:
	return {"worker":"일꾼", "sword":"검사", "archer":"궁수", "hall":"본진", "barracks":"병영", "house":"집", "archery":"궁술 훈련소", "tower":"탑"}.get(kind, kind)

func _draw() -> void:
	# Camera2D owns world-to-screen conversion. Applying camera_pos here as well
	# moved the terrain twice and made the background disappear.
	draw_world()
	if build_mode != "": draw_build_preview()
	if dragging:
		draw_rect(Rect2(drag_start, screen_to_world(get_viewport().get_mouse_position()) - drag_start).abs(), Color("8eea83aa"), true)
		draw_rect(Rect2(drag_start, screen_to_world(get_viewport().get_mouse_position()) - drag_start).abs(), Color("d9a63a"), false, 2)

func draw_world() -> void:
	var visible := Rect2(camera_pos - Vector2(128, 128), visible_size() + Vector2(256, 256))
	var tileset := SpriteLibrary.texture(SpriteLibrary.terrain_path("Tilemap_color1.png"))
	var first_x := int(floor(visible.position.x / 64.0)) * 64
	var first_y := int(floor(visible.position.y / 64.0)) * 64
	for x in range(first_x, int(visible.end.x) + 64, 64):
		for y in range(first_y, int(visible.end.y) + 64, 64):
			draw_texture_rect_region(tileset, Rect2(x, y, 64, 64), Rect2(64, 64, 64, 64))
	if command_ping.time > 0: draw_arc(command_ping.pos, 28 * command_ping.time / 0.6, 0, TAU, 20, {"move":Color("71d875"), "attack":ENEMY, "gather":GOLD, "build":ALLY}[command_ping.type], 3)
	for f in floating: draw_string(ThemeDB.fallback_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, f.color)

	for index in selected_units:
		if index < 0 or index >= units.size(): continue
		var unit: Dictionary = units[index]
		draw_arc(unit.pos, unit.body_radius + 8.0, 0.0, TAU, 20, GOLD, 2.0)
		draw_string(ThemeDB.fallback_font, unit.pos + Vector2(-42, -46), korean_name(unit.kind), HORIZONTAL_ALIGNMENT_CENTER, 84, 15, Color.WHITE)
	if selected_resource >= 0 and selected_resource < resources.size():
		var resource: Dictionary = resources[selected_resource]
		draw_arc(resource.pos, resource.block_radius + 8.0, 0.0, TAU, 20, GOLD, 2.0)
	if selected_building >= 0 and selected_building < buildings.size():
		var building: Dictionary = buildings[selected_building]
		var rect: Rect2 = building.block_rect.grow(8)
		var arm := 20.0
		draw_line(rect.position, rect.position + Vector2(arm, 0), GOLD, 3)
		draw_line(rect.position, rect.position + Vector2(0, arm), GOLD, 3)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - arm, rect.position.y), GOLD, 3)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + arm), GOLD, 3)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + arm, rect.end.y), GOLD, 3)
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - arm), GOLD, 3)
		draw_line(rect.end, rect.end - Vector2(arm, 0), GOLD, 3)
		draw_line(rect.end, rect.end - Vector2(0, arm), GOLD, 3)
		draw_string(ThemeDB.fallback_font, building.pos + Vector2(-65, -building.radius - 25), korean_name(building.kind), HORIZONTAL_ALIGNMENT_CENTER, 130, 16, Color.WHITE)

func draw_hp_bar(pos: Vector2, hp: float, maximum: float, color: Color) -> void:
	# BigBar_Base: 320×64, 9-slice: 좌(64px) / 중(192px) / 우(64px)
	# 화면에 128×16으로 출력: 좌끝(32×16) + 중간(늘림) + 우끝(32×16)
	var bw := 128.0; var bh := 16.0
	var base := sl_tex(SpriteLibrary.big_bar_base_path())  # 320×64
	var corner := 64.0; var out_c := 32.0  # 원본 모서리px / 화면 모서리px
	draw_texture_rect_region(base, Rect2(pos, Vector2(out_c, bh)), Rect2(0, 0, corner, 64))
	draw_texture_rect_region(base, Rect2(pos + Vector2(out_c, 0), Vector2(bw - out_c*2, bh)), Rect2(corner, 0, 192, 64))
	draw_texture_rect_region(base, Rect2(pos + Vector2(bw - out_c, 0), Vector2(out_c, bh)), Rect2(256, 0, corner, 64))
	# fill
	var fill_ratio := clampf(hp / maximum, 0.0, 1.0)
	if fill_ratio > 0.0:
		var fill_tex := sl_tex(SpriteLibrary.big_bar_fill_path())  # 64×64 단색
		var fill_x := pos.x + 6.0; var fill_w := (bw - 12.0) * fill_ratio
		var fill_h := bh - 6.0
		var hp_color := color.lerp(ENEMY, 0.0)
		if fill_ratio < 0.5: hp_color = GOLD
		if fill_ratio < 0.25: hp_color = ENEMY
		draw_texture_rect(fill_tex, Rect2(Vector2(fill_x, pos.y + 3.0), Vector2(fill_w, fill_h)), false, hp_color)

# 9-slice 조립: tex(원본)를 dest에 그리되, 모서리 s×s 픽셀을 고정하고 가운데만 늘림
func draw_9slice(tex: Texture2D, dest: Rect2, s: int) -> void:
	var tw := tex.get_width(); var th := tex.get_height()
	var mid_src_w := tw - s * 2; var mid_src_h := th - s * 2
	var mid_dst_w := dest.size.x - s * 2; var mid_dst_h := dest.size.y - s * 2
	var dx := dest.position.x; var dy := dest.position.y
	# 모서리 4개
	draw_texture_rect_region(tex, Rect2(dx, dy, s, s), Rect2(0, 0, s, s))
	draw_texture_rect_region(tex, Rect2(dx + dest.size.x - s, dy, s, s), Rect2(tw - s, 0, s, s))
	draw_texture_rect_region(tex, Rect2(dx, dy + dest.size.y - s, s, s), Rect2(0, th - s, s, s))
	draw_texture_rect_region(tex, Rect2(dx + dest.size.x - s, dy + dest.size.y - s, s, s), Rect2(tw - s, th - s, s, s))
	# 4개 변
	if mid_dst_w > 0:
		draw_texture_rect_region(tex, Rect2(dx + s, dy, mid_dst_w, s), Rect2(s, 0, mid_src_w, s))
		draw_texture_rect_region(tex, Rect2(dx + s, dy + dest.size.y - s, mid_dst_w, s), Rect2(s, th - s, mid_src_w, s))
	if mid_dst_h > 0:
		draw_texture_rect_region(tex, Rect2(dx, dy + s, s, mid_dst_h), Rect2(0, s, s, mid_src_h))
		draw_texture_rect_region(tex, Rect2(dx + dest.size.x - s, dy + s, s, mid_dst_h), Rect2(tw - s, s, s, mid_src_h))
	# 가운데
	if mid_dst_w > 0 and mid_dst_h > 0:
		draw_texture_rect_region(tex, Rect2(dx + s, dy + s, mid_dst_w, mid_dst_h), Rect2(s, s, mid_src_w, mid_src_h))

# SmallRibbons(320×640): 10행×3열. 행높이=64px, 열폭: 좌=96 / 중=128 / 우=96
# row: 0~9 (0=파랑 깃발), 출력 크기를 지정하면 중간만 늘림
func draw_ribbon(pos: Vector2, width: float, row: int) -> void:
	var tex := sl_tex(SpriteLibrary.small_ribbons_path())
	var ry := row * 64; var lw := 96.0; var mw := 128.0; var rw := 96.0
	# 좌 깃발 (96×64) → 32×22로 축소
	var scale := 0.34  # 64px 행 → 22px
	var dh := 64.0 * scale  # ≈22
	var dl := lw * scale; var dr := rw * scale; var dm := width - dl - dr
	draw_texture_rect_region(tex, Rect2(pos, Vector2(dl, dh)), Rect2(0, ry, lw, 64))
	draw_texture_rect_region(tex, Rect2(pos + Vector2(dl, 0), Vector2(dm, dh)), Rect2(lw, ry, mw, 64))
	draw_texture_rect_region(tex, Rect2(pos + Vector2(dl + dm, 0), Vector2(dr, dh)), Rect2(lw + mw, ry, rw, 64))

func draw_hud() -> void:
	# ── 좌측 상단 자원 패널: RegularPaper 9-slice (s=32) → 160×110 ──
	var paper := sl_tex(SpriteLibrary.regular_paper_path())  # 320×320, s=106
	draw_9slice(paper, Rect2(6, 4, 160, 116), 106)
	# 아이콘(64×64) → 22×22
	draw_texture_rect(sl_tex(SpriteLibrary.icon_path(1)), Rect2(14, 14, 22, 22), false)
	draw_string(ThemeDB.fallback_font, Vector2(40, 32), "%d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, EDGE)
	draw_texture_rect(sl_tex(SpriteLibrary.icon_path(2)), Rect2(14, 44, 22, 22), false)
	draw_string(ThemeDB.fallback_font, Vector2(40, 62), "%d" % wood, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, EDGE)
	draw_texture_rect(sl_tex(SpriteLibrary.icon_path(5)), Rect2(14, 74, 22, 22), false)
	draw_string(ThemeDB.fallback_font, Vector2(40, 92), "%d/%d" % [units.filter(func(u): return u.team == 0).size(), population_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, EDGE)

	# ── 메시지 배너: Banner_Slots(192×192) 배경 타일 + 리본 장식 ──
	# Banner_Slots를 배경으로 9-slice (s=32): 340×52
	var slots := sl_tex(SpriteLibrary.banner_slots_path())
	draw_9slice(slots, Rect2(172, 4, 340, 52), 32)
	if message != "":
		draw_string(ThemeDB.fallback_font, Vector2(342, 35), message, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, EDGE)

	# The visible selection workbench is UIInterface/SelectionTable (ui_wood_table.tscn).
	# Text is drawn here, but the WoodTable art itself is not duplicated in code.
	# 리본 타이틀
	draw_ribbon(Vector2(8, 480), 212, 0)
	# 선택 대상 정보
	var sel_name := "선택 없음"
	var sel_detail := "유닛이나 건물 클릭"
	var hp_ratio := -1.0
	var avatar_n := 1
	if selected_units.size() == 1:
		var u: Dictionary = units[selected_units[0]]
		sel_name = korean_name(u.kind) + "  %d/%d" % [u.hp, u.max_hp]
		sel_detail = "공격 %d  사거리 %d" % [stats[u.kind].attack, stats[u.kind].range]
		hp_ratio = float(u.hp) / float(u.max_hp)
		avatar_n = ({"worker":3, "sword":1, "archer":2} as Dictionary)[u.kind]
	elif selected_units.size() > 1:
		sel_name = "%d명 선택" % selected_units.size()
		sel_detail = "우클릭: 이동/공격"
		avatar_n = 4
	elif selected_building >= 0:
		var b: Dictionary = buildings[selected_building]
		sel_name = korean_name(b.kind) + "  %d/%d" % [b.hp, b.max_hp]
		sel_detail = "생산 버튼을 누르면 유닛이 바로 나옵니다."
		hp_ratio = float(b.hp) / float(b.max_hp)
		avatar_n = ({"hall":7, "barracks":8, "house":9} as Dictionary)[b.kind]
	# 아바타(256×256) → 48×48
	draw_texture_rect(sl_tex(SpriteLibrary.avatar_path(avatar_n)), Rect2(14, 503, 48, 48), false)
	draw_string(ThemeDB.fallback_font, Vector2(68, 520), sel_name, HORIZONTAL_ALIGNMENT_LEFT, 148, 14, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(68, 538), sel_detail, HORIZONTAL_ALIGNMENT_LEFT, 148, 12, PAPER)
	# HP 바
	if hp_ratio >= 0.0:
		draw_hp_bar(Vector2(14, 556), hp_ratio * 100.0, 100.0, ALLY)

	# The visible command workbench is UIInterface/CommandTable (ui_wood_table.tscn).
	# 리본 타이틀
	draw_ribbon(Vector2(1044, 480), 228, 1)
	draw_string(ThemeDB.fallback_font, Vector2(1158, 493), "명 령", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, PAPER)
	var btns := action_buttons()
	for i in btns.size():
		var col := i % 2; var row := i / 2
		draw_action_button(Rect2(1052 + col * 110, 506 + row * 84, 100, 76), btns[i])

	# ── 빌드 모드 힌트: Banner_Slots 9-slice ──
	if build_mode != "":
		draw_9slice(slots, Rect2(340, 686, 600, 30), 32)
		draw_string(ThemeDB.fallback_font, Vector2(640, 707), "우클릭: %s 놓기  /  ESC: 취소" % korean_name(build_mode), HORIZONTAL_ALIGNMENT_CENTER, 580, 14, GOLD)

func draw_action_button(rect: Rect2, kind: String) -> void:
	var s: Dictionary = stats[kind]
	var enabled: bool = gold >= s.gold and wood >= s.wood
	if kind in ["worker", "sword", "archer"]: enabled = enabled and units.filter(func(u): return u.team == 0).size() < population_cap
	# SmallRedSquareButton or SmallBlueSquareButton: 128×128, s=22 → 9-slice
	var btn := sl_tex(SpriteLibrary.small_square_button_path("Red" if enabled else "Blue"))
	draw_9slice(btn, rect, 22)
	# 아이콘(64×64) → 36×36, 버튼 중앙 상단
	var icon_n: int = ({"worker":3, "sword":1, "archer":2, "barracks":5, "house":6} as Dictionary)[kind]
	var icon_x := rect.position.x + (rect.size.x - 36) / 2.0
	draw_texture_rect(sl_tex(SpriteLibrary.icon_path(icon_n)), Rect2(Vector2(icon_x, rect.position.y + 6), Vector2(36, 36)), false)
	# 이름
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + 50), korean_name(kind), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, PAPER)
	# 비용
	draw_texture_rect(sl_tex(SpriteLibrary.icon_path(1)), Rect2(rect.position.x + 8, rect.position.y + 58, 10, 10), false)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 20, rect.position.y + 68), "%d" % s.gold, HORIZONTAL_ALIGNMENT_LEFT, 40, 10, GOLD)

func draw_minimap() -> void:
	# 미니맵: RegularPaper 9-slice → 220×70, 화면 맨 아래 좌측
	var paper := sl_tex(SpriteLibrary.regular_paper_path())
	draw_9slice(paper, Rect2(4, 672, 220, 46), 106)
	var mmap := Rect2(10, 674, 208, 42)
	draw_rect(mmap, Color("2e4520"))
	var sx := mmap.size.x / map_size.x; var sy := mmap.size.y / map_size.y
	for r in resources:
		if r.amount > 0: draw_circle(mmap.position + r.pos * Vector2(sx, sy), 1.5, GOLD)
	for u in units:
		draw_circle(mmap.position + u.pos * Vector2(sx, sy), 1.5, ALLY if u.team == 0 else ENEMY)
	draw_rect(Rect2(mmap.position + camera_pos * Vector2(sx, sy), visible_size() * Vector2(sx, sy)), Color.WHITE, false, 1)

func draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
	# The title content has no paper background asset mixed into it.
	draw_rect(Rect2(460, 120, 360, 320), Color("3d2c22"))
	# 타이틀 리본: BigRibbons 1행(파랑) = 448×128
	# 좌깃발(128×128) / 중(192×128) / 우깃발(128×128) → 폭 320으로 조립
	var brib := sl_tex(SpriteLibrary.big_ribbons_path())
	var rw := 320.0; var rh := 46.0; var rx := 460.0 + (360.0 - rw) / 2.0; var ry2 := 130.0
	draw_texture_rect_region(brib, Rect2(rx, ry2, 80, rh), Rect2(0, 0, 128, 128))
	draw_texture_rect_region(brib, Rect2(rx + 80, ry2, rw - 160, rh), Rect2(128, 0, 192, 128))
	draw_texture_rect_region(brib, Rect2(rx + rw - 80, ry2, 80, rh), Rect2(320, 0, 128, 128))
	draw_string(ThemeDB.fallback_font, Vector2(640, 167), "TINY SWORDS RTS", HORIZONTAL_ALIGNMENT_CENTER, 320, 24, PAPER)
	# 시작 버튼: SmallRedSquareButton 9-slice → 160×56
	var btn := sl_tex(SpriteLibrary.small_square_button_path("Red"))
	draw_9slice(btn, Rect2(560, 296, 160, 56), 22)
	draw_string(ThemeDB.fallback_font, Vector2(640, 330), "시  작", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(640, 390), "클릭하면 조작법이 열립니다", HORIZONTAL_ALIGNMENT_CENTER, 360, 13, PAPER)

func draw_help() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
	# The help content has no paper background asset mixed into it.
	draw_rect(Rect2(290, 110, 700, 460), Color("3d2c22"))
	# 타이틀 리본: BigRibbons 3행(황금) = y=256..383
	var brib := sl_tex(SpriteLibrary.big_ribbons_path())
	var rw := 520.0; var rh := 46.0; var rx := 640.0 - rw/2.0; var ry2 := 122.0
	draw_texture_rect_region(brib, Rect2(rx, ry2, 80, rh), Rect2(0, 256, 128, 128))
	draw_texture_rect_region(brib, Rect2(rx + 80, ry2, rw - 160, rh), Rect2(128, 256, 192, 128))
	draw_texture_rect_region(brib, Rect2(rx + rw - 80, ry2, 80, rh), Rect2(320, 256, 128, 128))
	draw_string(ThemeDB.fallback_font, Vector2(640, 156), "조  작  법", HORIZONTAL_ALIGNMENT_CENTER, 520, 22, PAPER)
	var lines := ["왼쪽 클릭: 유닛/건물 선택  /  드래그: 다중 선택", "오른쪽 클릭: 이동  /  금광·나무 채집  /  적 공격", "방향키·WASD: 카메라 이동  /  마우스 휠: 줌", "일꾼 선택 후 명령창: 병영·집 건설", "건물 선택 후 명령창: 유닛 생산", "H: 조작법  /  ESC·P: 일시정지  /  R: 재시작"]
	for i in lines.size():
		draw_string(ThemeDB.fallback_font, Vector2(640, 214 + i * 46), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 620, 17, EDGE)
	# 확인 버튼: SmallRedSquareButton 9-slice → 160×48
	var btn := sl_tex(SpriteLibrary.small_square_button_path("Red"))
	draw_9slice(btn, Rect2(560, 516, 160, 48), 22)
	draw_string(ThemeDB.fallback_font, Vector2(640, 547), "알겠어요", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, PAPER)

func draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
	# 창: RegularPaper 9-slice → 420×210
	var rp := sl_tex(SpriteLibrary.regular_paper_path())
	draw_9slice(rp, Rect2(430, 220, 420, 210), 106)
	# 리본: BigRibbons 2행(빨강) y=128..255
	var brib := sl_tex(SpriteLibrary.big_ribbons_path())
	var rw := 300.0; var rh := 40.0; var rx := 640.0 - rw/2.0; var ry2 := 230.0
	draw_texture_rect_region(brib, Rect2(rx, ry2, 60, rh), Rect2(0, 128, 128, 128))
	draw_texture_rect_region(brib, Rect2(rx + 60, ry2, rw - 120, rh), Rect2(128, 128, 192, 128))
	draw_texture_rect_region(brib, Rect2(rx + rw - 60, ry2, 60, rh), Rect2(320, 128, 128, 128))
	draw_string(ThemeDB.fallback_font, Vector2(640, 258), "일시정지", HORIZONTAL_ALIGNMENT_CENTER, 420, 22, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(640, 310), message, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, ENEMY)
	draw_string(ThemeDB.fallback_font, Vector2(640, 358), "클릭: 계속  /  R: 다시 시작", HORIZONTAL_ALIGNMENT_CENTER, 420, 15, EDGE)

func draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(rect, fill); draw_rect(rect, border, false, 3)

func ui_texture(relative: String) -> Texture2D:
	return SpriteLibrary.texture(SpriteLibrary.ui_path(relative))

func direction_to_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 2 if direction.x > 0 else 3
	return 0 if direction.y > 0 else 1

func visible_size() -> Vector2:
	return VIEW / zoom

func screen_to_world(screen_pos: Vector2) -> Vector2:
	# Use Camera2D's real canvas transform. Manual camera_pos/zoom arithmetic
	# drifted from the rendered camera after zoom/reset and offset click targets.
	return get_canvas_transform().affine_inverse() * screen_pos

func set_zoom(next: float, screen_pos: Vector2) -> void:
	var old_world := screen_to_world(screen_pos)
	zoom = clampf(next, 0.25, 3.0)
	sync_camera()
	var shifted_world := screen_to_world(screen_pos)
	camera_pos += old_world - shifted_world
	clamp_camera()
	sync_camera()

func sync_camera() -> void:
	$Camera2D.position = camera_pos + visible_size() * 0.5
	$Camera2D.zoom = Vector2.ONE * zoom

func clamp_camera() -> void:
	var visible := visible_size()
	camera_pos.x = clampf(camera_pos.x, 0.0, map_size.x - visible.x)
	camera_pos.y = clampf(camera_pos.y, 0.0, map_size.y - visible.y)

func draw_build_preview() -> void:
	var pos := snap_building_to_grid(build_mode, screen_to_world(get_viewport().get_mouse_position()))
	var texture := SpriteLibrary.texture(SpriteLibrary.path_for_building(build_mode, 0))
	var size := texture.get_size()
	var stats_data: Dictionary = stats[build_mode]
	var valid: bool = gold >= stats_data.gold and wood >= stats_data.wood and can_place_building(build_mode, pos)
	var color := Color(0.35, 1.0, 0.45, 0.60) if valid else Color(1.0, 0.25, 0.25, 0.60)
	draw_texture_rect(texture, Rect2(pos - size / 2, size), false, color)
	draw_rect(Rect2(pos - size / 2, size), Color("71d875") if valid else ENEMY, false, 3)
	var preview_node := load(ASSET_SCENES[build_mode]).instantiate() as Node2D
	var preview_bottom := building_visual_bottom_offset(preview_node)
	preview_node.queue_free()
	var grid_y: float = pos.y + preview_bottom
	draw_line(Vector2(pos.x - 96, grid_y), Vector2(pos.x + 96, grid_y), Color("71d875") if valid else ENEMY, 1)
	draw_string(ThemeDB.fallback_font, pos + Vector2(-80, -size.y * 0.5 - 16), "오른쪽 클릭: 건설  /  ESC: 취소", HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color.WHITE)
