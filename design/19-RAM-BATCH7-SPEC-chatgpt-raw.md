Ram Animation Spec
ALIEN FUSION — RAM (CRUNCH F3) · ANIMATION BATCH 7

Build specification · 29 October 2026 · CrunchF3v5 · 4 matter · 560 HP · base speed 16 studs/s
Visual authority: Ram hero/model/movement sheets and J1 HORN GORE, J2 HOOF STAMP, J3 RAM CHARGE, J4 HURT/DEFEAT, K EFFECTS.
Build verdict: GO TO BUILD WITH TWO INTEGRATION GATES: (i) verify the actual horn/hook-tip sockets and gameplay Gore reach; (ii) verify charge travel and hit timing against the combat server. These are integration measurements, not reasons to redesign the poses.

The Ram must remain the same four-legged lava-cracked stone bull: massive shoulder hump, two forward-curled amber horns, crystal dorsal ridge, four blocky hooves, rock tail, glowing orange seams. It must read heavy, not elastic. Large FX shapes are Blender-authored meshes, imported and pooled; reused Colossus rock effects and small particles are secondary. No camera shake and zero effect lights.

0. Conventions and implementation constraints
All times are measured from the server-authoritative move start T0; tHit is always sourced from the server, not independently scheduled by the client.
Model-space basis: +X = Ram's right, +Y up, -Z forward. root.fwd positive moves toward -Z. Rotations are degrees; +rx = nose up, -rx = nose down; signed roll/yaw must follow the animator's existing rz/ry conventions. ox/oy/oz are offsets from rest.
Listed Chest, Hips, Head, Tail rotations are additive, not replacements for rest transforms. Children inherit ancestor transforms. The final evaluated contacts (not the raw angle values) are the acceptance criteria. Unless noted: key interpolation smooth = cubic smoothstep, in = ease-in cubic (acceleration), out = ease-out cubic (deceleration). Unlisted bone components are zero/return to locomotion.
For a hoof TARGET, coordinates below are expressed in the fixed T0/cast-ground model frame: origin and forward basis frozen at cast. Transform that target to world only once. DO NOT parent the target to the rotating Root, or the IK hoof will float. Foot-bone TARGET Y is ground height + 0.58 (the hoof sole is 0.58 below its Foot bone). Hoof sole contact: terrain +0.00 to +0.08; never below terrain -0.03. For uneven terrain, raycast independently for all four feet and sample ground positions for FX.
Rig: front leg reach 2.99 (1.59+1.40), hind leg reach 2.87 (1.65+1.22). Normal hoof-bone contacts: FL=(-1.85,0.58,-1.30), FR=(+1.85,0.58,-1.30), BL=(-1.85,0.58,+3.30), BR=(+1.85,0.58,+3.30). Actual level-ground targets supersede these approximations on slopes.
PLANTED: retain the existing world foothold; TARGET: 2-bone IK to the specified independent world-space path; GAIT: the normal trot/gallop IK takes control. For each mode transition, blend IK weight, not the foot's transform after IK. IK must use the correct knee pole to avoid backward knees. Never stretch the rock leg mesh. If a target needs more than 97% of geometric leg reach, move the torso/target instead; at >100%, reject that pose.
Evaluation order: server placement/root motion -> locomotion base -> attack Root/Chest/Hips/Head/Tail -> per-foot target/IK -> additive HURT -> contact/terrain correction -> FX attachments. Additive HURT must not run a second post-IK solve that tears the feet loose.
No separate mandible bone exists on this Ram. Contact sockets must be measured from the rendered horn mesh and, if desired, the stone muzzle. Do not invent horn-tip local coordinates from the Head pivot. Author HornTipL/R, HornHookL/R (inner leading curve), MuzzleFront, FrontSoleL/R, BackSoleL/R attachments at real mesh locations and log their evaluated world points after posing.
Suggested contact tolerance: horn-to-target surface <=0.25 studs at Gore/Charge hit (ideal <=0.12), front soles within 0.08 studs of sampled terrain at Stamp, left/right stamp landing times <=0.025 s apart. Effects spawn from evaluated contact sockets, never from the chest pivot.
Gameplay is authoritative: Gore 55, x1.5 vs Packs, 1.25 s; Stamp 30 +0.50 s stun, max 2 eligible Packs/Brutes (Packs first), cd 9, warning 0.50; Charge 90 primary /135 vs Pack, 20 to up to two extra, cd 24, warning 0.85, up to 18 studs; never Titan target. The two secondary Charge targets are knocked aside. Swarms are dust-only for Stamp, not damaged or stunned.
1. Timing contract
Move	Warning / wind-up	Authoritative hit	Body free / next action	Visible FX end
A HORN GORE (passive)	0.00–0.37	0.55	1.05; next cycle 1.25	0.98
B HOOF STAMP (auto)	0.00–0.50 (ring)	0.68 (both hooves)	1.16	1.35; stun itself ends 1.18
C RAM CHARGE (order)	0.00–0.85 (lane)	0.85 + actual travel time to collision; <= approx. 1.66 at 18 studs under proposed speed	tBrake+0.36	tBrake+0.64
HURT (additive)	—	Immediate feedback	Never owns gameplay movement	0.52
DEFEAT	—	Terminal at T0	Never; corpse hidden after end	3.65 (optional corpse persistence is server-driven)

