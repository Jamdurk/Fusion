# Alien Fusion: resume snapshot (31 Oct 2026 13:50, Claude)

Moon TYCOON + merge battles (mechanics `design\21-GAME-MECHANICS.md` v4.2). Rules: `DECISIONS.md`. History: `BUILD-LOG.md`.
**Read `LESSONS.md` before touching models, textures, terrain or effects.** Old snapshots: `history\`.

## VERIFIED (file dates checked 15:18)
- **Main place** `AlienFusion-map.rbxl` saved 31 Oct 15:18 (3.76 MB, local file, Ctrl+S; title bar = the D:\ path).
  Backups: `backups\AlienFusion-map.pre-ring380-31Oct.rbxl` (13:45, ring at r 320);
  `backups\AlienFusion-map.pre-conquest-ring-31Oct.rbxl` (12:13 = the map before the ring);
  `Alien Fusion base map.rbxl` = James's untouched safety copy (same 12:13 map). NOT published (cloud test place has no
  canyon / ring yet; James publishes).
- **Hub map r5 RING** (ChatGPT stage-1 GO 9.2): moon stretched 100 N/S + 52 E/W (~1,764 x 1,600 playable); Moonwood N,
  Goo Marsh W, Crystal Canyon E built, Lander Ruins S greybox; 8 plots 85 x 95 at **r 380** (James 31 Oct pm: further back; was 320; 22.5 + 45k deg,
  facing the crater), graded lanes 20 wide r 337.5 -> 125 (75 studs clear from a base to Fort 1; ChatGPT GO 9.3), 16 levelled fort pads (Fort 1 r 240, Fort 2 r 170). Terrain =
  `assets\blender\scripts\hub_terrain_ring.py` (stretches `terrain_grid_hub.r4.json` from `hub_terrain.py`) ->
  `terrain_grid_hub.json`; Studio `src\tools\hub-ring-stretch.luau` (stages; ServerStorage.ArchiveRingR5 = old greybox +
  12 archived rocks).
- **FORT 1 "Hatchling Nest" on lane 1** (ChatGPT visual GO 9/10): `src\tools\hub-fort1-place.luau` ("wild" /
  "conquered") -> `workspace.Hub.Conquest.Lane1.Fort1`; inactive look in `ServerStorage.FortLooks`; AI pieces in
  `ServerStorage.FortKit`. CoreHitbox, CoreHP 600, 6 WildSpawn attachments, ApproachFrom.
- **CRATER THRONE** (ChatGPT stage B GO 9.2): reactor MOVES (client `ReactorMotion`,
  `src\StarterPlayer.StarterPlayerScripts.ReactorMotion.client.luau`), contained arena (terrace r 47-75, 8 ramps =
  the lanes' crater entries, pylons EAST/WEST, 4 spawn pockets at r 60) + state FX via `Throne` attributes. Backup before:
  `backups\AlienFusion-map.pre-throne-arena-31Oct.rbxl`. Spec `design\conquest-lanes\core\THRONE-SPEC.md`.
  Stage C (crown, rim banners, owner colour, spawn flash, meteor, broken pylon) GO 9.5. NOT built: throne COMBAT.

## MATERIALS + TYCOON (1 Nov, DESIGN LOCKED by James): `design\24-MATERIALS-AND-TYCOON.md` (ChatGPT GO). MOON ROCK /
GOO DNA / CRYSTAL DNA, ONE incubator (2 eggs), hand mining + slow machines, rare = looks only. NOTHING BUILT. First build =
one plot: starter launch pad, drill, mineable rock, Goo vein, incubator, a hatch into the army, Fort 1.

## CONQUEST LANES status (start: `design\CONQUEST-LANES-HANDOFF.md`, log `design\conquest-lanes\BUILD-LOG.md`)
- James 31 Oct: stretch + ring first (done), then Fort 1 on one lane (visual done); throne = real army capped at 32
  matter; Fort 1 goo nest / Fort 2 crystal fort as designed.
- NEXT (gameplay stage, ChatGPT gate): LAUNCH PAD deploy (8-matter cap), 6 wild Drips, 600 HP core break, capture
  transition (colour spread, flag swap, core swirl pulse 2-3 s), drill reward; then James's phone test.
  Needs the combat code from the AI-test place (`src-aitest\`) in the map place + MERGE in battle (not built anywhere).
- Throne next (ChatGPT): server-side combat: 32-matter garrison, 2 x 400 HP pylons, 3,000 HP core, capture state machine, a 32 v 32 test
  (Titan beside small units through the 21-stud pinch). Test a real army along a lane + up the plot ramp (F4).

## OPEN (older)
- Canyon non-blocking: per-view tris + 4 GB phone test; distance-based FX enable. Streaming settings by hand.
- Lander Ruins (S) still greybox.
