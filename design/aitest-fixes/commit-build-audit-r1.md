It's now BUILT from your r2 design (the owner approved the balance cost). The attached commit-build-r1.md describes the implementation (server start gate + attack ids, release hand-over, interrupts, order queue, shield end; client attack instances) and the measurements (24v24 and 32v32 fights, balance before/after). Please audit the BUILD: try to break it, verdict ROBUST / ROBUST WITH CHANGES / NOT ROBUST with exact changes.
Worked for 4m 25s
ChatGPT said:
Alien Fusion — Attack Commitment Build r1 Audit
NOT ROBUST

The build has made substantial progress, but I would block the merge. The 24v24 and 32v32 measurements are encouraging, and the haste correction is sensible. However, the implementation still has several paths where attack ownership, cancellation, or visual lifetime can become inconsistent.

I found five merge-blocking issues, plus three additional changes required before I would call this robust.

The biggest concern is that your counters prove the tested fights ran without observed overlap or early FX termination. They do not yet prove the lifecycle is correct under cancellation, death, callback ordering, or delayed client events.

F1 — The server's single start gate is a detector, not a gate
BLOCKER

Your implementation says:

Lua
if anim ~= "Defeat" and t < (u.commitUntil or 0) then
    bump("AITestIllegalOverlaps")
end
u.atkId += 1
u.curAnim = anim

It counts an illegal start but still executes it.

A future change to an auto, a queued-order path, or a forgotten direct playAnim call can violate commitment. Worse, the current attack's unreleased callbacks then become stale because its atkId changes.

Required change: Make the invariant enforce itself.

Lua
if not authorisedInterrupt
    and now < (u.commitUntil or 0) then
    bump("AITestIllegalOverlaps")
    return nil
end

Every ordinary attack must also pass alive, stun, AI-state, busy, and eligibility checks inside the central dispatcher—not merely in callers.

The interrupt path should validate the old animation, new animation, and reason before atomically replacing the old attack.

Keep the diagnostic counter, but a failed check must never create a new attack ID or send an atk event.

Regression: Force a direct ordinary attack start halfway through Sun. Expected: rejected, existing atkId unchanged, Sun continues, original hit remains valid.

F2 — Released attack state is being confused with cancellation permission
BLOCKER

Your cancel event sends gone when an attack with a release time has passed that time.

On the client, a gone cancellation avoids tombstoning or terminating the instance.

That's the wrong distinction.

Consider Boulder:

At 2.55 s, the projectile releases.

At 2.60 s, the Colossus dies.

The projectile should continue.

But the Colossus's remaining attached body animation and unreleased effects must end.

The existing gone flag effectively describes the entire attack as released. Only the released projectile is independent, not the whole attack.

Required change: Separate body cancellation from released-effect survival.

Every interruption must terminate the old body's ownership, including after release. Detached world effects survive only if individually handed over.

Replace the single gone decision with resource-specific ownership:

BODY_ATTACHED: cancel on interruption.

CAST_UNRELEASED: cancel, including pending hits.

WORLD_RELEASED: survive according to its own lifetime.

STATE_INDICATOR: follow authoritative state.

Always tombstone a cancelled attack's body ownership. Do not tombstone already released world effects merely because their source body was cancelled.

Use the actual completed handover record, not just now >= t0 + releaseAt, to decide what has been released.

Regression: Kill Boulder at 2.50, 2.55, and 2.60 seconds. Verify both server damage and client visuals, including the exact release-tick ordering.

F3 — Cancelling the current attack can orphan its FX
BLOCKER

The supplied client sequence is:

Lua
if currentAttackId == cancelledId then
    st.aiCur = nil
end

endInstance(st, cancelledId, gone)

But endInstance is described as stopping a detached instance. The current instance still owns st.ctx and st.fx.

This produces a dangerous sequence:

Drip begins Cling and creates attached effects.

Drip dodges, interrupting Cling.

