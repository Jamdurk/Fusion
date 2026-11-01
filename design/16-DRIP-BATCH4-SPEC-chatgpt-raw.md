You said:
drip-brief.md
Document
titan-as-built-spec.md
Document
Now please switch from images to the ANIMATION SPEC for the Drip (Thinking, high). All the images in this chat are the references to match. Attached: drip-brief.md (the rig, what the animator can do, the 3 abilities from the power graph, lessons from the last batch, and exactly what I need back) and titan-as-built-spec.md (a previous as-built spec, for the format and conventions).
Worked for 6m 13s
ChatGPT said:
ALIEN FUSION — Animation Batch 4: DRIP (SQUISH F1)

REFERENCE-LOCKED BUILD SPEC · 28 OCTOBER 2026 · PROPOSED, NOT YET MEASURED IN PLAY

Verdict: READY TO BUILD, with three rig/asset requirements.

The Drip should feel like a living water balloon: almost weightless during a hop, explosively elastic when escaping, and genuinely adhesive when attacking. Its eye remains readable and stable, while the surrounding body, curl and little feet communicate the motion.

The reference sheets from this conversation are the visual authority. The supplied power graph is the gameplay authority. If animation and combat disagree, correct the presentation rather than silently changing damage, range or cooldowns.

1. Rig decisions

Keep SquishF1v5, its existing dimensions and the existing eye-stabilisation skinning.

Three additions are necessary to reproduce the reference sheets faithfully:

DentL / DentR bones: add two optional deformation bones at model-space rest positions (-0.78, 0.82, 0.02) and (0.78, 0.82, 0.02), parented to Body. Weight only the lateral cheek/body surface, not the rigid eye patch. Maximum inward displacement: 0.16 studs.

Flat pancake and melt meshes: author a separate flattened Drip mesh and a partially melted Drip mesh. The animator has translations and rotations, not true squash scaling. Do not attempt to create the completely flat reference pose solely by rotating the Body and Top bones.

Spiral-eye overlay: author one lightweight iris overlay for the defeat daze, attached to the rigid eye region. This is a temporary appearance change, not an extra independently wobbling eye.

The ordinary hopping, clinging, biting and flying poses stay procedural.

Coordinate conventions

All values below use the supplied model-space coordinates:

+X = Drip's right; -X = Drip's left.

+Y = up; -Z = forward.

Angles are degrees. rx, ry, rz are local bone rotations.

ox, oy, oz are additional local bone translations in studs.

Unlisted channels remain at their rest values; interpolations use smooth unless otherwise specified.

Root translations used for presentation must not double-apply authoritative gameplay movement.

A positive Curl.rx bends its upper mass backward toward +Z; a negative value flops it forward.

All contact coordinates are solver targets, not claims about measured geometry. The actual nub-tip offsets must be calibrated against the imported mesh in Play.

2. Timing contract

Move

	

Warning / anticipation

	

Hit or decisive event

	

Body free / hand-off

	

Effects end




HOP gait

	

0.00–0.12

	

LAND at 0.42

	

0.44, next cycle

	

0.70




IDLE

	

—

	

—

	

Continuous, 1.60 s cycle

	

—




CLING hop-on

	

0.00–0.16

	

Surface contact 0.68

	

CLING at 0.82

	

Contact splash 1.08




CLING BITE

	

0.00–0.16 of each cycle

	

0.24

	

Cycle repeats at 0.50

	

Each bite FX +0.20




BOING — SAFE

	

0.00–0.12

	

Escape launch 0.12; land 0.52

	

0.70

	

0.95




BOING — SQUASHED

	

0.00–0.06

	

Flat by 0.06; defensive damage resolution is server-timed

	

0.80 nominal

	

0.95




BOING BOMBS

	

0.00–0.55

	

SPLAT ON 1.25; first bite 1.31

	

CLING by 1.45

	

2.05




HURT

	

—

	

Impact 0.00

	

Additive, 0.35 weight while committed

	

0.52




DEFEAT

	

—

	

Melt complete 2.20; mote rises 2.35

	

Terminal, never returns to idle

	

3.70

For BOING BOMBS, allow a deterministic launch stagger of 0.00–0.10 s across units assigned to the same target. Offset that unit's subsequent events by the same amount.

These timings are initial implementation targets. Keep the 0.50-second bite interval, 0.55-second BOING BOMBS warning, and the server's actual damage timing exact.

Gameplay invariants

Mechanic

	

Must remain




Base Drip

	

1 matter, 100 HP, 22 studs/s




CLING

	

6 damage every 0.50 s while attached




GOOED

	

6+ Drips: ×1.75 versus Titan, ×2 versus Brute




BOING

	

Titan danger only, 10 s cooldown, escape up to 10 studs




BOING failure

	

Flatten and take half damage




BOING BOMBS

	

24 s cooldown, 12-stud activation range, max 10 Drips per target




BOING BOMBS bonus

	

+15 on the first bite, only if its target survives until that bite




Particles

	

34/s maximum per client, shared




Lights / camera shake

	

0 / 0

The brief does not define whether GOOED multiplies the extra +15 damage. Preserve whichever ordering the authoritative power graph actually implements; the VFX must not introduce a new damage rule.

3. HOP — movement keys

Reference: MOVEMENT sheet, top row · 0.44 s moving hop cycle

