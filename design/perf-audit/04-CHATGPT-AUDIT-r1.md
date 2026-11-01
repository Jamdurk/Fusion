New topic, same game: a PERFORMANCE audit (nothing built yet). Attached: 01-MEASURED-FINDINGS.md (what I measured in Studio with timers and on/off switches at 64 units: the per-frame SurfaceAppearance.EmissiveStrength glow write halves the frame rate, bone/model writes, attack posing 7-9 ms per frame, ~40 KB/s network estimate, assets) and 02-PROPOSALS.md (P1-P9 ranked by measured win, plus a research cross-check: a Deep Research report came back with 0 searches, so I verified its key claims by hand and tested its dummy-Humanoid tip, which made no difference). Please audit the proposals as a hard-nosed senior Roblox performance engineer, and use web search to back or refute anything with sources: what is wrong, what is missing, what is over-engineered (James explicitly does not want over-engineered AI slop), and what order you would do them in. Verdict per proposal (KEEP / CHANGE / DROP) with exact changes, and anything I should measure before committing.
Worked for 3m 16s
ChatGPT said:
Alien Fusion — Performance Engineering Audit
SOUND WITH CHANGES

The proposals are headed in the right direction, but I would change the priority order and remove some unnecessary complexity before building.

The strongest part of this work is the measurement. You've isolated a major rendering bottleneck rather than guessing that 64 AI agents are inherently expensive.

The weakest parts are the unproven animation LOD thresholds, combining several major pose-pipeline changes, and proposing network serialization and effect pooling before establishing that either is necessary.

My engineering decision:

P1 is an immediate GO. It has by far the strongest evidence.

P3 is the next significant CPU optimization, particularly eliminating redundant bone writes.

P5 is worthwhile low-risk cleanup, provided combat queries remain correct.

P2 and P4 need smaller, staged implementations.

P6 and P7 should be conditional, not automatic work.

P9's source consolidation is more urgent than its module splitting.

I agree with rejecting Parallel Luau, dummy Humanoids, impostors, and an AI rewrite at this stage.

1. What the measurements actually prove

64 units standing — Studio PC, reported measurements

0
40
80
120
160
Normal
Glow writes off
Bone writes off
Model moves off
Raycasts off
Bones + moves + glow off
Normal: FPS 53.5
Glow writes off: FPS 113
Bone writes off: FPS 56
Model moves off: FPS 56
Raycasts off: FPS 56
Bones + moves + glow off: FPS 144

Higher FPS is better. Tests remove different workloads and are not additive.

Midpoints of the supplied ranges. The 144 FPS result is capped, not an uncapped performance measurement.

The glow test is decisive: standing performance rises from approximately 54 to 113 FPS, while measured animator script time barely changes.

That is strong evidence of an engine-side rendering or property-update cost, not primarily a Lua computation problem.

Roblox's rendering documentation confirms that material compatibility affects mesh instancing and draw calls. It does not, by itself, prove that every EmissiveStrength write creates exactly one additional draw call. The supplied DevForum discussion is supporting evidence, but the precise mechanism still warrants a Render Stats or MicroProfiler comparison. 
Documentation - Roblox Creator Hub
+1

Equally important: disabling bone writes only raises standing performance from approximately 54 to 56 FPS. That does not mean bone writes are free. It means they aren't the limiting factor in that particular glow-heavy test. After fixing P1, the bottleneck may shift.

The proposal's 7–9 ms of remaining mid-fight work is also not purely attack posing: it includes walking and other unseparated work. You should profile that residual before assuming pose allocation is responsible for most of it.

Do not add the individual FPS improvements together, or promise a doubling of frame rate on phones from the PC result. Roblox explicitly warns that Studio performance differs from client performance and that device characteristics materially change the bottleneck. 
Documentation - Roblox Creator Hub
+1

2. Proposal-by-proposal verdicts

Proposal

	

Verdict

	

Priority




P1 — Stop per-frame glow writes

	

KEEP

	

1




P2 — Animation LOD

	

CHANGE

	

Conditional




P3 — Reduce bone writes

	

CHANGE

	

3




P4 — Reduce allocations

	

CHANGE

	

Conditional




P5 — Physics/shadow cleanup

	

