ChatGPT said:
Alien Fusion AI — final pre-merge code review
NOT READY

Do not freeze these files as the reference for the Luau port yet. The code runs on Node 22 and repeated battles with the same seed are deterministic in the tested configuration, but several correctness defects remain. Most importantly, dead enemies can be selected as live targets, AoE sorting silently uses invalid coordinates, and the mixed-army parity harness has a side-assignment bias.

I am reviewing the simulation as executable reference code, not reopening the game's ability or balance design.

Execution findings

I reconstructed the uploaded .mjs module layout in a separate working directory, preserving the source code apart from import-path adjustments.

Test

	

Result




Node.js 22 module execution

	

Pass




Repeated identical seeded mixed battle, four runs

	

Identical results




Empty versus empty army

	

Returns draw without throwing




Empty versus one unit

	

Returns immediately




One unit versus one unit

	

Completes




Dead-target selection

	

Fail — reproducible




AoE distance comparator

	

Fail — NaN




Out-of-grid navigation

	

Does not reject unsupported positions




Invalid ORCA timestep/horizon

	

No validation




Power-graph legacy equivalence

	

Not yet established as a default-mode invariant

The successful determinism check is meaningful but limited: reproducing the same result does not mean the result is correct.

A. Correctness — blockers
1. BLOCKER — AoE target sorting uses invalid coordinates

File: sim.js:221, 253, 313, helper at line 33.

Problem: d2() expects x and y, but warning shapes use cx and cy. Sorting with d2(enemy, shape) returns NaN.

Failing scenario: Three enemies are inside a Boulder Hurl or Solar Strike radius, with more enemies than the target cap. Instead of taking the nearest targets to the impact centre, the simulator effectively retains insertion order.

Exact fix: Introduce an explicit distance-to-shape function:

JavaScript
const distSqToShape = (u, s) =>
  (u.x - s.cx) ** 2 + (u.y - s.cy) ** 2;

Replace all three invalid comparators. Add stable ID tie-breaking when distances are equal. Keep d2() for unit-to-unit and normal {x,y} coordinates only.

This is a silent correctness failure, not a crash. 
sim.js

2. BLOCKER — The brain can select dead targets

File: brain.js:67–71, 119–125; sim.js:366–397.

Problem: The simulator captures each side's living-unit array at the beginning of the tick. Units can die during Orders or earlier unit processing, but those cached arrays still contain them. The brain's candidate pool does not filter alive.

Reproduction: I passed one dead F2 at (4,0) and one living F2 at (20,0) to an F3's brain.tick(). It selected the dead F2.

Exact fix: Filter candidates inside the brain, regardless of caller behaviour:

JavaScript
const candidates = foes.filter(e => e.alive);
if (candidates.length === 0) {
  releaseSlot(u);
  A.target = null;
  A.goal = null;
  return;
}

Use only living units for sensing, fear, target selection and the attack-opportunity search. Revalidate the chosen target immediately before applying damage or planning movement.

3. BLOCKER — A* returns paths that intersect solid boulders

File: nav.js:34–84, especially grid construction and string pulling.

Problem: The grid models obstacles by blocked cell centres, while the string-pulling pass tests a reduced clearance radius (r * 0.95). Those checks are not geometrically equivalent. The returned route can cross an actual inflated obstacle.

Reproduction: I generated 80 seeded five-boulder environments, discarded invalid endpoints, and validated every returned route segment using nav.blocked(segment, r).

Result: 19 of 77 returned paths contained at least one blocked segment.

Exact fix:

Never reduce agent clearance during path smoothing.

Make grid occupancy conservative enough to account for cell dimensions.

Validate every final path segment against the exact inflated obstacle geometry.

If smoothing fails validation, retain the unsmoothed route; if that also fails, return a path failure.

Add a property test requiring blocked(a, b, clearance) === false for every consecutive returned segment.

This alone prevents me from approving the pathfinder as a port reference.

4. BLOCKER — --ai=old does not reproduce the previous power graph exactly

File: sim.js:16–17, 325–330 and the legacy code paths.

I compared the current simulator against the previously supplied v3 power-graph simulator using the same runtime, seeds and kit data, and enabled --ai=old --legacy-timer.