The hop must have four unmistakable silhouettes: wide squash, narrow upward spring, round airborne Drip, and feet-first landing. Preserve the body outline and the large eye from the model sheet.

Keyframes

Root.y means animated vertical lift. Body.oy and Top.oy are offsets from their rest positions.

Time

	

Root lift

	

Body / Top

	

Curl.rx

	

Arms / feet




0.00 SQUASH

	

0.00

	

Body oy -0.13, Top oy -0.10

	

-32°

	

Arms out 0.10; feet spread 0.10




0.10 COMPRESS

	

0.00

	

Body -0.20, Top -0.13

	

-25°

	

Feet planted, both level




0.16 SPRING

	

+0.32

	

Body +0.12, Top +0.15

	

+34°

	

Feet tuck up +0.16 and back +0.10




0.28 AIR

	

+0.94

	

Body 0.00, Top +0.04

	

+10°

	

Arms out 0.14; feet tuck +0.12




0.38 DESCEND

	

+0.38

	

Body -0.02, Top 0.00

	

-8°

	

Feet extend to landing pose




0.42 LAND

	

0.00

	

Body -0.13, Top -0.06

	

-28°

	

Both soles contact; arms bounce out




0.44 RECOVER

	

+0.03

	

Body -0.08, Top -0.04

	

-10°

	

Begin next hop

Use in for 0.10–0.16, out for 0.16–0.28, and smooth for the landing and recovery.

The leading spring pose should look tall primarily because of the Body/Top extension, not an enormous jump height.

Feet: mandatory ground contacts

Rest positions provided for the foot bones are at Y = 0.38, but the mesh's precise sole-tip offsets have not been supplied. Calibrate those once, then use the sole as the contact point.

Contact

	

Model-space sole target (studs)




Left sole

	

(-0.40, 0.04, -0.06)




Right sole

	

(0.40, 0.04, -0.06)




Squash left

	

(-0.50, 0.04, -0.06)




Squash right

	

(0.50, 0.04, -0.06)

The contact solver must operate on the transformed sole tips, not put the Foot bone origins at Y = 0.04.

At landing, allow a measured clearance of 0.02–0.06 studs above the sampled ground. Keep both soles within 0.05 studs of each other's landing time. During the planted 0.00–0.10 interval, correct the foot bones to prevent ground sliding.

HOP effects

At 0.42:

Reuse a ring mesh: diameter 1.25, thickness 0.045. Expand from 0.40 to 1.00 of authored size in 0.10 s, then dissolve by +0.22.

Reuse a puddle mesh: final diameter 0.90, thickness 0.045, four uneven shallow lobes. Fade by +0.28.

At most two tiny teardrop meshes, 0.08–0.13 studs across.

The effect is attached to the landing ground point, not the moving character. It should resemble the small HOP SPLAT reference, not a damaging shockwave.

4. IDLE — secondary motion

Reference: MOVEMENT sheet, IDLE · 1.60 s loop

Time

	

Body

	

Top

	

Curl

	

Eye / feet




0.00

	

oy 0

	

ry 0°

	

rz +6°

	

Neutral




0.40

	

oy +0.07, ry +7°

	

ry +5°

	

rz -12°

	

Both feet planted




0.80

	

oy 0

	

ry 0°

	

rz +4°

	

Blink, L = 60




1.20

	

oy +0.05, ry -9°

	

ry -5°

	

rz +14°

	

Feet planted




1.60

	

oy 0, ry 0°

	

ry 0°

	

rz +6°

	

Return

Blink interval: 0.75–0.88 s, with the lid fully shut at 0.80.

Body yaw makes the single big eye appear to glance around. Do not slide or rotate the eye independently of its rigidly skinned patch.

The body can bob, but the soles should not leave the ground during ordinary idle.

5. CLING — passive attack

Reference: MOVEMENT sheet, CLING and CLING BITE

This is the Drip's most important repeated combat animation. The creature must look stuck onto the enemy, not merely floating beside it.

5A. Hop onto the target

Use an aimed arc toward an actual surface point on the target. The surface point must be stored in the target's local coordinate system so the Drip follows a moving Brute or Titan.

Time

	

Root / movement

	

Body and Top

	

Curl.rx

	

Event




0.00

	

Grounded

	

Neutral

	

-10°

	

Select valid surface




0.12

	

Grounded

	

Body oy -0.16, Top -0.10

	

+28°

	

Compress




0.20

	

Begin arc

	

Body +0.10, Top +0.12

	

+32°

	

Launch puff




0.43

	

Arc apex

	

Body 0.00, Top +0.06

	

+18°

	

Tiny droplets




0.60

	

Approach surface

	

Body rx -12°, Top oy -0.08

	

-12°

	

Feet reach toward rock




0.68

	

Surface contact

	

Body toward surface 0.16; Top oy -0.20

	

-25°

	

Sticky contact




0.82

	

Fully CLINGING

	

Body flattened toward surface

	

-12°

	

Begin attached idle

The root follows the aimed arc; bone offsets add the pose. Target death or invalidation must cancel the attachment without leaving an orphaned Drip or goo mesh.

5B. Contact correction on a moving surface

Define:

P: chosen world-space point on the enemy's visible surface.

N: outward surface normal.

U: an upward tangent on the surface.