Charge travel calculation: proposed presentation velocity is 24 studs/s after a 0.12 s ramp, based on the established fast gallop feel, not a new gameplay speed. For distance d <= 18: from 0.85 to 0.97 ramp v(t)=24*smooth((t-0.85)/0.12); then v=24. This covers ~1.44 studs in the ramp; the remaining 16.56 takes 0.69 s, so full-distance stop begins near 1.66. If the server's charge velocity differs, use the actual server travel samples and derive tImpact from collision. A short charge can hit earlier. Define tBrake = tImpact when a collision occurs, or the actual end-of-travel time on a miss. All post-travel C recoil/skid keys use relative time τ = t - tBrake, not a permanently hard-coded 1.66; ChargeHit fires only for a real hit. tStop (body actually stationary) should be no later than tBrake+0.27. Any braking translation must be part of the server's total <=18-stud path, never added beyond the maximum after a full-distance hit.

Mandatory gameplay and placement gates
Gore physical reach: the brief describes enemies up to ~3 studs past the horns. A head rotation cannot bridge 3 studs. At cast measure gap g from the posed HornHook to the real target surface, along the forward plane. If server rules permit a short advancing Gore, move the server-authoritative Ram forward by L=clamp(g-0.35,0,2.65) over 0.34–0.55, coordinated with hoof steps, then settle at its new authoritative position. The hook arc supplies the last ~0.35 stud. If combat does not authorize that displacement, do not silently move the client Root 2.65 studs: keep the server's 3-stud hit contract, use the actual local contact where possible and an impact arc at the server-resolved surface when distant; record the visible gap as an unresolved visual mismatch. Prefer having combat own the motion, not lying about contact.
Charge corridor: d and impact point come from the server's swept collision, never a client- guessed 18-stud endpoint. Warn length follows the chosen path, maximum 18. Verify lane WIDTH against the server's real charge-hit corridor before release: proposed telegraph 6.4 wide because the rendered Ram is 5.9 wide, not a claim that the server's damage hitbox is exactly 6.4.
2. Attack A — HORN GORE (J1 / K1)

Read: steady head-up -> rock shoulders pull back/down -> short forwards/upwards horn hook -> sharply localized orange crystal-and-rock impact -> recoil into quadruped stance. The enemy is a placeholder only in the pose sheet; never spawn a gray blob in game.

A.1 Bone keys (all angles in degrees)
t	Root pitch / lift / fwd fraction L	Hips rx	Chest rx / oy	Head rx / ry	Tail rx
0.00	0 / 0 / 0	0	0 / 0	+3 / 0	0
0.16	-2 / -0.02 / 0	-3	-6 / -0.08	-10 / 0	+5
0.37	-4 / -0.06 / 0.05	-5	-10 / -0.12	-18 / 0	+8
0.48	+1 / +0.01 / 0.55	+2	+5 / +0.07	+8 / 0	-4
0.55 HIT	+3 / +0.04 / 1.00	+4	+11 / +0.10	+20 / ±5 toward chosen horn	-9
0.70	+1 / +0.02 / 1.00	+2	+6 / +0.06	+10 / ±2	-4
0.92	-1 / 0 / 1.00	-1	-2 / 0	-3 / 0	+3
1.05	0 / 0 / 1.00	0	0 / 0	0 / 0	0
1.25	normal gait	0	0	0	normal

L means the distance selected from the reach gate, not a fixed 2.65-stud translation: e.g. for L=0.8, 0.55 fraction is 0.44 studs. Root.fwd is relative to the starting authoritative placement. The first 0.37 s holds the wind-up; accelerate in during 0.37–0.55, recoil out 0.55–0.70, return smooth to 1.05. If the server moves the Ram, do not undo L at 1.05; let the locomotion controller inherit the advanced position.

Gore stepping/IK: 0.00–0.37 all four PLANTED. 0.37–0.55, for L>0.35 blend all legs to locomotion/short stepping over 0.07, or explicitly retarget the front pair Δz=-0.55L and rear pair Δz=-0.35L, one step with toe lift 0.18; do not pretend the hooves remain planted while the full root travels. 0.55–0.75 replant at the newly sampled footholds over 0.08; 0.75–1.05 planted recovery -> gait. For L<=0.35, keep rear hooves planted and make a very small front pivot-step. Do not root-teleport at hit.

Required contact: at 0.55, select the HornHookL/R with the smallest world-space distance to the target's facing surface, and solve the final Head aim within ±7° yaw / ±6° pitch plus the permitted L to keep selected hook <=0.25 from the target's actual visible surface. Place GoreBurst centroid 0.08 outside that surface along its normal, not midway between both horn tips. Opposite horn may graze; do not force both wide horns into a single narrow Pack. Suggested hit elevation 2.3–3.4 studs above Ram ground, clamped to the target model's visible surface. At t=0.37 both hook tips should visibly be behind their t=0.55 contact locations; at t=0.55 the head travels forwards then up, not straight down.

A.2 Events and sound
Time	Event	FX / audio
0.16	GoreStoneLoad	soft stone scrape/grind, 0.16–0.22 s, no bass-only boom
0.37	GoreSurge	short low-mid grunt and rushing grit, 0.16–0.23 s
0.55	GoreHit	server damage; one authored GoreBurst at selected horn hook; reused 3–4 pooled rock chips; sharp crystal crack + medium midrange stone impact, 0.20–0.32 s
0.55–0.73	GoreScatter	2–3 tiny orange sparks/stone flecks, short dust puff; sculpted burst grows and disappears
0.75	GoreRelease	scrape/off-contact tick (optional), <=0.13 s

No warning shape and no extra damage pulses. The sheet's burst is angular: wedge-shaped amber splinters and gray shards pointing along the horn impact normal, not a round explosion.

3. Attack B — HOOF STAMP (J2 / K2 & K3)

Read: notices nearby target -> both front hooves lift high as a coordinated rear -> shoulders reverse -> both front hooves hit together -> orange fractured circle + sculpted dust bank expands -> exactly up to two selected Pack/Brute enemies show small amber dizzy stars -> settle with a snort. Tiny Swarms get dust flecks only.

