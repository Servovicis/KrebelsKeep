extends Node2D

const DungeonAccessValidatorScript := preload("res://scripts/core/dungeon_access_validator.gd")
const DungeonMapScript := preload("res://scripts/core/dungeon_map.gd")
const CardinalPathfinderScript := preload("res://scripts/core/cardinal_pathfinder.gd")
const DigTaskScript := preload("res://scripts/core/dig_task.gd")
const ResourceManagerScript := preload("res://scripts/core/resource_manager.gd")
const BuildingDefinitionScript := preload("res://scripts/core/building_definition.gd")
const ConstructionTaskScript := preload("res://scripts/core/construction_task.gd")
const WorkerAgentScript := preload("res://scripts/core/worker_agent.gd")

const TILE_SIZE := 32
const CAMERA_SPEED := 600.0
const ZOOM_STEP := 0.1
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0
const COLOR_SOLID_ROCK := Color("20242a")
const COLOR_FLOOR := Color("4b5966")
const COLOR_BOUNDARY_WALL := Color("11151a")
const COLOR_ENTRANCE := Color("c58b3d")
const COLOR_OVERLORD_ROOM := Color("795d9a")
const COLOR_GRID_MAJOR := Color("3b4652")
const COLOR_GRID_MINOR := Color("2b333c")
const COLOR_DIG_TASK := Color("d6b24a", 0.55)
const COLOR_DIG_TASK_WAITING := Color("b9514f", 0.65)
const COLOR_DIG_TASK_ASSIGNED := Color("6fb7ff", 0.55)
const COLOR_CONSTRUCTION_TASK := Color("d99543", 0.68)
const COLOR_CONSTRUCTION_TASK_ASSIGNED := Color("6cd4c8", 0.58)
const COLOR_BARRACKS := Color("9d4f52")
const COLOR_WORKSHOP := Color("507dba")
const COLOR_LUMBERYARD := Color("4f9b5b")
const COLOR_MINE := Color("8b8f99")
const COLOR_WORKER_IDLE := Color("7bd88f")
const COLOR_WORKER_MOVING := Color("6fb7ff")
const COLOR_WORKER_WORKING := Color("f4d35e")
const COLOR_WORKER_BLOCKED := Color("d95f5f")
const WORKER_SPEED_TILES_PER_SECOND := 4.0
const DIG_WORK_REQUIRED := 2.0

enum ToolMode {
	SELECT,
	DIG,
	BUILD_BARRACKS,
	BUILD_WORKSHOP,
	BUILD_LUMBERYARD,
	BUILD_MINE,
}

@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $CanvasLayer/DebugLabel

var dungeon: RefCounted
var pathfinder: RefCounted
var resource_manager: RefCounted
var access_valid := false
var debug_visible := true
var active_tool: ToolMode = ToolMode.SELECT
var workers: Array[RefCounted] = []
var dig_tasks: Array[RefCounted] = []
var construction_tasks: Array[RefCounted] = []
var buildings: Dictionary = {}
var production_timers: Dictionary = {}
var next_task_id := 1
var next_task_order := 1
var last_message := "Ready"


func _ready() -> void:
	dungeon = DungeonMapScript.new()
	dungeon.initialize_fixed_mvp()
	pathfinder = CardinalPathfinderScript.new(dungeon)
	resource_manager = ResourceManagerScript.new()
	var access_validator := DungeonAccessValidatorScript.new()
	access_valid = access_validator.is_overlord_room_connected(dungeon)
	var access_message := "Access valid: Overlord room connected to outside" if access_valid else "Access invalid: Overlord room disconnected"

	print("Krebel's Keep Milestone 2B loaded")
	print(access_message)
	_spawn_workers()
	_update_debug_label()
	queue_redraw()


