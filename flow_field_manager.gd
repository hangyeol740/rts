class_name FlowFieldManager
extends RefCounted

# One shared navigation solution: Cost Field -> Integration Field -> Vector Field.
const BLOCKED := 1_000_000_000
const OFFSETS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const BUCKET_SIZE := 256.0

var cell_size := 24.0
var map_size := Vector2.ZERO
var grid_size := Vector2i.ZERO
var cost_field := PackedInt32Array()
var integration_field := PackedInt32Array()
var vector_field := PackedVector2Array()
var target_cell := Vector2i(-1, -1)
var target_world := Vector2.ZERO
var field_origin := Vector2i.ZERO
var field_size := Vector2i.ZERO
var obstacle_buckets: Dictionary = {}

func configure(size: Vector2) -> void:
	map_size = size
	grid_size = Vector2i(ceili(size.x / cell_size), ceili(size.y / cell_size))

func set_obstacle_index(value: Dictionary) -> void:
	obstacle_buckets = value

static func build_obstacle_index(circles: Array, rectangles: Array) -> Dictionary:
	var buckets: Dictionary = {}
	for shape in circles:
		var extent := obstacle_extent(shape)
		add_to_buckets(buckets, shape, shape.center - Vector2(extent, extent), shape.center + Vector2(extent, extent))
	for rect in rectangles:
		add_to_buckets(buckets, {"type":"rect", "rect":rect}, rect.position, rect.end)
	return buckets

static func obstacle_extent(shape: Dictionary) -> float:
	if shape.type == "circle": return shape.radius
	if shape.type == "capsule": return shape.height * 0.5
	if shape.type == "rectangle": return maxf(shape.size.x, shape.size.y) * 0.5
	return 0.0

static func add_to_buckets(buckets: Dictionary, obstacle: Dictionary, from: Vector2, to: Vector2) -> void:
	var minimum := Vector2i(floori(from.x / BUCKET_SIZE), floori(from.y / BUCKET_SIZE))
	var maximum := Vector2i(floori(to.x / BUCKET_SIZE), floori(to.y / BUCKET_SIZE))
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var key := Vector2i(x, y)
			if not buckets.has(key): buckets[key] = []
			buckets[key].append(obstacle)

func rebuild(target_world: Vector2, circles: Array, rectangles: Array, origins: Array = [], agent_radius := 0.0) -> Vector2:
	# Include target and command origins. Target-only windows returned zero vectors
	# whenever a unit stood outside the local field.
	self.target_world = target_world
	var raw_target := world_to_cell(target_world)
	var min_cell := raw_target
	var max_cell := raw_target
	for world_position in origins:
		var cell := world_to_cell(world_position)
		min_cell.x = mini(min_cell.x, cell.x); min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x); max_cell.y = maxi(max_cell.y, cell.y)
	var margin := 12
	field_origin = Vector2i(maxi(0, min_cell.x - margin), maxi(0, min_cell.y - margin))
	field_size = Vector2i(mini(grid_size.x - field_origin.x, max_cell.x - field_origin.x + margin + 1), mini(grid_size.y - field_origin.y, max_cell.y - field_origin.y + margin + 1))
	if obstacle_buckets.is_empty(): obstacle_buckets = build_obstacle_index(circles, rectangles)
	_build_cost_field(agent_radius)
	target_cell = _nearest_open_cell(raw_target - field_origin)
	_build_integration_field()
	_build_vector_field()
	self.target_world = cell_to_world(target_cell + field_origin)
	return self.target_world

func get_vector(world_position: Vector2) -> Vector2:
	var cell := world_to_cell(world_position)
	cell -= field_origin
	if not in_bounds(cell): return Vector2.ZERO
	var direction := vector_field[index(cell)]
	if direction != Vector2.ZERO: return direction
	# A unit can start physically outside a StaticBody2D yet occupy a Cost Field
	# cell blocked by its own body-radius clearance. Give that unit an escape
	# vector to the nearest reachable Integration Field cell instead of freezing.
	if integration_field[index(cell)] == BLOCKED:
		var escape := nearest_reachable_cell(cell)
		if escape != cell:
			var escape_world := cell_to_world(escape + field_origin)
			return (escape_world - world_position).normalized()
	return Vector2.ZERO