B.1 Mechanical solution: rotate about the hind-hoof pivot

The hind legs are only 2.87 studs long, and their rest distance from thigh to foot is already close to full extension. Do not implement the rear as root.lift=2 with a stationary upright root. Rotate the whole body nose-up around the T0 hind-foot-bone midpoint P=(0,0.58,+3.30), and let the hind hoof IK hold the original world contacts.

For a desired +pitch θ in radians, use the engine's rotation composition to calculate the world/model root translation T=P-Rx(θ)P (the table below assumes the usual +X rotation raises the forward -Z direction). In the root.fwd sign convention:

root.lift = 0.58*(1-cosθ) + 3.30*sinθ
root.fwd = -[3.30*(1-cosθ) - 0.58*sinθ]

This is pivot compensation, not an extra vertical hop. At +32°, the approximate displacement is root.lift=+1.84, root.fwd=-0.19 (i.e. 0.19 studs backward). This keeps both rear hoof-bone anchor locations fixed if the root has no separate translation; do not then apply the same correction again in the foot IK layer. Preserve hind hoof orientation against terrain as a separate ankle/foot correction. If the local rotation sign in this rig is reversed, invert the formula to match the measured +X nose-up convention; never blindly copy its sign.

B.2 Root/body keys
t	Root pitch / derived lift / fwd	Hips rx	Chest rx / oy	Head rx	Tail rx
0.00	0 / 0 / 0	0	0 / 0	0	0
0.12	+8 / +0.47 / +0.05	+2	+4 / +0.03	-4	-5
0.30	+24 / +1.39 / -0.05	+3	+7 / +0.10	-7	-11
0.44	+32 / +1.84 / -0.19	+4	+9 / +0.12	-8	-16
0.50 WARN END	+32 / +1.84 / -0.19	+4	+9 / +0.12	-8	-16
0.60	+16 / +0.93 / +0.03	-3	-5 / -0.06	+9	+7
0.68 STAMP	-2 / approx -0.10 / +0.08	-7	-9 / -0.16	+12	+12
0.82	-3 / -0.07 / +0.04	-5	-7 / -0.12	+9	+6
1.04	+1 / 0 / 0	+1	+2 / 0	-2	-3
1.16	0 / 0 / 0	0	0 / 0	0	0

The 0.68–0.82 values are explicit impact compression, not hind-pivot-derived offsets; they are corrected by planted IK. Ease out 0.00–0.44 (heavy rise), hold 0.44–0.50, ease in 0.50–0.68 (accelerating fall), out 0.68–0.82 (recoil), smooth to 1.16. Cap upper horn height via scene checks (no camera collision on phone).

B.3 Per-hoof TARGET tracks (essential; targets in fixed cast frame)

Mirrored signs: first target belongs to FL with negative X, FR has positive X. These are the Foot bone targets, therefore Y=0.58 at contact. All values are studs and linearly/smoothly interpolated between samples.

Time	FL target (X,Y,Z)	FR target	FL/FR IK target weight	BL/BR
0.00	(-1.85,0.58,-1.30)	(+1.85,0.58,-1.30)	1.00 PLANTED	keep original hoof footholds, PLANTED 1.00
0.12	(-1.80,1.85,-0.93)	(+1.80,1.85,-0.93)	0.75 TARGET after 0.08 blend	PLANTED 1.00
0.30	(-1.67,2.80,-0.10)	(+1.67,2.80,-0.10)	1.00 TARGET	PLANTED 1.00
0.44	(-1.57,3.55,+0.40)	(+1.57,3.55,+0.40)	1.00 TARGET	PLANTED 1.00
0.50	(-1.57,3.55,+0.40)	(+1.57,3.55,+0.40)	1.00 TARGET	PLANTED 1.00
0.60	(-1.72,2.25,-0.60)	(+1.72,2.25,-0.60)	1.00 TARGET	PLANTED 1.00
0.68	(-1.75,0.58,-1.75)	(+1.75,0.58,-1.75)	1.00 TARGET (both ground contact)	PLANTED 1.00
0.82	(-1.75,0.58,-1.75)	(+1.75,0.58,-1.75)	1.00 TARGET, 0.14-s contact hold	PLANTED 1.00
1.04	(-1.85,0.58,-1.30)	(+1.85,0.58,-1.30)	transition to footholds over 0.12	PLANTED 1.00
1.16	normal GAIT	normal GAIT	0 over 0.12 blend	GAIT

Reach check on the stated rig (before small Chest rotations): at 32° the front thigh root rotates to roughly (±1.75,5.40,+1.00); each high hoof target (±1.57,3.55,+0.40) is ~1.95 studs away, well within the 2.99-stud front chain. At impact, the forward sole target (±1.75,0.58,-1.75) should be reachable once Chest descends; verify measured reach <97% after all ancestor rotations. Hind IK targets never move in cast space during the rearing phase. If front hooves stretch on the descent, reduce target Z from -1.75 toward -1.55 rather than elongating stone limbs.

Do not key individual front-leg pitch to fake the lift: their LegFL/ShinFL/FootFL and right counterparts are IK-driven with knee poles pointing out/back. FK upper-leg guides only, optional: front Leg rx at 0.44 +28°, Shin rx -58°, Foot rx -12°, overridden by TARGET; at 0.68 guides -10° / +12° / +3°. Hind Leg/Shin/Foot rotations are solved by planted IK, with slight visual fetlock flex up to 8° at the peak.