Cancel sets st.aiCur = nil.

The replacement Boing starts with a fresh FX list.

The cancelled Cling's old FX handles may have lost their cleanup owner.

The zero-FX-parts result nine seconds after clearing the battlefield does not prove this is safe. Despawning the entire unit can destroy leaked effects without exercising the normal cancellation cleanup path.

Required change: Look up the instance first, clean up its unreleased attached resources, and only then remove its pose ownership.

Lua
local inst = findInstance(st, cancelledId)

if inst then
    cancelAttachedFx(inst, 0.12)
    detachReleasedFx(inst)

    if st.aiCur == inst then
        st.aiCur = nil
    end

    removeInstanceIfEmpty(st, inst)
end

Do not use a blanket stopFx on an instance that contains legitimate released world effects.

Regression: Interrupt Cling at 0.10, 1.50, and 3.20 seconds. Count attached FX handles before cancellation, immediately afterward, and 0.15 seconds later. The cancelled resources must reach zero without requiring unit despawn.

F4 — shieldEnd can remove the wrong effects or arrive before its attack
BLOCKER

Two distinct issues remain.

First: The client calls endInstance for shieldEnd, and potentially stopFx when the affected instance is current.

A shield-state termination should remove the shield aura, not necessarily every cosmetic effect belonging to Thump.

Second: Marks are processed before that frame's newly received attacks.

Force the following packet batch:

atk Thump, atkId=15, time 10.00

shieldEnd, atkId=15, time 10.20

If both arrive before the client's next render update, your mark-first processing can consume shieldEnd before the Thump instance exists. The attack can subsequently create an aura for a shield that is already gone.

Required changes:

Give each shield application a unique shieldStateId.

Capture that state ID in the shield's expiry callback, rather than reading a potentially overwritten u.shieldAtk.

On the client, terminate only the matching aura handle.

Persist ended-state tombstones so a later-created instance cannot resurrect an expired shield.

Process attack creation and state transitions in timestamp order, using a defined tie-breaking rule.

For example, a late shieldEnd for state 15 must not affect a newer shield state 19.

Regression: Deliver shieldEnd before its atk event, then test two consecutive shield applications with the first one's timeout arriving after the second shield starts.

F5 — Haste may still desynchronise server hits from animated contact
BLOCKING VERIFICATION

You fixed the visible early-replacement bug by sending playback speed and scaling body commitment.

But the report does not establish whether the server's damage callbacks use that same time scale.

For example, with a cadence multiplier of 0.80, a hit authored at 0.80 seconds should execute at 0.64 seconds if the entire attack timeline is accelerated. If the client moves its attack clock but the server schedules the hit at 0.80, the strike appears 160 ms before damage.

At 20 Hz, that's more than three simulation ticks.

Required change: Use one per-cast cadence value consistently for applicable body keys, server hit windows, and attack-relative FX events.

For any attack-relative timestamp:

Lua
effectiveDelay = authoredDelay * cadence

For projectiles, distinguish a scaled pre-release wind-up from an independent post-release flight time. Do not blindly speed up world projectile travel.

The existing RELEASE moves are not reported as hasted today, so I am not asserting they currently fail. The missing proof is for hasted melee hits.

Regression: Run Pound at cadence 1.00 and 0.80. Log server hit time and client contact time. Require their discrepancy to remain within one simulation tick (50 ms), excluding a separately measured network/render interpolation offset.

Additional required changes
F6 — Freeze the queued ability identity
HIGH

The pending order captures an issue, group, and target, but not an explicitly selected ability. It re-evaluates orderFor at execution.

If each group deterministically maps to exactly one allowed ability for that unit, this is fine. Otherwise, the executed ability may differ from the reserved ability.

Store abilityId in the reservation or prove that orderFor is restricted to the original group's intended cast.

Also verify that a newly issued order does not allow an old issue's refund, expiry callback, or dead participant to alter the new issue's cooldown.

