class_name ConstructionTask
extends RefCounted

const BuildingDefinitionScript := preload("res://scripts/core/building_definition.gd")

enum TaskStatus {
	PENDING,
	ASSIGNED,
	IN_PROGRESS,
	COMPLETE,
	BLOCKED,
	CANCELED,
}

var id := 0
var target_tile := Vector2i.ZERO
var interaction_tile := Vector2i(-1, -1)
var status: TaskStatus = TaskStatus.PENDING
var assigned_worker_id := -1
var work_required := 3.0
var work_done := 0.0
var created_order := 0
var building_type: BuildingDefinitionScript.BuildingType = BuildingDefinitionScript.BuildingType.BARRACKS_PLACEHOLDER
