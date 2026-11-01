Round 2 of the robustness audit: the attached fix-audit-r2.md has the reworked fixes (Fix 2 rebuilt per your r1 points; Fix 1 extended with a foot handoff, a leg-owner switch and a Ram Gore step fix) plus all new measurements. Please try to break both again, verdict per fix (ROBUST / ROBUST WITH CHANGES / NOT ROBUST) with exact changes.
Worked for 5m 50s
ChatGPT said:
Alien Fusion — Robustness Audit R2

The second round is a substantial improvement. The Ram's Gore regression is particularly useful evidence, and the decision to discard the invalid replication test batch was correct.

However, I've found a remaining liveness failure in Fix 2 and several transition hazards in Fix 1.

Fix

	

R1 verdict

	

R2 verdict




1. Foot IK / handoff / Gore

	

ROBUST WITH CHANGES

	

ROBUST WITH CHANGES




2. Colossus anti-cling AI

	

NOT ROBUST

	

NOT ROBUST

FIX 1 — Foot IK, handoff and Ram Gore

Verdict: ROBUST WITH CHANGES

The original coordinate correction remains sound. The new owner switch addresses a genuine second bug: resuming stale walk footholds after an attack.

Zero Ram foot snaps across 4,221 frames, zero Colossus snaps in the mixed fight, and zero Brute hind-foot snaps are strong results.

The Brute's 39 consecutive high-speed fist movements are not automatically defects: they're authored striking motion, not isolated teleports.

Required changes

F1.1 — Latch the post-lock leg-owner transition.

Current code:

Lua
local tail = not defeat
    and rt - cur.t0 > (atk.lock or atk.dur) + 0.25
    and st.spd > 0.4

Counterexample: attack time is past the lock, but smoothed speed alternates between 0.39 and 0.41.

The owner flips atk → walk → atk → walk, repeatedly calling resetFeet. The 0.18-second handoff may never complete.

Change: Once the attack has handed locomotion ownership to walk, latch that decision until the attack ends or a new attack explicitly begins. Don't derive ownership afresh from speed every frame.

If a character stops during its post-lock tail, the walk controller should resolve standing feet rather than giving ownership back to the attack controller.

F1.2 — Capture the final rendered foot, not an intermediate solver result.

The handoff is applied before attack limb targets and defeat-kneel modifications.

Two risks remain:

An attack target applied after the handoff can introduce a discontinuity that bypasses the smoothing.

If solveLegs executes twice, drawnP can temporarily represent the first, provisional solve rather than the pose ultimately rendered.

Change: Compute attack targets and pose overrides first, then apply the applicable foot transition before the final IK solve. Preserve a separate renderedP/renderedR from the previous completed frame; commit the new values only after the final pose has been resolved.

Intentional attacking limbs, such as the Brute's striking fists, should retain their authored movement. Don't slow those strikes merely to satisfy a foot-planted constraint.

F1.3 — Replace the 1.5-stud snap threshold with the original acceptance criterion.

R1 requested no unintentional transition discontinuity greater than 0.5 studs. R2 instead reports zero snaps greater than 1.5 studs, with a Colossus attack-start maximum of 0.72.

That is a significant improvement, but it has not passed the original gate.

The handoff also depends on frame rate. For a 2.65-stud displacement over 0.18 seconds, smoothstep produces approximately 0.74 studs of horizontal movement per frame near its midpoint at 30 FPS.

Change: Record world-space foot displacement and planted-foot slip separately at 30, 60 and 120 FPS. Target no unexplained single-frame discontinuity greater than 0.5 studs. Increase handoff duration or cap movement per rendered frame where needed, without changing intentional attack trajectories.

F1.4 — Keep Gore displacement immutable throughout the attack.

The travel function returns nil if ctx.gore is missing, or if L is below 0.3.

Counterexample: the Gore target dies during the forward lunge, and the attack context is rebuilt without its original target-dependent Gore data.

The travel footholds disappear while the authored body-forward keys may still be holding the Ram near maximum extension.

