class_name DungeonAccessValidator
extends RefCounted

const DungeonMapScript := preload("res://scripts/core/dungeon_map.gd")
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]


func is_overlord_room_connected(dungeon: RefCounted, blocked_tiles: Dictionary = {}) -> bool:
	var reachable := _find_reachable_tiles(dungeon, blocked_tiles)

	for y in range(dungeon.overlord_room.position.y, dungeon.overlord_room.end.y):
		for x in range(dungeon.overlord_room.position.x, dungeon.overlord_room.end.x):
			var position := Vector2i(x, y)
			if reachable.has(position):
				return true

	return false


func _find_reachable_tiles(dungeon: RefCounted, blocked_tiles: Dictionary) -> Dictionary:
	var reachable: Dictionary = {}
	var frontier: Array[Vector2i] = []

	for entrance_tile in dungeon.entrance_tiles:
		if _can_access(dungeon, entrance_tile, blocked_tiles):
			frontier.append(entrance_tile)
			reachable[entrance_tile] = true

	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1

		for direction in CARDINAL_DIRECTIONS:
			var next_tile := current + direction
			if reachable.has(next_tile) or not _can_access(dungeon, next_tile, blocked_tiles):
				continue

			reachable[next_tile] = true
			frontier.append(next_tile)

	return reachable


func _can_access(dungeon: RefCounted, position: Vector2i, blocked_tiles: Dictionary) -> bool:
	if not dungeon.is_in_bounds(position):
		return false
	if blocked_tiles.has(position):
		return false

	var tile_type: int = dungeon.get_tile(position)
	return tile_type == DungeonMapScript.TileType.ENTRANCE or tile_type == DungeonMapScript.TileType.FLOOR
