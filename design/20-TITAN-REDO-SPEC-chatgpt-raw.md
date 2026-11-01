TEXT ONLY now, please do not generate an image. The attached titan-brief.md is the build spec request for redoing the TITAN's attacks to match the five reference sheets you just made in this chat (J1 Tentacle Slam, J2 Goo Bomb, J3 Goo Tsunami, J4 Hurt + Defeat, K Effects). Please write the full spec it asks for (timing contract, keyframe tables per bone with contact points, events + effects by time, authored FX mesh list with sizes and curves, hurt + defeat with 16 motes, layered boss sound design for a phone speaker, budget for 2 Titans, still-check list), as precise numbers I can build from.
Worked for 8m 15s
ChatGPT said:
MEGA SQUISH TITAN — Animation Batch 2 REDO

BUILD SPECIFICATION v1.0 · 29 OCTOBER 2026

Reference sheets: J1 Tentacle Slam · J2 Goo Bomb · J3 Goo Tsunami · J4 Hurt + Defeat · K Effects

Rig: SquishF4v5 · 16 matter · 2,400 HP · 14.2 studs tall

Design target: The Titan must feel like a 14-stud, 2,400-HP boss. Its attacks should communicate enormous mass through anticipation, delayed follow-through, heavy impact geometry, secondary jelly motion, and layered sound. It must not feel like an oversized Drip.

The reference sheets establish the visual poses, silhouettes, effects, and material language. The existing power graph remains authoritative for gameplay timing, damage, and danger geometry.

This specification is intended to be directly implementable by Claude in Luau, with the listed meshes authored in Blender.

1. Non-negotiable implementation rules

Server-authoritative damage. The server owns the cast timestamp, target, hit time, affected targets, damage, slow, and knockback. Animation and VFX never apply damage themselves.

No runtime-generated primitive replacements for the main effects. Splash crowns, crack discs, wave bodies, impact sheets, puddles, and shockwave geometry are authored meshes.

No PointLights, SpotLights, SurfaceLights, or camera shake. Neon-looking geometry, emissive-style textures and bright cyan crack patterns provide the glow.

No scaling the skeletal bones. Use rotation and translation on the actual rig. Use authored meshes with scale curves for additional deformation, including the defeat melt.

Preserve one continuous creature. The body, crown, fangs, central purple eye, horns, four tentacles, cyan veins, and skirt remain recognizable in every normal attack.

Contacts are solved in world space. Never trust bone rotations alone to place a tentacle on the ground.

No pooled FX replaying stale events. Every cast has a unique castId; events execute at most once per cast.

Sound is part of the attack, not an afterthought. Every major attack needs anticipation, mechanical movement, initial impact, and sustained aftermath.

2. Rig conventions and coordinate contract

The source rig and bone origins are those in titan-brief.md.

Parameter

	

Value




Model forward

	

Local -Z




Model right

	

Local +X




Ground plane

	

Y = 0




Root rest

	

(0, 0.53, 0)




Body rest

	

(0, 1.73, 0.10)




Top rest

	

(0, 5.93, 0.20)




Lid rest

	

(-0.20, 9.08, -3.75)




Front FL origins

	

(3.20, 2.23, -2.60), (5.60, 1.93, -7.60), (4.00, 3.93, -10.90)




Front FR origins

	

Mirrored in X




Back BL origins

	

(3.60, 2.23, 2.00), (8.30, 3.03, 2.80), (8.50, 7.13, 1.40)




Back BR origins

	

Mirrored in X




Root movement speed

	

8 studs/s




Root turning speed

	

60°/s maximum

Important: The bone origins are not the terminal tip vertices. A final world-space position for the tip cannot be guaranteed from bone origins alone. The animation tables below provide exact desired tip contacts, while the last-bone tip offset must be measured once from the imported mesh.

Numeric notation

All rotations are in degrees, relative to the imported neutral pose.

rx is the tentacle's forward/backward swing; positive means forward swing in the animator's normalized convention.

rz is downward/inward swing for the +X-side limbs. Mirror its sign for the -X-side limbs.

oy is a bone's local vertical offset in studs.

F is forward movement in studs along -Z, relative to the cast pivot.

Root P is positive for forward lean in this specification; invert the sign at the engine adapter if necessary.

E is smooth cubic ease-in-out; I is cubic ease-in; O is cubic ease-out; L is linear.

Unspecified channels are zero. Every row is an absolute offset from rest, not an increment from the previous row.

All tables use normalized animation semantics. Before implementation, run a one-time signed-axis calibration for rx, rz, and root pitch against the real rig. Never blindly assume the naming corresponds to Roblox Euler signs.

Global animation and event contract

Setting

	

Requirement




Visual pose sampling

	

Every RenderStepped frame, interpolated from cast timestamp




Server time source

	

One synchronized server clock




Event firing

	

Crossing thresholds, not equality comparisons




Max event timing error

	

One rendered frame




Pose interpolation

	

Cubic easing by default




Combat contact

	

Exact authoritative server hit time




Root visual offsets

	

Local-only, no physics teleport




Target tracking

	

Fixed world-space snapshot at cast




Hurt during committed attack

	

0.35 additive weight




Hurt when uncommitted

	

1.00 weight




Defeat

	

Terminal; cancels all attacks




FX pooling

	

Reset transform, alpha, size, and active event identity

Attack VFX must use the real cast orientation and world-space aim. Do not keep rotating an attack effect toward a moving enemy after the cast is locked.

3. Timing contract — all four sequences

The J1 reference has illustrative timings substantially shorter than the existing gameplay attack. Those poses must be retimed to the server's real hit at 1.64 s.

A — Tentacle Slam (J1)

Time

	

Gameplay or animation state




0.00

	

Cast accepted, 120° danger wedge appears




0.28

	

Body begins leaning backward; front tentacles retract




0.74

	

Formal warning duration complete; direction locked




1.20

	

High wind-up, both front tentacles overhead




1.48

	

Peak coiled pose; short anticipation hold




1.56

	

Both tentacles begin accelerating downward




1.64

	

Authoritative hit: 400 damage, ×2.5 versus Brutes




1.64–1.72

	

Two tentacle contacts, dual goo crowns, shockwave expansion




2.08

	

Maximum splash and body compression




2.65

	

Tentacles retract, body rebounds




3.40

	

Body returns to free movement




3.80

	

Last persistent attack FX removed

Hit geometry: 120° forward wedge with 16-stud radius measured from the cast centre. No target outside the server's existing wedge is hit because of splash visuals.

B — Goo Bomb (J2)

Time

	

State




0.00

	

Cast target acquired; radius-5 ground warning appears




0.40

	

Throat begins glowing and cheeks start bulging




1.20

	

Body compresses, mouth opens wide




2.20

	

Fully formed 3-stud goo projectile in mouth




2.40

	

Warning duration complete; fixed target locked




2.55

	

Spit release, projectile becomes independent




3.00

	

Projectile near apex of trajectory




3.40

	

Authoritative impact: 160 damage + slow




3.45–3.80

	

Impact splash expands; bomb becomes puddle




5.55

	

Puddle gameplay duration ends

Target: ground point up to approximately 16 studs from the cast origin. Gameplay radius: 5 studs.

The body can finish its spit recoil before the puddle ends. The puddle remains a separately owned gameplay hazard.

C — Goo Tsunami (J3)

Time

	

State




0.00

	

Cast accepted; 12 × 30 danger lane appears




0.40

	

Titan rises and body starts swelling




1.20

	

Goo accumulation starts in front of the skirt




1.75

	

Huge wall formed; all four tentacles high




2.10

	

Warning complete; all four tentacles slam; wave released




2.60

	

Rolling wave dominates the lane




3.00

	

Crest approaches terminal impact




3.20

	

Authoritative hit: existing 300 / 60 + slow contract




3.25–3.75

	

Splash wall, tumbling debris, goo flood




4.15

	

Titan finishes shrinking to neutral posture




5.00

	

Reference-sheet aftermath pose complete

Danger geometry: 12 studs wide, extending 0–30 studs forward from the cast centre.

The brief specifies 300 / 60 + slow but does not define what the two damage figures represent. Preserve the existing power-graph interpretation; do not silently turn 60 into damage-over-time, residual damage, or a second strike.

Important visual synchronization: Because the gameplay contract supplies one hit time at 3.20 rather than progressive damage along the moving wall, the wave must clearly culminate at 3.20. The earlier rolling motion is visual anticipation, not a second damaging hit.

D — Hurt and Defeat (J4)

Sequence

	

Time

	

State




Hurt

	

0.00

	

Incoming impact; body dents




Hurt

	

0.10

	

Maximum squash; eye squeezed shut




Hurt

	