B.4 Warning ring, hit select, effects
At t=0.00 spawn ground-centred radius 5.0 circle, centred on the Ram's cast-ground pivot (trigger within 5 is given; confirm the combat target selection radius instead of silently changing damage range). CRUNCH styling: dark basalt rim #28201B 0.28 stud wider than the amber line, dim ochre ground fill #5C361C with apparent opacity 0.25–0.35, amber emissive #FF9A21 edge width 0.30, underlay 0.05 below line. Should remain visible under daylight without glowing white. No screen lights.
t=0.00–0.34 circle circumference appears (not a growing damage radius); draw 6 radial short interior scorch tick marks, fade in the fill; t=0.34–0.46 ring intensity rises; t=0.46 and 0.49 small warning pulses; warning hides at 0.50. Keep danger shape distinguishable from post-hit Shockwave (different transparency/height and an explosive dust crown on hit).
At 0.68 server selects/affects up to two eligible Pack/Brute targets (Packs first): each takes 30 and gets the 0.50 s stun until 1.18. Display StunSwirl above each actually stunned enemy's head, not above more than two enemies. Small Swarms get only ambient peripheral dust; zero damage, zero stun.
The actual ground shockwave is an expanding circular ring, radius 0.9 at 0.68 -> radius 5.0 at 0.89, then edge falls apart into low dust, fading by 1.16. The shockwave is visual only after the single server hit at 0.68; do not damage each enemy again as the ring passes.
t	Event	Result
0.00	StampWarn	warning ring appears, small amber granular hum
0.24	StampRear	rough layered hoof-rock strain, 0.28–0.42 s
0.50	StampDrop	warning vanishes, fast gritty downward whoosh 0.15–0.19 s
0.68	StampHit	one shared hit timestamp, two hoof contacts, sculpted StampCrackDisc and StampDustBank, 4 pooled chunks, low-mid 'THAK-KRR' 0.30–0.46 s
0.68–0.89	StampWave	StampDustBank outward ring; 1–2 dust particles per quadrant
0.68–1.18	StampStun	1 pooled star/swirl asset per actual stunned target; tiny chime/tinkle 0.16–0.24 s
1.03	StampSnort	short gravel snort 0.20–0.28 s
4. Attack C — RAM CHARGE (J3 / K4)

Read: a long dark-rimmed, amber-edged rectangular warning LANE appears in front -> the Ram paws once and cocks its glowing horns down -> gallops the entire distance with a blazing crack pattern, ground-skimming speed streaks and thick sculpted dust trail -> horns-first violent impact -> target and up to two more are flung sideways -> Ram skids and re-plants all four hooves.

C.1 Timeline keyed to impact/end of travel (variable distance)
Time	Root & main keys	Foot mode / intent
0.00	Root pitch 0; Chest rx 0; Head rx +3; Tail rx 0	four hoof PLANTED
0.20	Root -2°; Chest -4°; Head -7°; Tail +7°	near front hoof paws +0.22 Y, -0.35 Z; the other three PLANTED
0.46	Root -4°; Chest -9° / oy -0.08; Head -19°; Hips +3°; Tail +10°	paw hoof plants; all four brace
0.85 CHARGE RELEASE	Root -5°; Chest -10°; Head -18°; Hips +4°; Tail +15°	blend to GAIT/gallop over 0.08; no stationary hoof locks during travel
0.85..tBrake	Root/Chest/head low as above; run cycle with vertical body bob 0.17 max and alternating gallop hooves	actual whole-unit placement sampled from server; maintain legs visibly cycling
tBrake	Root +2°; Chest +7°; Head +12° (impact recoil, relative to charge pose); Tail -12°	front pair begin planting/contact bracing (IK only once root stops translating)
τ=+0.12	Root -8°; Chest -10° / oy -0.10; Head +7°; Hips -5°	front soles TARGET at new halt locations, rear pair step/GAIT
τ=+0.27	Root -4°; Chest -5°; Head +3°; Hips -2°	skid finishes, all four PLANTED at new footholds
τ=+0.36	Root 0; Chest 0; Head 0; Hips 0	normal GAIT free; do not jump back to cast position

The tBrake poses are relative modifications from the charged pose, not absolute sums that apply the down-facing head twice. Blend head from -18° to approximately -6° at impact, then to +1° at 0.12 recoil, back to zero at +0.36. One paw, not frenetic hoof tapping. Root yaw follows the target bearing locked at cast; no steering toward a moving unit after the warning unless the combat server explicitly supports turning.

Paw target (opposite foot has PLANTED weight 1): choose FL for default, switch mirrored to FR when target bearing is right. In frozen cast frame: t0.00 (-1.85,0.58,-1.30) weight 0 / PLANTED; t0.20 (-1.85,0.80,-1.65) weight 1 TARGET; t0.38 (-1.85,0.58,-1.66) weight 1 TARGET, kick up 3 dust flecks; t0.52 transition back to PLANTED 0.10 s; t0.85 GAIT. Body pitch is low enough to keep the hooves on terrain during the hold.

Charge hit contact: take measured HornHookL/R sockets; test collision in world against server-approved primary target. At a real hit, the selected hook approaches the target visible surface within 0.25 studs after client pose/contact correction; no horn should pass through the torso >0.15. Aim/head correction max ±6° pitch, ±5° yaw. Spawn the sculpted angular impact burst at the horn/target point; do NOT put a big burst on the Ram's rear or along its dorsal crystals. Impact must be horns-first, not shoulder-first.

Knockback: draw the main victim and up to two secondary victims moving out from the lane (suggested 20–35° lateral off its normal, with brief hop for the visual), but server owns vectors, knockback and targets. Never show three extra hit victims or fabricate a knockback when combat says none. 90 primary damage, 135 versus Pack; two others 20 each. Do not retarget a Titan.