The outputs differ. Examples include remaining-health percentages changing from 61% to 64%, from 70% to 72%, and a fight changing from 19s to 18s.

I repeated the comparison after supplying the older simulator with the current kit file. The differences persisted, so they cannot all be attributed to the small kit-data changes.

The current --ai=old without --legacy-timer differs further, because its attack timer has changed.

Exact fix: Decide and enforce one contract:

If old means exact historical parity, preserve every original rule and operation ordering in a frozen legacy implementation, then regression-test full-precision fight results against it.

If old means the old movement AI using today's corrected combat engine, document it that way and stop claiming exact historical reproduction.

I recommend the second meaning for normal comparisons and a separate frozen legacy fixture for regressions.

5. BLOCKER — Mixed-race parity results have a side-assignment bias

File: mixed.js:15–26.

The harness creates all SQUISH entries before CRUNCH entries, then evaluates only pairs where i < j.

For every cross-race matchup, this puts SQUISH on team 0 and CRUNCH on team 1. It never mirrors that matchup with the races swapped.

This makes the reported 53.5% versus 46.5% result unsuitable as a clean race-parity measurement.

Exact fix: For every cross-race composition pair and seed, run both orientations. Reverse the compositions and races, and calculate the win outcome from the perspective of the same race. Aggregate the two outcomes with equal weight. Prefer paired seeds and report variance.

Keep the existing per-composition ranking separate from the race-parity calculation.

6. BLOCKER — Invalid timestep can hang the simulator

File: sim.js:29–30, 360–361.

Problem: DT is accepted directly from --dt. With --dt=0, the loop never advances. A negative timestep is also unsafe. With NaN, the simulation can terminate immediately and return misleading results.

Exact fix: Validate DT, RUNS, seed and HP multipliers at the public entry points. For the simulator, accept only finite DT > 0, and preferably constrain it to 0.01–0.2 seconds. Reject invalid input with a nonzero exit code. For reproducible balance runs, select a canonical supported timestep explicitly.

B. Correctness and robustness — major findings
7. MAJOR — Exact-centre boulder collision does not resolve

File: sim.js:433–436.

Failing scenario: A unit is placed exactly at a boulder's centre. dx and dy are both zero. Although L falls back to 0.01, multiplying by the zero direction leaves the unit exactly where it was.

Fix: When squared distance is below 1e-6, choose a deterministic unit-ID/obstacle-ID normal and push the unit to b.r + 0.9 * u.r. Test both exact-centre and near-centre cases.

8. MAJOR — Collision resolution is not closed under its own operations

File: sim.js:433–450.

Problem: Boulder push-out runs before unit separation. Separating overlapping units can push one directly back into a boulder. There is no second static-obstacle resolution pass.

Failing scenario: Two units occupy a narrow gap beside a rock. Both are projected outside the rock, then their mutual separation pushes one inside again. The next tick repeats the correction.

Fix: Resolve static obstacles and agents iteratively, with a bounded number of passes—for example 3 passes initially—and finish with an exact static-obstacle projection. Assert that every surviving unit satisfies the clearance constraint to within a stated epsilon. Do not let the pass depend on unbounded convergence.

9. MAJOR — Navigation silently clamps coordinates outside its grid

File: nav.js:4, 35–38.

Problem: cell() clamps out-of-bounds positions to the nearest edge cell. That changes the requested problem without telling the caller.

Reproduction: A route beginning around (500,0) does not trigger an out-of-bounds error, even though the configured X grid only covers approximately -120 to 120.

Fix: Return a distinct OUT_OF_BOUNDS result, or explicitly expand the navigation domain. Do not confuse an unsupported coordinate with a valid pathfinding request. This distinction is particularly important for the much larger Roblox arena.

10. MAJOR — Blocked-goal replacement is not guaranteed reachable

File: nav.js:39–50.

The code chooses a nearby free cell by geometric distance to the blocked destination, with a small start-distance tie-breaker.

That cell may be on the wrong side of an enclosing obstacle. The subsequent A* search can fail even when another nearby free cell is reachable.