0.30

	

Rebound overshoots neutral




Hurt

	

0.52

	

Fully recovered




Defeat

	

0.00

	

Terminal hit; stagger




Defeat

	

0.40

	

Maximum backward reel




Defeat

	

1.20

	

Crown and dome collapse




Defeat

	

2.40

	

Body melted almost entirely




Defeat

	

3.20

	

Only shallow puddle and sinking eye




Defeat

	

3.80

	

Sixteen matter motes emerge

The Titan becomes non-interactive immediately upon the server accepting defeat. Its corpse sequence is visual only.

4. J1 — Tentacle Slam: exact animation
4.1 Root, body, crown and eyelid

Root F is positive forward along -Z. Body rx and Top rx are relative to their rest orientation.

t (s)

	

Root Y

	

Root F

	

Root P

	

Body rx

	

Body oy

	

Top rx

	

Top oy

	

Lid

	

Ease




0.00

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°

	

E




0.28

	

+0.10

	

-0.08

	

-4°

	

-5°

	

+0.05

	

+3°

	

+0.10

	

12°

	

O




0.74

	

+0.42

	

-0.35

	

-9°

	

-10°

	

+0.18

	

+6°

	

+0.30

	

24°

	

E




1.20

	

+0.58

	

-0.55

	

-12°

	

-13°

	

+0.24

	

+9°

	

+0.42

	

32°

	

E




1.48

	

+0.62

	

-0.60

	

-14°

	

-15°

	

+0.27

	

+10°

	

+0.48

	

38°

	

O




1.56

	

+0.42

	

-0.25

	

-5°

	

+5°

	

+0.10

	

-4°

	

+0.30

	

30°

	

I




1.64

	

-0.18

	

+1.20

	

+13°

	

+15°

	

-0.28

	

-10°

	

-0.30

	

16°

	

I




1.82

	

-0.24

	

+1.30

	

+11°

	

+13°

	

-0.35

	

-8°

	

-0.42

	

22°

	

O




2.08

	

-0.10

	

+0.92

	

+6°

	

+7°

	

-0.20

	

+5°

	

+0.06

	

12°

	

O




2.65

	

+0.08

	

+0.28

	

-2°

	

-3°

	

+0.12

	

+3°

	

+0.15

	

5°

	

E




3.40

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°

	

E

The body should have a visibly delayed recoil. At 1.82, the front tentacles are still planted while the dome finishes compressing, producing a convincing weight-transfer moment.

4.2 Front tentacles: FL1–3 and FR1–3

Values are per segment, in bone order. Every tuple contains three explicit per-bone values.

t

	

FL rx (1,2,3)

	

FL rz (1,2,3)

	

Ease




0.00

	

(0, 0, 0)

	

(0, 0, 0)

	

E




0.28

	

(-12, -18, -12)

	

(-4, -8, -10)

	

O




0.74

	

(-21, -28, -16)

	

(-8, -12, -14)

	

E




1.20

	

(-28, -32, -22)

	

(-12, -16, -14)

	

E




1.48

	

(-32, -35, -25)

	

(-14, -18, -16)

	

O




1.56

	

(-14, -10, +8)

	

(+3, +8, +12)

	

I




1.64

	

(+28, +37, +22)

	

(+12, +16, +14)

	

I




1.82

	

(+30, +39, +20)

	

(+14, +18, +15)

	

O




2.08

	

(+15, +22, +12)

	

(+8, +10, +8)

	

O




2.65

	

(+4, +7, +4)

	

(+3, +4, +2)

	

E




3.40

	

(0, 0, 0)

	

(0, 0, 0)

	

E

FR1–3 use the same rx tuple and the opposite rz signs. This is mirroring, not a 180° rotation or a swap of FL/FR labels.

The coiled wind-up must read as two huge tentacles rising backward, not as short arms pointing vertically. The last segment should curl inward toward the head.

4.3 Back tentacles: BL1–3 and BR1–3

These provide bracing and recoil. They do not deliver J1 damage.

t

	

BL rx (1,2,3)

	

BL rz (1,2,3)




0.00

	

(0, 0, 0)

	

(0, 0, 0)




0.74

	

(-5, -8, -10)

	

(+6, +8, +6)




1.48

	

(-10, -14, -12)

	

(+12, +12, +8)




1.64

	

(+12, +16, +8)

	

(+15, +16, +10)




1.82

	

(+15, +18, +10)

	

(+18, +18, +12)




2.08

	

(-5, -9, -6)

	

(-6, -8, -6)




2.65

	

(+3, +5, +3)

	

(+4, +5, +3)




3.40

	

(0, 0, 0)

	

(0, 0, 0)

BR mirrors rz. Intermediate times interpolate smoothly.

4.4 Mandatory world-space contact

At 1.64, the two main front tips target these points in cast-local space:

Tip

	

Target X

	

Target Y

	

Target Z




TentFL3 terminal tip

	

+4.50

	

+0.12

	

-12.00




TentFR3 terminal tip

	

-4.50

	

+0.12

	

-12.00

These positions are visual contact targets, not collision origins.

Apply the inherited full-chain rotations first, then the existing tip correction to the real mesh tip.

Target terminal-tip ground error: ≤0.25 studs.

Prefer raw pose error ≤0.90 studs before correction.

Maximum correction: 8° per joint per pass.

Up to two correction passes, recalculating forward kinematics between passes.

Hold the planted contact from 1.64–1.88; blend it out by 2.08.

Both contact events occur on the same gameplay frame; a cosmetic delay of no more than 0.02 s is permitted.

Freeze the contact targets in world space while the body finishes its local compression.

If either tip cannot satisfy the tolerance, change the upstream pose, not the ground position or damage geometry.

4.5 Slam events and effects

Time

	

Event

	

Exact visual




0.00

	

SlamWarnStart

	

120° wedge, radius 16, thin cyan outline with faint interior fill




0.28

	

SlamWindup

	

Cyan vein texture intensity rises to 1.25× baseline




0.74

	

SlamWarnLock

	

Wedge outline brightens and remains stationary




1.48

	

SlamPeak

	

Front tips pause overhead; large droplets stretch but do not detach yet




1.56

	

SlamWhip

	

Two authored curved motion ribbons, width 0.55




1.64

	

SlamDamage

	

One server damage event; both grounded tips trigger effects




1.64

	

SlamCrowns

	

Two 8-wide splash crowns at the front contact points




1.64

	

SlamCracks

	

Two 10-wide crack discs, with overlap managed by one shared material mask




1.66

	

SlamShockwave

	

120° ground goo wave expands from radius 4 to 16




1.69

	

SlamDebris

	

6–8 rock chunks per Titan, plus small droplets




2.08

	

SlamSplashPeakEnd

	

Crowns collapse; heavier goo sheets fold inward




2.65

	

SlamResidual

	

Only crack markings and shallow splats remain




3.40

	

SlamBodyFree

	

Skeleton fully neutral




3.80

	

SlamFXClear

	

All remaining attack-specific meshes removed

Visual priority: the two tentacles physically striking the ground, followed by one enormous connected shockwave. Avoid separate explosions that make the two strikes feel unrelated.

5. J2 — Goo Bomb: exact animation
5.1 Main skeleton

t (s)

	

Root Y

	

Root F

	

Root P

	

Body rx

	

Body oy

	

Top rx

	

Top oy

	

Lid

	

Ease




0.00

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°

	

E




0.40

	

-0.08

	

-0.10

	

-3°

	

-5°

	

-0.12

	

+4°

	

+0.08

	

12°

	

O




1.20

	

-0.32

	

-0.28

	

-7°

	

-9°

	

-0.30

	

+8°

	

+0.10

	

22°

	

E




2.20

	

-0.45

	

-0.35

	

-10°

	

-12°

	

-0.38

	

+10°

	

+0.14

	

30°

	

E




2.40

	

-0.48

	

-0.38

	

-11°

	

-13°

	

-0.40

	

+10°

	

+0.16

	

34°

	

O




2.55

	

+0.28

	

+0.82

	

+17°

	

+18°

	

+0.16

	

-12°

	

-0.12

	

10°

	

I




2.70

	

+0.18

	

+0.48

	

+10°

	

+12°

	

+0.10

	

-8°

	

0

	

18°

	

O




3.00

	

-0.08

	

+0.12

	

-3°

	

-4°

	

-0.08

	

+4°

	

+0.08

	

8°

	

E




3.40

	

+0.04

	

0

	

+1°

	

+2°

	

+0.04

	

-2°

	

0

	

0°

	

E




3.90

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°

	

E

The head should appear to compress under the bomb's mass and then snap violently upward and forward at release.

5.2 Tentacle posing