C.2 Warning LANE geometry
Parameter	Spec
Origin	cast-time Ram ground pivot, pointing along frozen charge direction
Length	actual server planned travel d, 0–18 studs; truncate if earlier collision/obstacle is planned
Display width	6.4 studs proposed (Ram model width 5.9); adjust to verified server hit corridor before ship
Rim	dark basalt #28201B, 0.30 stud outer border
Amber outline	#FF9A21 0.30 stud width, over a slightly broader dark underlay
Fill	dark rust/ochre #4B2819, low-opacity, repeated 4–5 chevron arrows across length
Height	conform to sampled floor, outline 0.04 above its underlay, no vertical wall
Lifetime	0.00–0.85, immediately withdrawn beneath charging hoof at 0.85

Use a single authored 2-stud lane tile mesh, repeated along length with appropriately trimmed final tile; emboss chevrons and both rim edges in its baked appearance. Ground-follow sample <=2 studs along the corridor and adjust tile poses to terrain; do not use one floating 18-stud flat plane on uneven ground. Warning fill sweeps outward 0.00–0.60; 0.60–0.76 hold; at 0.77/0.82 two rising amber outline pulses; at 0.85 hide. No camera shake or post-warning danger re-hit.

C.3 Charge run and events
Time	Event	Effect / sound
0.00	ChargeWarn	2-stud modular lane tile array; low scraped gravel 0.30–0.50 s
0.20 / 0.38	ChargePaw, ChargePlant	3 tiny ground flecks, 0.14-s hoof scrape
0.66–0.85	ChargeReady	horns/cracks warm orange; brief grated inhale 0.24 s
0.85	ChargeStart	whole body begins authoritative travel; one sculpted dust ribbon and two speed streak meshes follow, horn seams hotter; pitched-forward, mid-range rushing rasp
every 0.15–0.19 s during gallop	ChargeHoofBeat	alternating lightly layered rock footfalls, 0.09–0.15 s (rate-limited)
tImpact (on actual hit only)	ChargeHit	server applies primary and up to 2 secondary hits, authored GoreBurst scaled 1.35, 4–5 reused rock chunks, sharp impact 'CRACK/THUD' 0.30–0.43 s
τ=0.00–0.23	ChargeKnockback	hit-confirmed knockback/side dust on up to 3 actual victims only
τ=0.02–0.31	ChargeSkid	continuous sideways stone-dust scrape from hooves; actual root travel decelerates, ends at server destination, no backward teleport; scrape 0.30 s
τ=0.36–0.64	ChargeEnd	dust thins, hot overlay fades and gait resumes

If no eligible target is encountered, miss charge: there is still the lane, rush, skid and dust, but no enemy hit sparks/damage or fake knocked enemy.

5. HURT (J4 top, additive 0.52 s)

Left-side reference: visual hit on the Ram's left shoulder (negative X), rocks/chips spark, torso leans onto the right legs (+X), head jerks sideways, overshoots past centre, settles with a short gravel snort. Mirror the signs for a right-side hit. Should look like rigid linked boulders shock-shifting, not rubber bending.

t	Root side / roll	Chest rz / ox	Hips rz / ox	Head ry / rz	Tail rz
0.00	0 / 0	0 / 0	0 / 0	0 / 0	0
0.09	+0.12 / +4° right	+7° / +0.10	+3° / +0.06	+11° / +7°	-5°
0.18 PEAK	+0.24 / +7° right	+11° / +0.17	+5° / +0.10	+16° / +10°	-9°
0.31	-0.07 / -2.5°	-4° / -0.05	-2° / -0.03	-5° / -4°	+4°
0.43	+0.02 / +1°	+2° / +0.02	+1° / 0	+2° / +1°	-2°
0.52	0 / 0	0 / 0	0 / 0	0 / 0	0

right is the intended visual direction, not an assumption about your animator's rz rotation sign: verify +X motion in Play and flip signs if rig composition requires it. Ease out to 0.18, in-out past centre to 0.31, smooth to zero. The left-shoulder strike event at 0.00: reused 2–3 chunky chip meshes + 2 spark particles + a 0.12–0.18 s bright fissure pulse; sound stone fracture 0.18–0.26 s. Snort at 0.40, 0.15–0.25 s. Additive weight 0.35 inside committed attacks, 1.0 otherwise; stamp's planted legs must not slide, and do not blend HURT into the terminal DEFEAT.

IK: preserve all currently PLANTED hooves; permit chest/hump rocking and foot ankle roll while shifting visible weight right. If foot contact would break by >0.08, reduce lateral Root to +0.14 while retaining Chest and Head reaction. Right legs bear weight; left shoulder does not move closer to the attacker.

6. DEFEAT (J4 bottom, terminal 3.65 s; exactly FOUR matter motes)

Four clear beats: wounded stagger/head low and cracks flicker -> front knees buckle -> massive body falls onto one side, splitting along existing orange cracks while horns snap off -> rock mound with both identifiable detached horns -> exactly 4 amber matter seeds rise with faint trails, no fifth orb or ornamental amber spark mistaken for matter.

6.1 Key poses
t	Root lift / pitch / roll	Chest rx / rz / oy	Hips rx / rz / oy	Head rx / ry / rz	Tail rx	State
0.00	0 / 0 / 0	0 / 0 / 0	0 / 0 / 0	-8 / 0 / 0	0	stun, dim flicker
0.35	-0.10 / -5 / +2	-11 / +3 / -0.10	-4 / +1 / -0.03	-17 / +2 / +3	-9	head droops
0.85	-0.40 / -12 / +5	-18 / +7 / -0.25	-8 / +3 / -0.10	-22 / +5 / +6	-15	front knees buckle
1.30	-0.63 / -16 / +20	-23 / +13 / -0.34	-12 / +9 / -0.20	-18 / +9 / +15	-18	rolls into side
1.75	-0.67 / -12 / +54	-15 / +16 / -0.34	-14 / +18 / -0.20	-14 / +12 / +22	-22	side hits ground; fractured shell replacement starts
2.12	skeleton fades / static	fracture	fracture	horns detach	settle	replace with sculpted mid-fall rubble
2.48	hidden	hidden	hidden	hidden	hidden	full long rubble pile, both horns visible
2.72	hidden	hidden	hidden	hidden	hidden	glow fades, four motes begin
3.65	hidden	hidden	hidden	hidden	hidden	motes exit upward and trails fade

