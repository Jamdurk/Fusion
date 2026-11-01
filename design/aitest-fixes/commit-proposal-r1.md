DESIGN AUDIT BEFORE BUILDING: "attacks always play out" (Alien Fusion AI test place). Not built yet: please find what's wrong with this plan, then give a verdict (SOUND / SOUND WITH CHANGES / UNSOUND) and exact changes.

James (owner), watching AI fights: "with the Colossus sometimes his Sun Shot cuts abruptly... make it so AI has to commit and finish an attack before doing another, so they all fully play out."

== How it works today ==
Server (20 Hz, authoritative): an attack start sets u.busyUntil = t + lock and fires an "atk" event { id, name, t0, aim, target }. lock = "body free" from the specs; the unit may walk after it, and the passive / auto / order may start the NEXT attack as soon as now >= busyUntil (plus its own cooldown).
Client: draws each unit 0.35 s behind; the CURRENT attack is the newest atk event; it plays while rt - t0 < atk.dur. When a NEW atk event becomes current: stopFx(st) kills every live effect of the previous attack (and clears its ctx state: sun / slam / rock markers), then the new attack starts.
The specs' timing contract has three clocks: server hit, body free (= lock), effects end (= dur). The batch-1 spec says: "After the lock the pose blends back in 0.25 s; projectiles, beams and burns keep playing at their captured world spots."

Per attack, lock vs dur (effects end):
  Colossus: Slam 3.4 / 3.8; Boulder 2.6 / 4.7; SUN 3.2 / 6.2 (hit 3.2: the beam lands exactly at the lock)
  Titan: Slam 3.4 / 3.8; Bomb 2.6 / 5.9 (puddle 3.40-5.55); Wave 3.2 / 5.3
  Brute: Pound 1.02 / 1.25 (cycle 1.25); Grab 1.65 / 2.0; Thump 1.40 / 6.98 (6 s shield aura)
  Ram: Gore 1.05 / 1.25 (cycle); Stamp 1.16 / 1.35; Charge 2.5 / 2.6
  Twin: Slap ~0.56 / cycle 1.0; Sticky 0.85 / 3.2 (puddle); Boing 1.25 (server 1.85) / 1.85
  Pincer: Snap 0.58 / 1.0 (cycle); Block 3.55 guard; Sweep 1.08 / 1.35
  Drip: Cling 3.32 / 3.32; Boing (dodge) 0.70 / 0.95; Squash 0.80 / 0.95; Bombs 3.07 / 3.07
  Pebble: Chip 4.74; Curl 1.11; Roll 1.85

== Root causes found (code read) ==
C1 CLIENT: stopFx on every new attack. Any attack whose effects outlive its lock (Sun beam 3.2 -> 6.2, Boulder, Bomb, Wave, Thump aura, Sticky puddle, the Slam's last 0.4 s) is cut off the moment the unit starts its next attack. This is James's "Sun cuts abruptly": the Colossus is free at 3.2 = beam impact, its passive slam starts as soon as a target is in its wedge.
C2 SERVER: group ORDER race. tryOrders checks orderFor(u) (which requires now >= busyUntil) and then schedules the start 0.06-0.30 s later (a staggered group cast) with later(owner, at, start, released=true). The start function does NOT re-check busy, so if the unit started its passive / auto in between, the order starts on top of it: that attack is cut mid-swing (its pending hit still lands, released or not).
C3 SERVER: by design some moves cancel the unit's own current move: the Drip's BOMBS order and the Pebble's ROLL order call cancel(u) (dropping their own Cling / Chip mid-bite); reactive autos: the Drip's dodge (Boing / Squash) cancels its Cling when a giant's slam is coming; and the anti-cling shake-off (our r4 audit) cancels a rider.
C4 Defeat interrupts everything (correct, terminal). Hurt is additive (never cuts). Stun: giants immune; little ones' stun delays their next action but plays no anim.

== Proposed changes ==
P1 (client) EFFECTS ALWAYS PLAY OUT: on a new attack, the previous attack's live effects are NOT stopped. They move to st.linger = { fx list, t0, dur } and keep stepping on their own clock (now - t0) until that attack's dur, then stop. Only Defeat / despawn stops lingering effects. The per-unit ctx state the old effects read (sunAt / slamAt / marker) is snapshotted into the linger record before the new attack resets it. The shared FX budget (34 particles/s per client) still applies to everything.
P2 (server) BODY COMMIT: no new attack (passive / auto / order) may START until the current one's body has finished: u.commitUntil = t0 + lock + 0.25 (the lock plus the spec's 0.25 s blend-back). Walking after the lock is unchanged.
P3 (server) ORDER RACE: the delayed order start re-checks: if the unit is busy / committed / stunned / dead at its start time, it waits (re-try every tick) up to 1.0 s, then is dropped and the order's cooldown is NOT spent for that unit (or: spent?). Never starts on top of another attack.
P4 (server) WHAT MAY STILL INTERRUPT (proposal): Defeat; the Drip's / Pebble's reactive DODGE family (Boing, Squash, Curl: they are the survival counterplay vs a giant's slam, ~1 s, and only interrupt their own Cling / Chip); the anti-cling shake-off (forced by the carrier). NOT allowed any more: Drip BOMBS and Pebble ROLL orders cancelling their own Cling / Chip: they wait until it ends (<= 3.3 / 4.7 s) like every other move.
P5 Rejected alternative: commit to the FULL effects end (dur) before any new attack. That would freeze a Brute 7 s after Thump (its 6 s shield aura), a Twin 3.2 s after Sticky, a Titan 5.9 s after Bomb: a big power-graph change for lingering world effects that are not the body. P1 shows them in full instead.

Expected gameplay effect: +0.25 s per attack cycle at most (P2), orders no longer clip, Drip / Pebble orders start up to ~3-4.7 s later when they were mid-cling.

Measurement plan (after building): a client log of every attack that is replaced before its dur ("cut"), with how much of it was left and whether its effects lingered; before vs after in the same mixed 12 v 12 fights + a Colossus-only fight with its Sun; plus a server log of order starts deferred / dropped by P3. Target: 0 body cuts except Defeat / dodge / shake-off; 0 effects stopped early.

CHECKED since: the Sun is a SKY beam (a mini sun summoned 30 up, 16 ahead; the beam falls onto a spot 26 ahead), so P1 shows it in full regardless of the body. BUT its body keys keep animating after the lock: the raised gauntlet comes down over 3.20 -> 3.70 -> 4.90 (arms 15/85 -> 5/25) and settles at 6.20. So "lock + 0.25" would still clip the Sun's arm recovery. Alternative P2': commit = a per-attack BODY END (the time its pose keys return to rest, read from each attack's keys: Sun ~4.9, others mostly lock .. lock + 0.4), not lock + 0.25.

Questions: P2 (lock + 0.25) or P2' (per-attack body end from the keys) as the commit point; should the order keep its cooldown when deferred / dropped; is the P4 exception list right; any risk in P1 (effects reading shared ctx state, budget, effects that assume the body is still in the pose)?