FL/FR mirrored, BL/BR mirrored. rx is given for all three bones; rz for the positive-X side, mirrored on the other side.

t

	

Front rx

	

Front rz

	

Back rx

	

Back rz




0.00

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)




0.40

	

(+4,+6,+5)

	

(+8,+8,+5)

	

(-3,-5,-5)

	

(+5,+6,+4)




1.20

	

(+9,+12,+8)

	

(+12,+14,+8)

	

(-8,-12,-8)

	

(+9,+10,+7)




2.20

	

(+14,+16,+10)

	

(+16,+16,+10)

	

(-12,-16,-10)

	

(+12,+12,+8)




2.40

	

(+16,+18,+12)

	

(+18,+18,+12)

	

(-14,-18,-12)

	

(+14,+14,+9)




2.55

	

(-14,-20,-12)

	

(-10,-12,-8)

	

(+14,+18,+12)

	

(+16,+18,+12)




2.70

	

(-8,-10,-6)

	

(-5,-6,-4)

	

(+8,+10,+6)

	

(+8,+10,+6)




3.00

	

(+4,+6,+3)

	

(+4,+4,+3)

	

(-4,-6,-4)

	

(-4,-5,-3)




3.40

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

The front tentacles brace during charging and open outward on release. The rear tentacles counterbalance the launch.

5.3 Throat, cheeks and mouth — additional authored geometry

The existing rig does not list a jaw bone or cheek bones. Therefore, bone animation alone cannot create the bulging cheeks and expanding mouth in J2.

Build three lightweight cosmetic meshes:

Mesh

	

Dimensions

	

Attachment / behaviour




Titan_ThroatBulge

	

3.0 × 2.3 × 1.3

	

Under face, follows Body, swells during charging




Titan_CheekBulge_L

	

1.4 × 1.7 × 0.7

	

Along left mouth edge; expands 1.00→1.30




Titan_CheekBulge_R

	

1.4 × 1.7 × 0.7

	

Mirrored right mouth edge

Use a 0.55–0.75 baseline transparency for their edges or a texture-matched seamless surface, then animate scale. The cheeks should look like part of the Titan, not detached balloons.

If these cannot merge cleanly into the existing face, add dedicated cheek deformation bones instead; do not ship obvious overlay seams.

The mouth is already visually open in the supplied mesh. Its apparent widening can be achieved with slight mouth-rim deformation, but a literal jaw-opening animation requires a controllable mouth region.

5.4 Projectile trajectory

Projectile mesh: 3.00-stud diameter.

The projectile launches from the actual mouth centre. Use a measured local mouth attachment, provisionally (0, 6.2, -4.5) in model space. Replace that provisional value with the measured attachment position before finalizing the build.

The target is a fixed world-space ground point established by the server. Let S be the mouth position at 2.55 and T the locked impact centre.

Time

	

Horizontal position

	

Height




2.55

	

S

	

S.y




2.70

	

17.6% of path to T

	

Approximately 9.3




3.00

	

52.9% of path to T

	

Approximately 13.4




3.20

	

76.5% of path to T

	

Approximately 9.3




3.40

	

T

	

Ground contact, centre Y approximately 1.5

Use a smooth cubic path with a vertical tangent of zero at the 3.00 apex, and a steep downward final segment. These are animation constraints, not a claim of ballistic Newtonian motion.

Do not apply the same fixed world coordinates to every cast. The path must be transformed for each locked target.

The trail follows actual previous projectile positions; it must not point toward a target that the server has since moved or changed.

5.5 Goo Bomb events

Time

	

Event

	

Effect




0.00

	

BombWarn

	

Radius-5 circle at locked ground target




0.40

	

BombChargeBegin

	

Throat glow mesh appears




1.20

	

BombBodyCompress

	

Cheek and throat bulges; gurgling increases




1.80

	

BombSeed

	

Small glowing goo seed inside the mouth




2.20

	

BombFull

	

Ball reaches diameter 3




2.40

	

BombWarnLock

	

Target ring brightens; target remains fixed




2.55

	

BombSpit

	

Projectile detached; mouth spray and ribbon trail




3.00

	

BombApex

	

Ball wobbles ±10°; droplets detach




3.28

	

BombPreImpact

	

Projectile descends steeply; targeting ring pulses




3.40

	

BombDamage

	

Server damage + slow; bomb mesh replaced by splat




3.40

	

BombSplat

	

10-wide crown; three thick lateral goo sheets




3.48

	

BombGroundCrack

	

Small 6-wide cracked substrate, subordinate to the goo




3.65

	

BombPuddle

	

10-wide bubbling sticky puddle




4.20

	

BombBubbles

	

Bubble cycle continues without expanding the hitbox




5.55

	

BombPuddleEnd

	

Slow-area lifetime ends; fade and clean up

The player should perceive an enormous object being launched, followed by a sticky, heavy splat. Do not substitute a particle burst for the projectile or impact crown.

6. J3 — Goo Tsunami: exact animation
6.1 Main skeleton

| t (s) | Root Y | Root F | Root P | Body rx | Body oy | Top rx | Top oy | Lid | Ease |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0.00 | 0 | 0 | 0° | 0° | 0 | 0° | 0 | 0° | E |
| 0.40 | +0.42 | -0.22 | -6° | -8° | +0.30 | +5° | +0.35 | 14° | O |
| 1.20 | +0.92 | -0.45 | -11° | -13° | +0.56 | +8° | +0.72 | 22° | E |
| 1.75 | +1.25 | -0.55 | -15° | -17° | +0.70 | +10° | +0.94 | 32° | O |
| 2.10 | -0.25 | +0.95 | +18° | +19° | -0.38 | -13° | -0.50 | 12° | I |
| 2.30 | -0.30 | +1.02 | +14° | +15° | -0.42 | -10° | -0.46 | 20° | O |
| 2.60 | +0.12 | +0.38 | +4° | +5° | +0.06 | +5° | +0.18 | 12° | E |
| 3.20 | +0.05 | +0.08 | -2° | -2° | +0.10 | +2° | +0.12 | 5° | E |
| 4.15 | 0 | 0 | 0° | 0° | 0 | 0° | 0 | 0° | E |
| 5.00 | 0 | 0 | 0° | 0° | 0 | 0° | 0 | 0° | E |

Scale limitation: The existing skeleton has no bone scaling. The swollen warning silhouette should come from increased Top separation, skirt expansion and an authored transparent swelling shell, not from scaling the entire skinned Titan.

Use Titan_SwellShell, approximately 13.4 × 13.8 × 10.5 studs at its neutral authored size, anchored to the cast pose:

0.00: invisible, scale 1.00

0.40: scale 1.04, opacity 0.12

1.20: scale 1.12, opacity 0.28

1.75: scale 1.18, opacity 0.35

2.10: scale 1.04, opacity 0.15

2.30: invisible

The shell should be a texture-matched bulging surface, not a second clearly visible monster. If it creates double-contours, replace it with additional deformation bones.

6.2 All four tentacles

Values are absolute per-bone rotations, relative to rest.

t

	

Front rx

	

Front rz

	

Back rx

	

Back rz




0.00

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)




0.40

	

(-12,-16,-12)

	

(-8,-10,-8)

	

(-10,-12,-10)

	

(-8,-9,-6)




1.20

	

(-23,-27,-17)

	

(-14,-15,-12)

	

(-20,-24,-17)

	

(-12,-14,-9)




1.75

	

(-32,-34,-22)

	

(-18,-18,-14)

	

(-28,-30,-20)

	

(-18,-18,-12)




2.10

	

(+27,+36,+24)

	

(+14,+18,+14)

	

(+38,+36,+22)

	

(+18,+22,+16)




2.30

	

(+29,+38,+22)

	

(+16,+19,+16)

	

(+40,+37,+20)

	

(+20,+23,+17)




2.60

	

(+12,+16,+10)

	

(+7,+9,+6)

	

(+14,+17,+10)

	

(+8,+10,+7)




3.20

	

(+3,+5,+3)

	

(+2,+3,+2)

	

(+4,+6,+3)

	

(+3,+4,+2)




4.15

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

Use mirrored rz on the corresponding opposite-side bones.

6.3 Four-contact ground placement

Target points in cast-local coordinates:

Bone terminal tip

	

X

	

Y

	

Z




TentFL3

	

+4.50

	

+0.12

	

-10.50




TentFR3

	

-4.50

	

+0.12

	

-10.50




TentBL3

	

+5.10

	

+0.12

	

-3.10




TentBR3

	

-5.10

	

+0.12

	

-3.10

Contact event: 2.10 s.

Front terminal error ≤0.25 studs.

Back terminal error ≤0.35 studs.

