Share
You said:
commit-proposal.md
Document
Please audit the attached design (commit-proposal.md) BEFORE I build it, as a hard-nosed senior Roblox gameplay engineer. It's about making every AI attack fully play out instead of being cut off. Find what's wrong or missing, then give a verdict (SOUND / SOUND WITH CHANGES / UNSOUND) with exact changes. Text only.
Worked for 3m 58s
ChatGPT said:
Design audit: Alien Fusion — Attack Commitment
UNSOUND AS WRITTEN

The architecture is salvageable, but I would block implementation of P1–P4 in their current form.

The proposal correctly identifies the central problem: attack animation, body availability, and lingering effects are three different lifecycles. Treating them as one is why the Colossus's Sun Shot gets cut short.

However, the proposed fix has several serious holes:

P1 preserves existing effects, but does not guarantee their future animation or emissions continue. It can also leave cancelled attacks or destroyed shields visibly active.

P2's fixed 0.25-second recovery is wrong. P2' is closer, but the Sun's body animation does not actually finish at 4.9 seconds as currently authored.

P3's one-second order timeout defeats the entire purpose. A queued order can expire while correctly waiting for another attack to finish.

P4 permits interruptions without defining what happens to pending server hits, client animation, and released projectiles.

There is no unified enforcement point. Fixing delayed orders alone does not establish the invariant that every ordinary attack start respects commitment.

These are functional correctness problems, not polish. In particular, the current design could make an attack look complete while its damage is wrong, or keep showing an attack that has already been cancelled.

The correct approach is per-attack body commitment, independently owned effect timelines, centralized server attack arbitration, and explicit cancellation semantics.

Required changes before build
1. Replace P2 with a genuine per-attack body-end contract

Severity: BLOCKER

Use P2', but do not simply read a nominal end time from the existing animation and assume it is correct.

Every attack needs these explicit values:

Field

	

Meaning




hitAt

	

Server-authoritative hit timing or hit windows




moveFreeAt

	

When locomotion may resume




bodyEndAt

	

When all committed body animation is finished




fxEndAt

	

When ordinary cosmetic effects finish




releaseAt

	

When a projectile or independent hazard becomes detached, if applicable

commitUntil = t0 + bodyEndAt.

The important case is Colossus Sun:

Hit: 3.20 s

Locomotion unlocked: 3.20 s

Arm substantially lowered: 4.90 s

Arm fully settled: 6.20 s

The existing animation therefore requires bodyEndAt = 6.20 s, not 4.90, if the whole motion must remain intact.

Alternatively, explicitly re-author the final arm motion to settle by 4.90 s, and use 4.90 as the body end. If you instead blend the partially recovered 4.90 pose to neutral over 0.25 s, commitment ends at 5.15 s.

Do not leave the 6.20 key in place while releasing the body at 4.90. That recreates the original visual discontinuity.

Also required: Change the client animator's lock-based blending. If it already fades the action pose at lock + 0.25, changing server commitment alone will not preserve the Sun's arm recovery.

Audit all eight forms, especially repeated-cycle Slap/Snap, Pincer Block, Pebble Chip, and sustained attack poses.

Do not assume that a cosmetic shield aura lasting 6.98 seconds implies the Brute must remain committed for 6.98 seconds.

Source: the existing timing contract and post-lock Sun keys. 
commit-proposal.md
 
commit-proposal.md

2. Replace P1's linger-record approach with independent attack instances

Severity: BLOCKER

The proposed {fx list, t0, dur} record is insufficient.

An effect that exists when the next attack begins can be preserved, but what happens to an emission scheduled 0.4 seconds later? Merely retaining existing FX handles does not execute the remainder of the previous attack's effect timeline.

Implement one AttackVisualInstance per attack event, identified by a unique attackId.

Each instance must own:

Its complete effect timeline, including future spawns.

Its own context, markers, and captured world positions.

Its emitter and effect handles.

Its independent cleanup state.

Its interruption and detachment state.

A new attack must never overwrite another attack instance's live context.

Do not assume copying sunAt, slamAt, and marker is comprehensive. Inspect every existing attack module for references to mutable unit-level state, callbacks, shared emitters, and delayed spawns.

The client should advance all live attack instances on their own timebases, including those no longer controlling the character pose.

At each transition, process the old timeline through the transition timestamp before activating the new one. Otherwise, an impact exactly at the boundary can be skipped.

3. Centralize every server attack start