KEEP

	

2




P6 — Pack network messages

	

CHANGE

	

Conditional




P7 — Pool/cull effects

	

CHANGE

	

Conditional




P8 — Small hot-path cleanups

	

CHANGE

	

Selective




P9 — Code hygiene

	

CHANGE

	

Split into separate tasks

P1 — Glow writes: KEEP
BUILD FIRST

The proposed fix is largely correct. Eliminate the idle material pulse and stop writing EmissiveStrength during normal movement.

I would change one detail: don't assume quantizing the attack glow to three values automatically preserves batching.

Exact implementation:

Set each creature's base glow once when its model is initialized.

Remove the per-frame glow writes from aiWalk, runAttack, and the MOVE TEST loop.

Preserve essential attack signalling through existing effects.

First benchmark completely static emissive strength.

Only then test event-driven attack boosts with three discrete levels, writing on state transitions and restoring the base value afterward.

Do not introduce a material manager, new shader-like system, or separate glow rig.

Acceptance: Measure standing and fighting FPS, draw calls, frame time, and number of property writes for three variants: original, static glow, and static-plus-attack-beats.

If the last variant loses a substantial amount of the recovered performance, use static glow. James should judge whether the visual difference matters, but performance must be quantified first.

P2 — Animation LOD: CHANGE

This is a potentially good optimization, but its current thresholds are invented rather than derived from the game's camera.

The 60/150-stud thresholds have no measured relationship to the phone's actual screen-space creature size.

Also, every second frame is not a fixed animation rate. On a 30 FPS phone, that becomes 15 FPS animation. Every third frame becomes 10 FPS, which may look terrible for fast Drips and flying Twins.

Simpler version:

Keep near and prominent creatures at full animation rate.

Run distant, small-on-screen bodies at a target of roughly 20–30 Hz, only if the phone comparison demonstrates a win.

For genuinely off-screen units, skip pose and IK work, but continue advancing attack clocks, processing attack events, and maintaining world-effect lifetimes.

Determine visibility using a padded projected bounding area, not just the creature's centre. Roblox's WorldToViewportPoint() is suitable for a simple visibility test, but its on-screen result does not establish whether terrain or another object obscures the creature. 
Documentation - Roblox Creator Hub

Use a modest screen margin so a Titan's limbs do not freeze as the body crosses the edge. On returning to full detail, evaluate the current pose directly and use the existing handoff if necessary. Never replay skipped frames or skip combat-critical event processing.

Before building: Record the number of visible units and approximate projected sizes during normal phone gameplay. If most of the 64 units are visible and sizeable, P2 may deliver much less than expected.

Do not build a multi-level LOD scheduler yet. One full-rate/low-rate decision is enough for the first experiment.

P3 — Bone writes: CHANGE

This is the best next CPU candidate, but the proposal combines three optimizations of different risk levels.

Stage A — Immediate, low risk

Cache rest:Inverse() per bone when the rig is initialized. Eliminate redundant recalculation. Only invalidate the cache if the rest transform genuinely changes.

This is unambiguously sensible.

Stage B — Reduce redundant writes

The current idle → attack → blend pipeline writes some bones two or three times.

Aim for one final Bone.Transform assignment per bone per rendered pose.

But be careful: the attack code performs contact and reach corrections using live world-space bone positions. If those corrections depend on an intermediate engine-applied pose, blindly merging all writes into one pass can change contact geometry.

Required: Identify which intermediate bone writes are actually read by those correction functions. Consolidate the others first. Do not replace working engine-based contact calculations with a custom skeletal forward-kinematics system just to achieve a perfect single pass.

Stage C — Skip unchanged transforms

Do this only if Stage B leaves measurable unnecessary writes.

Comparing calculated transforms costs CPU too. Exact floating-point equality may rarely succeed while characters are moving, and a last-written transform from a previous attack must not become a permanently stuck pose.

Use a small numerical tolerance only if testing shows it to be worthwhile, and always restore the intended neutral pose when an animation ends.

Roblox documents Bone.Transform as the local animated offset, with world transforms depending on the bone hierarchy. That is precisely why contact-correction regression testing matters. 
Documentation - Roblox Creator Hub