Rear tips require a proper reach test, because their rest origins are much farther to the sides.

Maximum correction per joint: 8° per pass; up to two passes.

Ground contact held until 2.28.

Release planted positions progressively between 2.28 and 2.55.

These are target contacts, not validated inverse-kinematics results. Because the final tip offsets and imported local joint axes are not in the brief, verify the four contacts in Roblox and retune the parent segment keys before marking this sequence complete.

6.4 Tsunami effect and hit synchronization

The visual lane starts at the locked cast centre:

−
6
≤
𝑥
≤
6
,
−
30
≤
𝑧
≤
0
−6≤x≤6,−30≤z≤0

This corresponds to 12 wide × 30 long, including the section immediately ahead of the Titan.

The danger-lane mesh is purely visual. Actual gameplay uses the existing power-graph hit test.

The wave motion is divided into three parts:

Interval

	

Position / presentation




1.20–2.10

	

Goo gathers into a wall without travelling down the lane




2.10–3.20

	

Wave crest travels forward from 0 toward 30 studs




3.20–3.75

	

Terminal crash and splash wall; long flood remains

For the animated front edge, use:

𝑑
(
𝑡
)
=
30
clamp
⁡
(
𝑡
−
2.10
1.10
,
0
,
1
)
d(t)=30clamp(
1.10
t−2.10
	​

,0,1)

The progression is intentionally linear at the gameplay level. Secondary wave deformation supplies the accelerating, rolling appearance.

Time

	

Front-edge distance




2.10

	

0.0 studs




2.30

	

5.5 studs




2.60

	

13.6 studs




2.80

	

19.1 studs




3.00

	

24.5 studs




3.20

	

30.0 studs

Production caveat: This creates a visible travelling wave before the single 3.20 server hit. Enemies nearer the Titan may appear to be passed by the wave before damage occurs. Do not invent early client damage to conceal this. If that mismatch fails the playtest, change the animation staging to a mostly stationary rising wall until late in the sequence, then use a rapid lane-wide surge at 3.20. Changing to true travelling collision damage would be a separate server gameplay change.

6.5 Wave height and silhouette

The K sheet specifies a 12 × 10-stud authored source mesh. J3 depicts a wave taller than the 14.2-stud Titan.

Resolve this by retaining the 12 × 10 source mesh but using:

Authored mesh height: 10.0 studs.

Maximum vertical scale: 1.55.

Maximum apparent height: 15.5 studs.

Maximum width: 12.0 studs.

Crest curl depth: 4.5 studs.

Thick crest lip: 1.2 studs.

Base thickness: 2.0 studs.

Wave pitch: -10° to +6° during roll.

Side-to-side crest wobble: ±0.45 studs maximum.

The Titan must be visible behind the wave in the gather and release frames. Once the wave starts rolling, it can dominate the entire shot.

6.6 Tsunami events

Time

	

Event

	

Effect




0.00

	

TsunamiWarn

	

12 × 30 cyan outlined ground lane




0.40

	

TsunamiSwell

	

Body glow increases; skirt thickens




1.20

	

TsunamiGather

	

Authored goo accumulation rises from skirt




1.75

	

TsunamiWallFull

	

Accumulation 12 wide, 5.5 tall




2.10

	

TsunamiRelease

	

Four tentacle contacts; accumulation becomes moving wave




2.12

	

TsunamiGroundBurst

	

Low wide crown along launch edge




2.30

	

TsunamiRoll

	

Wave body at full width; crest starts curling




2.60

	

TsunamiFoam

	

Authored foam crest and 4–6 tumbling rock chunks




3.00

	

TsunamiTerminalApproach

	

Wave at near-maximum height; splash buildup




3.20

	

TsunamiDamage

	

Server-authoritative hit, existing 300 / 60 + slow




3.20

	

TsunamiCrash

	

14-wide impact wall; debris and enemies thrown




3.28

	

TsunamiFlood

	

12 × 30 long glowing goo strip left on ground




3.75

	

TsunamiSplashEnd

	

Main vertical splash and flying rock effects gone




4.15

	

TsunamiBodyFree

	

Titan fully neutral




5.00

	

TsunamiVisualEnd

	

End of the reference aftermath pose

The flood should suggest slowing through thick bubbles and partial immersion. Its gameplay lifetime must follow the existing server-side slow rules; 5.00 s is a reference-pose endpoint, not authorization to change those rules.

7. J4 — Hurt and Defeat
7.1 Hurt: 0.52 seconds, right-side impact

The hit comes from the Titan's physical right, local +X. The dome compresses inward on that side, the head recoils away from the blow, then the body overshoots neutral.

Hurt is additive unless defeat is triggered.

Main bone keys

Root X is lateral displacement; R is roll away from the incoming hit. The table uses a right-side hit as the reference and mirrors signs for a left-side hit.

t (s)

	

Root X

	

Root Y

	

Root R

	

Body rz

	

Body ox

	

Top rz

	

Top ox

	

Lid




0.00

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°




0.06

	

-0.28

	

-0.12

	

-6°

	

-9°

	

-0.24

	

-11°

	

-0.12

	

48°




0.10

	

-0.40

	

-0.18

	

-8°

	

-12°

	

-0.35

	

-13°

	

-0.20

	

60°




0.20

	

-0.22

	

-0.08

	

-4°

	

-5°

	

-0.12

	

-3°

	

-0.02

	

24°




0.30

	

+0.22

	

+0.09

	

+5°

	

+7°

	

+0.16

	

+8°

	

+0.12

	

8°




0.42

	

-0.08

	

-0.03

	

-2°

	

-3°

	

-0.06

	

-2°

	

-0.04

	

2°




0.52

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

0°

Easing: 0.00–0.10 O, 0.10–0.30 E, 0.30–0.52 E.

Tentacle hurt reaction

Values are per segment. Mirror the lateral component on the opposite side.

t

	

Hit-side rx

	

Opposite-side rx

	

Back rx




0.00

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)




0.10

	

(+12,+20,+24)

	

(-10,-16,-18)

	

(+8,+12,+10)




0.30

	

(-9,-14,-12)

	

(+12,+18,+14)

	

(-8,-10,-9)




0.42

	

(+3,+5,+4)

	

(-4,-5,-4)

	

(+3,+4,+2)




0.52

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

Apply hit-side rz of (8,12,10) at 0.10, (-5,-8,-6) at 0.30, and zero at 0.52. The opposite-side limb receives the mirrored sign.

Body dent

Use a small impact-deformation mesh if the existing Body/Top skin weights cannot produce a convincing lateral dent.

Property

	

Value




Hit-side local centre

	

Approximately (4.2, 7.0, -1.8)




Maximum inward depth

	

0.48 studs




Maximum affected diameter

	

3.4 studs




Maximum compression time

	

0.10 s




Rebound outward bulge

	

0.16 studs at 0.30 s




Fully neutral

	

0.52 s

Use a smooth deformation profile, not a sharp circular crater. Do not visibly detach a patch from the head.

Additive behaviour

When the Titan is in a committed attack:

𝑃
final
=
𝑃
attack
+
0.35
𝑃
hurt
P
final
	​

=P
attack
	​

+0.35P
hurt
	​


Translations and signed rotations are blended independently. Re-solve any active ground-planted contacts after applying hurt.

At 0.35 weight, the hurt eyelid can only contribute up to 21° of its 60° close value; this is intentional during committed attacks. Outside an attack, the eye fully shuts.

A new nonfatal hit can refresh the reaction, but do not stack multiple additive hurt tracks. Use a visual retrigger interval of 0.18 s and restart from the current blended pose.

Hurt FX: 4–6 small goo droplets from the struck side, maximum droplet travel 2.8 studs, fully cleared by 0.48 s.

7.2 Defeat: terminal, 3.80 seconds

This should feel like a gigantic living mass losing its internal structure, not simply shrinking vertically.

Root, body, Top and eye progression

t

	

Root Y

	

Root F

	

Root P

	

Body rx

	

Body oy

	

Top rx

	

Top oy

	

Eye/Lid




0.00

	

0

	

0

	

0°

	

0°

	

0

	

0°

	

0

	

Eye wide, lid 0°




0.20

	

+0.24

	

-0.40

	

-12°

	

-12°

	

+0.10

	

+12°

	

+0.18

	

Eye wide




0.40

	

+0.35

	

-0.65

	

-17°

	

-18°

	

+0.20

	

+16°

	

+0.30

	

Eye wide, dizzy




0.75

	

-0.20

	

+0.20

	

+8°

	

+10°

	

-0.35

	

-8°

	

-0.45

	

Lid 20°




1.20

	

-0.65

	

+0.30

	

+10°

	

+14°

	

-1.10

	

+20°

	