Fix: Generate candidate free endpoints and choose the lowest-cost reachable candidate. Alternatively, run a multi-goal A* and stop at the best reachable candidate within the allowed endpoint region. Distinguish NO_REACHABLE_GOAL from OUT_OF_BOUNDS.

11. MAJOR — Melee reservation lifecycle is incomplete

File: brain.js:38–44, 67–69, 309–315.

The current target-switch path releases reservations properly, but the no-enemies branch sets A.target = null without releasing its sectors.

This leaves stale sector ownership and a stale slotTarget reference.

Fix: Create one clearTarget(u) function that releases the slot, clears target, goal, saviour, evadeFrom and path state as appropriate. Invoke it when enemies disappear, on death/despawn, and when a transformation replaces the unit.

Do not rely on later scoring checks ignoring dead owners; cleanup should be an explicit lifecycle invariant.

12. MAJOR — Path and blocked-state bookkeeping can outlive the goal it describes

File: brain.js:119–125, 211–229, 281–304.

On target change, pickTarget() releases the melee slot but does not invalidate the current cached path or reset the progress baseline.

The path may still be used until the next permitted repath. Similarly, progD can describe a previous route while wantGoal refers to a new one. The first completed stuck window after a fight can compare distances from different movement objectives.

Failing scenario: An F2 is routing around a boulder toward a Titan; it switches to a nearby F1. Before the repath interval expires, it can keep steering along the old route.

Fix: Introduce a goalVersion incremented on target, mode or major destination change. Tag path, detour, blockedEvent and progress windows with that version. Discard or reset them whenever versions differ. Repath immediately for a genuinely new target, while retaining the per-unit cooldown for repeated attempts at the same destination.

13. MAJOR — Movement planning is simultaneous, but decision-making is still order-dependent

File: sim.js:388–432; brain.js:140–151, 192–205.

brain.plan() is correctly performed for all movers before integration. However, the preceding brain.tick() calls modify reservations and targets sequentially.

Earlier units reserve preferred sectors first. Later units plan against those updated reservations. This is deterministic in the current JS array order, but not independent of processing order.

Fix: Make the semantics explicit:

Sense and score from an immutable decision snapshot.

Collect desired target/slot claims.

Resolve conflicting claims in stable unit-ID order, or through a defined priority mechanism.

Commit decisions after conflict resolution.

Plan velocities from a shared physical snapshot.

For the port, specify whether deterministic priority or fairness is preferred. Do not accidentally inherit Lua table iteration order.

14. MAJOR — ORCA accepts invalid numerical inputs without guarding

File: orca.js:73–106.

The LP port's normal vector maths is consistent with the RVO2-style implementation, and I did not find a definite sign error in lp1/lp2/lp3 during this review.

But computeVelocity() does not validate horizon, dt, maxSpeed, positions, radii or avoidance shares. Zero values reach divisions such as 1 / horizon and 1 / dt; non-finite inputs may propagate through comparisons and return misleading finite or non-finite outputs.

Fix: At the boundary, enforce:

JavaScript
if (!Number.isFinite(dt) || dt <= 0) throw new RangeError("dt");
if (!Number.isFinite(horizon) || horizon <= 0) throw new RangeError("horizon");
if (!Number.isFinite(maxSpeed) || maxSpeed < 0) throw new RangeError("maxSpeed");

Also validate finite vectors, nonnegative radii and 0 <= share <= 1. Check output finiteness before committing it to unit state.

15. MAJOR — Mutable profile objects bypass validation

File: profiles.js:7–21, 55–90; brain.js:21–23, 232–245.

Values are imported directly from mutable objects. Extreme settings can introduce division by zero or NaN: falloff = 0, gangUp.want = 0, ramp.over = 0, stayNear.radius = 0, and so on.

Fix: Add validateProfiles() before simulation startup. Validate ranges and cross-field invariants, then freeze the approved data for production simulations. Tests that deliberately alter profiles should work on cloned configurations passed into the brain, not shared imported singletons.

C. Determinism and test-harness findings
16. MAJOR — Determinism depends on stable insertion order, not just the RNG seed

Files: brain.js target and slot selection; sim.js unit processing; mixed.js matchup generation.

I found no executed unseeded Math.random() path in normal battle() creation: the armies pass the seeded generator into makeUnit(). However, makeUnit() still declares Math.random as a fallback.

