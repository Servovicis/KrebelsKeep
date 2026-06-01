# Krebel's Keep

Krebel's Keep is a 2D top-down tile-based dungeon builder/defense sim prototype.

## Milestone 1A Dungeon Model Bootstrap

- Godot version: 4.6.3
- Language: GDScript
- MVP platform target order: Linux, SteamOS, Windows
- Main scene: `res://scenes/main/Main.tscn`

## Open And Run

1. Open Godot 4.6.3.
2. Import/open this project folder.
3. Press Run Project or open and run `scenes/main/Main.tscn`.

## Validation

Milestone 1A is valid when:

- The project opens in Godot 4.6.3.
- The main scene runs.
- A fixed 128x128 dungeon grid is visible.
- Solid rock, floor, boundary wall, entrance, and Overlord room tiles are visually distinct.
- The entrance is near the south-center edge and connects by cardinal floor path to the north-center 5x5 Overlord room.
- The debug label says `Krebel's Keep - Milestone 1A loaded` and shows the hovered tile coordinate/type.
- Camera movement works with WASD or arrow keys.
- Zoom works with mouse wheel or `+` and `-`.
- Startup output reports `Access valid: Overlord room connected to outside`.
- No workers, digging, resources, buildings, doors, traps, adventurers, combat, waves, tech tree, or save/load behavior exists yet.

Milestone 1B will implement worker digging on top of this dungeon model.
