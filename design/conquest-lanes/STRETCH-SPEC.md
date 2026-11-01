# Conquest Lanes, stage 1: STRETCH the moon + 8 plots in a RING (31 Oct 2026, Claude) - for ChatGPT audit

James (31 Oct): stretch the map and move all 8 bases into the ring first, then add Fort 1 on one lane. "Heaps of
reference images ... and simplicity." Handoff: `design\CONQUEST-LANES-HANDOFF.md`.

## What changes (all numbers MEASURED from the generator, not estimated)
| Thing | r4 (today) | r5 (this stage) |
|---|---|---|
| Playable moon | ~1,660 x 1,400 | ~1,764 x 1,600 (cliff ring 850 x 720 -> 902 x 820 half-axes) |
| Moonwood Forest (N) | N 420..700 | N 520..800 (same ground moved +100) |
| Lander Ruins (S) | N -420..-700 | N -520..-800 (moved -100) |
| Goo Marsh (W) | X -490..-830 | X -542..-882 (moved -52) |
| Crystal Canyon (E) | X 490..830 | X 542..882 (moved +52) |
| Open plain | +-470 x +-440 | +-522 x +-540 |
| Plots | 8 pads 85 x 95 in 2 rows (X +-230, N +-65 / +-190) | 8 pads **70 x 70** at **r 320**, angles 22.5 + 45k, turned to face the crater, y = 3, 9-stud skirt |
| Lanes | none | 8 lanes 20 wide, r 285 (plot inner edge) -> r 125 (crater edge), painted Ground (darker), ground NOT flattened |
| Crater + scar + wreck | - | untouched (hub core ground identical: 0.00 difference measured over 5,776 samples) |
| Fort 1 / Fort 2 / throne sites | - | r 240 / r 170 / crater (nothing built this stage; Fort 1 next stage on ONE lane) |

Gaps (plot outer corner -> biome edge, before the edge noise of +-30): plots at 22.5 deg reach X 341 -> marsh / canyon
at 542 = **~200**; plots at 67.5 deg reach N 341 -> forest / ruins at 520 = **~179**. (r4 plots were 180-220 from the
biomes; James: "close but not super close".) Each biome faces a GAP between two plots, never a plot head-on.
Neighbouring plots: centre to centre 245; lanes at Fort 2 (r 170) are 130 apart, at Fort 1 (r 240) 184 apart.

## How (no hand rebuilds, nothing re-authored)
1. `assets\blender\scripts\hub_terrain.py` r5: every biome's height + zone mask is evaluated at SHIFTED coordinates,
   so each biome is the same ground moved; shifts are whole voxels (100 / 52 studs = 25 / 13 voxels). Measured vs r4,
   biome interiors identical; differences only in the blend bands (biome <-> plain / highland / cliff, up to ~10 studs
   at the hub-facing marsh edge + canyon mouth, larger in the cliff band). Meteor craters + passes + the plateau ramp
   move with their biome (same random draws). Plain soft craters re-drawn outside r 390 (clear of plots + lanes).
2. Studio `src\tools\hub-ring-stretch.luau`: (a) DELTA: read the live terrain in 4 edit boxes (crater core, forest,
   marsh, canyon) and compare voxel by voxel to what the r4 grid wrote: every difference is a hand edit (canyon channels
   / bowls / vein bays / spire foundation, marsh pools + paint, forest Ground paths, crater mound + scar); (b) write the
   pure r5 grid and re-take MarshTerrainBackup / CanyonTerrainBackup at their shifted corners (the place scripts'
   restore point stays valid); (c) write r5 again with the hand edits folded in at their shifted positions (one write
   per strip, no read-back round trip, which lifts ground ~0.2); (d) move every part of MoonwoodForest / GooMarsh /
   CrystalCanyon by the shift.
3. Then: float / sink check on every prop (bottom vs terrain under it, all 4 biomes + crater + plain rocks), re-seat
   outliers; plain rocks that land on a plot or lane are archived; greybox redone for the ring (plot outlines, PLOT n
   signs, a LAUNCH PAD marker at each plot's crater-facing edge, biome beacons at the new entrances); top-down +
   player-height shots; this audit again on the result.

## Reference images (design\concepts\hub\)
L2 (ring layout, painted over our real render), L2 v2 (22.5 deg fix), more to come per stage: G3 plot in the ring,
L3 lane view from a base, L4 Fort 1 ortho / sizes, L5 conquest effects.

## Questions for ChatGPT
1. Any problem with 70 x 70 plots (r4 pads were 85 x 95)? The tycoon base must fit: drills, incubator, pads, launch pad.
2. Lanes: paint only, or flatten them (+-0.6 ease) for readability and fights?
3. Anything in the method that can break the finished biomes?
