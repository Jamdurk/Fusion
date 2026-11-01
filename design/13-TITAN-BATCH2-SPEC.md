# Titan animation batch 2 (28 Oct 2026): spec as built

Second per-alien batch (James: "Collousus is great. Yes start titan."). ChatGPT Thinking spec, full text in
`13-TITAN-BATCH2-SPEC-chatgpt-raw.md`. This file is what was BUILT and measured. Code:
`src\ReplicatedStorage.AlienFusion.Attacks.module.luau` (section "BATCH 2: the SQUISH TITAN"; `A.TSlam`, `A.Bomb`,
`A.Wave`, `A.THurt`, `A.TDefeat`, registered as `A.FOR.SquishF4v5`), `src\StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau`
(per-bone attack poses, per-form hurt with left/right chain swap, the tip-contact correction), MOVE TEST menu "TITAN (BATCH 2)".
Sheet: `shots\39-titan-batch2.jpg`. Audit trail: ChatGPT r1 NO-GO (15 changes, all handled) -> r2 (see BUILD-LOG).

## Timing contract (same marks as the Colossus)
| Move | Warning | Hit | Body free | Effects end |
|---|---|---|---|---|
| TENTACLE SLAM | 0.74 | 1.64 | 3.40 | 3.80 |
| GOO BOMB (aimed) | 2.40 | 3.40 (spit 2.55) | 2.60 | 5.90 (puddle 3.40-5.55) |
| GOO TSUNAMI (Order) | 2.10 | 3.20 | 3.20 | 5.30 |
| HURT | - | - | additive, 0.35 weight in a committed attack | 0.52 |
| DEFEAT | - | - | terminal (body stays hidden) | 3.80 |

## Danger shapes (SQUISH = smooth goo shapes; bright cyan line over a dark rim, dark-teal Neon fill)
- SLAM: exact 120-degree wedge, 16 from the centre (power graph: radius 10 + body 6), fill r = 16 * smooth((t-0.74)/0.9),
  cyan + mint ripple arcs at 1.34 / 1.49, two pulses 1.60-1.64.
- BOMB: smooth radius-5 circle on the aim point (fixed at 2.40), 3 inward violet/mint rings, mint centre dot.
- TSUNAMI: exact 12-wide rectangle, 0..30 from the centre (power graph: length 24 + body 6), fill advancing 2.10-2.75,
  3 swell lines 2.75-3.04.
- Built from ground-placed pieces (edges <= 2 studs, fills in chunks), ground read once per 0.5-stud cell (`memoGround`).
- Colours: cyan #37F5FF, violet #A56BFF, mint #A5FFD8, rim #28201B, fill RGB(0,105,125) Neon (cyan plastic vanished in sun,
  bright cyan Neon bloomed white). No lights, no camera shake.

## Measured deviations from the raw spec (the rig: tentacles hang off the Body bone, which pitches with the root)
- SLAM 1.64 F1 (18,2,1) F2 (-32,0,1); 1.86 F1 (27,1,-3) F2 (-39,0,-1) F3 (0,0,-4) + the animator's contact correction
  (front tips pulled to 0.13 above the ground 1.64-1.73, in 1.60-1.64, out 1.73-1.86, max 12 deg). Measured 0.13 / 0.13.
- BOMB 2.55 F1 (8,0,-2) F2 (-25,0,-3); 2.60 F1 (1,0,-2) F2 (-22,0,-1). TSUNAMI 3.00 F1 (8,2,4) F2 (-18,0,5);
  3.20 F1 (34,1,-4) F2 (-40,0,-6). DEFEAT 1.42 B1 rz +10; 1.70 F1 (10,0,-12) F2 (-40,0,-16); 2.05+ F1 (8,0,-15) F2 (-41,0,-14).
  Whole-move sweeps: lowest tentacle joint -0.09 to +0.02.
- DEFEAT dome oy (abs) -0.50 / -1.05 / -1.75 / -1.75 (softer than the spec's). Melt puddle in RADII (25 x 21 at 2.25).
- TSUNAMI crest + a 3-lobe curling lip on its top edge (0.92 x height), surge 6->30 in 3.04-3.20, collapse to 4.30.
- Lid: L >= 0 -> -175 * L/60 (60 = shut); negative L tucks it back -L * 0.5 degrees.

## Budget (two Titans, same move)
Particles/s <= 34 (shared cap), lights 0, fragments <= 12 (the defeat's 6 goo blobs each), avg frame ~7 ms (Studio desktop).
16 motes per defeat are anchored non-colliding markers, outside the debris budget (as batch 1).

## Open (not this batch)
- Sounds: library IDs (`A.GSOUNDS`), not yet judged on James's phone; ChatGPT's test gains: slam slap 1.30, thump 0.70,
  splash 0.45; tsunami splash 0.85, thump 0.60.
- Server combat: lane hit 0 <= f <= 30, |s| <= 6; bomb picks only targets the slam can't reach
  (`d > 16 and d <= 30 and |theta| <= 30`; slam `d <= 16 and |theta| <= 60`).