R: right-hand tangent, perpendicular to N and U.

The desired centre of the Drip's sticky patch is P + 0.06N.

Model-space attachment landmarks

Body contact patch centre	

(0, 0.64, -0.72)


Left gripping nub	

(-0.66, 0.74, -0.18)


Right gripping nub	

(0.66, 0.74, -0.18)


Left foot sole	

(-0.40, 0.04, -0.06)


Right foot sole	

(0.40, 0.04, -0.06)

These are target landmarks; the nub-tip and body-contact landmark positions must be validated against the imported geometry before solving.

Arrange the attached points approximately as follows:

Feature

	

Desired world-space position




Sticky body patch

	

P + 0.06N




Left nub contact

	

P - 0.48R + 0.12U + 0.06N




Right nub contact

	

P + 0.48R + 0.12U + 0.06N




Left foot contact

	

P - 0.34R - 0.34U + 0.06N




Right foot contact

	

P + 0.34R - 0.34U + 0.06N

Correction priorities: main sticky patch first, rigid eye clearance second, nub contacts third.

Keep the contact patch within 0.08 studs of the target surface.

Keep the visible eye at least 0.10 studs outside the rock.

Try to keep gripping nub tips within 0.12 studs of their target contacts.

Rotate the whole Drip around the attachment normal by approximately 25–35° when needed to keep the face visible from the gameplay camera. Check eye clearance again after this rotation.

If the tiny nubs cannot reach, let the authored goo strands bridge the remaining distance. Do not stretch a nub into a long arm.

Run contact correction after the ordinary animation blend and after the parent's transform is resolved. Otherwise a Body pitch will undo the correction, the same class of failure seen in the earlier Titan work.

The reused pin mesh provides the sticky body-to-surface connection. The creature itself should remain rounded enough to retain its Drip silhouette.

5C. CLING idle and BITE cycle

While attached, the body breathes against the surface with a 0.07-stud outward/inward pulse over 0.50 s. The pin stays attached to the surface; only its visual strands flex.

The BITE is a 0.50-second repeat.

Here, Δn is an additional displacement along the world-space outward normal: positive moves away from the enemy, negative toward it.

Phase

	

Time

	

Body

	

Top / Curl

	

Arms and feet




HOLD

	

0.00

	

Δn 0.00

	

Curl rx -12°

	

Gripped




WIND

	

0.10

	

Δn +0.08, rx +7°

	

Top oy +0.04; Curl +18°

	

Keep contacts




LUNGE

	

0.24

	

Δn -0.13, rx -11°

	

Top oy -0.10; Curl -32°

	

Nubs tighten




REBOUND

	

0.33

	

Δn +0.06, rx +4°

	

Top oy +0.03; Curl +15°

	

Gripped




SETTLE

	

0.50

	

Δn 0.00, rx 0°

	

Curl -12°

	

Return

At 0.24, reuse a 6-spike crown for the little BITE SPLAT, 0.60 studs across and 0.20 deep. Its effect duration is 0.20 s.

Keep the bite lunge visibly directional, but don't bury the giant eye in the enemy's surface. The collision appearance can be carried by the little outward goo burst.

Damage remains server-authoritative: one successful bite every 0.50 s while attached. The client animation cannot create an additional damage event or reset the interval when a visual loop restarts.

5D. GOOED — the six-Drip threshold

This needs a readable visual change, but not six separate oversized effects.

At the server-confirmed transition from five to six attached Drips:

Add one shared irregular cyan-blue goo overlay to the enemy's upper back/shoulder area, roughly 2.4–3.2 studs across depending on target size.

Pulse its cyan cracks and violet underside once over 0.45 s; the emissive highlights brighten by approximately 30%, without adding lights.

Keep a subtle 1.00-second pulse while the enemy remains GOOED.

When attached count drops below six, fade the shared overlay over 0.30 s.

The shared overlay must be keyed to the target, not the Drips. It must not be spawned afresh by every bite.

Use the existing GOOED damage multipliers exactly as specified. The overlay is feedback, not a separate area attack.

6. BOING — automatic defensive move

Reference: BOING sheet · ALERT → SPRING → FLIGHT → SAFE LANDING / SQUASHED

The attack has two mutually exclusive visual outcomes. The server chooses the outcome based on the Titan danger shape and the available escape point; the animator must not choose it independently.

6A. SAFE — spring clear

Let s = +1 for an escape to Drip's right or -1 for left. Mirror all lateral rotations and offsets.

Time

	

Root / movement

	

Body / Top

	

Curl

	

Arms / feet




0.00 ALERT

	

Stationary

	

Body oy -0.06

	

Curl rx -12°

	

Nubs raised




0.08 CROUCH

	

Root roll -8s°

	

Body oy -0.22, Top -0.14

	

Curl rz +18s°

	

Feet spread ±0.10




0.12 SPRING

	

Launch toward escape point

	

Body oy +0.18, Top +0.16; roll -18s°

	

Curl rz +30s°

	

Feet kick back +0.16




0.30 FLIGHT

	

Arc apex

	

Body rx -12°, roll -10s°

	

Curl rz +42s°

	

Feet tucked, arms back




0.45 DESCENT

	

Approach destination

	

Body relaxes; roll -4s°

	

Curl rz +18s°

	

Feet down




0.52 LAND

	

