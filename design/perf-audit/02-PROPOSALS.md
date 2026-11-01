# Alien Fusion performance proposals (draft 1, 29 Oct 2026, Claude; NOT built)

Evidence: `01-MEASURED-FINDINGS.md`. Ranked by MEASURED win first. Rule for all of them: the simplest change that
removes the measured cost; no new framework, no abstraction layer, no premature Parallel Luau. Each is verified by the
same Studio timers (and the phone test) before the next.

## P1. Stop rewriting the glow every frame (biggest single win, measured)
What: every unit writes `SurfaceAppearance.EmissiveStrength` almost every frame (the idle pulse + attack glows, written
whenever it moves by > 0.01). 64 units standing: 55 fps with it, 113 without; first seconds of a fight: 46 -> 89 fps.
Change: keep EmissiveStrength CONSTANT per form (its base glow). Only change it for an attack's own big glow beats,
quantised to a few steps (e.g. 0 / 0.5 / 1 extra), written only when the step changes (a few writes per attack, not per
frame). Drop the idle pulse on the material; if a living shimmer is still wanted, the aura particles already give it.
Files: AlienAnimator (3 places: aiWalk, runAttack, the MOVE TEST loop).
Risk: the idle pulse is gone (visual). James to judge on the phone.

## P2. Animation level of detail (LOD) by distance and visibility
What: every unit is fully animated every frame (1,150-1,840 bone writes / frame) wherever it is.
Change (simple tiers, per unit, decided once per frame from the camera):
- close and on screen (< 60 studs): every frame, as now;
- far (60-150 studs) or small on screen: bones every 2nd frame (3rd beyond 150); the model still moves every frame
  (no stutter in position);
- off screen: no bone / IK / glow updates at all, position only; when it comes back on screen the pose handoff
  (already built) eases it in.
Expected: on a phone at a normal camera only a fraction of 64 units are close: bone writes drop by roughly half or
more. Measure with `AnimBoneWrites`.

## P3. Write each bone once per frame, and only when it changed
What: `apply()` recomputes `rest:Inverse()` for every bone every call and writes every bone, identity included; during
an attack the bones are written 2-3 times per frame (idle pose, then attack pose, then the blend-in loop), which is why
a fight writes ~1,800 bones per frame vs ~1,150 standing.
Change: cache `rest`, `rest:Inverse()` per bone at setup; build the final pose in one pass (idle -> attack blend ->
hurt -> legs) into the unit's own pose buffer, then write each bone ONCE; skip the write when the new Transform equals
the last written one (bones not driven this frame stay as they are).
Expected: bone writes about -40 % in fights, script ms down (measure).

## P4. Stop allocating per frame in the pose pipeline
What: `newPose()` (a table + a closure + a 6-number table per bone, several times per unit per frame), `Attacks.pose`
(`lerp6` table per bone per frame), the `held` table of every bone per frame in attacks, local `at()` closures per unit
per frame. Garbage-collector pressure shows up as frame spikes on phones.
Change: one reusable pose buffer per unit (preallocated per-bone number arrays, cleared not rebuilt); `Attacks.pose`
writes into a passed-in buffer; `at()` becomes a function taking the base as an argument (no closure). Same maths,
same results (compare a frame of bone Transforms before / after in a test).

## P5. Make the moving parts cheap for the physics engine
What: every unit's Hitbox has CanCollide + CanQuery + CanTouch ON and is moved every frame; SquishF1v5's visible mesh
too; several visible meshes keep PreciseConvexDecomposition collision geometry; every alien casts a shadow.
Change: visible MeshPart: CanCollide / CanQuery / CanTouch off, CollisionFidelity Box (it never collides); Hitbox:
CanCollide / CanTouch off, CanQuery only if click-select needs it (it does not in the AI test), CastShadow off;
CastShadow off on the small forms (F1 / F2), keep it on F3 / F4 (they read better grounded). Template change, no code.

## P6. Smaller network messages
What: 64 unit states x 6 doubles (incl. the same timestamp per unit) 9.4 times a second + events, estimated ~40 KB/s
per player.
Change: one timestamp per message; pack states into a `buffer`: id u16, x / z as i16 fixed-point (1 cm; or f32), facing
u16, speed u8 = ~9 bytes a unit (~0.6 KB a message, ~6 KB/s); send states on an UnreliableRemoteEvent (only the latest
matters; the client already interpolates and coasts), keep attack / cancel / shield events on the reliable one.
Only units that changed beyond a small threshold need sending (optional second step).

