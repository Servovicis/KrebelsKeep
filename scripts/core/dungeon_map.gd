class_name DungeonMap
extends RefCounted

enum TileType {
	SOLID_ROCK,
	FLOOR,
	BOUNDARY_WALL,
	ENTRANCE,
}

enum ResourceNodeType {
	NONE,
	ORE,
	ROOT,
}

const WIDTH := 128
const HEIGHT := 128
const ENTRANCE_TILE := Vector2i(64, 127)
const OVERLORD_ROOM := Rect2i(62, 10, 5, 5)
const DEFAULT_SOURCE_MAX_AVAILABLE := 5
const DEFAULT_SOURCE_REGEN_INTERVAL := 5.0
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var size := Vector2i(WIDTH, HEIGHT)
var tiles: Array[int] = []
# These are permanent regenerating resource sources, despite the temporary
# "node" API name. Harvesting spends current availability; dungeon magic
# regenerates that availability over time instead of finite depletion.
var resource_nodes: Array[int] = []
var resource_current_available: Array[int] = []
var resource_max_available: Array[int] = []
var resource_regen_interval: Array[float] = []
var resource_regen_timers: Array[float] = []
var entrance_tiles: Array[Vector2i] = []
var overlord_room: Rect2i = OVERLORD_ROOM


func get_tile(position: Vector2i) -> int:
	if not is_in_bounds(position):
		return TileType.BOUNDARY_WALL

	return tiles[_tile_index(position)]


func set_tile(position: Vector2i, tile_type: TileType) -> void:
	if not is_in_bounds(position):
		return

	tiles[_tile_index(position)] = tile_type
	if tile_type != TileType.FLOOR:
		set_resource_node(position, ResourceNodeType.NONE)


func get_resource_node(position: Vector2i) -> int:
	if not is_in_bounds(position):
		return ResourceNodeType.NONE

	return resource_nodes[_tile_index(position)]


func set_resource_node(position: Vector2i, resource_node_type: ResourceNodeType) -> void:
	if not is_in_bounds(position):
		return

	var index := _tile_index(position)
	resource_nodes[index] = resource_node_type
	if resource_node_type == ResourceNodeType.NONE:
		resource_current_available[index] = 0
		resource_max_available[index] = 0
		resource_regen_interval[index] = 0.0
		resource_regen_timers[index] = 0.0
	else:
		resource_current_available[index] = DEFAULT_SOURCE_MAX_AVAILABLE
		resource_max_available[index] = DEFAULT_SOURCE_MAX_AVAILABLE
		resource_regen_interval[index] = DEFAULT_SOURCE_REGEN_INTERVAL
		resource_regen_timers[index] = 0.0


func has_resource_node(position: Vector2i, resource_node_type: ResourceNodeType) -> bool:
	return get_resource_node(position) == resource_node_type


func get_resource_current_available(position: Vector2i) -> int:
	if not is_in_bounds(position):
		return 0

	return resource_current_available[_tile_index(position)]


func get_resource_max_available(position: Vector2i) -> int:
	if not is_in_bounds(position):
		return 0

	return resource_max_available[_tile_index(position)]


func is_resource_empty(position: Vector2i) -> bool:
	return get_resource_node(position) != ResourceNodeType.NONE and get_resource_current_available(position) <= 0


func try_harvest_resource(position: Vector2i, amount: int = 1) -> bool:
	if get_resource_node(position) == ResourceNodeType.NONE:
		return false

	var index := _tile_index(position)
	if resource_current_available[index] < amount:
		return false

	resource_current_available[index] -= amount
	return true


func update_resource_regeneration(delta: float) -> void:
	for index in range(resource_nodes.size()):
		if resource_nodes[index] == ResourceNodeType.NONE:
			continue
		if resource_current_available[index] >= resource_max_available[index]:
			resource_regen_timers[index] = 0.0
			continue

		resource_regen_timers[index] += delta
		var interval := resource_regen_interval[index]
		if interval <= 0.0:
			continue
		while resource_regen_timers[index] >= interval and resource_current_available[index] < resource_max_available[index]:
			resource_regen_timers[index] -= interval
			resource_current_available[index] += 1


func is_in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < size.x and position.y < size.y


func is_overlord_room(position: Vector2i) -> bool:
	return overlord_room.has_point(position)