Both soles at destination

	

Body oy -0.17, Top -0.10

	

Curl rx -32°

	

Splat contact




0.62 WOBBLE

	

Root stationary

	

Body rz +9s°, Top rz -6s°

	

Curl rz -18s°

	

Feet planted




0.70 SAFE

	

Normal pose

	

Return to rest

	

Return to rest

	

Movement unlocked

The ALERT pose should point the curl upward as much as the existing Curl bone allows. Do not translate the rigid eye out of the face to exaggerate surprise. If the curl silhouette cannot appear sufficiently upright with its current single-bone deformation, use a brief alternate curl shape rather than stretching the whole eye region.

Escape trajectory

Use the server-selected nearest safe edge point, at most 10 studs away.

Interpolate horizontal movement from 0.12 to 0.52 s, using the server's movement authority.

Add a visual vertical arc with peak elevation 2.10 studs above the interpolated ground path at the middle of the flight.

Keep the visual root aligned to the authoritative position; do not apply the 10-stud lateral motion a second time as an animation offset.

At touchdown, align both feet to the sampled destination ground. Neither foot should penetrate more than 0.03 studs.

Use the actual selected escape distance; do not always travel 10 studs.

When the server confirms the escape, the model must visibly finish outside the danger shape. A successful-looking landing inside the Titan's telegraph is a failed implementation.

SAFE effects

Event

	

Time

	

Mesh / action




Alert

	

0.00

	

Brief cyan brightening of existing cracks, +20%




Launch

	

0.12

	

Reused mound + 2 drops, 0.70-stud puff




Flight

	

0.20 and 0.34

	

1–2 small drop meshes, 0.10–0.16 studs




Landing

	

0.52

	

Reused ring + puddle, 1.20-stud splat




Wobble

	

0.62

	

No extra FX; silhouette alone

Keep the launch puff at the original ground location. Do not parent it to the flying Drip.

6B. SQUASHED — the escape fails

This is the most visually demanding pose because the reference depicts a genuine pancake with the eye on its upper surface.

Use the dedicated flattened Drip mesh, not an aggressively rotated ordinary body.

Time

	

State

	

Visual




0.00

	

Danger confirmed

	

Sudden eye squint; curl jolts upward




0.03

	

Collapse

	

Body drops toward ground, original mesh begins disappearing




0.06

	

Fully flat

	

Pancake mesh visible at full size




0.06–0.40

	

HOLD

	

Flat, faint jelly tremor; little glowing cracks remain




0.40–0.56

	

RELEASE

	

Pancake pulls inward, eye rises first




0.56–0.70

	

POP

	

Original skinned Drip returns, Top oy +0.12




0.70–0.80

	

REBOUND

	

Top settles, Curl rx -25° then +12°




0.80

	

READY

	

Normal movement resumes if server permits

The 0.40 s hold is nominal. Do not release the pancake before the server has resolved the threatening hit. Delay its recovery if necessary.

Pancake mesh target dimensions: 2.10 wide × 0.22 high × 1.80 deep studs, including its shallow lobes, excluding any small eye bulge. The top-facing eye should still be recognisably purple and white, approximately 0.80 studs across, and integrated into the flat mesh rather than floating above it.

On release, one tiny puddle/ripple effect (diameter 0.85) is enough. Do not use a large explosion.

Gameplay: the pancake takes half the applicable damage, not zero. Defensive damage resolution must stay independent of how quickly the mesh transition renders.

No new danger marker is needed: BOING responds to the Titan's existing telegraph. Adding a second warning would imply a separate attack.

7. BOING BOMBS — ordered swarm leap

Reference: BOING BOMBS sheet · WIND-UP → LAUNCH → DIVE → SPLAT ON

This should be the most recognisable Drip attack at a glance: a little blue comet launches, curls up, then sticks to a large enemy in a spectacular but small-scale splash.

One Drip owns one trajectory and one impact splat. At the target level, share the warning marker. Do not create ten identical large target markers.

Keyframes

Times below exclude the optional 0.00–0.10 s per-unit stagger.

Time

	

Pose

	

Root / body

	

Top / Curl

	

Nubs




0.00

	

WIND-UP

	

Body oy -0.08; root pitch -5°

	

Curl rx +10°

	

Feet grounded




0.40

	

DEEP CROUCH

	

Body oy -0.23, Top -0.14; pitch -12°

	

Curl rx +38°

	

Arms drawn inward




0.55

	

RELEASE READY

	

Body oy -0.26, Top -0.16

	

Curl +42°

	

Both soles still touching




0.60

	

LAUNCH

	

Begin target arc; Body oy +0.16

	

Top +0.18; Curl +32°

	

Feet kick back +0.18




0.91

	

ARC / BALL

	

Near apex; Body compact

	

Top oy -0.08; Curl rx +15°

	

Arms and feet tucked




1.10

	

DIVE

	

Root orient toward impact; Body rx -35°

	

Top -0.06; Curl +45° trailing

	

Feet tucked




1.25

	

SPLAT ON

	

Body patch contacts target; Body oy -0.24

	

Top -0.18; Curl rx -28°

	

Nubs contact surface




1.31

	

FIRST BITE

	

Short face lunge, Δn -0.10

	

Curl snaps forward -36°

	

Maintain grip




1.45

	

