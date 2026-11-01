Now please switch from images to the ANIMATION SPEC for the Pebble (think hard). All five sheets in this chat (J1-J4, K) are the references to match. Attached: pebble-brief.md (the rig, what the animator can do, the 3 abilities from the power graph, the lessons, and exactly what I need back) and example-drip-spec.md (a previous spec you wrote, for the format and level of detail). Keep it buildable: concrete numbers, contact points, a short FX mesh list.
Worked for 4m 41s
ChatGPT said:
ALIEN FUSION — Animation Batch 5: PEBBLE (CRUNCH F1)

REFERENCE-LOCKED BUILD SPEC · 29 OCTOBER 2026 · PROPOSED, NOT YET MEASURED IN PLAY

Verdict: READY TO BUILD, with two mandatory geometry requirements: a reusable stone-ball replacement mesh and an authored shell-break/rubble sequence.

The Pebble should feel like a tiny, stubborn rock beetle: six fast skittering legs, a decisive horn strike, a lower mandible bite, and the ability to turn into a solid defensive projectile. It must look much heavier and harder than the Drip, despite sharing the same 100 HP and 22 studs/s movement speed.

The five sheets are the visual authority. The supplied power graph is the gameplay authority. If an animation timing conflicts with server damage, cooldowns or status application, adjust the animation rather than changing combat values.

1. Rig decisions and conventions

Keep CrunchF1v5, including the existing shell, crystals, eye, horn and six procedural tripod legs.

Three presentation assets are required:

PebbleStoneBall: one authored compact stone-ball mesh, reused for both CURL UP and ROLL OUT. The ordinary rig cannot realistically fold its six rocky legs, rigid head and shell into a round ball using rotations alone.

PebbleShellBreak: a break-state kit with separated shell plates and crystal pieces for DEFEAT. Parent-bone rotation cannot produce the sheet's fracture along individual magma seams.

PebbleRubble: one low rubble-pile mesh for the terminal state, with darkened crystals and nearly extinguished cracks.

No additional bones are mandatory. In particular, do not add mandible bones solely for CHIP. Use the Head's forward/downward snap and the bite-tear FX to communicate the bite. The mandibles remain rigidly skinned to Head. An independently closing jaw would require a later rig revision; don't invent one through impossible bone keys.

Coordinate conventions

Model space: +X = Pebble's right, −X = left, +Y = up, −Z = forward.

rx, ry, rz are local rotations in degrees; ox, oy, oz are local translation offsets in studs.

Root lift, side, forward movement, pitch, roll and yaw are presentation channels. Do not double-apply authoritative locomotion.

Unlisted channels stay at rest. Eases are smooth unless explicitly marked in or out.

A positive pitch about X raises the front for this forward-facing rig; negative pitch dips the nose.

L/R leg roll and splay signs are mirrored. Leg angles below are starting targets: contact constraints have priority over angle fidelity.

The brief gives bone origins, not final visible toe-tip, horn-tip or mandible-tip vertices. All landmark coordinates below are initial calibration targets, not claims about the imported mesh. Measure the actual skinned tips once in Studio and keep those offsets as the contact solver's source of truth.

Gameplay invariants

Mechanic

	

Must remain




Base

	

1 matter, 100 HP, 22 studs/s




CHIP

	

Passive attack, ground-based, material-dependent rock chip / goo bite




CRACKED

	

6+ Pebbles on one big enemy; ×1.75 against Titan, ×2 against Brute




CURL UP

	

Auto, Titans only, 12 s cooldown; 70% of the qualifying hit bounces off




ROLL OUT

	

ORDER, 24 s cooldown, 0.55 s warning




ROLL OUT bonuses

	

+60% movement speed, 30% damage cut for 2.5 s; +20 on the first qualifying big-target jab




HURT

	

Additive, approximately 0.50 s; 0.35 weight during committed moves




DEFEAT

	

Terminal, approximately 3.20 s; exactly ONE amber matter mote




Particles

	

34 emissions/s per client, shared with other creatures




Lights / camera shake

	

0 / 0

The brief does not specify CHIP's numerical damage or authoritative hit interval. The proposed 0.96-second animation cycle below is a visual baseline. It must not establish its own damage rate or create two gameplay hits just because the sheet shows both horn and mandible contacts.

2. Timing contract

Move

	

Warning / anticipation

	

Hit or decisive event

	

Body free / hand-off

	

Effects end




CHIP

	

0.00–0.28

	

Horn at 0.40; bite at 0.65, material-dependent

	

0.78; repeat at 0.96

	

Each contact +0.25




CRACKED

	

Server-confirmed 5→6 transition

	

Overlay active immediately

	

While threshold holds

	

0.30 after removal




CURL UP

	

0.00–0.23

	

Server-resolved Titan hit, tHit

	

tHit + 0.56 nominal

	

tHit + 0.35




ROLL OUT

	

0.00–0.55

	

First qualifying contact at tC

	

tC + 0.42, or expiry recovery

	

Impact +0.42; trail +0.45




HURT

	

—

	

0.00 impact

	

0.50

	

0.45




DEFEAT

	

—

	

Shell fracture 1.20; rubble 1.95; mote 2.25

	

Never returns to idle

	

3.20

For CURL UP and ROLL OUT, tHit and tC are runtime event times, not guaranteed fixed timestamps. Their impact, recovery and FX phases must follow the actual server event.

3. Shared ground and attack contact system

This is the most important technical foundation for CHIP and the ROLL OUT jab.

Pebbles attack big enemies from the ground. Do not attach them to back or side stick points like Drips. Use those authored points to find the target surface, normal and available attack sectors, then solve the Pebble's standing position.