Acceptance: Preserve contact-point accuracy, foot placement, animation interruption rules, and attack timing. Measure actual bone-write count and total frame time. Do not claim success based solely on fewer writes.

P4 — Pose allocations: CHANGE

The allocation findings are credible: repeatedly constructing nested pose tables, closures, and arrays for up to 64 units is unnecessary work.

But rewriting newPose, Attacks.pose, held, and the closure system simultaneously is too much change before you've shown GC pauses are important.

My smaller implementation:

Start with only newPose() and lerp6().

Reuse a per-unit pose buffer, clearing or overwriting all fields that a particular pose can consume. Make Attacks.pose() write into that buffer rather than generating a fresh table for every bone.

Measure again.

Only tackle held and at() if the remaining allocation profile justifies it.

Be especially careful with the attack-instance system you just finished auditing: an active attack's pose data must not share a mutable buffer with a detached effect instance that still reads it. Use reusable scratch storage for transient calculations, not for independent instance ownership.

Acceptance: Lower allocated bytes/second, fewer GC-related frame spikes, and unchanged bone transforms and effect behaviour.

Do not assume this produces a large FPS gain. The attachments identify allocations, but provide no allocation-rate or GC-pause measurement yet.

P5 — Physics and shadow cleanup: KEEP

This is worthwhile, cheap, and straightforward.

Roblox explicitly states that disabling collisions and touch events can reduce physics work, and that simplified collision fidelity is appropriate for non-interactive objects. The rendering guidance also recommends selectively disabling unnecessary shadows on small objects. 
Documentation - Roblox Creator Hub
+2

Exact changes:

Object

	

Change




Visible skinned MeshPart

	

CanCollide=false, CanTouch=false




Visible MeshPart queries

	

CanQuery=false only if nothing queries it




Collision fidelity

	

Box for non-interactive visual geometry




Client hitbox

	

Disable collisions and touch; disable queries if genuinely unused




F1/F2 shadows

	

Disable




F3/F4 shadows

	

Keep initially

My one objection: don't equate CanQuery with click-selection alone. It also controls whether spatial queries such as Raycast and GetPartBoundsInBox see the part.

Audit targeting, ground/contact rays, selection, and any collision-query code before disabling it.

For the test place, a pure client-rendered hitbox probably doesn't need to participate in physics. Prove that with a few attack and selection tests.

Do not rebuild collision geometry dynamically.

Measure: Compare physics step time, rendering/shadow time, and FPS. If the FPS improvement is within noise, keep the safe configuration cleanup anyway.

P6 — Network packing: CHANGE

Defer until actual bandwidth is measured.

The current 40 KB/s per-player number is an estimate, not a measurement.

Roblox doesn't necessarily transmit six Lua numbers and every table overhead byte in the simple form assumed. It applies serialization and compression, and Roblox's documentation explicitly notes that buffers may be compressed. 
Documentation - Roblox Creator Hub

There is also a concrete mistake in the proposed coordinate encoding.

Signed 16-bit coordinates at 0.01 studs per unit only cover approximately ±327.67 studs around the chosen origin. That may not cover the game's full coordinate range.

If you implement packing, choose the origin and resolution from actual reachable world bounds. For example, a 0.02-stud scale covers approximately ±655.34 studs per signed coordinate. Include a range assertion rather than silently wrapping a value.

Also verify that every id fits u16 and every quantized speed fits u8.

For now I recommend only:

P6a: Put the repeated timestamp once per snapshot. Keep the current reliable transport. Measure real incoming/outgoing bandwidth in a standalone client.

P6b, only if warranted: Implement the packed buffer.

At the proposed nine bytes per unit, 64 states occupy 576 bytes plus headers. That is a plausible size under the documented 1,000-byte UnreliableRemoteEvent limit, but confirm encoded message size in Studio. 
Documentation - Roblox Creator Hub

If switching to unreliable delivery, include a snapshot sequence number and discard older snapshots. Keep spawn/despawn and attack/cancel/shield events reliable. Roblox explicitly warns that unreliable and reliable remotes have no shared ordering guarantee. 
Documentation - Roblox Creator Hub

DROP the optional changed-units-only delta scheme for now. With packet loss, it requires refresh or resynchronization logic. Full snapshots are simpler and well suited to 64 units.

