# Map size / structure audit (ChatGPT, 30 Oct 2026 ~21:35) - VERDICT: OPTION C, HYBRID HUB, "GO: expand to 1,500 x 1,050"

> **Current numbers = the r4 section at the END of this file** (James 30 Oct ~22:10: open plain round the bases, biomes
> against the walls, ~1,660 x 1,400). The table below is the first plan (1,500 x 1,050), kept as the audit record.
James (30 Oct): "the map's gotta be bigger ... to have the three biomes we need a much larger map with the other two
biomes and then still the bases in between. Or should the moon have portals to these biomes as separate instances?"
Asked in ChatGPT chat "Create Master Map Reference" with current-map-sheet.jpg + the textured forest.

## Decision (ChatGPT; Claude agrees) - NOT YET APPROVED BY JAMES
One bigger seamless moon: crater + 8 plots + Moonwood + Goo Marsh + Crystal Canyon + Lander Ruins in ONE place.
Biomes are NOT portals (loading screens on every farming trip, splits friends across servers). Separate places stay
for big battles (16+ raids, PvP) and FUTURE moons only. A: giant 2,000 x 1,400 = too much build + travel; B: portals =
fragmented, loading friction.

## Numbers (targets, crater centre = 0,0; "north" axis +)
| Region | Size | Placement |
|---|---|---|
| Whole playable map | 1,500 x 1,050 (2.3x today's 1,008 x 672) | X -750..+750, N -525..+525 |
| Central hub | 650 x 520 | centre, crater + plots |
| Crater | 130 across | origin (keep the built one) |
| 8 plots | 85 x 95 each | X = -230 / +230, N = -165, -55, +55, +165 (15 studs between plots) |
| Moonwood Forest | 760 x 240 (today ~680 x 95) | X -380..+380, N +275..+515 |
| Goo Marsh | 365 x 420 | X -730..-365, N -200..+220 |
| Crystal Canyon | 365 x 420 | X +365..+730, N -200..+220 |
| Lander Ruins | 860 x 215 | X -430..+430, N -300..-515 |
Travel: walk speed ~22 studs/s in the hub; plot -> crater 10-15 s; plot -> nearest biome 8-15 s; to the far biome
25-35 s; entrance -> biome landmark 8-15 s. A fast-travel terminal on every plot (Forest / Marsh / Canyon / Ruins,
unlocked on first visit) = in-place move in the SAME server (Player:RequestStreamAroundAsync first), not TeleportService.

## Performance budget (4 GB phone baseline; project targets, not Roblox limits)
Visible env tris 150-220k (250k stress); draw calls < 500-700; loaded parts < 1,500-2,000; placed env tris whole hub
0.8-1.2 M; client memory < ~1.0-1.2 GB (watch % of allocation in Roblox perf analytics); 30 fps min, 45+ wanted;
forest full detail 45-85k tris; <= 4-6 dynamic lights per view.
Streaming: MinRadius 64, TargetRadius start 384 (test 512; Roblox default 1024), StreamOutBehavior Opportunistic,
ModelStreamingBehavior Improved, StreamingIntegrityMode PauseOutsideLoadedArea, static tree/building models
LevelOfDetail SLIM, small interactive assemblies Atomic only where needed. Bulky assets out of ReplicatedStorage.
HIDDEN RISK: 8 players each in an 8v8 nest fight = 128 units in the hub. Server-authoritative, but distance-based
client replication + animation LOD: render <= ~32-48 full-detail fighters per client; stress-test the server with 128.
Keep out of the hub: big raids / PvP / bosses (64-196 units), future-moon assets, lots of goo particles / stacked
transparent water, physics-driven decoration, global replication of every off-screen fight.

## DNA economy: make every biome necessary
Crater = generic DNA + meteorite fragments (early + shared events); Moonwood = violet MUTATION SPORES (rare mutations,
incubator upgrades, cosmetics; the elder tree = a DNA bloom / mutation event); Goo Marsh = cyan Squish DNA (Squish
forms / upgrades, ~60-70 % of the practical rate); Crystal Canyon = amber Crunch DNA; Lander Ruins = scrap, machine
parts, meteorite cores (drill / refinery upgrades, automation); plot = Moon Rock + a small generic DNA trickle;
battles = progression tokens + main combat income. First hatch + first nest only need plot + crater. Each biome: a
first-visit bonus + 3 short tasks; automation later so players are not forced to repeat the trip forever.

## Revised build order
1 expand floor + cliff ring to 1,500 x 1,050, GREYBOX coloured zone volumes + plot footprints, check routes;
2 G2 showcase plot at its final coordinates; 3 move + widen Moonwood (reuse the 104 trees, depth ~240, no new texture
pass); 4 Goo Marsh (test transparency cost at once); 5 Crystal Canyon (mostly opaque); 6 Lander Ruins (interactive
scrap first); 7 travel terminals, biome rewards, streaming test, worst-case profile on a 4 GB Android.
Don't decorate biomes before their resource loops exist.
Condition before locking the bigger map: a perf test with one full plot + the forest + a worst-case 128-unit hub fight
on a real 4 GB phone; if it fails, cut resident content / visible fighters, not automatically the map size.
Top risks: 1 low-end phone memory / fps; 2 boring empty travel; 3 an economy that makes exploring pointless.
"One moon, four regions, eight social bases, separate battle instances, additional moons as future worlds."

## BUILT + LOCKED (30 Oct ~22:00, James: "yes to ChatGPT's recommendation")
- Terrain: `assets\blender\scripts\hub_terrain.py` -> `assets\blender\terrain\terrain_grid_hub.json` (431 x 316 cells,
  4 studs) -> `src\tools\build-terrain-hub.luau` (grid corner snapped to the voxel grid). Crater + scar terrain copied out
  first and pasted back exactly (ServerStorage.CraterTerrainBackup). Top views `hub-greybox-r1/r2/r3-top.png`.
- ChatGPT greybox r1 GO WITH CHANGES -> applied: plot rows N +-65 / +-190 (X +-230), 9-stud skirts; 4 corner passes
  (28 wide) + a 20-wide hub -> canyon plateau ramp. Studio found a ridge across the marsh entrance (highland noise in the
  hub/biome gaps) -> r3: each hub side eases straight into its biome. ChatGPT r3 **GO, LOCK THE LAYOUT (9/10)**.
- Greybox: `src\tools\hub-greybox.luau` = workspace.Hub.Greybox (8 plot outlines + signs, 4 biome beacons + signs;
  signs currently hidden for screenshots). Old arena (2 bases + 71 rocks) -> ServerStorage.ArchiveArenaV1; 24 hub rocks
  kept; 8 showcase aliens moved to the hub south of the crater. Shots: `hub-greybox\greybox-studio-sheet.jpg`.
- Checks: all 8 plots see the reactor ring at 5-stud eye height. Walks @22: plot -> nearest biome 8-10 s; passes 10-11 s;
  plateau ramp 23 studs climb (local max 28 deg, Humanoid MaxSlopeAngle 89).
- NOT DONE: streaming properties (StreamingMinRadius 64, StreamingTargetRadius 384, ModelStreamingBehavior Improved,
  StreamOutBehavior Opportunistic) are not scriptable: set by hand in Workspace properties.
- NEXT (ChatGPT order): G2 showcase plot -> Moonwood move + widen (keep the 14-wide path, the elder clearing r 32, no
  dense trees in the gap to the north plots, elder visible without hiding the crater ring) -> Goo Marsh -> Crystal
  Canyon -> Lander Ruins -> fast-travel terminals + biome rewards + 4 GB phone test.

## r4 (30 Oct ~22:15) - James: trees floating + "biomes straight up against the tycoon buildings"; wants open space
## round the bases, big biomes against the walls
- Playable now ~1,660 x 1,400 (cliff ring +-850 x +-720). Plots + crater unchanged. OPEN PLAIN (old rolling ground,
  soft craters) round the bases to ~+-470 x +-440. Biomes against the walls: Moonwood N 420..700 x X +-480; Lander Ruins
  N -700..-420 x X +-480; Goo Marsh X -830..-490 x N +-330; Crystal Canyon X 490..830 x N +-330. Highland corners +
  4 passes + plateau ramp (500 -> 600, N -280). Plot edge -> biome ~160-200 studs (7-9 s @22). r3 kept as
  `hub_terrain.r3.py`; top view `hub-greybox-r4-top.png`; sheet `hub-greybox\greybox-r4-sheet.jpg`.
- Forest re-laid by `hub-moonwood-place.luau` (r3 kept as `.r3.luau`) in the new zone: 207 trees + elder, 4 clearings,
  path, ~500k textured tris placed; all raycast-seated; LevelOfDetail SLIM on the tree models; canopy tint + pod colours
  re-applied. 10 old rocks left floating by the terrain change re-seated. Plain detail: 6 rock groups with a dark meteor
  fragment each (workspace.Hub.PlainDetail).
- ChatGPT r4 GO WITH CHANGES 8.5/10 ("much closer to what James described ... don't enlarge again"). Done: fix 1 (plain
  points of interest). Open: fix 2 = landmark silhouettes at the marsh / canyon / ruins entrances (giant cyan mushrooms,
  amber spires, a satellite tower) -> that is the start of each biome build (reference images first); fix 3 = 4 GB phone
  test of the forest (target 60-90k rendered forest tris from the hub; if over, thin to ~165-175 trees).
- Map saved ~22:17.
