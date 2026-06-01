class_name DigTask
extends RefCounted

enum TaskType {
	DIG_TILE,
}

enum TaskStatus {
	PENDING,
	ASSIGNED,
	IN_PROGRESS,
	COMPLETE,
	BLOCKED,
	CANCELED,
}

var id := 0
var task_type: TaskType = TaskType.DIG_TILE
var target_tile := Vector2i.ZERO
var interaction_tile := Vector2i(-1, -1)
var status: TaskStatus = TaskStatus.PENDING
var assigned_worker_id := -1
var work_required := 2.0
var work_done := 0.0
var created_order := 0
