Now please switch from images to the ANIMATION SPEC for this creature (Thinking, high). All the images in this chat (the model pack + the attack, hurt/defeat and effects sheets you made) are the references to match. Below: my brief for this batch (both creatures are in it: answer for the BRUTE only), then the as-built spec of the previous batch (the Titan) so you use the same conventions and format.

===== BRIEF =====
# Animation batch 3: TWIN (Squish F2) + BRUTE (Squish F3), spec request

James approved the Colossus and the Titan. His notes for this batch:
1. The Titan's goo tsunami wave "looks very Robloxy" (squashed-sphere lobes) — to be fixed later.
2. **From now on every attack AND the effects it produces must be built to match REFERENCE IMAGES**, like the models were.
   The 10 attached images are those references (5 per creature: 3 attack key-pose sheets, HURT + DEFEAT, an EFFECTS sheet).

So: **no primitive-looking FX.** My plan is to model the goo effect shapes in Blender from the EFFECTS sheets as real meshes
(each imported once as a MeshPart template with the aliens' own goo surface: SurfaceAppearance colour + normal + glowing
cracks, EmissiveStrength 2) and animate them with scale / transparency / position curves. Particles only for small droplets
and motes. Please spec those meshes too (see section D).

## A. The rigs (model space, studs; pivot on the ground; model forward = -Z; +X is the creature's RIGHT on these two)

**TWIN SquishF2v5**: 4.6 x 4.6 x 4.4, Hitbox 2.0 x 3.6 x 1.9. No legs: it sits in its own puddle and bounce-slides.
- Root (0,0,0) -> Base (0,0.05,0) (the puddle) -> Body (0,0.45,0) (lower lobe) -> Top (0,2.00,0) (upper lobe: eye, brow, horns) -> Lid (-0.17,2.95,-0.68)
- Tendrils from Body: TendL1 (-0.62,2.20,0) -> TendL2 (-1.35,1.80,-0.10) -> TendL3 (-1.72,1.18,-0.10); TendR mirrored at +X.
- Its gait (for scale): walk hop 0.55 up, squash 0.25, tendril fling 28 deg; idle hop 0.35 every 6.2 s.

**BRUTE SquishF3v5**: 7.9 x 6.8 x 6.7, Hitbox 5.6 x 5.2 x 4.4. A goo gorilla on 4 limbs (arms = front legs, knuckle-walk).
- Root (0,0,0) -> Hips (0,2.40,1.20) -> Chest (0,3.10,0.70) -> Head (0,3.60,-0.90) -> Lid (-0.05,4.12,-1.50)
- Arms from Chest: LegFL (-2.20,4.30,-0.30) -> ShinFL (-2.62,2.50,-0.95) -> FootFL (-2.65,1.45,-1.45) (= the fist); FR mirrored at +X.
- Legs from Hips: LegBL (-0.95,2.55,1.25) -> ShinBL (-0.95,1.45,0.90) -> FootBL (-0.95,0.50,1.20); BR mirrored.
- Its gait: 4-limb planted IK (fists + feet stay on footholds), crouch 0.6, shoulders roll over the planted arm.

## B. What the animator can do
- Per-bone keys like the Titan's: root { lift, side, fwd, pitch, roll, yaw } + each bone { rx, ry, rz, ox, oy, oz } in MODEL
  axes, degrees (+rx = nose up / tip up for a forward-pointing bone), eases out / in / smooth, events at times returning effects.
  Lesson from the Titan: child chains inherit their parent's pitch, so contacts are measured in Play and tuned; give me the
  INTENT (where each contact must land, in model space) as well as keys.
- **New for the Brute (I'll build it):** each limb, per time window, is PLANTED (IK keeps it on its foothold), FREE (your FK
  keys drive it), or TARGET (2-bone IK to a point you give in model space, e.g. both fists onto the ground 2.5 ahead), with a
  blend time. A TARGET beyond reach STRETCHES the forearm (the fist bone slides out along the forearm; the goo skin stretches
  between): that's the STRETCH GRAB rope. Give each limb's mode per phase + blend.
- The Titan's tip-contact correction exists (pull a joint to a target height above the ground at the hit).
- Danger shapes on the ground (SQUISH style: bright cyan line, dark rim, dark-teal fill RGB(0,105,125) Neon), built from
  ground-placed pieces. Gameplay locks (body free time), hurt is additive (0.35 weight in a committed move), defeat terminal.
- FX budget per client (shared): 34 particles/s, 2 lights, 24 loose fragments; danger shapes free. No camera shake on these.