HAND-OFF

	

Begin regular CLING idle

	

Curl -12°

	

Attached

Body oy and Top oy remain bone offsets; they must not be used as the entire flight trajectory.

At 1.31, the first bite receives the existing +15 bonus, provided the target is still alive and the bite is accepted by the server. Subsequent bites repeat at 0.50 s intervals without that bonus.

Aimed flight path

At the start of the order, store an attachment point in the target's local coordinates, with a surface normal. At each animation update, resolve its current world-space location so the Drip can follow a moving target.

For a flight starting at S, with current destination P(t), use:

𝑄
(
𝑢
)
=
(
1
−
𝑢
)
𝑆
+
𝑢
𝑃
(
𝑡
)
+
4
ℎ
𝑢
(
1
−
𝑢
)
𝑌
^
Q(u)=(1−u)S+uP(t)+4hu(1−u)
Y
^

where 
𝑢
u progresses from 0 to 1 over 0.60–1.25 s, and

ℎ
=
clamp
⁡
(
2.5
+
0.4
∣
𝑃
𝑦
−
𝑆
𝑦
∣
,
  
2.5
,
  
9.0
)
h=clamp(2.5+0.4∣P
y
	​

−S
y
	​

∣,2.5,9.0)

All distances are studs. This gives a visibly raised arc even when the target's back is well above the ground.

This is an initial trajectory, not a replacement for collision checking. If the straight-through interpolation cuts through a limb or the Titan's body, use a collision-cleared intermediate control point while preserving the arrival time and overall silhouette.

The final segment should visibly descend toward the selected surface, not float horizontally into it.

Surface contacts at impact

At 1.25:

The same Body contact patch landmark from CLING must align to P + 0.06N.

Body pitch compresses into the target, but the rigid eye must stay at least 0.10 studs clear.

Left/right nub tips should reach the target surface or be connected by sticky strands.

The giant's surface normal determines how the splat sits, including on sloped backs.

The goo splat itself is owned by the target's moving attachment, not by an independent world-space anchor.

Maximum acceptable attachment correction after touchdown: 0.12 studs, measured from the visible sticky patch to the collision surface. If the target moves rapidly during flight, interpolate its attachment position; never teleport the Drip on impact.

Warning marker: 0.00–0.55

Use a single target-surface mark on each enemy receiving BOING BOMBS.

Form: irregular cyan ring, approximately 1.50 studs diameter, following the target surface.

Bright edge: #37F5FF, approximately 0.08 studs wide.

Dark underlay: #28201B, approximately 0.14 studs wide.

Fill: translucent dark teal, not fully bright cyan Neon.

Timing: appear at 0.00, expand slightly from 0.85 to 1.00 scale by 0.40, pulse twice between 0.40 and 0.55, then disappear when launching begins.

One marker per recipient target, regardless of the number of incoming Drips.

This is an incoming-swarm indicator, not an area-damage warning. Do not draw a false danger circle on the ground or imply that BOING BOMBS damages a region around the Titan.

If no Drips are assigned to an enemy, do not display the mark.

Impact effects: 1.25–2.05

Use the new sloped-surface splat mesh described below.

Relative time from impact

	

Action




+0.00

	

New splat visible at 0.30 scale




+0.08

	

Spreads to 0.80 scale; 2 tiny droplets




+0.17

	

Full 1.00 scale, glossy cyan lobes visible




+0.25

	

Three or four short drips hang downward




+0.45

	

Surface splash begins fading into the smaller CLING pin




+0.80

	

Large temporary splat gone; permanent CLING pin remains

The main splat remains attached to the moving target. Do not make it spray backward through the enemy's surface.

If the target dies before the first bite, remove the planned +15 bonus and abort attachment as the server directs. The Drip may fall toward a valid ground point; it must not remain attached to a destroyed part.

Ten-Drip readability

For multiple assigned Drips, use server-selected surface slots, not ten Drips sharing exactly the same attachment point.

Aim for approximately 0.9–1.2 studs of spacing between adjacent contact patches where the target surface permits. Use a deterministic surface-placement pattern, with the server validating the chosen locations. If ten cannot fit visibly on a small body region, distribute them onto other valid back/side surfaces; don't extend the target's hitbox or silently change the ten-unit gameplay cap.

The stagger and slightly separated landing locations should make a swarm look like many individual goo creatures, rather than one giant cyan explosion.

8. HURT — additive, 0.52 seconds

Reference: HURT sheet · lateral dent, droplets, jelly overshoot

The image establishes two readable poses: the instant dent-and-recoil, followed by the body springing past upright.

Use the two new Dent bones. For an impact from Drip's left (-X), move DentL inward toward +X. Mirror every lateral channel for a right-side impact.

Keyframes — hit from left

Time

	

Root / Body

	

Top

	

Curl

	

DentL

	

Lid




0.00

	

Neutral

	

Neutral

	

Neutral

	

0

	

L 0




0.07

	

Root rz -19°; Body ox +0.10, oy -0.06

	

rz -11°

	

rz +32°

	

ox +0.16

	

L 26




0.16

	

Root rz -12°; Body ox +0.07

	

rz -6°

	

rz +20°

	

ox +0.10

	

L 20




0.27

	

Root rz +9°; Body ox -0.05

	

rz +7°

	

rz -22°

	