There is no justification yet for building that machinery.

P7 — Effects optimization: CHANGE

Your 1,200-live-effect measurement is a warning, but pooling is not automatically the solution.

Pooling can reduce allocation cost, but it also introduces ownership, reset, and stale-state bugs—particularly dangerous after the work you've just completed on released effects and detached attack instances.

I'd reverse the proposed order:

First reduce nonessential distant effects.

Then cap decorative debris, never telegraphs or released gameplay effects.

Only pool a specific effect type if profiling shows its creation/destruction is expensive.

At a distance, dropping tiny droplets or pebbles is sensible. Removing a warning outline, Sun beam, shield, or projectile is not.

Also distinguish FX controller records from actual Roblox Instance objects. The measurement says 1,200 effect instances; before optimizing, establish how many Parts, MeshParts, ParticleEmitters, Beams, Sounds, and Lua records those represent.

Your attack event creation time of 0.5–0.8 ms per frame isn't large enough by itself to justify a general pooling system.

Pooling verdict: DROP as a default. Bring it back only for a demonstrated high-frequency allocator.

Roblox's performance guide specifically identifies dense rendering, particles, transparency, and shadow work as costs worth investigating. 
Documentation - Roblox Creator Hub

P8 — Hot-path cleanups: CHANGE

There are three ideas here, and they deserve separate decisions.

Change

	

Decision

	

Exact adjustment




Cache ground raycasts

	

Conditional

	

Cache per foot/contact position, not only root movement




Cache attributes

	

Selective KEEP

	

Cache immutable rig information at setup; dynamic fields only where measured useful




RenderStepped → PreRender

	

KEEP as housekeeping

	

No expected FPS improvement

Raycasts: The proposed 0.5-stud movement threshold can be wrong when a foot moves across a step or slope while the creature's root barely moves. Use the foot's actual ground-sample position, invalidate on teleport/landing, and preserve corrections when terrain height changes. If this becomes more complicated than the current raycasts, leave them alone.

Attributes: Cache FormName and AiId at setup. For runtime-changing values such as aim and freeze state, don't automatically create dozens of change-signal connections. A few attribute reads may be cheaper and considerably simpler. Test the difference.

PreRender: Verified. Roblox documents PreRender as the successor to RenderStepped and confirms that rendering waits for its callbacks to finish. Changing the name does not move expensive work off the rendering path. 
Documentation - Roblox Creator Hub

No elaborate event-cache infrastructure.

P9 — Code hygiene: CHANGE

This proposal mixes essential engineering hygiene with cosmetic refactoring.

Do immediately: Make src and src-aitest derive their shared production modules from one canonical source. The testing place can have its own harness and overrides, but it must not silently maintain an older copy of the animator or attack code.

Do after benchmarking: Remove test hooks from production execution paths, keeping the instrumented test harness available for regression runs. A build-time debug constant is adequate; you don't need a debugging framework.

Do only if maintainability demands it: Split the 181 KB Attacks module into creature modules.

File size alone is not evidence of an ongoing frame-time problem. Splitting it now risks disturbing the attack system for no measured gain. Since Crunch and Drip are already separated, use that pattern when new creature work actually benefits from it.

Moving obsolete audit notes into a build log is fine, but low priority.

Do not optimize the server's friend/foe lists now. A 2.7 ms average 20 Hz step does not justify changing server architecture when the current bottleneck is client rendering.

3. Research cross-check: confirmed, conditional, or rejected

Claim in proposals

	

Audit




Changing emissive properties harms batching

	

Plausible and supported by your A/B result. Exact draw-call mechanism needs Render Stats confirmation




Unreliable remotes reject over 1,000 bytes

	

Confirmed by Creator documentation




PreRender replaces RenderStepped

	

Confirmed, not a speed optimization




Add Humanoids for FastClusters

	

Not justified here; your own four-run test found no clear benefit




SLIM/avatar animation throttling solves custom procedural animation

	

Not demonstrated for this renderer




Parallel Luau is needed

	

No; no evidence of a remaining parallelizable bottleneck requiring that complexity