3A. Model-space landmarks

Provisional coordinates, in studs:

Landmark

	

Coordinate




Horn tip

	

(0.00, 1.66, -2.03)




Mandible midpoint

	

(0.00, 0.76, -1.85)




Left mandible tip

	

(-0.25, 0.76, -1.85)




Right mandible tip

	

(+0.25, 0.76, -1.85)




Left front toe

	

(-1.38, 0.04, -1.08)




Right front toe

	

(+1.38, 0.04, -1.08)




Left middle toe

	

(-1.45, 0.04, +0.12)




Right middle toe

	

(+1.45, 0.04, +0.12)




Left rear toe

	

(-1.34, 0.04, +1.20)




Right rear toe

	

(+1.34, 0.04, +1.20)

These foot positions describe a supported stance, not the six exact bone origins. The final solver targets the visible sole tips.

During ordinary skittering, the procedural tripod remains:

Tripod A: L1 + R2 + L3.

Tripod B: R1 + L2 + R3.

During the committed attack brace, transition to all six planted legs over 0.10 seconds. If a toe cannot reach its target using the existing two-bone chain, constrain it to the reachable locus rather than extending the leg geometry.

3B. Aiming at a real enemy surface

Define:

P: target hit point on the actual visible enemy mesh.

N: outward surface normal, pointing from the enemy toward Pebble.

U: upward tangent of the surface.

R: horizontal tangent, perpendicular to N.

Face the Pebble so its −Z direction points approximately along −N.

At an ordinary ground-based contact, start with the root approximately 2.03 studs outward from the hit point along N, projected to the sampled ground. Correct the actual position with the measured horn tip, rather than assuming that this nominal distance is exact.

For the horn jab:

HornTip_world = P + 0.03N

For a bite, choose a lower surface point P_bite and solve:

MandibleMid_world = P_bite + 0.04N

The two jaw tips should straddle the bite point along the target tangent, without requiring them to physically close.

Reach policy:

Preferred horn impact height: 0.85–1.90 studs above Pebble's local ground.

Calibrate up to approximately 2.10 studs only if the rig can achieve it without losing grounded support.

Bite impact height: approximately 0.55–1.10 studs.

Do not aim at 3–4-stud-high flank or back points simply because those are available on the enemy mesh. A 2.4-stud Pebble cannot reach them while retaining its grounded attack silhouette.

If no accessible surface point exists, select another lower leg/flank region or keep approaching. Do not fake a midair hit.

Contact acceptance targets:

Check

	

Maximum




Horn tip to actual visible surface at impact

	

0.10 studs




Mandible midpoint to visible surface

	

0.12 studs




Weapon penetration

	

0.06 studs




Planted sole clearance

	

0.06 studs




Planted sole horizontal drift during brace

	

0.08 studs




Last-frame presentation-only root correction

	

0.18 studs preferred

If the standing position requires a larger root correction, fix the locomotion approach or target slot. Do not teleport the visual character into its contact point.

3C. Moving targets and sector claims

Resolve the chosen hit point from the enemy's target-local attachment frame each update. Revalidate its surface before each new contact when the enemy has moved substantially or its geometry has changed.

The existing ≥2.2-stud claim separation is a hard minimum. Because the Pebble itself is 3.4 studs wide, prefer 3.1–3.6 studs between ground attack centres where possible. Stagger radial distances and orientation when sectors are crowded.

A 24-Pebble swarm cannot all occupy the same small flank without overlapping. Keep extra Pebbles approaching or waiting for sectors; do not force 24 bodies through the target. The server must remain the authority for which units count toward CRACKED.

Contact correction order:

Resolve current authoritative root position.

Apply gait, attack pose and additive HURT.

Resolve parent and child bone transforms.

Correct visible planted toes.

Solve the horn or mouth endpoint toward the current enemy surface.

Check all foot and body penetrations; reject an unreachable contact.

Do not run an independent full raycast for every Pebble on every rendered frame. Reuse the authored target points and target-local frames; raycast when choosing or invalidating a contact.

4. J1 — CHIP (passive)

Reference: APPROACH SKITTER → BRACE → HORN JAB → MANDIBLE BITE → BACK OFF AND REPEAT.

The motion should be short, repetitive and determined. Pebble must feel as though it is chiselling away at something much larger, not delivering an oversized Brute-style punch.

4A. Keyframes — 0.96-second proposed cycle

Time

	

Root / Body

	

Head

	

Six legs




0.00 APPROACH

	

Normal skitter; Body oy 0.00, rx 0°

	

rx 0°, oz 0

	

Tripod gait active




0.12 BRACE START

	

Body oy -0.08, rx -5°

	

rx +8°

	

Fade gait to six contacts




0.22 BRACE

	

Body oy -0.15, rx -8°; slight forward lean

	

rx +14°, oz +0.06

	

All six toes planted; legs spread




0.32 DRAW BACK

	

Body oy -0.10, rx +4°

	

rx +20°, oz +0.10

	

Rear/middle feet resist forward motion




0.40 HORN JAB

	

Body oy -0.06, rx -7°, forward visual offset up to 0.10

	

rx -9°, oz -0.18

	

Front toes planted; impact correction




0.50 RECOIL

	

Body rx +3°

	

rx +12°, oz +0.04

	

All six grounded




0.59 BITE WIND

	

Body oy -0.10, rx -3°

	

rx +5°, oz +0.06

	

Front legs brace




0.65 MANDIBLE BITE

	

Body oy -0.13, rx -6°

	

rx -17°, oz -0.16

	

Jaw tips reach lower contact




0.78 BACK OFF

	

Body oy +0.03, root visual offset backward 0.12

	

rx +8°, oz 0

	

