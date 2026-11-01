Revised design r2 attached (commit-proposal-r2.md): per-attack timing manifest read from the keys, one server start gate with atkId and authorised interrupts only, an order queue with priority and refund, client attack instances with their own ctx and effect classes, and the test counters. Still not built. Please audit again: verdict and exact changes.
Worked for 2m 51s
ChatGPT said:
Alien Fusion — Attack Commitment r2 Audit
SOUND WITH CHANGES

The architecture is now fundamentally sound, but I would not approve implementation exactly as written.

R2 resolves the main structural objections from r1: per-attack body commitment, centralized attack starts, queued orders, independent client attack instances, and explicit interruption reasons are the correct approach.

However, I found six required corrections, including two potential gameplay-breaking bugs. The most serious are phantom damage from supposedly released attacks and AI units becoming idle while waiting for an invalid order.

Required changes
F1 — Released callbacks can produce phantom damage

BLOCKER — Server

Your current later(u, at, fn, released) system separates released and unreleased actions at scheduling time. But an attack may be scheduled before its projectile is actually released.

Example: Colossus Boulder is released at 2.55 seconds. If its future hit callback is marked released=true when the attack starts at 0.00, a death or legitimate cancellation at 1.00 could leave that callback running even though the boulder was never thrown.

Sun has a related problem: its post-impact burn ticks are classified as a released hazard, but that hazard must not exist unless the 3.20-second impact actually occurs.

Required changes:

All future attack callbacks initially belong to an unreleased atkId.

At the actual releaseAt, atomically create or activate the released projectile/hazard and transfer ownership of subsequent callbacks to it.

Released callbacks must verify their projectile/hazard exists and remains valid.

cancel(u) must invalidate all unreleased callbacks for the cancelled attack, without destroying legitimately released effects.

Use atkId validation for each unreleased callback, not solely a global unit cancellation flag.

Tests: Boulder cancelled at 2.50 versus 2.60; Sun defeated at 3.15 versus 3.25. No projectile or burn damage may originate from an attack cancelled before release.

F2 — Pending orders must not freeze otherwise functional AI

BLOCKER — Server

R2 states that while a valid pending order exists, passive and auto attacks do not start—even when the target is temporarily out of range.

That means a Twin could stand idle for seven seconds waiting for an impossible Sticky order rather than using available Slaps.

Required changes:

Process pending orders before passive/auto attacks on every tick.

If the queued order is executable now, start it and suppress passive/auto selection.

If it is blocked solely by the current commitment or intentional group stagger, retain the reservation.

If it is currently invalid because of range, facing, line of sight, or unavailable target, allow ordinary passive/auto behaviour while retaining the order for later revalidation.

If the target is permanently invalid, clear the order immediately instead of waiting for expiry.

Keep the order's priority on the next eligible server tick, but do not forcibly interrupt the new passive attack.

The seven-second expiry is acceptable as a policy, not a guarantee that every accepted order will execute. Long commitments, stuns, and target invalidation can still prevent execution.

This is a deliberate tradeoff: maintain responsive autonomous combat rather than allowing a pending order to paralyse the unit.

F3 — Order identity and cooldown refund are not race-safe

HIGH — Server

u.pendingOrder = { group, notBefore, expires } lacks enough information to preserve the actual command.

Re-running orderFor(u, now) could select a different ability or target from the one originally ordered.

The proposed refund (group cooldown = now + 1) can also overwrite the cooldown of a newer order.

Required changes:

Store:

{ issueId, groupId, abilityId, targetId, issuedAt, notBefore, expiresAt }

Then:

Revalidate the original ability and target; never silently substitute a different order. Retargeting must be an explicit ability rule.

Track each group's issueId, pending participant count, and successful cast count.

Reserve the group cooldown on issuance; commit it on the first successful cast.

If every participant fails without casting, release only that issue's reservation. Keep the proposed one-second reissue throttle separately.

Never let an old issue refund or overwrite a newer issue's cooldown.

Resolve each pending order exactly once: executed, expired, superseded, or invalid.

This prevents lost commands, double refunds, and accidental changes to the player's intended attack.

F4 — Authorized interrupts cannot use the ordinary start gate unchanged

BLOCKER — Server

canStart() rejects starts while now < commitUntil.

That is correct for normal attacks, but a Drip attempting an authorized dodge during Cling will fail the same check.

Your interrupt(u, reason) cancels the old action, but the proposal never explicitly clears its commitment or authorizes the replacement attack.

Required changes:

Use one centralized requestAttack(u, attack, now, interruptReason?) dispatcher.

For an authorized interrupt:

Verify the exact permitted transition: Cling → Boing/Squash, Chip → Curl.

Capture the old atkId.

Cancel its unreleased callbacks and emit its cancellation event.

End the old body commitment.

Start the replacement attack atomically, assigning a new atkId.

Validate and count any unauthorized bypass attempt.

Shake-off ends the rider's action without necessarily starting a replacement. Defeat ends the action without starting another.

Use a unit spawn generation alongside atkId so a late event from a dead unit cannot affect a replacement unit that reuses its identifier.

