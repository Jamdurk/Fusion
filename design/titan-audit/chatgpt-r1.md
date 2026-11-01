# TITAN Batch 2 — Round 1 Audit

NO-GO — current source

Visual direction: promising. Timing: largely correct. Code integrity: not yet safe to approve.

The nine stills show a convincing heavy creature, particularly the Slam's two-tentacle impact and the Bomb's landing indicator. The measured corrections to ground penetration are sensible. However, I found a definite keyframe-indexing bug in the supplied Luau, plus several gameplay-boundary and cleanup issues that need addressing.

## 1. Critical source bug: three commented-out keyframe rows

This is the highest-priority fix.

In `titan-attacks.luau.txt`, lines 242, 301 and 437 contain comments followed by keyframe entries on the same physical line. Luau's `--` comments consume everything to the end of that line.

Consequently:

| Animation     | Intended front-chain keys | Actual keys | Consequence                                                                    |
| ------------- | ------------------------- | ----------- | ------------------------------------------------------------------------------ |
| Tentacle Slam | 10                        | 8           | 2.25 s receives the final neutral pose; 2.90 and 3.40 have no front-chain keys |
| Goo Bomb      | 8                         | 7           | Missing 2.85 s neutral front-chain pose                                        |
| Goo Tsunami   | 9                         | 8           | Missing 3.45 s front-chain recovery                                            |

These are not syntax errors: they can silently produce valid tables with incorrectly paired timestamps and poses.

Required change 1: Move all three comments onto separate lines and restore the omitted entries exactly as intended.

For Slam, restore:

```
{ { -7, 0, 3 }, { 4, 0, 4 }, { 9, 0, 5 } }, -- 2.25
{ { 4, 0, 5 }, { 2, 0, 3 }, { -2, 0, 2 } }, -- 2.90
{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, -- 3.40
```

For Bomb, restore the neutral 2.85 s front-chain row. For Tsunami, restore the neutral 3.45 s row.

Then assert the input-array lengths in `titanKeys()`:

```
assert(not front or #front == #rows, "Titan front key count mismatch")
assert(not back or #back == #rows, "Titan rear key count mismatch")
```

Also verify every generated key has all 12 tentacle-bone entries. This catches the same bug automatically in future animation batches.

The frozen stills remain useful evidence of the build's appearance, but the corrected source must be retested because the source currently supplied cannot produce every intended front-chain pose.

## 2. Timing contract audit

| Animation          | Required | Measured / coded                     | Result |
| ------------------ | -------- | ------------------------------------ | ------ |
| Slam warning       | 0.74     | 0.74                                 | PASS   |
| Slam hit           | 1.64     | 1.64                                 | PASS   |
| Slam unlock        | 3.40     | 3.40 + 0.25 blend                    | PASS   |
| Slam FX end        | 3.80     | 3.80                                 | PASS   |
| Bomb warning       | 2.40     | 2.40                                 | PASS   |
| Bomb release       | 2.55     | 2.55                                 | PASS   |
| Bomb hit           | 3.40     | 3.40                                 | PASS   |
| Bomb unlock        | 2.60     | 2.60                                 | PASS   |
| Bomb puddle expiry | 5.90     | Fade 5.55–5.90; visually gone \~5.80 | PASS   |
| Tsunami warning    | 2.10     | 2.10                                 | PASS   |
| Tsunami hit/unlock | 3.20     | 3.20                                 | PASS   |
| Tsunami FX end     | 5.30     | 5.30                                 | PASS   |
| Hurt               | 0.52     | 0.52                                 | PASS   |
| Defeat             | 3.80     | 3.80                                 | PASS   |

The animation timestamps are correctly represented in the definitions. These measurements do not independently prove that the server's damage timestamps and hitboxes match the client warnings.

The Slam's required 3.40-second lock versus its 3.80-second effect duration is handled correctly. The same applies to Bomb's 2.60-second unlock with a projectile still airborne. Preserve those separations.

## 3. FK and contact audit

### Tentacle Slam — retain the new FK correction