Fix: Make the RNG argument mandatory; remove the fallback. Define stable tie-breaking by unit ID in target, slot, collision and ability selection. Record the seed and configuration with each result.

The tested identical-seed runs passed, but changing unit insertion order or porting to Luau could change outcomes.

17. MAJOR — Diagnostic harnesses do not fail reliably in CI

Files: check.js:10–25, metrics.js:25–32, edge1.js.

check.js prints flagged values but does not set a nonzero exit status. A failed balance check can therefore look like a successful process to an automated pipeline.

metrics.js also divides by unitT and dmg without guarding zero-fight or zero-damage cases.

Fix: Set process.exitCode = 1 when a required check fails. Reject N <= 0. Emit structured JSON with pass, failedChecks, seed, code version and configuration. Define null or “not applicable” for metrics with zero denominators, never NaN in the report.

18. MINOR — The attack timer's reference behaviour needs an explicit contract

File: sim.js:325–330.

The remainder-preserving attack timer is an improvement over the legacy reset. However, attacks are still initiated within a discretised update loop, and some effects use absolute timestamps while others accumulate DT.

Fix: Separate nextAttackAt, impactAt and recoveryUntil in one scheduling abstraction. Define how much overdue time can be carried forward and forbid multi-attack bursts after a long timestep. Test the same duel at 10, 20 and 40 Hz with bounded outcome tolerances.

Keep the legacy timer only inside the frozen compatibility test path.

19. MINOR — Per-unit maps and pending effects have no explicit disposal contract

Files: brain.js:28–34, 61, 192; sim.js:67–70, 87, 125–127, 363–365.

unreach retains references to targets until the whole brain is discarded. Dead units can also remain in units and hold ai.slots; expired puddles, slows and pending-effect-related state are not systematically compacted during the battle.

At the current fixed battle size, this is bounded by the match, but it is a poor reference for a long-running server controller with repeated fusion and split.

Fix: Implement disposeUnit(), expiry pruning for unreach, removal of expired status entries and cancellation/cleanup of owned effects. Use stable numeric IDs with generation counters for spawned/replaced units.

20. MINOR — Excessive hot-loop allocation and repeated full scans

Files: brain.js:47–58, 67–87, 140–175, 247–258; sim.js targeting, bestCluster(), collision and burn loops; nav.js:52–83.

The code performs repeated filter, sort, find, temporary vector allocation and full-unit scans. In dense fights, target scoring can itself scan other units for guards. bestCluster() is quadratic, and A* allocates and fills several arrays on every search.

Fix before Luau port:

Use the planned spatial hash for nearby-unit queries, not all-unit scans.

Maintain reusable nearby-friends and nearby-enemies collections per decision snapshot.

Replace full sorts with bounded top-K selection when only 1–4 targets are required.

Reuse velocity, ORCA-line and pathfinding scratch arrays where safe.

Prebuild or cache static navigation clearance classes.

Profile the worst case: 64 units, all in a dense engagement, with simultaneous target changes and blocked routes.

I would not invent a guaranteed CPU budget from code inspection. Measure server CPU time in the Roblox implementation.

21. MINOR — Simulation and AI-module boundaries remain too coupled

Files: brain.js:16–19, 47–58; sim.js:118–122, 378–386.

The brain expects units containing ai, ab, form-specific fields and direct references to other mutable units. It reaches into combat-derived attack counts and assumes all targets have brain state.

Fix: Define a documented UnitSnapshot and BrainState interface. Supply counter priority, effective DPS and nearby-unit data through explicit adapters. Keep combat-specific ability evaluation in the simulator/combat module, not embedded in navigation or steering logic.

This is a maintainability issue rather than proof of an immediate gameplay defect.

22. NIT — Comments, constants and identifiers need cleanup before reference freeze

Examples:

brain.js header still describes an earlier audit version.

Several timestamps, distance thresholds and 24 sectors are hardcoded in the brain instead of a central validated configuration.

sim.js:188 includes an unused dT parameter.

preferPick() uses a hardcoded modulo-9 technique to handle preference ranks, making its intent unnecessarily opaque.

The imported profile constants are mutable, while comments sometimes imply fixed rules.

