# TITAN Batch 2 — Round 2 Re-audit

GO WITH CHANGES

The animation rebuild is substantially improved. Both geometry and animation pushbacks are accepted. The original keyframe-indexing failure is corrected, the tentacle contact measurements are within tolerance, and the revised defeat pool is the correct scale.

I would not request a third animation redesign. There are a few remaining source-integrity, contact and performance checks before calling the batch fully approved.

## 1. Verification of all 15 Round 1 changes

| #  | Fix                        | R2 finding                                                                                    |
| -- | -------------------------- | --------------------------------------------------------------------------------------------- |
| 1  | Lost keyframe rows         | PASS — rows restored; 10/8/9 pose times for Slam/Bomb/Wave, with assertions                   |
| 2  | Slam tip contact           | PASS at impact — both tips 0.13 studs above terrain                                           |
| 3  | Wedge radial edges         | PASS — both now start at radius 0                                                             |
| 4  | Tsunami lane parity        | ACCEPT PUSHBACK — explained below                                                             |
| 5  | Grounded outline endpoints | PASS — `strip()` calls `onGround()` for both                                                  |
| 6  | Bomb landing tangent       | PASS — endpoint now `dia * 0.50`                                                              |
| 7  | Crest lip                  | ACCEPT PUSHBACK — new height is correct for this mesh                                         |
| 8  | Defeat radii               | PASS — maximum footprint restored to 25 × 21 studs                                            |
| 9  | Dome drop                  | PASS — softened keys applied; brim requires no further pose change                            |
| 10 | Bomb/Slam targeting        | SPECIFIED, NOT IMPLEMENTED — AI/server combat remains future work                             |
| 11 | Event sorting              | PASS per build report — module-level sorting stated, though not included in the Titan excerpt |
| 12 | Terminal opacity           | PASS in measured Play loop — hidden at 4.25, restored for next test                           |
| 13 | Puddle radius              | PASS — lobes and main puddle now stay within approximately radius 5                           |
| 14 | Fragment budget            | PASS under current debris definition — 12/24 for two defeats                                  |
| 15 | Terrain cache              | IMPROVED — measured worst frame 23 → 20 ms; one issue remains in cache implementation         |

The reported Play measurements support the new poses and effects. The source confirms the keyframe tables, danger geometry, revised projectile, crest, puddle and most cleanup logic. The production server hit test and full parent animation scheduler were not included, so those cannot receive an independently verified pass.

## 2. Decisions on the pushbacks

### #4 — Tsunami lane: pushback accepted

Your power graph establishes that the Titan's 6-stud body radius extends the nominal 24-stud wave reach to 30 studs measured from its centre.

The revised warning is:

\\[ 0\le f\le30,\qquad -6\le s\le6 \\]

That is the correct visible shape for the gameplay definition you provided. The first six studs fall largely underneath the Titan, which is visually sensible for a wave originating in its body.

Keep the source call:

```
gooLane(ctx, ctx.waveO, face, 0, 30, 6, 2.10, 3.20)
```

I withdraw my previous request to shorten or move the lane. The important implementation requirement is that server combat uses the identical `0..30` forward interval and `±6` lateral interval.

### #7 — Curling lip: pushback accepted

Your measurement shows why my proposed `0.65 × h` placement failed: the upper lip was submerged inside the main crest.

Keep `0.92 × h`, the 1.1-stud backward offset, and the 50° forward rotation.

Panel 7 now has a visible overhanging lip and a more distinctive leading edge. It still has a simple, chunky Roblox silhouette rather than a physically realistic breaking wave, but that is appropriate for the intended presentation and FX budget.

No additional crest lobes are necessary.

### #9 — Defeat brim: leave it