## P7. Effects: fewer live instances
What: up to ~1,200 effect instances alive at once, events creating instances at 0.5-0.8 ms / frame; the 34
particles/s budget already sits at its cap.
Change: (a) pool the most-made pieces (debris chunks, droplets, rings, dust puffs) instead of Instance.new / Destroy;
(b) effect detail by distance: beyond ~80 studs an attack plays its main mesh pieces only (no droplets / debris /
small particles); (c) a hard per-client cap on live debris pieces (oldest fade first). Gameplay-critical pieces
(warnings, beams, projectiles, shields) are never culled.

## P8. Small cleanups in the hot path
- Ground raycast per unit per frame (~0.6 ms): reuse the last height while the unit moved < 0.5 studs.
- Hot `GetAttribute` reads (FormName, AiId, FreezeTT, MoveTest, AimTest, AiAimX / Z) per unit per frame: read once into
  the unit's state when they change (attributes changed signal) or at setup.
- RenderStepped -> PreRender for the animation loop if the research confirms it (RenderStepped blocks the frame).

## P9. Code hygiene (robustness, not speed)
- ONE source of truth: fold `src-aitest` back into `src` (the AI test's animator / Crunch / Drip are now ahead of
  the main place's copies); the AI test place and the game use the same files.
- Strip test scaffolding from runtime code behind one `DEBUG` flag: the test hooks (force / ghost / arm / preshield /
  kill / dodge / flag), the readout attributes (AiFx / AiDetIds / FxParticles every 15 frames, FeetResets, ShakeOffs,
  Anim*), the Dbg switches, the profiler wrappers.
- Split the 181 KB `Attacks` module per creature (like AttacksCrunch / AttacksDrip already are); shared helpers in one
  small module.
- Comments: keep the WHY; move the long audit-history notes ("(29 Oct, audit r3: ...)") into BUILD-LOG.
- Server (cheap today: 2.7 ms of 50): build foes / friends lists once per tick per team instead of per unit (O(n^2)
  allocations), only if it ever shows in a profile.

## Research cross-check (Deep Research came back "0 citations, 0 searches" = from memory: verified by hand)
- CONFIRMED: changing `EmissiveStrength` per object breaks render batching (separate draw calls; DevForum report
  https://devforum.roblox.com/t/is-changing-emissive-strength-of-a-surface-appearance-meant-to-be-an-individual-draw-call/4778407 ;
  the reporter's fix = a few SHARED values). Matches P1's measurement (55 -> 113 fps).
- CONFIRMED: UnreliableRemoteEvent drops payloads over 900-1000 bytes (Creator Docs). P6's packed message (~0.6 KB for
  64 units) fits; today's table format (~4 KB) would not, so P6 must pack BEFORE switching to unreliable.
- CONFIRMED: PreRender is the modern counterpart of RenderStepped (no deprecation in force); a tidy-up, not a speed win.
- TESTED AND REJECTED: "add a dummy Humanoid to each skinned model to stop FastCluster rebuilds" (staff:
  https://devforum.roblox.com/t/updateinvalidatedfastclusters-causing-slowdowns/4528467): 4 runs of the same fight,
  with vs without a Humanoid on every unit: no difference beyond noise (52-66 vs 46-68 fps mid-fight).
- NOT APPLICABLE: SLIM avatars / ClientAnimatorThrottling (they act on Animator / avatar pipelines; our bones are
  driven by script).
- Assets (measured in Studio): triangles per form 3,000 (Drip) - 14,000 (Titan); textures 512 px (F1) / 1024 px (F2-F4),
  4 maps each; all cast shadows; SquishF1v5's visible mesh and every Hitbox have collision on (see P5).

## Not proposed (on purpose)
- Parallel Luau / Actors for animation: real complexity (bone writes are not allowed in parallel), only worth it if
  P1-P4 still leave the phone short.
- Rewriting the attack modules: their per-frame cost is 1.3-2.1 ms; P7 covers the instance side.
- Impostors / billboard units: overkill at 64 units with P2.

## Order of work (each measured before the next)
P1 -> P5 -> P2 -> P3 + P4 -> P8 -> P6 -> P7 -> P9, then the phone test (64 units, 3 minutes).
