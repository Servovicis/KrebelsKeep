class_name WorkerAgent
extends RefCounted

enum WorkerState {
	IDLE,
	MOVING_TO_TASK,
	WORKING,
	MOVING_TO_SOURCE,
	GATHERING,
	RETURNING_TO_BUILDING,
	DEPOSITING,
	BLOCKED,
}

var id := 0
var tile_position := Vector2i.ZERO
var world_position := Vector2.ZERO
var state: WorkerState = WorkerState.IDLE
var path: Array[Vector2i] = []
var task_id := -1
var carried_resource := -1
var carried_amount := 0
