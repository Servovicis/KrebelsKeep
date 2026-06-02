extends Node2D

const DungeonAccessValidatorScript := preload("res://scripts/core/dungeon_access_validator.gd")
const DungeonMapScript := preload("res://scripts/core/dungeon_map.gd")
const CardinalPathfinderScript := preload("res://scripts/core/cardinal_pathfinder.gd")
const DigTaskScript := preload("res://scripts/core/dig_task.gd")
const ResourceManagerScript := preload("res://scripts/core/resource_manager.gd")
const BuildingDefinitionScript := preload("res://scripts/core/building_definition.gd")
const ConstructionTaskScript := preload("res://scripts/core/construction_task.gd")
const HarvestTaskScript := preload("res://scripts/core/harvest_task.gd")
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
const COLOR_ORE_SOURCE := Color("b9c3cf")
const COLOR_ROOT_SOURCE := Color("7aa15f")
const COLOR_GRID_MAJOR := Color("3b4652")
const COLOR_GRID_MINOR := Color("2b333c")
const COLOR_DIG_TASK := Color("d6b24a", 0.55)
const COLOR_DIG_TASK_WAITING := Color("b9514f", 0.65)
const COLOR_DIG_TASK_ASSIGNED := Color("6fb7ff", 0.55)
const COLOR_CONSTRUCTION_TASK := Color("d99543", 0.68)
const COLOR_CONSTRUCTION_TASK_ASSIGNED := Color("6cd4c8", 0.58)
const COLOR_HARVEST_TASK := Color("78b36d", 0.62)
const COLOR_HARVEST_TASK_ASSIGNED := Color("b7d66a", 0.64)
const COLOR_BARRACKS := Color("9d4f52")
const COLOR_WORKSHOP := Color("507dba")
const COLOR_LUMBERYARD := Color("4f9b5b")
const COLOR_MINE := Color("8b8f99")
const COLOR_WORKER_IDLE := Color("7bd88f")
const COLOR_WORKER_MOVING := Color("6fb7ff")
const COLOR_WORKER_WORKING := Color("f4d35e")
const COLOR_WORKER_HARVESTING := Color("b7d66a")
const COLOR_WORKER_DEPOSITING := Color("f3a35c")
const COLOR_WORKER_BLOCKED := Color("d95f5f")
const WORKER_SPEED_TILES_PER_SECOND := 4.0
const DIG_WORK_REQUIRED := 2.0
const SOURCE_GATHER_COOLDOWN := 5.0
# Extractors can work nearby permanent sources. Adjacency is optimal because it
# minimizes worker travel, but it is not required.
const EXTRACTOR_SOURCE_RANGE_TILES := 12
const RECRUIT_WORKER_COST := {
	ResourceManagerScript.ResourceType.WOOD: 20,
	ResourceManagerScript.ResourceType.ORE: 10,
	ResourceManagerScript.ResourceType.GOLD: 0,
}
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

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
var harvest_tasks: Array[RefCounted] = []
var buildings: Dictionary = {}
var harvest_buildings: Dictionary = {}
var source_cooldowns: Dictionary = {}
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

	print("Krebel's Keep Milestone 2G loaded")
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
	_update_resource_source_cooldowns(delta)
	_update_harvest_requests()
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
	elif event.is_action_pressed("recruit_worker"):
		_try_recruit_worker()
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
			_draw_resource_source(tile_position, tile_rect)

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

	for task in harvest_tasks:
		if task.status == HarvestTaskScript.TaskStatus.COMPLETE or task.status == HarvestTaskScript.TaskStatus.CANCELED:
			continue
		var task_rect := Rect2(Vector2(task.source_tile * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var task_color := COLOR_HARVEST_TASK_ASSIGNED if task.status == HarvestTaskScript.TaskStatus.ASSIGNED or task.status == HarvestTaskScript.TaskStatus.IN_PROGRESS else COLOR_HARVEST_TASK
		draw_rect(task_rect.grow(-8.0), task_color, false, 3.0)

	for tile_position in buildings:
		var building_rect := Rect2(Vector2(tile_position * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
		var building_type: int = int(buildings[tile_position])
		draw_rect(building_rect.grow(-3.0), _get_building_color(building_type), true)
		draw_rect(building_rect.grow(-3.0), Color("101318"), false, 2.0)

	for worker in workers:
		var worker_color := _get_worker_color(worker.state)
		draw_circle(worker.world_position, TILE_SIZE * 0.28, worker_color)
		draw_circle(worker.world_position, TILE_SIZE * 0.28, Color("0b0f14"), false, 2.0)


func _draw_resource_source(tile_position: Vector2i, tile_rect: Rect2) -> void:
	match dungeon.get_resource_node(tile_position):
		DungeonMapScript.ResourceNodeType.ORE:
			var center := tile_rect.get_center()
			var points := PackedVector2Array([
				center + Vector2(0, -10),
				center + Vector2(9, -3),
				center + Vector2(7, 8),
				center + Vector2(-8, 8),
				center + Vector2(-10, -2),
			])
			draw_colored_polygon(points, COLOR_ORE_SOURCE)
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), Color("1a1d22"), 2.0)
		DungeonMapScript.ResourceNodeType.ROOT:
			var center := tile_rect.get_center()
			draw_circle(center, TILE_SIZE * 0.24, COLOR_ROOT_SOURCE)
			draw_arc(center, TILE_SIZE * 0.22, -PI * 0.1, PI * 1.15, 12, Color("2f482b"), 2.0)
			draw_line(center + Vector2(-8, 6), center + Vector2(8, -7), Color("2f482b"), 2.0)


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

	debug_label.text = "Krebel's Keep Milestone 2G loaded\n%s\nResources: %s\nWorkers: %d\nRecruit: R (%s)\nTool: %s\n%s\nTasks: %s\n%s\n%s" % [
		access_message,
		resource_manager.get_debug_text(),
		workers.size(),
		_get_cost_debug_text(RECRUIT_WORKER_COST),
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
		_spawn_worker_at(spawn_tiles[index])


func _spawn_worker_at(tile_position: Vector2i) -> RefCounted:
	var worker := WorkerAgentScript.new()
	worker.id = workers.size() + 1
	worker.tile_position = tile_position
	worker.world_position = _tile_center(worker.tile_position)
	workers.append(worker)
	return worker


func _try_recruit_worker() -> void:
	if _get_completed_barracks_tiles().is_empty():
		last_message = "Recruit failed: completed BarracksPlaceholder required"
		print(last_message)
		_update_debug_label()
		return

	var spawn_tile := _find_worker_recruit_spawn_tile()
	if not dungeon.is_in_bounds(spawn_tile):
		last_message = "Recruit failed: no valid reachable Floor spawn tile"
		print(last_message)
		_update_debug_label()
		return

	if not resource_manager.spend(RECRUIT_WORKER_COST):
		last_message = "Recruit failed: insufficient resources (%s)" % _get_cost_debug_text(RECRUIT_WORKER_COST)
		print(last_message)
		_update_debug_label()
		return

	var worker := _spawn_worker_at(spawn_tile)
	last_message = "Recruited worker %d at %s for %s" % [
		worker.id,
		str(spawn_tile),
		_get_cost_debug_text(RECRUIT_WORKER_COST),
	]
	print(last_message)
	_update_debug_label()
	queue_redraw()


func _update_workers(delta: float) -> void:
	for worker in workers:
		match worker.state:
			WorkerAgentScript.WorkerState.IDLE:
				_assign_next_task(worker)
			WorkerAgentScript.WorkerState.MOVING_TO_TASK:
				_update_worker_movement(worker, delta)
			WorkerAgentScript.WorkerState.WORKING:
				_update_worker_work(worker, delta)
			WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
				_update_worker_movement(worker, delta)
			WorkerAgentScript.WorkerState.GATHERING:
				_update_worker_gathering(worker, delta)
			WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING:
				_update_worker_movement(worker, delta)
			WorkerAgentScript.WorkerState.DEPOSITING:
				_update_worker_depositing(worker, delta)
			WorkerAgentScript.WorkerState.BLOCKED:
				_assign_next_task(worker)


func _assign_next_task(worker: RefCounted) -> void:
	for task in _get_assignable_tasks():
		if not _is_waiting_for_assignment(task):
			continue

		var worker_on_construction_target := _get_worker_at_construction_target(task)
		if worker_on_construction_target != null and worker_on_construction_target.id != worker.id:
			continue

		var assignment := _find_reachable_interaction(worker.tile_position, task.target_tile)
		if not assignment.reachable:
			continue

		task.interaction_tile = assignment.interaction_tile
		task.status = DigTaskScript.TaskStatus.ASSIGNED
		task.assigned_worker_id = worker.id
		worker.task_id = task.id
		worker.path = assignment.path
		if _is_harvest_task(task):
			worker.state = WorkerAgentScript.WorkerState.GATHERING if worker.path.is_empty() else WorkerAgentScript.WorkerState.MOVING_TO_SOURCE
		else:
			worker.state = WorkerAgentScript.WorkerState.WORKING if worker.path.is_empty() else WorkerAgentScript.WorkerState.MOVING_TO_TASK
		last_message = "%s task %d assigned to worker %d" % [_get_task_action_name(task), task.id, worker.id]
		return


func _update_worker_movement(worker: RefCounted, delta: float) -> void:
	if worker.path.is_empty():
		if worker.state == WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
			worker.state = WorkerAgentScript.WorkerState.GATHERING
		elif worker.state == WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING:
			worker.state = WorkerAgentScript.WorkerState.DEPOSITING
		else:
			worker.state = WorkerAgentScript.WorkerState.WORKING
		return

	var next_tile: Vector2i = worker.path[0]
	if not pathfinder.is_passable_tile(next_tile):
		var task := _get_task_by_id(worker.task_id)
		if task != null and (task.status == DigTaskScript.TaskStatus.ASSIGNED or _is_harvest_task(task)):
			_clear_task_assignment(task)

		_clear_worker_task(worker)
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
			if worker.state == WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
				worker.state = WorkerAgentScript.WorkerState.GATHERING
			elif worker.state == WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING:
				worker.state = WorkerAgentScript.WorkerState.DEPOSITING
			else:
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
		if _has_worker_at(task.target_tile):
			if not task.completion_waiting_for_clear:
				task.completion_waiting_for_clear = true
				last_message = "Build task %d waiting for worker to clear %s" % [task.id, str(task.target_tile)]
				print(last_message)
				_update_debug_label()
				queue_redraw()
			return

		task.completion_waiting_for_clear = false
		buildings[task.target_tile] = task.building_type
		_register_production_building(task.target_tile, task.building_type)
	else:
		dungeon.set_tile(task.target_tile, DungeonMapScript.TileType.FLOOR)

	task.status = DigTaskScript.TaskStatus.COMPLETE
	worker.task_id = -1
	worker.state = WorkerAgentScript.WorkerState.IDLE
	var access_validator := DungeonAccessValidatorScript.new()
	access_valid = access_validator.is_overlord_room_connected(dungeon, _get_access_blocked_tiles())
	last_message = "%s task %d complete at %s" % [_get_task_action_name(task), task.id, str(task.target_tile)]
	print("%s. Access valid: %s" % [last_message, str(access_valid)])
	_update_pathfinder_blocked_tiles()
	_reconsider_moving_worker_paths()
	queue_redraw()


func _update_worker_gathering(worker: RefCounted, delta: float) -> void:
	var task := _get_task_by_id(worker.task_id)
	if task == null or not _is_harvest_task(task):
		_clear_worker_task(worker)
		return

	if task.status == HarvestTaskScript.TaskStatus.ASSIGNED:
		task.status = HarvestTaskScript.TaskStatus.IN_PROGRESS
		last_message = "Harvest task %d gathering at %s" % [task.id, str(task.source_tile)]
		print(last_message)

	task.gather_done += delta
	if task.gather_done < task.gather_required:
		return

	task.carrying = true
	worker.carried_resource = task.resource_type
	worker.carried_amount = task.resource_amount
	source_cooldowns[task.source_tile] = SOURCE_GATHER_COOLDOWN
	var assignment := _find_reachable_interaction(worker.tile_position, task.building_tile)
	if not assignment.reachable:
		_clear_task_assignment(task)
		_clear_worker_task(worker)
		last_message = "Harvest task %d waiting for building access" % task.id
		print(last_message)
		queue_redraw()
		return

	task.building_interaction_tile = assignment.interaction_tile
	worker.path = assignment.path
	worker.state = WorkerAgentScript.WorkerState.DEPOSITING if worker.path.is_empty() else WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING
	last_message = "Worker %d returning +%d %s to %s" % [
		worker.id,
		task.resource_amount,
		_get_resource_name(task.resource_type),
		str(task.building_tile),
	]
	print(last_message)
	queue_redraw()


func _update_worker_depositing(worker: RefCounted, delta: float) -> void:
	var task := _get_task_by_id(worker.task_id)
	if task == null or not _is_harvest_task(task):
		_clear_worker_task(worker)
		return

	task.deposit_done += delta
	if task.deposit_done < task.deposit_required:
		if task.deposit_done == delta:
			last_message = "Harvest task %d depositing at %s" % [task.id, str(task.building_tile)]
		return

	resource_manager.add(task.resource_type, task.resource_amount)
	task.status = HarvestTaskScript.TaskStatus.COMPLETE
	last_message = "Harvest task %d deposited +%d %s" % [
		task.id,
		task.resource_amount,
		_get_resource_name(task.resource_type),
	]
	print(last_message)
	_clear_worker_task(worker)
	_update_debug_label()
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

	var source_tile := _find_best_reachable_resource_source(tile_position, _get_required_source_type(building_type))
	if not dungeon.is_in_bounds(source_tile):
		last_message = "%s complete but no reachable source found" % definition.short_name
		print(last_message)
		return

	harvest_buildings[tile_position] = {
		"building_type": building_type,
		"source_tile": source_tile,
		"resource_type": definition.production_resource,
		"resource_amount": definition.production_amount,
		"idle_message": "",
	}
	if not source_cooldowns.has(source_tile):
		source_cooldowns[source_tile] = 0.0
	last_message = "%s ready to harvest from %s" % [definition.short_name, str(source_tile)]


func _update_resource_source_cooldowns(delta: float) -> void:
	for source_tile in source_cooldowns.keys():
		source_cooldowns[source_tile] = maxf(0.0, float(source_cooldowns[source_tile]) - delta)


func _update_harvest_requests() -> void:
	for building_tile in harvest_buildings.keys():
		if not buildings.has(building_tile):
			harvest_buildings.erase(building_tile)
			continue
		if _has_active_harvest_task_for_building(building_tile):
			continue

		var harvest_data: Dictionary = harvest_buildings[building_tile]
		var source_tile := _find_best_reachable_resource_source(building_tile, _get_required_source_type(int(harvest_data["building_type"])))
		if not dungeon.is_in_bounds(source_tile):
			_report_extractor_idle(building_tile, harvest_data)
			continue
		harvest_data["source_tile"] = source_tile
		harvest_data["idle_message"] = ""
		harvest_buildings[building_tile] = harvest_data
		if _has_active_harvest_task_for_source(source_tile):
			continue
		if float(source_cooldowns.get(source_tile, 0.0)) > 0.0:
			continue

		var task := HarvestTaskScript.new()
		task.id = next_task_id
		task.target_tile = source_tile
		task.source_tile = source_tile
		task.building_tile = building_tile
		task.created_order = next_task_order
		task.building_type = harvest_data["building_type"]
		task.resource_type = harvest_data["resource_type"]
		task.resource_amount = int(harvest_data["resource_amount"])
		next_task_id += 1
		next_task_order += 1
		harvest_tasks.append(task)
		last_message = "Queued harvest task %d at %s" % [task.id, str(source_tile)]
		print(last_message)
		queue_redraw()


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
	if dungeon.is_overlord_room(tile_position):
		return "Invalid placement: Overlord room is reserved"
	if tile_type != DungeonMapScript.TileType.FLOOR:
		return "Invalid build: target must be Floor"
	if _has_active_dig_task(tile_position):
		return "Invalid build: tile has an active dig task"
	if _has_active_construction_task(tile_position):
		return "Invalid build: tile already has a construction task"
	if _has_building_at(tile_position):
		return "Invalid build: tile already has a building"
	if dungeon.get_resource_node(tile_position) != DungeonMapScript.ResourceNodeType.NONE:
		return "Invalid placement: source tile must remain open"
	if definition.building_type == BuildingDefinitionScript.BuildingType.MINE_PLACEHOLDER and not _has_reachable_resource_source(tile_position, DungeonMapScript.ResourceNodeType.ORE):
		return "Invalid placement: Mine requires reachable Ore source"
	if definition.building_type == BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER and not _has_reachable_resource_source(tile_position, DungeonMapScript.ResourceNodeType.ROOT):
		return "Invalid placement: Lumberyard requires reachable Root source"
	if not _would_preserve_outside_access(tile_position):
		return "Invalid placement: would block outside access"
	if not _would_preserve_resource_source_access(tile_position):
		return "Invalid placement: would block source access"
	if not resource_manager.can_afford(definition.cost):
		return "Invalid build: insufficient resources for %s" % definition.display_name

	return ""


func _has_reachable_resource_source(tile_position: Vector2i, resource_node_type: int) -> bool:
	return dungeon.is_in_bounds(_find_best_reachable_resource_source(tile_position, resource_node_type, tile_position))


func _find_best_reachable_resource_source(tile_position: Vector2i, resource_node_type: int, extra_blocked_tile: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if resource_node_type == DungeonMapScript.ResourceNodeType.NONE:
		return Vector2i(-1, -1)

	var source_pathfinder := CardinalPathfinderScript.new(dungeon)
	source_pathfinder.blocked_tiles = _get_access_blocked_tiles(extra_blocked_tile)
	var building_interaction_tiles: Array[Vector2i] = source_pathfinder.get_cardinal_interaction_tiles(tile_position)
	if building_interaction_tiles.is_empty():
		return Vector2i(-1, -1)

	var best_source := Vector2i(-1, -1)
	var best_distance := EXTRACTOR_SOURCE_RANGE_TILES + 1
	for y in range(dungeon.size.y):
		for x in range(dungeon.size.x):
			var source_tile := Vector2i(x, y)
			if not dungeon.has_resource_node(source_tile, resource_node_type):
				continue

			var distance := _get_shortest_interaction_path_distance(source_pathfinder, building_interaction_tiles, source_tile, best_distance)
			if distance >= 0 and distance < best_distance:
				best_distance = distance
				best_source = source_tile

	return best_source


func _get_shortest_interaction_path_distance(source_pathfinder: RefCounted, start_tiles: Array[Vector2i], source_tile: Vector2i, best_distance: int) -> int:
	var source_interaction_tiles: Array[Vector2i] = source_pathfinder.get_cardinal_interaction_tiles(source_tile)
	if source_interaction_tiles.is_empty():
		return -1

	var shortest_distance := best_distance
	for start_tile in start_tiles:
		for source_interaction_tile in source_interaction_tiles:
			var distance := 0
			if start_tile != source_interaction_tile:
				var path: Array[Vector2i] = source_pathfinder.find_cardinal_path(start_tile, source_interaction_tile)
				if path.is_empty():
					continue
				distance = path.size()
			if distance <= EXTRACTOR_SOURCE_RANGE_TILES and distance < shortest_distance:
				shortest_distance = distance

	if shortest_distance == best_distance:
		return -1

	return shortest_distance


func _get_required_source_type(building_type: int) -> int:
	match building_type:
		BuildingDefinitionScript.BuildingType.MINE_PLACEHOLDER:
			return DungeonMapScript.ResourceNodeType.ORE
		BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER:
			return DungeonMapScript.ResourceNodeType.ROOT
		_:
			return DungeonMapScript.ResourceNodeType.NONE


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


func _has_active_harvest_task_for_building(tile_position: Vector2i) -> bool:
	for task in harvest_tasks:
		if task.building_tile != tile_position:
			continue
		if _is_finished_task(task):
			continue
		return true

	return false


func _has_active_harvest_task_for_source(tile_position: Vector2i) -> bool:
	for task in harvest_tasks:
		if task.source_tile != tile_position:
			continue
		if _is_finished_task(task):
			continue
		return true

	return false


func _report_extractor_idle(building_tile: Vector2i, harvest_data: Dictionary) -> void:
	var idle_message := _get_extractor_idle_message(int(harvest_data["building_type"]))
	if str(harvest_data.get("idle_message", "")) == idle_message:
		return

	harvest_data["idle_message"] = idle_message
	harvest_buildings[building_tile] = harvest_data
	last_message = idle_message
	print(last_message)


func _get_extractor_idle_message(building_type: int) -> String:
	match building_type:
		BuildingDefinitionScript.BuildingType.MINE_PLACEHOLDER:
			return "Mine idle: no reachable Ore source"
		BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER:
			return "Lumberyard idle: no reachable Root source"
		_:
			return "Extractor idle: no reachable source"


func _get_completed_barracks_tiles() -> Array[Vector2i]:
	var barracks_tiles: Array[Vector2i] = []
	for tile_position in buildings:
		if int(buildings[tile_position]) == BuildingDefinitionScript.BuildingType.BARRACKS_PLACEHOLDER:
			barracks_tiles.append(tile_position)

	return barracks_tiles


func _find_worker_recruit_spawn_tile() -> Vector2i:
	var barracks_tiles := _get_completed_barracks_tiles()
	if barracks_tiles.is_empty():
		return Vector2i(-1, -1)

	var spawn_pathfinder := CardinalPathfinderScript.new(dungeon)
	spawn_pathfinder.blocked_tiles = _get_access_blocked_tiles()
	var best_spawn_tile := Vector2i(-1, -1)
	var best_distance: int = dungeon.size.x + dungeon.size.y + 1
	for barracks_tile in barracks_tiles:
		var barracks_interaction_tiles: Array[Vector2i] = spawn_pathfinder.get_cardinal_interaction_tiles(barracks_tile)
		for y in range(dungeon.size.y):
			for x in range(dungeon.size.x):
				var candidate := Vector2i(x, y)
				var distance: int = abs(candidate.x - barracks_tile.x) + abs(candidate.y - barracks_tile.y)
				if distance >= best_distance:
					continue
				if not _is_valid_worker_recruit_spawn_tile(candidate):
					continue
				if not _can_reach_spawn_tile(spawn_pathfinder, barracks_interaction_tiles, candidate):
					continue

				best_spawn_tile = candidate
				best_distance = distance

	return best_spawn_tile


func _is_valid_worker_recruit_spawn_tile(tile_position: Vector2i) -> bool:
	if not dungeon.is_in_bounds(tile_position):
		return false
	if dungeon.is_overlord_room(tile_position):
		return false
	if dungeon.get_tile(tile_position) != DungeonMapScript.TileType.FLOOR:
		return false
	if dungeon.get_resource_node(tile_position) != DungeonMapScript.ResourceNodeType.NONE:
		return false
	if _has_building_at(tile_position):
		return false
	if _has_active_construction_task(tile_position):
		return false
	if _has_active_dig_task(tile_position):
		return false

	return true


func _can_reach_spawn_tile(spawn_pathfinder: RefCounted, start_tiles: Array[Vector2i], spawn_tile: Vector2i) -> bool:
	for start_tile in start_tiles:
		if start_tile == spawn_tile:
			return true
		if not spawn_pathfinder.find_cardinal_path(start_tile, spawn_tile).is_empty():
			return true

	return false


func _would_preserve_outside_access(proposed_blocked_tile: Vector2i) -> bool:
	var access_validator := DungeonAccessValidatorScript.new()
	return access_validator.is_overlord_room_connected(dungeon, _get_access_blocked_tiles(proposed_blocked_tile))


func _would_preserve_resource_source_access(proposed_blocked_tile: Vector2i) -> bool:
	if not _is_cardinal_neighbor_of_resource_source(proposed_blocked_tile):
		return true

	var current_blocked_tiles := _get_access_blocked_tiles()
	var proposed_blocked_tiles := _get_access_blocked_tiles(proposed_blocked_tile)
	for y in range(dungeon.size.y):
		for x in range(dungeon.size.x):
			var source_tile := Vector2i(x, y)
			if dungeon.get_resource_node(source_tile) == DungeonMapScript.ResourceNodeType.NONE:
				continue
			if _count_open_resource_interaction_tiles(source_tile, current_blocked_tiles) > 0 and _count_open_resource_interaction_tiles(source_tile, proposed_blocked_tiles) == 0:
				return false

	return true


func _is_cardinal_neighbor_of_resource_source(tile_position: Vector2i) -> bool:
	for direction in CARDINAL_DIRECTIONS:
		if dungeon.is_in_bounds(tile_position + direction) and dungeon.get_resource_node(tile_position + direction) != DungeonMapScript.ResourceNodeType.NONE:
			return true

	return false


func _count_open_resource_interaction_tiles(source_tile: Vector2i, blocked_tiles: Dictionary) -> int:
	var open_tiles := 0
	for direction in CARDINAL_DIRECTIONS:
		var interaction_tile := source_tile + direction
		if _is_accessible_floor_tile(interaction_tile, blocked_tiles):
			open_tiles += 1

	return open_tiles


func _is_accessible_floor_tile(tile_position: Vector2i, blocked_tiles: Dictionary) -> bool:
	if not dungeon.is_in_bounds(tile_position):
		return false
	if blocked_tiles.has(tile_position):
		return false

	var tile_type: int = dungeon.get_tile(tile_position)
	return tile_type == DungeonMapScript.TileType.FLOOR or tile_type == DungeonMapScript.TileType.ENTRANCE


func _has_worker_at(tile_position: Vector2i) -> bool:
	return _get_worker_at(tile_position) != null


func _get_worker_at(tile_position: Vector2i) -> RefCounted:
	for worker in workers:
		if worker.tile_position == tile_position:
			return worker

	return null


func _get_worker_at_construction_target(task: RefCounted) -> RefCounted:
	if not _is_construction_task(task):
		return null

	return _get_worker_at(task.target_tile)


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
			assigned_worker.carried_resource = -1
			assigned_worker.carried_amount = 0
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


func _clear_task_assignment(task: RefCounted) -> void:
	task.status = DigTaskScript.TaskStatus.PENDING
	task.assigned_worker_id = -1
	task.interaction_tile = Vector2i(-1, -1)
	if _is_harvest_task(task):
		task.building_interaction_tile = Vector2i(-1, -1)
		task.gather_done = 0.0
		task.deposit_done = 0.0
		task.carrying = false


func _clear_worker_task(worker: RefCounted) -> void:
	worker.task_id = -1
	worker.path.clear()
	worker.world_position = _tile_center(worker.tile_position)
	worker.carried_resource = -1
	worker.carried_amount = 0
	worker.state = WorkerAgentScript.WorkerState.IDLE


func _get_assignable_tasks() -> Array[RefCounted]:
	var tasks: Array[RefCounted] = []
	for task in dig_tasks:
		if _is_finished_task(task):
			continue
		tasks.append(task)
	for task in construction_tasks:
		if _is_finished_task(task):
			continue
		tasks.append(task)
	for task in harvest_tasks:
		if _is_finished_task(task):
			continue
		tasks.append(task)

	tasks.sort_custom(func(a: RefCounted, b: RefCounted) -> bool:
		if _get_task_priority(a) != _get_task_priority(b):
			return _get_task_priority(a) < _get_task_priority(b)
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
	for task in harvest_tasks:
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
		if worker.state != WorkerAgentScript.WorkerState.MOVING_TO_TASK and worker.state != WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
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
		WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
			return COLOR_WORKER_MOVING
		WorkerAgentScript.WorkerState.GATHERING:
			return COLOR_WORKER_HARVESTING
		WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING:
			return COLOR_WORKER_MOVING
		WorkerAgentScript.WorkerState.DEPOSITING:
			return COLOR_WORKER_DEPOSITING
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
		WorkerAgentScript.WorkerState.MOVING_TO_SOURCE:
			return "MovingToSource"
		WorkerAgentScript.WorkerState.GATHERING:
			return "Gathering"
		WorkerAgentScript.WorkerState.RETURNING_TO_BUILDING:
			return "Returning"
		WorkerAgentScript.WorkerState.DEPOSITING:
			return "Depositing"
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
	if _is_harvest_task(task):
		return "Harvest"

	return "Dig"


func _is_construction_task(task: RefCounted) -> bool:
	return task != null and task.get_script() == ConstructionTaskScript


func _is_harvest_task(task: RefCounted) -> bool:
	return task != null and task.get_script() == HarvestTaskScript


func _is_finished_task(task: RefCounted) -> bool:
	return task.status == DigTaskScript.TaskStatus.COMPLETE or task.status == DigTaskScript.TaskStatus.CANCELED


func _get_task_priority(task: RefCounted) -> int:
	if _is_harvest_task(task):
		return 1

	return 0


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


func _get_cost_debug_text(cost: Dictionary) -> String:
	return "%d Wood, %d Ore, %d Gold" % [
		int(cost.get(ResourceManagerScript.ResourceType.WOOD, 0)),
		int(cost.get(ResourceManagerScript.ResourceType.ORE, 0)),
		int(cost.get(ResourceManagerScript.ResourceType.GOLD, 0)),
	]


func _update_pathfinder_blocked_tiles() -> void:
	pathfinder.blocked_tiles = _get_access_blocked_tiles()


func _get_access_blocked_tiles(extra_blocked_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var blocked_tiles: Dictionary = {}
	for tile_position in buildings:
		blocked_tiles[tile_position] = true
	for task in construction_tasks:
		if task.status == ConstructionTaskScript.TaskStatus.COMPLETE or task.status == ConstructionTaskScript.TaskStatus.CANCELED:
			continue
		blocked_tiles[task.target_tile] = true
	if dungeon != null and dungeon.is_in_bounds(extra_blocked_tile):
		blocked_tiles[extra_blocked_tile] = true

	return blocked_tiles