-1.75

	

Lid 38°




1.80

	

-0.82

	

+0.20

	

+5°

	

+10°

	

-1.60

	

+24°

	

-2.50

	

Lid 48°




2.40

	

-0.95

	

0

	

0°

	

+4°

	

-2.00

	

+15°

	

-3.30

	

Eye half submerged




3.20

	

-0.95

	

0

	

0°

	

0°

	

-2.10

	

0°

	

-3.70

	

Eye disappears




3.80

	

-0.95

	

0

	

0°

	

0°

	

-2.10

	

0°

	

-3.70

	

Only puddle remains

These bone keys control the initial collapse. They cannot, by themselves, produce the final flat silhouette.

Tentacle collapse keys

t

	

Front rx

	

Front rz

	

Back rx

	

Back rz




0.00

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)

	

(0,0,0)




0.40

	

(-14,-20,-15)

	

(-8,-10,-8)

	

(-10,-14,-12)

	

(-6,-8,-6)




0.75

	

(+10,+16,+12)

	

(+8,+12,+8)

	

(+12,+16,+10)

	

(+10,+12,+8)




1.20

	

(+22,+28,+18)

	

(+14,+18,+14)

	

(+25,+28,+17)

	

(+16,+20,+14)




1.80

	

(+12,+18,+10)

	

(+10,+12,+8)

	

(+14,+17,+10)

	

(+10,+13,+9)




2.40

	

(+5,+7,+3)

	

(+4,+5,+3)

	

(+6,+8,+4)

	

(+5,+6,+3)

At 1.20, all four tentacle tips must visibly lie flat or nearly flat on the studio ground. Solve contact at each actual tip rather than treating these rotations as guaranteed contact.

Between 1.80 and 2.40, blend the limb geometry into the melting proxy. Do not leave skeletal tentacles standing above the puddle.

7.3 Required authored defeat geometry

Create:

Mesh

	

Default size

	

Purpose




Titan_DefeatCollapseShell

	

13 × 11 × 11

	

Caving dome, drooping horns, sinking eye




Titan_DefeatMeltBody

	

13 × 5 × 12

	

Transitional melting heap with preserved cyan veins




Titan_DefeatPuddle

	

13 × 0.22 × 12

	

Final spreading goo puddle




Titan_MatterMote

	

0.62 diameter

	

Reused sixteen times

At 1.05–1.30, crossfade the normal skinned dome into the authored collapse shell. At 1.70–2.55, crossfade the collapse shell into the melt heap, and then into the puddle.

The collapse shell must maintain the Titan's original sculpted features. Its horn positions, eye colour, fangs and blue-cyan texture should stay identifiable until they are physically submerged.

Do not simply scale the whole character's Y to zero; that produces pancake horns, a flattened eye, and distorted teeth.

Defeat deformation curves

Time

	

Collapse shell height

	

Melt heap height

	

Puddle width

	

Behaviour




0.75

	

100%

	

Hidden

	

8.0

	

Initial sag




1.20

	

72%

	

Hidden

	

9.0

	

Dome caves




1.80

	

46%

	

3.8 studs

	

10.5

	

Tentacles dissolve




2.40

	

22%

	

1.8 studs

	

12.0

	

Eye sinks




3.20

	

Hidden

	

0.35 studs

	

13.0

	

Flat goo remains




3.80

	

Hidden

	

Hidden

	

13.0

	

Matter release

Puddle expansion uses ease-out, becoming progressively slower as it reaches maximum width. It must not resemble a circular shockwave.

7.4 Sixteen matter motes — exact behaviour

Create exactly sixteen motes from one pooled mesh asset, not sixteen particle emitters.

For i = 0..15:

𝜃
𝑖
=
𝑖
×
137.507764
∘
θ
i
	​

=i×137.507764
∘
𝑟
𝑖
=
1.0
+
3.8
(
𝑖
+
0.5
)
/
16
r
i
	​

=1.0+3.8
(i+0.5)/16
	​

𝑥
𝑖
=
𝑟
𝑖
cos
⁡
𝜃
𝑖
,
𝑧
𝑖
=
𝑟
𝑖
sin
⁡
𝜃
𝑖
x
i
	​

=r
i
	​

cosθ
i
	​

,z
i
	​

=r
i
	​

sinθ
i
	​


All positions are relative to the final puddle centre.

Property

	

Value




Mote count

	

16 exactly




Individual diameter

	

0.62 studs




First visible

	

3.80 s




Initial Y

	

0.30–0.50 studs




Rise delay

	

(i mod 4) × 0.08 s




Rise height

	

3.5–6.0 studs




Rise duration

	

1.05 s




Horizontal drift

	

Maximum 0.45 studs




Bob amplitude

	

0.12 studs




Glow halo

	

1.25× mote diameter




Maximum lifetime

	

5.20 s from defeat start

Spawn all sixteen at 3.80, then stagger their upward motion into four groups. Use an ease-out vertical rise with a little damped bobbing. The group should feel like valuable matter being released, not ordinary splashing debris.

The motes use the same cyan-blue material as the Titan, with a bright central core and subtle purple outer fringe.

Gameplay separation: The visual count of sixteen represents sixteen matter, but no client-side mote independently creates currency, matter, or other rewards. The server remains authoritative.

7.5 Defeat events

Time

	

Event

	

Effect




0.00

	

TitanDefeatStart

	

Cancel attack track, stop future damage events, disable interaction




0.15

	

DefeatReel

	

Body springs backward; small goo drops




0.40

	

DefeatStaggerPeak

	

Eye wide; tentacles sag




0.75

	

DefeatCollapseBegin

	

Collapse proxy activates




1.20

	

DefeatBodyFall

	

Dome caves; four limbs hit the ground




1.70

	

DefeatMeltBegin

	

Melt geometry starts replacing normal rig




2.40

	

DefeatNearFlat

	

Eye half submerged; bubbles




3.20

	

DefeatPuddleOnly

	

Original rig and eye fully hidden




3.80

	

DefeatMatterRelease

	

Spawn exactly sixteen motes




5.20

	

DefeatCosmeticClear

	

Motes cleared; puddle cleaned up according to corpse-visibility policy

Keep the 3.80-second terminal defeat sequence intact. Mote movement after 3.80 is post-defeat cosmetic animation, not a longer gameplay lock.

8. K — Authored FX mesh library

All dimensions are in studs. Meshes are designed at their listed base sizes and scaled in the engine.

All major assets use the same visual material system:

Primary goo: saturated cyan-blue.

Shadow goo: deep blue-violet.

Core glow: bright cyan, approximately RGB (80, 255, 255).

Vein cracks: thin branching cyan channels.

Roughness: visually very low, glossy finish.

Highlights: large and rounded, never noisy.

Rock material: matte medium-dark grey with thin goo residue.

Do not rely on high transparency for the entire mesh. Keep the core body of each splash readable, using translucent edges and small interior highlights.

8.1 Required mesh assets

ID

	

Mesh name

	

Authored size

	

Shape and construction

	

Target triangles




K1

	

FX_SlamCrown

	

8 W × 4 H × 7 D

	

Thick irregular splash crown, 7–9 blunt rising arms, deep central impact bowl

	

650




K2

	

FX_CrackDisc

	

10 diameter × 0.14 H

	

Broken ground slab, 8–12 large fracture polygons, glowing goo recessed in cracks

	

450




K3

	

FX_DebrisSet

	

0.35–1.4 per chunk

	

Four reusable irregular rock variants with goo streaks

	

80–160 each




K4

	

FX_GooDrop

	

0.25–0.9

	

Three glossy rounded tear shapes with thick tips

	

60–100 each




K5

	

FX_BombBall

	

3 diameter

	

Wobbly sphere with large rounded lobes, emissive channels and attached short trail socket

	

550




K6

	

FX_BombSplat

	

10 W × 5 H × 10 D

	

Wide shallow impact crown plus three broad sideways goo sheets

	

900




K7

	

FX_StickyPuddle

	

10 × 0.25 × 10

	

Thick irregular puddle, six large embedded bubbles, raised outer lip

	

500




K8

	

FX_TsunamiWave

	

12 W × 10 H × 5 D

	

Giant curling wave, hollow-looking crest, massive thick body, no paper-thin sheets

	

1,600




K9

	

FX_WaveSplashWall

	

14 W × 11 H × 4 D

	

Vertical breaking splash with blunt spikes, foam lobes and large hanging sheets

	

1,100




K10

	

FX_FloodLane

	

12 W × 0.25 H × 30 L

	

Long irregular goo strip, raised edges, shallow undulating bumps

	

750




K11

	

FX_MeltPuddle

	

13 W × 0.22 H × 12 D

	