Decision: PASS the direction of the FK change; tighten the final ground contact.

The original F1 negative pitch was inappropriate once Body pitch and Root pitch were applied. The new values produce a more convincing grounded creature in still 2.

| Time | Front F1 `rx` | Front F2 `rx` | Decision |
| ---- | ------------- | ------------- | -------- |
| 1.64 | +18°          | -32°          | KEEP     |
| 1.86 | +27°          | -39°          | KEEP     |

The contact zone, approximately `x = ±3.8, z = -12.3`, is at a radial distance of 12.9 studs and safely inside the 16-stud wedge. The new keys preserve the body's forward lunge and the delayed heavy follow-through.

But the measured clearance is still 0.30–0.34 studs on the left and 0.60–1.00 on the right. At close range, the higher right tip can appear to strike empty space.

Required change 2: Keep the FK keys above. Add a small ground-height correction for the two front tips over 1.60–1.86 s:

- Begin correction at 1.60, reach full weight at 1.64.
- Maintain tip-to-ground clearance of 0.08–0.18 studs at 1.64–1.73.
- Fade correction out by 1.86.
- Permit at most 1.0 stud of tip-position correction and 12° of additional rotation at any joint.

If either chain cannot meet that tolerance, report an IK saturation instead of allowing the mesh to stretch unnaturally.

The proposed tip contact beginning at 1.54 in my first spec was overly early; your measured visible descent from 1.44 onward is fine. The crucial instant is the 1.64 impact.

### Bomb and Tsunami lunges

Decision: PASS their FK corrections.

Keep these keys:

| Action  | Time | F1 `rx` | F2 `rx` |
| ------- | ---- | ------- | ------- |
| Bomb    | 2.55 | +8°     | -25°    |
| Bomb    | 2.60 | +1°     | -22°    |
| Tsunami | 3.00 | +8°     | -18°    |
| Tsunami | 3.20 | +34°    | -40°    |

Your reported minimum tentacle height of -0.03 studs across the sweeps is acceptable as a negligible skin/contact tolerance.

The Bomb still reads as inflation followed by release. Tsunami still reads as a whole-body fold rather than an arm-only attack.

Restore the commented-out recovery keys before accepting that the entire transition is clean. The current file leaves parts of that recovery underdefined.

### Defeat drape

The correction from F1 negative pitch toward a positive root rotation is also appropriate: a melting tentacle should drape on the ground, not travel several studs through it.

Keep the 1.70 F1/F2 values of `+10°/-40°` and the 2.05 values of `+8°/-41°`. The final -0.09-stud penetration is negligible and becomes hidden during the proxy transition.

The problem with still 8 is primarily the dome, not the tentacles.

## 4. Danger shapes and gameplay readability

