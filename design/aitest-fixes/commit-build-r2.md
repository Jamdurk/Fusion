BUILD AUDIT r2 ("attacks always play out"). Your r1: NOT ROBUST (F1-F4 blockers, F5 verify, F6-F8). Every point below with the change and a FORCED probe (test hooks that arm a probe at an exact server time into a chosen attack, so client lag can't spoil the timing). Verdict + exact changes; say plainly if ROBUST for this test place.

== F1 ENFORCED GATE ==
playAnim: `if anim ~= "Defeat" and t < commitUntil then bump(IllegalOverlaps); return nil end` (no new id, no event). PLUS a `gate(u)` check as the FIRST line of every start function and every Order start closure (13 entry points: startSlam / startLob / startCling / startMelee / tryAuto + 8 orders), before they touch any state (busy, pinned, riding, cooldowns). Authorised interrupts (dodge from its own Cling / Chip, shake-off, defeat, a carrier's death) end the commitment first via interrupt().
PROBE 1: forced an ordinary Slam 1.0 s into a Colossus Sun -> refused (IllegalOverlaps +1), NO new attack event, the Sun's atkId unchanged, the Sun's hit landed at 3.2.
PROBE 2 (deliberate violation): dropped a Colossus's commitment WITHOUT a cancel 0.5 s into a Slam and started a second Slam -> the first Slam's unreleased hit was blocked as stale: StaleBlocked +1 (the counter's first non-zero, as you required).

== F2 RELEASE vs BODY ==
Server: the hand-over action (at RELEASE time, itself an unreleased cast action) sets hitP.released AND u.releasedAtk = that attack's id; a cancel reports gone = (u.releasedAtk == u.atkId): the hand-over RECORD, not the clock.
Client: a cancel ALWAYS ends the body (pose ownership + every attached effect). Effects carry the attack time they were created at (f._t); an effect that later becomes the projectile declares it (f.worldAt: the Boulder's rock is one effect from the rip at 0.80 to the impact, worldAt = 2.55). On a "gone" cancel only effects with f._t >= release or f.worldAt <= release survive (a detached instance that fires only events at/after the release); everything else stops now. A non-gone cancel stops everything and tombstones the id.
PROBE 3 (Boulder thrower defeated at an exact time into the throw): +2.50 -> gone=false, no hit (Pebble 100 hp); +2.55 (the release tick) -> the defeat ran before the hand-over action in that tick -> gone=false, no hit (ordering rule: a pending action at time T runs in the Heartbeat pass that reaches T; a probe / remote command at the same T may run first; the record decides, consistently on server and client); +2.60 -> gone=true, the hit landed (Pebble 0), and on the client the rock kept flying after the defeat and was cleaned up afterwards (rock parts seen after the cancel; 0 Boulder parts left later).

== F3 CANCEL CLEANUP BY ITS OWNER ==
The current attack's cancel: st.cancelled[id] = "cut"/"gone"; aiCur = nil; the switch (same frame if the replacement arrives, else next frame) runs detachOrStop, which stops (cut) or splits (gone) the CURRENT st.fx: owned cleanup, no despawn needed. A detached instance's cancel: endInstance splits / stops it.
PROBE 4 (a Drip dodging out of its Cling at an exact time, 3 runs): dodge at Cling +0.10 / +1.50 / +3.20 -> the cancel + Boing at that time; bites landing on the carrier between the cancel and the Drip's NEXT attack's first bite: 0 / 0 / 0; the cut Cling left no detached instance; the Drip's live effects 0.6 s later = only its Boing's.
PROBE 5 (cancel BEFORE its attack): the server sent `cancel id N` then started attack id N -> the client skipped it (AiSkipped +1), never played it.

== F4 SHIELD STATE ==
Server: shield(u, amount, dur, src) with src = { caster id, caster's Thump atkId }; a newer cast takes over u.shieldSrc; shieldEnded sends { unitId, "shieldEnd", t, casterId, casterAtkId } once when that unit's shield is used up or times out. Client: marks and new attacks are processed in TIMESTAMP order (tie: the mark first); shieldEnd -> Attacks.endShield(model, "caster:atk"): the shell (owned by the shield manager, not by the Thump's effects) fades in 0.18 s only if that cast still owns it (src == key; a newer cast that took it over is left alone) and the pair is TOMBSTONED, so a shell that cast hasn't drawn yet is never created (the Thump FX key = its caster's AiId + its own atkId, set on the attack's ctx).
Found and fixed while testing: the Thump FX also shelled ENEMY units within 8 studs (the server only shields friends) -> friends only now (same Team attribute, not "ALL", like the server's friendly()).
PROBE 6 (shield end BEFORE its Thump): the server sent shieldEnd for the Brute's next Thump id, then forced that Thump -> 0 shell parts appeared. Control (a normal Thump): the shell appears (6 parts) and ends with the server's timeout (6.85 s). Early break (2 Rams break the 70 shield): shell parts: 6 appear; ALL gone 0.51 s after the shieldEnd arrives (0.35 s render delay + 0.18 s fade); no enemy shells.

== F5 HASTE TIMING ==
Server melee: hit at hitAt x cadence, commitment body x cadence; client plays the attack's whole timeline (keys and its events) at speed = 1 / cadence.
PROBE 7 (Brute Pound swing start -> server hit, from the target's hurt events): normal 0.60-0.61 s x13 (expected 0.60); hasted 0.50-0.51 s x4 (expected 0.50). Within one 20 Hz tick. The client's contact is at hitAt / speed on the same attack clock. No RELEASE move is hasted.

== F6 ORDER IDENTITY ==
Each unit has exactly ONE Order (kit.order); a reservation can only ever start that one; for the two aimed at the brain's target (beam / lane) the SAME target is required. resolveOrder refunds only when the issue that reserved is still the group's latest issue (never a newer issue's cooldown). A dead participant resolves "invalid" exactly once.

== F7 PHONE PERFORMANCE ==
Agreed: unproven, a release gate for the owner's phone test (midrange Android + iPhone, 64 units, 3 min). Studio measurements below are PC only.

== F8 STRESS ==
Sustained ~3 min with waves topped up every 30 s (64 at start, 12-46 alive at the samples): 27-28 fps, p95 frame 48-50 ms, worst 57-91 ms, live attack effects 0-17 (bounded), client memory 1792 -> 1833 MB over 3 min (+41 MB; 1822 MB after clearing: mild, flagged); IllegalOverlaps 0, StaleBlocked 0 (no forced violations in that run), FxCutEarly 0, detached instances per unit <= 1; Orders: executed 209, expired 3, invalid 14, superseded 0; 0 FX / shell parts left 9 s after clearing.
Earlier: mixed 24 v 24 x2 and 32 v 32: same zeros.

Known, not changed: a Gore that misses server-side still shows its contact burst (earlier audit); a hasted attack's hurt flinch rides the sped-up clock (<= 0.1 s for 20 % haste).
