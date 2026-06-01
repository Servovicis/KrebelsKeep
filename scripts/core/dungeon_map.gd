class_name DungeonMap
extends RefCounted

enum TileType {
	SOLID_ROCK,
	FLOOR,
	BOUNDARY_WALL,
	ENTRANCE,
}

const WIDTH := 128
const HEIGHT := 128
const ENTRANCE_TILE := Vector2i(64, 127)
const OVERLORD_ROOM := Rect2i(62, 10, 5, 5)

var size := Vector2i(WIDTH, HEIGHT)
var tiles: Array[int] = []
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


func is_in_bounds(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < size.x and position.y < size.y


func is_overlord_room(position: Vector2i) -> bool:
	return overlord_room.has_point(position)


func get_tile_display_name(position: Vector2i) -> String:
	if not is_in_bounds(position):
		return "Out of bounds"
	if is_overlord_room(position):
		return "OverlordRoom"

	match get_tile(position):
		TileType.SOLID_ROCK:
			return "SolidRock"
		TileType.FLOOR:
			return "Floor"
		TileType.BOUNDARY_WALL:
			return "BoundaryWall"
		TileType.ENTRANCE:
			return "Entrance"
		_:
			return "Unknown"


func initialize_fixed_mvp() -> void:
	tiles.resize(size.x * size.y)
	tiles.fill(TileType.SOLID_ROCK)
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


func _tile_index(position: Vector2i) -> int:
	return position.y * size.x + position.x