func nearest_reachable_cell(origin: Vector2i) -> Vector2i:
	for radius in range(1, 12):
		var best := origin
		var best_distance := INF
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius: continue
				var cell := origin + Vector2i(x, y)
				if not in_bounds(cell) or integration_field[index(cell)] == BLOCKED: continue
				var distance := cell.distance_squared_to(origin)
				if distance < best_distance: best_distance = distance; best = cell
		if best != origin: return best
	return origin

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(world_position.x / cell_size), 0, grid_size.x - 1), clampi(floori(world_position.y / cell_size), 0, grid_size.y - 1))

func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < field_size.x and cell.y < field_size.y

func index(cell: Vector2i) -> int:
	return cell.y * field_size.x + cell.x

func _build_cost_field(agent_radius: float) -> void:
	var count := field_size.x * field_size.y
	cost_field.resize(count)
	for y in field_size.y:
		for x in field_size.x:
			var cell := Vector2i(x, y)
			var pos := cell_to_world(cell + field_origin)
			var blocked := false
			var bucket_key := Vector2i(floori(pos.x / BUCKET_SIZE), floori(pos.y / BUCKET_SIZE))
			for obstacle in obstacle_buckets.get(bucket_key, []):
				if obstacle.type == "rect":
					if obstacle.rect.grow(agent_radius).has_point(pos): blocked = true; break
				elif shape_contains(obstacle, pos, agent_radius):
					blocked = true
					break
			cost_field[index(cell)] = BLOCKED if blocked else 1

func shape_contains(shape: Dictionary, point: Vector2, agent_radius: float) -> bool:
	var local: Vector2 = point - shape.center
	if shape.type == "circle": return local.length() < shape.radius + agent_radius
	if shape.type == "rectangle":
		local = local.rotated(-shape.rotation)
		return absf(local.x) < shape.size.x * 0.5 + agent_radius and absf(local.y) < shape.size.y * 0.5 + agent_radius
	if shape.type == "capsule":
		local = local.rotated(-shape.rotation)
		var radius: float = shape.radius + agent_radius
		var half_line := maxf(0.0, shape.height * 0.5 - shape.radius)
		var closest := Vector2(0, clampf(local.y, -half_line, half_line))
		return local.distance_to(closest) < radius
	return false

func _build_integration_field() -> void:
	var count := field_size.x * field_size.y
	integration_field.resize(count)
	for i in count: integration_field[i] = BLOCKED
	integration_field[index(target_cell)] = 0
	var queue: Array[Vector2i] = [target_cell]
	var read := 0
	# Dijkstra/BFS from the target creates minimum cumulative cost for every reachable cell.
	while read < queue.size():
		var current: Vector2i = queue[read]
		read += 1
		var current_cost := integration_field[index(current)]
		for offset in OFFSETS:
			var neighbor: Vector2i = current + offset
			if not in_bounds(neighbor) or cost_field[index(neighbor)] == BLOCKED: continue
			if offset.x != 0 and offset.y != 0:
				if cost_field[index(current + Vector2i(offset.x, 0))] == BLOCKED or cost_field[index(current + Vector2i(0, offset.y))] == BLOCKED: continue
			var next_cost := current_cost + cost_field[index(neighbor)]
			if next_cost < integration_field[index(neighbor)]:
				integration_field[index(neighbor)] = next_cost
				queue.append(neighbor)

func _build_vector_field() -> void:
	vector_field.resize(field_size.x * field_size.y)
	for y in field_size.y:
		for x in field_size.x:
			var cell := Vector2i(x, y)
			var cell_index := index(cell)
			if integration_field[cell_index] == BLOCKED or cell == target_cell:
				vector_field[cell_index] = Vector2.ZERO
				continue
			var best_cost := integration_field[cell_index]
			var direction := Vector2.ZERO
			for offset in OFFSETS:
				var neighbor: Vector2i = cell + offset
				if not in_bounds(neighbor): continue
				var neighbor_cost := integration_field[index(neighbor)]
				if neighbor_cost < best_cost:
					best_cost = neighbor_cost
					direction = Vector2(offset).normalized()
			vector_field[cell_index] = direction

func _nearest_open_cell(origin: Vector2i) -> Vector2i:
	if cost_field[index(origin)] != BLOCKED: return origin
	for radius in range(1, 32):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius: continue
				var cell := origin + Vector2i(x, y)
				if in_bounds(cell) and cost_field[index(cell)] != BLOCKED: return cell
	return origin