Severity: BLOCKER

P3 rechecks the delayed order callback. Good, but insufficient.

Implement a single authoritative tryStartAttack entry point through which all ordinary attacks must pass:

Passive attacks

Reactive autos that do not have explicit interruption permission

Player orders

Staggered order callbacks

Internal follow-up attacks

Any future ability that starts an attack

The guard must verify the unit is alive, not stunned, not committed, eligible to perform that attack, and not prevented by a conflicting pending action.

The validation and transition into a new attack must be atomic: no yielding between successful eligibility checks and recording the new commitment.

Only an explicitly authorized interrupt path may bypass commitment.

Ensure orderFor(u) and other AI selection functions respect commitment too. They must not continue using only busyUntil.

Required invariant:

No two ordinary body-attack intervals for the same unit may overlap. Every exception must be authorized and identified by a cancellation reason.

This belongs in the common attack dispatcher, not separately in each creature's module.

4. Redesign P3: queue orders rather than polling and dropping them

Severity: BLOCKER

The proposed one-second timeout is incorrect.

Example: a Pebble is committed to a long Chip sequence when an order is issued. With a one-second retry window, the order can be dropped before the Chip completes.

Implement a per-unit pending order record with these rules:

At most one pending order per unit; a newer player order replaces an older pending order.

An accepted pending order receives priority over ordinary passive and auto attacks once the current commitment ends.

Preserve the intended group stagger of 0.06–0.30 seconds where applicable.

Revalidate target existence, range, attack eligibility, cooldown, ownership, and relevant line-of-sight conditions at actual execution, not merely at command issuance.

Use a maximum queue lifetime of 7.0 seconds for the current proposal, enough to cover the 6.20-second Sun body commitment plus scheduling margin. Do not keep orders indefinitely.

Drop invalid or superseded orders with an explicit reason, not silently.

Do not consume a unit's attack cooldown for an order that never starts.

For a shared group-order cooldown, consume it once when the first eligible unit actually casts; subsequent already-authorized participants retain their reservation. If nobody casts, consume nothing. Define resource-spending/refund behaviour consistently with that rule.

Most importantly, a pending player order must not repeatedly lose its execution opportunity to newly selected passive attacks.

5. Give interrupted attacks a formal cancellation contract

Severity: BLOCKER

P4's allowed exceptions are reasonable starting points, but the state transitions are unspecified.

Use a server cancellation message containing attackId, cancellation time, and reason.

Cause

	

Required behaviour




Normal attack completion

	

Body finishes; detached effects continue




Drip/Pebble survival dodge

	

Cancel original body action and unreleased hit windows; begin dodge




Carrier shake-off

	

Cancel Cling, stop remaining Cling ticks, detach rider




Defeat

	

End body action and unreleased hits; apply explicit policy to released effects




Stun

	

Block new attack starts; do not cancel current action unless explicitly specified




Knockback

	

Apply movement and hit-validity rules; do not implicitly cancel the action




Shield destroyed

	

End shield-state aura immediately, even before nominal FX end

For a legitimate interrupt, attached or unreleased attack visuals should be stopped or faded promptly (target 0.10–0.15 s). Already released projectiles and persistent world hazards should follow their own specified lifetimes.

Critical: Every delayed server hit must know which attack instance owns it.

A cancelled, unreleased cast must never deliver a stale hit. A legitimately released projectile must not lose its damage just because the unit started a new attack.

That distinction is essential for Bomb, Wave, Boulder, Cling ticks, and similar delayed mechanics.

Keep the proposed special dodge exception restricted to interrupting Drip Cling and Pebble Chip, unless a separate move-specific design authorizes more. Do not turn dodge into a universal commitment bypass.

6. Distinguish lingering cosmetic FX from gameplay state

Severity: HIGH

P1 assumes every effect should continue until dur. That is not universally valid.

The Brute's shield aura is the clearest counterexample. If the server removes the shield early, keeping its visible aura until 6.98 seconds falsely tells the player the protection remains active.

Use three lifecycle classes:

Class

	

Lifetime




One-shot cosmetic

	

Finishes on its original timeline




Released world effect

	

Follows the projectile/hazard's independent lifetime




Gameplay-state indicator

	

Exists only while that gameplay state is active

This also resolves ambiguity about projectiles and puddles when their owner dies or despawns.

The invariant should be: every valid effect completes its intended lifecycle—not every visual remains alive until its original nominal duration regardless of gameplay.