func _process(delta: float) -> void:
	var move_direction := Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	if move_direction != Vector2.ZERO:
		camera.position += move_direction * CAMERA_SPEED * delta / camera.zoom.x

	_update_workers(delta)
	_update_building_production(delta)
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_camera(ZOOM_STEP)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_camera(-ZOOM_STEP)
	elif event.is_action_pressed("tool_dig"):
		active_tool = ToolMode.DIG if active_tool != ToolMode.DIG else ToolMode.SELECT
		last_message = "Dig tool active" if active_tool == ToolMode.DIG else "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("tool_build_barracks"):
		active_tool = ToolMode.BUILD_BARRACKS if active_tool != ToolMode.BUILD_BARRACKS else ToolMode.SELECT
		last_message = "Build Barracks active" if active_tool == ToolMode.BUILD_BARRACKS else "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("tool_build_workshop"):
		active_tool = ToolMode.BUILD_WORKSHOP if active_tool != ToolMode.BUILD_WORKSHOP else ToolMode.SELECT
		last_message = "Build Workshop active" if active_tool == ToolMode.BUILD_WORKSHOP else "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("tool_build_lumberyard"):
		active_tool = ToolMode.BUILD_LUMBERYARD if active_tool != ToolMode.BUILD_LUMBERYARD else ToolMode.SELECT
		last_message = "Build Lumberyard active" if active_tool == ToolMode.BUILD_LUMBERYARD else "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("tool_build_mine"):
		active_tool = ToolMode.BUILD_MINE if active_tool != ToolMode.BUILD_MINE else ToolMode.SELECT
		last_message = "Build Mine active" if active_tool == ToolMode.BUILD_MINE else "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("select"):
		match active_tool:
			ToolMode.DIG:
				_try_create_dig_task(_get_hovered_tile())
			ToolMode.BUILD_BARRACKS:
				_try_create_construction_task(_get_hovered_tile(), BuildingDefinitionScript.BuildingType.BARRACKS_PLACEHOLDER)
			ToolMode.BUILD_WORKSHOP:
				_try_create_construction_task(_get_hovered_tile(), BuildingDefinitionScript.BuildingType.WORKSHOP_PLACEHOLDER)
			ToolMode.BUILD_LUMBERYARD:
				_try_create_construction_task(_get_hovered_tile(), BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER)
			ToolMode.BUILD_MINE:
				_try_create_construction_task(_get_hovered_tile(), BuildingDefinitionScript.BuildingType.MINE_PLACEHOLDER)
	elif event.is_action_pressed("cancel"):
		if active_tool == ToolMode.DIG and _try_cancel_dig_task(_get_hovered_tile()):
			return
		active_tool = ToolMode.SELECT
		last_message = "Select tool active"
		_update_debug_label()
	elif event.is_action_pressed("toggle_debug"):
		debug_visible = !debug_visible
		debug_label.visible = debug_visible