ox -0.025

	

L 8




0.40

	

Root rz -3°

	

rz -2°

	

rz +8°

	

0

	

L 0




0.52

	

Neutral

	

Neutral

	

Neutral

	

0

	

L 0

Ease sharply into the initial impact (out), then use smooth for the recovery and overshoot. The dent must visibly recover rather than remain as a flattened cheek.

For an impact from the right, apply the opposite signs to X displacement, lateral rolls and curl sway; use DentR instead of DentL. Front/back impacts use the general squash and recoil without forcing a false lateral dent.

HURT effects and contacts

At 0.03, spawn 2–4 small reused drop meshes from the struck cheek:

Diameters 0.10–0.22 studs.

Initial movement 0.8–1.6 studs away from the contact point.

Lifetime 0.22–0.35 seconds.

No persistent puddle required.

Keep both soles within 0.06 studs of the ground during ordinary grounded HURT. On a CLINGING Drip, preserve the surface attachment and limit visible displacement away from the surface to 0.15 studs.

During a committed attack, blend HURT at 0.35 weight. Outside the commitment window, use 1.00. Apply the contact correction after the final blend.

The large eye should squint but never pop out or wobble independently. The rigid-eye solution from the previous Drip fix stays in force.

9. DEFEAT — terminal melt

Reference: DEFEAT sheet · dazed → melting → puddle with ONE rising matter mote

The defeat must remain gentle and recognisable on phones. It should not look like an explosion or a collection of body fragments.

Keyframes

Time

	

Body / Root

	

Top / Curl

	

Eye

	

Replacement geometry




0.00

	

Root stationary

	

Small recoil

	

L 10

	

None




0.30

	

Body rz +12°, oy -0.10

	

Top rz -9°; Curl droops -28°

	

Spiral appears

	

None




0.55

	

Body rz -8°

	

Top rz +6°; Curl droops -42°

	

Spiral half-lidded

	

None




0.85

	

Body oy -0.35

	

Top oy -0.20; Curl folds down

	

L 35

	

Melt cap starts




1.20

	

Body oy -0.55

	

Top oy -0.45

	

L 50

	

Puddle emerges




1.65

	

Body oy -0.80

	

Top oy -0.72

	

L 60

	

Melt cap dominates




2.05

	

Original rig fully faded

	

—

	

Closed eye sinking

	

Flat puddle




2.20

	

No visible creature

	

—

	

Eye gone

	

Puddle at full size




2.35

	

—

	

—

	

—

	

ONE cyan mote emerges




3.20

	

—

	

—

	

—

	

Mote rises; puddle fades




3.70

	

—

	

—

	

—

	

Cleanup complete

For the daze, animate the spiral overlay's UV rotation approximately 180° over 0.45 s, followed by a short fade. If UV rotation is unsupported, use a short baked sequence rather than rotating the entire eyeball.

Melt transition

Author a DripMeltCap mesh: a low mound transitioning into a shallow puddle, with the closed eye partially embedded in its surface.

The original skinned model and this authored transition must crossfade over 1.30–2.05, not coexist as two obvious complete Drips.

Use a separate final puddle:

Diameter 2.20 × 2.00 studs.

Maximum central height 0.09 studs.

Four or five irregular rounded lobes.

Same glossy cyan-blue material and glowing cracks.

No eyeball remaining after 2.20.

The curl and nubs should appear to dissolve into the mound; they must not detach as solid body parts.

Exactly ONE matter mote

At 2.35 spawn:

One emissive cyan sphere, 0.22 studs diameter.

One faint curved trailing ribbon, approximately 0.75 studs long.

Vertical rise 1.60 studs over 0.85 seconds.

Subtle lateral drift, maximum 0.16 studs.

Sphere fades between 3.20 and 3.65.

No extra little orbital motes. No secondary light source. No particle explosion. The reference effect is a single glowing point leaving the puddle.

DEFEAT is terminal: its animation must never transition back into idle after completion. Release attached pins, bite events, temporary splats and any pending ability timeline when defeat begins. Guard the mote spawn so repeated defeat notifications cannot produce multiple motes.

10. Effects asset specification

Reference: six-panel EFFECTS sheet, plus the BOING and BOING BOMBS pose sheets

The glossy goo look matters more than sheer quantity of effects. The main shapes should be actual authored meshes; particles are reserved for tiny dots and sparkles.

Reuse versus new assets

Reference effect

	

Mesh choice

	

Authored size

	

Lifecycle




1 HOP SPLAT

	

Reuse ring + puddle

	

1.25 diameter / 0.90 diameter

	

0.28 s




2 LAUNCH PUFF

	

Reuse mound + drop

	

0.70 wide, drops 0.10–0.22

	

0.32 s




3 CLING STICK

	

Reuse pin (six-strand mesh)

	

0.95 wide, strands 0.35–0.85

	

Until detach




4 BITE SPLAT

	

Reuse crown6

	

0.60 wide × 0.20 deep

	

0.20 s




5 BOMB SPLAT

	

NEW DripSlopeSplat

	

1.85 wide × 1.60 tall incl. drips

	

0.80 s




6 MATTER MOTE

	

Reuse lump or a sphere + rope trail

	

Sphere diameter 0.22

	

1.30 s




GOOED target overlay

	

Reuse large surface-splat variant

	