Release brace into gait




0.96 REPEAT

	

Body neutral

	

Head neutral

	

Normal skitter or next brace

Use in for the draw-back-to-strike transition, out for the 0.40 and 0.65 contacts, and smooth for recoil and return.

4B. Limb-specific brace

Initial angles, to be corrected by the foot-tip solver:

Bones

	

Brace pose




LegL1, LegR1

	

rx -11°, outward splay rz ±12°




ShinL1, ShinR1

	

rx +12°, tips remain planted




LegL2, LegR2

	

rx +3°, splay rz ±9°




ShinL2, ShinR2

	

rx +5°




LegL3, LegR3

	

rx +10°, splay rz ±13°




ShinL3, ShinR3

	

rx -8°

The L/R signs are mirrored according to the imported leg axes. Use the actual measured toe positions as the final constraints.

All six toes must be visibly planted from approximately 0.22–0.69, except for a tiny natural impact recoil. No moonwalking into the target.

4C. Rock versus goo contacts

The sheet contains both attacks, but the combat material determines which is the damaging visual contact.

Target surface

	

Primary visible damaging event

	

Secondary presentation




Rock / CRUNCH

	

Horn jab at 0.40; shards and amber sparks

	

Small mandible scrape at 0.65, no second large burst




Goo / SQUISH

	

Mandible bite at 0.65; cyan chunk stretches and tears

	

Short horn poke at 0.40, no rock shards

If the server explicitly authorises two hits within a cycle, both may receive their appropriate contact FX. Otherwise, only the authoritative hit gets the full effect. Do not double damage just to match the two sheet poses.

4D. J1 effects

Rock CHIP, time 0.40

Reuse 2–4 pooled Colossus rock fragments, sizes 0.10–0.28 studs.

Reuse short orange Neon spark streaks, 0.12–0.35 studs long, fanning away from the surface normal.

One small crack flash on the impacted rock seam.

Shards move roughly 0.6–1.5 studs away from contact and fall under cosmetic gravity.

Visible burst lifetime: 0.18–0.25 s.

Goo BITE, time 0.65

New cyan GooTear mesh at the mandible contact, approximately 0.70 wide × 0.50 high × 0.55 deep.

A small detached chunk, about 0.35 studs across, is part of the authored effect.

Two or three stretched strands, approximately 0.35–0.65 studs long, retract and break.

Strands shrink/fade from +0.10 to +0.24 s.

No permanent damage hole is required.

The target material selects the effect. An amber spark burst and a cyan goo splash must not fire together indiscriminately.

5. CRACKED — the six-Pebble threshold

Reference: J1 inset CRACKED and K panel 3.

This is a target-owned shared status read, not six individual glowing crack overlays.

At the server-confirmed transition from five to six qualifying Pebbles actively chipping the same enemy, display one amber fissure network on that enemy.

Appearance

Three to five branching crack ribbons spread over a visible flank, hip, shoulder or shell region.

Overall footprint: approximately 2.5–4.0 studs, adapted to target size.

Main fissure widths: 0.07–0.10 studs; smaller branches 0.035–0.06.

Bright amber core #FF9C20, small highlights #FFD35A.

Optional subdued dark underlay, roughly 0.03 studs wider on either side of the bright line.

Keep the original rock or goo material visible between the lines.

Use reusable Neon crack strips from the Colossus system, arranged in target-specific authored layouts. Surface geometry differs across Titan, Brute, Ram and Colossus, so a single planar decal cannot be assumed to fit every mesh. Author or select flat and curved anchor layouts as needed.

Timing

Relative time

	

Overlay




0.00

	

Server threshold reached; first crack line appears




0.12

	

Branch lines spread to about 70%




0.30

	

Full network visible; brightness peaks




0.45

	

Settles to sustained amber




While CRACKED

	

One understated 1.20 s brightness pulse




Status removed

	

Fade overlay in 0.30 s

Brightness pulse: about +30% compared with its sustained level. No dynamic light.

The damage multipliers stay ×1.75 versus Titan and ×2 versus Brute. The brief supplies no CRACKED damage multiplier for other large forms, so do not extrapolate one.

Store the overlay on the target, with the relevant attacking team/status ownership if your combat rules permit opposing swarms. A Pebble hit may briefly brighten an existing fissure near its contact point, but it must not create another full overlay.

CRACKED must remain clearly visible in the six-Pebble view and absent in the five-Pebble view, including on a moving, turning target.

6. J2 — CURL UP (automatic defence)

Reference: ALERT → TUCK IN → STONE BALL → HIT BOUNCES OFF → UNCURL → SHAKE OFF.

This is not an escape move. Pebble stays in place, absorbs the blow as a compact stone ball, then returns to combat.

6A. Mandatory stone-ball mesh

Author one PebbleStoneBall replacement:

Overall main body: 2.90 wide × 2.45 high × 2.95 deep studs.

Ground-space centre approximately (0, 1.23, 0) when stationary.

Low point approximately 0.03–0.05 studs above ground.

Rounded grey shell plates separated by the existing bright magma fissures.

Amber crystal cluster concentrated toward the top of the silhouette. Retain the distinctive crystal shapes rather than making a generic spiked mine.

The head, mandibles and six legs are fully tucked/hidden. No floating eye or visible toes.

Use the existing rock and emissive texture palette.

The stone-ball pivot must rotate around its centre, not the ground Root origin. A wheel rotating around the ground pivot will penetrate the floor.

Both CURL UP and ROLL OUT use this exact same mesh and materials.

6B. Keyframes

Let tHit be the actual server-resolved threatening Titan strike. A nominal example is tHit = 0.55, but the animation must adapt.

Time

	

