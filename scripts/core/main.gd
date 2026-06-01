extends Node2D

const TILE_SIZE := 32
const MAP_TILES := Vector2i(128, 128)
const CAMERA_SPEED := 600.0
const ZOOM_STEP := 0.1
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0

@onready var camera: Camera2D = $Camera2D
@onready var debug_label: Label = $CanvasLayer/DebugLabel

var debug_visible := true


func _ready() -> void:
	print("Krebel's Keep Milestone 0 loaded")
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_camera(ZOOM_STEP)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_camera(-ZOOM_STEP)
	elif event.is_action_pressed("toggle_debug"):
		debug_visible = !debug_visible
		debug_label.visible = debug_visible


func _draw() -> void:
	var map_size := Vector2(MAP_TILES * TILE_SIZE)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("20242a"), true)

	for x in range(MAP_TILES.x + 1):
		var x_pos := x * TILE_SIZE
		var color := Color("3b4652") if x % 8 == 0 else Color("2b333c")
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, map_size.y), color, 1.0)

	for y in range(MAP_TILES.y + 1):
		var y_pos := y * TILE_SIZE
		var color := Color("3b4652") if y % 8 == 0 else Color("2b333c")
		draw_line(Vector2(0, y_pos), Vector2(map_size.x, y_pos), color, 1.0)

	_draw_start_markers()


func _zoom_camera(amount: float) -> void:
	var next_zoom := clamp(camera.zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)


func _draw_start_markers() -> void:
	var start_area := Rect2(Vector2(61, 61) * TILE_SIZE, Vector2(5, 5) * TILE_SIZE)
	var entrance := Rect2(Vector2(62, 123) * TILE_SIZE, Vector2(4, 2) * TILE_SIZE)
	var overlord_room := Rect2(Vector2(60, 10) * TILE_SIZE, Vector2(8, 6) * TILE_SIZE)

	draw_rect(start_area, Color("5f7f57", 0.45), true)
	draw_rect(entrance, Color("7f6a45", 0.45), true)
	draw_rect(overlord_room, Color("66517a", 0.45), true)
