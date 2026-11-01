Alien Fusion — Senior Engineering Audit

Scope: The supplied code excerpts, measurements and described state transitions. I cannot certify the unprovided implementations of solveLegs, brain.hold, inArc or the attack scheduler.

Fix

	

Verdict

	

Assessment




1. Attack foot IK

	

ROBUST WITH CHANGES

	

Correct root-cause fix; transition and locomotion edge cases remain




2. Colossus rider deadlock

	

NOT ROBUST

	

Solves the reproduced case but introduces a potentially broader AI deadlock

FIX 1 — Attack feet snapping backwards

Verdict: ROBUST WITH CHANGES

The coordinate-space diagnosis is correct.

Previously, at(0) evaluated to base * Vector3.new(0, 0, s0), placing the ground reference behind the current root by the entire accumulated walking distance. Replacing that with base * Vector3.new(0, 0, 0) removes the erroneous displacement.

The measurements strongly support the correction:

Colossus: 612/936 abnormal samples reduced to 2/1060.

Ram: 1099/3808 reduced to 24/6360.

Brute: hind-foot maximum reduced from 2.92 to 1.84 studs.

However, those samples are not paired by attack and animation phase. They demonstrate a major improvement, not complete correctness.

Required changes

1. Do not blindly reset every planted foot at attack onset.

leg.stand = nil causes every leg to acquire a new stance foothold, including legs already firmly planted in world space.

A mid-stride attack could therefore produce a visible one-frame foot teleport even though the original backwards-stretch bug is fixed.

Change:

Preserve each planted leg's current world-space foothold.

For swinging legs, transition to the attack's intended foothold over 0.10–0.15 seconds.

Preserve deliberate lifting or stepping for attack-specific poses.

Do not reset a leg's foothold unless its attack transition explicitly requires repositioning.

Acceptance: No unintentional attack-start foot discontinuity greater than 0.5 studs.

2. Separate planted attacks from locomoting attacks.

The corrected at(0) is appropriate for an attack whose feet should be planted relative to its current location. It is not sufficient as a universal attack-grounding policy.

Explicitly classify attack locomotion:

Attack behaviour

	

Required IK policy




Stationary slam / brace

	

Preserve world-space stance




Ram Stamp

	

Preserve supporting hooves; animate stamping hoof




Ram Charge

	

Use charge travel position and moving gait




Twin Boing

	

Disable grounded stance during airborne phase; reacquire on landing




Walk during attack effects

	

Resume walking foothold calculation

In particular, verify that a travelling attack never continues using a world-space foothold captured before its root moved beyond leg reach.

3. Audit the aiWalk after lock call path.

The new at(u) treats u as a local displacement. The walking implementation described in the file uses absolute accumulated stride distance.

Those are two different coordinate contracts.

Require:

atAttack(localDisplacement) for attack-grounding.

atWalk(absoluteStrideDistance) for walking.

Every solveLegs call must pass the matching displacement convention.

If an attack-effect path still passes st.s or n * stride into the newly local at(u), the original class of bug can reappear in another form.

Do not share the two functions without an explicit coordinate conversion.

4. Investigate the remaining two Colossus outliers.

The Colossus still has two foot samples more than 2.5 studs behind their rest positions, with a maximum displacement of 2.83 studs.

Capture for each:

Attack name and normalized attack time.

Leg identifier and planted/swinging state.

Root position and facing.

Foot target versus actual IK result.

Whether the target lies beyond the leg's reachable length.

If both samples are deliberate attack poses, document them as exceptions. Otherwise, correct them.

Required regression tests

Run at accumulated walking distances of 0, 100 and 1,000 studs, with attacks initiated at 0%, 25%, 50% and 75% of the gait cycle. Test stationary attacks, turning attacks, travelling attacks and the return to walking.

Merge gate: Zero unexplained foot-reach violations, no planted-foot teleport greater than 0.5 studs, and no walking-phase discontinuity on attack exit.

Engineering decision: Accept the coordinate correction. Require the transition and call-site checks before calling the complete animation fix robust.

FIX 2 — Colossus walking indefinitely with attached Drips

Verdict: NOT ROBUST

The reproduced failure makes sense: the Colossus chases a target whose position moves with its own position. Stopping locomotion allows facing to converge toward the rider.

But the implementation:

not onMe in the global walking condition

is too broad.

It turns being targeted while attached into an unconditional movement veto, without proving that the unit can actually attack the rider.

That is a liveness bug waiting to happen.

Required changes

1. Restrict the hold behaviour to units with a valid anti-cling attack.

Consider a Ram, Pincer or another unit whose current target is attached to it.

The new rule stops the unit, regardless of whether its attack can reach the target.

If the attack requires a minimum distance, a particular contact shape or a forward-facing hit volume, the unit can stand motionless while being damaged.

Change:

Compute onMe as currently implemented, but only suppress normal movement when:

The target is alive and actually attached to this unit.

The target is geometrically within a valid attached-contact region.

The unit possesses an attack that can resolve this situation.

Otherwise, choose another reachable target or an appropriate escape/reposition action.

Do not apply a global movement veto solely because tg.on == u.