Wide collapsed Titan puddle, large bubble domes, cyan veins

	

500




K12

	

FX_MatterMote

	

0.62 diameter

	

Clean luminous sphere with subtle asymmetric lobe and soft halo

	

80

The wave uses 1.55× vertical scaling during J3 to reach 15.5 studs tall.

8.2 Additional functional meshes

Mesh

	

Size

	

Purpose




FX_SlamWedgeWarn

	

Radius 16, arc 120°

	

Ground telegraph




FX_SlamShockSector

	

Radius 16, arc 120°

	

Thick expanding shockwave




FX_BombWarnDisc

	

Diameter 10

	

Target circle




FX_TsunamiWarnLane

	

12 × 30

	

Danger rectangle




FX_TsunamiGatherWall

	

12 × 5.5 × 4

	

Goo gathering before release




FX_WhipRibbon

	

Width 0.55, variable length

	

Pre-slam movement streak




FX_BombTrailRibbon

	

Width 0.55–0.85

	

Authored, segmented ballistic trail




FX_TsunamiFoamCrest

	

12 × 1.6 × 2.0

	

Crest lobes and foam




FX_SwellShell

	

13.4 × 13.8 × 10.5

	

Temporary charging deformation




FX_ThroatBulge / cheek pair

	

As in §5.3

	

Bomb charge deformation




Defeat shell and melt heap

	

As in §7.3

	

Proper silhouette collapse

The core twelve K assets should be reusable. Additional functional meshes may have alternate low-detail variants, but should not be replaced by neon cylinders, spheres or flat procedural parts in the final release.

8.3 FX animation curves

Use normalized asset age u = 0..1.

S is relative scale, A is opacity (0 invisible, 1 opaque). Unless specified otherwise, interpolate values using a smooth cubic curve.

Effect

	

Lifetime

	

Scale keys (u:S)

	

Opacity keys (u:A)




K1 Slam crown

	

0.95 s

	

0:.55, .12:1.0, .38:1.12, .75:.90, 1:.72

	

0:0, .05:1, .40:1, .80:.35, 1:0




K2 Crack disc

	

To 3.80 absolute

	

0:.8, .08:1, 1:1

	

0:0, .08:1, .72:.8, 1:0




K3 Debris

	

0.85–1.10 s

	

0:1, .85:1, 1:.5

	

0:1, .75:1, 1:0




K4 Goo drops

	

0.40–0.75 s

	

0:.65, .25:1, .75:.9, 1:.25

	

0:1, .65:1, 1:0




K5 Bomb ball

	

2.55–3.40

	

0:1, .42:1.06, .70:.97, 1:1

	

0:1, 1:1, then despawn on impact




K6 Bomb splat

	

0.80 s

	

0:.40, .18:1, .50:1.10, 1:.70

	

0:0, .08:1, .65:.8, 1:0




K7 Sticky puddle

	

Until 5.55

	

0:.55, .20:1.0, 1:1

	

Hold 1 through gameplay lifetime




K8 Tsunami wave

	

2.10–3.20

	

Y scale 0:.65, .45:1.25, .75:1.55, 1:1.55

	

1 throughout travel




K9 Wave splash wall

	

0.90 s

	

0:.60, .18:1, .45:1.15, 1:.75

	

0:0, .10:1, .60:.85, 1:0




K10 Flood lane

	

From 3.28

	

Width scale 0:.70, .20:1.0, 1:1

	

Hold while hazard active




K11 Melt puddle

	

From 2.40

	

Width 0:.70, .80:1, 1:1

	

1 during defeat




K12 Matter mote

	

1.40 s

	

0:.2, .10:1, .75:1, 1:.65

	

0:0, .10:1, .80:1, 1:0

For K7 and K10, begin a 0.18–0.25-second fade after the authoritative slow hazard expires. Never make an active damaging or slowing area invisible.

8.4 Slam shockwave: exact mesh curve

Use a 120° authored sector ribbon, not a full circular ring.

Age after 1.64

	

Radius

	

Ring thickness

	

Height




0.00

	

4.0

	

1.8

	

0.25




0.08

	

7.0

	

1.6

	

0.55




0.18

	

11.5

	

1.4

	

0.80




0.32

	

15.0

	

1.0

	

0.50




0.42

	

16.0

	

0.65

	

0.15




0.55

	

16.0

	

0.45

	

0; invisible

The damage remains a single 1.64-second event. Ring expansion cannot deliver additional hits.

8.5 Debris trajectories

Use deterministic cosmetic paths rather than physical unanchored parts.

Parameter

	

Slam

	

Bomb

	

Tsunami




Primary chunks

	

6–8

	

4–6

	

8–10




Chunk size

	

0.35–1.2

	

0.30–0.85

	

0.45–1.4




Launch speed

	

7–13

	

5–11

	

8–16 studs/s




Initial upward speed

	

9–16

	

7–14

	

10–18 studs/s




Cosmetic gravity

	

28

	

28

	

28 studs/s²




Angular rotation

	

180–400

	

150–350

	

200–450 °/s




Lifetime

	

0.85

	

0.75

	

1.10 s

The trajectories should originate from real contact positions, not the Titan's root.

If two Titans produce overlapping effects, reduce secondary chunks first. Never reduce the main wave, bomb ball, impact crown, or ground telegraph as the first performance response.

9. Boss sound design — phone-speaker priority

The attack sounds must be built from mid-range transients plus sustained wet mass, not deep bass alone.

At phone-speaker volume, a sub-bass boom frequently disappears. The audible attack should still feel enormous through crunch, slap, liquid movement, and the length of the decay.

9.1 Audio conventions

The following gain values use Roblox Sound.Volume units from 0–1. They are starting mix values, assuming the licensed source assets have been normalized to comparable perceived loudness.

Pitch means PlaybackSpeed. Clip offset means the starting TimePosition within the source sound. Times are relative to the beginning of the cast.

9.2 J1 — Tentacle Slam sound layers

Cast time

	

Source asset

	

Gain

	

Pitch

	

Clip offset

	

Purpose




0.28

	

Bubbling gurgle

	

0.26

	

0.84

	

0.00

	

Internal pressure building




0.90

	

Giant monster roar, 2.9 s

	

0.36

	

0.90

	

0.05

	

Threat and anticipation




1.48

	

Giant boomy footstep

	

0.28

	

0.88

	

0.00

	

Pre-impact mass shift




1.56

	

Wet slap

	

0.44

	

1.12

	

0.00

	

Sharp tentacle whip




1.64

	

Huge mushy wet impact

	

0.82

	

0.94

	

0.00

	

Primary hit




1.64

	

Rock avalanche

	

0.38

	

1.04

	

0.08

	

Stone cracking




1.70

	

Giant splash

	

0.53

	

0.92

	

0.00

	

Huge goo crown




1.78

	

Earthquake debris rumble

	

0.22

	

1.00

	

0.50

	

Sustained aftershock




2.08

	

Wet heavy body fall

	

0.30

	

0.96

	

0.00

	

Body settling




2.65

	

Bubbling gurgle

	

0.15

	

0.90

	

0.00

	

Residual goo

The impact should have a recognizable acoustic envelope:

Time relative to hit

	

Perceived sound




0–0.06 s

	

Sharp wet slap and crunch




0.06–0.20 s

	

Huge mushy impact body




0.20–0.55 s

	

Splash and debris




0.55–1.40 s

	

Heavy rolling decay




1.40–2.10 s

	

Final diminishing goo sounds

Avoid an exaggerated bass tail extending beyond the visible attack.

9.3 J2 — Goo Bomb sound layers

Cast time

	

Source asset

	

Gain

	

Pitch

	

Clip offset

	

Purpose




0.40

	

Bubbling gurgle

	

0.28

	

0.80

	

0.00

	

Throat pressure




1.20

	

Giant monster roar, 2.9 s

	

0.23

	

0.84

	

0.10

	

Increasing strain




2.20

	

Bubbling gurgle

	

0.32

	

1.02

	

0.00

	

Goo ball swelling




2.52

	

Wet slap

	

0.40

	

1.08

	

0.00

	

Release snap




2.55

	

Water splash big dive

	

0.46

	

1.18

	

0.05

	

Projectile ejection




3.00

	

Bubbling gurgle

	

0.16

	

1.15

	

0.00

	

Wobbling projectile




3.40

	

Huge mushy wet impact

	

0.78

	

0.94

	

0.00

	

Bomb explosion




3.40

	

Giant splash

	

0.61

	

1.00

	

0.00

	

Wet splat crown




3.46

	

Rock avalanche

	

0.24

	

1.10

	

0.08

	

Ground cracking




3.75

	

Bubbling gurgle

	

0.19

	

0.92

	