[RAW - CommunityDragon](https://images.openai.com/static-rsc-4/9oyxtUgBuX8UYu8_tbSbIr_xMm0A4q4hr1jAmExedxc2OLLPmgonjOXr-SZmFebY6iLwhkBMwxoeQUOG_N5Fi76FsA8K7AD8t_m6efjyNhXb79ewGgT1UR48UM2yAWIA7iZUhJlDshg1-2LcLF31cMj1PmcaB2HZfz_AVw_0cx8?purpose=inline)

Dark-teal fill: APPROVED. The choice `RGB(0,105,125)`, Neon, with transparency 0.72–0.42 is much better than a fully luminous cyan fill on this grey, sunlit terrain. Keep the bright cyan perimeter and dark underlay.

The important distinction in stills 1, 3 and 6 is that the boundary is readable before the interior effect becomes visually prominent. That is the right priority for a phone-focused PvP game.

### Slam wedge

The arc approximation with 32 segments is mathematically adequate: its maximum arc-to-chord error is approximately 0.0086 studs, below the 0.01-stud geometry tolerance specified previously.

However, `gooWedge()` draws both radial sides from radius 1.5 to 16, not from 0 to 16. The innermost 1.5 studs of each boundary are missing.

Required change 3: In `gooWedge()`, change both radial-edge starts from `1.5` to `0`. The Titan may cover those sections, but the geometry should still be complete.

### Bomb circle

The 28-sided circumscribed outline has a maximum vertex excess of approximately 0.032 studs at radius 5. That's negligible compared with its 0.36-stud line width. The inner rings look distinct in still 3.

PASS. Keep radius 5, three inward ripples, and the dark teal fill.

### Tsunami lane — gameplay mismatch requiring resolution

Your original approved animation geometry was:

`forward = 0..24, sideways = -6..+6`

The build instead calls:

```
gooLane(ctx, ctx.waveO, face, 6, 30, 6, 2.10, 3.20)
```

That is still a 24 × 12 rectangle, but translated 6 studs forward. It has the correct dimensions and the wrong origin relative to the approved specification.

This matters significantly in PvP: the first six studs are excluded and the last six are added.

Required change 4: Make the warning and server hitbox identical. My preferred solution is to retain the visually cleaner `6..30` lane only if the server's actual hit test is explicitly changed to `6 ≤ f ≤ 30` and the owner approves that gameplay-range change. Otherwise, revert the warning and visual hit coverage to `0..24`.

Do not ship with a `6..30` warning and a `0..24` server hit. The supplied files contain no server hit-test implementation, so that parity is not yet verified.

### Ground-conforming outlines

One more code issue: `gooEdge()` subdivides the original edge into segments no longer than 2 studs, but it does not itself raycast the segment endpoints. It passes interpolated points directly to `strip()`.

By contrast, the fill chunks explicitly use `onGround()`.

Required change 5: Unless the parent `strip()` helper already raycasts, do this inside `gooEdge()`:

```
local p = onGround(ctx, a:Lerp(b, (i - 1) / n))
local q = onGround(ctx, a:Lerp(b, i / n))
```

Preserve the existing 0.04-stud dark-underlay separation. Test on a sloped and cratered section, not just the flat test area.

## 5. Bomb, Tsunami and defeat FX

### Goo Bomb — PASS with one trajectory correction

In still 4, the ball reads as a distinct cyan/violet projectile. The 0.85-second flight, 5–9-stud arc rise and 3.6–4.4-stud diameter follow the design. Still 5 also confirms that the puddle is visibly different from the circular warning.

One geometry error is in the projectile's last position:

```
local p = from:Lerp(hit + Vector3.new(0, dia * 0.35, 0), u)
```

At impact, a sphere with radius `dia/2` has its centre only `0.35*dia` above the ground. Its bottom therefore penetrates the ground by `0.15*dia`, approximately 0.54–0.66 studs.

Required change 6: Change `dia * 0.35` to `dia * 0.50`. That makes the sphere tangent to the ground at its final frame, before the splat replaces it.

Keep the 0.85-second duration, trajectory peak, projectile size and puddle dissolve timing.

### Goo Tsunami — travel PASS, silhouette needs improvement

The previous visual snap-back has been fixed. The leading surge travelling 6→30 studs in 0.16 seconds and the crest then advancing a further 3 studs are continuous in the code.

However, still 7 shows four horizontal, rounded lobes at the far end of a nearly flat sheet. It reads more like a rolling blob or squashed tube than a 4.5-stud-high breaking wave.

This weakens the distinction between Bomb and Tsunami at mobile distance.

Required change 7: Add one upper curling lip row to the existing four crest lobes:

| Lip property          | Value                                |
| --------------------- | ------------------------------------ |
| New lobes             | 3                                    |
| Each lobe width       | 3.7 studs                            |
| Height                | 1.1 studs                            |
| Forward depth         | 1.8 studs                            |
| Forward rotation      | 50°                                  |
| Centre height at 3.20 | \~0.65 × crest height                |
| Leading offset        | 0.9 studs behind current crest front |
| Fade                  | With crest by 4.30                   |

Keep the lip within the committed warning lane at the 3.20 hit. After the hit, the cosmetic crest can continue its existing residual movement.

Add a thin violet underside to the lip for a more obvious overhang. Do not enlarge the attack hitbox or add another damage event.

### Defeat — the puddle was halved by mistake

This is an important correction to the build log.

My original specification explicitly labelled the puddle dimensions as X radius × Z radius, not diameters.

Your current `KT` values are half those specified. That explains why the resulting puddle in still 9 is so small compared with the Titan.

Required change 8: Replace the entire puddle key array with the original radii:

```
local KT = {
    { 1.86, 10.5, 8.5, 3.5 },
    { 2.10, 11.5, 9.5, 0.6 },
    { 2.25, 12.5, 10.5, 0.4 },
    { 3.10,  7.5, 6.0, 0.3 },
    { 3.55,  2.5, 2.0, 0.2 },
    { 3.80,  0.0, 0.0, 0.05 },
}
```

Keep your existing `cm.Scale = Vector3.new(rx*2, h*2, rz*2)` logic.

The corrected puddle will spread to a maximum width of 25 studs, rather than 12.5, fitting the collapse of a dome that is 21 studs wide.

The six little goo fragments and the staggered matter escape remain suitable.

### Motes — cumulative count PASS

The code does create exactly 16 motes, arranged into four groups beginning at 2.20, 2.45, 2.70 and 2.95.

The observation `4/8/12/12` is not necessarily an error: earlier motes fade before the last group appears, so all 16 need not be visible simultaneously. Sixteen distinct motes traverse their paths over the full sequence.

However, the two-Titan object budget needs separate attention below.

## 6. Answers to open questions A–D

| Question                     | Decision                 | Required action                                        |
| ---------------------------- | ------------------------ | ------------------------------------------------------ |
| A. Defeat brim               | SOFTEN                   | Reduce Top's downward translation at the collapse keys |
| B. Tsunami crest             | ADD LIP                  | Add the 3-lobe curling row specified above             |
| C. Bomb overlapping tentacle | ALLOW OCCASIONAL OVERLAP | Fix ability selection, not the minimum cast distance   |
| D. Sounds                    | HOLD AUDIO APPROVAL      | Test actual playback on a phone before signing off     |

### A — Defeat dome

Still 8 looks more like the dome has folded into a rigid shelf than a liquid mass losing cohesion.

Required change 9: Keep the Root and Body pose values, but change the absolute Top `oy` values:

| Time | Current | New   |
| ---- | ------- | ----- |
| 1.42 | -0.90   | -0.50 |
| 1.70 | -1.65   | -1.05 |
| 2.05 | -2.45   | -1.75 |
| 3.80 | -2.45   | -1.75 |

These are the fourth values in the Top pose rows, before `titanKeys()` converts them into relative translations.

The first 1.10-second wobble remains unchanged. Your six flattened tentacle poses can also stay.

With the corrected, larger melt puddle, the creature can appear to dissolve into the ground without compressing the dome quite so violently.

### B — Tsunami lip

Add the curling row described in change 7. The current crest is adequate as an underlying liquid mass, but lacks the upper overturn that would distinguish a tsunami from a generic goo projectile.

### C — Bomb range

A 14-stud target at 25° is already inside the Slam's 16-stud, ±60° wedge. Under normal ability selection, that target should not have triggered an out-of-reach Goo Bomb.

Required change 10: Use the existing melee eligibility test for automatic selection:

```
local slamReachable = d <= 16 and math.abs(theta) <= 60
local bombEligible = d > 16 and d <= 30 and math.abs(theta) <= 30
```

That assumes no other priority or cooldown rule overrides selection.

Do not impose a blanket 17-stud minimum without a combat reason. A target at 16.5 studs is outside Slam range but should still be a legal Bomb target.

A small cosmetic puddle overlap near the tentacles is tolerable, provided the Titan is unaffected by its own slow and the warning correctly shows the gameplay area.

### D — Sound approval

The source names match the intended sound categories, but I cannot judge the actual waveforms or mix from stills and source IDs.

Test the attack mix on a phone speaker at approximately 50% volume, including simultaneous attacks from two Titans.

For the first mix pass, try reducing the strongest Slam layers:

| Sound              | Current gain argument | Test gain |
| ------------------ | --------------------- | --------- |
| Slam wet slap      | 2.60                  | 1.30      |
| Slam thump         | 1.40                  | 0.70      |
| Slam splash        | 0.90                  | 0.45      |
| Tsunami hit splash | 1.60                  | 0.85      |
| Tsunami hit thump  | 1.20                  | 0.60      |

These are starting mix values, not measured loudness corrections. The final balance must be checked by ear, particularly whether the warning is audible and the impact remains distinct.

## 7. Remaining code and concurrency fixes

### Required change 11 — Sort Defeat events

The Defeat events at the end of the source are not in chronological order:

```
{ t = 3.20, ... },
{ t = 3.10, ... },
{ t = 3.75, ... },
```

Some event dispatchers scan every event independently; others process the ordered list until reaching a future timestamp. The latter implementation would delay the 3.10 bubbling event until 3.20.

Put them in this order:

`2.95 → 3.10 → 3.20 → 3.75`

Better still, sort the event table once when registering an attack. Do not rely on every future animation author manually maintaining order.

### Required change 12 — Prevent Defeat's hidden model reappearing

The melt event's `stop()` function unconditionally restores the original model's `LocalTransparencyModifier` to zero.

That is dangerous for a terminal animation. If the server hasn't destroyed the defeated model when the effect finishes, the monster can briefly reappear at 3.80 s.

Change the cleanup contract so:

- Normal terminal completion leaves the original model hidden until its destruction.
- Explicitly cancelled or recycled effects can restore the model's previous transparency.
- FX instances are destroyed at termination in either case.

Do not indiscriminately set every part's modifier to zero. Cache each part's original value and restore it only on an actual cancellation.

I cannot verify the parent animation manager's cancellation behaviour from this isolated file, so this needs an integration test.

### Required change 13 — Keep the sticky puddle inside radius 5

The puddle's five lumpy outer blobs are not guaranteed to remain within the radius-5 gameplay circle.

Currently, some have a centre offset of 4.2 studs and a half-width of up to 1.2 studs, extending approximately 5.4 studs from the centre.

Change:

```
local offset = 3.25 + (i % 2) * 0.35
```

Use `offset` instead of `3.7 + (i % 2) * 0.5`.

The largest lobe then extends no farther than approximately 4.8 studs.

Also reduce the main puddle diameter factor from `10` to `9.7` in its animated `pm.Scale` expression. With the existing ±3% wobble, that keeps its maximum radius just under 5.

Post-impact splash ripples may extend beyond radius 5; the persistent sticky surface should not imply a larger slow zone.

### Required change 14 — Correct the two-Titan loose-object accounting

The reported particle rates are acceptable relative to Batch 1's strict less-than-35/s ceiling:

| Two-Titan test | Reported particles/s | Result                |
| -------------- | -------------------- | --------------------- |
| Slam           | 24                   | PASS                  |
| Bomb           | 28                   | PASS                  |
| Tsunami        | 34                   | PASS, little headroom |
| Defeat         | 14                   | PASS                  |

But the Defeat report lists zero fragments, despite the source creating 6 scripted goo blobs and 16 motes per Titan.

Under a conservative interpretation of Batch 1's 24-loose-object limit:

- One defeat: 22 animated loose objects.
- Two defeats: 44 animated loose objects.

That exceeds the shared 24-object limit, even before considering the cap meshes.

For two simultaneous defeats, retain 16 visible matter motes per creature but render them through batched or grouped visual geometry rather than allocating all 32 independent Parts. A skinned effect mesh with 16 independently animated mote bones per Titan is one possible solution.

Alternatively, explicitly revise the budget contract to distinguish lightweight matter motes from heavy debris, and benchmark that revised limit on mobile. Do not report zero fragments without accounting for the objects the effect actually creates.

### Required change 15 — Reduce repeated terrain sampling in the Slam warning

This is the biggest potential performance issue after the keyframe bug.

Each frame, `gooWedge()` updates 48 fill strips, with two `onGround()` calls per strip: 96 terrain samples per Titan per frame.

While both 16-segment ripple arcs overlap, their additional terrain samples bring the potential total to roughly 160 per frame per Titan.

Two simultaneous Titans can therefore request approximately 320 terrain samples in a single frame, excluding other FX.

At 60 FPS that corresponds to a theoretical rate of 19,200 samples/second during the brief overlap.

Cache static ground heights for the wedge ahead of the warning, interpolating heights during the visual animation. A useful starting resolution is:

- 1-stud radial intervals from 0 to 16.
- 25 angular sample directions across the wedge.
- At most 10 precomputation raycasts per frame, distributed across the 0.74-second wind-up.

Then animate the fill and ripples using the cached heights instead of raycasting every visual frame. Recompute if the underlying terrain is actually modified.

Your measured 23 ms worst frame for two simultaneous Slams is about a 43 FPS frame, whereas 60 FPS requires a 16.7 ms budget. That measurement alone does not establish phone performance, but it warrants optimization before release.

## 8. Hurt mirroring and runtime safety

### Hurt: PASS

I inspected the supplied `addHurt()` implementation.

The side-swap expression correctly transforms names such as `TentFL3` into `TentFR3`. The `sg` inversion for `pushX`, followed by sign changes to `ry`, `rz` and `ox`, is appropriate for the specified asymmetric bone data.

Your measured root displacements of -0.135/+0.134 studs are effectively symmetric.

Do not rewrite the hurt mirroring logic. Retest during Slam impact with two Titans facing opposite directions, but no defect is evident in the supplied function.

### Additional checks before GO

There are three integration details I cannot fully prove from the files provided.

| Area             | Assessment                                                                                      | Required verification                                                        |
| ---------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| FX ownership     | Most visual handlers provide `stop()` cleanup and explicitly destroy their instances            | Interrupt effects at 1.0, 2.6 and 3.2 s; confirm no orphaned Parts or sounds |
| Concurrent casts | Most state is stored in per-event locals or `ctx`; no obvious shared mutable Titan effect table | Verify `ctx` is per cast, not shared across two Titans or successive Bombs   |
| Sound ramps      | Tsunami's `rush:step(t)` and `rush:stop()` operate inside the wave effect                       | Verify the parent scheduler does not also drive the same ramp twice          |

For Defeat motes, also sample ground height at each mote's actual horizontal start position instead of all 16 using the puddle centre's ground height. That avoids initial clipping on uneven terrain.

The event callbacks reference shared helpers such as `part`, `strip`, `soundRamp`, and `SND`, whose implementations are outside this excerpt. Consequently, this is a source inspection and measurement audit, not a successful standalone compilation or full runtime proof.

## 9. Final approval criteria

## Round 2 target

Do not rebuild the entire batch. Preserve the timing contract and most of the revised FK.

| Pose and animation direction | PASS with fixes  |
| ---------------------------- | ---------------- |
| Timing contract              | PASS             |
| Warning visual readability   | PASS             |
| Server geometry parity       | Unverified       |
| Defeat visual                | FIX              |
| Keyframe table integrity     | FAIL             |
| Hurt mirroring               | PASS             |
| Two-Titan FX budget          | Needs correction |

The biggest positive result is that the measured FK changes solved a genuine rigging issue without destroying the creature's heavy liquid movement. Don't revert those.

The decisive blockers are the malformed front-chain key tables, the mismatched Tsunami lane origin until server parity is established, the undersized defeat puddle, and the terminal cleanup/concurrency issues.

Verdict remains NO-GO for the current source. Once those specific corrections and the mobile/concurrent tests pass, this is a strong candidate for GO without another full animation redesign.

One last editorial correction: the build log says the puddle measurements were changed to diameters. They were explicitly specified as radii. An unfortunately consequential reading error when the creature is supposed to melt into a substantial pool of goo.