Root / Body

	

Head

	

Legs / mesh




0.00 ALERT

	

Body oy -0.04, rx +3°

	

rx +12°

	

Legs spread slightly; cracks brighten




0.10 TUCK

	

Body oy -0.16, rx -9°

	

rx -22°, oz +0.12

	

All six Legs fold inward; Shin rx +25°




0.18 DEEP CURL

	

Body oy -0.22, rx -18°

	

rx -38°

	

Legs retract; replacement begins




0.23 STONE BALL

	

Rig hidden; ball fully visible

	

Hidden

	

Ball stationary at ground




0.23–tHit HOLD

	

Root remains fixed

	

—

	

Ball holds; no rolling




tHit BOUNCE

	

Ball tilts/rolls up to 6° away from impact direction

	

—

	

Deflection ring, sparks, dust




tHit + 0.12

	

Ball returns to grounded rest

	

—

	

Defensive hold ends only if server permits




tHit + 0.24 UNCURL

	

Begin ball-to-rig swap

	

Head raises

	

Front legs unfold first




tHit + 0.38

	

Body oy -0.10

	

rx +10°

	

All six legs reaching ground




tHit + 0.48 SHAKE

	

Body rz +7°, then -5°

	

ry -8°, then +6°

	

Front legs stamp lightly




tHit + 0.56 READY

	

Neutral

	

Neutral

	

Return to gait/attack

In the two replacement transitions, keep the double-mesh overlap brief: approximately 0.04–0.06 s. A longer full-character crossfade makes two translucent creatures visible.

6C. Gameplay timing and bounce read

The 12-second cooldown and qualification against Titan danger are server-owned.

The Pebble may begin curling on the Titan telegraph, but the defensive damage reduction must use the server's decision, not whether the local animation has reached frame 0.23.

If a valid hit arrives before the full visual curl, accelerate the replacement transition to complete within approximately 0.06 s of the confirmed defensive event. Don't delay server damage resolution to wait for a pretty pose.

When protected, the hit deals its existing 30% remaining damage, because 70% bounces off. Do not render an invulnerability shield or imply zero damage.

If the Titan attack misses or its hit window closes without a registered hit, skip the large bounce effect and uncurl after the server resolves the threat.

6D. BOUNCE-OFF effect

At tHit:

Use one new thin deflection arc/ring mesh, about 3.40 studs diameter, with broken orange-white highlights.

Orient the main arc to the incoming impact direction; a low ground dust ring may remain horizontal.

Scale the main arc from 0.45 to 1.00 in 0.10 s, then fade by +0.28.

Reuse 2–3 short spark streaks at the impact side of the ball.

Reuse one Colossus ground dust puff, about 1.8 studs across, disappearing by +0.35.

Ball recoil stays small: maximum 6° angular wobble or 0.08 studs lateral presentation displacement.

No camera shake, no lights and no new area-damage danger ring. This should look like a huge blow being rejected by a tiny, impossibly hard ball, not a shockwave attack.

Use the Titan's existing incoming-danger shape. Pebble's own brief crack-brightening is reaction feedback, not a second telegraph.

7. J3 — ROLL OUT (ordered attack)

Reference: CROUCH → CURL → ROLL FAST → BOUNCE & UNCURL → BIG HORN JAB → LAND & CONTINUE.

The defining read is a small blazing rock ball streaking along the ground, bouncing open at the enemy and delivering one much larger-than-normal horn jab.

7A. Timing and movement contract

Warning remains 0.55 seconds.

Effective roll movement speed: 22 × 1.60 = 35.2 studs/s.

The 30% damage cut lasts 2.5 seconds, measured by the server's status clock.

Cooldown: 24 seconds.

First qualifying jab against a Titan or Brute receives +20 damage, once per ordered attack, only if accepted by the server.

For the proposed visual timeline, the 2.5-second active window begins at the 0.55-second release, ending at 3.05. If the implementation's authoritative buff starts at a different time, move the presentation window to match it; do not create a second duration rule.

7B. Keyframes — pre-roll

Time

	

Root / Body

	

Head

	

Legs / mesh




0.00 CROUCH

	

Body oy -0.06, rx -4°

	

rx +9°

	

Skitter stops; warning starts




0.25 WIND

	

Body oy -0.14, rx -9°

	

rx -12°

	

Legs bend inward; all feet grounded




0.42 DEEP CURL

	

Body oy -0.22, rx -17°

	

rx -32°, oz +0.12

	

Leg rx +25°, Shin tucks




0.50 BALL TRANSITION

	

Original rig starts hiding

	

—

	

Ball fades in




0.55 RELEASE

	

Ball presentation fully active

	

—

	

Begin authoritative roll




0.68 ROLL FAST

	

Ball follows actual navigation path

	

—

	

Continuous spin and trail

Use in during the deep curl, then out for the release. The beginning must be visually distinct from CURL UP: the amber ground warning and forward acceleration communicate that this is an offensive order.

7C. Roll trajectory and spin

Use the existing server-selected nearest Titan/Brute and its movement/pathing authority.

The ball follows the ground path, with the visual centre at the sampled ground height plus its calibrated rolling radius.

Nominal effective rolling radius: approximately 1.28 studs. Given 35.2 studs/s, a physical no-slip spin is roughly:

𝜔
=
35.2
1.28
≈
27.5
 rad/s
ω=
1.28
35.2
	​

≈27.5 rad/s

That is approximately 1,576°/s, or 4.38 revolutions per second. Implement spin from actual distance travelled, not a fixed rotation keyed to time:

Δ
𝜃
=
Δ
𝑠
𝑟
Δθ=
r
Δs
	​


