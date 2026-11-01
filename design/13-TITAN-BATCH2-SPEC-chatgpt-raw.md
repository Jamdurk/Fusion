# ALIEN FUSION — Animation Batch 2: SQUISH TITAN

Implementation specification — ready for Studio testing

Creature: SQUISH Titan (F4, 16 matter)\
Rig: 16 bones, sliding skirt, four 3-bone tentacles\
Animation language: Heavy liquid mass, delayed momentum, elastic overshoot, rippling recovery\
Reference contract: Approved CRUNCH Colossus Batch 1, 28 October 2026

## 1. Animation direction and timing contract

The Titan must not feel like the Colossus with different geometry. The Colossus moves by transferring weight through rigid limbs. The Titan moves by redistributing a large, viscous body, while its tentacles lag behind and then catch up.

Each attack needs a completely different silhouette:

[Ooze Blue Four Tentacles - Pathfinder 2E PFRPG PFSRD DND D&D 3.5 4E 5E 5th ed d20 fantasy](https://images.openai.com/static-rsc-4/KzpK1X01m-mQD4mh7waAiF_CDPPNAR0COjB9NnOqzLHvNPBqz2lY9dpRKGOtSW-TMrAYYVtMk8fpZBVSUSt4pbdDYV8TNJVSwBZo5jGYKXsrgJgFD0PhOmskRKW5QEmyrPs7a31A4Tw_Zx9wFllS52jUlByOD2YzqpIskMCFGIc?purpose=inline)

A — Tentacle Slam: CRUSH

Both front tentacles curl high, hesitate with their tips overhead, then whip down together. The dome lurches forward slightly after contact. The weight is in the downward impact, not a fast whole-body jump.

[Slime Ball by TrulyMalicious on DeviantArt](https://images.openai.com/static-rsc-4/ZC7U-KKxelFvi6EFlM2FmSYRfXN8GIxIR8ezH419YDLI4puh_MYDrR8oKraM7k_4ytK3iQ3dDOm2RpfyDiLuaqx9YEKU_8uPdHbdx-17dQ2Rd7cUePfywlhddZG56qOacTXSUnNGE7I20AiPin797bt-mLIT7x66eWkFr0pBSRg?purpose=inline)

B — Goo Bomb: TRAP

The dome inflates and the mouth area visibly bulges. The Titan spits one heavy, elastic sphere, then relaxes immediately. The projectile and sticky landing effect continue independently.

[Vibrant colorful ocean wave illustration | Premium Photo Illustration - rawpixel](https://images.openai.com/static-rsc-4/JqrH8u3T9zmP8RPK6rfq2Unej--ODtK5wUa1ZcahiBvxiz4tGFAbwj4HQ1vuJ21C2Xl8MPXUXqpSGW-P70f9rHrNrrjVRxvZ0rVYhJjUmR2gmgIqtlablKtApgqxTuM70h3_tJUrYMap0XcAB0zoEDaGqJp_KIcuX-0sUznYUYo?purpose=inline)

C — Goo Tsunami: OVERWHELM

The entire body stretches vertically. Tentacles spread into a broad wall. The monster folds forward and releases a rolling surge of goo through the lane.

The effects should communicate soft material, but the danger boundaries must communicate exact combat geometry.

### Three-clock contract

| Action        | Warning | Server hit | Body free | Effects gone |
| ------------- | ------- | ---------- | --------- | ------------ |
| Tentacle Slam | 0.74 s  | 1.64 s     | 3.40 s    | 3.80 s       |
| Goo Bomb      | 2.40 s  | 3.40 s     | 2.60 s    | 4.70 s       |
| Goo Tsunami   | 2.10 s  | 3.20 s     | 3.20 s    | 5.00 s       |
| Hurt          | —       | —          | No lock   | 0.52 s       |
| Defeat        | —       | —          | Terminal  | 3.80 s       |

The Goo Tsunami FX end at 5.00 s is a proposed cosmetic duration; the other three attack clocks follow the supplied power graph.

Critical rules:

- Combat uses server-authoritative `T0`, fixed geometry and predetermined hit timestamps.
- Actor poses can end before their world effects.
- On body unlock, return to locomotion over 0.25 s.
- Hurt is additive at 100% outside attacks and 35% during committed attacks.
- Defeat overrides all other poses. No attack or hurt animation can restart afterward.
- No jaw animation: the mouth cavity remains rigid. Goo Bomb uses dome deformation and a separate projectile.
- No bone scaling: the defeat melt ends with a mesh-to-puddle visual handoff.

## 2. Pose notation and implementation conventions

The full numeric tables below use the supplied rotation format.

`rot(bone, rx, ry, rz, ox, oy, oz)`

Angles are degrees; translations are studs.

| Symbol        | Meaning                                    |
| ------------- | ------------------------------------------ |
| `R`           | Root `[lift, side, fwd, pitch, roll, yaw]` |
| `D`           | Body `[rx, ry, rz]`                        |
| `T`           | Top `[rx, ry, rz; oy]`                     |
| `L`           | Lid `rx`                                   |
| `F1/F2/F3`    | FL1–FL3 and FR1–FR3, mirrored              |
| `B1/B2/B3`    | BL1–BL3 and BR1–BR3, mirrored              |
| `O`, `I`, `S` | Ease out, ease in, smoothstep              |

For mirrored tentacle keys, a value `(a,b,c)` means:

- Left side (`sx = +1`): `rot(a,b,c,0,0,0)`
- Right side (`sx = -1`): `rot(a,-b,-c,0,0,0)`

Thus positive `b` swings forward and positive `c` raises the tentacle on both sides.

`T` includes the Top vertical translation. Its neutral value is +0.75 studs, matching the current tall dome pose. Do not add another +0.75 on top of the table value. Hurt uses deltas from the current pose; the other animations use their own pose targets.

An all-zero rotation key represents neutral rotation. Root channels are neutral at zero.

For attacks, freeze the strong body-squash oscillation at cast start, preserve its current root ground position and blend into the authored attack. Small idle surface ripples may continue at roughly 20% amplitude. This prevents two incompatible deformation systems from fighting the same bones.

The tables are deliberately FK pose targets, not guaranteed tentacle contact solutions. Contact constraints described below take precedence at the specified impact frames.

## 3. Full attack key-pose tables

### A. TENTACLE SLAM — crush

Duration 3.40 s · Warning 0.74 s · Hit 1.64 s · 400 damage, 2.5× against Brute primary · Second target 25%

The front tentacles perform the attack; the rear pair stabilize the mass.

Primary pose table

`D` and `T` are rotation triples. `T` ends with its `oy` value.

| Time / ease | Root R             | Body D  | Top T        | Lid L |
| ----------- | ------------------ | ------- | ------------ | ----- |
| 0.00 S      | 0,0,0,0,0,0        | 0,0,0   | 0,0,0; .75   | 0     |
| 0.25 O      | -.18,0,-.12,5,0,0  | 6,0,0   | 4,0,0; .30   | -5    |
| 0.74 S      | 0,0,-.05,7,0,0     | 9,0,0   | 6,0,0; .95   | -10   |
| 1.16 O      | +.18,0,-.15,9,0,0  | 11,0,0  | 8,0,0; 1.18  | -12   |
| 1.44 I      | +.08,0,+.20,1,0,0  | -3,0,0  | -2,0,0; .95  | 0     |
| 1.64 I      | -.22,0,+.58,-7,0,0 | -11,0,0 | -8,0,0; .18  | 3     |
| 1.86 O      | -.30,0,+.66,-9,0,0 | -13,0,0 | -11,0,0; .08 | 6     |
| 2.25 O      | -.08,0,+.22,-2,0,0 | -4,0,0  | -2,0,0; .55  | 0     |
| 2.90 S      | +.05,0,-.05,2,0,0  | 2,0,0   | 1,0,0; .86   | 0     |
| 3.40 S      | 0,0,0,0,0,0        | 0,0,0   | 0,0,0; .75   | 0     |

Tentacle keys

Each parenthesized triple is `(rx, ry, rz)`. Mirroring follows the notation in §2.

| Time | F1         | F2        | F3        |
| ---- | ---------- | --------- | --------- |
| 0.00 | (0,0,0)    | (0,0,0)   | (0,0,0)   |
| 0.25 | (10,2,3)   | (8,1,5)   | (-8,0,6)  |
| 0.74 | (24,3,7)   | (22,1,11) | (-18,0,5) |
| 1.16 | (32,2,10)  | (25,0,14) | (-23,0,7) |
| 1.44 | (8,2,4)    | (6,0,8)   | (-5,0,2)  |
| 1.64 | (-23,2,1)  | (-5,0,1)  | (0,0,-2)  |
| 1.86 | (-27,1,-3) | (-8,0,-1) | (3,0,-4)  |
| 2.25 | (-7,0,3)   | (4,0,4)   | (9,0,5)   |
| 2.90 | (4,0,5)    | (2,0,3)   | (-2,0,2)  |
| 3.40 | (0,0,0)    | (0,0,0)   | (0,0,0)   |

| Time | B1       | B2       | B3       |
| ---- | -------- | -------- | -------- |
| 0.00 | (0,0,0)  | (0,0,0)  | (0,0,0)  |
| 0.25 | (-2,0,3) | (0,0,4)  | (0,0,5)  |
| 0.74 | (-4,0,5) | (0,0,7)  | (0,0,8)  |
| 1.16 | (-6,0,7) | (0,0,9)  | (0,0,12) |
| 1.44 | (1,0,8)  | (0,0,10) | (0,0,10) |
| 1.64 | (-5,0,4) | (0,0,5)  | (0,0,7)  |
| 1.86 | (-8,0,2) | (0,0,4)  | (0,0,5)  |
| 2.25 | (3,0,5)  | (0,0,6)  | (0,0,7)  |
| 2.90 | (1,0,2)  | (0,0,3)  | (0,0,3)  |
| 3.40 | (0,0,0)  | (0,0,0)  | (0,0,0)  |

Contact constraint — essential

The two front tips start roughly 11–12 studs forward from the body centre in the rest model. At the hit, the FK poses will bring them downward, but joint-space blending and dome pitching can move their exact contact points.

Use a temporary three-bone tentacle-tip IK correction from 1.54–1.80 s, reaching:

- FL3: local ground target `( +4.5, groundY, -9.5 )`
- FR3: local ground target `( -4.5, groundY, -9.5 )`

These are nominal targets relative to the locked attack origin and facing; raycast the local ground height. Both are approximately 10.5 studs radially from the attack origin and well inside the ±60° wedge.

Blend the tip constraint in over 0.10 s, maintain contact through 1.73, then release by 1.80. Limit correction to 18° at any tentacle joint. If the correction saturates, flag the contact measurement and adjust the FK keys rather than visibly stretching the tentacle.

The ground hit is server-timed at 1.64 s. The tentacle IK is visual only.

Motion quality: the front limbs accelerate into the floor, while the heavy dome reaches its deepest dip at 1.86 — 0.22 s after impact. That delayed dome movement is what sells weight.

### B. GOO BOMB — trap

Warning 2.40 s · Spit 2.55 s · Impact 3.40 s · Actor free 2.60 s · Range ≤30 studs

The Titan should feel like it is inhaling and building fluid pressure, not throwing something with its tentacles.

Primary pose table

| Time / ease | Root R                    | Body D | Top T        | Lid L |
| ----------- | ------------------------- | ------ | ------------ | ----- |
| 0.00 S      | 0,0,0,0,0,0               | 0,0,0  | 0,0,0; .75   | 0     |
| 0.40 O      | -.08,0,-.12,5,0,0         | 6,0,0  | 4,0,0; .95   | -5    |
| 1.25 S      | -.14,0,-.18,9,0,0         | 10,0,0 | 9,0,0; 1.35  | -9    |
| 1.85 O      | +.02,0,-.12,11,0,0        | 13,0,0 | 11,0,0; 1.55 | -13   |
| 2.32 S      | +.06,0,+.10,5,0,0         | 6,0,0  | 3,0,0; 1.35  | -8    |
| 2.55 I      | -.08,0,+(.35+.30k),-5,0,0 | -9,0,0 | -12,0,0; .60 | 4     |
| 2.60 O      | -.06,0,+(.25+.20k),-3,0,0 | -7,0,0 | -7,0,0; .55  | 3     |
| 2.85 S      | 0,0,0,0,0,0               | 0,0,0  | 0,0,0; .75   | 0     |

Here `k = clamp((distance - 12)/18, 0, 1)`. For targets at 12, 21 and 30 studs, the spit root-forward displacement is respectively 0.35, 0.50 and 0.65 studs.

Tentacle keys

| Time | F1        | F2        | F3       |
| ---- | --------- | --------- | -------- |
| 0.00 | (0,0,0)   | (0,0,0)   | (0,0,0)  |
| 0.40 | (3,0,3)   | (2,0,3)   | (0,0,2)  |
| 1.25 | (6,0,5)   | (4,0,6)   | (-3,0,4) |
| 1.85 | (8,0,7)   | (6,0,8)   | (-5,0,6) |
| 2.32 | (4,0,4)   | (3,0,5)   | (-2,0,3) |
| 2.55 | (-7,0,-2) | (-5,0,-3) | (4,0,-2) |
| 2.60 | (-5,0,-2) | (-3,0,-2) | (3,0,-1) |
| 2.85 | (0,0,0)   | (0,0,0)   | (0,0,0)  |

| Time | B1       | B2       | B3       |
| ---- | -------- | -------- | -------- |
| 0.00 | (0,0,0)  | (0,0,0)  | (0,0,0)  |
| 0.40 | (0,0,3)  | (0,0,4)  | (0,0,4)  |
| 1.25 | (-2,0,5) | (0,0,7)  | (0,0,8)  |
| 1.85 | (-3,0,7) | (0,0,10) | (0,0,12) |
| 2.32 | (-1,0,5) | (0,0,7)  | (0,0,9)  |
| 2.55 | (2,0,-2) | (0,0,-4) | (0,0,-5) |
| 2.60 | (1,0,-2) | (0,0,-3) | (0,0,-4) |
| 2.85 | (0,0,0)  | (0,0,0)  | (0,0,0)  |

Aiming layer

Acquire the target point at the beginning of the attack and keep it fixed.

For a target angle \\(\theta\\), measured positive to the Titan's left, define:

\\[ a=\operatorname{clamp}(\theta/30^\circ,-1,1) \\]

At full 30° deflection, distribute the aiming turn across:

| Layer | Yaw    |
| ----- | ------ |
| Root  | `10a°` |
| Body  | `8a°`  |
| Top   | `12a°` |

Apply the full aim progressively from 0.40 to 1.85 s, then hold through 2.55. The complete 30° distributed turn is achieved without visually twisting the entire dome sideways in one instant.

The FK table remains the additive pitch/lean pose; the aiming yaw is applied separately and must not be overwritten by zero `ry` entries.

The animated mouth should be directed at the captured target. Compute the projectile launch point from the posed monster at 2.55 s, rather than using an unrotated model-space point.

Important lock separation: at 2.60 the body can start another action or return to walking, but the projectile, target circle and puddle remain world-anchored and continue until their own end times.

### C. GOO TSUNAMI — overwhelm

ORDER ability · Warning 2.10 s · Hit 3.20 s · 24 × 12 stud lane · Body free 3.20 s

Unlike the Slam, which concentrates energy into two limbs, Tsunami visibly involves the whole creature.

Primary pose table

| Time / ease | Root R              | Body D  | Top T         | Lid L |
| ----------- | ------------------- | ------- | ------------- | ----- |
| 0.00 S      | 0,0,0,0,0,0         | 0,0,0   | 0,0,0; .75    | 0     |
| 0.45 O      | -.12,0,-.10,5,0,0   | 7,0,0   | 6,0,0; .90    | -5    |
| 1.10 S      | +.20,0,-.16,10,0,0  | 12,0,0  | 9,0,0; 1.35   | -9    |
| 1.70 O      | +.42,0,-.22,14,0,0  | 17,0,0  | 12,0,0; 1.70  | -12   |
| 2.10 S      | +.45,0,-.24,15,0,0  | 19,0,0  | 14,0,0; 1.90  | -14   |
| 2.65 I      | +.22,0,+.08,5,0,0   | 6,0,0   | 4,0,0; 1.40   | -5    |
| 3.00 I      | -.06,0,+.45,-6,0,0  | -10,0,0 | -12,0,0; .50  | 3     |
| 3.20 I      | -.42,0,+.80,-10,0,0 | -17,0,0 | -18,0,0; -.40 | 8     |
| 3.45 O      | 0,0,0,0,0,0         | 0,0,0   | 0,0,0; .75    | 0     |

Tentacle keys

| Time | F1         | F2         | F3         |
| ---- | ---------- | ---------- | ---------- |
| 0.00 | (0,0,0)    | (0,0,0)    | (0,0,0)    |
| 0.45 | (5,1,3)    | (5,0,5)    | (-3,0,4)   |
| 1.10 | (14,2,8)   | (12,0,10)  | (-8,0,8)   |
| 1.70 | (23,4,12)  | (20,0,16)  | (-14,0,11) |
| 2.10 | (28,5,15)  | (24,0,19)  | (-17,0,13) |
| 2.65 | (12,4,12)  | (9,0,15)   | (-8,0,10)  |
| 3.00 | (-10,2,4)  | (-12,0,5)  | (-4,0,3)   |
| 3.20 | (-28,1,-4) | (-19,0,-6) | (5,0,-8)   |
| 3.45 | (0,0,0)    | (0,0,0)    | (0,0,0)    |

| Time | B1        | B2       | B3       |
| ---- | --------- | -------- | -------- |
| 0.00 | (0,0,0)   | (0,0,0)  | (0,0,0)  |
| 0.45 | (0,0,5)   | (0,0,8)  | (0,0,8)  |
| 1.10 | (-2,0,10) | (0,0,14) | (0,0,15) |
| 1.70 | (-5,0,15) | (0,0,21) | (0,0,24) |
| 2.10 | (-6,0,18) | (0,0,24) | (0,0,27) |
| 2.65 | (-2,0,16) | (0,0,21) | (0,0,23) |
| 3.00 | (4,0,8)   | (0,0,12) | (0,0,14) |
| 3.20 | (-8,0,-2) | (0,0,-6) | (0,0,-9) |
| 3.45 | (0,0,0)   | (0,0,0)  | (0,0,0)  |

At 2.10 the rear tentacles form a tall, wide silhouette, while the two front tentacles are lifted like a curtain. The body should look briefly taller and more threatening than its idle form.

From 2.65 to 3.20, the entire form folds forward in one accelerating movement. The tentacles lag behind the dome by approximately 0.08–0.12 s, which can be implemented as a small interpolation delay, not by changing combat timestamps.

At 3.20, the main wave is created and the server resolves its hit. It is not necessary for the entire visual wave to disappear at the same moment; the residual liquid motion continues after the actor regains control.

For both Tsunami and Slam, ground penetration should be caught by a local skirt contact constraint, preserving the large-body compression without allowing the dome mesh to pass through the terrain.

## 4. HURT — additive impact reaction

0.52 s · No stun · 192-damage trigger · 0.65 s cooldown · 35% weight during attacks

The Titan should absorb damage like a giant liquid-filled balloon: an indentation, a brief sideways displacement, then a small rebound.

Unlike the Colossus, it should not jerk rigidly at every joint.

For the following asymmetric pose, the hit pushes the Titan toward model `+X`. Mirror lateral translations, roll, yaw and left/right tentacle entries for the opposite direction. Frontal impacts may reduce the lateral component by 70% while preserving the compression.

Primary pose table — additive deltas

| Time / ease | Root R                 | Body D  | Top T         | Lid L |
| ----------- | ---------------------- | ------- | ------------- | ----- |
| 0.00 S      | 0,0,0,0,0,0            | 0,0,0   | 0,0,0; 0      | 0     |
| 0.05 O      | -.05,+.06,-.04,1,-2,1  | -1,1,-2 | -2,1,-3; -.06 | 5     |
| 0.13 I      | -.14,+.14,-.09,3,-4,3  | -3,2,-5 | -4,3,-7; -.16 | 13    |
| 0.24 S      | -.08,+.08,-.04,-1,2,-1 | 2,-1,2  | 3,-1,4; -.06  | 7     |
| 0.40 S      | 0,+.02,0,0,-1,0        | -1,0,-1 | -1,0,-1; +.02 | 0     |
| 0.52 S      | 0,0,0,0,0,0            | 0,0,0   | 0,0,0; 0      | 0     |

Asymmetric tentacle keys

Here the triples are literal bone rotations, not mirror-template values. `F+` means FL1/FL2/FL3 and `F-` means FR1/FR2/FR3. The same convention applies to `B+` and `B-`.

| Time | F+ chain                       | F- chain                        |
| ---- | ------------------------------ | ------------------------------- |
| 0.00 | (0,0,0); (0,0,0); (0,0,0)      | (0,0,0); (0,0,0); (0,0,0)       |
| 0.05 | (-3,1,2); (-2,0,2); (2,0,2)    | (1,-1,-4); (2,0,-3); (2,0,-3)   |
| 0.13 | (-8,2,-3); (-6,0,-4); (4,0,-4) | (4,-2,-8); (5,0,-7); (-3,0,-6)  |
| 0.24 | (3,1,3); (4,0,4); (-2,0,3)     | (-3,-1,-5); (-2,0,-4); (3,0,-4) |
| 0.40 | (-1,0,1); (-1,0,1); (0,0,1)    | (1,0,-1); (1,0,-1); (0,0,-1)    |
| 0.52 | (0,0,0); (0,0,0); (0,0,0)      | (0,0,0); (0,0,0); (0,0,0)       |

| Time | B+ chain                      | B- chain                       |
| ---- | ----------------------------- | ------------------------------ |
| 0.00 | (0,0,0); (0,0,0); (0,0,0)     | (0,0,0); (0,0,0); (0,0,0)      |
| 0.05 | (-2,0,2); (0,0,3); (0,0,3)    | (1,0,-4); (0,0,-4); (0,0,-4)   |
| 0.13 | (-5,0,-4); (0,0,-6); (0,0,-7) | (4,0,-9); (0,0,-11); (0,0,-12) |
| 0.24 | (3,0,4); (0,0,5); (0,0,6)     | (-2,0,-5); (0,0,-6); (0,0,-7)  |
| 0.40 | (-1,0,1); (0,0,2); (0,0,2)    | (1,0,-2); (0,0,-2); (0,0,-2)   |
| 0.52 | (0,0,0); (0,0,0); (0,0,0)     | (0,0,0); (0,0,0); (0,0,0)      |

Hurt blending: apply the additive deltas before ground-contact constraints. During Slam, the tentacle-tip IK correction must still keep the attacking tips on the ground. During Bomb or Tsunami, reduce visual reactions but never delay the committed server ability.

The 13° lid movement is only a partial flinch blink. It must not fully close the eye; the eye remains an important readability feature at mobile distance.

## 5. DEFEAT — wobble, collapse, melt

3.80 s · Terminal state · 16 cyan matter motes · No gore

The creature should look momentarily confused, wobble as if its internal structure is failing, then progressively lose cohesion.

A rigid falling animation would be the wrong choice. Its legs do not buckle because it has no legs.

Primary pose table

| Time / ease | Root R                 | Body D  | Top T          | Lid L |
| ----------- | ---------------------- | ------- | -------------- | ----- |
| 0.00 S      | 0,0,0,0,0,0            | 0,0,0   | 0,0,0; .75     | 0     |
| 0.16 O      | -.10,+.12,-.08,-3,-2,2 | -2,2,-3 | -3,3,-4; .65   | 8     |
| 0.48 O      | -.25,-.24,-.12,5,5,-3  | 6,-2,8  | 7,-4,10; .92   | 0     |
| 0.80 S      | -.13,+.18,+.05,-2,-4,4 | -4,3,-7 | -5,3,-8; .58   | 18    |
| 1.10 I      | -.42,-.22,+.12,7,4,-3  | 8,-1,6  | 11,-2,8; .15   | 33    |
| 1.42 I      | -.72,+.10,+.25,10,-3,1 | 11,0,-6 | 12,1,-7; -.90  | 54    |
| 1.70 O      | -.92,-.09,+.32,3,2,0   | -9,0,4  | -11,0,6; -1.65 | 60    |
| 2.05 S      | -1.02,0,+.20,0,0,0     | -4,0,0  | -6,0,0; -2.45  | 60    |

Tentacle keys

| Time | F1          | F2          | F3         |
| ---- | ----------- | ----------- | ---------- |
| 0.00 | (0,0,0)     | (0,0,0)     | (0,0,0)    |
| 0.16 | (5,2,2)     | (2,0,3)     | (-4,0,2)   |
| 0.48 | (-4,4,-2)   | (7,0,9)     | (-8,0,8)   |
| 0.80 | (8,-2,8)    | (-4,0,4)    | (6,0,4)    |
| 1.10 | (-12,2,-4)  | (-5,0,-8)   | (9,0,-7)   |
| 1.42 | (-19,1,-8)  | (-15,0,-12) | (12,0,-9)  |
| 1.70 | (-25,0,-12) | (-21,0,-16) | (15,0,-12) |
| 2.05 | (-32,0,-15) | (-26,0,-14) | (18,0,-10) |

| Time | B1          | B2        | B3        |
| ---- | ----------- | --------- | --------- |
| 0.00 | (0,0,0)     | (0,0,0)   | (0,0,0)   |
| 0.16 | (-2,0,5)    | (0,0,7)   | (0,0,6)   |
| 0.48 | (5,0,10)    | (0,0,15)  | (0,0,17)  |
| 0.80 | (-5,0,6)    | (0,0,8)   | (0,0,10)  |
| 1.10 | (-7,0,-6)   | (0,0,-10) | (0,0,-14) |
| 1.42 | (-10,0,-12) | (0,0,-17) | (0,0,-20) |
| 1.70 | (-12,0,-16) | (0,0,-22) | (0,0,-25) |
| 2.05 | (-15,0,-19) | (0,0,-25) | (0,0,-28) |

The large negative `Top.oy` values are intentional translations of the dome, not scaling. The tentacles gradually flatten outwards into the floor.

The 2.05 pose is the last important pose on the original rig. It is not expected to turn a 14.2-stud-tall skinned mesh into a flat puddle by itself.

### Defeat sequence and visual handoff

1. 0.00–0.80: Instability. Two large sideways wobbles, deliberately unequal. The eye remains open at first. The rear tentacles briefly curl up, then lose their coordinated posture.
2. 0.80–1.42: Collapse begins. The dome sags, the lid closes progressively, and the front tentacles flatten. At 1.42 the eye is nearly closed and the character's centre of mass is visibly lower.
3. 1.42–2.10: Melt. A simple proxy goo-cap mesh grows from the bottom of the body between 1.86 and 2.10. Simultaneously fade the original skinned body and tentacles into that cap. The cap compresses downward into a wide puddle. By 2.10 the original rig is hidden.
4. 2.20–3.45: Matter escapes. Exactly 16 bright cyan motes leave the puddle in four groups of four, spiralling upward and then streaking toward their owner's home base.
5. 3.10–3.80: Dissolution. The puddle contracts and becomes transparent. At 3.80 no original monster geometry, proxy, mote or debris remains.

The lid-closing rotations above assume positive `Lid.rx` closes the eye. If the lid mesh was authored in the opposite orientation, invert only the Lid channel; do not change the timing.

The goo-cap transition is an essential extra implementation step, because the 16-bone rig has no true vertex-scaling or morph-target control. Trying to simulate the whole melt through joint rotations alone would result in a crumpled but still recognizably solid dome.

## 6. SQUISH danger shapes — exact geometry

The danger shapes should look like water, slime and elastic membranes, rather than the Colossus's fractures and jagged rock markings.

However, the soft visual language must not reduce hitbox clarity.

### Palette and rendering rules

Cyan

\#37F5FF

Violet

\#A56BFF

Mint

\#A5FFD8

Dark rim

\#28201B

Use an opaque-enough dark underlay behind bright outlines, as established in the approved Colossus testing. The Titan's underlay should be a dark neutral rather than more cyan, because the map's sunlit ground and the creature's highly saturated textures can otherwise make the warning disappear.

Outline geometry uses a dark strip approximately 0.30 studs wider than the bright line, placed 0.04 studs lower. The bright line itself should remain on the exact boundary centreline. Avoid dynamic lights; emissive colour and transparency are sufficient.

### A. Tentacle Slam — 120° wedge

Geometry schematic, not to character scale. The full outer arc and both radial edges are visible from the first warning frame.

Server hit test

Let `O` be the ground-projected attack origin, `F` the locked forward direction, and `V` the horizontal vector from `O` to the candidate target.

\\[ |V|\le16,\qquad \frac{F\cdot V}{|V|}\ge\cos60^\circ=0.5 \\]

Targets at the exact boundary are included. At the origin, handle the zero-length vector separately.

Timing

| Time      | Warning action                                                                   |
| --------- | -------------------------------------------------------------------------------- |
| 0.74      | Whole wedge boundary appears instantly, cyan line 0.42 studs, dark underlay 0.72 |
| 0.74–1.34 | Semi-transparent goo fill expands radially through the wedge                     |
| 1.34      | First rounded ripple travels outward                                             |
| 1.49      | Second ripple, brighter mint inner line                                          |
| 1.60–1.64 | Entire boundary brightens, 2 rapid pulses                                        |
| 1.64      | Server hit; warning disappears, contact splash begins                            |
| 1.64–2.15 | Non-damaging goo ripples spread and fade                                         |

Fill radius:

\\[ r(t)=16\\,\operatorname{smoothstep}\left(\frac{t-0.74}{0.90}\right) \\]

Use at least 48 segments across the 120° arc. That gives less than 0.01 stud of radial geometric approximation error at the maximum radius. Never animate the actual outer boundary inward.

### B. Goo Bomb — fixed circular landing zone

Server geometry

The hit is a circle of radius 5 studs, centred on the captured ground target `P`:

\\[ (x-P_x)^2+(z-P_z)^2\le25 \\]

Visual features:

- Full smooth circle; not an octagon.
- Bright cyan outer circumference, 0.36 studs wide, with darker underlay 0.66.
- Three concentric, violet-to-mint ripples drawn inside the circle.
- A soft central landing dot.
- Liquid fill stays inside the danger circle.

| Time      | Warning action                                            |
| --------- | --------------------------------------------------------- |
| 2.40      | Entire radius-5 boundary appears                          |
| 2.40–2.90 | Fill opacity rises from 0.15 to 0.28                      |
| 2.90–3.20 | Three interior circular ripples animate toward the centre |
| 3.20–3.40 | Mint centre flashes twice; fill rises to 0.40             |
| 3.40      | Projectile lands; hit resolves; danger circle disappears  |
| 3.40–5.90 | Sticky puddle persists for its 2.50 s lifetime            |

The shrinking interior ripples are decorative. The actual five-stud boundary never changes size or centre.

Timing correction to §1: because the bomb leaves a puddle lasting 2.5 seconds after its 3.40-second impact, its world effect cannot end at the Colossus Boulder Hurl's 4.70-second mark. The correct Goo Bomb world-effect end is 5.90 s, with pooled visuals fully cleaned immediately afterward.

### C. Goo Tsunami — exact rectangular lane

Server geometry

Use a fixed 24-stud-forward by 12-stud-wide rectangle.

Let `F` be the locked forward vector and `S` its perpendicular sideways vector.

For a target position `X`, project into:

\\[ f=(X-O)\cdot F,\qquad s=(X-O)\cdot S \\]

Hit if:

\\[ 0\le f\le24,\qquad |s|\le6 \\]

This is a rectangle, not a rounded capsule. The warning may contain round ripples, but the outer line must show the rectangular limits, including the four corners.

| Time      | Warning action                                         |
| --------- | ------------------------------------------------------ |
| 2.10      | Entire 24 × 12 rectangle appears immediately           |
| 2.10–2.75 | Liquid fill advances from the Titan toward the far end |
| 2.75–3.04 | Three transverse swell lines pulse forward             |
| 3.04–3.20 | Main leading wave rapidly covers the full lane         |
| 3.20      | Server resolves the entire lane simultaneously         |
| 3.20–4.70 | Non-damaging residual rolling goo and foam             |
| 5.20      | Enemy slow expires; gameplay effect complete           |

The main danger lane does not change dimensions. The leading wave uses the same spatial limits.

Important visual/combat alignment: a slowly travelling wave that reaches the far end after 3.20 would make distant enemies appear to take damage before the wave touches them. Instead, the fast leading surge traverses the lane from 3.04 to 3.20 — about 150 studs/s — so the full lane is visibly engulfed at the server hit timestamp. A slower, taller secondary rolling crest provides the spectacle afterward but causes no additional damage.

The slow lasts 2.0 s after the hit, so the world-effect expiry must be at least 5.20 s. Use 5.30 s for the final visual fade and cleanup, superseding §1's preliminary 5.00-second cosmetic end.

## 7. Goo Bomb projectile — exact trajectory

### Launch

The projectile originates near the fixed mouth cavity, at approximately:

`M_local = (0, 8, -6.5)`

At 2.55 s, transform that point using the actual posed model transform, including the aim layer. The launch point is captured once. No further attachment to the head or body.

Projectile dimensions

| Property             | Value                                                |
| -------------------- | ---------------------------------------------------- |
| Main sphere diameter | 3.6 studs near, 4.4 studs far                        |
| Colour               | Electric cyan shell, violet interior                 |
| Highlight            | Mint crescent, low-intensity emissive                |
| Flight duration      | Exactly 0.85 s                                       |
| Rotation             | 1.25 turns over the flight                           |
| Stretch              | Up to 18% along its flight tangent                   |
| Impact deformation   | Flatten to 40% height, expand 1.4× width over 0.12 s |

The sphere should be an elongated, wobbling lump rather than a hard, perfectly spherical energy projectile.

### Arc by target distance

Use the same basic ballistic-looking curve as the approved Colossus Boulder Hurl.

\\[ k=\operatorname{clamp}((d-12)/18,0,1) \\]

\\[ H=5+4k \\]

| Distance | Arc rise above chord | Sphere diameter |
| -------- | -------------------- | --------------- |
| 12 studs | 5.0 studs            | 3.6 studs       |
| 21 studs | 7.0 studs            | 4.0 studs       |
| 30 studs | 9.0 studs            | 4.4 studs       |

For `u = clamp((t - 2.55)/0.85,0,1)`:

\\[ P(u)=(1-u)M+uP\_{\mathrm{target}}+4Hu(1-u)\hat{Y} \\]

`P_target` is the fixed landing position on the ground.

This is a deterministic visual curve. The server should not rely on a simulated projectile collision to establish the hit.

### Projectile and puddle sequence

| Time      | Visual                                                         |
| --------- | -------------------------------------------------------------- |
| 1.85      | Small cyan pressure bulge appears directly in the mouth cavity |
| 2.32      | Bulge expands to \~1.6-stud radius, with two surface ripples   |
| 2.55      | Goo sphere detaches and begins its arc                         |
| 2.60      | Mouth bulge collapses; actor becomes free                      |
| 3.40      | Sphere splats into its captured ground point                   |
| 3.40–3.55 | Sphere flattens and resolves into the sticky puddle            |
| 3.55–5.55 | Persistent puddle with slow internal ripples                   |
| 5.55–5.90 | Puddle dissolves, visual and gameplay lifetime end             |

Puddle geometry: a flat radius-5 circular goo patch, approximately 0.12–0.22 studs thick. Give it a slightly scalloped surface texture, but keep its actual gameplay area circular.

The sticky slow is 25%. I recommend keeping the area active from 3.40–5.90 with the server as the sole authority; whether entering the puddle later refreshes the slow is a combat design decision, not an animation decision. The animation must not silently change that rule.

At impact, one mint-coloured ring expands across the radius-5 zone over 0.18 s. The ring is not a second hit.

## 8. Goo Tsunami — rolling wave implementation

The wave needs to read as a mass of goo being released, not a blue laser or a standard translucent rectangular projectile.

### Wave construction

Use a pooled, low-poly or procedural mesh ribbon with a rounded leading crest and a low, connected liquid body behind it.

| Property               | Value                     |
| ---------------------- | ------------------------- |
| Gameplay lane          | 24 long × 12 wide         |
| Main wave visual width | 11.5 studs                |
| Leading crest height   | 4.5 studs                 |
| Trailing liquid height | 0.5–1.5 studs             |
| Leading crest depth    | 3.0 studs                 |
| Crest roll             | Approximately 65° forward |
| Crest onset            | 3.04 s                    |
| Full lane engulfed     | 3.20 s                    |
| Secondary roll         | 3.20–4.30 s               |
| Foam and residue       | Fade by 5.30 s            |

### How it rolls

Side-profile schematic: low connected body, thick rolling crest, and rounded foam ripples.

- 3.04–3.20: A relatively low, fast surge runs from the Titan's front to the end of the 24-stud lane. Its leading crest is about 2.5 studs high during this initial sweep.
- 3.20: The entire lane is engulfed; the server performs its one hit check. A stronger 4.5-stud crest appears as part of the impact.
- 3.20–4.30: A rolling, taller secondary crest follows, folding and redistributing the liquid within the lane. No second hit.
- 4.30–5.30: The wave collapses into flatter ripples and dissipates.

Make the wave's material mostly cyan with darker violet pockets and occasional mint highlights. Avoid a solid white crest; it would overpower the character and obscure smaller opponents.

The wave has no need for dozens of independently simulated goo blobs. A small number of connected mesh sections animated with sine offsets and timed transforms should produce the desired result at much lower cost.

### Server hit order

At 3.20, determine all targets within the captured rectangle. Select the first big enemy using the established target-ordering rule, then apply:

- Primary: 300 damage, or 750 if the primary is a Brute.
- Up to three additional enemies: 60 damage each.
- Affected targets: 25% slow for 2.0 seconds.

The animation should not choose enemies, calculate damage or independently decide whether the wave hit. The game server handles all of that.

## 9. Defeat puddle and 16 escaping matter motes

### Puddle transformation

Use a simple pooled liquid mesh, separate from the skinned Titan.

| Time | Puddle footprint, X radius × Z radius | Appearance                        |
| ---- | ------------------------------------- | --------------------------------- |
| 1.86 | 10.5 × 8.5                            | Emerging beneath the sagging body |
| 2.10 | 11.5 × 9.5                            | Original model fully hidden       |
| 2.25 | 12.5 × 10.5                           | Maximum spread                    |
| 3.10 | 7.5 × 6.0                             | Shrinking, dimming                |
| 3.55 | 2.5 × 2.0                             | Thin remaining pool               |
| 3.80 | 0 × 0                                 | Gone                              |

This is not a damage zone; its irregular perimeter is purely cosmetic.

Keep thickness under 0.35 studs through most of the sequence. Its centre can briefly rise to 0.50 studs as it collects the collapsing dome.

### Sixteen matter motes

Exactly 16 scripted objects, not an uncontrolled particle emitter.

2.20 s

4 motes

2.45 s

4 motes

2.70 s

4 motes

2.95 s

4 motes

Each mote:

- Begins within 4 studs of the puddle centre.
- Has a cyan luminous core, 0.25–0.38 studs diameter, with a mint halo.
- Rises 1–4 studs, following a curved path.
- Turns toward the owning home base.
- Streaks approximately 45 studs toward home at a visually accelerated speed, then fades.
- Has no `PointLight`, no physics collision and no particle emitter.

By 3.45, all 16 have completed their initial escape streaks. The remaining puddle fades by 3.80.

If home is farther than 45 studs, the streak can fade while continuing in the correct direction. The client animation does not determine whether the player's matter is refunded or transferred.

The entire defeat should remain cheerful and readable, even if the monster is enormous. No explosions, dismemberment or disturbing organic detail.

## 10. Sound design — ProSoundEffects library

Use category-matched sounds from the existing ProSoundEffects collection. The labels below describe the sound to select, not invented asset IDs.

### Tentacle Slam

| Time | Sound                           | Character             |
| ---- | ------------------------------- | --------------------- |
| 0.00 | Low wet gurgle                  | Heavy anticipation    |
| 0.25 | Deep rubber stretch             | Tentacles lifting     |
| 0.74 | Quiet liquid pressure tone      | Warning activation    |
| 1.16 | Sticky suction / elastic strain | High wind-up          |
| 1.44 | Short, fast whoosh              | Downward acceleration |
| 1.64 | Large wet slap + low bass thump | Main impact           |
| 1.86 | Thick liquid slosh              | Dome follow-through   |
| 2.25 | Short wobbly boing              | Rebound               |
| 2.90 | Soft squelch                    | Settle                |

The 1.64 wet slap must be the loudest event. Layering a pitched-down, short thump underneath gives the attack mass without making it sound like a rock explosion.

### Goo Bomb

| Time      | Sound                      | Character           |
| --------- | -------------------------- | ------------------- |
| 0.40      | Bubbling inhale            | Gathering pressure  |
| 1.25      | Increasing gurgle          | Body swelling       |
| 1.85      | Low elastic stretch        | Maximum inflation   |
| 2.40      | Light liquid warning pulse | Landing indicator   |
| 2.55      | Wet spit / suction pop     | Projectile launches |
| 2.55–3.40 | Quiet airy liquid whoosh   | Projectile flight   |
| 3.40      | Heavy sticky splat         | Landing impact      |
| 3.55      | Two small bubbles          | Puddle established  |
| 5.55      | Faint wet evaporation      | Puddle ending       |

Keep the projectile sound quieter than the landing. It should sound weighty and funny, not explosive.

### Goo Tsunami

| Time | Sound                            | Character         |
| ---- | -------------------------------- | ----------------- |
| 0.00 | Deep liquid rumble               | Start             |
| 0.45 | Rising wet stretch               | Body elongating   |
| 1.10 | Layered gurgles                  | Pressure building |
| 1.70 | Large wobbling swell             | Full extension    |
| 2.10 | Low liquid warning tone          | Lane appears      |
| 2.65 | Thick suction release            | Forward collapse  |
| 3.04 | Powerful rushing liquid          | Surge begins      |
| 3.20 | Massive splash + low impact boom | Full-lane hit     |
| 3.65 | Cascading water and bubbles      | Residual wave     |
| 4.30 | Fading wet ripples               | Aftermath         |

The Tsunami should have the deepest and widest sound of the three moves. The Slam is a concentrated thud; the Tsunami is an extended roar.

### Hurt and defeat

| Action | Time | Sound                     |
| ------ | ---- | ------------------------- |
| Hurt   | 0.00 | Short, soft wet knock     |
| Hurt   | 0.13 | Little rubber compression |
| Hurt   | 0.24 | Wobbly elastic rebound    |
| Defeat | 0.00 | Low surprised gurgle      |
| Defeat | 0.48 | Unstable rubber wobble    |
| Defeat | 0.80 | Falling liquid tone       |
| Defeat | 1.42 | Soft heavy collapse       |
| Defeat | 2.10 | Large, gentle goo splat   |
| Defeat | 2.20 | Bright cyan matter chime  |
| Defeat | 2.65 | Four-mote group whoosh    |
| Defeat | 3.10 | Quiet bubbling fade       |
| Defeat | 3.80 | Soft final pop            |

Use one grouped escape sound per mote group, not a separate sound for every mote. Otherwise 16 small sounds could create an unpleasant clutter during crowded battles.

## 11. FX budgets — inherited Batch 1 limits

The approved Colossus limits remain in force.

# 2

Detailed concurrent attacks

# 32/s

Proposed particle cap (strictly below 35/s)

# 24

Maximum loose fragments/motes

# 0

Titan dynamic lights and camera shakes

Batch 1 allows two lights and one camera shake; the Titan deliberately uses none, leaving capacity for other concurrent effects.

### Event allocation

These counts cover transient particles. Pooled danger outlines, ribbon meshes, puddles and the main projectile are animated geometry, not particle-emitter output.

| Event         | Particle allocation                                                                    | Loose objects                    |
| ------------- | -------------------------------------------------------------------------------------- | -------------------------------- |
| Tentacle Slam | 4 charge droplets; 8 splash droplets + 6 sparks at impact; 4 settle droplets           | 0                                |
| Goo Bomb      | 6 pressure bubbles; 4 launch droplets; 8 splash droplets + 4 small bubbles at impact   | 0                                |
| Goo Tsunami   | 6 pre-release droplets; 8 splash droplets + 6 foam bubbles at hit; 4 residual droplets | 0                                |
| Hurt          | 3 tiny droplets + 2 bubbles                                                            | 0                                |
| Defeat        | 5 early droplets + 7 melt droplets + 3 final bubbles                                   | 16 motes + 6 small goo fragments |

The defeat uses 22 loose objects at maximum, below the 24-fragment limit. The puddle and melt-cap proxy are persistent pooled effect geometry, not loose fragments.

A necessary concurrency restriction: the listed counts are per event, not permission to emit all of them in one second across simultaneous attacks. Maintain a shared FX allocator that caps total transient emission at 32 particles/s. Prioritize impact splashes, then charge effects, then decorative aftermath. Reduce decorative counts when the cap would be exceeded.

For mobile LOD, keep all warning boundaries fully visible and preserve their hit timing. Simplify secondary wave ribbons and impact splashes before reducing gameplay-critical tells.

### Recommended implementation ownership

| System                      | Responsibility                                                                            |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| Server combat               | Cast time, targeting, locked hit geometry, damage, slows, defeat/matter rules             |
| `Attacks.module.luau`       | Named pose keys, interpolation, combat-relative event timings                             |
| `AlienAnimator.client.luau` | Sample poses from server `T0`, additive hurt, actor locomotion blend, tentacle correction |
| FX module                   | Pooled danger graphics, projectile, wave, puddles, motes, cleanup                         |
| Shared FX allocator         | Particle limits, concurrent detailed effects, LOD                                         |

Avoid building a completely separate attack scheduler just for the Titan. It should use the same core timeline playback system that already powers the Colossus.

## 12. Studio acceptance checklist

Batch 2 verification

0 / 10 passed

Slam timing

Full wedge appears at 0.74, both tips contact at 1.64, body unlocks at 3.40.

Slam contact

Tips land 6–12 studs forward, do not penetrate the ground, and remain within the actual 120° hit wedge.

Bomb targeting

Test 12, 21 and 30 studs at -30°, 0° and +30°. Projectile lands at the fixed point at 3.40.

Bomb independence

Titan can resume walking at 2.60 while the sphere is in flight and the puddle persists to 5.90.

Tsunami lane

All four corners and exact edges visible from 2.10; full 24 × 12 lane hit at 3.20.

Tsunami recovery

Actor free at 3.20, residual wave cosmetic only, slow ends at 5.20.

Hurt additive

192-damage threshold, 0.65 cooldown, 0.52 duration, 35% attack blend. No contact snapping.

Defeat

Eye closes, melt proxy replaces rig by 2.10, precisely 16 motes escape, everything cleaned by 3.80.

Visual integrity

No floating eye, seam ring, tentacle inversion, ground penetration or giant dome clipping.

Performance

Two overlapping detailed attacks, mobile-distance readability, global particle cap, no unnecessary lights or shakes.

Reset checklist Copy results

## 13. Final implementation verdict

GO FOR IMPLEMENTATION AND STUDIO VALIDATION, with three critical requirements:

1. Slam tip contact must be verified in world space. The joint rotations are starting poses; a contact solver is necessary to achieve reliable ground contact across the full three-bone chain.
2. Goo Bomb and Tsunami effect lifetimes must cover their slows. The Colossus's cosmetic end times cannot be copied directly when gameplay effects persist longer.
3. Defeat requires a separate melt proxy. The existing bone rig cannot realistically flatten the entire dome into a puddle using rotations and translations alone.

The three moves now have deliberately separate identities: Slam is a delayed, heavy double-tentacle crush; Bomb is a swelling, pressure-based ranged trap; Tsunami is a whole-body collapse that releases a lane-filling surge.

The values above are authored animation targets, not measured Blender or Roblox playback results. The owner's Studio pass should determine whether the tentacle contact and deformation look right before Batch 2 is marked approved.

Minor wording correction for the brief: “landing circle radius 5 appears 2.40” should read “a radius-5 landing circle appears at 2.40 s.” Precision matters in a timing contract. And for the record, baked potatoes remain entirely unworthy of defending.
