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


func find_weighted_cardinal_path(start_tile: Vector2i, goal_tile: Vector2i, tile_costs: Dictionary = {}) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start_tile]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	var finalized: Dictionary = {}
	cost_so_far[start_tile] = 0

	while not frontier.is_empty():
		var current_index: int = _find_lowest_cost_frontier_index(frontier, cost_so_far)
		var current: Vector2i = frontier.pop_at(current_index)
		if finalized.has(current):
			continue
		finalized[current] = true
		if current == goal_tile:
			return _reconstruct_path(came_from, start_tile, goal_tile)

		for direction in CARDINAL_DIRECTIONS:
			var next_tile: Vector2i = current + direction
			if finalized.has(next_tile) or not is_passable_tile(next_tile):
				continue

			var new_cost: int = int(cost_so_far[current]) + _get_tile_movement_cost(next_tile, tile_costs)
			if cost_so_far.has(next_tile) and new_cost >= int(cost_so_far[next_tile]):
				continue

			cost_so_far[next_tile] = new_cost
			came_from[next_tile] = current
			frontier.append(next_tile)

	return []


func get_cardinal_path_cost(path: Array[Vector2i], tile_costs: Dictionary = {}) -> int:
	var total_cost := 0
	for tile_position in path:
		total_cost += _get_tile_movement_cost(tile_position, tile_costs)

	return total_cost


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


func _find_lowest_cost_frontier_index(frontier: Array[Vector2i], cost_so_far: Dictionary) -> int:
	var best_index := 0
	var best_cost := int(cost_so_far[frontier[0]])
	for index in range(1, frontier.size()):
		var candidate_cost := int(cost_so_far[frontier[index]])
		if candidate_cost < best_cost:
			best_index = index
			best_cost = candidate_cost

	return best_index


func _get_tile_movement_cost(tile_position: Vector2i, tile_costs: Dictionary) -> int:
	return maxi(1, int(tile_costs.get(tile_position, 1)))


func _reconstruct_path(came_from: Dictionary, start_tile: Vector2i, goal_tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := goal_tile
	while current != start_tile:
		path.push_front(current)
		current = came_from[current]

	return path