This automatically slows the visual spin when pathfinding slows the character and prevents a stationary ball from spinning furiously.

If the calibrated contact radius differs, use that measured value. Keep a motion-blurred-looking trail mesh behind the moving ball rather than inventing extra rotations to imply speed.

The 2.5-second active phase covers up to about 88 studs of travel at uninterrupted full speed. That is a theoretical movement distance, not a guaranteed reach or a new activation range. If navigation, spacing or obstacle constraints prevent contact, let the order end without an invented hit.

7D. Contact sequence at the enemy

Let tC be the predicted/confirmed contact time. This part is relative to tC, not locked to a universal timestamp.

Time

	

Pose / placement

	

Contact




tC − 0.18

	

Ball starts shallow upward bounce; roll slows/orients toward target

	

Leave ground, no hit




tC − 0.12

	

Ball lift about 0.45 studs; begin uncurl transition

	

No hit




tC − 0.07

	

Original Pebble rig appears; front legs extend backward, horn aimed forward

	

Align horn toward surface




tC − 0.02

	

Root/Body rx -12°; Head rx -18°, oz -0.16

	

Horn almost touching




tC BIG HORN JAB

	

Horn tip reaches actual target surface

	

Server-accepted jab; +20 once if applicable




tC + 0.12

	

Body recoils rx +6°; Head rx +12°

	

Shards and amber burst




tC + 0.25 LAND

	

Six toe tips settle onto sampled ground

	

Return to grounded stance




tC + 0.42 CONTINUE

	

Normal CHIP pose

	

Resume ordinary attack

The launch height is an initial visual target. Cap it or redirect it to preserve an achievable horn contact on the selected target. Avoid lifting the Pebble high into a flank and then snapping it downward to the ground.

The ball-to-rig swap must have its head/horn aligned with the target before the impact frame. Do not let the invisible ball trigger damage while the horn appears half a stud away.

At tC, use the same surface solver as CHIP, but permit the airborne root to have approximately 0.35–0.55 studs of lift before its subsequent landing.

If contact cannot be solved without visible teleportation, do not manufacture a successful horn pose. Continue/cancel according to the server's actual result.

7E. Warning and impact FX

Ground warning, 0.00–0.55

One low amber ring/disc under Pebble, approximately 2.4 studs diameter.

Reuse a thin Neon ring style with a dark underlay.

Start at 0.80 of authored scale, reach 1.00 by 0.40.

Two small brightness pulses at 0.40 and 0.52.

Remove as the ball begins rolling.

This is the ordered unit's preparation indicator, not an AOE marker under its target. Do not display a damaging ground circle on the Titan.

Rolling trail

Use one new authored ground-skimming dust ribbon mesh, roughly 2.80 long × 1.10 wide × 0.30 high:

Two or three irregular dusty lobes.

A few integrated dark stone flecks.

Thin amber streak sections embedded in the ribbon.

The luminous streaks run backward from the ball, not vertically upward.

Keep a short chain of 1–3 pooled segments at actual ground positions. Individual segments expand slightly over 0.08 s and fade by 0.35–0.45 s. Far-away Pebbles use a single attached streak with no segment history.

Big horn jab at tC

Reuse Colossus rock chunks, 4–6 visible pieces, sized 0.14–0.38 studs.

Add one new faceted amber impact-burst mesh, approximately 1.15 wide × 0.80 high × 0.40 deep.

Burst scale 0.25→1.00 over 0.09 s, fade by +0.28.

Affected local seam flashes bright amber.

One small dust puff fades by +0.42.

For a goo target, substitute the GooTear family of effects rather than producing stone rubble from liquid.

The special impact should read approximately 1.5–1.8× the visual width of an ordinary CHIP contact, not three or four times larger. Pebble is still F1.

7F. Order integrity

Target selection remains server-authoritative.

Warning, speed buff and damage reduction use one server-timestamped order instance.

The +20 first-jab bonus is consumed by one accepted qualifying hit, never by a cosmetic collision.

Do not reset that bonus when switching meshes, cancelling the roll pose or restarting a visual attack cycle.

If a target dies, disappears or changes eligibility, follow the combat server's cancellation/retargeting decision; do not hit a stale target-local point.

A stagger across multiple ordered Pebbles is acceptable for visual separation only when their server event timestamps receive the same stagger. Do not change the 0.55-second per-unit warning.

8. J4 — HURT (additive, 0.50 seconds)

Reference: HIT LANDS → KNOCKED SIDEWAYS → ROCKS BACK → SETTLES.

The hit comes from Pebble's left (−X), pushing the body toward its right (+X). Pebble should tilt onto its right-side legs, not fly off the ground.

Keyframes — left-side hit

Time

	

Root / Body

	

Head

	

Legs




0.00

	

Neutral / current pose

	

Current pose

	

Current contact




0.06 IMPACT

	

Root rz -13°; Body ox +0.10, rz -7°

	

rz +5° counter-tilt

	

Left legs unload, right legs brace




0.13 KNOCK

	

Root rz -20°; Body ox +0.16, oy -0.06

	

rz +9°

	

Three right toes planted; left soles rise up to 0.16




0.28 ROCK BACK

	

Root rz +8°; Body ox -0.04, rz +4°

	

rz -7°

	

Left toes return; right legs recover




0.39 SETTLE

	

Root rz -3°; Body ox 0

	

rz +2°

	

Six-leg support restored




0.50 READY

	

Neutral

	

Neutral

	

Return to gait/attack

Apply out into the initial strike, smooth through the recovery, and a slight overshoot at 0.28. Mirror the signs for a hit from the right.

HURT FX

At 0.03:

2–3 grey stone chips emerge from approximately (-1.25, 1.12, -0.20) on the struck left shell.

