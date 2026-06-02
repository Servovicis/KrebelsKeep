# Krebel's Keep

Krebel's Keep is a 2D top-down tile-based dungeon builder/defense sim prototype.

## Milestone 2H Regenerating Source Capacity

- Godot version: 4.6.3
- Language: GDScript
- MVP platform target order: Linux, SteamOS, Windows
- Main scene: `res://scenes/main/Main.tscn`

## Open And Run

1. Open Godot 4.6.3.
2. Import/open this project folder.
3. Press Run Project or open and run `scenes/main/Main.tscn`.

## Resource Extraction And Recruitment Prototype

Milestone 2H keeps the worker trip prototype and lets Mine/Lumberyard extractors
use reachable nearby permanent sources instead of requiring direct adjacency.
Completed extractor buildings request harvest work from the shortest reachable
matching source within a small cardinal path range. A worker travels to the
source, gathers briefly, returns to the building, and deposits Wood or Ore into
the global resources.

Ore and Root sources are not finite deposits. They are permanent dungeon
features with capped current/max availability and regeneration rates. Harvesting
spends current source availability, then dungeon magic regenerates that
availability over time up to the source max. Root sources regrow partly through
dungeon magic, and ore-rich sources replenish as magic flowing through the
dungeon slowly replaces ore. Sources are not permanently depleted or removed.

Current fixed test sources are exposed on floor for easy validation. Later,
players should usually dig to reach or expose resource sources instead of
starting with every source pre-dug.

Sources start at 5/5 available and regenerate 1 available resource every 5
seconds. Multiple workers can benefit from the same source while it has current
availability, but output is capped by source availability and regeneration
rather than by finite depletion.

Adjacent extractor placement is still optimal because worker travel is shorter,
but it is not mandatory. If buildings or construction block access to a matching
source, production stalls with debug feedback until access is restored.

Press `R` to recruit one temporary worker-capacity test Goblin Worker. Recruitment
currently requires a completed `BarracksPlaceholder`, costs 20 Wood and 10 Ore,
and spawns the worker on a valid reachable floor tile near the Barracks. This is
a temporary worker-capacity stub before worker assignment UI.

Worker assignment UI and building removal are future work.

## Validation

Milestone 2H is valid when:

- The project opens in Godot 4.6.3.
- The main scene runs.
- A fixed 128x128 dungeon grid is visible.
- Solid rock, floor, boundary wall, entrance, and Overlord room tiles are visually distinct.
- The entrance is near the south-center edge and connects by cardinal floor path to the north-center 5x5 Overlord room.
- The debug label says `Krebel's Keep Milestone 2H loaded` and shows the hovered tile coordinate/type.
- Hovering a source shows its current/max availability, such as `Exposed Ore Source: 3/5 available`.
- Camera movement works with WASD or arrow keys.
- Zoom works with mouse wheel or `+` and `-`.
- Startup output reports `Access valid: Overlord room connected to outside`.
- Mines require valid floor with a reachable exposed Ore source in range.
- Lumberyards require valid floor with a reachable exposed Root source in range.
- Completed Mines and Lumberyards create recurring worker harvest tasks instead of passive production.
- Workers travel to the reachable source, spend source availability, gather, return to the building, and deposit +1 Wood or +1 Ore.
- Empty sources remain visible and cause harvesters to wait/retry until regeneration restores availability.
- Blocking source access stalls extractor production clearly instead of producing without a route.
- Pressing `R` before a completed `BarracksPlaceholder` exists rejects recruitment clearly.
- Pressing `R` with a completed `BarracksPlaceholder`, enough resources, and a valid reachable spawn tile deducts 20 Wood and 10 Ore and adds a worker.
- The debug label shows worker count, recruitment cost, and the latest recruitment result.
- Ore and Root source tiles remain visible, open, permanent, and regenerating.
- No worker assignment UI, general hauling, finite source depletion, doors, traps, adventurers, combat, waves, tech tree, or save/load behavior exists yet.

Future milestones will add broader hauling/resource logistics.
