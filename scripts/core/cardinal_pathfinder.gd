class_name CardinalPathfinder
extends RefCounted

const DungeonMapScript := preload("res://scripts/core/dungeon_map.gd")
const TaskAssignmentScript := preload("res://scripts/core/task_assignment.gd")
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

var dungeon: RefCounted
var blocked_tiles: Dictionary = {}


func _init(source_dungeon: RefCounted) -> void:
	dungeon = source_dungeon


func find_best_reachable_interaction(start_tile: Vector2i, target_tile: Vector2i) -> RefCounted:
	var best_assignment := TaskAssignmentScript.new()

	for interaction_tile in get_cardinal_interaction_tiles(target_tile):
		var candidate_path: Array[Vector2i] = []
		if interaction_tile != start_tile:
			candidate_path = find_cardinal_path(start_tile, interaction_tile)
			if candidate_path.is_empty():
				continue

		if not best_assignment.reachable or candidate_path.size() < best_assignment.path.size():
			best_assignment.reachable = true
			best_assignment.interaction_tile = interaction_tile
			best_assignment.path = candidate_path

	return best_assignment


func find_cardinal_path(start_tile: Vector2i, goal_tile: Vector2i) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start_tile]
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	var cursor := 0
	visited[start_tile] = true

	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal_tile:
			return _reconstruct_path(came_from, start_tile, goal_tile)

		for direction in CARDINAL_DIRECTIONS:
			var next_tile := current + direction
			if visited.has(next_tile) or not is_passable_tile(next_tile):
				continue

			visited[next_tile] = true
			came_from[next_tile] = current
			frontier.append(next_tile)

	return []


func get_cardinal_interaction_tiles(target_tile: Vector2i) -> Array[Vector2i]:
	var interaction_tiles: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		var neighbor := target_tile + direction
		if is_passable_tile(neighbor):
			interaction_tiles.append(neighbor)

	return interaction_tiles


func is_passable_tile(tile_position: Vector2i) -> bool:
	if not dungeon.is_in_bounds(tile_position):
		return false
	if blocked_tiles.has(tile_position):
		return false

	var tile_type: int = dungeon.get_tile(tile_position)
	return tile_type == DungeonMapScript.TileType.FLOOR or tile_type == DungeonMapScript.TileType.ENTRANCE


func _reconstruct_path(came_from: Dictionary, start_tile: Vector2i, goal_tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := goal_tile
	while current != start_tile:
		path.push_front(current)
		current = came_from[current]

	return path
