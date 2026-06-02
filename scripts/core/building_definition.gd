class_name BuildingDefinition
extends RefCounted

const ResourceManagerScript := preload("res://scripts/core/resource_manager.gd")

enum BuildingType {
	BARRACKS_PLACEHOLDER,
	WORKSHOP_PLACEHOLDER,
}

var building_type: BuildingType = BuildingType.BARRACKS_PLACEHOLDER
var display_name := ""
var short_name := ""
var cost: Dictionary = {}
var build_time := 3.0


func configure(type: BuildingType) -> void:
	building_type = type
	build_time = 3.0

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


static func get_type_name(type: BuildingType) -> String:
	match type:
		BuildingType.BARRACKS_PLACEHOLDER:
			return "BarracksPlaceholder"
		BuildingType.WORKSHOP_PLACEHOLDER:
			return "WorkshopPlaceholder"
		_:
			return "UnknownBuilding"
