// Alien Fusion shared AI brain (prototype for the sim; the Luau version follows the same layers).
// Layers per unit: SENSE → APPRAISE (fear vs courage) → CHOOSE TARGET (utility score) → POSITION (slot / evade / guard /
// facing) → STEER (ORCA + acceleration + turn limits). Decisions at 5 Hz (staggered), motion every tick, all units move
// from the SAME snapshot (plan for everyone, then integrate). Numbers: profiles.mjs (validated at creation).
// History: v2 = ChatGPT r1 fixes, v2.1 = r2 fixes, v2.2 = code review r3 fixes (see chatgpt-audit.md).
// Contract with the caller (sim.mjs today, ArmyAI in Luau later): units carry { x, y, r, reach, form, race, team, matter,
// alive, hp, maxHp, face } plus u.ai (owned by this module); the caller sets e.ai.attackers each tick before tick().
import { BRAIN, PREY, PREDATOR, PROFILES, validateProfiles } from "./profiles.mjs";
import { computeVelocity } from "./orca.mjs";
import { createNav } from "./nav.mjs";

const angDiff = (a, b) => { const d = a - b; return Number.isFinite(d) ? Math.atan2(Math.sin(d), Math.cos(d)) : 0; };   // constant-time wrap (r3c)
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const gapOf = (a, b) => dist(a, b) - a.r - b.r;
const lerp = (a, b, k) => a + (b - a) * k;
const clamp01 = x => Math.max(0, Math.min(1, x));
const SECTORS = 24;   // audit r1 #2: one shared angular grid per target, whatever the attacker's size