Fix: Rename ambiguous variables, remove unused parameters, replace magic-value ranking with explicit indexOf < 0 ? Infinity : index, and update documentation after the code is stable.

D. Performance and Luau port readiness

The architecture can translate, but the current JS should not be ported mechanically line for line.

JS pattern

	

Required Luau treatment




Map keyed by unit objects

	

Numeric unit IDs and explicit generation numbers




Set of angular sectors

	

Fixed-size arrays or bitsets




Zero-based sector indices 0..23

	

Explicit conversion to Luau's 1..24 indexing




Grid index cy * W + cx

	

Consistent one-based indexing and bounds assertions




Map.get() / .set() / .delete()

	

Typed table access with explicit missing-value semantics




Array.sort() and stable insertion order

	

Defined tie-breaking; never depend on pairs() order




Closures capturing units, t, pending

	

Explicit simulation context and cleanup ownership




JS undefined, NaN, Infinity behaviour

	

Luau-compatible validation and finite-value checks




Frequent temporary {x,y} objects

	

Reused numeric/vector storage where profiling warrants it

The server port must also preserve event ordering: deaths and Orders, then target decisions, then movement planning and integration, followed by collision resolution and cleanup. Freeze that order in documentation and tests.

E. Minimal regression test suite

These tests should run automatically on every reference-code change.

#

	

Test

	

Pass criterion




1

	

Seed replay

	

Same seed/configuration produces bit-identical result and unit trace across repeated JS runs




2

	

Legacy parity

	

Frozen legacy fixtures match exactly when explicit compatibility mode is enabled




3

	

Dead-target filtering

	

No dead unit is selected, attacked or reserved




4

	

Slot lifecycle

	

Target change, EVADE, GUARD, death and despawn release only owned sectors




5

	

Slot capacity

	

64 contenders cannot claim overlapping sectors unintentionally; stable IDs resolve ties




6

	

A path safety*

	

Every returned segment is obstacle-clear at full agent radius




7

	

Navigation boundaries

	

Out-of-grid, blocked start, blocked goal, unreachable goal and no-obstacle cases return defined results




8

	

Collision edge cases

	

Coincident units, unit at boulder centre and unit separation near a wall all remain finite and clear




9

	

ORCA property tests

	

Finite output, speed bound, valid share, deterministic ties; reject invalid inputs




10

	

Target and path invalidation

	

Changing target resets incompatible path, progress and blocked state




11

	

Ability target caps

	

Lob, leap slam and Solar Strike select nearest eligible enemies with deterministic ties




12

	

Time-step invariance

	

10/20/40 Hz results remain within documented tolerances without event loss




13

	

Mixed-race parity harness

	

Both team orientations receive equal weight for every cross-race comparison




14

	

Input validation

	

Zero/negative/NaN dt, invalid seeds, zero runs and invalid profile numbers fail cleanly




15

	

Lifecycle endurance

	

Repeated unit creation, death, fusion and split leave no stale IDs, sectors, paths or unbounded state




16

	

64-unit dense stress

	

No exceptions, NaNs, persistent wall penetration or uncontrolled allocation growth

I additionally ran a custom test starting 64 brain-controlled units at coincident team positions for 200 steps. Their coordinates and velocities remained finite. That is a useful smoke test, not a substitute for the complete collision-resolution test, because it exercised the brain without the simulator's final hard-separation stage.

Final merge decision

NOT READY for reference freeze.

The immediate merge gate is:

Repair invalid AoE coordinates and dead-target selection.

Make A* output collision-safe and reject unsupported coordinates.

Resolve boulder/crowd collision in a consistent final pass.

Correct the race-parity harness and state precisely what legacy mode guarantees.

Add timestep/configuration validation and the regression tests above.

Define explicit unit-state cleanup and deterministic Luau-compatible identifiers.

After those changes, I would expect a much smaller review focused on test evidence, numerical stability and performance—not another architectural redesign.

The principal risk is not that the AI lacks sophistication. It is that the current simulator can produce believable, deterministic numbers while silently evaluating incorrect targets, invalid paths or biased matchups. That is exactly the kind of reference-code defect worth eliminating before the Luau port.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High