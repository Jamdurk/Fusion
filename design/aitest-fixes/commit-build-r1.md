BUILD AUDIT r1: "attacks always play out" is now BUILT from your r2 design (SOUND WITH CHANGES) + the owner's OK on the balance cost. Try to break the implementation. Verdict ROBUST / ROBUST WITH CHANGES / NOT ROBUST + exact changes.

== SERVER (AITest.server.luau) ==
BODY[kit][anim] manifest (keys-derived, as in r2) + RELEASE = { Colossus Boulder 2.55, Titan Bomb 2.55, Titan Wave 2.10 } + INTERRUPTS = { Cling = {Boing, Squash}, Chip = {Curl} }.
playAnim(u, anim, ax, az, tgt, slot, scale) = THE one place an attack begins (every start path, incl. orders, dodges, shake-off, Defeat, ends here):
    if anim ~= "Defeat" and t < (u.commitUntil or 0) then bump("AITestIllegalOverlaps") end
    u.atkId += 1; u.curAnim = anim
    u.commitUntil = (anim == "Defeat") and math.huge or t + BODY[name][anim] * (scale or 1)    -- scale = haste cadence (melee)
    event({ id, "atk", anim, t, ax, az, tgtId, slot, u.atkId, 1 / (scale or 1) })              -- last = playback speed
canStart(u, now) = not dead, ai on, not stunned, now >= busyUntil, now >= commitUntil. The step: runOrder(u) first; then `if not u.brainOn or not canStart(u, now) then continue end` before auto / passive. orderFor(u, now, ifFree) uses canStart (ifFree = the queue's issue check skips it).
later(u, at, fn, released) records atkId = u.atkId and returns the record. The runner: an UNRELEASED action whose atkId ~= u.atkId never runs (bump "AITestStaleBlocked"); released ones run even if the unit died. die() no longer wipes u.pending (only cancel's unreleased drop), so a projectile already thrown still lands.
handOver(u, anim, hitP, now): if RELEASE has the anim, later(u, now + rel, function() hitP.released = true end) (itself a cast action: a cancel before release drops both). Boulder / Bomb lob hit and Wave lane hit are scheduled unreleased + handOver. The Sun beam's hit is now UNRELEASED (was released=true): cut before 3.20 = no hit and no burn.
interrupt(u, reason): event { id, "cancel", u.atkId, t, reason, gone } (gone = a RELEASE anim past its release time), cancel(u) (drop unreleased + release riding), commitUntil = 0. Used by: die ("defeat"), a carrier's death for each rider ("carrier"), shakeOff ("shake"), and mayReact.
mayReact(e, anim) for the reactive autos (Drip dodge Boing / Squash, Pebble Curl), run at reaction time: free -> cancel(e) (old leftovers), allowed; committed -> allowed only if INTERRUPTS[e.curAnim][anim] (then interrupt(e, "dodge")), else refused and its auto cooldown refunded.
ORDER QUEUE: tryOrders issues a reservation per ready unit (orderFor(u, now, true)): u.pendingOrder = { issue = { id, group, open, cast }, issuedAt, notBefore = now + 0.06..0.30, expires = now + 7, target = brain.target }; an existing reservation is resolved "superseded" first. runOrder(u, now): dead / AI off -> "invalid"; past expires -> "expired"; its target dead -> "invalid"; ripple or busy / committed / stunned -> "hold" (nothing else starts); beam / lane whose brain target is no longer the reserved one -> nil (fight on, keep the reservation); orderFor -> start(now), "executed"; else nil. resolveOrder: exactly once; when an issue ends with 0 casts and is still the group's latest issue, groupCd = now + 1 (refund); never touches a newer issue.
SHIELD: shieldBuff (Brute Thump) sets u.shieldAtk = u.atkId after shield(); damage() and the timeout send { id, "shieldEnd", t, shieldAtk } once when that shield reaches 0 / expires.

== CLIENT (AlienAnimator, AI units only) ==
Events: atk carries id + speed; "cancel" (id, gone) and "shieldEnd" (id) go into q.marks and are applied when t <= the unit's render clock, BEFORE that frame's new atk events (a cancel is always sent before its replacement).
Marks: cancel -> tombstone st.cancelled[id] (unless gone); if it is the current attack, st.aiCur = nil; endInstance(st, id, gone) stops a detached instance with that id (not if gone). shieldEnd -> endInstance + stopFx if it is the current attack.
New atk event: skipped if id <= st.aiCurId (an older attack never retakes the body) or tombstoned.
The attack's own clock te = t0 + (rt - t0) * speed (hasted swings play faster).
Switch to a new attack / end of the current: detachOrStop(st, rt): if the old attack is not cancelled and its elapsed (speed-scaled) time < its dur, it becomes a DETACHED instance { atk, t0, ctx = st.ctx, fx = st.fx, lastTT, id, speed } and the new attack gets st.ctx = table.clone(st.ctxTemplate) (a clone of the per-unit ctx taken at setup, before any attack wrote into it) and st.fx = {}; else stopFx (counter "AiFxCutEarly" if it was stopped before its end without a cancel: must stay 0).
tickDetached(st, rt) every frame: fires the instance's remaining events (ev.t > lastTT and <= tt) with ITS ctx, steps its fx with tt, cleans up at tt >= dur. Bone-reading events / effects (aura on the body) keep reading the live bones.

== MEASURED (Studio Play, AI on) ==
Mixed 24 v 24 (every form; 60 s): IllegalOverlaps 0, StaleBlocked 0, FxCutEarly 0, client-measured starts before the previous attack's body end (speed-scaled): none; Orders executed 29-33, expired 0, invalid 3-8 (target died), superseded 0, longest wait 4.0 s; max detached instances per unit 1-2. Sun cast 3x, each played 6.2 s.
First run found 2 hasted Brute Pounds starting 0.2 s before the previous Pound's 1.25 s animation ended (Thump haste: server commits 1.25 x cadence) -> fixed by the playback speed above; re-run: 8 hasted swings, 0 early starts.
32 v 32 (64 units, 60 s): 0 overlaps / stale / cut; Studio client avg 32 fps, worst frame 64 ms, memory 1.2 GB; 0 FX parts left 9 s after clearing the field (no leaks).
BALANCE (owner accepted the commit cost; reporting the size): Colossus v 12 Drips: before 26-31 s with 680-965 HP left; now 34 s with 126-167 HP left (it still wins). Titan v 12 Drips: before 26 s, 780-895 HP left; now 27-28 s, 440-615 HP left.

Known limits: Gore miss VFX (earlier audit); a hasted attack's hurt flinch timing uses the attack's sped-up clock (up to ~0.2 s early for a 20 % haste); no death-before-release targeted test (no kill command in the test place; the code path is the generic released / unreleased rule).