// ctx: { units, rand, DT, now(), obstacles: [{x, y, r}], dps(u, e) → damage/s u would deal to e right now }
export function createBrain(ctx) {
  const { units, rand, DT } = ctx;
  if (!(Number.isFinite(DT) && DT > 0)) throw new RangeError(`brain: DT must be > 0 (got ${DT})`);
  validateProfiles();
  const nav = ctx.obstacles.length ? createNav(ctx.obstacles) : null;
  const ringOf = (u, e) => e.r + u.r * 0.9 + u.reach * 0.5;
  const spacing = (u, e) => u.ai.prof.spreadVs?.[e.form] ?? u.ai.prof.slotSpacing ?? 1;
  // how many of the target's 24 sectors one attacker covers (a Drip on a Titan: 1; a Brute on a Pack: 4)
  const need = (u, e) => Math.max(1, Math.ceil(2 * u.r * spacing(u, e) / (2 * Math.PI * ringOf(u, e) / SECTORS)));
  let nextId = 0;

  function init(u) {
    const [r0, r1] = BRAIN.reactRange;
    u.ai = {
      id: nextId++, prof: PROFILES[u.race][u.form], target: null, targetSince: -9, mode: "ENGAGE", goal: null,
      nextThink: rand() * BRAIN.thinkEvery, react: lerp(r0, r1, rand()), noticeUntil: 0, met: false,
      speedMul: 1 + (rand() * 2 - 1) * BRAIN.speedJitter, vx: 0, vy: 0, nv: null, slot: null, evadeT: 0, fightUntil: 0,
      progAt: 0, progX: u.x, progY: u.y, detourUntil: 0, detour: null, switches: 0, annoy: 0, angryUntil: 0,
      nextPath: 0, pathFails: 0, unreach: new Map(), blocked: false, blockedT: 0, trap: 0, trapMax: 0, yield: false,
      pursuit: 0, lastDir: null, post: null, postUntil: 0, sectors: null,
    };
  }

  // ---------- slots: sectors of the target this unit holds ----------
  function sectorsFree(e, u) { let n = 0; for (let i = 0; i < SECTORS; i++) { const o = e.ai.slots.get(i); if (!o || o === u || !o.alive || o.ai?.target !== e) n++; } return n; }
  function releaseSlot(u) {
    const A = u.ai, e = A.slotTarget;
    if (e?.ai?.slots && A.sectors) for (const i of A.sectors) if (e.ai.slots.get(i) === u) e.ai.slots.delete(i);   // only my own
    A.slot = null; A.sectors = null; A.slotTarget = null;
  }

  // ---------- target value (Infinite-Axis style: a product of considerations, each 0..~2) ----------
  function score(u, e, incoming) {
    const A = u.ai, P = A.prof, g = Math.max(0, gapOf(u, e)), t = ctx.now();
    let s = PREY[u.form][e.form];
    s *= 1 / (1 + (g / P.falloff) ** 2);                                   // distance curve
    if (P.gangUp && (e.form === "F4" || e.form === "F3")) {                 // swarm: FOCUS a big one until 6+ are on it, never past the cap
      const n = (e.ai?.attackers ?? 0) - (e === A.target ? 1 : 0);
      s *= n >= P.gangUp.cap ? P.gangUp.full : 1 + (P.gangUp.bonus - 1) * Math.min(n, P.gangUp.want) / P.gangUp.want * 2;
    } else if ((incoming.get(e) ?? 0) > e.hp * BRAIN.overkill.over && e !== A.target) s *= BRAIN.overkill.factor;  // spread fire
    if (u.form !== "F4" && e.ai?.slots && sectorsFree(e, u) < need(u, e)) s *= 0.3;   // no room round it: look elsewhere
    if (P.facing) s *= 1 - P.facing.weight * Math.abs(angDiff(Math.atan2(e.y - u.y, e.x - u.x), u.face)) / Math.PI;
    if (P.guard && e.form === "F1") {                                       // bodyguard: peel swarmers off big friends
      const big = units.find(f => f.alive && f.team === u.team && (f.form === "F3" || f.form === "F4") && dist(f, u) < P.guard.radius && gapOf(f, e) < 2.5);
      if (big) s *= P.guard.bonus * (A.angryUntil > t ? 1.3 : 1);
    }
    if ((A.unreach.get(e) ?? 0) > t) s *= 0.2;                              // couldn't find a way there recently
    if (e === A.target) s *= BRAIN.commit;
    return s;
  }

  // ---------- THINK (5 Hz) ----------
  function clearTarget(u) {
    const A = u.ai;
    releaseSlot(u); A.target = null; A.goal = null; A.saviour = null; A.evadeFrom = null; resetRoute(A);
  }
  // a new target / mode = a new route: drop the cached path, detour and progress window (code review r3 #12)
  function resetRoute(A) { A.path = null; A.pathGoal = null; A.detour = null; A.detourUntil = 0; A.progAt = ctx.now(); A.progD = null; A.winYield = 0; A.winTicks = 0; }

  function setMode(u, mode) {
    const A = u.ai;
    if (A.mode === mode) return;
    if (mode === "EVADE" || mode === "GUARD") releaseSlot(u);   // leaving the melee ring frees my sectors (audit r2 #1)
    A.mode = mode; resetRoute(A);
  }

  function think(u, foesIn, friendsIn, incoming) {
    const A = u.ai, P = A.prof, t = ctx.now();
    const foes = foesIn.filter(e => e.alive), friends = friendsIn.filter(f => f.alive);   // callers may pass this tick's stale lists
    if (!foes.length) { clearTarget(u); return; }
    const near = foes.filter(e => dist(u, e) < BRAIN.senseRange);
    const pool = near.length ? near : foes;

    // APPRAISE (LC Baboon Hawk): fear = Σ threatLevel / (dist x 0.2) - group + 1 - courage. Only hunters count.
    let fear = 0, pred = null, predD = 1e9;
    if (P.evade) {
      for (const e of pool) if (e.form === PREDATOR[u.form]) {
        const d = Math.max(1, gapOf(u, e)); if (d > P.evade.radius) continue;
        const toward = e.ai && e.ai.target === u ? 1 : 0;                  // LC: a threat moving towards it +1
        fear += (3 + toward) / (d * 0.2);
        if (d < predD) { predD = d; pred = e; }
      }
      const group = friends.filter(f => f !== u && dist(f, u) < 15).length / 4;
      fear = fear - group + 1 - P.courage;
    }
    // EVADE behind the nearest friend that hunts my hunter ("run to its Packs"), never longer than holdMax
    // (LC Spore Lizard: cornered = fight); then a 3 s fight burst before it can evade again.
    let saviour = pred && friends.filter(f => f.alive && f.form === PREDATOR[pred.form] && dist(f, u) < 60).sort((a, b) => dist(a, u) - dist(b, u))[0];
    // Packs and Brutes evade selectively (audit r2 #2): only to a protector within 14, only if the spot behind it is >= 4
    // studs further from the hunter, and never while already hitting their prey (unless below 30 % HP). Swarm: unchanged.
    if (saviour && u.form !== "F1" && A.mode !== "EVADE") {
      const d = Math.max(0.1, dist(saviour, pred)), off = saviour.r + u.r + 2;
      const spot = { x: saviour.x + (saviour.x - pred.x) / d * off, y: saviour.y + (saviour.y - pred.y) / d * off };
      const hittingPrey = A.target && A.target.form !== PREDATOR[u.form] && gapOf(u, A.target) <= u.reach;
      if (dist(saviour, u) > 14 || dist(spot, pred) - dist(u, pred) < 4 || (hittingPrey && u.hp > 0.3 * u.maxHp)) saviour = null;
    }
    // a BLOCKED event is consumed once (audit r2 #3): it can't keep extending timers or penalties
    if (A.blockedEvent && A.blockedEvent !== A.blockedSeen) {
      A.blockedSeen = A.blockedEvent;
      if (A.mode === "EVADE") { A.fightUntil = t + (u.form === "F1" ? 3 : 6); A.evadeT = 0; }   // can't get behind the protector = cornered: fight
      else if (A.mode === "ENGAGE" && A.target) { A.unreach.set(A.target, t + 2); A.targetSince = -9; }   // can't get to it: pick something reachable
      else if (A.mode === "GUARD") A.noHoldUntil = t + (P.hold?.secs ?? 2);
    }
    if (BRAIN.evadeOn !== false && pred && saviour && fear > BRAIN.evadeFear && t > A.fightUntil) {
      A.evadeT += BRAIN.thinkEvery;
      if (A.evadeT > P.evade.holdMax) { A.fightUntil = t + (u.form === "F1" ? 3 : 6); A.evadeT = 0; }   // F2/F3 then commit 6 s
      else { setMode(u, "EVADE"); A.evadeFrom = pred; A.saviour = saviour; return; }   // keep the target in memory, free my spot (r2 #1)
    } else A.evadeT = Math.max(0, A.evadeT - BRAIN.thinkEvery);
    if (A.mode === "EVADE") setMode(u, "ENGAGE");   // GUARD is decided in goalFor()
    // Bodyguards (LC Hoarding Bug): swarmers on a big friend nearby fill an annoyance meter; full = angry for a while
    if (P.guard) {
      const pest = pool.some(e => e.form === "F1" && friends.some(f => (f.form === "F3" || f.form === "F4") && dist(f, u) < P.guard.radius && gapOf(f, e) < 2.5));
      A.annoy = pest ? A.annoy + P.guard.annoyPerTick : Math.max(0, A.annoy - P.guard.annoyPerTick / 2);
      if (A.annoy > P.guard.angryAt) { A.angryUntil = t + P.guard.angryFor; A.annoy = 0; }
    }
    pickTarget(u, pool, incoming, t);
    if (!A.met && A.target && gapOf(u, A.target) < BRAIN.noticeAt) { A.met = true; A.noticeUntil = t + A.react; }  // first contact: the "notice" beat
  }

  function pickTarget(u, pool, incoming, t) {
    const A = u.ai;
    let best = null, bs = -1;
    for (const e of pool) { const s = score(u, e, incoming); if (s > bs) { bs = s; best = e; } }
    const cur = A.target && A.target.alive ? A.target : null;
    if (cur && best !== cur && t - A.targetSince < BRAIN.minHold) best = cur;   // hysteresis
    if (best !== A.target) { releaseSlot(u); A.target = best; A.targetSince = t; A.switches++; A.pursuit = 0; resetRoute(A); }
  }

  // ---------- POSITION: where to stand ----------
  function slotCost(u, e, P, friends, center, bearing) {
    const a = center * 2 * Math.PI / SECTORS, ring = ringOf(u, e);
    let c = Math.abs(angDiff(a, bearing)) * ring;                                         // studs to walk round
    if (e.form === "F4" && P.wedgeAvoid && Math.abs(angDiff(a, e.face)) < Math.PI / 3) c += P.wedgeAvoid * Math.PI * ring;
    if (P.stayNear) {
      const sx = e.x + Math.cos(a) * ring, sy = e.y + Math.sin(a) * ring;
      let nf = 1e9; for (const f of friends) if (f !== u) nf = Math.min(nf, Math.hypot(f.x - sx, f.y - sy));
      c += P.stayNear.weight * ring * Math.max(0, nf - P.stayNear.radius) / P.stayNear.radius;
    }
    return c;
  }
  function pickSlot(u, e, P, friends) {
    const k = need(u, e), bearing = Math.atan2(u.y - e.y, u.x - e.x);
    let best = -1, bc = 1e9;
    for (let c = 0; c < SECTORS; c++) {
      let ok = true;
      for (let j = 0; j < k && ok; j++) { const i = (c - Math.floor(k / 2) + j + SECTORS) % SECTORS, o = e.ai.slots.get(i); if (o && o !== u && o.alive && o.ai?.target === e) ok = false; }
      if (!ok) continue;
      const cost = slotCost(u, e, P, friends, c, bearing);
      if (cost < bc) { bc = cost; best = c; }
    }
    return [best, bc, k];
  }

  function goalFor(u, friends) {
    const A = u.ai, P = A.prof, e = A.target, t = ctx.now();
    if (A.mode === "EVADE" && A.saviour?.alive) {               // behind the friend that counters my hunter
      const s = A.saviour, p = A.evadeFrom, d = Math.max(0.1, dist(s, p));
      return { x: s.x + (s.x - p.x) / d * (s.r + u.r + 2), y: s.y + (s.y - p.y) / d * (s.r + u.r + 2) };
    }
    if (!e) return null;
    // Pincer (LC Nutcracker sentry, audit r1 #6): next to a big friend and nothing it wants in reach → hold a post between
    // the friend and the threat for 2 s (moves only if the friend walks > 6 off it or prey comes into reach).
    if (P.hold) {
      const big = friends.filter(f => f.alive && (f.form === "F3" || f.form === "F4") && dist(f, u) < P.guard.radius
        && units.some(x => x.alive && x.team !== u.team && x.form === "F1" && dist(x, f) < 12)).sort((a, b) => dist(a, u) - dist(b, u))[0];   // r2 #5: a real swarm threat on it
      const preyInReach = gapOf(u, e) <= u.reach;
      if (A.blocked && A.mode === "GUARD") A.noHoldUntil = t + P.hold.secs;   // can't reach the post: fight instead for a while
      if (big && !preyInReach && t > (A.noHoldUntil ?? 0)) {
        if (!A.post || t > A.postUntil || dist(big, A.post.anchor) > P.hold.leash) {
          const d = Math.max(0.1, dist(big, e)), off = big.r + u.r + 2;
          A.post = { x: big.x + (e.x - big.x) / d * off, y: big.y + (e.y - big.y) / d * off, anchor: { x: big.x, y: big.y } };
          A.postUntil = t + P.hold.secs;
        }
        setMode(u, "GUARD");
        return { x: A.post.x, y: A.post.y };
      }
      A.post = null; if (A.mode === "GUARD") setMode(u, "ENGAGE");
    }
    if (u.form === "F4") {
      // Titan: walk to reach along the line, but don't get mobbed: if 6+ swarmers are on it, slide towards its Packs.
      const sw = P.swarmed;
      if (sw) {
        const onMe = units.filter(f => f.alive && f.team !== u.team && f.form === "F1" && gapOf(f, u) < 2).length;
        const help = onMe >= sw.count && friends.filter(f => f.form === sw.toFriends).sort((a, b) => dist(a, u) - dist(b, u))[0];
        if (help) return { x: help.x, y: help.y };
      }
      const d = Math.max(0.1, dist(u, e)), stand = u.r + e.r + u.reach * 0.5;
      return { x: e.x + (u.x - e.x) / d * stand, y: e.y + (u.y - e.y) / d * stand };
    }
    // Melee slot (SC2-style surround) on a shared 24-sector ring. Keep it until the target changes, I'm blocked, or after
    // 1.5 s a free spot is >= 2 studs shorter to walk to (audit r1 #2: no re-picking every second = no orbiting).
    if (!e.ai.slots) e.ai.slots = new Map();
    const ring = ringOf(u, e);
    const lost = A.slot && A.sectors.some(i => { const o = e.ai.slots.get(i); return o && o !== u && o.alive && o.ai?.target === e; });
    if (!A.slot || lost || A.blocked || t - A.slot.at > 1.5) {
      const [c, cost, k] = pickSlot(u, e, P, friends);
      const curCost = A.slot && !lost && !A.blocked ? slotCost(u, e, P, friends, A.slot.c, Math.atan2(u.y - e.y, u.x - e.x)) : 1e9;
      if (c >= 0 && cost < curCost - 2) {
        releaseSlot(u);
        A.sectors = []; for (let j = 0; j < k; j++) { const i = (c - Math.floor(k / 2) + j + SECTORS) % SECTORS; A.sectors.push(i); e.ai.slots.set(i, u); }
        A.slot = { c, at: t }; A.slotTarget = e;
      } else if (c < 0 && (!A.slot || lost)) {               // ring full: wait a body-width outside it
        releaseSlot(u); const d = Math.max(0.1, dist(u, e)); return { x: e.x + (u.x - e.x) / d * (ring + 2 * u.r), y: e.y + (u.y - e.y) / d * (ring + 2 * u.r) };
      } else if (A.slot) A.slot.at = t;                    // keep it; look again in 1.5 s
    }
    const a = A.slot.c * 2 * Math.PI / SECTORS;
    return { x: e.x + Math.cos(a) * ring, y: e.y + Math.sin(a) * ring };
  }

  // ---------- STEER, phase 1: plan a velocity from the shared snapshot (nobody has moved yet this tick) ----------
  function plan(u, speed, slowK) {
    const A = u.ai, P = A.prof, t = ctx.now();
    let goal = A.detourUntil > t ? A.detour : A.goal;
    A.pathFail = false;
    // boulder in the way → grid path; one attempt per second whether it worked or not (audit r1 #4); 3 failures in a
    // row → this target counts as unreachable for 3 s (the scorer looks elsewhere)
    if (nav && goal) {
      const r = u.r * BRAIN.clearance;
      if (nav.blocked(u, goal, r)) {
        const moved = A.pathGoal && Math.hypot(A.pathGoal.x - goal.x, A.pathGoal.y - goal.y) > 2;   // r2 #4: was 4
        const stale = A.path && (t - A.pathAt > 2 || A.path.length <= 1);                            // r2 #4: paths expire
        if ((!A.path || moved || stale) && t >= A.nextPath) {
          A.path = nav.path(u, goal, r); A.nextPath = t + 1; A.pathGoal = { x: goal.x, y: goal.y }; A.pathAt = t;
          if (!A.path) { if (++A.pathFails >= 3 && A.target) { A.unreach.set(A.target, t + 3); A.pathFails = 0; } }
          else A.pathFails = 0;
        }
        if (A.path) { while (A.path.length > 1 && Math.hypot(A.path[0].x - u.x, A.path[0].y - u.y) < 1.5) A.path.shift(); goal = A.path[0]; }
        else A.pathFail = true;
      } else A.path = null;
    }
    let pv = { x: 0, y: 0 };
    // Ram (LC Thumper, audit r1 #6): starts a straight pursuit at 70 % speed, builds to 100 % after 0.6 s, turns 20 % worse at full
    let rampK = 1, turnK = 1;
    if (P.ramp && A.mode === "ENGAGE") { const k = clamp01((A.pursuit - P.ramp.after) / P.ramp.over); rampK = P.ramp.from + (1 - P.ramp.from) * k; turnK = 1 - P.ramp.turnLoss * k; }
    const maxV = speed * A.speedMul * slowK * rampK;
    A.walkDir = goal && Math.hypot(goal.x - u.x, goal.y - u.y) > 0.5 ? Math.atan2(goal.y - u.y, goal.x - u.x) : null;
    if (goal && t >= A.noticeUntil) {
      const dx = goal.x - u.x, dy = goal.y - u.y, L = Math.hypot(dx, dy);
      // brake only in the last 1.5 studs (a speed-scaled brake zone made the swarm crawl the last 8 studs into melee)
      if (L > 0.3) { const k = maxV * Math.min(1, L / 1.5); pv = { x: dx / L * k, y: dy / L * k }; }
    }
    if (P.ramp) {   // the ramp resets on a sharp turn or when blocked
      const dir = Math.hypot(pv.x, pv.y) > 0.1 ? Math.atan2(pv.y, pv.x) : null;
      if (dir == null || A.blocked || (A.lastDir != null && Math.abs(angDiff(dir, A.lastDir)) > P.ramp.sharp * Math.PI / 180)) A.pursuit = 0; else A.pursuit += DT;
      A.lastDir = dir;
    }
    // ORCA against everyone near (allies + enemies + boulders). Bigger units barely give way to small ones.
    const nb = [], R = BRAIN.orca.neighbourRange;
    for (const o of units) {
      if (o === u || !o.alive || o === A.target) continue;   // never steer around the thing I'm trying to hit
      let ox = o.x, oy = o.y; const d = dist(u, o); if (d > R + u.r + o.r) continue;
      if (o.team !== u.team && d > u.r + o.r + 2) continue;  // enemies only matter up close; friends get the full horizon
      if (d < 0.001) { const a = ((u.ai.id * 7919 + (o.ai?.id ?? 0) * 104729) % 360) * Math.PI / 180; ox += Math.cos(a) * 0.01; oy += Math.sin(a) * 0.01; }  // exact overlap: deterministic split
      nb.push({ x: ox, y: oy, vx: o.ai?.vx ?? 0, vy: o.ai?.vy ?? 0, r: o.r * BRAIN.orca.radiusScale, share: o.matter / (u.matter + o.matter) });
    }
    for (const b of ctx.obstacles) if (dist(u, b) < R + u.r + b.r) nb.push({ x: b.x, y: b.y, vx: 0, vy: 0, r: b.r, share: 1 });
    const me = { x: u.x, y: u.y, vx: A.vx, vy: A.vy, r: u.r * BRAIN.orca.radiusScale };
    let v = nb.length ? computeVelocity(me, pv, maxV, nb, BRAIN.orca.horizon, DT) : pv;
    const pvL = Math.hypot(pv.x, pv.y);
    A.yield = pvL > 0.5 && Math.hypot(v.x, v.y) < 0.5 * pvL;      // avoidance is holding it back (not a failure)
    // Acceleration (LC: speed has inertia; Titans 16 studs/s², swarm 80)
    const ax = v.x - A.vx, ay = v.y - A.vy, aL = Math.hypot(ax, ay), amax = P.accel * DT * turnK;
    if (aL > amax) v = { x: A.vx + ax / aL * amax, y: A.vy + ay / aL * amax };
    // Titans move only roughly where they face (turning is the slow part)
    if (P.facing) {
      const sp = Math.hypot(v.x, v.y);
      if (sp > 0.01) {
        const off = Math.abs(angDiff(Math.atan2(v.y, v.x), u.face)), cone = P.facing.moveCone * Math.PI / 180;
        if (off > cone) v = { x: v.x * 0.15, y: v.y * 0.15 }; else v = { x: v.x * Math.cos(off * 0.5), y: v.y * Math.cos(off * 0.5) };
      }
    }
    if (!Number.isFinite(v.x) || !Number.isFinite(v.y)) v = { x: 0, y: 0 };
    A.nv = v; A.wantGoal = goal; A.maxV = maxV;
  }

  // ---------- STEER, phase 2: everyone moves at once ----------
  function integrate(u) {
    const A = u.ai, t = ctx.now();
    if (!A.nv) return;
    A.vx = A.nv.x; A.vy = A.nv.y; A.nv = null;
    u.x += A.vx * DT; u.y += A.vy * DT;
    // the progress window only covers time spent trying to move: restart it after a fight / stun / busy spell
    if (t - (A.lastMoveT ?? -9) > DT * 1.5) { A.progAt = t; A.progX = u.x; A.progY = u.y; A.winYield = 0; A.winTicks = 0; }
    A.lastMoveT = t; A.winTicks = (A.winTicks ?? 0) + 1; if (A.yield) A.winYield = (A.winYield ?? 0) + 1;
    // BLOCKED (audit r1 #5): the goal is reachable but progress over 1.5 s < 25 % of what it should be → sidestep
    // (LC Snare Flea re-routes when stuck); track how long a unit stays trapped in a row
    if (t - A.progAt > BRAIN.stuck.window) {
      const moved = Math.hypot(u.x - A.progX, u.y - A.progY), goal = A.wantGoal;
      const nowD = goal ? Math.hypot(goal.x - u.x, goal.y - u.y) : 0, closer = (A.progD ?? nowD) - nowD;   // route progress (r2 #3)
      const wanted = goal && Math.hypot(goal.x - u.x, goal.y - u.y) > u.r + 1 && t >= A.noticeUntil && !A.pathFail;
      const yielding = A.winYield > A.winTicks / 2;   // mostly giving way in a crowd = YIELDING, not blocked (audit r1 #5 table)
      const minP = BRAIN.stuck.minProgress * A.maxV * BRAIN.stuck.window;
      const wasBlocked = A.blocked;
      A.blocked = !!(wanted && !yielding && moved < minP && closer < minP);
      if (A.blocked && !wasBlocked) A.blockedEvent = (A.blockedEvent ?? 0) + 1;   // a NEW blockage = a new one-shot event
      A.winYield = 0; A.winTicks = 0;
      if (A.blocked) {

        A.blockedT += t - A.progAt; A.trap += t - A.progAt; A.trapMax = Math.max(A.trapMax, A.trap);
        const gx = goal.x - u.x, gy = goal.y - u.y, gL = Math.hypot(gx, gy) || 1, side = (A.id % 2) ? 1 : -1;
        A.detour = { x: u.x + (-gy / gL * side) * 6 + gx / gL * 3, y: u.y + (gx / gL * side) * 6 + gy / gL * 3 };
        A.detourUntil = t + 1.0;
      } else A.trap = 0;
      A.progAt = t; A.progX = u.x; A.progY = u.y; A.progD = A.wantGoal ? Math.hypot(A.wantGoal.x - u.x, A.wantGoal.y - u.y) : null;
    }
  }

  // ---------- the per-tick entry point ----------
  // Returns the target to fight this tick (or null). The sim then does facing, autos, attack, as before.
  function tick(u, foes, friends, incoming) {
    const A = u.ai, t = ctx.now();
    if (A.target && !A.target.alive) clearTarget(u);
    if (t >= A.nextThink) { A.nextThink = t + BRAIN.thinkEvery; think(u, foes, friends, incoming); }
    A.goal = goalFor(u, friends.filter(f => f.alive));   // the spot follows a moving target every tick (cheap: the slot itself is sticky)
    return A.target;
  }

  return { init, tick, plan, integrate, setMode };   // setMode exported for the regression tests
}