2.4–3.2 wide

	

While GOOED




SQUASHED

	

NEW DripPancake

	

2.10 × 0.22 × 1.80

	

Defensive hold




DEFEAT transition

	

NEW DripMeltCap

	

2.20 × 0.65 × 1.90 at start

	

0.75 s crossfade

The two structural deformation meshes and the iris overlay are character presentation assets, not ordinary combat debris.

New DripSlopeSplat — important

The existing ground puddle and pool are not sufficient for the sloped-back BOING BOMBS reference.

Author one irregular organic splat with:

Seven or eight asymmetrical rounded perimeter lobes.

A raised central wet mound, approximately 0.12 studs deep.

Three large downward-running drips, lengths 0.45, 0.70 and 0.90 studs.

Two thinner connective strands at the upper edge.

Glowing cyan cracks that continue from the centre into the large lobes.

An underside violet tint, subdued enough not to resemble fire.

Build two baked curvature variants: one for relatively flat surfaces and one for rounded rock bodies. Orient the appropriate variant to the sampled surface normal. Roblox MeshParts cannot be assumed to deform themselves over arbitrary changing collision geometry; solve placement and choose the variant rather than pretending the mesh will wrap automatically.

The large impact version fades into the smaller permanent CLING pin.

Material and visibility

Reuse the established SQUISH palette, including:

Element

	

Colour / treatment




Main goo

	

Glossy blue-cyan, translucent appearance




Glowing cracks

	

Cyan #37F5FF




Bright interior highlights

	

Mint #A5FFD8




Violet underside

	

Violet #A56BFF, blended into deep purple




Warning line underlay

	

Dark #28201B




Telegraphed fill

	

Dark teal RGB(0,105,125), translucent

Do not make the entire splat a fully emissive white-cyan Neon surface. The reference has a glossy blue body with distinct glowing cracks and dots. Preserve that material separation.

Animation curves for effects

Effect

	

Scale / alpha behaviour




HOP SPLAT

	

Scale 0.40→1.00 over 0.10 s, then alpha 0→1 by 0.28




LAUNCH PUFF

	

Scale 0.30→1.00 over 0.07, fade by 0.32




CLING PIN

	

Scale 0.20→1.00 over 0.14, then sustained




BITE SPLAT

	

Scale 0.30→1.00 over 0.07, fade by 0.20




BOMB SPLAT

	

Scale 0.30→1.00 over 0.17; fade between +0.45 and +0.80




GOOED overlay

	

Scale 0.90→1.00 over 0.45, brightness pulse




MATTER MOTE

	

Fade in over 0.10, rise 0.85, then fade out

Here alpha 0 means fully visible and alpha 1 means transparent.

All effects should be non-colliding and pooled where possible. Temporary surface effects must follow their owning enemy attachment.

11. Sounds — phone-first specification

Use short, mid-frequency cartoon sounds rather than bass-heavy impact effects. The Drip is tiny: it should sound elastic, wet and energetic, not like the Titan.

The volumes below are suggested initial Roblox Sound.Volume values, subject to the actual asset mastering.

Event

	

Character

	

Length

	

Starting volume




HOP land

	

Tiny wet plip

	

0.10–0.16 s

	

0.35




CLING attach

	

Sticky shlup

	

0.18–0.28 s

	

0.55




BITE

	

Short wet pip/chomp

	

0.09–0.14 s

	

0.30




BOING wind-up

	

Rubber tension chirp

	

0.15–0.22 s

	

0.45




BOING launch

	

Sharp elastic boing

	

0.22–0.35 s

	

0.75




BOING pancake

	

Compressed wet fwup

	

0.18–0.25 s

	

0.65




BOING BOMBS launch

	

Higher-pitched spring

	

0.25–0.38 s

	

0.65




BOING BOMBS impact

	

Broad gooey slap

	

0.20–0.32 s

	

0.80




HURT

	

Tiny startled squeak + wet impact

	

0.15–0.25 s

	

0.50




DEFEAT melt

	

Falling, watery warble

	

0.45–0.70 s

	

0.55




MATTER MOTE

	

Small rising crystalline ping

	

0.35–0.60 s

	

0.45

Prioritise useful energy around roughly 450 Hz–3 kHz, where the sounds can remain audible on phone speakers. Don't use excessive sub-bass.

Do not play every one of 24 concurrent BITE sounds independently at full volume. For a swarm, aggregate bite sounds spatially per target and permit at most three short bite sounds per second per client, favouring the nearest or clearest contacts. Damage and visual bite timing continue normally even when a sound is skipped.

The 34 particles/s limit does not apply to sound playback, but sound polyphony still needs its own restraint.

12. Performance budget — 24 simultaneous CLINGING Drips

This is a swarm character, so the 24-unit case is a primary acceptance test, not an afterthought.

A nominal 24-Drip bite rate is:

24
×
1
0.5
=
48
 bites/second
24×
0.5
1
	​

=48 bites/second

Attempting to spawn several particles on every bite would exceed the shared 34 particles/s budget before any other combat effects appeared.

Required budget policy

System

	

Limit / decision




Regular BITE particles

	

0; use the authored crown mesh




Active CLING pins

	

1 pooled mesh per attached Drip




Active GOOED overlays

	

1 per affected target




Active bite crown FX

	