0.00

	

Sticky puddle

The Goo Bomb should sound viscous and explosive, rather than metallic or electrical. The spit needs an obvious wet launch transient, but the actual ground impact must be substantially louder.

9.4 J3 — Goo Tsunami sound layers

This is the Titan's ORDER super move and should have the largest perceived sound of the three attacks.

Cast time

	

Source asset

	

Gain

	

Pitch

	

Clip offset

	

Purpose




0.00

	

Giant monster roar, 4.1 s

	

0.42

	

0.88

	

0.00

	

Major super-move call




0.45

	

Bubbling gurgle

	

0.32

	

0.77

	

0.00

	

Internal fluid buildup




1.20

	

Earthquake debris rumble

	

0.30

	

0.93

	

0.00

	

Goo gathering




1.75

	

Giant splash

	

0.28

	

0.85

	

0.12

	

Wall rising




2.10

	

Wet heavy body fall

	

0.58

	

0.94

	

0.00

	

Four-tentacle release




2.10

	

Huge mushy wet impact

	

0.48

	

0.90

	

0.00

	

Ground launch




2.30

	

Water splash big dive

	

0.45

	

0.91

	

0.00

	

Rolling surge




2.60

	

Rock avalanche

	

0.34

	

0.94

	

0.18

	

Rocks inside wave




3.20

	

Huge mushy wet impact

	

0.86

	

0.88

	

0.00

	

Terminal crash




3.20

	

Giant splash

	

0.73

	

0.90

	

0.00

	

Huge splash wall




3.24

	

Rock avalanche

	

0.52

	

1.04

	

0.00

	

Destructive debris




3.30

	

Earthquake debris rumble

	

0.32

	

1.04

	

0.80

	

Rolling aftermath




3.80

	

Bubbling gurgle

	

0.19

	

0.82

	

0.00

	

Goo flood

Audio hierarchy: Tsunami crash is the strongest event, Slam second, Goo Bomb third.

The Tsunami's secondary debris tail can be longer than the Slam's, but it must not mask the next player's input or the next important attack cue.

9.5 J4 — Hurt and Defeat audio

Sequence / time

	

Source asset

	

Gain

	

Pitch

	

Clip offset




Hurt 0.00

	

Wet slap

	

0.43

	

1.08

	

0.00




Hurt 0.10

	

Bubbling gurgle

	

0.24

	

0.92

	

0.00




Hurt 0.30

	

Wet heavy body fall

	

0.19

	

1.12

	

0.08




Defeat 0.00

	

Giant monster roar, 2.9 s

	

0.48

	

0.82

	

0.00




Defeat 0.40

	

Giant boomy footstep

	

0.32

	

0.78

	

0.00




Defeat 1.20

	

Wet heavy body fall

	

0.76

	

0.88

	

0.00




Defeat 1.20

	

Huge mushy wet impact

	

0.46

	

0.90

	

0.08




Defeat 1.80

	

Bubbling gurgle

	

0.34

	

0.75

	

0.00




Defeat 2.40

	

Giant splash

	

0.38

	

0.78

	

0.12




Defeat 3.20

	

Bubbling gurgle

	

0.18

	

1.04

	

0.00




Defeat 3.80

	

Wet slap, lightly processed

	

0.18

	

1.22

	

0.05

At 3.80, the motes should make a small, soft, rising liquid release. Do not use a triumphant explosion; the dramatic moment has already happened during the collapse.

9.6 Phone audio processing

Use an EqualizerSoundEffect or preprocess the licensed audio where permitted.

Band / parameter

	

Target




Below 100 Hz

	

Reduce substantially




160–350 Hz

	

Preserve body and weight




500–1,200 Hz

	

Strong audible wet impact




1,200–3,000 Hz

	

Preserve slap, crunch and attack definition




Above 7,000 Hz

	

Control harsh hiss




Transient emphasis

	

+2 to +3 dB around the main audible crack, if necessary




Dynamic compression

	

Approximately 2.5:1




Peak headroom

	

At least 2–3 dB below clipping after mixing




Sound preload

	

Required before attack playback

Prioritize perceived loudness, not just increasing every Sound.Volume value.

At the exact impact frame, limit each Titan to three high-priority sound layers plus one low-priority tail. If overlapping sounds exceed this, duck anticipation or rumble layers instead of the primary impact.

Use 3D spatial audio centred on the actual contact or impact location:

RollOffMinDistance: 10 studs.

RollOffMaxDistance: 85 studs.

Smooth distance attenuation.

No global non-spatial impact sounds.

Randomize pitch by no more than ±4% between repeated casts, preserving the distinctive sound identity of each attack.

Phone pass condition: At approximately 30% device volume, a listener must clearly distinguish Slam, Bomb and Tsunami by sound alone.

10. Performance budget — two Titans simultaneously

The test case is two fully visible Titans performing high-cost actions at the same time while other smaller units are active.

10.1 Hard client budgets

Resource

	

Target limit




Visible Titans

	

2




Shared particles

	

34 particles/s/client maximum




Boss particles

	

Up to 12/s per Titan




Reserved particles for other systems

	

Minimum 10/s




Active boss FX MeshParts

	

48 combined maximum




Active boss FX triangles

	

15,000 combined target




Boss audio voices

	

8 simultaneous, combined




Runtime-built FX geometry

	

None




Runtime cloning during combat

	

Avoid; prepool




Lights

	

0




Attack-specific camera shakes

	

0




Gameplay-critical FX culled by distance

	

Never while relevant to the player

The triangle and mesh limits above are proposed production budgets, not measured Roblox engine thresholds.

10.2 Budget allocation by attack

Attack

	

Peak FX triangles per Titan

	

Typical main mesh count

	

Small mesh count




Tentacle Slam

	

~5,000

	

5–7

	

6–8 debris




Goo Bomb

	

~2,800

	

3–5

	

4–6 debris




Goo Tsunami

	

~6,500

	

4–6

	

8–10 debris




Hurt

	

~900

	

1

	

4–6 droplets




Defeat, mote phase

	

~3,000

	

1–3

	

16 motes

These counts must be verified against the final Blender exports. Material slots, transparency overdraw, draw calls and actual mobile GPU performance matter as much as triangle counts.

10.3 Dynamic visual quality

Distance / situation

	

Treatment




Near, up to 45 studs

	

Full authored FX and eligible droplets




45–80 studs

	

Keep silhouette-critical meshes; halve small droplets




Beyond 80 studs

	

Keep gameplay telegraphs and major attack shapes; remove nonessential small debris




Two Titans overlapping

	

Preserve both impact geometries; reduce small droplets and debris first




Severe budget pressure

	

Prefer lower-detail FX mesh variants over deleting attack silhouettes

The visuals must still communicate the danger from a phone-sized screen.

10.4 Pooling rules

Preallocate representative peak demand:

2 Slam shock sectors.

4 Slam crowns.

4 crack discs.

2 bomb balls.

2 bomb splats.

2 sticky puddles.

2 wave meshes.

2 tsunami splash walls.

2 flood lanes.

20 debris mesh instances.

32 matter motes.

Reusable warning geometry for two simultaneous casts.

These are pool capacities, not permission to display everything concurrently. Apply the 48-active-MeshPart cap to live allocations, and allow the pool to contain more inactive assets.

On every reuse, reset:

Transparency, Size, CFrame, colour, scale state, trajectory parameters, event ID, owner ID, and any sound-related callbacks.

A superseded pooled effect cannot receive updates from its old cast.

11. Render and correctness requirements
11.1 Visual integration

The most common failure for this kind of attack redo is that individual effects look excellent in Blender but fail to integrate once animated.

Enforce the following:

Ground FX rests at Y approximately 0.03–0.12 above the visible floor as appropriate for thickness.

Main splashes emerge from the actual collision points.

Never draw a splash crown a significant distance away from the tentacle tip.

Projectiles leave the actual mouth attachment.

All warning shapes remain fixed after target lock.

A large wave must appear thick from the side, never like a flat sheet.

Cyan vein detail must survive bright highlights rather than becoming uniformly white.

The purple eye remains readable during normal attacks.

The front tentacles should never clip deeply through the head.

The shockwave should not obscure the whole boss at impact from common camera angles.

11.2 Timing and network correctness

The visual event scheduler must support frames which skip over one or more event timestamps.

For example, if a frame moves from cast time 1.60 to 1.70, it must fire the 1.64 event once.

Recommended event processing:

Lua
local function fireDueEvents(cast, previousTime, currentTime)
    for _, event in ipairs(cast.events) do
        if not event.fired
            and event.time > previousTime
            and event.time <= currentTime then
            event.fired = true
            event.callback(cast)
        end
    end
end