The start gate must perform its own validation, not rely exclusively on callers having checked canStart() earlier.

F5 — Client instance isolation and event ordering are incomplete

BLOCKER — Client

table.clone(st.ctxTemplate) is a shallow copy. Nested tables remain shared, as do closures that capture mutable unit-level state.

Consequently, two supposedly independent instances could still overwrite one another's animation markers or delete each other's effects.

There are also two timing problems.

First, pinning effects at bodyEnd is too late. Boulder releases at 2.55 seconds but its body continues until 4.70. Its projectile origin must be captured at release, not after the arm recovers.

Second, an atkId protects cancellation lookup but does not automatically protect against out-of-order attack events. An older attack packet must not regain ownership of the pose after a newer attack has started.

Required changes:

Give each instance an independent mutable context, FX container, event cursor, and cleanup owner. Shared immutable helpers may remain shared.

Audit helper closures for captured references to st.ctx, st.fx, or other mutable attack-level state.

Capture projectile origins and world-effect anchors at their actual release/impact times. After release, world effects must not follow the unit's bones.

Allow only the highest valid atkId to own the current body pose. Older valid released FX may still finish independently.

Store cancellation tombstones so a cancel received before its attack event is still applied.

Track the last processed effect timestamp and fired-event index; late packets must not replay old emissions or sounds.

Also change the shield message from:

{ id, "shieldEnd" }

to something that identifies the actual state instance, such as:

{ unitId, spawnGen, stateId, sourceAtkId, endAt }

A late shield-end event must never remove a newer shield or guard aura.

F6 — Timing manifest needs a stricter completion definition

HIGH — Animation and performance

The manifest approach is correct, including sampling the procedural extra, limbs, post, and place functions.

But the definition of bodyEnd must be:

The first time the entire committed body action has reached its intended exit pose, including procedural corrections and recovery blending.

Merely finding the last animation key is insufficient.

For example, your previous specification allowed a 0.25-second pose blend after lock. R2 lists both Colossus Slam and Titan Slam as having bodyEnd = lock = 3.40. Verify their actual body animation is genuinely complete at 3.40. If an additional blend is still occurring, the commitment must include it.

Required:

Complete all manifest entries with explicit moveFreeAt, bodyEnd, fxEnd, hit windows, and applicable release events. Entries such as Pincer Block, Drip Bombs, and Pebble Roll must use the same schema.

Verify pose continuity at the next attack's first rendered frame, not just at the final key.

Distinguish an attached body effect from a projectile or hazard after release.

Stop pose ownership at bodyEnd even if the same attack instance keeps FX alive longer.

Measure maximum live emitters, parts, sounds, and memory—not merely instances and particles per second.

The expectation of three or fewer active instances per unit is not an enforced bound. It must be measured, and cleanup must be verified.

I would also require explicit owner acceptance of the proposed combat changes, especially Sun +3.0 seconds, Boulder +2.1 seconds, and Sticky +2.35 seconds of commitment. Those are significant enough to change the power graph.

Additional mandatory tests

Your existing tests are good. Add these before accepting the implementation:

Scenario

	

Pass condition




Dodge while still committed

	

Authorized dodge executes; old body action and unreleased damage end




Order remains out of range for 5 s

	

Passive AI continues fighting




Order is superseded during a refund

	

Newer order cooldown remains unchanged




Cancel arrives before attack event

	

No cancelled attached effects appear




Older attack arrives after newer attack

	

Older attack never takes pose ownership




Boulder releases before body recovery ends

	

Projectile continues from captured world position




Shield expires, then a newer shield starts

	

Old shieldEnd does not remove new aura




32v32 sustained combat

	

No leaked instances, bounded FX costs, stable mobile frame pacing




Attack with final post-lock blend

	

No abrupt pose replacement on the first eligible next attack

For the 32v32 test, use the full 64-unit maximum, not just the proposed 32-Drip swarm.

Final decision

Area

	

Verdict




Per-attack timing manifest

	

SOUND WITH CHANGES




Central server start gate

	

SOUND WITH CHANGES




Authorized interruption model

	

SOUND WITH CHANGES




Order queue and priority

	

SOUND WITH CHANGES




Client attack instances

	

SOUND WITH CHANGES




FX lifecycle classes

	

SOUND conceptually




Existing test plan

	

SOUND WITH CHANGES

Overall: SOUND WITH CHANGES — six fixes required before implementation.

There is no longer a fundamental architectural reason to reject the design. I would not request an r3 conceptual redesign.

The most important corrections are F1, F2, F4, and F5. F3 and F6 can be implemented alongside those fixes, but must be resolved before merge.

For this test place, the acceptance standard should be:

Zero unauthorized body interruptions, zero stale server hits, zero invalid order cooldown mutations, zero effects terminated before their valid lifetimes, and no unit rendered idle for several seconds solely because an unavailable order is queued.

If those invariants survive the targeted tests and full 32v32 stress test, the implementation is a candidate for ROBUST. The design itself is not yet proof of robustness.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High