The target-change path that allows AI to keep fighting is a good correction. Keep it.

F7 — Mobile performance is not established
HIGH

Your 32v32 measurements are:

Studio average

32 FPS

Worst frame

64 ms

Studio memory

1.2 GB

This does not demonstrate acceptable performance for a phone-heavy audience.

Test at least one representative midrange Android device and one iPhone at 64 units for three continuous minutes.

Suggested minimum acceptance thresholds:

Sustained average at least 30 FPS on the representative midrange devices.

95th-percentile frame time at most 50 ms.

No monotonic growth in live FX handles or memory across repeated casts.

No missing gameplay-critical beams, projectiles, or state indicators under cosmetic budget pressure.

If these fail, optimize or reduce cosmetic FX first. Do not shorten committed attacks or delete essential attack telegraphs to recover frame rate.

Studio's 1.2 GB measurement is not directly equivalent to mobile-process memory usage.

F8 — The most important adversarial tests are missing
HIGH

Your measurements show zero StaleBlocked actions. That is not a meaningful success unless you deliberately generated stale callbacks.

Similarly, no death-before-release test was run.

Add the following deterministic probes:

Forced situation

	

Required result




Boulder owner dies at 2.50 s

	

No projectile or subsequent damage




Boulder owner dies at 2.60 s

	

Released projectile survives and resolves correctly




Cancellation on the exact release tick

	

Deterministic result according to defined event ordering




Ordinary playAnim called during Sun

	

Rejected without changing atkId




Dodge interrupts Cling with a pending hit

	

At least one stale hit is demonstrably blocked




Client receives cancel before attack

	

No cancelled body animation or attached FX




Shield end arrives before Thump attack

	

Aura never resurrects




Queued unit dies before casting

	

Reservation resolves once; cooldown accounting remains correct




64-unit fight lasting three minutes

	

No accumulating FX ownership or frame-time degradation

For the stale-hit test, explicitly require StaleBlocked >= 1 and invalid damage events = 0. A zero counter without an attempted violation is insufficient.

What passed the audit

I would retain the following implemented decisions:

Keys-derived body commitment instead of locking to complete FX duration.

Independent released callbacks that can survive their owner's death.

The restricted Drip/Pebble dodge interruption table.

One pending order per unit, with an issue-scoped group cooldown.

Permitting ordinary AI combat when an order cannot currently target its intended enemy.

Separate client attack instances and future timed FX dispatch.

Speeding up hasted body playback to match its shortened commitment.

The balance measurements also show that the proposed changes are consequential: the Colossus now wins against twelve Drips with substantially less health. Because the owner explicitly accepted that tradeoff, I am not treating it as a merge blocker.

Final verdict by subsystem

Subsystem

	

Verdict




Server body commitment

	

FIX F1




Projectile release handover

	

FIX F2 + TEST F8




Authorized interruption

	

FIX F2/F3




Queued orders

	

PASS WITH F6 CHECK




Client FX ownership

	

FIX F3




Shield-state lifetime

	

FIX F4




Hasted attack timing

	

VERIFY F5




24v24 combat

	

PASS observed test




32v32 functional stress

	

PASS observed test




32v32 mobile performance

	

UNPROVEN — F7

Verdict: NOT ROBUST.

The implementation has achieved its primary visual goal in the measured fights, but F1–F4 are serious enough that I would not ship this build. F5 also needs targeted confirmation rather than an assumed pass.

I would not redesign the system again. Apply these localized fixes, run the adversarial probes, and retain the architecture.

One evidence limitation: the attachment contains implementation excerpts and reported measurements, not the complete Lua modules or raw test logs. The counterexamples above follow the described code paths; confirming every one against the executable source requires a code-level follow-up audit.

The next build should be judged primarily on cancellation correctness, release ordering, and resource ownership—not on another ordinary 60-second fight with zero overlap counters.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High