## C. The moves (power graph, design/09 + kits.mjs: these numbers are the gameplay contract)
**TWIN** (2 matter, 235 HP, 19 studs/s; job: control swarms)
- A **DOUBLE SLAP** (passive attack): both tendrils slap at once, 20 dmg to TWO little ones, every **1.0 s**. Must loop in a
  1.0 s cycle and read at phone distance; no danger shape (it's the basic attack).
- B **STICKY FLOOR** (auto, cd 9, warn **0.5**): when 3+ enemies are close, its puddle spreads to radius **5**: enemies
  25 % slower (move + attack) for **2.5 s**. Danger: the circle.
- C **BOING SLAM** (ORDER, cd 22, warn **0.8**): bounces up to **14** studs into a crowd and belly-flops: 20 dmg to 3 in
  radius **5**, little ones tossed up 0.4 s. Danger: the landing circle (fixed at cast).

**BRUTE** (4 matter, 560 HP, 16 studs/s; job: smash Packs)
- A **KNUCKLE POUND** (passive attack): two-fist pound, 55 dmg (x1.5 vs Packs), every **1.25 s**. Loops in 1.25 s.
- B **STRETCH GRAB** (auto, cd 8, warn **0.5**): an arm stretches to a unit up to **14** away, yanks it in, slams it down:
  30 dmg + held **0.5 s**. Danger: a line/lane to the target.
- C **CHEST THUMP** (ORDER, cd 26, warn **0.8**): beats its chest: goo SHIELD 70 for itself, 30 for friends within **8**,
  for **6 s**; punches **20 % faster for 4 s**. (A buff, no damage: the "warning" is the wind-up.)
- Both: HURT (additive, ~0.5 s) and DEFEAT (terminal ~3.8 s, melt to a puddle, 16 matter motes fly home; the Twin is
  2 matter, the Brute 4: how many motes reads best?).

## D. What I need back (same format as your Titan spec)
1. Timing contract per move: warning / hit / body free / effects end (passives: wind-up / hit / recover within the cycle).
2. Keyframe tables per bone (both rigs), with eases; Brute limb modes (PLANTED / FREE / TARGET + points) per phase.
3. Events + effects by time; danger shapes (exact shape + size + how they fill/pulse) where a move has a warning.
4. **FX MESH LIST** from the effects sheets: per mesh: what it is, which sheet cell it copies, dimensions in studs at full
   size, how many spikes/lobes, thickness, and its animation (scale / opacity curves, timing). Re-use meshes across both
   creatures where possible (e.g. one splash crown, one rimmed puddle, one droplet, one shock ring, one jelly shield shell,
   one goo pin). Say where particles are still fine (tiny droplets, motes).
5. HURT + DEFEAT for both, matching the reference sheets.
6. Sound categories per event (I pick from Roblox's licensed library; James judges on a phone speaker: mid-range + length).
7. Budget check: two of the same creature doing the same move at once; a whole army (8 Twins, 4 Brutes) doing passives.
8. What to look at in the stills to judge it against the reference sheets.


===== PREVIOUS BATCH, AS BUILT (format + conventions) =====
# Titan animation batch 2 (28 Oct 2026): spec as built

Second per-alien batch (James: "Collousus is great. Yes start titan."). ChatGPT Thinking spec, full text in
13-TITAN-BATCH2-SPEC-chatgpt-raw.md. This file is what was BUILT and measured. Code:
src\ReplicatedStorage.AlienFusion.Attacks.module.luau (section "BATCH 2: the SQUISH TITAN"; A.TSlam, A.Bomb,
A.Wave, A.THurt, A.TDefeat, registered as A.FOR.SquishF4v5), src\StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau
(per-bone attack poses, per-form hurt with left/right chain swap, the tip-contact correction), MOVE TEST menu "TITAN (BATCH 2)".
Sheet: shots\39-titan-batch2.jpg. Audit trail: ChatGPT r1 NO-GO (15 changes, all handled) -> r2 (see BUILD-LOG).

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
- Built from ground-placed pieces (edges <= 2 studs, fills in chunks), ground read once per 0.5-stud cell (memoGround).
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
- Sounds: library IDs (A.GSOUNDS), not yet judged on James's phone; ChatGPT's test gains: slam slap 1.30, thump 0.70,
  splash 0.45; tsunami splash 0.85, thump 0.60.
- Server combat
…
Show more
Worked for 6m 32s
ChatGPT said:
SQUISH BRUTE — Animation Batch 3 Specification

SquishF3v5 · F3 · 4 Matter · 28 October 2026

Implementation verdict: GO TO BUILD, with two rig constraints addressed below.

This specification covers the Brute only, using the approved hero, model sheet, movement poses, three attack sheets, HURT/DEFEAT sheet and six-cell effects sheet as visual authority.

The central requirement is that the Brute must remain the same huge, asymmetrical, knuckle-walking cyan goo gorilla throughout. Its attacks should feel like a single heavy, elastic creature—not a humanoid performing combat animations.

The Blender FX meshes are mandatory for the major silhouettes. Particles provide secondary droplets and motes, never the primary shape of an attack.

1. Timing contract

All timestamps are seconds from server-authoritative attack start T0.

Move

	

Warning / wind-up

	

Hit / activation

	

Body free

	

Effects end




KNUCKLE POUND

	

0.00–0.42

	

0.60

	

1.02

	

1.12




STRETCH GRAB

	

0.00–0.50

	

1.30 slam

	

1.65

	

1.98




CHEST THUMP

	

0.00–0.80

	

0.80 buff

	

1.40

	

6.98




HURT

	

—

	

Immediate

	

Additive

	

0.52




DEFEAT

	

—

	

Terminal

	

Never

	

3.80

Additional contract:

KNUCKLE POUND repeats every 1.25 seconds. Damage 55, multiplied by 1.5 against Packs, at T0 + 0.60.

STRETCH GRAB has an 8-second cooldown. The hand catches at 0.76; the yank and slam deliver 30 damage at 1.30. The target remains held from 1.30 to 1.80, exactly 0.50 seconds.

CHEST THUMP has a 26-second cooldown. At 0.80, grant 70 shield to the Brute and 30 to qualifying allies within 8 studs. Shields expire at 6.80; the punch-speed buff expires at 4.80.

HURT plays at weight 0.35 during committed attacks, otherwise 1.0.

DEFEAT lasts 3.80 seconds and releases four distinct matter motes, matching the Brute's four-matter value.

For CHEST THUMP, interpret 20% faster punching as attack frequency ×1.20. The normal 1.25-second interval therefore becomes 1.0417 seconds, not 1.00 second. If the existing server's power graph explicitly specifies a different interval formula, preserve server gameplay and retime only the visual attacks.

Important rig constraints

1. The grab requires more than a literal 3× extension at maximum range.

The rest shoulder-to-fist chain measures approximately 3.12 studs (1.96 + 1.16). From the right shoulder to a target 14 studs directly forward, the extended distance is approximately 14.2 studs.

That is roughly 4.5× the chain's original reach.

The reference image's threefold stretch describes its visual character, not a sufficient mathematical maximum. Gameplay range stays 14. The arm mesh must support at least 4.6× elongation at extreme reach, while retaining the narrow, glossy rope appearance.

2. The Brute's hind legs cannot support a large literal root lift.

The rear leg chains are short relative to the standing hip height. Raising the root 0.6 studs while fixing both rear feet would overextend them.

Instead, use a near-ground root, pelvis counter-offset and substantial chest extension/pitch to create the upright gorilla silhouette. The fists can rise above the head without dragging the rear feet.

Both constraints must be handled through targets and procedural correction, not by introducing arbitrary changes to the rig's base proportions.

2. Animation conventions

The following applies to every animation table.

Coordinate space: model coordinates, origin at ground pivot, forward = -Z, right = +X.

root.fwd is a positive displacement along -Z.

Rotations are degrees; rx positive raises the nose, negative pitches the upper body forward.

ry and rz use the existing animator's signed model-axis convention.

ox/oy/oz are translation offsets, not replacements for rest joint coordinates.

All unlisted values are zero or blend to the existing locomotion pose.

smooth means cubic smoothstep; out means ease-out cubic; in means ease-in cubic.

Bone FK angles are guides where IK is active. The TARGET contact position overrides FK at full IK weight.

Root and parent bone rotations compose. All ground/fist positions given below are required final world/model contact coordinates after this composition, not assumed outcomes of the listed Euler angles.

For every move, the playback controller must evaluate gait, attack pose, IK corrections and additive hurt in a consistent order. Otherwise, one layer can undo another's ground contact.

Visual identity constraints

Preserve the three dorsal fin silhouette, prominent forward brow, single purple eye, two little white tusks, oversized knuckles, luminous cyan cracks and deeper violet recesses.

The eye and its surrounding rigid skinning region remain attached to the Head bone. No independent eye wobble. The repaired shallower brow must not be pushed back into its old overhanging form.

The reference sheets—not generic Roblox effects—determine the silhouettes of the splashes, rope, pin, shields and chest ripples.

3. Attack A — KNUCKLE POUND

Passive · 1.25 s cycle · 55 damage · ×1.5 versus Packs

ilovetheyeti.blogspot.com

Reference: KNUCKLE POUND sheet, frames 1–3; FX sheet cell 1.

The creature rises from its knuckles, raises both enormous fists over its head, and drives them down as one hammer. Its arms compress and bulge on impact, then remain planted while its body recoils.

This must feel like one very heavy impact, not two alternating punches.

Phase sequence

Time

	

Action




0.00–0.18

	

Hind legs brace; weight shifts back




0.18–0.42

	

Chest rises; both fists lift together above the eye and fins




0.42–0.54

	

Brief overhead compression, then rapid descent




0.54–0.60

	

Fists accelerate toward one shared impact point




0.60

	

Both fists contact ground simultaneously; server damage




0.60–0.78

	

Arms squash and bulge; fused splash crown rises




0.78–1.02

	

Fists remain grounded while torso rocks back




1.02–1.25

	

Return to the normal knuckle-walking stance

Root and upper-body keyframes

All rotations are additive to the movement pose. lift and fwd are studs; other translation fields are noted explicitly.

t

	

Root lift / fwd / pitch

	

Hips rx / oy

	

Chest rx / oy

	

Head rx

	

Lid close




0.00

	

0 / 0 / 0

	

0 / 0

	

0 / 0

	

0

	

0




0.18

	

0 / −0.08 / +3

	

+8 / −0.08

	

+15 / +0.12

	

−7

	

0




0.42

	

+0.05 / −0.12 / +4

	

+11 / −0.10

	

+23 / +0.22

	

−12

	

0




0.54

	

0 / +0.28 / −8

	

−7 / −0.12

	

−16 / −0.12

	

+10

	

8




0.60

	

−0.08 / +0.45 / −12

	

−11 / −0.22

	

−27 / −0.26

	

+12

	

16




0.78

	

−0.04 / +0.32 / −8

	

−7 / −0.14

	

−19 / −0.15

	

+8

	

8




1.02

	

0 / +0.10 / −2

	

−2 / −0.04

	

−5 / −0.04

	

+2

	

0




1.25

	

0 / 0 / 0

	

0 / 0

	

0 / 0

	

0

	

0

Ease: out for the rear-up, in from 0.42 to 0.60, out from impact to 0.78, smooth for the return.

A positive Lid close value uses the Titan's established 0..60 eyelid convention.

Limb targets and modes

Window

	

FL + FR

	

BL + BR

	

Blend




0.00–0.10

	

PLANTED

	

PLANTED

	

—




0.10–0.42

	

FREE, fists rise overhead

	

PLANTED

	

0.10




0.42–0.54

	

FREE, overhead hold

	

PLANTED

	

—




0.54–0.60

	

TARGET, ground impact

	

PLANTED

	

0.05




0.60–0.82

	

TARGET, hold contact

	

PLANTED

	

—




0.82–1.02

	

PLANTED at impact footholds

	

PLANTED

	

0.08




1.02–1.25

	

Return to locomotion footholds

	

PLANTED

	

0.16

Required fist targets, in model space:

Stage

	

Left fist FL

	

Right fist FR




Overhead, 0.42

	

(−1.55, 6.10, −0.55)

	

(+1.55, 6.10, −0.55)




Impact, 0.60

	

(−1.05, 0.14, −2.25)

	

(+1.05, 0.14, −2.25)




Hold, 0.78

	

(−1.05, 0.14, −2.25)

	

(+1.05, 0.14, −2.25)

The two fists must land within 0.03 seconds of one another. Their target centres are 2.10 studs apart, visually forming a single hammer strike.

Rear feet remain near (±0.95, 0.10, +1.20) throughout, adjusted to their actual measured sole contact heights.

Limb bone guides

The following are additive FK biases. IK controls final contact and limb bend, so these angles are not independently guaranteed contact solutions.

Bone

	

0.42 rear-up

	

0.60 strike

	

0.78 recoil




LegFL / LegFR rx

	

+105

	

−38

	

−24




ShinFL / ShinFR rx

	

−65

	

+42

	

+24




FootFL / FootFR rx

	

−15

	

+8

	

+3




LegFL / LegFR ry

	

±8 outward

	

∓12 inward

	

∓5




LegFL / LegFR rz

	

∓12

	

±7

	

±3




LegBL / LegBR rx

	

IK

	

IK

	

IK




ShinBL / ShinBR rx

	

IK

	

IK

	

IK




FootBL / FootBR rx

	

IK

	

IK

	

IK

For mirrored ry/rz, left takes the first sign, right takes the opposite. Use the actual IK elbow poles, not FK mirroring, to prevent elbow inversion.

At 0.60, target the shoulder origin near (±1.80, 2.95, −0.95) after torso deformation. This keeps the ground strike within approximately 1.03× the natural arm reach. If the measured rig is farther away, correct the chest pose first; do not use the extreme Stretch Grab extension on this attack.

The fist contact should be no more than 0.16 studs above the terrain and must never penetrate it below −0.03 studs.

Events and effects

t

	

Event

	

Exact effect




0.42

	

PoundPeak

	

Fists high, held for 0.04 s




0.54

	

PoundDown

	

Begin fast descending movement; short wet air displacement




0.60

	

PoundHit

	

Server applies 55 damage, Pack multiplier




0.60

	

PoundSplash

	

One sculpted double-contact splash crown




0.60

	

PoundRing

	

One flat, irregular goo ring expands outward




0.60–0.66

	

PoundCompress

	

Arms thicken visually by 15–18% around their lower lobes




0.60–0.75

	

PoundDroplets

	

Three small directional droplets, pooled




0.78–1.12

	

PoundSettle

	

Crown collapses and rim flattens

FX silhouettes: Use the sheet's high, sharply curved splash lips and irregular forked branches. The splash is wider than it is tall, and its outer ring remains visibly flat on the ground.

No danger shape. No camera shake.

4. Attack B — STRETCH GRAB

Automatic · 8 s cooldown · 14-stud targeting range · 0.50 s warning · 30 damage + 0.50 s hold

Reference: STRETCH GRAB sheet, frames 1–4; FX sheet cells 2 and 3.

The Brute pins its left knuckle, draws its right arm backwards, fires a thin rubbery limb to the selected target, and recoils like a stretched elastic band. The hand pulls the target close and finishes with a heavy ground slam.

The arm is a continuous goo limb, not a beam, cable or chain.

Phase sequence

Time

	

Action




0.00–0.25

	

Left fist plants; right shoulder hunches and pulls backwards




0.25–0.50

	

Right arm compresses into a spring-loaded wind-up




0.50

	

Warning finishes; arm fires toward target




0.50–0.76

	

Arm stretches into a long, narrow, glossy rope




0.76

	

Sticky hand catches the target; begin retract




0.76–1.12

	

Rope curls and snaps back, becoming thicker




1.12–1.25

	

Hand carries the goo-wrapped target downwards




1.30

	

Ground slam: 30 damage, 0.50 s hold begins




1.30–1.65

	

Arm remains compressed at the ground; goo pin persists




1.65–1.80

	

Brute returns to locomotion; target remains held




1.80–1.98

	

Hold ends; goo patch peels away and disappears

Root and upper-body keyframes

t

	

Root fwd / pitch / roll

	

Hips rx

	

Chest rx / ry / rz

	

Head rx / ry

	

Lid




0.00

	

0 / 0 / 0

	

0

	

0 / 0 / 0

	

0 / 0

	

0




0.25

	

−0.12 / +2 / −3

	

+3

	

+7 / +12 / −6

	

−4 / −8

	

0




0.50

	

−0.08 / −3 / +2

	

−2

	

−8 / +15 / +5

	

+4 / −10

	

5




0.76

	

+0.22 / −8 / +3

	

−5

	

−14 / +10 / +5

	

+7 / −6

	

8




1.00

	

+0.08 / +5 / −5

	

+6

	

+14 / −12 / −8

	

−8 / +6

	

0




1.12

	

+0.12 / +3 / −2

	

+3

	

+7 / −5 / −4

	

−3 / +3

	

0




1.30

	

+0.35 / −10 / +4

	

−9

	

−24 / +4 / +7

	

+10 / −2

	

16




1.55

	

+0.20 / −5 / +2

	

−4

	

−13 / +2 / +3

	

+6 / 0

	

5




1.80

	

+0.03 / −1 / 0

	

−1

	

−3 / 0 / 0

	

+1 / 0

	

0




2.00

	

0 / 0 / 0

	

0

	

0 / 0 / 0

	

0 / 0

	

0

Use smooth during wind-up, in on extension, out on recoil and strike, and smooth after the slam.

Arm and hind-leg modes

Window

	

Left arm FL

	

Right arm FR

	

Both hind legs




0.00–0.50

	

PLANTED

	

FREE

	

PLANTED




0.50–0.76

	

PLANTED

	

TARGET, extending

	

PLANTED




0.76–1.12

	

PLANTED

	

TARGET, retracting

	

PLANTED




1.12–1.30

	

PLANTED

	

TARGET, slam point

	

PLANTED




1.30–1.55

	

PLANTED

	

TARGET, ground hold

	

PLANTED




1.55–1.70

	

PLANTED

	

PLANTED at slam point

	

PLANTED




1.70–2.00

	

Normal IK

	

Normal IK

	

Normal IK

Blend right arm FREE→TARGET over 0.06 s, TARGET→PLANTED over 0.12 s.

Right-arm FK guides:

Bone

	

0.25 wind-up

	

0.50 release

	

1.00 yank

	

1.30 slam




LegFR rx

	

+26

	

−35

	

+48

	

−35




LegFR ry

	

+16

	

−8

	

+12

	

−8




LegFR rz

	

−12

	

+5

	

−10

	

+6




ShinFR rx

	

−55

	

+8

	

−52

	

+38




FootFR rx

	

+12

	

0

	

+15

	

+6

The left arm's LegFL, ShinFL and FootFL are solved by planted IK during the entire attack. Its elbow should bend under the body without crossing the chest.

Required TARGET positions

Event

	

Right hand target




Wind-up

	

(+3.35, 3.15, +0.45)




Full stretch

	

Target unit's validated catch point, maximum horizontal root distance 14




Fully retracted

	

(+1.25, 2.20, −1.30)




Slam contact

	

(+0.85, 0.13, −2.20)

The catch point follows the selected target during the extension, subject to the server's attack validity rules. A client must not extend the gameplay range beyond 14 just to preserve the visual.

At maximum reach, the rope should measure approximately 14.2 studs between its shoulder and terminal hand attachment. The shaft should be thin in the middle, approximately 0.30–0.38 studs in diameter, broadening smoothly toward both ends.

The rope retracts with a visible S-curve, not a straight line that simply becomes shorter.

Danger shape

A single narrow, ground-projected goo lane ending at the selected target.

Property

	

Value




Length

	

0 to selected target distance, capped at 14




Width

	

0.90 studs




Centreline

	

From Brute pivot toward the selected target




Fill

	

Dark teal RGB(0,105,125) Neon




Rim

	

Dark RGB(40,32,27), 0.18 wider on each side




Bright outline

	

Cyan #37F5FF, 0.28 studs




Target cap

	

Rounded goo-ended shape, 0.55-stud radius




Warning lifetime

	

0.00–0.50

Timing:

0.00–0.38: fill advances from near the Brute to the target.

0.38–0.46: a thin mint line travels outward.

0.46–0.50: two rapid cyan pulses.

0.50: line withdraws beneath the reaching arm.

The ground lane is a single-target telegraph, not a damaging rectangular area. Its width communicates direction and visibility, not a second hitbox.

Update the line toward the server-authoritative target position during the warning. Freeze the final launch direction at 0.50, unless the gameplay implementation explicitly supports further tracking.

Events and effects

t

	

Event

	

Effect




0.00

	

GrabWarn

	

Lane appears; arm compresses




0.50

	

GrabLaunch

	

Sculpted stretchy rope extends




0.50–0.76

	

RopeExtend

	

Length expands, middle narrows, glowing crack veins elongate




0.76

	

GrabLatch

	

Open palm closes over target




0.76–1.12

	

RopeRecoil

	

Curved rope replaces straight stretch; two long trailing goo strands




0.88

	

GrabWrap

	

A sticky cyan/violet wrap surrounds the target




1.12–1.30

	

GrabDownstroke

	

Recovered massive fist drives down




1.30

	

GrabSlam

	

Damage, hold, splash and pin




1.30–1.80

	

GooPin

	

Lumpy patch and ground strands hold the target




1.80–1.98

	

GooRelease

	

Strands release, patch contracts and fades

In actual gameplay, the wrap follows the real grabbed unit. The grey blob shown in the reference is a placeholder for visual development, not a substitute for the enemy's real model.

If no valid target is caught, run the missed-grab recovery without a phantom captured blob, damage or pin effect.

5. Attack C — CHEST THUMP

ORDER · 26 s cooldown · 0.80 s wind-up · 70 self shield / 30 allied shield · 6 s duration · 20% faster punches for 4 s

Reference: CHEST THUMP sheet, frames 1–4; FX sheet cells 4, 5 and 6.

This is the Brute's signature ability. It rises onto its hind legs, swells its chest and beats the violet core. A giant goo bubble grows around its body while smaller matching shields envelop nearby allies. Its fists brighten, and it returns to knuckle stance with faster punching.

The visual priority is:

Chest impact → violet energy flare → jelly shield growth → charged fists.

Phase sequence

Time

	

Action




0.00–0.25

	

Hind legs brace, shoulders begin to rise




0.25–0.55

	

Chest swells dramatically; fists draw back




0.55–0.73

	

Right fist approaches chest; left fist waits




0.73

	

First chest thump, right fist




0.80

	

Second thump; gameplay shields and attack-speed buff activate




0.80–1.08

	

Violet core flares; goo shields expand




1.08–1.40

	

Brute lowers onto both knuckles inside shield




1.40–4.80

	

Fists stay charged; attack cadence ×1.20




4.80–6.80

	

Speed buff gone; shields remain




6.80–6.98

	

Shields dissolve and fade

The first thump at 0.73 is purely audiovisual. The second thump at 0.80 is the server-authoritative buff event. This avoids applying shield strength twice.

Upper-body keyframes

t

	

Root lift / pitch

	

Hips rx / oy

	

Chest rx / oy

	

Head rx

	

Lid




0.00

	

0 / 0

	

0 / 0

	

0 / 0

	

0

	

0




0.25

	

+0.05 / +3

	

+8 / −0.08

	

+17 / +0.20

	

−8

	

0




0.55

	

+0.08 / +4

	

+11 / −0.14

	

+25 / +0.28

	

−13

	

0




0.73

	

+0.04 / +2

	

+8 / −0.12

	

+16 / +0.15

	

−7

	

12




0.80

	

−0.04 / −4

	

+4 / −0.12

	

+7 / +0.05

	

+2

	

24




0.95

	

+0.02 / +2

	

+7 / −0.10

	

+13 / +0.12

	

−5

	

0




1.20

	

0 / −3

	

−3 / −0.05

	

−8 / −0.04

	

+4

	

0




1.40

	

0 / 0

	

0 / 0

	

0 / 0

	

0

	

0

Ease: out to maximum chest expansion, in on both thumps, out on the chest recoil, smooth into the resumed gait.

Limb modes and fist positions

Window

	

FL / FR

	

BL / BR




0.00–0.12

	

PLANTED

	

PLANTED




0.12–0.55

	

FREE, draw back

	

PLANTED




0.55–0.73

	

FREE, alternating thumps

	

PLANTED




0.73–0.83

	

TARGET, chest contact

	

PLANTED




0.83–1.10

	

FREE, fists recoil

	

PLANTED




1.10–1.40

	

TARGET, normal ground footholds

	

PLANTED




1.40 onward

	

Normal planted gait

	

Normal planted gait

Required thump contacts:

Right fist at 0.73: approximately (+0.65, 4.50, −1.10).

Left fist at 0.80: approximately (−0.65, 4.48, −1.12).

Both hands must stay visible on opposite sides of the core in the thump silhouette.

FK arm guides:

Bone

	

0.55 wind-up

	

0.73 right thump

	

0.80 left thump

	

1.10 release




LegFL rx

	

+50

	

+48

	

+76

	

+20




LegFR rx

	

+50

	

+76

	

+48

	

+20




ShinFL rx

	

−55

	

−50

	

−75

	

−20




ShinFR rx

	

−55

	

−75

	

−50

	

−20




FootFL rx

	

+10

	

+10

	

−8

	

0




FootFR rx

	

+10

	

−8

	

+10

	

0

IK must keep both rear feet on the ground. Front fists do not have to remain planted during the chest animation.

Shield geometry and duration

The main shield is a thick, translucent, asymmetrically wobbly jelly shell enclosing the Brute, not a perfect glass dome.

The reference shows visible cyan surface streaks, faint crack lines, a thick lower skirt where the shell meets the ground, and a few little drops extending off its perimeter.

Main shield at full size:

Overall bounding box approximately 9.0 × 8.1 × 8.0 studs, in width × height × depth order.

Bottom edge at the ground, flaring slightly outward.

Shell wall averages 0.18–0.28 studs in thickness, increasing to 0.42 at the bottom.

Visually around 45% opaque, adjusted to keep the eye visible.

Irregular wobbles of approximately 0.20–0.35 studs across its surface.

5–7 faint branching cyan crack paths; 6–10 small luminous dots.

Absolutely no perfect sphere outline.

The allied shield uses the same sculptural language, scaled to each ally's bounding box with at least 0.35 studs of clearance, and a maximum base wall thickness of 0.22 studs for little units.

Apply one shield visual per affected unit, not one shell per incoming buff source. This prevents several overlapping translucent bubbles from obscuring a unit.

Shield events

t

	

Event

	

Effect




0.00

	

ThumpWarn

	

Chest and shoulders begin growing




0.55–0.80

	

ThumpCharge

	

Violet core increases in apparent intensity




0.73

	

ThumpOne

	

First chest ripple, small




0.80

	

ThumpActivate

	

Server grants shields + attack-speed buff




0.80

	

ThumpTwo

	

Large violet core flare and radial chest ripple




0.82–1.08

	

ShieldGrow

	

Main and allied jelly shells expand




1.08–1.30

	

ShieldWobble

	

Shell overshoots and settles




0.80–4.80

	

FistsPumped

	

Cyan cracks and fist edge glow appear enhanced




4.80–5.00

	

PumpEnd

	

Enhanced fist glow fades




6.80–6.98

	

ShieldEnd

	

Jelly shell thins, softens and disappears

There is no damage danger shape for CHEST THUMP.

A brief, cosmetic cyan/mint ground halo expanding to radius 8 at 0.55–0.80 can communicate the ally-buff radius, but it must not resemble an enemy attack warning. Do not hold that ring for the six-second shield duration.

Punch-speed integration

When the buff is active, reuse KNUCKLE POUND rather than building an unrelated fast-punch animation.

Scale its pose timeline by 1 / 1.2 = 0.8333, giving:

Original hit: 0.60 → 0.50 seconds within the accelerated attack.

Original recovery: 1.02 → 0.85 seconds.

Original complete cycle: 1.25 → 1.0417 seconds.

The server still determines when attacks actually occur. The animator should start each animation using authoritative attack times rather than running a self-maintained cooldown loop that can drift.

The shield must not change attack damage. Only the approved frequency increases.

6. Blender FX mesh library

Build the silhouettes below as authored meshes. Do not approximate them with Roblox spheres, cylinders, toruses or unions of rounded primitive lobes.

The following dimensions are targets for the Brute at full size, not claims about the dimensions of the Blender reference renders.

Use the existing alien surface identity:

Property

	

Value




Base colour

	

Bright saturated cyan-blue




Inner depth

	

Rich violet / indigo




Glowing cracks

	

Cyan #37F5FF




Violet highlights

	

#A56BFF




Accent motes

	

Mint #A5FFD8




Roughness

	

0.12–0.22, varied across the sculpt




Metalness

	

0




EmissiveStrength

	

2 baseline




Glow pattern

	

Authored emissive mask, not full-surface Neon




Collision

	

Off




Anchored

	

Yes for detached visual FX

All dimensions use studs. W × H × D means X width, vertical height and Z depth.

The geometry should contain its own material variation, vein paths, specular bulges and organic edges. Scaling a simple geometric primitive with an emissive texture is not an acceptable substitute.

Primary mesh asset list

ID

	

Mesh / source

	

Full-size bounds

	

Sculpting requirements




GooPoundCrown

	

Cell 1: POUND SPLASH

	

3.8 × 1.15 × 2.8

	

8 major curved spikes, 5 smaller tips, connected rising sheets 0.08–0.22 thick; fused double-impact centre




GooFlatRim

	

Cell 1: POUND SPLASH

	

4.6 × 0.12 × 3.9

	

Flat irregular splash annulus, 7 broad scalloped lobes, 0.10–0.20-thick raised rim




GooStretchStraight

	

Cell 2: STRETCH ARM

	

Max length 14.6

	

Tapered rope, middle diameter 0.30–0.38, proximal shoulder taper 0.90; 3 longitudinal ridges




GooStretchCurl

	

Cell 2 / grab key pose 3

	

6.8 × 2.2 × 2.1

	

Bent S-curve recoil with 2 branching trailing strands; no straight-cylinder silhouette




GooOpenPalm

	

Cell 2: STRETCH ARM

	

1.6 × 1.4 × 1.0

	

Palm with 4 rounded sticky fingertip lobes, narrow string bridges, uneven spread




GooGrabWrap

	

Grab key pose 3

	

2.0 × 1.7 × 1.7

	

Five asymmetrical wrapping ribs around a hollow centre; target remains visible




GooPinPatch

	

Cell 3: GOO PIN

	

2.8 × 0.85 × 2.3

	

5 merged bulbous masses, 6 stretched ground strands, 3 drooping bridges, lumpy violet recesses




GooShieldShell

	

Cell 4: GOO SHIELD

	

9.0 × 8.1 × 8.0

	

Thick wobbly translucent dome, 5 broad surface undulations, 5–7 crack paths; weighted skirt at base




GooChestRipple

	

Cell 5: CHEST RIPPLE

	

2.7 × 2.5 × 0.18

	

Curved chest-conforming patch with 3 irregular expanding ripple ridges and violet central depression




GooPumpedFist

	

Cell 6: PUMPED FISTS

	

2.2 × 2.0 × 2.1

	

Thin conforming glow shell over existing fist, 4 irregular bright knuckle regions, 2 trailing wisps




GooMeltMound

	

DEFEAT frame 3

	

6.5 × 1.65 × 5.3

	

Slumped body mass, flattened shoulder lobes, three drooping fin remnants and a closed-eye impression




GooMeltFlat

	

DEFEAT frame 4

	

7.2 × 0.16 × 6.1

	

Broad nearly flat puddle, uneven raised perimeter, 8 shallow surface lobes, faint interior veins

Two additional assets should be pooled: a teardrop-shaped goo droplet in sizes 0.12–0.28 studs, and a small cyan matter-mote mesh approximately 0.20–0.30 studs across. The mote should be an irregular luminous seed, not a white ball.

The same mesh library may be reused for the Twin at rescaled sizes, but this specification does not define the Twin's attack animations. Particularly useful shared assets are GooFlatRim, GooPinPatch, GooShieldShell, droplets and matter motes.

Mesh animation curves

In this table, scale is a multiplier on the mesh's authored dimensions. Opacity is the visible fraction (1 = fully opaque; 0 = invisible), which must be translated to the appropriate Roblox transparency setting.

Mesh

	

Animation




GooPoundCrown

	

0.60: scale (0.45,0.15,0.45), opacity 0.8; 0.67: (1,1,1), opacity 1; 0.85: (1.08,0.60,1.08); 1.10: (1.10,0.03,1.10), opacity 0




GooFlatRim

	

0.60: horizontal scale 0.55; 0.72: 1.00; 0.88: 1.20, height scale 0.65; 1.12: opacity 0




GooStretchStraight

	

0.50: visible at 12% length; 0.66: 75% reach; 0.76: full catch reach; 0.83: fade/replace with curl




GooStretchCurl

	

0.76: starts at 75% opacity, 1.0 scale; 0.96: length scale 0.60, vertical curve still pronounced; 1.12: scale 0.20, opacity 0




GooOpenPalm

	

0.50: hand starts closed; 0.66: open pose fully visible; 0.76–0.82: closes around target; fades back into clenched fist before 1.12




GooGrabWrap

	

0.76: 0.45 scale, opacity 0; 0.88: 1.0 scale, opacity 0.75; 1.30: contracts against captured target




GooPinPatch

	

1.30: scale (0.60,0.35,0.60); 1.38: (1,1,1); 1.50: height 0.75; 1.80: release; 1.98: opacity 0




GooShieldShell

	

0.82: scale 0.15, opacity 0; 1.00: scale 1.07, opacity 0.55; 1.08: scale 1.0, opacity 0.45; 6.80–6.98: opacity falls to 0




GooChestRipple

	

0.73: small ripple 0.35 scale; 0.80: main ripple starts at 0.30 scale; 0.94: reaches 1.0; 1.15: opacity 0




GooPumpedFist

	

0.80: opacity 0; 1.08: 0.65; subtle 1.00–1.06 shell-size pulse on punches; 4.80–5.00: fade out




GooMeltMound

	

1.55: opacity 0; 1.85: visible with height scale 1.0; 2.30: height scale 0.65 and width scale 1.12; 2.85: fade out




GooMeltFlat

	

2.20: starts at horizontal scale 0.65; 2.85: horizontal scale 1.0, opacity 1; 3.60–3.80: fades away

Mesh-specific geometry guidance

Pound splash: The crown should resemble intersecting liquid membranes with tapering forks and droplet tips. Avoid identical radial spikes. There should be an obvious shared centre beneath the two fists.

Stretch arm: One end has a thick shoulder transition and the other has a distinct open sticky hand. The middle is smooth but not cylindrical; it has uneven, flowing bulges and pulled-thin electric cracks. Author it along one axis so the complete mesh can orient along an arbitrary target vector.

The curved recoil needs a second sculpted pose or actual deformation. A straight rope scaled shorter will not reproduce frame 3's whip shape.

Goo pin: The upper surface must be irregular and solid-looking, with surface membranes descending into the ground. The grabbing target is enclosed by the wrap while the patch visibly connects it to the floor. It must not look like three squashed spheres stacked together.

Shield: This is a sculpted, uneven shell, not a perfect sphere using transparency. The lower perimeter should visibly pool and have 4–6 short drips or protrusions. Its centre must remain clear enough to see the Brute's eye.

Chest ripple: Build the ripple on a shallow curved sheet fitted to the existing chest surface. The violet core is a recessed luminous feature, not a separate hovering energy orb. The ripple rings should be irregular and non-concentric.

Pumped fist: This overlays the existing fist and should only add bright, surface-hugging highlights and a narrow energy smear. Do not duplicate the whole fist as a second large opaque blob.

Roblox material implementation note

The intended SurfaceAppearance approach is valid: Roblox currently supports emissive masks, tint and strength, including for published experiences. However, high emissive values may clamp toward white, losing the cyan/violet colour separation. Test strength 2 under the actual map lighting before changing it. 
Documentation - Roblox Creator Hub
+1

For the shield, use AlphaMode.Transparency with an authored alpha map and a nonzero MeshPart transparency value. Roblox documents different rendering behaviour and imperfect depth/occlusion for semi-transparent PBR surfaces, so test one Brute shield overlapping an allied shield before committing the material. 
Documentation - Roblox Creator Hub
+1

Do not depend on dynamically editing texture maps at runtime. Pre-author the necessary glow variations and animate mesh opacity/placement. The emissive intensity can remain fixed in the material, with a separate overlay creating the apparent flare.

7. HURT — additive, 0.52 seconds

Reference: HURT row, frames A and B.

The Brute receives a heavy blow on its left shoulder. The goo dents inward, droplets burst from that shoulder, the weight shifts sideways onto the right fist, and the body springs back with a snarl.

Do not turn this into a generic humanoid flinch. The visible shoulder compression is essential.

HURT keyframes

t

	

Root side / roll

	

Chest rz / ox

	

LegFL ox / oy

	

Head rx / ry

	

Lid close




0.00

	

0 / 0

	

0 / 0

	

0 / 0

	

0 / 0

	

0




0.10

	

+0.20 / +5

	

+9 / +0.12

	

+0.28 / −0.15

	

−5 / +6

	

34




0.22

	

+0.28 / +8

	

+12 / +0.18

	

+0.34 / −0.18

	

−8 / +9

	

42




0.35

	

−0.06 / −3

	

−5 / −0.08

	

−0.10 / +0.05

	

+4 / −4

	

15




0.52

	

0 / 0

	

0 / 0

	

0 / 0

	

0 / 0

	

0

For the limb chains:

Right front arm FR: remains PLANTED, absorbing most of the stagger.

Left front arm FL: briefly reduces IK weight to 0.55 between 0.08 and 0.24, then restores planted contact by 0.40.

Both hind legs: PLANTED, with body roll corrected by leg IK.

Left shoulder compression: inward approximately 0.34 studs at peak.

Left forearm: rotate outward 8 degrees to emphasize the dent rather than simply translating the whole limb.

The Head bone rolls slightly with the body, but the rigid eye area must not warp.

At 0.12, emit a small mesh spray with two droplet particles from the left shoulder.

At 0.30–0.43, allow a 0.10-stud outward overshoot as the shoulder regains its shape. The eye opens progressively while the shoulders settle.

The analogous right-side hit mirrors the geometry and sign of lateral rotations.

Critical: 0.35-weight HURT must not pull a committed attack's TARGET fist off its required contact. Apply additive shoulder/head deformation before the final contact solver, or explicitly exclude any ground-target correction from HURT blending.

8. DEFEAT — terminal, 3.80 seconds

Reference: DEFEAT row, frames 1–4.

The Brute loses strength rather than exploding. First one arm gives way; then its torso falls forward; finally, the body loses all structure and turns into a sprawling puddle.

The back fins remain recognizable during the intermediate melt, droop, and then disappear into the last puddle. The one eye must visibly close before the face dissolves.

Defeat phases

Time

	

Appearance




0.00–0.45

	

Dazed sway, half-closed eye, left arm weakening




0.45–1.15

	

Arms buckle and body pitches forward




1.15–1.65

	

Chest and face settle onto ground; shoulders spread sideways




1.55–2.30

	

Begin blending from the normal body to the sculpted melt mound




2.30–2.85

	

Mound spreads wide and settles nearly flat




2.65–3.55

	

Four cyan matter motes rise and fly home




3.55–3.80

	

Final puddle loses its glow and fades

Defeat keyframes

t

	

Root lift / fwd / roll

	

Hips oy / rx

	

Chest oy / rx

	

Head oy / rx

	

Lid close




0.00

	

0 / 0 / 0

	

0 / 0

	

0 / 0

	

0 / 0

	

0




0.35

	

−0.05 / +0.05 / +6

	

−0.12 / −4

	

−0.18 / −8

	

−0.05 / +5

	

30




0.70

	

−0.10 / +0.18 / −5

	

−0.25 / −10

	

−0.50 / −20

	

−0.22 / +12

	

45




1.15

	

−0.15 / +0.32 / +3

	

−0.48 / −18

	

−0.95 / −32

	

−0.55 / +18

	

60




1.65

	

−0.18 / +0.35 / 0

	

−0.65 / −20

	

−1.30 / −35

	

−0.75 / +18

	

60




2.30

	

Model fading

	

Model fading

	

Model fading

	

Hidden

	

60

The specified body and head translations are target pose offsets, subject to the same compositional grounding corrections as the attacks. Never allow the eye or chest to penetrate the visible floor.

Limb behaviour

Time

	

Arms

	

Rear legs




0.00–0.40

	

Both planted; left starts weakening

	

PLANTED




0.40–0.85

	

Left shifts to FREE, folding inward; right supports weight

	

PLANTED




0.85–1.15

	

Both FREE, arms dropping forward

	

IK weight decreases




1.15–1.65

	

Both fists spread outward and forward

	

FREE, knees collapse




1.65 onward

	

Hidden by melt-transition mesh

	

Hidden with character

Left arm collapse biases:

LegFL rx −32, rz +14 by 0.85.

ShinFL rx +58 by 0.85.

FootFL rx +20 by 1.15.

Right arm follows approximately 0.22 seconds later:

LegFR rx −28, rz −12.

ShinFR rx +52.

FootFR rx +16.

Rear legs collapse with LegBL/BR rx −25 and ShinBL/BR rx +45 by 1.35, allowing the hindquarters to sink.

Use a fast in ease as each supporting limb gives way, then a slow out as the mass settles.

Melt implementation

Do not try to squash the entire skinned Brute into a puddle through Root scaling alone. It would crush the eye, tusks, fins and shoulders into an unrecognizable pancake.

Use the two Blender-authored melt meshes:

GooMeltMound replaces the collapsing body silhouette between 1.55 and 2.30.

GooMeltFlat replaces the mound between 2.20 and 2.85.

Their crossfade must preserve apparent mass: as the mound loses height, the puddle gains area.

At 2.30, three dorsal fin remnants should still read from the side. At 2.85, they should have sunk into the puddle.

If the original rig lacks independent fin bones, their defeat droop must be sculpted into the melt mesh. Do not improvise independent fin rotation on joints that do not exist.

Matter motes

Use four prominent motes, not sixteen.

The Brute contains four matter, and the four-mote exit makes that readable.

Mote

	

Spawn

	

Initial motion




1

	

2.65

	

Rise 0.70 studs




2

	

2.73

	

Rise 1.05 studs




3

	

2.81

	

Rise 0.85 studs




4

	

2.89

	

Rise 1.20 studs

Each then curves towards its owner's matter-home destination, with a gentle arc approximately 2.0–2.6 studs above the puddle. Finish their visual departure by 3.55–3.70.

These are noncolliding, client-only visual markers. They do not alter server matter accounting.

Four readable lights are better than sixteen tiny sparks at phone-game distance. Secondary faint sparkles are optional, but they must not resemble additional matter units.

9. Sound specification

Use licensed Roblox library assets. These are sound categories and mix targets, not fabricated asset IDs.

Prioritize audible mid-range impact over sub-bass. The important sounds should remain recognizable through a phone speaker at moderate volume.

Event

	

Sound character

	

Target length

	

Relative gain




Pound rear-up

	

Thick elastic tension / rising wet stretch

	

0.25–0.35 s

	

0.40




Pound downstroke

	

Short displaced-air whoosh

	

0.12–0.20 s

	

0.55




Pound impact

	

Heavy wet thump with a crisp slap transient

	

0.20–0.32 s

	

1.00




Pound settle

	

Lower, bubbling jelly recoil

	

0.18–0.30 s

	

0.35




Grab wind-up

	

Pulled rubber / strained goo

	

0.30–0.45 s

	

0.45




Grab launch

	

Fast sticky elastic twang

	

0.15–0.25 s

	

0.75




Grab latch

	

Short adhesive pop

	

0.08–0.16 s

	

0.60




Grab yank

	

Rising wet whip returning towards body

	

0.25–0.40 s

	

0.65




Grab slam

	

Sharp slap over a heavy goo impact

	

0.20–0.30 s

	

0.90




Grab pin

	

Wet adhesive stretch and release

	

0.25–0.45 s

	

0.35




Chest wind-up

	

Low pulsing organic resonance

	

0.40–0.70 s

	

0.50




Chest thump 1

	

Deep hollow wet drumbeat

	

0.12–0.20 s

	

0.70




Chest thump 2

	

Stronger wet drumbeat with rising violet-energy accent

	

0.18–0.30 s

	

0.90




Shield forming

	

Soft liquid expansion / shimmering membrane

	

0.35–0.55 s

	

0.55




Pumped fists

	

Brief crackling goo accent on attacks

	

0.08–0.15 s

	

0.30




Hurt

	

Short squelch, surprised creature growl

	

0.20–0.35 s

	

0.65




Defeat collapse

	

Heavy deflating jelly slap

	

0.35–0.55 s

	

0.75




Defeat melt

	

Soft viscous bubbling, falling in pitch

	

0.70–1.00 s

	

0.40




Matter returning

	

Four soft bell-like luminous pops, not piercing

	

0.10–0.20 s each

	

0.35

The main impacts should have meaningful energy around 500 Hz–3 kHz, rather than relying exclusively on bass below 150 Hz.

When four Brutes attack simultaneously, apply per-listener sound concurrency limiting so their impacts do not stack into distorted noise. Preserve at least one clear impact; reduce or suppress redundant nearby layers.

No camera shake.

10. Client FX budget and pooling

Shared scene budget: 34 particle births/second, 2 dynamic lights, 24 loose fragments.

The Brute's sculpted FX should require no loose physical fragments and ideally no dynamic lights. The emissive mesh masks supply the visible glow.

A. Two Brutes executing the same move simultaneously

Move

	

Concurrent major visual meshes

	

Particles / motes

	

Lights

	

Loose fragments




KNUCKLE POUND

	

2 splash crowns + 2 flat rims

	

Up to 6 droplets total

	

0

	

0




STRETCH GRAB

	

Up to 2 active ropes + 2 hands + 2 wraps/pins, using transitions

	

Up to 6 droplets

	

0

	

0




CHEST THUMP

	

2 main shields, plus one shield per unique buffed ally

	

Optional 2–4 tiny droplets total

	

0

	

0




HURT

	

No required detached major mesh

	

Up to 4 droplets total

	

0

	

0




DEFEAT

	

Up to 4 melt meshes during crossfades

	

8 large visual motes total

	

0

	

0

Transient geometry must be pooled. Do not instantiate fresh copies of the FX meshes during every 1.25-second passive hit.

Use one template asset per unique mesh design, cloned or pooled into each active effect instance. That is separate from the number of visible instances.

Motes can use the Titan's existing anchored, noncolliding marker approach. They are not physics fragments.

B. Whole army: eight Twins and four Brutes using passives

For a conservative shared budget, assign:

Unit

	

Attack frequency

	

Droplets per attack

	

Average particles/s




8 Twins

	

8.0 attacks/s

	

2

	

16.0




4 Brutes

	

3.2 attacks/s

	

3

	

9.6




Total

	

11.2 attacks/s

	

—

	

25.6

This leaves approximately 8.4 particle births/s for nearby non-passive effects.

Those Twin droplet allocations are a provisional shared-budget allowance, not the Twin's animation specification.

For heavy scenes, use a global token-bucket emitter capped at 34 particles/s with a bounded short burst. Lower-priority ambient droplets are discarded before important attack cues.

The impact meshes must remain visible even when particle emission is throttled.

FX performance gates

Target 600–1,200 triangles for ordinary primary attack FX meshes, subject to preserving the sculpted outline.

Prefer a maximum of roughly 1,500 triangles for a Brute shield shell. Translucent fill-rate may be more limiting than triangles.

Allow only one visible shield shell per unit even when several Brutes apply buffs.

At lowest supported phone quality, simplify distant shields and suppress secondary droplets before degrading attack silhouettes.

Never use per-frame mesh reimporting or unbounded runtime mesh generation.

Recycle splash meshes once their effects end; do not leave transparent shells in the workspace indefinitely.

Roblox bone animation is a visual deformation system and does not deform a character's physics collision shape. Bone transforms also are not automatically replicated. This is consistent with the existing client-local procedural animator, but the actual grab, damage, hold and shield state must remain server-authoritative. 
Documentation - Roblox Creator Hub
+1

The server needs to communicate authoritative T0, move identity, selected target where applicable, and buff/hold state. The client renders the appropriate mesh/pose timeline from those facts.

11. Reference-match stills and acceptance criteria

Use consistent framing, lighting and orientation against the generated reference sheets.

Capture the Brute in neutral Studio lighting, then check the same frames under actual game lighting and at phone-camera distance.

KNUCKLE POUND

Reference: 3-frame attack sheet + FX cell 1

Still

	

Time

	

What must be visible




P1

	

0.42

	

Both fists above head, broad chest exposed, rear feet planted




P2

	

0.60

	

Both fists on ground, shoulders driven low, arms compressed




P3

	

0.70

	

One sculpted crown and a flat irregular spreading ring




P4

	

0.88

	

Body rocking back while fists remain down

Reject if: fists land separately, hands visibly float, shoulder geometry becomes narrow/humanoid, or splash resembles a set of squashed spheres.

STRETCH GRAB

Reference: 4-frame attack sheet + FX cells 2–3

Still

	

Time

	

What must be visible




G1

	

0.40

	

Left fist planted, right pulled back, eye locked on target




G2

	

0.72

	

Long, thin glossy arm, open sticky palm at its far end




G3

	

0.95

	

Curved, recoiling arm with trailing strands and wrapped target




G4

	

1.38

	

Slammed fist, lumpy pin patch and ground-tether strands

Reject if: rope looks like a cylinder, the grab hand is missing, the original fist duplicates the extended hand, or the pin is a stack of round blobs.

At full range, verify the arm truly reaches a target 14 studs away without detaching from the shoulder or stretching the torso into an unnatural shape.

CHEST THUMP

Reference: 4-frame attack sheet + FX cells 4–6

Still

	

Time

	

What must be visible




C1

	

0.55

	

Upright heavy chest, fists pulled back




C2

	

0.80

	

Fist contacting chest, violet core flare, visible ripple




C3

	

1.08

	

Entire upright Brute enclosed by thick wobbly shield; small ally shield nearby




C4

	

1.55

	

Brute back on knuckles, clearly visible through shield, powered-up fists

Reject if: shield looks like an ordinary glass sphere, cracks disappear, base floats above ground, ally bubble is missing, or the creature becomes too obscured to see its eye and fists.

HURT and DEFEAT

Still

	

Time

	

What must be visible




H1

	

0.15

	

Left shoulder indented, opposite fist supporting weight, visible impact droplets




H2

	

0.40

	

Shoulder springing back, eye open, no permanent deformation




D1

	

0.35

	

Dazed and unbalanced, one arm buckling




D2

	

1.30

	

Chest down, arms spreading, eye shut




D3

	

2.40

	

Broad melting mass, three remaining drooping fins




D4

	

3.30

	

Flat puddle with four luminous matter motes leaving

Reject if: the body simply scales down like a balloon, the fins remain rigidly upright during the melt, the closed eye sticks out of the goo mound, or the four matter motes are too small to distinguish.

12. Merge gates before James plays

Gate 1 — Timing and gameplay

Pound damage at 0.60 within a 1.25-second cycle; Grab warning 0.50, slam 1.30 and hold exactly 0.50; Chest activation 0.80 with proper shield and speed-buff expiry.

Gate 2 — Contacts and extension

Both Pound fists and Grab's final slam contact are within −0.03 to +0.16 studs of the terrain. No hind-foot sliding or unreachable rear-up IK. Grab reaches 14 studs without tearing.

Gate 3 — Reference silhouettes

All six primary FX types are recognizable against the approved effect sheet. No primitive-looking splash lobes, straight recoil rope, perfect shield sphere or spherical goo pin.

Gate 4 — Overlay integrity

Committed hurt never breaks attack IK. Eye never clips out of face. Shields follow their owners, do not duplicate per source, and expire correctly.

Gate 5 — Stress test

Two Brutes doing the same move, followed by four Brutes and eight Twins using passives, remain within 34 particles/s, two dynamic lights and 24 loose fragments.

Final build direction

The three highest-priority visual matches are the overhead-to-ground double hammer, the truly elastic grab rope with its curved recoil, and the thick transparent jelly shield enclosing the creature.

For the build, I would prioritize Blender FX silhouette fidelity ahead of adding more particles, sounds or secondary polish. The Brute has unusually distinctive proportions; a primitive-looking splash or a geometrically perfect shield will stand out much more than the absence of a few small droplets.

After implementation, James should judge the Brute at normal phone-game camera distance first, then inspect the close-up stills. Every attack needs to be immediately distinguishable by body language, even before its effect appears.

Final disposition: GO TO BUILD. Not yet a measured runtime PASS. The pose angles, contact targets and timings above are the implementation targets; the contact clearances and final silhouettes must be verified in Play before accepting the batch.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High