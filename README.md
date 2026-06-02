# Krebel's Keep

Krebel's Keep is a 2D top-down tile-based dungeon builder/defense sim prototype.

## Milestone 2F Extractor Range And Source Access

- Godot version: 4.6.3
- Language: GDScript
- MVP platform target order: Linux, SteamOS, Windows
- Main scene: `res://scenes/main/Main.tscn`

## Open And Run

1. Open Godot 4.6.3.
2. Import/open this project folder.
3. Press Run Project or open and run `scenes/main/Main.tscn`.

## Resource Extraction Prototype

Milestone 2F keeps the worker trip prototype and lets Mine/Lumberyard extractors
use reachable nearby permanent sources instead of requiring direct adjacency.
Completed extractor buildings request harvest work from the shortest reachable
matching source within a small cardinal path range. A worker travels to the
source, gathers briefly, returns to the building, and deposits Wood or Ore into
the global resources.

Ore and Root sources are not finite deposits. They are permanent dungeon
features with future capped available output and regeneration rates. Root
sources regrow partly through dungeon magic, and ore-rich sources replenish as
magic flowing through the dungeon slowly replaces ore. Sources are not intended
to be permanently depleted.

Current fixed test sources are exposed on floor for easy validation. Later,
players should usually dig to reach or expose resource sources instead of
starting with every source pre-dug.

Sources currently use a minimal cooldown-style availability gate. They are not
deleted, consumed, or permanently depleted.

Adjacent extractor placement is still optimal because worker travel is shorter,
but it is not mandatory. If buildings or construction block access to a matching
source, production stalls with debug feedback until access is restored. Worker
recruitment, worker assignment UI, and building removal are future work.

## Validation

Milestone 2F is valid when:

- The project opens in Godot 4.6.3.
- The main scene runs.
- A fixed 128x128 dungeon grid is visible.
- Solid rock, floor, boundary wall, entrance, and Overlord room tiles are visually distinct.
- The entrance is near the south-center edge and connects by cardinal floor path to the north-center 5x5 Overlord room.
- The debug label says `Krebel's Keep Milestone 2F loaded` and shows the hovered tile coordinate/type.
- Camera movement works with WASD or arrow keys.
- Zoom works with mouse wheel or `+` and `-`.
- Startup output reports `Access valid: Overlord room connected to outside`.
- Mines require valid floor with a reachable exposed Ore source in range.
- Lumberyards require valid floor with a reachable exposed Root source in range.
- Completed Mines and Lumberyards create recurring worker harvest tasks instead of passive production.
- Workers travel to the reachable source, gather, return to the building, and deposit +1 Wood or +1 Ore.
- Blocking source access stalls extractor production clearly instead of producing without a route.
- Ore and Root source tiles remain visible, open, permanent, and undepleted.
- No general hauling, source stock accounting, doors, traps, adventurers, combat, waves, tech tree, or save/load behavior exists yet.

Future milestones will add source output caps, fuller regeneration, and broader
hauling/resource logistics.
