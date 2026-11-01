# Crater Throne: motion, effects + contained spawn area (31 Oct 2026, Claude; from ChatGPT `core-audit-plan-r1.txt`)

James (31 Oct pm): "the center the stuff moving shining ... show ChatGPT what we have with screenshots then get reference
images for the movements" + "making it a bit better so monsters can spawn around it in its own contained area".
Now (`now-1..3.jpg`): the reactor is fully STATIC (no script animates it). ChatGPT r1: GO WITH CHANGES; silhouette 8,
hull 8, colour 8, match to B 7, **motion 3, combat readability 4**. Keep every existing mesh; no remodel.

## Crater (measured 31 Oct)
Bowl floor y -2..-9 out to r 55-60; rim peaks y 12-18 at r 80-90; low breaches E + W (y -3..-10); low notch at 225 deg;
plain y 1-3 outside; lanes end at r 125 (22.5 + 45k deg). Wreck shell ~81 x 87 at the centre.

## Contained combat area (lock this FIRST, greybox + nav test before any effects)
| Element | Where / size | Treatment |
|---|---|---|
| Combat ring | r 47-72 | shallow terraces on the inner slopes round the wreck |
| Boundary | existing rim r 80-90 | basalt + short rock buttresses; a faint energy arc between ramps ONLY during a fight |
| 4 spawn pockets | r 60-68 at 45 / 135 / 225 / 315 deg, ~18 x 22 flat | garrison: 4 groups x 8 matter (1 F3 + 1 F2 + 2 F1) = 16 units / 32 matter (wild); holder's own 32 later |
| 2 shield pylons | N (0, -67) + S (0, +67) on 14 x 14 shelves | between lanes, glowing faces toward the lanes; 400 HP each |
| 8 entry ramps | one per lane, r 125 -> rim cut r 80-90 -> shelf r 68-72 | 18-20 clear, 10-12 soft sides; keep raised basalt between; test with F4 |
Containment = the server's nav area (defenders stay inside r 72; attackers enter by their lane ramp), not visual walls.
One throne assault per server at first; everything server-authoritative.

## Motion (one client controller, Workspace:GetServerTimeNow() phase; 20 Hz near, 5 Hz mid, off far)
| Part | Motion | Look |
|---|---|---|
| Broken ring (4 segments) | 0.6 RPM clockwise (100 s / turn), keep its tilt | stays dominant over the halo |
| Cyan halo | 1.2 RPM counter-clockwise (50 s) | |
| Upper cyan orb | spin 8 deg/s | brightness pulse every 3.5 s |
| Lower violet core | spin 12 deg/s | inner pulse every 3 s, +-15 % |
| 3 beams | texture flow 0.2 cycles/s | violet -> cyan, opacity breathing every 4 s |
| 6 floating rocks | bob +-0.8 over 5-8 s, turn 2-4 deg/s | |
| Floor crystals | still | occasional single sparkle |
| Meteor | every 90-120 s, idle only, outer scar / rim | streak, flash, dust ring, fade (cosmetic) |
Budget: 20-30 ambient particles (core motes 2 x 2/s, pylon motes 2 x 1.25/s, sparkles 3 x 1/s, meteor burst 20-30);
4 shadowless lights (6 max in events); no particles on ring / halo / rocks.

## States
WILD (violet) -> ATTACKED (pylons light, shield over the core, garrison deploys ONCE) -> each pylon at 0 breaks its link
with a flash -> both down: shield folds in 1.5 s, core marked as the target -> core pulses faster as HP falls -> 0 HP:
ring slows, beams cut, a contained shockwave across the scar -> CONQUEST 3-5 s: restarts in the winner's colour, banners
rise, upper orb accent changes, crown hologram above the ring. HELD = owner colour strips / glow / links / banners. Never
move collision or throw physical debris.

## Build order (ChatGPT)
1. One terrace + one pylon + one ramp in greybox; test 32 v 32 space round the shell.
2. Duplicate terraces / pylons / ramps.
3. Then motion, beams, pulses, crown, meteor.

## Reference images (design\concepts\hub\)
R1 top-down dimensioned layout; R2 motion sheet; R3 states / effects sheet; R4 pylon ortho sheet; R5 spawn pocket +
ramp close-ups (planned).

## As built (31 Oct, 14:00-14:55)
- Refs R1 layout, R2 motion, R3 states, R4 pieces (`design\concepts\hub\`).
- MOTION: `src\StarterPlayer.StarterPlayerScripts.ReactorMotion.client.luau` (one client controller, installed by
  `src\tools\hub-reactor-motion-setup.luau`, which writes RestCF + the beam look). Ring / halo / orbs / core / rocks /
  beams as in the table above; beams = band texture rbxassetid://80886891608954 (`assets\textures\reactor-beam-flow.png`)
  flowing up, violet -> cyan. Checked: ring tilt drift 0.0000 at t 7 / 13 / 19 / 61.
- ARENA TERRAIN: `src\tools\hub-throne-arena.luau` ("measure" / "greybox" / "terrain"; backup
  `ServerStorage.ThroneTerrainBackup`, re-runs paste it back first). Terrace y -2 r 47-75 (eased to the rim by r 83),
  8 ramps 20 + 11 soft on the lane angles (y 3 at r 122 -> -2 at r 72), pads levelled at the voxel boundary y 0.
- PIECES: `src\tools\hub-throne-pieces.luau` -> `workspace.Hub.Conquest.Throne.Pieces`: **pylons EAST (67,0) + WEST
  (-67,0)** (moved from N / S after measuring a 9-stud pinch at the south: the wreck bulges south to r 56), 4 spawn
  pockets at r 60 (18 x 22 Slate slab, violet ring, kit-boulder lip on the rim side, 4 Spawn attachments each),
  CoreFX: ShieldBubble (ForceField + Highlight outline), TargetMarker (red, r 9), Shockwave.
- STATES = attributes on `Throne`: State wild / attacked / shieldDown / held, ShieldDownAt, BreakAt, OwnerColor;
  pylon State neutral / active / destroyed. Clearance: narrowest free band round the wreck = 21 studs (was 9).
- NOT built: crown hologram, rim banners, core + upper orb owner colour, spawn flash, meteor, destroyed-pylon stump,
  real 32 v 32 army test (needs the combat code in this place).
- STAGE C (15:20, GO 9.5): `src	oolshub-throne-stageC.luau` -> Pieces.StageC; ref R5. Tinted parts restore to their RestColor attribute.
