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

var size := Vector2i(WIDTH, HEIGHT)
var tiles: Array[int] = []
var resource_nodes: Array[int] = []
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

	resource_nodes[_tile_index(position)] = resource_node_type


func has_resource_node(position: Vector2i, resource_node_type: ResourceNodeType) -> bool:
	return get_resource_node(position) == resource_node_type


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
			return "OreNode"
		ResourceNodeType.ROOT:
			return "RootNode"
		_:
			return ""


func initialize_fixed_mvp() -> void:
	tiles.resize(size.x * size.y)
	tiles.fill(TileType.SOLID_ROCK)
	resource_nodes.resize(size.x * size.y)
	resource_nodes.fill(ResourceNodeType.NONE)
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
	_carve_cardinal_path(Vector2i(64, 92), Vector2i(60, 92))
	_carve_cardinal_path(Vector2i(64, 84), Vector2i(59, 84))
	_carve_cardinal_path(Vector2i(64, 70), Vector2i(68, 70))
	_carve_cardinal_path(Vector2i(64, 62), Vector2i(69, 62))

	set_resource_node(Vector2i(60, 92), ResourceNodeType.ORE)
	set_resource_node(Vector2i(59, 84), ResourceNodeType.ORE)
	set_resource_node(Vector2i(68, 70), ResourceNodeType.ROOT)
	set_resource_node(Vector2i(69, 62), ResourceNodeType.ROOT)


func _tile_index(position: Vector2i) -> int:
	return position.y * size.x + position.x
