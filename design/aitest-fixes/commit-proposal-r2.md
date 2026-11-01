DESIGN AUDIT r2: "attacks always play out" (Alien Fusion AI test place). Your r1 verdict: UNSOUND as written (P1 rewrite, P2 reject, P2' accept with changes, P3 reject -> queue, P4 conditional, P5 accept). This is the revised architecture, answering each blocker. Still NOT built. Verdict SOUND / SOUND WITH CHANGES / UNSOUND + exact changes.

== 0. Facts I checked in the code since r1 ==
- Server pending actions already have the released / unreleased split you asked for: later(u, at, fn, released). cancel(u) drops every UNRELEASED pending action of u (a cast's hit) and keeps RELEASED ones (a projectile / a lob in flight / a group-order start). Boulder, Bomb, Wave, Sun hits are scheduled at cast time; I will mark each one released or not explicitly (manifest below).
- Stun never cancels (it only blocks starts; giants are immune). Knockback (jump) never cancels. Defeat = die(u) -> cancel(u).
- Every start path today: step() passive (slam / cling / melee), tryAuto (lob, stunRing, pull, shieldBuff, zoneSlow, block, curl, rush ...), warnDanger reactive dodge (Drip Boing / Squash), tryOrders -> later(owner, t + 0.06..0.30, start, released = true) (the race), and shakeOff (forced, our rider fix). Bombs (Drip) and Roll (Pebble) order starts call cancel(u) on their own Cling / Chip.

== 1. Per-attack TIMING MANIFEST (P2') ==
Each kit anim gets { lock = moveFreeAt, bodyEnd, fxEnd = dur, hit times, released? }. bodyEnd = the time the attack's own pose keys reach their final rest key (read from the keys tables, below), or its cycle for the repeating passives. commitUntil = t0 + bodyEnd.
  Colossus: Slam lock 3.40 body 3.40 dur 3.80 | Boulder 2.60 / 4.70 / 4.70 (released at the throw 2.55) | SUN 3.20 / 6.20 / 6.20 (beam hit at 3.20 not released before it; the burn ticks after 3.20 are a released hazard)
  Titan: Slam 3.40 / 3.40 / 3.80 | Bomb 2.60 / 2.85 / 5.90 (released at spit 2.55) | Wave 3.20 / 3.45 / 5.30
  Brute: Pound 1.02 / cycle 1.25 | Grab 1.65 / 2.00 / 2.00 | Thump 1.40 / 1.40 / 6.98 (shield aura = a STATE indicator, see 4)
  Ram: Gore 1.05 / cycle 1.25 | Stamp 1.16 / 1.16 / 1.35 | Charge 2.50 / 2.60 (travel + place drive it to the end)
  Twin: Slap 0.56 / cycle 1.0 | STICKY 0.85 / 3.20 / 3.20 | Boing 1.25 / 1.25 / 1.85
  Pincer: Snap 0.58 / cycle 1.0 | Block 3.55 guard | Sweep 1.08 / 1.18 / 1.35
  Drip: Cling 3.32 | Boing 0.70 / 0.70 / 0.95 | Squash 0.80 / 0.95 | Bombs 3.07
  Pebble: Chip 4.74 (keys rest at 4.34; lock 4.74) | Curl 1.11 | Roll 1.85
  (Attacks with extra / limbs / post / place functions can move bones beyond their keys; I will check each of those by sampling the rendered pose and take the later time.)
Balance: commit minus today's lock = Sun +3.0 s (order, cd 28), Boulder +2.1 (auto, cd 12), STICKY +2.35 (Twin auto, cd 9: a Twin loses ~2 Slaps per Sticky), Grab +0.35, Bomb +0.25, Wave +0.25, Sweep +0.10, Squash +0.15; repeating passives unchanged (bodyEnd = their cycle = their `every`). No re-authoring now: I will report these to the owner (James) and measure casts / damage per minute and time-to-kill before / after.

== 2. ONE SERVER START GATE ==
canStart(u, now, kind) = alive, brainOn (not stunned), now >= u.busyUntil and now >= u.commitUntil, kind's own cooldown ready. beginAttack(u, anim, now, opts) is the ONLY place that starts an attack: increments u.atkId, sets busyUntil / commitUntil from the manifest, sends the atk event WITH atkId, and returns the id; every later() it schedules carries atkId and its released flag. All existing start paths call it (passive / auto / order execution); there is no yield between the canStart check and beginAttack (same 20 Hz step, synchronous). orderFor and tryAuto use canStart too (not busyUntil alone). Debug invariant counter: an ordinary start while now < commitUntil = "illegal overlap" (must stay 0).
AUTHORISED INTERRUPTS (each with a reason, via interrupt(u, reason) = cancel(u) + cancel event { id, "cancel", atkId, t, reason }):
  dodge: the Drip's Boing / Squash may interrupt ONLY its own Cling (and the Pebble's Curl only its own Chip). Not a universal bypass.
  shake: the anti-cling shake-off (Cling).
  defeat: die(u).
  Nothing else. The Drip Bombs / Pebble Roll orders no longer cancel their Cling / Chip: they queue (3).

== 3. ORDER QUEUE (replaces the 0.06-0.30 s later() race and the 1 s retry) ==
u.pendingOrder = { group, notBefore = t + stagger(0.06-0.30), expires = t + 7.0 } (7 s covers the Sun's 6.2 s commit). At most one per unit; a newer order for the same unit replaces it (reason "superseded").
Every step, BEFORE passive / auto: if a unit has a pending order, now >= notBefore and canStart(u, now, "order"): re-run orderFor(u, now) (fresh target / range / facing checks) -> if it returns a start, beginAttack it; if the order is momentarily invalid (target out of range), keep waiting until expiry. While a valid pending order exists and the unit is free, passive / auto do NOT start (the order has priority, so it can't keep losing to new passives). Expired -> dropped with reason "expired".
Cooldown: the group's cooldown is still set when the order is issued (so it isn't re-issued every tick), but if EVERY unit's pending order of that issue expires / is dropped without a cast, the group cooldown is refunded (set to now + 1). A unit's own state is never charged for an order it didn't cast.

== 4. CLIENT: ATTACK INSTANCES (replaces the P1 linger record) ==
Today each unit has ONE ctx (per-unit, reused by every attack; attack modules write per-attack state into it: sunAt / sunTarget / slamAt / rockAt / marker / gore / charge / keys / aim / hookFn ...) and ONE fx list; runAttack fires the attack's timed events (events[i].t <= tt) and steps the fx list with the attack's tt.
New: an AttackInstance { atkId, atk, t0, ctx, fx, lastTT, cls } per atk event. ctx = a fresh table.clone(st.ctxTemplate) (the per-unit fields: m, holder, FX folder, sound / bonePos / ground helpers), so no instance can overwrite another's per-attack fields. The CURRENT instance drives the pose + legs (as now). When a new attack becomes current, the previous instance is NOT stopped: it moves to st.detached and keeps (a) firing its remaining timed events (future spawns: e.g. the Sun's 3.20 BOOF and burn) and (b) stepping its fx, on its own clock (rt - t0), until its fxEnd; then cleanup. Before switching, the old instance is ticked up to the switch time first (no boundary event skipped). Events and fx that need the unit's BONES (bonePos: a fist glow, a held boulder) read the live bones; I will audit every attack's events for bone reads after its bodyEnd and pin those to world positions captured at bodyEnd if any exist.
Effect classes (your 6): one-shot cosmetic = runs to fxEnd; released world effect = its own lifetime; STATE indicator = the Brute's Thump shield aura (and the Pincer's Block guard glow): ends when the state ends: the server sends { id, "shieldEnd" } when the shield is used up or expires early, and the client stops that instance's aura then.
Cancel event (2): the client stops / fades (0.12 s) the cancelled instance's unreleased attached visuals; its released projectiles keep their lifetime.
Defeat: the current instance stops (unreleased); detached instances keep their own lifetimes; the Defeat plays.
atkId on every atk / cancel event: a late or reordered cancel only touches its own instance.
Layering (your 7): the current instance owns the pose until its bodyEnd (the server can't start another before it); after lock the server may walk the unit: the animator already plays the walk on top during an attack's tail (legs = walk; body = the attack's keys); with bodyEnd now longer for Sun / Boulder / Sticky, that tail is longer: same mechanism, the walk owns the legs, the attack owns the upper body; I will check the Sun's arm recovery while walking in stills.
Budget: the shared 34 particles/s cap stays a COSMETIC emission cap; beams / projectiles / state auras are parts, not particles, so they are not culled by it; I will count live instances per unit (expect <= 3) and log the max.

== 5. TESTS (your gate list, adapted) ==
Counters: illegal overlaps (server), unauthorised interrupts (server), stale hits after cancel (server: an unreleased pending action of a cancelled atkId that executes), FX stopped before their lifetime (client), pending orders executed / superseded / expired with wait times (server), live instances per unit (client).
Scenarios: Sun then immediate Slam request; order issued during a passive (the race); order during a Pebble Chip; Drip dodge interrupts Cling (no stale bite); shake-off; death before / after a Boulder / Bomb release; Brute shield broken mid-aura; two attacks inside the previous FX lifetime; mixed 12 v 12 and a 32-Drip swarm for budget; casts / damage per minute and time-to-kill before vs after.

Questions: is the manifest approach right (keys-derived bodyEnd, sampled for extra/limbs/post)? Is the order-priority rule (no passive while a valid order waits) right, or should passives keep going until the order becomes valid? Anything still missing before I build?
