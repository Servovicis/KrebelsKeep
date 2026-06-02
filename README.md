# Krebel's Keep

Krebel's Keep is a 2D top-down tile-based dungeon builder/defense sim prototype.

## Milestone 3D Defensive Placement Stub

- Godot version: 4.6.3
- Language: GDScript
- MVP platform target order: Linux, SteamOS, Windows
- Main scene: `res://scenes/main/Main.tscn`

## Open And Run

1. Open Godot 4.6.3.
2. Import/open this project folder.
3. Press Run Project or open and run `scenes/main/Main.tscn`.

## Defensive Placement Prototype

Milestone 3D adds one-tile `DoorPlaceholder` and `TrapPlaceholder` defensive
objects through the existing construction flow. Press `O` to select Door build
mode and `T` to select Trap build mode, then left-click a valid Floor tile to
queue construction. Doors cost 15 Wood and 5 Ore; traps cost 10 Wood and 10
Ore. Both take 2 seconds of worker construction time.

Doors and traps are passable placeholders. They reserve their tile for
placement, but do not block worker/adventurer pathing or outside-access
validation. Completed doors briefly slow adventurer parties that cross them.
Completed traps show `Adventurer party triggered trap at (x, y)` when an
adventurer party steps on the trap and briefly delay that party. A trap can
trigger once per party for each trap tile; real damage, combat, trap balance,
door locking, and open/close logic are future work.

## Adventurer Wave Prototype

Milestone 3D keeps the simple timed non-combat adventurer wave stub. The first
timed wave starts after 20 seconds, subsequent waves start every 30 seconds,
and each wave currently spawns one placeholder adventurer party at the Entrance.
Spawned parties path cardinally through reachable Floor and Entrance tiles
toward the Overlord room. Adventurer route selection treats completed doors and
traps as higher-cost passable tiles, so parties prefer a modestly longer clean
route over a shorter route packed with defenses. Doors and traps remain
passable for outside-access validation. The marker is intentionally
placeholder-only and distinct from workers.

The Overlord starts with 3 HP. When an adventurer party reaches the Overlord
room, the party breaches once, stops there, and reduces Overlord HP by 1. If HP
reaches 0, the game shows `Overlord defeated placeholder: dungeon would lose
here`. This is only a placeholder loss message; the game does not restart or
reset automatically. Timed waves stop after the Overlord HP reaches 0.

Press `V` to spawn another debug adventurer party from the Entrance. This is a
manual test hook for reducing Overlord HP to 0 and remains available alongside
the timed wave stub.

If no route is available, debug output reports
`Adventurer path blocked: no route to Overlord room`.

Combat, defenders, loot, gold rewards, varied wave composition, damage systems,
trap damage, and full loss screens are future milestones.

## Resource Extraction And Recruitment Prototype

Milestone 3D keeps the worker trip prototype and lets Mine/Lumberyard extractors
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

Press `P` to cycle the temporary global worker focus mode through Balanced,
Digging, Building, and Harvesting. Focus mode biases idle workers toward that
kind of eligible task, then falls back to other eligible work when the preferred
task type is unavailable. This is a debug/HUD-first priority stub, not
per-worker or per-building assignment UI.

Full worker assignment UI, per-building assignment UI, and building removal are
future work.

## Validation

Milestone 3D is valid when:

- The project opens in Godot 4.6.3.
- The main scene runs.
- A fixed 128x128 dungeon grid is visible.
- Solid rock, floor, boundary wall, entrance, and Overlord room tiles are visually distinct.
- The entrance is near the south-center edge and connects by cardinal floor path to the north-center 5x5 Overlord room.
- The debug label says `Krebel's Keep Milestone 3D loaded` and shows the hovered tile coordinate/type.
- The debug label shows Overlord HP.
- The debug label shows the current wave, countdown until the next wave, and active/resolved adventurer party counts.
- The first timed wave spawns one adventurer party at or near the Entrance after 20 seconds.
- The adventurer party moves cardinally through reachable Floor/Entrance tiles toward the Overlord room.
- If its current route is blocked by a new building and another route exists, the party recalculates from its current tile.
- Pressing `O` selects Door build mode, and pressing `T` selects Trap build mode.
- Door and Trap placement rejects invalid/non-Floor/reserved/source/Entrance/Overlord-room tiles.
- Door and Trap placement on valid Floor deducts resources, queues construction, and completes through worker construction.
- Completed doors and traps are visible, passable, and do not break outside-access validation.
- Adventurer parties crossing a completed door show door slow debug feedback and remain able to reach the Overlord room.
- Adventurer parties stepping on a completed trap show `Adventurer party triggered trap at (x, y)` and are briefly delayed.
- Reaching the Overlord room logs an Overlord breach message and reduces Overlord HP by 1.
- The same party does not repeatedly damage the Overlord every frame.
- Pressing `V` spawns another debug adventurer party, allowing HP to reach 0.
- HP 0 shows `Overlord defeated placeholder: dungeon would lose here`.
- Timed waves stop after HP reaches 0.
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
- The debug label shows worker count, worker status counts, worker focus mode, recruitment cost, and the latest recruitment result.
- Pressing `P` cycles worker focus through Balanced, Digging, Building, and Harvesting.
- Worker focus makes idle workers prefer eligible tasks of that type without preventing fallback to other eligible work.
- Ore and Root source tiles remain visible, open, permanent, and regenerating.
- No worker assignment UI, general hauling, finite source depletion, combat, defenders, loot, gold rewards, varied wave composition, tech tree, or save/load behavior exists yet.

Future milestones will add broader hauling/resource logistics.