Chips range 0.10–0.22 studs.

One nearby magma seam flashes at approximately +60% brightness, then returns to normal by 0.18.

Tiny local dust, lasting 0.20–0.35 s.

No permanent missing shell geometry.

During committed moves, blend HURT at weight 0.35. Otherwise, weight 1.00.

While the stone-ball replacement is visible, do not render independently moving hidden legs or the normal HURT lean. Apply a bounded 4–6° ball wobble and brief crack flash instead. The existing CURL UP deflection takes precedence if it is the relevant Titan hit.

Re-run foot correction after additive blending. The HURT recoil may unload the left toes, but it must not drive the right toes below ground.

9. J4 — DEFEAT (terminal crumble)

Reference: STUNNED → LEGS GIVE WAY → SHELL CRACKS APART → RUBBLE → ONE MATTER MOTE.

This must look like the Pebble's internal heat dying, not like an explosion.

Keyframes

Time

	

Root / Body

	

Head / legs

	

Replacement geometry / FX




0.00 STUNNED

	

Root grounded; Body rz +5°

	

Head rx -8°

	

Magma glow begins uneven flicker




0.25

	

Body rz -7°, oy -0.08

	

Head droops; Legs twitch 5–8°

	

Crack brightness fluctuates




0.55 LEGS GIVE WAY

	

Body oy -0.27, rx -8°

	

Front and middle legs fold; rear legs lose support

	

Small dust at feet




0.90 SLUMP

	

Body oy -0.45, rx -15°

	

Head low; legs compressed

	

Magma fissures briefly brighten




1.20 SHELL FRACTURE

	

Original rig begins hiding

	

Head and legs stop

	

PebbleShellBreak appears along existing crack boundaries




1.48 BREAK APART

	

Rig fully hidden

	

—

	

Shell plates separate 0.10–0.40 studs; small chunks fall




1.75 COLLAPSE

	

—

	

—

	

Plates drop into rubble area, crystal cluster darkens




1.95 RUBBLE

	

—

	

—

	

PebbleRubble fully replaces break kit




2.15 GLOW DIES

	

—

	

—

	

Remaining fissures fade to a very low ember




2.25 MOTE

	

—

	

—

	

Exactly one amber matter mote rises




3.10

	

—

	

—

	

Rubble remains or cleans up under normal corpse lifetime rules; mote fading




3.20 END

	

—

	

—

	

Terminal presentation complete

Geometry and fracture

PebbleShellBreak should be a small kit of approximately 6 shell plates and 2 crystal pieces, derived from the existing shell shapes. Preserve the original large plate divisions and orange seam topology.

Do not scatter every tiny texture fragment as a physics object. Animate the separated pieces visually along short authored paths:

Initial separation: 0.10–0.18 studs.

Maximum outward travel: 0.40–0.55 studs for the largest pieces.

Individual downward drops: 0.25–0.75 studs before settling.

Rotation: 10–28° per piece, with variation.

The final PebbleRubble mesh should be roughly 2.7 wide × 0.45 high × 2.8 deep studs. Use low, irregular grey stone chunks and two or three visible dim amber crystal tips. No intact head, eye or six-legged silhouette should remain.

Crossfade/handoff the shell-break kit to the rubble pile between approximately 1.75 and 1.95 s. Do not display the whole original beetle and a complete rubble pile simultaneously.

Exactly ONE matter mote

At 2.25 seconds, spawn one amber faceted diamond/lump:

Main mote: approximately 0.22 wide × 0.34 tall × 0.18 deep studs.

Bright amber centre, warm orange edge.

One faint attached curved trail, approximately 0.65 studs long.

Rise approximately 1.55 studs over 0.85 seconds.

Lateral drift no more than 0.12 studs.

Begin fading around 3.05; fully gone by 3.20.

No extra little sparks that resemble additional matter. No orbiting beads. No second gem hidden inside the trail. The reference explicitly calls for one and only one rising piece.

DEFEAT must cancel CHIP, CURL UP, ROLL OUT, pending contact effects and any temporary target ownership. Give the mote spawn a once-only guard keyed to the defeated unit's death instance. Repeated death events must not spawn duplicates.

The mote is a visual representation unless the server separately defines a collectible matter object. Client FX must never grant gameplay matter.

10. K — FX mesh specification

The six K reference panels are the effect-shape authority. The large effects should be real authored meshes, not approximated by particle clouds.

Reuse versus new assets

K effect

	

Mesh decision

	

Authored size

	

Lifetime / behaviour




1 CHIP SPARKS

	

Reuse pooled Colossus rock fragments + short Neon spark strips

	

Chips 0.10–0.28; sparks 0.12–0.35

	

0.18–0.25 s




2 GOO BITE

	

NEW GooTear

	

0.70 × 0.50 × 0.55; strands to 0.65

	

0.24 s




3 CRACKED

	

Reuse crack-strip system, target-specific arranged layouts

	

2.5–4.0 overall footprint

	

Persistent while status active




4 ROLL TRAIL

	

NEW PebbleRollRibbon, plus reused dust/chips

	

2.80 × 0.30 × 1.10

	

0.35–0.45 s per segment




5 BOUNCE-OFF

	

NEW PebbleDeflectRing, reuse spark strips and dust puff

	

3.40 diameter; line about 0.07–0.10 thick

	

0.28–0.35 s




6 MATTER MOTE

	

NEW AmberMote, one trail ribbon

	

0.22 × 0.34 × 0.18

	

0.95 s




J3 BIG JAB

	

NEW PebbleAmberBurst, reuse rock fragments

	

1.15 × 0.80 × 0.40

	

0.28–0.42 s