Change: Snapshot L, the world-space lunge origin and the attack direction at attack creation. Keep those values until the animation finishes, even if the target dies, detaches or changes.

Test target death at Gore times 0.40, 0.55 and 0.85 seconds; lengths 0.29, 0.30 and 0.31 studs; and consecutive attacks separated by exactly 1.25 seconds.

F1.5 — Verify that the Gore's visual step matches server-side combat reach.

The server does not actually move the Ram forward during Gore, but the client visually moves its body by as much as 2.65 studs.

That is acceptable as a non-authoritative attack animation only if server hit validation and the displayed contact remain consistent.

Change: At the Gore contact frame, compare the server-authoritative hit decision against the visual horn/target separation. Ensure the attack neither visibly connects and misses without explanation nor deals damage from an implausible gap. Do not trust client visual displacement for hit registration.

Fix 1 regression gate

Run Gore, Stamp, Pound and Colossus Slam at 30/60/120 FPS, including an attack starting mid-stride, post-lock speed oscillating around 0.4, target death mid-attack and consecutive attacks.

Disposition: Keep 1a–1d. They fix the demonstrated problems. F1.1 and F1.2 are required for ownership correctness; F1.3–F1.5 are required to validate the remaining transitions and combat consistency.

The separate 4–9-stud whole-body clock-resynchronisation jumps are still unresolved, but they should be tracked as a distinct network presentation defect, not misattributed to IK.

FIX 2 — Colossus/Titan anti-cling behaviour

Verdict: NOT ROBUST

The rework fixes the most obvious r1 problem: ordinary melee units are no longer subjected to the giant's special hold rule. The successful Colossus and Titan tests demonstrate that the normal combat case works.

But the timeout mechanism is mathematically incapable of resolving several stalled states.

Required changes

F2.1 — The timeout resets on attack attempts, not progress. Critical.

Current code:

Lua
if now - math.max(
    u.holdSince,
    u.lastSlamT or -1e9
) > limit then

Colossus limit = 11 seconds.

Counterexample:

At 0 seconds: hold begins.

At 4 seconds: Slam starts but deals zero damage.

At 8 seconds: another Slam starts, again zero damage.

At 12 seconds: another unsuccessful Slam.

Because lastSlamT updates every four seconds, elapsed time never exceeds 11 seconds.

The watchdog never fires.

Change: Track lastClingProgressT independently of lastSlamT. Update progress only when the held target receives a confirmed effective hit, dies, detaches or otherwise resolves the threat.

Attack animation starts are not evidence of progress.

Use a fixed no-progress deadline, rather than resetting it on every attack attempt.

F2.2 — holdFor changes can reset the watchdog indefinitely. Critical.

Counterexample: two attached Drips sit on opposite sides of the Colossus. The brain alternates targets every 1–2 seconds.

Current code:

Lua
if u.holdFor ~= tg then
    u.holdFor, u.holdSince = tg, now
end

Each target switch resets holdSince. Meanwhile, the Colossus's facing direction keeps changing.

Neither rider is necessarily attacked, and the timeout never fires.

Change: Lock one valid attached target for the current anti-cling attempt. Retarget only after resolution, invalidation or a genuine recovery decision.

Keep a separate no-progress timestamp for the overall anti-cling state; switching riders must not silently reset it.

F2.3 — The four-second unreachable penalty does not guarantee escape. Critical.

Current timeout:

Lua
u.brain.unreach[tg] = now + 4
u.holdFor = nil
return false

Counterexample: one Drip remains attached and there are no other enemies.

The Colossus has no alternative target. The planner may retain or reselect the same Drip despite the scoring penalty.

On the next eligible movement tick, holdFor ~= tg, so the hold is reinitialised.

Result: 11 seconds holding, possibly a brief movement attempt, then another 11 seconds holding. The original failure can return.

Change: Timeout recovery must perform a deterministic action, not merely adjust target scoring.

If another reachable enemy exists, explicitly switch to it.

