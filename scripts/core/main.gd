extends Node2D

const DungeonAccessValidatorScript := preload("res://scripts/core/dungeon_access_validator.gd")
const DungeonMapScript := preload("res://scripts/core/dungeon_map.gd")

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

@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $CanvasLayer/DebugLabel

var dungeon: RefCounted
var access_valid := false
var debug_visible := true


func _ready() -> void:
	dungeon = DungeonMapScript.new()
	dungeon.initialize_fixed_mvp()
	var access_validator := DungeonAccessValidatorScript.new()
	access_valid = access_validator.is_overlord_room_connected(dungeon)
	var access_message := "Access valid: Overlord room connected to outside" if access_valid else "Access invalid: Overlord room disconnected"

	print("Krebel's Keep Milestone 1A loaded")
	print(access_message)
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

	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_camera(ZOOM_STEP)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_camera(-ZOOM_STEP)
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

	var mouse_tile := Vector2i(floori(get_global_mouse_position().x / TILE_SIZE), floori(get_global_mouse_position().y / TILE_SIZE))
	var access_message := "Access valid: Overlord room connected to outside" if access_valid else "Access invalid: Overlord room disconnected"
	debug_label.text = "Krebel's Keep - Milestone 1A loaded\n%s\nTile %s: %s" % [
		access_message,
		str(mouse_tile),
		dungeon.get_tile_display_name(mouse_tile),
	]