func get_tile_display_name(position: Vector2i) -> String:
	if not is_in_bounds(position):
		return "Out of bounds"
	if is_overlord_room(position):
		return "OverlordRoom"

	var node_name := get_resource_node_display_name(position)
	match get_tile(position):
		TileType.SOLID_ROCK:
			return "SolidRock"
		TileType.FLOOR:
			return "Floor" if node_name == "" else "Floor, %s" % node_name
		TileType.BOUNDARY_WALL:
			return "BoundaryWall"
		TileType.ENTRANCE:
			return "Entrance"
		_:
			return "Unknown"


func get_resource_node_display_name(position: Vector2i) -> String:
	match get_resource_node(position):
		ResourceNodeType.ORE:
			return _get_resource_source_display_name(position, "Exposed Ore Source")
		ResourceNodeType.ROOT:
			return _get_resource_source_display_name(position, "Exposed Root Source")
		_:
			return ""


func _get_resource_source_display_name(position: Vector2i, source_name: String) -> String:
	var current := get_resource_current_available(position)
	var maximum := get_resource_max_available(position)
	var suffix := ", regenerating" if current <= 0 and maximum > 0 else ""
	return "%s: %d/%d available%s" % [source_name, current, maximum, suffix]


func initialize_fixed_mvp() -> void:
	tiles.resize(size.x * size.y)
	tiles.fill(TileType.SOLID_ROCK)
	resource_nodes.resize(size.x * size.y)
	resource_nodes.fill(ResourceNodeType.NONE)
	resource_current_available.resize(size.x * size.y)
	resource_current_available.fill(0)
	resource_max_available.resize(size.x * size.y)
	resource_max_available.fill(0)
	resource_regen_interval.resize(size.x * size.y)
	resource_regen_interval.fill(0.0)
	resource_regen_timers.resize(size.x * size.y)
	resource_regen_timers.fill(0.0)
	entrance_tiles.clear()

	for x in range(size.x):
		set_tile(Vector2i(x, 0), TileType.BOUNDARY_WALL)
		set_tile(Vector2i(x, size.y - 1), TileType.BOUNDARY_WALL)

	for y in range(size.y):
		set_tile(Vector2i(0, y), TileType.BOUNDARY_WALL)
		set_tile(Vector2i(size.x - 1, y), TileType.BOUNDARY_WALL)

	set_tile(ENTRANCE_TILE, TileType.ENTRANCE)
	entrance_tiles.append(ENTRANCE_TILE)

	_carve_rect(overlord_room)
	_carve_cardinal_path(ENTRANCE_TILE, Vector2i(overlord_room.position.x + 2, overlord_room.position.y + overlord_room.size.y - 1))
	_place_fixed_resource_nodes()


func _carve_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			set_tile(Vector2i(x, y), TileType.FLOOR)


func _carve_cardinal_path(start: Vector2i, target: Vector2i) -> void:
	var current := start

	while current.y != target.y:
		current.y += -1 if target.y < current.y else 1
		if current != start:
			set_tile(current, TileType.FLOOR)

	while current.x != target.x:
		current.x += -1 if target.x < current.x else 1
		set_tile(current, TileType.FLOOR)


func _place_fixed_resource_nodes() -> void:
	# Milestone 2E exposes fixed test sources on floor so Mine/Lumberyard
	# placement and worker harvest trips are easy to validate. Later sources
	# should usually be reached or exposed by digging instead of all starting
	# pre-dug.
	_carve_cardinal_path(Vector2i(64, 92), Vector2i(60, 92))
	_carve_cardinal_path(Vector2i(64, 84), Vector2i(59, 84))
	_carve_cardinal_path(Vector2i(64, 70), Vector2i(68, 70))
	_carve_cardinal_path(Vector2i(64, 62), Vector2i(69, 62))
	_carve_source_pocket(Vector2i(60, 92))
	_carve_source_pocket(Vector2i(59, 84))
	_carve_source_pocket(Vector2i(68, 70))
	_carve_source_pocket(Vector2i(69, 62))

	# Sources are permanent. Roots regrow through dungeon magic; ore-rich
	# sources replenish as dungeon magic slowly replaces ore.
	set_resource_node(Vector2i(60, 92), ResourceNodeType.ORE)
	set_resource_node(Vector2i(59, 84), ResourceNodeType.ORE)
	set_resource_node(Vector2i(68, 70), ResourceNodeType.ROOT)
	set_resource_node(Vector2i(69, 62), ResourceNodeType.ROOT)


func _tile_index(position: Vector2i) -> int:
	return position.y * size.x + position.x


func _carve_source_pocket(source_tile: Vector2i) -> void:
	for direction in CARDINAL_DIRECTIONS:
		set_tile(source_tile + direction, TileType.FLOOR)
