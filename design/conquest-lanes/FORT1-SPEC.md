# Conquest Lanes, stage 2: FORT 1 "THE HATCHLING NEST" on ONE lane (31 Oct 2026, Claude) - for ChatGPT audit

Design (handoff section 3, ChatGPT fort design r2): reuse the GOO MARSH nest; 6 wild Drips; 600 HP goo core; a goo
puddle (20 % slow); lesson = MERGE. After conquest: nest in the player's colour, egg sacs calm, a tiny drill (rally
point + small rock trickle). James: heaps of reference images + SIMPLE.

## Where
Lane 1 (Plot 1, 22.5 deg). Fort 1 pad centre r 240 = (221.7, y, -91.8) in Roblox coordinates, pad 38 along x 44
across, levelled at the graded lane height (~0.9 surface). Nest tunnel mouth faces OUT along the lane (toward Plot 1,
where the attacker comes from); the core stands between the mouth and the attacker.

## Pieces (sizes from L4; reuse first)
| Piece | Source | Size | Notes |
|---|---|---|---|
| Nest shell + tunnel | REUSE `HubKit.GooMarsh.gmNestShell` + `gmNestTunnel` | 36 x 15 x 29 | as in the marsh |
| Goo puddle | REUSE `gmPoolB` scaled | ~14 x 10 | 20 % slow zone (gameplay later) |
| Small goo blobs, rocks, sprouts | REUSE `gmBlobA/B`, `gmRockA/B/C`, `gmSprout*` | as kit | dressing, kept sparse |
| GOO CORE (orb + rock ring) | NEW Blender | orb ~5, ring ~7 | the target; glow on the orb only |
| Core PLINTH | NEW Blender | ~6 x 4 | goo-crusted stone |
| Egg sacs x 6 | NEW Blender | 2.5-3.5 | translucent cyan shell + dark embryo |
| Flag pole + wild rag / player banner | NEW Blender | pole ~12 | banner tinted to the owner's colour |
| Tiny drill (AFTER only) | NEW Blender | ~6 x 6 x 7 | conquered state |
Budget: new pieces 0.8-2k tris each, one 1024 atlas per group (the Goo Marsh method), whole fort < 30k tris, <= 2
lights, <= 3 emitters (1-3 /s).

## States (one model, two looks; script switches)
- WILD: cyan / violet nest, core glowing, egg sacs pulsing, rag on the pole.
- CONQUERED: the nest + core tinted toward the owner's colour (SurfaceAppearance.Color), core dim, egg sacs still,
  banner up, drill on and turning.

## Out of scope for this stage (next stage, gameplay)
DEPLOY, wild Drip AI, core HP + break, the capture itself, rewards. This stage = the structure, both looks, the
spawn points (attributes) for 6 wild Drips and the attack approach, and ~60-70 studs clear round the fort.