J2/J3 STONE BALL

	

NEW PebbleStoneBall

	

2.90 × 2.45 × 2.95

	

Ability duration




J4 BREAK

	

NEW PebbleShellBreak

	

Approximately original collapsed shell footprint

	

0.75 s




J4 RUBBLE

	

NEW PebbleRubble

	

2.7 × 0.45 × 2.8

	

Terminal/corpse lifetime

The five first entries after the reused effects should be lightweight, low-poly, bake-once meshes. There is no need for a unique mesh per shard or per spark direction.

Animation curves and ownership

FX

	

Scale / visibility curve

	

Ownership




CHIP burst

	

Scale 0.30→1.00 in 0.05; fade by +0.25

	

World-space contact point




GooTear

	

Stretch 0.50→1.00 by +0.08; strands retract/break by +0.24

	

Initially target-local; detached chunk becomes cosmetic




CRACKED

	

0.85→1.00 scale / spreading layout over 0.30; settle at 0.45

	

Target-owned




Roll trail

	

Segment begins 0.55 scale, expands to 1.00 by +0.08, fades by +0.45

	

Ground/world-space segments




Bounce ring

	

0.45→1.00 scale by +0.10; fade by +0.28

	

Impact frame, oriented to incoming blow




Amber burst

	

0.25→1.00 scale by +0.09; fade by +0.28

	

Target-local contact for moving enemy




Matter mote

	

Fade in 0.10; rise 0.85; fade in last 0.15

	

Defeat rubble origin

Here alpha 0 means fully visible and alpha 1 means transparent. All temporary FX are non-colliding and pooled where practical.

CRACKED and the large jab impact must not float off an enemy that turns or moves. Target-surface effects resolve their current transform from the owning target-local point until they expire.

Materials

Rock: existing medium/dark grey stone, with distinct rocky planes.

Amber crystal: faceted warm orange/yellow, saturated but not white-hot.

Magma cracks: core #FF9C20, hot highlights #FFD35A.

Dust: subdued grey-brown with high transparency; do not use glowing dust.

Goo: glossy cyan-blue, consistent with the SQUISH reference, with thinner bright strands.

Warning underlay: subdued dark brown-grey, wider than its glowing line.

Do not make every rock fragment Neon. The appeal comes from the contrast between mostly dark stone and small, intensely bright cracks.

11. Sounds — phone-first specification

Pebble needs crisp, mid-frequency hard-material sounds. Unlike the Drip's wet, elastic calls, Pebble should produce tiny ceramic/stone ticks, grinding scrapes and a satisfying crunchy impact.

The values below are initial Roblox Sound.Volume targets, subject to the actual audio asset mastering.

Event

	

Sound character

	

Length

	

Starting volume




CHIP skitter

	

Light rapid stone-tap ticks, subtle

	

0.10–0.18 s

	

0.20




CHIP horn contact

	

Sharp ceramic crack + small gritty crunch

	

0.12–0.20 s

	

0.43




Goo bite

	

Short tacky tear with a hard mandible click

	

0.14–0.22 s

	

0.38




CRACKED threshold

	

One short layered crystalline stress crack

	

0.28–0.42 s

	

0.58




CURL warning

	

Low-mid gritty tightening rattle

	

0.18–0.28 s

	

0.40




CURL hit deflect

	

Hard hollow clonk plus a bright ricochet

	

0.22–0.35 s

	

0.72




ROLL warning

	

Rising gritty rolling rattle

	

0.35–0.55 s

	

0.50




ROLL movement

	

Looped rough stone rumble, light and compressed

	

Loop, 0.35–0.60 s seamless

	

0.35




BIG HORN JAB

	

Heavier brittle crack with short shard scatter

	

0.23–0.38 s

	

0.80




HURT

	

Startled small rock clack and chip scatter

	

0.14–0.22 s

	

0.45




DEFEAT crumble

	

Falling grit and several diminishing stone knocks

	

0.55–0.85 s

	

0.55




MATTER MOTE

	

One clear rising crystalline ping

	

0.35–0.55 s

	

0.42

Prioritise useful audio energy around roughly 500 Hz–3 kHz. Avoid low-bass rumbles that disappear on phone speakers.

For a swarm, aggregate CHIP sounds per target and allow at most three distinct CHIP impacts per second per client, prioritising nearest/clearest contacts. A local ROLL OUT or BIG JAB may receive higher priority. Do not play 24 independent rolling-rumble loops at full volume.

12. Performance budget — 24 simultaneous Pebbles

The 24-Pebble case is an explicit acceptance test. At a nominal 0.96-second visual CHIP cycle:

24
/
0.96
=
25
 cycles per second
24/0.96=25 cycles per second

That is already a high presentation rate, even before simultaneous ROLL OUT orders or DEFEAT transitions. Do not attach particle emitters to every contact.

Required budget policy

System

	

Limit / decision




Regular CHIP particles

	

0; use pooled authored rock chips and spark strips




CHIP impact meshes

	

Pool for up to 24 simultaneous visible bursts, with LOD suppression




CRACKED overlays

	

1 per qualifying target/status, not per Pebble




Roll trails

	

Near Pebbles: max 3 short segments; medium/far: 1 attached simplified trail




Full detailed roll trails

	

Prioritise nearest ~8 units per client




Curl bounce rings

	

At most one per confirmed defensive event; suppress small sparks on distant units




Tiny cosmetic debris particles

	

Draw from remaining shared 34/s budget, never reserve all 34 for Pebbles




Ambient lights

	

0




Camera shake

	

0




CHIP sounds

	

Max 3 per second per client for routine impacts




Defeat mote

	

