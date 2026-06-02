class_name ResourceManager
extends RefCounted

enum ResourceType {
	WOOD,
	ORE,
	GOLD,
}

var resources: Dictionary = {
	ResourceType.WOOD: 100,
	ResourceType.ORE: 60,
	ResourceType.GOLD: 0,
}


func can_afford(cost: Dictionary) -> bool:
	for resource_type in cost:
		if get_amount(resource_type) < int(cost[resource_type]):
			return false

	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false

	for resource_type in cost:
		resources[resource_type] = get_amount(resource_type) - int(cost[resource_type])

	return true


func get_amount(resource_type: ResourceType) -> int:
	return int(resources.get(resource_type, 0))


func get_debug_text() -> String:
	return "Wood %d, Ore %d, Gold %d" % [
		get_amount(ResourceType.WOOD),
		get_amount(ResourceType.ORE),
		get_amount(ResourceType.GOLD),
	]