[Water Elemental - 3D Model by SAN 3D Art](https://images.openai.com/static-rsc-4/LnTTNol2LIf8Zl0zfwkCXUeIBZ89Il6SCMNvHb1x9Wxyz6LrNm-GG7MwBv3XyDh4Q-wGHHlLlPsgz_Y-Fzg4PElFBHwNbTmBbwbqBY1p4T16tpqQc0EdDiMwTvIEx8HzpbY-r4VMM30rv2no_gSWBDvVt5ueyzZRm0pFxzhljwc?purpose=inline)

Stylistic reference only; the verdict is based on your supplied panel 8 and isolation measurements.

Your isolation test is decisive: eliminating Top translation, Top rotation and most pitch did not remove the horizontal protrusion. That strongly supports the rear-fin/skin-weight explanation rather than my previous diagnosis of excessive dome compression.

Keep these absolute Top `oy` values:

| Time | Value |
| ---- | ----- |
| 1.42 | -0.50 |
| 1.70 | -1.05 |
| 2.05 | -1.75 |
| 3.80 | -1.75 |

In panel 8, the brim is noticeable, but the creature already reads as collapsing. At 1.86 the geometry transitions into the melt proxy, so this silhouette is short-lived.

I would not alter skin weights or remove the rear fin to fix one 0.3–0.4-second transitional view. Leave the brim.

## 3. Contact correction code audit

The new solver is sound for this rig. It samples `TentFL3` and `TentFR3` after the FK pose, calculates the vertical error, adjusts each chain's first bone, then reapplies the pose.

| Interval                | Behaviour                             | Verdict |
| ----------------------- | ------------------------------------- | ------- |
| 1.60–1.64               | Smooth correction ramp                | PASS    |
| 1.64–1.73               | Full contact correction               | PASS    |
| 1.73–1.86               | Smooth release                        | PASS    |
| Correction cap          | ±12° per chain                        | PASS    |
| Measured saturation     | 0                                     | PASS    |
| Left/right independence | Separate measurements and corrections | PASS    |

The result of 0.13 studs above ground on both tips through the impact hold is precisely the contact tolerance requested.

Two minor cautions:

- `perDeg = 0.155` is a measured linear approximation, not a true IK Jacobian. It is validated for this rig and these poses, but not arbitrary terrain or different body scaling.
- `ContactOver` is only written during the correction window when `fz` is active. Reset it to `0` when entering a new Slam test, or an old diagnostic value could remain visible.

No rewrite of the contact solver is required.

## 4. Remaining required changes

### 1. Clean the supplied source copy

After `A.FOR.SquishF4v5`, the attachment includes diagnostic excerpts beginning with `1124:local function memoGround(ctx)` and `66:local function claimFrag(p)`.

Those lines are not executable Luau as written.

Because the measured Studio module loads successfully, I infer they were appended to the audit attachment to show shared helpers. Do not include them verbatim in the actual module. Keep the real helper definitions in their original source locations.

### 2. Make the terrain cache deterministic

`memoGround()` caches the height from the first arbitrary point sampled inside each 0.5-stud cell. Subsequent points in that same cell reuse that first height.

On sharply sloping terrain, the result can depend on sample order. It can cause small visible variations in ground-following lines.

Use a fixed sample coordinate per cell:

```
local ix, iz = math.floor(x * 2), math.floor(z * 2)
local key = ix .. ":" .. iz

if cache[key] == nil then
    cache[key] = g((ix + 0.5) * 0.5, (iz + 0.5) * 0.5)
end

return cache[key]
```

This also avoids relying on the numerical hash's coordinate-range assumptions.

Keep the 0.5-stud cache resolution. On steep crater slopes, test whether the resulting height approximation makes the outline clip into terrain by more than 0.10 studs. If it does, use locally finer sampling for those segments rather than globally increasing raycasts.

### 3. Align the four matter-escape sounds

Four matter groups start at:

`2.20 / 2.45 / 2.70 / 2.95`

The source's four whooshes currently occur at:

`2.45 / 2.70 / 2.95 / 3.20`

Move the whooshes to the four group-birth timestamps. Keep the chime at 2.20, but mix its gain below the first whoosh so the pair does not sound like two unrelated events.

### 4. Validate the remaining performance and combat integration

The measured 20 ms worst frame for two Slams is still above a 16.7 ms 60-FPS frame budget on desktop. That is not an automatic failure for the animation batch, but it does not establish mobile performance.

Before public release, use these acceptance targets:

- Two Titans performing Slam simultaneously on a representative phone: maintain at least 30 FPS through the effect.
- No repeated frames above 50 ms due to effect creation or terrain sampling.
- Server and client use identical captured wedge, circle and `0..30 × ±6` lane geometry.
- A 35%-weighted Hurt during Slam's 1.64–1.73 contact hold does not visibly lift or bury the tips.
- Interrupting or replacing an effect destroys its transient Parts and sounds without leaving the original defeated model visible.

The AI/server targeting rule remains specified but unimplemented; that is a separate gameplay integration requirement, not a reason to redesign these animations.

## 5. What James should inspect in Play

Five visual checks, in priority order

1. Slam: Do both tentacles appear to strike together at 1.64 s, or does one still look suspended despite the measured contact?
2. Tsunami: Is the curling lip distinguishable from the ordinary front tentacles at mobile camera distance?
3. Defeat: Does the rear fin read as part of the monster collapsing, rather than a rigid horizontal shelf?
4. Goo Bomb: Does the projectile clearly leave the mouth and land inside the marked circle, without an obvious visual jump at impact?
5. Audio: On phone speakers, can he distinguish the concentrated Slam slap, Bomb splat and extended Tsunami crash without distortion?

## Final verdict

GO WITH CHANGES — animation implementation accepted, final integration checks outstanding.

The important artistic and technical decisions are settled. The FK corrections are justified by measurements; the two pushbacks are valid; the danger shapes are now appropriate to the documented combat model; and the larger melt pool is the correct result.

I would freeze the pose and FX design after this round. No further geometry or keyframe redesign is warranted unless James sees a concrete problem during live gameplay.

One linguistic detail for the build log: “the dome brim” is better expressed as “the dome's brim”. Even a perfectly timed collapse deserves properly attached possessives.
