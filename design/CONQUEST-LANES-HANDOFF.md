# Alien Fusion: CONQUEST LANES handoff (31 Oct 2026, Claude) - read this first, then build

**One line:** each of the 8 player bases sends its alien army down its own lane, through two enemy forts, to the
crater throne held by a player (James's "Merge an Army" idea, 30 Oct). ChatGPT: GO WITH CHANGES (8.5/10, fun 9).
**Status:** designed + audited. **James chose (31 Oct): (1) STRETCH the map + move all 8 plots into the RING first
(he first picked a one-lane test, then on hearing that meant no bases moved: "Move bases too"), then Fort 1 + its lane on one base; (2) throne = holder's REAL army capped at 32 matter (ruling A);
(3) Fort 1 goo nest / Fort 2 crystal fort as designed.** Build log: `design/conquest-lanes/BUILD-LOG.md`.
**Built 31 Oct (side session):** stage 1 stretch + 8-plot ring (ChatGPT GO 9.2) and Fort 1 visual on lane 1 (GO 9/10).
Then (James) plots moved back to **r 380** (75-stud gap to Fort 1; GO 9.3). Next = Fort 1 GAMEPLAY (deploy, 6 wild Drips, core break, capture, drill reward). Section 4-5 numbers below are pre-build.

## 0. Safety copy (do not touch)
- `Alien Fusion base map.rbxl` (same folder as this game) = the full map as it was on 31 Oct 12:13, WITHOUT this idea:
  Moonwood N, Goo Marsh W, Crystal Canyon E, crater, 8 plots in 2 rows, speed button in the MOVE TEST menu.
  Byte-identical to `AlienFusion-map.rbxl` at that time. If James drops the idea, that file is the map.
- Also: `backups\AlienFusion-map.pre-crystal-canyon-31Oct.rbxl` (before the canyon). Work in `AlienFusion-map.rbxl`;
  back it up to `backups\` before any terrain change.

## 1. James's words (30 Oct, trimmed)
"You merge your army, they passively spawn in your base, then there's a little army base right in front of yours, and
when you're ready you can deploy however many troops, you can upgrade how many you can deploy. They fight that first
mini base ... if they die you keep trying again ... you conquer it, then the second base in front ... then it goes
right to the center, which is the hardest ... conquered by another player ... if that player has put really
overpowered troops there, you'll need overpowered troops as well ... It would mean spacing out the tycoon bases a bit
more." 31 Oct: "I want them close to the biomes, but not super close." 31 Oct: "what is gonna be in the mini bases?"

## 2. Read these (in order)
1. `design\23-CONQUEST-LANES.md`: the proposal + the audit summary (rulings A-F).
2. `design\conquest-audit\conquest-lanes-audit-r1.txt`: ChatGPT audit r1 (GO WITH CHANGES 8.5).
3. `design\conquest-audit\fort-design-r1.txt`: ChatGPT fort design r2 (what is inside each fort).
4. `design\21-GAME-MECHANICS.md` (v4.2, locked: hatching, 32 matter, merge / split rules, fair PvP), `03-FORMS-AND-RULES.md`,
   `09-POWER-GRAPH.md` (swarm / pack / brute / titan counters), `11-ALIEN-AI.md`.
5. `design\map-review\map-size-audit.md` (r4 section at the end = today's map numbers), `00-CHECKPOINT.md`, `LESSONS.md` (ALL).
6. `design\map-review\BIOME-BUILD-METHOD.md`: how anything visual gets built (refs -> spec -> Blender -> Studio -> audits).

## 3. The design (ChatGPT-audited, James to confirm the starred ones)
| Thing | Decision |
|---|---|
| Deploy | LAUNCH PAD on your base; your OWNED aliens pour out and march down the lane (looks like passive spawning, but aliens still come from DNA hatching: ruling B) |
| Deploy cap (MATTER, not units) | 8 -> 12 -> 16 -> 24 -> 32 via upgrade pads |
| Lose | no aliens lost, back home, redeploy after 10 s |
| **Fort 1 "The Hatchling Nest"** | reuse the GOO MARSH nest (32 x 24 x 15); footprint ~40 x 34; 6 wild Drips (6 matter); 600 HP goo core on a plinth; a goo puddle (20 % slow). Lesson: MERGE (Drips -> Twins beat swarms). 30-45 s fight. Target win at minute 1-3, 70-85 % first try. Runs IN THE HUB (max 2 at once) |
| Fort 1 after | nest tamed in your colour, egg sacs calm, a tiny drill: forward rally point + small rock trickle (~5-10 % of active rock income) |
| **Fort 2 "The Swarm Trap"** | reuse the CRYSTAL CANYON nest (34 x 24 x 17) inside jagged crystal-basalt walls with one gap; footprint ~48 x 44; 12 Pebbles + 2 Pincers (16 matter); 1,200 HP crystal core; 2 crystal pylons (200 HP, 8 dps, warned). Lesson: SPLIT (your first Titan gets swarmed: split into Brutes / Packs). 45-75 s, minute 8-15, 40-60 % first try. INSTANCED |
| Fort 2 after | crystals dimmed, your banners, a DNA extractor + launch platform: rally point + small DNA trickle (~5 %) |
| **Crater Throne "King of the Moon"** | giant reactor in the crater (keep image B's look); fight area ~100-110 inside the 125 crater; the holder's chosen 32-matter army (AI), ONE finite wave (no respawns); 2 shield pylons (400 HP) then a 3,000 HP core. 60-90 s. INSTANCED |
| * Throne fairness (ruling A) | holder uses his REAL army, capped at 32 matter, PvE bonus <= +10 %; NOT unlimited "overpowered" (James said OP troops: confirm) |
| * Throne rotation (E) | 60 s protection, max 10 min reign, 1 challenger at a time, loser waits 2 min, 60 s reconnect grace, then back to an NPC army; reward crown + temporary +5 % rock + a kept title; server-local |
| Fair PvP | unchanged: separate battle place, 32 matter, normalised |
| Progress | each player's forts are PERSONAL (profile-saved, first-clear rewards never paid twice); your Fort 1 colour never hides another player's |
| Replay | optional harder repeat defences per fort (Fort 2 repeat: a Ram + Packs); never reset conquered forts |
| Originality (F) | only original if MERGE / SPLIT is what wins. Acceptance test: same army, tactical player wins clearly more than "always biggest form" |

## 4. Map geometry (MEASURED, not ChatGPT's numbers)
- ChatGPT's first ring (plots r 215, forts r 140 / 90) is WRONG: it assumed a 42-radius crater. Our crater bowl + rim
  reaches ~125 from the centre (terrain grid `assets\blender\terrain\terrain_grid_hub.json`: rim y 12-15 at r 80-90 N/S,
  bowl below 0 out to r ~120-130 along X).
- Working ring: crater edge 125 / **Fort 2 r 170 / Fort 1 r 240 / plot centres r 320** (70 x 70 plots, outer edge ~355),
  lanes 18-22 wide, plots every 45 deg starting at 22.5 deg. ChatGPT r2 confirmed these radii.
- Today's map (r4): playable ~1,660 x 1,400, open plain to ~+-470 x +-440; biomes start at |X| 490 (marsh / canyon)
  and |Z| 420 (forest / ruins). Today's plots are 2 rows (X +-230, Z +-65 / +-190), 180-220 studs from the biomes.
- With the ring on today's map: plots at 67.5 deg reach Z ~330 -> only ~90 studs to the forest / ruins; plots at
  22.5 deg reach X ~330 -> ~160 to marsh / canyon. James wants "close but not super close".
- => **Stretch the moon ~100 studs north + south and ~50 east + west** (ChatGPT r2 said 200-250 N/S but measured from the
  OLD 1,008 x 672 map: ignore that). Verify the gaps from the real biome edges after the stretch.
- The crater + scar stay exactly as they are (CraterTerrainBackup).

## 5. How big the stretch is (told James "medium, about 1-2 hours")
- Terrain = `assets\blender\scripts\hub_terrain.py` -> `terrain_grid_hub.json` -> `src\tools\build-terrain-hub.luau`:
  change the zone boxes (`plain`, `forest`, `marsh`, `canyon`, `ruins`, the cliff ring `sup` 850 / 720, the 4 passes,
  the plateau ramp, the plot pads -> RING) and rebuild. Crater copied out + pasted back (as in r3/r4).
- The 3 finished biomes move with their zone: their scripts use ABSOLUTE coordinates -> add an offset and re-run:
  `hub-moonwood-place.luau` (re-runnable, raycast-seated), `hub-goomarsh-place.luau` (+ `-fx`; its terrain backup
  region must be re-taken AFTER the new terrain), `hub-crystalcanyon-place.luau` (+ `-fx`; its NORTH / SOUTH channel
  polylines, links, nests, veins, spire are measured world coordinates: shift them all; delete the old
  ServerStorage.CanyonTerrainBackup first or it restores the OLD canyon!). Same for MarshTerrainBackup.
- Plots: only greybox outlines + signs (`hub-greybox.luau`): cheap to move. No real base is built yet.
- Then: float check on every prop, Studio shots, ChatGPT audit (as every stage).

## 6. Smallest first build (ChatGPT's advice; works on today's map too)
One plot, one ~130-stud lane, Fort 1 only, in the one-place slice: 8 starter Drips, 8-matter cap, LAUNCH PAD, 6 wild
Drips + 600 HP core using the goo nest, MERGE prompt, win = flag flips + rock reward + the next goal, lose = back +
10 s. No throne, no other lanes, no instancing. Test: does a new player understand that merging wins, enjoy marching
in, want the next fort? James does the phone test (he plays; don't start Play yourself unless asked).

## 7. Reference images (`design\concepts\hub\`)
- Existing: A (master map), B + B2 (crater + reactor: the THRONE look), G (plot start vs built), G2 (plot layout),
  H (machines: drill, incubator, launch pad...), J (battle arena: pylons, cores, team colours), D / D2b (goo nest),
  E2 / E2b / E6 (crystal nest), `design\conquest-audit\radial-layout-chatgpt.jpg` (ChatGPT's ring sketch: its distances
  are wrong, the idea is right).
- New: **L1** `L1-conquest-forts-chatgpt.png` (Fort 1 / Fort 2 / Throne, before + after conquest) - see section 9.
- Still to ask for (James: "spam reference images"): L2 top-down ring layout with the CORRECT radii (give ChatGPT the
  numbers in section 4), L3 eye-level view down a lane from a base, L4 fort ortho / sizes sheet, L5 conquest effects
  (flag flip, colour spreading, core break, deploy march), a G3 plot-in-the-ring version of G2.

## 8. Lessons that apply here (full list in `LESSONS.md`)
- Audit EVERY stage with ChatGPT (Thinking) until GO; save each verdict; rebut with measurements when it's wrong
  (it was wrong twice here: crater radius, map size).
- Never trust ChatGPT's map coordinates: measure the real terrain (raycasts / the terrain grid) and send numbers.
- After ANY terrain rewrite every placed prop can float or sink: re-run the placement scripts (they raycast-seat).
- Terrain Read/WriteVoxels needs the region corner on the 4-stud grid; terrain backups are region copies (restore
  with PasteRegion at their CornerVoxel attribute).
- Studio: Save via File > Save to File As (helper `af-click2.ps1 -x 28 -y 51 -x2 90 -y2 387`, then paste the path);
  NEVER Ctrl+Shift+S (AMD replay hotkey); keep James's monitor on (`D:\Roblox Game Venture\Keep Screen On.cmd`).
- Big Luau scripts: serve `src\tools` on localhost (`serve2.mjs`) + HttpService:GetAsync + loadstring; stop the server after.
- Chrome extension can drop: relaunch Chrome, reselect device 204741d1; or drive ChatGPT by hand (clipboard paste).
- Hub performance: render <= 32-48 full-detail fighters per client; that's why Fort 1 = max 2 hub fights.
- Plain kid words for anything players read (DEPLOY, ATTACK, REWARD); short plain answers to James; "percent" = progress.

## 9. Open questions for James
1. Stretch the map first, or build the one-lane test on today's map first?
2. Throne: real army capped at 32 matter (ChatGPT) or truly "overpowered troops" (James's first idea)?
3. Happy with Fort 1 = goo nest (merge lesson), Fort 2 = crystal fort (split lesson)?