7. Define motion layering and bound visual workload

Severity: HIGH

P2' lets the Sun's recovery continue after locomotion unlocks at 3.20 seconds. That requires the client animator to combine continuing upper-body animation with walking, turning, and knockback.

Without explicit joint ownership or blending rules, the unit can move while its attack pose is still visually fighting the locomotion controller.

Use attack-specific joint masks or defined blend priorities. A move's locomotion unlock must not implicitly clear its remaining committed animation.

For P1, retain the 34-particles-per-second budget as a cosmetic emission budget, not as a reason to tear down critical attack visuals.

Track concurrent attack instances, active emitters, skipped emissions, and cleanup. Give readability-critical effects priority. A Sun beam or active shield indicator must not vanish because six puddles have exhausted the cosmetic budget.

Avoid allocating a new unbounded closure or emitter collection for every lingering effect on a 32v32 battlefield.

Corrected lifecycle example

Colossus SUN — preserve existing 6.20 s pose

Illustrative timeline from the supplied Sun timings. The body is committed to 6.20 s unless its recovery is explicitly re-authored.

At 3.20 seconds, the server resolves the hit and permits walking. The beam continues independently. The Colossus remains unable to start another ordinary attack while its gauntlet recovers. At 6.20 seconds, the final neutral pose is reached and the next queued action may start.

This preserves the complete current animation, unlike the proposed lock + 0.25 approach.

Required pre-merge test gates

The current measurement plan is useful but too focused on visual cuts. A before/after 12v12 comparison will not establish correctness.

Test

	

Required pass condition




Sun followed by immediate Slam request

	

No early body replacement or beam loss




Delayed group order racing with passive

	

Zero overlapping ordinary body attacks




Order submitted during Pebble Chip

	

Queued order executes after commitment if still valid; no silent 1 s expiry




Drip dodge interrupts Cling

	

No stale Cling damage, no ghost attachment




Carrier shake-off

	

No residual Cling ticks or rider reattachment through stale callbacks




Death before vs after projectile release

	

Server damage and visuals agree with the specified release policy




Shield breaks during Thump aura

	

Visual shield indicator ends with actual shield state




Two consecutive attacks within previous FX lifetime

	

Both visual instances remain valid and clean up independently




32v32 repeated casting on phone

	

Stable frame pacing, bounded FX instances, no critical effects unexpectedly culled




Late or reordered attack/cancel messages

	

attackId prevents obsolete effects or cancellation from corrupting newer attacks

Instrument four separate counters:

Illegal body overlap and unauthorized body interruption.

Intended FX emissions missed, and effects stopped before their valid lifetime ends.

Cancelled attacks that still produce invalid server hits.

Pending orders executed, expired, superseded, or rejected, with wait-time distribution.

At 20 Hz, aim to dispatch an eligible queued order within two server ticks (0.10 seconds), excluding its intentional stagger.

Finally, benchmark casts per minute, damage per minute, time-to-kill, and match outcomes before and after. The claimed maximum 0.25-second cycle increase is false if P2' is used: Sun alone may gain 3.0 seconds of commitment, from 3.20 to 6.20, unless re-authored. Actual DPS impact depends on cooldowns, but this is a meaningful balance change.

Final build decision

Proposal

	

Verdict




P1 — Preserve lingering FX

	

REWRITE — independent instances and effect classes




P2 — Lock + 0.25 s

	

REJECT




P2' — Per-attack body end

	

ACCEPT WITH CHANGES — complete pose manifest and animator alignment




P3 — Retry for 1.0 s

	

REJECT — queued, reserved orders instead




P4 — Interrupt exceptions

	

CONDITIONAL — explicit cancel/hit/release policies




P5 — Reject commitment to full FX duration

	

ACCEPT — correct architectural decision

Implementation remains blocked. I would approve the revised architecture once the per-attack timing manifest, unified server start gate, independent FX instances, and cancellation contract are specified.

One final limitation: this is an audit of the design, not the implementation. The proposal reports code-read findings but does not attach the relevant server dispatcher or attack visual modules, so I cannot certify that those are the only overlapping-start paths or shared-state dependencies.

The most important principle is: finish the body animation before starting another body attack; let released effects finish independently; never allow an interrupted cast to leave behind invalid damage. That is the contract worth building.

ChatGPT can make mistakes. Check important info.
Latest response




Thinking effort
High