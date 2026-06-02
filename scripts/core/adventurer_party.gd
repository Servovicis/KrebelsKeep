class_name AdventurerParty
extends RefCounted

enum PartyState {
	PATHING,
	MOVING,
	REACHED_TARGET,
	BLOCKED,
}

var id := 0
var tile_position := Vector2i.ZERO
var world_position := Vector2.ZERO
var target_tile := Vector2i.ZERO
var path: Array[Vector2i] = []
var state: PartyState = PartyState.PATHING
var reached_target := false
var breached_overlord_room := false
