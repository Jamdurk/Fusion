# Titan batch 2: round 2 (your r1 changes, re-measured in Play)

| # | Your change | Done | Measured after |
|---|---|---|---|
| 1 | Commented-out key rows | Comments moved to line ends; slam 2.25/2.90/3.40, bomb 2.85, wave 3.45 rows back. `titanKeys` now asserts front/back row counts AND that every key has all 15 bones (3 + 6 + 6). | Module loads, asserts pass. Whole-move sweeps: lowest tentacle joint slam +0.01 (2.25), bomb -0.03 (2.60), wave +0.02 (3.00), defeat -0.09 (2.05). |
| 2 | Slam tip contact 0.08-0.18 | Animator `atk.contact`: after the pose, each front tip's measured height is pulled to 0.13 by turning that chain's root (0.155 studs/deg, measured), max 12 deg, weight in 1.60-1.64, out 1.73-1.86. Reports saturation (`ContactOver`). | FL3 / FR3 = 0.13 / 0.13 at 1.64, 1.68, 1.73; 0.23 / 0.40 at 1.80; 0.32 / 0.62 at 1.86. FL2 0.24, FR2 0.73-0.75. Saturation 0 (no clamp hit). |
| 3 | Wedge radial edges from 0 | Done. | - |
| 4 | Tsunami lane parity | **Pushback, with evidence:** the power graph (`design/power/sim.mjs`, the gameplay truth everything is balanced on) measures every Titan shape from the Titan's CENTRE with its 6-stud body radius added: the slam wedge is `radius 10 + r 6 = 16` (your 16), the lane is `length 24 + r 6 = 30`. So the lane hit is 0 <= f <= 30, |s| <= 6. The warning is now drawn 0..30 from the centre (the first 6 studs run under its own body) and the server will use exactly that. Panel 6. | Outline shows all 4 corners; the fill is a 6 x 3 grid of ground-placed chunks. |
| 5 | Edge endpoints on the ground | Already true: `strip()` puts both ends through `onGround()` (helper attached). | - |
| 6 | Ball tangent at landing | `dia * 0.50`. | - |
| 7 | Tsunami lip | 3 lobes 3.7 x 1.1 x 2.2, tipped 50 deg forward, violet underside, lighter cyan. **Measured:** at your 0.65 x crest height the lip sat INSIDE the crest (crest top = h, its centre 0.2h): invisible. Now on the crest's top edge (0.92 h), 1.1 behind the front so its tip stays inside the lane; visible 3.10, fades with the crest by 4.30. Panel 7. | - |
| 8 | Melt puddle in radii | Your original radii restored (I'd misread them). | Cap 21.6 x 17.6 at 1.95, 25.0 x 21.0 at 2.25, 15 x 12 at 3.10. Panel 9. |
| 9 | Softer dome drop | Top oy -0.50 / -1.05 / -1.75 / -1.75. **Measured: the "brim" in panel 8 is NOT the dome drop.** I isolated it live: zero Top oy, zero Top rotation, lid untouched, tilt (root + body + top pitch) x 0.4: the brim stays in all of them. It's the dome's rear fin (visible at rest from this angle) plus the Body-weighted skin spreading while Top lowers. Kept your oy values. Your call: leave it (reads as goo spreading), or something else? |
| 10 | Bomb vs slam selection | Server/AI rule (no combat code yet): logged for the AI build: `slamReachable = d <= 16 and |theta| <= 60`, `bombEligible = d > 16 and d <= 30 and |theta| <= 30`. |
| 11 | Event order | Already: every attack's events are `table.sort`ed once at module load (end of the module), the Titan's included. |
| 12 | Defeat terminal | Melt caches each part's own LocalTransparencyModifier; a FINISHED defeat leaves the body hidden; only a cancelled/recycled one restores the cached values. The MOVE TEST repeat shows the body again at its t = 0. | LTM 1.00 at 3.79 and in the idle gap (4.25), 0.00 on the next repeat (0.33). |
| 13 | Puddle inside r = 5 | Lumps at 3.25 + (i % 2) * 0.35; puddle 9.7 x spread. | - |
| 14 | Loose objects | The 6 goo blobs now claim fragment slots (`claimFrag`, nil when full). The 16 motes stay anchored, non-colliding, non-query Neon balls (the same as batch 1's approved Colossus motes), outside the debris budget. | Two defeats at once: fragments <= 12 of 24, particles <= 14/s, 52 FX parts max, avg frame 7.2 ms, worst 12 ms. |
| 15 | Terrain sampling | All goo danger shapes (wedge, circle, lane, slam rings, bomb ring) read the ground through `memoGround`: one raycast per 0.5-stud cell per cast, then cached. | Two slams at once: avg 7.0 ms, worst 20 ms (Studio, desktop; was 23). Wave x2 worst 13, bomb x2 worst 12. |
| D | Sound mix | Not changed yet: James judges sound on his phone speaker; your test gains are logged for that pass. |

Panels 1-5 are from before the r1 code changes (unchanged visually except the wedge's inner 1.5 studs and the ball's last frame); 6-9 are new.

Budget, two Titans at once, after r1: particles/s max slam 24, defeat 14, tsunami 34 (the shared cap clamps it), bomb 32; lights 0; fragments 0 / 12 / 0 / 0.
