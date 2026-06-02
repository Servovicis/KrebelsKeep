class_name BuildingDefinition
extends RefCounted

const ResourceManagerScript := preload("res://scripts/core/resource_manager.gd")

enum BuildingType {
	BARRACKS_PLACEHOLDER,
	WORKSHOP_PLACEHOLDER,
	LUMBERYARD_PLACEHOLDER,
	MINE_PLACEHOLDER,
	DOOR_PLACEHOLDER,
	TRAP_PLACEHOLDER,
}

var building_type: BuildingType = BuildingType.BARRACKS_PLACEHOLDER
var display_name := ""
var short_name := ""
var cost: Dictionary = {}
var build_time := 3.0
var produces_resource := false
var production_resource: ResourceManagerScript.ResourceType = ResourceManagerScript.ResourceType.WOOD
var production_amount := 0
var production_interval := 0.0
var blocks_movement := true


func configure(type: BuildingType) -> void:
	building_type = type
	build_time = 3.0
	produces_resource = false
	production_resource = ResourceManagerScript.ResourceType.WOOD
	production_amount = 0
	production_interval = 0.0
	blocks_movement = true

	match type:
		BuildingType.BARRACKS_PLACEHOLDER:
			display_name = "BarracksPlaceholder"
			short_name = "Barracks"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 40,
				ResourceManagerScript.ResourceType.ORE: 20,
			}
		BuildingType.WORKSHOP_PLACEHOLDER:
			display_name = "WorkshopPlaceholder"
			short_name = "Workshop"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 30,
				ResourceManagerScript.ResourceType.ORE: 30,
			}
		BuildingType.LUMBERYARD_PLACEHOLDER:
			display_name = "LumberyardPlaceholder"
			short_name = "Lumberyard"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 20,
				ResourceManagerScript.ResourceType.ORE: 0,
				ResourceManagerScript.ResourceType.GOLD: 0,
			}
			produces_resource = true
			production_resource = ResourceManagerScript.ResourceType.WOOD
			production_amount = 1
			production_interval = 5.0
		BuildingType.MINE_PLACEHOLDER:
			display_name = "MinePlaceholder"
			short_name = "Mine"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 20,
				ResourceManagerScript.ResourceType.ORE: 10,
				ResourceManagerScript.ResourceType.GOLD: 0,
			}
			produces_resource = true
			production_resource = ResourceManagerScript.ResourceType.ORE
			production_amount = 1
			production_interval = 5.0
		BuildingType.DOOR_PLACEHOLDER:
			display_name = "DoorPlaceholder"
			short_name = "Door"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 15,
				ResourceManagerScript.ResourceType.ORE: 5,
				ResourceManagerScript.ResourceType.GOLD: 0,
			}
			build_time = 2.0
			blocks_movement = false
		BuildingType.TRAP_PLACEHOLDER:
			display_name = "TrapPlaceholder"
			short_name = "Trap"
			cost = {
				ResourceManagerScript.ResourceType.WOOD: 10,
				ResourceManagerScript.ResourceType.ORE: 10,
				ResourceManagerScript.ResourceType.GOLD: 0,
			}
			build_time = 2.0
			blocks_movement = false


static func get_type_name(type: BuildingType) -> String:
	match type:
		BuildingType.BARRACKS_PLACEHOLDER:
			return "BarracksPlaceholder"
		BuildingType.WORKSHOP_PLACEHOLDER:
			return "WorkshopPlaceholder"
		BuildingType.LUMBERYARD_PLACEHOLDER:
			return "LumberyardPlaceholder"
		BuildingType.MINE_PLACEHOLDER:
			return "MinePlaceholder"
		BuildingType.DOOR_PLACEHOLDER:
			return "DoorPlaceholder"
		BuildingType.TRAP_PLACEHOLDER:
			return "TrapPlaceholder"
		_:
			return "UnknownBuilding"