If no alternative exists, use a defined anti-cling recovery action or enforce a finite attachment lifetime.

Never resume chasing a rider attached to your own moving body as the sole fallback.

Ensure brain.unreach exists and the forced-timeout code path is actually exercised. None of the reported successful fights establishes that this branch works.

F2.4 — Your rider-offset design contains a deeper geometric problem.

This is the biggest structural concern.

Currently, a Drip retains a world-space offset from the Colossus.

When the Colossus turns, the Drip remains at approximately the same world bearing. The giant can eventually face it, but the rider effectively slides around the rotating body.

If you correct the attachment to use a body-local offset, a rider on the Colossus's back will rotate with the Colossus.

Its relative bearing remains 180 degrees behind, no matter how far the Colossus turns.

A forward 120-degree Slam can never face that rider through turning alone.

Change: Decide and enforce the attachment geometry.

If riders are intended to remain in world-offset positions, validate that visual behaviour deliberately. If they are genuinely attached to the creature's body, turning alone cannot be the anti-cling solution.

A body-attached implementation requires a separately defined response to rear riders: for example, a limited shake-off or close-body attack with an explicit cooldown and server-authoritative hit volume. Do not casually convert the entire forward Slam into an unconditional 360-degree attack; that would materially change the swarm-versus-giant balance.

F2.5 — The hold reach check does not match the actual attack predicate.

Current check:

Lua
flatDist(u, tg) <= p.radius + u.r

But Slam uses inArc(u, e, radius, 120).

Unless inArc explicitly uses the same radius convention, the hold can accept a rider that the attack cannot hit.

Change: Use one shared server-side range predicate for attack eligibility and anti-cling holding, with only the angular requirement handled separately.

Test riders at the actual hit-radius boundary, including one just inside and one just outside it.

Also test the pivot exception at e.r - 0.01, e.r and e.r + 0.01 studs. Ensure the resulting bearing calculation is finite and stable.

F2.6 — Verify movement ownership while busy or pinned.

The movement conditional still invokes brain.hold whenever the unit is busy or pinned.

That is acceptable only if brain.hold cannot cancel attack-controlled or crowd-control-controlled displacement.

Change: Add an assertion or isolated regression test ensuring hold clears only AI locomotion, without overwriting scripted travel or pinned-state displacement.

This is a verification requirement, not a demonstrated regression.

Fix 2 adversarial regression gate

Test

	

Required result




Single rider, all Slams miss

	

Watchdog fires and real recovery occurs




Two opposite riders, target changes every second

	

Target lock prevents oscillation




One remaining rider, no other enemies

	

No repeating hold/chase cycle




Rear rider with body-local attachment

	

Explicit attack or escape, no impossible turn-to-face




Slam starts but deals zero damage

	

No-progress timer continues




Rider dies during Slam

	

State clears without stale targeting




Rider at exact pivot

	

No undefined bearing or stalled attack




Busy/pinned giant with attached Drip

	

Attack and crowd-control movement ownership preserved




Rider beyond actual Slam reach

	

No hold without a valid attack or recovery path

Run each for the full 210-second match duration at 20 Hz, including forced missed attacks. Record target changes, hold duration, attack attempts, effective hits and recovery transitions.

Final merge decision

Fix

	

Keep current work?

	

Release gate




1. IK / handoff / Gore

	

Yes

	

Correct owner latching and final-pose handoff; pass remaining tests




2. Anti-cling

	

Partially

	

Replace timer/recovery logic and resolve attachment geometry

Fix 1 is close to sign-off. I would not rewrite the handoff architecture; it needs targeted safeguards and validation.

Fix 2 still has a fundamental liveness defect. The happy-path combat tests pass, but the timeout cannot guarantee progress, a different target can repeatedly restart it, and a lone rider has no guaranteed escape path.

The most important change for r3 is to make the anti-cling controller guarantee one of three outcomes: the rider is successfully attacked, the rider detaches, or the giant transitions to a genuinely reachable alternative. It must not continue indefinitely without one of those outcomes.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High