Exactly 1 mesh per defeated Pebble, subject to normal visibility culling; never duplicate




Surface checks

	

At targeting/contact invalidation, not full per-frame raycasts for every unit

LOD

Near: Full horn/bite pose, complete CHIP burst, full dust/spark trail, all six limbs animated.

Medium: Preserve full creature pose and impact timing; simplify rock fragments, one roll trail mesh, reduced dust. Keep the CRACKED overlay.

Far: Preserve the large silhouette changes—beetle → stone ball → beetle—and the special big jab. Suppress individual tiny chips and most skid sparks. Maintain the shared CRACKED read.

Use projected screen size rather than only world distance. Pebble is small enough that a distant 0.12-stud rock chip can occupy less than a useful pixel on a phone.

The 34 emissions/s budget is shared with Colossus, Drip and the rest of the battle. If FX pressure rises, drop cosmetic Pebble dust and micro-sparks first, not the authored stone-ball silhouette, meaningful attack contact or CRACKED status.

13. Implementation integrity

These are hard requirements:

CHIP visual cycles do not authorise damage. Only combat-server events do.

The target material controls the main CHIP contact effect; don't spawn goo and rock bursts together without a legitimate reason.

Horn and mandible endpoints are solved against the enemy's real current surface, after parent transforms and additive blending.

Grounded Pebbles do not become fake clinging units; authored stick points are targeting references, not physical attachments.

The claim system remains authoritative. Do not place units through one another to satisfy a dramatic attack sheet.

CRACKED is target-owned, server-confirmed and applied only once per qualifying status instance.

CURL UP's 70% bounce is a server damage result, not a client-generated shield.

ROLL OUT's warning, cooldown, 2.5-second status and +20 first-jab consumption are server-owned.

A ROLL OUT ball follows the authoritative path. Its visual rotation must be driven by actual distance travelled.

Contact effects on moving enemies use target-local frames. Ground trails and settled rubble do not follow a moving target.

The same PebbleStoneBall mesh is used for defensive CURL and offensive ROLL.

DEFEAT cancels every active timeline and spawns one matter mote at most once.

Pooled meshes must never be reused while an active target or effect still owns them.

No lights, camera shake or particle substitutions for the main authored effect shapes.

14. Required MOVE TEST stills

Capture the following in Studio at the actual timestamps. Use consistent cameras and include one mobile-scale composite. Close-up hero renders alone are not sufficient.

Group

	

Stills

	

Must be checked




CHIP

	

0.22, 0.40, 0.65, 0.78

	

All six brace; exact horn contact; lower mouth contact; clean retreat




CHIP contact, side view

	

0.40 and 0.65, against two different big forms

	

No floating tip, no foot penetration




CRACKED

	

5 versus 6 qualifying Pebbles on same enemy

	

Shared overlay transition; no duplicated fissure networks




CURL UP

	

0.10, 0.23, tHit, tHit+0.38, tHit+0.48

	

Tuck, round ball, hit rejection, six-leg return, shake




ROLL OUT

	

0.42, 0.55, rolling phase, tC−0.07, tC, tC+0.25

	

Amber warning, ball, speed trail, mid-bounce uncurl, horn strike, landing




HURT

	

0.06, 0.13, 0.28, 0.50

	

Left strike, rightward lean, overshoot, settles




DEFEAT

	

0.55, 1.20, 1.75, 1.95, 2.65

	

Leg collapse, shell fracture, breakup, rubble, exactly one mote




SWARM

	

24 Pebbles in one encounter

	

Stable client frame time, no overlapping bodies, readable target, effect culling




MOBILE

	

CHIP, CURL, ROLL, CRACKED at typical gameplay zoom

	

Silhouette and status readability

Final acceptance criteria

CHIP: Both the horn and mandible motions are visually unmistakable at normal game distance. The contact points follow real moving enemy surfaces. No planted foot penetration greater than 0.06 studs; no visible sliding greater than 0.08 studs during the brace.

CRACKED: Five Pebbles do not show the shared CRACKED overlay; six qualifying Pebbles do. It stays correctly attached during target movement.

CURL UP: The ball silhouette is genuinely closed, with no floating legs or visible face. A protected Titan hit gives a readable deflection burst and the Pebble remains in its original defensive area.

ROLL OUT: The ball rolls toward the actual target at the correct authoritative speed. The horn is visible before the accepted contact, the special hit reads larger than CHIP and the character lands cleanly.

HURT: A left-side strike causes a rightward lean followed by a visible overshoot. Additive HURT does not break committed attacks or the stone-ball replacement.

DEFEAT: The shell breaks along its glowing fissures and becomes a low rubble pile. Exactly one amber matter mote rises.

Performance: 24 units remain readable without excessive particles, sound stacking or unbounded FX instances.

Recommended build order

Build and measure in this order:

Calibrate horn, mandible and six toe-tip landmarks.

CHIP ground attack and moving enemy contact.

CRACKED target overlay.

PebbleStoneBall and CURL UP.

ROLL OUT using the same ball and contact solver.

HURT additive.

DEFEAT break/rubble/mote sequence.

Full 24-Pebble swarm and mobile readability checks.

The critical dependency is ground-to-real-surface contact solving, followed closely by the stone-ball transition. Everything else can be iterated after those are stable.

In the first audit, bring back measured horn-tip contact error, mandible contact error, six-foot clearances, ball-to-ground clearance, ball spin rate versus actual travel, CRACKED five/six transition, and 24-Pebble frame/FX counts. Those will identify which proposed numbers need changing in Play.

One editorial correction: the reference range is properly styled J1–J4, with an en dash, rather than a hyphen. And, for the record, baking potatoes remains an unjustifiable culinary decision.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High