One interesting nuance: current Roblox documentation explicitly discusses Humanoids as a workaround for moving skinned MeshPart FastCluster rebuilding. That is real advice, not an invented recommendation. But the documentation also says to profile its effect, and your test did exactly that without finding a benefit. Don't add Humanoids. 
Documentation - Roblox Creator Hub
+1

I could not independently inspect the content of the specific EmissiveStrength DevForum thread because the page blocked direct retrieval. The Roblox rendering documentation and your measured results are sufficient to justify P1, but not to certify the thread's precise explanation.

4. My preferred implementation order

I would not use the original P1 → P5 → P2 → P3+P4 → P8 → P6 → P7 → P9.

Use this instead:

P9a — Consolidate shared source

Ensure the performance work is applied to the actual game and test place, without a large refactor.

P1 — Remove per-frame emissive writes

Implement, benchmark, check visual readability, and lock the result.

P5 — Disable unnecessary collision, query and shadow work

Straightforward template edits with combat-query regression tests.

Measure on a real phone now

Identify whether the remaining bottleneck is script execution, rendering, skinning, or effects. Do not wait until P9.

P3a — Cache rest inverses; reduce redundant bone writes

Start with small local changes. Only consolidate the complete pose pipeline if there is a measured CPU gain worth the risk.

Choose one of P2 / P4 / P7 based on the new profile

P2 if distant animation costs dominate; P4 if allocations and GC dominate; P7 if effects and rendering dominate. Don't automatically build all three.

P8, P6, P9b — Conditional finishing work

Apply only the remaining demonstrated improvements. Retain the test harness and regression probes.

This sequence deliberately moves the phone test earlier and separates the easy, proven wins from speculative optimizations.

5. Measurements I would require before committing further work

The next benchmark should answer these questions, not just produce another FPS number.

Measurement

	

Why




Average and p95 frame time, FPS

	

Distinguish throughput improvements from stuttering




Render draw calls with glow on/off

	

Establish whether batching explains P1




CPU vs GPU frame cost

	

Identify the post-P1 bottleneck




Animation pose, contact corrections and IK separately

	

Determine what really accounts for the 7–9 ms residual




Bone Transform writes per frame

	

Quantify P3's actual reduction




Allocated KB/s and GC pause time

	

Establish whether P4 is needed




Number and types of live effect objects

	

Establish whether P7 is needed




Actual client bandwidth and packet loss

	

Establish whether P6 is needed




Visible-unit count and projected size distribution

	

Choose P2's thresholds from real camera use




Mobile memory after repeated 64-unit fights

	

Catch sustained resource growth

Keep the benchmark reproducible: same camera, graphics settings, unit composition, action seed where practical, and test duration. Run repeated A/B comparisons rather than relying on a single fight where the number of living units changes rapidly.

For the mobile test, run one midrange Android and one iPhone for three minutes with 64 units replenished as necessary. Report thermal degradation, frame pacing, and memory. Roblox specifically recommends a baseline low-end device and real-client testing for performance decisions. 
Documentation - Roblox Creator Hub
+1

6. What I would explicitly NOT build

No parallel animation Actors, ECS rewrite, custom skeletal renderer, general-purpose animation job scheduler, automatic network delta framework, universal FX pool, dynamic material manager, or server AI optimization pass.

None is justified by the measured evidence.

Your existing server takes roughly 2.7 ms per 50 ms simulation tick on average, while changing one client material property path nearly doubles standing FPS on the desktop.

That's where the engineering attention belongs.

Final engineering verdict

Performance proposal set

SOUND WITH CHANGES

Approved to build: P1, the safe parts of P5, caching rest inverses in P3, and source consolidation in P9.

Conditionally approved: P2, the rest of P3, P4, P6, P7, P8.

Rejected for now: General FX pooling, delta networking, splitting the attack module solely for speed, and extra parallelization/framework work.

The best first optimization is not a rewrite. It is removing a handful of unnecessary material property assignments.

After P1 and P5, profile the actual phone. If it is already achieving acceptable sustained frame pacing with all 64 units, don't spend another week optimizing architecture for hypothetical gains.

If it is still struggling, tackle whichever subsystem the new measurements identify—not whichever proposal sounds most sophisticated.

That is the design I would approve for James: small changes, measurable wins, no unnecessary machinery.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High