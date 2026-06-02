class_name HarvestTask
extends RefCounted

const BuildingDefinitionScript := preload("res://scripts/core/building_definition.gd")
const ResourceManagerScript := preload("res://scripts/core/resource_manager.gd")

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
var building_tile := Vector2i.ZERO
var building_interaction_tile := Vector2i(-1, -1)
var source_tile := Vector2i.ZERO
var status: TaskStatus = TaskStatus.PENDING
var assigned_worker_id := -1
var gather_required := 2.0
var gather_done := 0.0
var gather_retry_wait := 0.0
var deposit_required := 0.5
var deposit_done := 0.0
var created_order := 0
var building_type: BuildingDefinitionScript.BuildingType = BuildingDefinitionScript.BuildingType.LUMBERYARD_PLACEHOLDER
var resource_type: ResourceManagerScript.ResourceType = ResourceManagerScript.ResourceType.WOOD
var resource_amount := 1
var carrying := false
var source_consumed := false