func _draw() -> void:
	if dungeon == null:
		return

	var map_size := Vector2(dungeon.size * TILE_SIZE)
	draw_rect(Rect2(Vector2.ZERO, map_size), COLOR_SOLID_ROCK, true)

	for y in range(dungeon.size.y):
		for x in range(dungeon.size.x):
			var tile_position := Vector2i(x, y)
			var tile_rect := Rect2(Vector2(tile_position * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, _get_tile_color(tile_position), true)

	for x in range(dungeon.size.x + 1):
		var x_pos := x * TILE_SIZE
		var color := COLOR_GRID_MAJOR if x % 8 == 0 else COLOR_GRID_MINOR
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, map_size.y), color, 1.0)

	for y in range(dungeon.size.y + 1):
		var y_pos := y * TILE_SIZE
		var color := COLOR_GRID_MAJOR if y % 8 == 0 else COLOR_GRID_MINOR
		draw_line(Vector2(0, y_pos), Vector2(map_size.x, y_pos), color, 1.0)

	for task in dig_tasks:
		if task.status == DigTaskScript.TaskStatus.COMPLETE or task.status == DigTaskScript.TaskStatus.CANCELED:
			continue
		var task_rect := Rect2(Vector2(task.target_tile * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var task_color := _get_dig_task_color(task)
		draw_rect(task_rect.grow(-5.0), task_color, true)
		draw_rect(task_rect.grow(-5.0), Color("f7e2a1"), false, 2.0)

	for task in construction_tasks:
		if task.status == ConstructionTaskScript.TaskStatus.COMPLETE or task.status == ConstructionTaskScript.TaskStatus.CANCELED:
			continue
		var task_rect := Rect2(Vector2(task.target_tile * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var task_color := COLOR_CONSTRUCTION_TASK_ASSIGNED if task.status == ConstructionTaskScript.TaskStatus.ASSIGNED or task.status == ConstructionTaskScript.TaskStatus.IN_PROGRESS else COLOR_CONSTRUCTION_TASK
		draw_rect(task_rect.grow(-4.0), task_color, true)
		draw_rect(task_rect.grow(-4.0), Color("ffe0a1"), false, 2.0)

	for tile_position in buildings:
		var building_rect := Rect2(Vector2(tile_position * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var building_type: int = int(buildings[tile_position])
		draw_rect(building_rect.grow(-3.0), _get_building_color(building_type), true)
		draw_rect(building_rect.grow(-3.0), Color("101318"), false, 2.0)

	for worker in workers:
		var worker_color := _get_worker_color(worker.state)
		draw_circle(worker.world_position, TILE_SIZE * 0.28, worker_color)
		draw_circle(worker.world_position, TILE_SIZE * 0.28, Color("0b0f14"), false, 2.0)


func _zoom_camera(amount: float) -> void:
	var next_zoom: float = clampf(camera.zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)


func _get_tile_color(tile_position: Vector2i) -> Color:
	if dungeon.is_overlord_room(tile_position):
		return COLOR_OVERLORD_ROOM

	match dungeon.get_tile(tile_position):
		DungeonMapScript.TileType.SOLID_ROCK:
			return COLOR_SOLID_ROCK
		DungeonMapScript.TileType.FLOOR:
			return COLOR_FLOOR
		DungeonMapScript.TileType.BOUNDARY_WALL:
			return COLOR_BOUNDARY_WALL
		DungeonMapScript.TileType.ENTRANCE:
			return COLOR_ENTRANCE
		_:
			return Color.MAGENTA


func _update_debug_label() -> void:
	if dungeon == null:
		return

	var access_message := "Access valid: Overlord room connected to outside" if access_valid else "Access invalid: Overlord room disconnected"
	var hover_text := "Outside map"
	var mouse_tile := _get_hovered_tile()
	if dungeon.is_in_bounds(mouse_tile):
		hover_text = "Tile %s: %s" % [str(mouse_tile), dungeon.get_tile_display_name(mouse_tile)]

	var task_counts := _get_task_counts_text()
	var worker_lines: Array[String] = []
	for worker in workers:
		var worker_task := _get_task_by_id(worker.task_id)
		var worker_task_text := "-"
		if worker_task != null:
			worker_task_text = "%s %d" % [_get_task_action_name(worker_task), worker_task.id]
		worker_lines.append("Worker %d: %s tile %s task %s" % [
			worker.id,
			_get_worker_state_name(worker.state),
			str(worker.tile_position),
			worker_task_text,
		])

	debug_label.text = "Krebel's Keep - Milestone 2B loaded\n%s\nResources: %s\nTool: %s\n%s\nTasks: %s\n%s\n%s" % [
		access_message,
		resource_manager.get_debug_text(),
		_get_tool_name(active_tool),
		hover_text,
		task_counts,
		"\n".join(worker_lines),
		last_message,
	]


func _spawn_workers() -> void:
	var spawn_tiles: Array[Vector2i] = [
		Vector2i(dungeon.overlord_room.position.x + 1, dungeon.overlord_room.position.y + 2),
		Vector2i(dungeon.overlord_room.position.x + 3, dungeon.overlord_room.position.y + 2),
	]

	workers.clear()
	for index in range(spawn_tiles.size()):
		var worker := WorkerAgentScript.new()
		worker.id = index + 1
		worker.tile_position = spawn_tiles[index]
		worker.world_position = _tile_center(worker.tile_position)
		workers.append(worker)


func _update_workers(delta: float) -> void:
	for worker in workers:
		match worker.state:
			WorkerAgentScript.WorkerState.IDLE:
				_assign_next_task(worker)
			WorkerAgentScript.WorkerState.MOVING_TO_TASK:
				_update_worker_movement(worker, delta)
			WorkerAgentScript.WorkerState.WORKING:
				_update_worker_work(worker, delta)
			WorkerAgentScript.WorkerState.BLOCKED:
				_assign_next_task(worker)


func _assign_next_task(worker: RefCounted) -> void:
	for task in _get_assignable_tasks():
		if not _is_waiting_for_assignment(task):
			continue

		var assignment := _find_reachable_interaction(worker.tile_position, task.target_tile)
		if not assignment.reachable:
			continue

		task.interaction_tile = assignment.interaction_tile
		task.status = DigTaskScript.TaskStatus.ASSIGNED
		task.assigned_worker_id = worker.id
		worker.task_id = task.id
		worker.path = assignment.path
		worker.state = WorkerAgentScript.WorkerState.WORKING if worker.path.is_empty() else WorkerAgentScript.WorkerState.MOVING_TO_TASK
		last_message = "%s task %d assigned to worker %d" % [_get_task_action_name(task), task.id, worker.id]
		return


func _update_worker_movement(worker: RefCounted, delta: float) -> void:
	if worker.path.is_empty():
		worker.state = WorkerAgentScript.WorkerState.WORKING
		return

	var next_tile: Vector2i = worker.path[0]
	if not pathfinder.is_passable_tile(next_tile):
		var task := _get_task_by_id(worker.task_id)
		if task != null and task.status == DigTaskScript.TaskStatus.ASSIGNED:
			task.status = DigTaskScript.TaskStatus.PENDING
			task.assigned_worker_id = -1
			task.interaction_tile = Vector2i(-1, -1)

		worker.task_id = -1
		worker.path.clear()
		worker.world_position = _tile_center(worker.tile_position)
		worker.state = WorkerAgentScript.WorkerState.IDLE
		last_message = "Worker %d path blocked, retrying assignment" % worker.id
		queue_redraw()
		return

	var next_position := _tile_center(next_tile)
	var max_distance := WORKER_SPEED_TILES_PER_SECOND * TILE_SIZE * delta
	worker.world_position = worker.world_position.move_toward(next_position, max_distance)

	if worker.world_position.is_equal_approx(next_position):
		worker.tile_position = next_tile
		worker.path.remove_at(0)
		if worker.path.is_empty():
			worker.state = WorkerAgentScript.WorkerState.WORKING

	queue_redraw()


func _update_worker_work(worker: RefCounted, delta: float) -> void:
	var task := _get_task_by_id(worker.task_id)
	if task == null:
		worker.task_id = -1
		worker.state = WorkerAgentScript.WorkerState.IDLE
		return

	if task.status == DigTaskScript.TaskStatus.ASSIGNED:
		task.status = DigTaskScript.TaskStatus.IN_PROGRESS
		last_message = "%s task %d in progress" % [_get_task_action_name(task), task.id]

	task.work_done += delta
	if task.work_done < task.work_required:
		return

	if _is_construction_task(task):
		buildings[task.target_tile] = task.building_type
		_register_production_building(task.target_tile, task.building_type)
	else:
		dungeon.set_tile(task.target_tile, DungeonMapScript.TileType.FLOOR)

	task.status = DigTaskScript.TaskStatus.COMPLETE
	worker.task_id = -1
	worker.state = WorkerAgentScript.WorkerState.IDLE
	var access_validator := DungeonAccessValidatorScript.new()
	access_valid = access_validator.is_overlord_room_connected(dungeon)
	last_message = "%s task %d complete at %s" % [_get_task_action_name(task), task.id, str(task.target_tile)]
	print("%s. Access valid: %s" % [last_message, str(access_valid)])
	_update_pathfinder_blocked_tiles()
	_reconsider_moving_worker_paths()
	queue_redraw()


func _try_create_dig_task(tile_position: Vector2i) -> void:
	var invalid_reason := _get_invalid_dig_reason(tile_position)
	if invalid_reason != "":
		last_message = invalid_reason
		print(last_message)
		_update_debug_label()
		return

	var task := DigTaskScript.new()
	task.id = next_task_id
	task.target_tile = tile_position
	task.created_order = next_task_order
	next_task_id += 1
	next_task_order += 1
	dig_tasks.append(task)
	if _can_any_worker_reach_task(tile_position):
		last_message = "Queued dig task %d at %s" % [task.id, str(tile_position)]
	else:
		last_message = "Queued dig task %d at %s, waiting for access" % [task.id, str(tile_position)]
	print(last_message)
	_update_debug_label()
	queue_redraw()


func _try_create_construction_task(tile_position: Vector2i, building_type: BuildingDefinitionScript.BuildingType) -> void:
	var definition := BuildingDefinitionScript.new()
	definition.configure(building_type)
	var invalid_reason := _get_invalid_build_reason(tile_position, definition)
	if invalid_reason != "":
		last_message = invalid_reason
		print(last_message)
		_update_debug_label()
		return

	if not resource_manager.spend(definition.cost):
		last_message = "Invalid build: insufficient resources for %s" % definition.display_name
		print(last_message)
		_update_debug_label()
		return

	var task := ConstructionTaskScript.new()
	task.id = next_task_id
	task.target_tile = tile_position
	task.created_order = next_task_order
	task.building_type = building_type
	task.work_required = definition.build_time
	next_task_id += 1
	next_task_order += 1
	construction_tasks.append(task)
	_update_pathfinder_blocked_tiles()

	if _can_any_worker_reach_task(tile_position):
		last_message = "Queued %s construction task %d at %s" % [definition.display_name, task.id, str(tile_position)]
	else:
		last_message = "Queued %s construction task %d at %s, waiting for access" % [definition.display_name, task.id, str(tile_position)]
	print(last_message)
	_update_debug_label()
	queue_redraw()


func _register_production_building(tile_position: Vector2i, building_type: BuildingDefinitionScript.BuildingType) -> void:
	var definition := BuildingDefinitionScript.new()
	definition.configure(building_type)
	if not definition.produces_resource:
		return

	production_timers[tile_position] = 0.0


func _update_building_production(delta: float) -> void:
	if production_timers.is_empty():
		return

	var produced := false
	for tile_position in production_timers.keys():
		if not buildings.has(tile_position):
			production_timers.erase(tile_position)
			continue

		var definition := BuildingDefinitionScript.new()
		definition.configure(buildings[tile_position])
		if not definition.produces_resource:
			production_timers.erase(tile_position)
			continue

		var timer := float(production_timers[tile_position]) + delta
		while timer >= definition.production_interval:
			timer -= definition.production_interval
			resource_manager.add(definition.production_resource, definition.production_amount)
			last_message = "%s produced +%d %s" % [
				definition.display_name,
				definition.production_amount,
				_get_resource_name(definition.production_resource),
			]
			print(last_message)
			produced = true

		production_timers[tile_position] = timer

	if produced:
		_update_debug_label()


func _get_invalid_dig_reason(tile_position: Vector2i) -> String:
	if not dungeon.is_in_bounds(tile_position):
		return "Invalid dig: outside map"

	var tile_type: int = dungeon.get_tile(tile_position)
	if tile_type == DungeonMapScript.TileType.BOUNDARY_WALL:
		return "Invalid dig: boundary wall"
	if tile_type != DungeonMapScript.TileType.SOLID_ROCK:
		return "Invalid dig: target must be SolidRock"
	if _has_active_dig_task(tile_position):
		return "Invalid dig: tile already has a dig task"
	if _has_building_at(tile_position) or _has_active_construction_task(tile_position):
		return "Invalid dig: tile already has a building task"

	return ""


func _get_invalid_build_reason(tile_position: Vector2i, definition: RefCounted) -> String:
	if not dungeon.is_in_bounds(tile_position):
		return "Invalid build: outside map"

	var tile_type: int = dungeon.get_tile(tile_position)
	if tile_type == DungeonMapScript.TileType.SOLID_ROCK:
		return "Invalid build: target must be Floor"
	if tile_type == DungeonMapScript.TileType.BOUNDARY_WALL:
		return "Invalid build: boundary wall"
	if tile_type == DungeonMapScript.TileType.ENTRANCE:
		return "Invalid build: entrance tile"
	if tile_type != DungeonMapScript.TileType.FLOOR:
		return "Invalid build: target must be Floor"
	if _has_active_dig_task(tile_position):
		return "Invalid build: tile has an active dig task"
	if _has_active_construction_task(tile_position):
		return "Invalid build: tile already has a construction task"
	if _has_building_at(tile_position):
		return "Invalid build: tile already has a building"
	if _has_worker_at(tile_position):
		return "Invalid build: tile occupied by worker"
	if not resource_manager.can_afford(definition.cost):
		return "Invalid build: insufficient resources for %s" % definition.display_name

	return ""


func _has_active_dig_task(tile_position: Vector2i) -> bool:
	return _get_active_dig_task_at(tile_position) != null


func _get_active_dig_task_at(tile_position: Vector2i) -> RefCounted:
	for task in dig_tasks:
		if task.target_tile != tile_position:
			continue
		if task.status == DigTaskScript.TaskStatus.COMPLETE or task.status == DigTaskScript.TaskStatus.CANCELED:
			continue
		return task

	return null


func _has_active_construction_task(tile_position: Vector2i) -> bool:
	for task in construction_tasks:
		if task.target_tile != tile_position:
			continue
		if task.status == ConstructionTaskScript.TaskStatus.COMPLETE or task.status == ConstructionTaskScript.TaskStatus.CANCELED:
			continue
		return true

	return false


func _has_building_at(tile_position: Vector2i) -> bool:
	return buildings.has(tile_position)


func _has_worker_at(tile_position: Vector2i) -> bool:
	for worker in workers:
		if worker.tile_position == tile_position:
			return true

	return false


func _try_cancel_dig_task(tile_position: Vector2i) -> bool:
	if not dungeon.is_in_bounds(tile_position):
		last_message = "No dig task to cancel"
		print(last_message)
		_update_debug_label()
		return true

	var task := _get_active_dig_task_at(tile_position)
	if task == null:
		last_message = "No dig task to cancel at %s" % str(tile_position)
		print(last_message)
		_update_debug_label()
		return true

	if task.status == DigTaskScript.TaskStatus.IN_PROGRESS:
		last_message = "Cannot cancel dig task %d currently in progress" % task.id
		print(last_message)
		_update_debug_label()
		return true

	if task.status == DigTaskScript.TaskStatus.ASSIGNED:
		var assigned_worker := _get_worker_by_id(task.assigned_worker_id)
		if assigned_worker != null:
			if assigned_worker.state == WorkerAgentScript.WorkerState.WORKING:
				last_message = "Cannot cancel dig task %d currently in progress" % task.id
				print(last_message)
				_update_debug_label()
				return true

			assigned_worker.task_id = -1
			assigned_worker.path.clear()
			assigned_worker.world_position = _tile_center(assigned_worker.tile_position)
			assigned_worker.state = WorkerAgentScript.WorkerState.IDLE

	task.status = DigTaskScript.TaskStatus.CANCELED
	task.assigned_worker_id = -1
	task.interaction_tile = Vector2i(-1, -1)
	last_message = "Canceled dig task %d at %s" % [task.id, str(task.target_tile)]
	print(last_message)
	_update_debug_label()
	queue_redraw()
	return true


func _is_waiting_for_assignment(task: RefCounted) -> bool:
	return task.status == DigTaskScript.TaskStatus.PENDING or task.status == DigTaskScript.TaskStatus.BLOCKED


func _get_assignable_tasks() -> Array[RefCounted]:
	var tasks: Array[RefCounted] = []
	for task in dig_tasks:
		tasks.append(task)
	for task in construction_tasks:
		tasks.append(task)

	tasks.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		return a.created_order < b.created_order
	)
	return tasks


func _can_any_worker_reach_task(target_tile: Vector2i) -> bool:
	for worker in workers:
		var assignment := _find_reachable_interaction(worker.tile_position, target_tile)
		if assignment.reachable:
			return true

	return false


func _find_reachable_interaction(start_tile: Vector2i, target_tile: Vector2i) -> RefCounted:
	return pathfinder.find_best_reachable_interaction(start_tile, target_tile)


func _get_task_by_id(task_id: int) -> RefCounted:
	for task in dig_tasks:
		if task.id == task_id:
			return task
	for task in construction_tasks:
		if task.id == task_id:
			return task

	return null


func _get_worker_by_id(worker_id: int) -> RefCounted:
	for worker in workers:
		if worker.id == worker_id:
			return worker

	return null


func _reconsider_moving_worker_paths() -> void:
	for worker in workers:
		if worker.state != WorkerAgentScript.WorkerState.MOVING_TO_TASK:
			continue
		if not worker.world_position.is_equal_approx(_tile_center(worker.tile_position)):
			continue

		var task := _get_task_by_id(worker.task_id)
		if task == null or task.status != DigTaskScript.TaskStatus.ASSIGNED:
			continue

		var assignment := _find_reachable_interaction(worker.tile_position, task.target_tile)
		if not assignment.reachable or assignment.path.size() >= worker.path.size():
			continue

		task.interaction_tile = assignment.interaction_tile
		worker.path = assignment.path
		print("Worker %d switched to shorter path for %s task %d" % [worker.id, _get_task_action_name(task), task.id])


func _get_hovered_tile() -> Vector2i:
	var mouse_position := get_global_mouse_position()
	var tile_position := Vector2i(floori(mouse_position.x / TILE_SIZE), floori(mouse_position.y / TILE_SIZE))
	if dungeon == null or not dungeon.is_in_bounds(tile_position):
		return Vector2i(-1, -1)

	return tile_position


func _tile_center(tile_position: Vector2i) -> Vector2:
	return Vector2(tile_position * TILE_SIZE) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


func _get_worker_color(state: int) -> Color:
	match state:
		WorkerAgentScript.WorkerState.IDLE:
			return COLOR_WORKER_IDLE
		WorkerAgentScript.WorkerState.MOVING_TO_TASK:
			return COLOR_WORKER_MOVING
		WorkerAgentScript.WorkerState.WORKING:
			return COLOR_WORKER_WORKING
		WorkerAgentScript.WorkerState.BLOCKED:
			return COLOR_WORKER_BLOCKED
		_:
			return Color.MAGENTA


func _get_dig_task_color(task: RefCounted) -> Color:
	if task.status == DigTaskScript.TaskStatus.ASSIGNED or task.status == DigTaskScript.TaskStatus.IN_PROGRESS:
		return COLOR_DIG_TASK_ASSIGNED
	if _is_waiting_for_assignment(task) and not _can_any_worker_reach_task(task.target_tile):
		return COLOR_DIG_TASK_WAITING

	return COLOR_DIG_TASK


func _get_worker_state_name(state: int) -> String:
	match state:
		WorkerAgentScript.WorkerState.IDLE:
			return "Idle"
		WorkerAgentScript.WorkerState.MOVING_TO_TASK:
			return "MovingToTask"
		WorkerAgentScript.WorkerState.WORKING:
			return "Working"
		WorkerAgentScript.WorkerState.BLOCKED:
			return "Blocked"
		_:
			return "Unknown"


func _get_task_status_name(status: int) -> String:
	match status:
		DigTaskScript.TaskStatus.PENDING:
			return "Pending"
		DigTaskScript.TaskStatus.ASSIGNED:
			return "Assigned"
		DigTaskScript.TaskStatus.IN_PROGRESS:
			return "InProgress"
		DigTaskScript.TaskStatus.COMPLETE:
			return "Complete"
		DigTaskScript.TaskStatus.BLOCKED:
			return "Blocked"
		DigTaskScript.TaskStatus.CANCELED:
			return "Canceled"
		_:
			return "Unknown"


func _get_tool_name(tool: ToolMode) -> String:
	match tool:
		ToolMode.SELECT:
			return "Select"
		ToolMode.DIG:
			return "Dig"
		ToolMode.BUILD_BARRACKS:
			return "Build Barracks"
		ToolMode.BUILD_WORKSHOP:
			return "Build Workshop"
		ToolMode.BUILD_LUMBERYARD:
			return "Build Lumberyard"
		ToolMode.BUILD_MINE:
			return "Build Mine"
		_:
			return "Unknown"


func _get_task_counts_text() -> String:
	var counts: Dictionary = {}
	for task in _get_assignable_tasks():
		var status_name := _get_debug_task_status_name(task)
		counts[status_name] = int(counts.get(status_name, 0)) + 1

	if counts.is_empty():
		return "0"

	var parts: Array[String] = []
	for status_name in counts:
		var status_text := str(status_name)
		parts.append("%s %d" % [status_text, counts[status_text]])

	return ", ".join(parts)


func _get_debug_task_status_name(task: RefCounted) -> String:
	if _is_waiting_for_assignment(task):
		if _can_any_worker_reach_task(task.target_tile):
			return "%sQueued" % _get_task_action_name(task)
		return "%sWaitingForAccess" % _get_task_action_name(task)

	return "%s%s" % [_get_task_action_name(task), _get_task_status_name(task.status)]


func _get_task_action_name(task: RefCounted) -> String:
	if _is_construction_task(task):
		return "Build"

	return "Dig"


func _is_construction_task(task: RefCounted) -> bool:
	return task != null and task.get_script() == ConstructionTaskScript


func _get_building_color(building_type: int) -> Color:
	match building_type:
		BuildingDefinitionScript.BuildingType.BARRACKS_PLACEHOLDER:
			return COLOR_BARRACKS
		BuildingDefinitionScript.BuildingType.WORKSHOP_PLACEHOLDER:
			return COLOR_WORKSHOP
		BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER:
			return COLOR_LUMBERYARD
		BuildingDefinitionScript.BuildingType.MINE_PLACEHOLDER:
			return COLOR_MINE
		_:
			return Color.MAGENTA


func _get_resource_name(resource_type: ResourceManagerScript.ResourceType) -> String:
	match resource_type:
		ResourceManagerScript.ResourceType.WOOD:
			return "Wood"
		ResourceManagerScript.ResourceType.ORE:
			return "Ore"
		ResourceManagerScript.ResourceType.GOLD:
			return "Gold"
		_:
			return "Unknown"


func _update_pathfinder_blocked_tiles() -> void:
	var blocked_tiles: Dictionary = {}
	for tile_position in buildings:
		blocked_tiles[tile_position] = true
	for task in construction_tasks:
		if task.status == ConstructionTaskScript.TaskStatus.COMPLETE or task.status == ConstructionTaskScript.TaskStatus.CANCELED:
			continue
		blocked_tiles[task.target_tile] = true

	pathfinder.blocked_tiles = blocked_tiles