Pool up to 24 for coincident impact bursts




Bite FX lifetime

	

0.20 s maximum




Tiny droplet particles

	

Prefer mesh drops; cap overall client emissions at 34/s




CLING sounds

	

Aggregate; max 3 bite sounds/s/client




Lights

	

0




Camera shake

	

0




Surface raycasts

	

On attach and when necessary for a changed surface; not 24 full raycasts every render frame




Attachment transforms

	

Update every visible frame from stored target-local frames




DEFEAT mote

	

Exactly 1 per defeated Drip; no replicated gameplay projectile

At a perfectly even 48 bites/s and 0.20 s FX lifetime, average concurrent bite crowns would be about 10. But if the Drips synchronise, as they can during BOING BOMBS, concurrency could briefly reach 24.

Pool for the peak, not just the average.

Recommended LOD behaviour
Near	Full bite crown; six-strand CLING pin; tiny droplets allowed within global budget.
Medium	Full body animation and pin; suppress individual droplets; shorten crown lifetime to 0.14 s.
Far	Keep body pose and attached silhouettes; show only selected bite crowns; preserve GOOED overlay.

Use projected screen size to select LOD, rather than arbitrary world distances alone. A two-and-a-half-stud creature can become very small on a phone.

Maintain the existing shared client particle budget rather than reserving all 34/s for Drips. If another creature needs the budget, drop cosmetic Drip droplets first.

Implementation integrity

The following are hard requirements:

One authoritative bite clock per attached Drip. Client animation loops cannot schedule additional damage.

Attachments have ownership. Clear the stored target reference, pin mesh and bite state when detaching or dying.

Surface transforms are target-local. If a Brute turns, the Drip and its pin turn with the correct surface point.

GOOED is target-owned. Multiple Drips cannot create multiple independent GOOED overlays.

BOING escape is server-decided. No client-side success that contradicts the actual hit.

BOING BOMBS target assignment is authoritative. Respect activation range 12 and max 10 assigned Drips per target.

Never reuse a pooled FX object while it remains attached to a living target.

DEFEAT cancels every other timeline, including a pending first bite.

Contact correction happens after parent transforms and additive animation blending.

Use one shared source of time for authoritative impact events and matching visual timeline playback.

Where the server cannot know an exact mesh-surface collision point, the visual placement may use a validated approximation, but it must never redefine the damage target or damage timing.

13. Required MOVE TEST stills

Capture the following at the actual requested timestamps. Include at least one mobile-scale composite; don't judge only close-up hero renders.

Group

	

Stills to capture

	

What must be checked




HOP

	

0.00, 0.16, 0.28, 0.42

	

Wide squash, upright spring, round air silhouette, both feet landing together




IDLE

	

0.40, 1.20

	

Readable small bob, curl sway, no sliding




CLING hop-on

	

0.43, 0.68, 0.82

	

Arc, surface contact, eye clearance, sticky strands




CLING BITE

	

Phase 0.10, 0.24, 0.33

	

Visible face lunge, small impact splat, recovery




GOOED

	

5 attached versus 6 attached

	

Clear threshold read without overwhelming enemy silhouette




BOING SAFE

	

0.08, 0.12, 0.30, 0.52, 0.62

	

Compression, comet flight, correct escape direction, clean landing




BOING SQUASHED

	

0.06, 0.40, 0.65

	

Fully flat mesh, eye still visible, successful pop-back




BOING BOMBS

	

0.55, 0.60, 0.91, 1.10, 1.25, 1.45

	

Launch, arcing flight, compact dive, surface splat, CLING hand-off




HURT

	

0.07, 0.27

	

Indented side, lateral recoil, overshoot




DEFEAT

	

0.55, 1.65, 2.20, 2.90

	

Dazed spiral, melt, clean puddle, single mote




SWARM

	

24 Drips, 0.5 s bite cycle

	

Stable frame time, manageable FX, legible target

Final visual acceptance criteria

Movement: no visible foot penetration greater than 0.06 studs during normal landing. No rigid-eye clipping.

CLING: the visible sticky patch stays within 0.08 studs of the surface and survives target rotation/movement.

BOING: a visually successful escape ends at the server's actual safe point. Failed escape reads as a truly flat pancake.

BOING BOMBS: the Drip lands on the giant's actual moving surface, and the goo spreads across that surface rather than hovering above it.

DEFEAT: the body fully becomes a glossy puddle, with one and only one cyan matter mote rising.

Build order

Build and measure in this order: HOP/IDLE → CLING contact and BITE → BOING → BOING BOMBS → HURT → DEFEAT → 24-Drip performance test.

The CLING contact solver is the critical dependency. BOING BOMBS should reuse it rather than implement another surface attachment system. Similarly, the HOP landing effects and BOING launch effects should use the same mesh library with different parameters.

My strongest recommendation: spend the most iteration time on CLING and the BOING BOMBS hand-off. Those are the poses players will see repeatedly in a real match, and the most noticeable failures will be floating goo, misplaced eyes, or Drips sliding across a moving giant. A slightly imperfect curl angle is far less damaging than any of those.

The numbers above are the implementation baseline. In the first audit, bring back the measured sole clearances, body-to-surface distances, eye clearances, attack event timestamps, and two-target/24-Drip performance measurements. Those will determine which keys need changing in Play.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High