For cast reconstruction or clients joining partway through an attack, explicitly reconcile past events. Do not replay expired transient FX.

Use stable event IDs such as:

castId .. ":SlamDamage"

Authoritative damage is not permitted inside a local animation event callback. The client's corresponding event is cosmetic only.

11.3 Hit and animation agreement

Condition

	

Required behaviour




Server hit at 1.64

	

Slam tentacles reach contact on that frame




Bomb target moves

	

Bomb continues toward locked cast target




Server hit at 3.40

	

Bomb disappears into impact FX at that moment




Server hit at 3.20

	

Tsunami terminal crash occurs on that frame




Titan dies during wind-up

	

All future cast events and damage cancelled by server




Titan dies during projectile flight

	

Follow existing server projectile policy; do not invent a new one




Hurt during attack

	

Attack remains committed; hurt additive 0.35




Two Titans hit simultaneously

	

Independent event IDs and FX ownership




One Titan despawns

	

Its remaining owned cosmetic FX cleaned up as appropriate




Camera moves away and returns

	

Active FX reconstructed or correctly culled, no replayed bursts

12. Required still-check sheet

Claude should capture these screenshots in Roblox Play mode from the actual rebuilt geometry, not Blender mockups.

J1 — Tentacle Slam

Still

	

Time

	

Required observation




J1-S1

	

0.00

	

Clear aggressive idle silhouette and danger wedge




J1-S2

	

0.74

	

Both front tentacles visibly rearing, body leaning back




J1-S3

	

1.48

	

Both tentacles coiled above head, purple eye narrowed




J1-S4

	

1.64

	

Both front tips contact ground, no floating




J1-S5

	

1.82

	

Massive crowns and shock sector; body compressing




J1-S6

	

2.65

	

Recoil, crown receding, cracks still legible




J1-S7

	

3.40

	

Entire skeleton neutral




J1-S8

	

3.80

	

No remaining attack-specific FX

Also provide side and top-down contact screenshots at 1.64.

J2 — Goo Bomb

Still

	

Time

	

Required observation




J2-S1

	

0.00

	

Target circle visibly separate from Titan




J2-S2

	

2.20

	

3-stud goo bomb fully formed in open mouth




J2-S3

	

2.55

	

Projectile exiting the mouth, Titan snapping forward




J2-S4

	

3.00

	

Distinct projectile apex, visible trail




J2-S5

	

3.40

	

Ball replaced by full 10-wide impact crown




J2-S6

	

4.20

	

Sticky puddle with bubbles, smaller enemy partially stuck




J2-S7

	

5.55

	

Gameplay slow ends and cosmetic fade begins

Capture a side view showing the complete projectile arc, plus a top-down view demonstrating the 5-stud impact radius.

J3 — Goo Tsunami

Still

	

Time

	

Required observation




J3-S1

	

0.00

	

Clearly readable 12 × 30 warning lane




J3-S2

	

1.20

	

Goo gathering, Titan visibly swelling




J3-S3

	

1.75

	

Large raised wall, four tentacles overhead




J3-S4

	

2.10

	

All four tips hit ground, wave released




J3-S5

	

2.60

	

Thick 15.5-high rolling wave with readable curl




J3-S6

	

3.20

	

Major crash, enormous splash wall, displaced enemies




J3-S7

	

3.50

	

Long glowing flooded lane and visible debris




J3-S8

	

5.00

	

Titan neutral, aftermath pose complete

Capture S5 from the side to prove the wave's height and physical thickness, and S6 from above to establish lane alignment.

J4 — Hurt and Defeat

Still

	

Time

	

Required observation




J4-H1

	

0.10

	

Right-side dent, shut eye, sprayed goo




J4-H2

	

0.30

	

Rebound overshoot, angry eye, flailing tentacles




J4-H3

	

0.52

	

Complete neutral recovery




J4-D1

	

0.40

	

Eye wide and dizzy, dramatic backward stagger




J4-D2

	

1.20

	

Dome caved, horns drooping, tentacles grounded




J4-D3

	

2.40

	

Body almost melted, recognizable sinking eye




J4-D4

	

3.20

	

Only puddle remains, no floating skeletal parts




J4-D5

	

3.80

	

Sixteen visible glowing motes, count independently




J4-D6

	

4.50

	

Motes rising, no extra objects resembling matter

For the matter release, count 16, not approximately 16. It must also be obvious that they rise from the puddle itself.

K — FX asset stills

One neutral-background isolation image of all twelve assets, arranged as a 4 × 3 grid with labels and size callouts.

Additionally:

K8 wave side profile and front profile, with measurement reference.

K9 splash wall side profile, proving it has thickness.

K10 flood lane overhead, showing 12 × 30 proportions.

K1 and K6 alongside each other, proving the Slam crown and Bomb splat have different silhouettes.

13. Acceptance tests and merge gates

Test

	

Pass threshold




Slam damage timestamp

	

Exactly 1.64 server seconds




Slam warning

	

0.74 seconds




Slam front tip contacts

	

≤0.25 studs from targets




Slam wedge

	

120°, radius 16




Bomb spit

	

Exactly 2.55 seconds




Bomb impact

	

Exactly 3.40 seconds




Bomb target

	

Within existing 16-stud cast limit




Bomb hit radius

	

5 studs




Bomb slow lifetime

	

Through 5.55 seconds




Tsunami release

	

Exactly 2.10 seconds




Tsunami terminal hit

	

Exactly 3.20 seconds




Tsunami rear tip contacts

	

≤0.35 studs from targets




Tsunami warning footprint

	

12 × 30 studs




Hurt additive weight

	

0.35 committed, 1.00 otherwise




Hurt duration

	

0.52 seconds




Defeat terminal pose

	

3.80 seconds




Matter motes

	

16 exactly




Client particle budget

	

≤34/s, shared




Lights / camera shakes

	

Zero added




Two Titans simultaneously

	

No missing principal effects or sound impacts




Floating or detached FX

	

None visible at Play camera distance




Runtime warnings/errors

	

Zero




Server damage double-fires

	

Zero

Required regression scenarios

One Titan versus one small unit, one Brute, and a clustered group.

Two Titans simultaneously casting Tentacle Slam.

One Titan casting Goo Bomb while another casts Tsunami.

Two Tsunamis overlapping without borrowing one another's pooled effects.

Titan killed at 0.50 into Slam, 2.30 into Bomb, and 1.90 into Tsunami.

Hurt applied at maximum wind-up and contact on all three moves.

Titan defeated while another Titan's large impact FX is active.

Titan rotated 90° and 180° before casting, verifying all contacts and damage regions transform correctly.

Bomb aimed at the minimum practical range and at 16 studs.

Phone test with both Titans and a full complement of smaller units, including sound playback.

14. Implementation order

Build and approve in this order:

Gate

	

Work

	

Required proof




G1

	

Correct bone signs, contact solver, animation interpolation

	

Debug views and ≤0.25-stud front contact




G2

	

J1 Slam skeleton and primary FX

	

J1 still sheet plus server hit timestamp




G3

	

J2 Bomb, aimed projectile and puddle

	

Full arc, locked target and 5.55 expiry




G4

	

J3 Tsunami and four-tip correction

	

Height, lane alignment and 3.20 timing




G5

	

J4 Hurt and Defeat

	

Full collapse and sixteen motes




G6

	

K authored FX polish

	

All twelve isolated meshes




G7

	

Layered sound pass

	

Phone recording at 30% volume




G8

	

Two-Titan budget and regression

	

Profiler measurements and clean console

Don't spend time polishing tiny droplets before the large skeleton and major FX shapes read correctly. They contribute very little to the perceived weight compared with contact, squash, splash mass and audio.

15. Final engineering verdict

BUILD-READY WITH THREE VALIDATION GATES

The spec preserves the supplied gameplay contract and defines concrete implementation targets. Three things must be established from the real assets before final approval:

Terminal tip offsets and local bone axes. The measured origins in the brief are insufficient to guarantee contact with the ground. Validate the signed transforms, reach and world-space tip correction.

Facial and defeat deformation. Confirm that the existing skinning can support bulging, collapse and the sinking eye, or implement the authored proxy geometries described above.

Tsunami visual travel versus fixed hit timing. Verify that enemies appearing to be passed by the wave before 3.20 does not undermine combat readability. Do not change server damage timing as a purely visual fix.

The main artistic requirement is straightforward: Slam should feel like a giant creature smashing the ground, Bomb like a massive liquid projectile, and Tsunami like an entire wall of glowing matter destroying everything in its path.

The Titan's attacks must feel heavy even when all incidental particles are turned off. If that test fails, the problem is in the key poses, primary meshes or sound design—not the quantity of effects.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High