2. Handle zero-distance bearing explicitly.

If a rider is directly under the pivot, dx = dz = 0.

The desired facing direction is geometrically undefined. Depending on the implementation of bearing and inArc, this can produce an arbitrary angle, a zero-length normalization or an invalid direction.

The Colossus could remain held indefinitely.

Change:

For target distance below 0.25 studs, preserve current facing instead of recalculating bearing.

Allow a confirmed attached rider within the body's legitimate contact region to qualify for an anti-cling attack without requiring angular alignment.

Keep normal cone restrictions for ordinary, unattached targets.

This exception must be restricted to a visually credible body-contact or anti-cling attack. Do not silently make every forward attack hit enemies behind the unit.

3. Resolve multiple riders without depending on a single target.

Test two riders attached on opposite sides of the Colossus.

The current code stops movement and turns toward brain.target, but it does not establish that all attached riders will eventually be considered or hit.

If targeting switches rapidly, facing can oscillate. If targeting never switches, another rider may remain attached indefinitely.

Change:

Maintain a server-side set of valid attached enemies.

For a suitable anti-cling area attack, evaluate all attached riders independently.

Otherwise, lock an eligible rider target until an attack completes or that target becomes invalid.

Re-evaluate remaining riders immediately after an attack, kill or detachment.

Avoid a target-selection rule that changes the desired bearing every simulation tick.

4. Do not let brain.hold interfere with attack-controlled movement.

The new conditional calls brain.hold(u) whenever the unit is busy, pinned or targeting its own rider.

Busy and pinned were already excluded from walking, so this is not necessarily a new regression. However, its correctness depends on what brain.hold modifies.

Verify whether it clears velocity, attack travel, mode state, route state or reservations.

Required ownership rule:

Stationary attack: AI locomotion may be held.

Travelling attack: attack controller owns displacement.

Pinned state: crowd-control controller owns displacement.

Ordinary rider handling: AI may hold only when permitted by the anti-cling policy.

The generic hold operation must never cancel a scripted Ram Charge or equivalent movement.

5. Add a guaranteed recovery from unsuccessful holds.

Even after the above changes, a unit can potentially remain in an apparently valid attack state without dealing damage.

Add a liveness safeguard:

If a unit is held solely to attack an attached target, and two complete attack opportunities pass without a successful attack attempt or meaningful resolution, invalidate that hold decision.

The controller must then re-evaluate range, target eligibility and available attacks, and either retarget, reposition or invoke an appropriate anti-cling action.

Count attack opportunities rather than relying on a universal timeout, since cooldowns differ between forms.

Do not bypass legitimate attack cooldowns or create free damage.

6. Do not chase an inaccessible rider indefinitely when it is attached to another unit.

For tg.on ~= u, ordinary movement is still allowed.

That is generally correct, but an attached enemy can itself be an unsuitable navigation goal.

Ensure target validation considers whether the attacker can reach and hit the rider while the carrier moves. If not, retarget the carrier where appropriate or choose another reachable enemy.

This is primarily a broader AI-targeting requirement, but the original stalled behaviour exposes the weakness.

Required regression tests

Scenario

	

Expected outcome




One rider at exact pivot

	

Valid anti-cling response, no undefined bearing




One rear rider

	

Attack eventually executes without perpetual movement




Two riders on opposite sides

	

Both eventually considered; no endless turn oscillation




Rider detaches while turning

	

Normal locomotion resumes without stale hold




Rider dies while held

	

Target invalidated and locomotion resumes




Rider attached to a different unit

	

No inappropriate self-rider hold




Ram or Pincer with attached target

	

No permanent idle state when unable to attack




Titan with attached Drips

	

Equivalent liveness behaviour if it shares the same mechanics




Busy travelling attack with rider

	

Scripted attack movement is preserved




Rider on Colossus plus nearby free enemy

	

Explicit target-priority policy; no perpetual hold




Rider offset beyond attack reach

	

Hold rejected; target or movement reconsidered

Run the scenarios at 20 Hz for at least one full 210-second match each, across multiple deterministic target-selection seeds.

Merge gate: No indefinitely held unit without a reachable attack, no target-switch oscillation, no scripted-motion cancellation, and all valid attached enemies eventually receive a combat response.

The existing 6/6 successful fights are encouraging, but they cover only one fight composition. They do not validate the generic movement rule.

Final disposition

Fix 1: ROBUST WITH CHANGES — conditionally approve. The underlying coordinate correction is sound and should remain. Do not revert it. Fix the attack-entry foot transition, verify the separate walking coordinate contract, and classify travelling attacks correctly.

Fix 2: NOT ROBUST — reject the generic hold rule as a final solution. Keep the insight that self-attached targets should not be chased. Implement it as an explicit, attack-capability-aware anti-cling behaviour with a guaranteed escape from unsuccessful holds.

Priority: Fix 2 first. Fix 1 primarily risks visual defects and animation regressions. Fix 2 can create permanently passive units, exploitable combat behaviour and matches that fail to terminate.

These are the required changes based on the submitted excerpts; full source review is still needed to establish whether some protections already exist elsewhere.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High