These are FK intent keys, not proof of collision-free placement. With an 11.6-stud stone animal, a naive -0.67 Root lift / 54° Root roll can push the shoulder hump through ground. For 1.15–2.12, use your supported whole-unit placement correction and ground queries to preserve grounded contact on the rolling flank: no mesh penetration deeper than 0.08 studs where visible. Adjust Root translations (not final resting roll silhouette) after playback and terrain query. The animal must look broadside and long before becoming rubble, not curl into a ball.

Leg intent: 0–0.35 four PLANTED; 0.35–0.85 front TARGET hoof-bone centres FL=(-1.75,0.58,-1.05), FR=(+1.75,0.58,-1.05) with knees visibly crouching (Chest oy down -0.25); hind PLANTED. 0.85–1.30 release left-side pair into collapsing pose, right-side pair briefly supports. From 1.30 onward IK weight -> 0 over 0.14 s as the whole body rolls; no hidden foot-stretch to maintain all four footholds through 54° rotation.

Fracture logic: At 1.50 light existing crack veins in 3 irregular branching bursts (no new random lines). At 1.75 swap intact shell sections to a custom long segmented collapse mesh with 7–10 big distinct boulders and two horn detach sockets; do not break the entire silhouette into hundreds of triangles. At 1.78–2.15 separate exactly two real amber horn pieces (reuse actual horn geometry or pre-baked detached versions) and rotate each 40–85° into rubble; by 2.48 both have landed as recognizable curves, left and right separated ~2.6 studs across pile. 2.12–2.48 replace transitional mass with RamRubblePile (approx. 8.8 W × 1.5 H × 6.3 D; orient its long dimension approximately along Ram's fallen torso axis). Glow 0.60 at 2.12 -> 0.15 at 2.48 -> 0 at 3.00.

Four motes: from t=2.72, spawn exactly 4 mesh motes, shape irregular faceted luminous amber crystals (not extra stars), 0.30 × 0.40 × 0.28 studs. Spawn above rubble at approximate positions (X,Y,Z) [(-1.1,1.5,-0.6), (+0.9,1.7,-0.2), (-0.45,1.3,+0.7), (+1.2,1.4,+0.9)] in corpse-local coordinates. Move each +Y by 2.7 / 3.0 / 3.25 / 2.85 studs between 2.72–3.52 using ease-out, with horizontal drift at most 0.45 stud and stagger 0.04 s. Each mote owns one very thin 0.05–0.09-wide tapering amber trail lasting until 3.65. No independent spark particles in the final mote frame, no secondary orange rocks hovering, four motes total. These motes represent the Ram's four matter; no gameplay matter count change originates in client FX.

Defeat audio: 0.00 low gritty moan 0.30 s, 0.84 heavy knee-rock scrape 0.26 s, 1.65 multilayer crack 0.40–0.55 s, 2.13 tumbling rubble 0.40 s, 2.72 four-note airy amber shimmer 0.50–0.70 s (one swell, not four noisy pings). Keep strong content in 300 Hz–4 kHz for phone playback.

7. Sculpted Blender FX mesh library (K)

Sizing convention: W × H × D is X × Y × Z at full intended Ram scale, studs, proposed targets for the Blender build—not measurements extracted from images. MeshParts are anchored, noncolliding, pooled; detail comes from modeled silhouette and the baked surface, not transparent sphere/torus stacks. Basalt gray + hot crack amber/orange; crystal surfaces golden amber. Use emission masks/pulses, but do not add light instances. Ground FX should work on gray stone, sand and darker ground.

Asset ID	Source	Full-size bounds	Make / usage
NEW RamGoreBurst	K1	3.2 × 2.2 × 1.3	Sculpt 7 long tapered crystal blades + 5 shorter gray rock splinters from one oblique contact centre; 0.05–0.16-thick blade fins; open fan, asymmetrical. Reorient to impact surface normal. Reuse ×1.35 for Charge impact.
NEW RamStampCrackDisc	K2 top	10.0 × 0.07 × 10.0	Broken irregular two-hoof central crack with 9 branching veins radiating outward, 4–5 small outer splits; dark gaps backed by bright orange emissive surfaces. Visually top-down disc; do not use an unbroken perfect circle. Split into 4 conforming quadrant mesh pieces on uneven terrain.
NEW RamStampDustBank	K2 side	10.0 × 0.80 × 10.0	One low, uneven annular dust wall with 8 directional rising lips, thicker on impact side, lower on far side, center open. Author as 4 quarter-ring segments for terrain alignment. No piled spheres.
NEW RamStunSwirl	K3	1.65 × 0.32 × 1.65	Crooked amber 1.3-turn corkscrew oval and 4 five-pointed star tips mounted together, thickness 0.07–0.11; empty centre shows enemy head. Only actual stunned units get it.
NEW RamChargeDustRibbon	K4 top	4.8 × 1.25 × 7.0	Tapered torn trail with 5 connected swept-up dust fins, low at hooves, rearward curl; orientation follows velocity, mesh stretches over ground.
NEW RamChargeSpeedStreaks	K4 top	4.5 × 1.0 × 5.8	5 elongated tapered arcs, not beams: 3 warm orange narrow streaks + 2 warm gray streaks; thin 0.04–0.10 wide. Attached to moving Ram but trailing backward.
NEW RamLaneTile	K4 lower	6.4 × 0.06 × 2.0	2-stud repeating low tile with dark charcoal rim, narrow amber line, dark rust centre and irregular embossed directional chevrons. Pool at most 9 tiles + 1 trimmed cap; terrain-ground them.
NEW RamRubbleTransition	J4 defeat 3	7.5 × 2.8 × 5.5	7–10 angular stone masses, emerging large holes aligned to orange crack paths; coarse collapsed shoulder ridge; use during 1.75–2.48.
NEW RamRubblePile	K5	8.8 × 1.5 × 6.3	Long low pile of 12–16 irregular rock blocks, largest remnants near former hump, taper to tail, two prominent detached crystal horns positioned separately. Horns should be individually detachable, not fused forever to mound.
REUSE / CLONE ACTUAL RamHornDetachedL/R	K5 close-up	~2.1 × 2.4 × 1.1 each (measure actual rig)	Pre-bake the same identifiable curled horn geometry; one left + one right, cracked bases. Don't redesign generic crescents.
NEW RamMatterMote	K6	0.30 × 0.40 × 0.28	One angular teardrop faceted amber matter gem, instantiated exactly four times. Soft glow mask and one narrow trail per mote.
REUSE RockFragment	Colossus	0.18–0.55 longest axis	Irregular pooled gray chunks and tiny dark stone chips; capped by shared client loose-fragment pool.
REUSE CrackNeonStrip / MagmaPulse	Colossus	0.05–0.12 thick	Actual rock fissures/temporary localized glow on Ram rig and ground. Conform to existing mesh UV/cracks, no random new cracks across intact plates.
REUSE DustPuff	Colossus	0.20–0.45 nominal	Micro-dust only; NOT a substitute for the sculpted shockwave ring or charging dust ribbon.

RamHornDetached dimensions are placeholders until measured on the Blender source. Likewise actual K visual geometry guides the silhouette, but the sizes above are implementation targets.

7.1 Major FX curves (time from each effect spawn; scale X/Y/Z, visible opacity where 1 is fully visible)
Effect	Mesh scale + opacity curve
GoreBurst	a=0.00: (0.40,0.35,0.40), opacity .90; 0.055:(1.0,1.0,1.0),1; 0.16:(1.12,0.75,1.05),.60; 0.31:(1.15,0.20,1.1),0
StampCrackDisc	0.00:(0.18,1,0.18), .95; 0.08:(0.68,1,0.68),1; 0.21:(1,1,1),.95; 0.44:(1,1,1),.35; 0.65:opacity0
StampDustBank	0.00:(0.18,0.30,0.18),.55; 0.12:(0.75,1.0,0.75),.90; 0.21:(1,1,1),.85; 0.35:(1.12,0.55,1.12),.35; 0.48:opacity0
StunSwirl	0.00:opacity 0; 0.08:opacity1; gently rotate ±100° total over first 0.30 s at head+0.7–1.0; 0.42:.8; 0.50:opacity0; use same server 0.50-s duration
ChargeDustRibbon	from ChargeStart: 0.00:zScale .25, opacity 0; 0.12:zScale1, opacity .90; sustain with 0.94–1.06 silhouette wobble; at skid τ=.00:1; .27:0.30; .55:0
ChargeSpeedStreaks	start 0.00:.3,0; 0.12:1.0,.85; repeat mild length pulse 0.85–1.15 during travel; at impact τ=.00:opacity .9; .16:0
WarningLane	0.00–0.60 reveal out along actual travel; .60–.76 hold; pulse .77, .82; .85:opacity0—do not fade it across damaging travel
RubbleTransition	defeat t=1.72:opacity0; 1.85:opacity1 while original shell fades; 2.22:yScale .72; 2.48:opacity0 as rubble pile replaces it
RubblePile	defeat t=2.12:scale horizontal .86, y1; 2.48:horizontal1.0, y .90 and opacity1; persistent through motes, then environment cleanup as existing corpse protocol
HornDetached pair	defeat 1.78: detach real horn sockets; by 2.20 rotate 40–85° and arc to ground; stop moving by 2.48
4 MatterMotes	defeat 2.72: opacity0/height start; 2.80:opacity1; 3.52: vertical drift 2.7–3.25; 3.65:opacity0, one attached faint trail per mote

Lighting test: pure Neon may bleach yellow/amber to white in sunlight. Keep basalt underlays dark and reserve high-emissive masked areas for the thin rim/cracks. Don't emit from whole rock chunks. Ensure the K effects remain legible at approximately 25–40 studs on a phone.

8. Sound palette / mix gate

Use licensed Roblox audio, non-looping for one-shots. Prioritise the 300 Hz–4 kHz range; a heavy explosion with nothing but sub-bass will disappear on a phone. Limit stacking to one impact transient + one low-mid crunch body + optionally one short grit layer per actual hit. Suggested duration windows, not fixed IDs:

Event	Category	Length	Mix note
Gore load	rough granite drag	0.16–0.22 s	quiet, close
Gore hit	sharp crystal snap + middle rock thunk	0.20–0.32 s	primary readable transient
Stamp rear	hoof grind / weight shift	0.28–0.42 s	quieter than stamp
Stamp hit	large flat stone THAK + gravel fracture	0.30–0.46 s	the two hooves are one hit, not two duplicate booms
Stun	light metallic crystal twirl	0.16–0.24 s	avoid 2x loud stacking
Charge warning	brief directional granular rumble	0.30–0.50 s	no long alarm
Charge travel	midrange rushing stone grit	up to travel length, gated loop	shorten/fade as soon as movement ends
Charge impact	bright crack then 0.3-s heavy crunch	0.30–0.43 s	one impact even if 3 units affected
Charge skid	coarse gravel scrape	0.30 s	follows actual stopping time
Hurt	single chipped-stone fracture	0.18–0.26 s	suppress pile-up on repeated hits
Defeat	weighted knee drop + splitting rocks + gentle matter swell	0.26 / 0.55 / 0.70 s	leave room between three beats

Suggested starting relative gains: impact 1.0, grunt 0.48, dust/grit 0.35, chime 0.30, knockback victim impacts 0.38; A/B mix on a phone and reduce if the 4-Ram simultaneous hit clips. Do not layer random low-frequency sub-bass to imply weight.

9. Four-Ram mobile budget and pooling

This budget is PER CLIENT, shared with all other aliens, not per Ram. The brief caps particles at 34 emitted particles/s total. Treat all FX as one global token bucket; reserve 6 particles/s for non-Ram effects under this specific four-Ram stress case.

Case, four Rams same second	Maximum particle requests per Ram	Total target	Authored meshes / loose chunks
Four Gore hits	5	20/s	1 RamGoreBurst each = 4; <=3 pooled rock chips per hit = 12
Four Stamps	7	28/s	up to 4 crack-disc quadrants + 4 dust-bank quadrants per Ram = up to 32 anchored/pool pieces; <=3 pooled rock chunks per Ram = 12
Four Charges	7	28/s	one dust ribbon + one speed-streak mesh per moving Ram; warning up to 9 terrain-tiled pieces + cap per Ram; <=3 impact chunks per Ram = 12
Four concurrent Defeats	4 during collapse, 0 at mote phase	<=16/s	four static rubble piles, eight horns, 16 motes total (4 per Ram)

Global recommendations: 0 PointLights / SurfaceLights / SpotLights; 0 camera shake; <=16 loose rock fragments across these four simultaneous moves (leaves spare capacity under the earlier 24-fragment Colossus pool); collision/touch/query off for all purely visual mesh FX. Cap 1 RamStunSwirl per actually stunned target and refresh its expiration rather than stacking overlapping dizzy halos. Reuse the same authored RamGoreBurst for Charge (scale +1.35); use one pooled RamLaneTile reused 9 times per charge (not 9 unique Mesh assets). Rate-limit hoof sound triggers. All effect attachment meshes must be pooled, nonnetworked cosmetic instances; the server owns gameplay and target lists, not 30 new networked parts per attack.

Use LOD at phone distance: after 45 studs, remove secondary individual micro-flecks and use only the giant authored burst/ring; beyond 80, hide small star tips, reduce charge ribbon opacity, never hide danger lane/ring while warning. Profile four Stamps hitting on the same frame with the regular 64-unit battle; no per-frame mesh creation, dynamic mesh rebuild, or unbounded dust accumulation.

10. Capture/still pass criteria: compare directly to J1–J4 and K
J1 0.37 / 0.55 / 0.70: reference Ram silhouette preserved, dramatic pulled-back/down head then forward-and-up horn hook. Selected HornHook socket ends <=0.25 from real target surface when contact is physically authorized. Crystal spark burst looks like K1, not a spherical orange flash; no magically extending horns.
J2 0.44 / 0.50: both front hooves clearly high off the floor (~3 studs above sole baseline), horns tipped backward, both hind feet locked at ground with no pinching or hyperextended legs. Measure rear foot slip <=0.08 studs; front chains less than 97% of their lengths.
J2 0.68 / 0.89: both front soles contact at the same timestamp (<=0.025 s mismatch) and on the ground (+0.00..+0.08); K2 top-down broken radial cracks + K2 low side-on dust ring; up to 2 eligible enemies visibly dazed (each 0.50 s), tiny ones only dusted.
J3 0.50 / 0.85: warning lane rectangular, dark-rimmed, amber edged, <=18 studs, lined up with actual planned path; Ram paws once and keeps horns down, tail and dorsal hump intact.
J3 travel / impact / skid: charge movement truly translates the body (no running in place), midrange visual hot cracks and distinct ground-scraping dust trail; horns first into target, up to 2 secondary enemies knocked aside based on actual server hits; Ram stops once without moving back to cast origin.
J4 hurt 0.18 / 0.31: left shoulder chips, body staggers right, head lags, then overshoots centre; all planted hoof contacts stay within 0.08; reverse left/right correctly.
J4 defeat 0.85 / 1.75 / 2.48 / 3.15: knees truly buckle, animal lies broadly on its side before crumbling, both recognizable horns detach, rock pile has long low silhouette, orange glow dies, and exactly four separate amber motes with four trails rise (not 3/5/8).
K sheet: each major authored effect survives without particles as a recognisable shape; only small chips/dust/sparks should disappear when particle emissions are set to zero. At phone zoom, warning and impact readability take priority over micro-surface details.
Measurement report required before final GO

Supply: contact socket rest coordinates; A hit-world hook-to-enemy gap at near/far ends of gameplay range and any actual server lunge; B hind foot world drift through 0.50 and forefoot penetration/time mismatch at 0.68; C lane width-vs-hitbox measurement and actual charge distance/speed/hit timestamps (short & 18-stud case), horn impact clearance and skid stop displacement; J4 4-mote count; worst one-second particles, pooled fragments/meshes, mobile 64-unit frame cost. A pretty still cannot prove those numbers.

Source brief consistency note: ram-brief.md mistakenly says “what NEW meshes the Pebble needs”; this sheet is for the Ram, not the Pebble. Treat that as a naming typo, not an instruction to build Pebble meshes.