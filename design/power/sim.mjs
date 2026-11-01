// Alien Fusion battle sim: equal-matter (32 v 32) open-field fights, 2D, dt 0.1 s, kits from kits.mjs.
// node sim.mjs [runs] [--off=abilityId,...] [--only=matrix|ablation|mixed] [--json=out.json]
// Units walk to the nearest enemy and fight; abilities fire on their own triggers (no player micro).
import { FORMS, KITS, RULES } from "./kits.mjs";
const SIZE = RULES.f4.vsSmall ?? {};  // size rule: a Titan's hits on small, quick units are scaled

const args = Object.fromEntries(process.argv.slice(2).filter(a => a.startsWith("--")).map(a => { const [k, v] = a.slice(2).split("="); return [k, v ?? true]; }));
let FORMATION = "open";
export const setFormation = f => { FORMATION = f; };
const RUNS = Number(process.argv.slice(2).find(a => !a.startsWith("--")) ?? 120);
const DT = 0.1, TMAX = 150, LANE = 10;  // lane formation = a 20-stud-wide corridor

function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
const d2 = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;
const dist = (a, b) => Math.sqrt(d2(a, b));

function makeUnit(team, race, form, x, y, off, hpMul = 1, rand = Math.random) {
  const F = FORMS[form], kit = KITS[race][form];
  const ab = {};
  for (const a of kit.abilities) if (!off.has(a.id)) ab[a.slot] = a;
  return { team, race, form, matter: F.matter, x, y, r: F.r, reach: F.reach, speed: F.speed, hp: F.hp * hpMul, maxHp: F.hp * hpMul,
    face: team === 0 ? 0 : Math.PI, ab, cd: { B: 1 + rand() * 2, C: 3 + rand() * 3 }, atk: rand(),
    slows: [], stunUntil: 0, immuneUntil: 0, shield: 0, shieldUntil: 0, dr: 0, drUntil: 0, haste: 0, hasteUntil: 0,
    busyUntil: 0, alive: true, dmgDone: {}, stats: null };
}

function army(team, race, comp, rand, off, hpMul = 1) {
  // comp: { F1: n, F2: n, ... }. Formation: blob around x = ±30.
  const out = [], sx = team === 0 ? -30 : 30;
  for (const [form, n] of Object.entries(comp)) for (let i = 0; i < n; i++) {
    const spread = (form === "F4" ? 10 : 9) * (FORMATION === "spread" ? 2 : 1), depth = FORMATION === "spread" ? 24 : FORMATION === "lane" ? 30 : 12;
    let y = (rand() - 0.5) * 2 * spread * Math.sqrt(n / 4 + 1); if (FORMATION === "lane") y = Math.max(-LANE + 1, Math.min(LANE - 1, y));
    out.push(makeUnit(team, race, form, sx + (rand() - 0.5) * depth + (team === 0 ? -1 : 1) * (form === "F4" ? 6 : 0), y, off, hpMul, rand));
  }
  return out;
}

function battle(raceA, compA, raceB, compB, seed, off = new Set(), trace = null, hpMul = [1, 1]) {
  const rand = rng(seed);
  const units = [...army(0, raceA, compA, rand, off, hpMul[0]), ...army(1, raceB, compB, rand, off, hpMul[1])];
  units.forEach((u, i) => { u.uid = i; });   // stable ids for deterministic tie-breaks
  const pending = [];   // telegraphed effects
  const oc = () => 3 + rand() * 6;  // players tap their first Order at different moments
  const orderCd = [{ F1: oc(), F2: oc(), F3: oc(), F4: oc() }, { F1: oc(), F2: oc(), F3: oc(), F4: oc() }];  // shared per player + form (fusion can't reset it)
  const puddles = [];   // { team, x, y, r, slow, until, burn }
  let t = 0;
  const now = () => t;
  const live = tm => units.filter(u => u.alive && u.team === tm);

  const slowOf = u => {
    let s = 0;
    for (const sl of u.slows) if (sl.until > t) s = Math.max(s, sl.pct);
    for (const p of puddles) if (p.until > t && p.slow && p.team !== u.team && d2(u, p) < (p.r + u.r * 0.5) ** 2) s = Math.max(s, p.slow);
    s = Math.min(s, RULES.slowCap);
    return u.form === "F4" ? s * RULES.f4.slowFactor : s;
  };
  const stun = (u, d) => {
    if (u.form === "F4" && RULES.f4.stunImmune) return;
    if (u.immuneUntil > t) return;
    d = Math.min(d, RULES.stunMax); u.stunUntil = t + d; u.immuneUntil = t + d + RULES.stunImmunity;
  };
  const slow = (u, pct, dur) => u.slows.push({ pct, until: t + dur });
  const shove = (u, dx, dy) => {  // pulls, knocks, tosses share one budget per victim
    if (u.form === "F4") return;
    u.shoves = (u.shoves ?? []).filter(m => m.t > t - RULES.shoveWindow);
    const used = u.shoves.reduce((a, m) => a + m.d, 0), L = Math.hypot(dx, dy); if (!L) return;
    const k = Math.min(1, Math.max(0, RULES.shoveBudget - used) / L); if (!k) return;
    u.x += dx * k; u.y += dy * k; u.shoves.push({ t, d: L * k });
  };
  const damage = (src, u, amt, abId) => {
    if (!u.alive) return 0;
    if (u.drUntil > t) amt *= 1 - u.dr;
    if (src?.form === "F4") amt *= (SIZE[u.form] ?? 1);
    let left = amt;
    const pool = u.hp + (u.shieldUntil > t ? u.shield : 0);
    if (u.shieldUntil > t && u.shield > 0) { const s = Math.min(u.shield, left); u.shield -= s; left -= s; }
    u.hp -= left;
    if (trace && src) { const k = src.team + ":" + abId; trace[k] = (trace[k] ?? 0) + Math.min(amt, pool); }
    if (u.hp <= 0) die(u);
    return amt;
  };
  const die = u => {
    u.alive = false; u.hp = 0;
    const C = u.ab.C;
    if (C?.kind === "deathSlow") puddles.push({ team: u.team, x: u.x, y: u.y, r: C.radius, slow: C.slow, until: t + C.dur });
    if (C?.kind === "deathBurst") {
      const near = units.filter(e => e.alive && e.team !== u.team && dist(e, u) < C.radius + e.r).sort((a, b) => d2(a, u) - d2(b, u)).slice(0, C.cap);
      for (const e of near) damage(u, e, C.hit, C.id);
    }
  };
  const mult = (a, tgt) => (a.mult?.[tgt.form] ?? 1);
  // nearest to a danger shape's centre first, ties by unit id. (Before 28 Oct this used d2(unit, shape) = NaN: shapes use
  // cx/cy, so capped AoE hits took units in list order. Found by the AI code review; old file: sim-v3-before-fix.mjs.)
  const byShape = s => (p, q) => ((p.x - s.cx) ** 2 + (p.y - s.cy) ** 2) - ((q.x - s.cx) ** 2 + (q.y - s.cy) ** 2) || p.uid - q.uid;
  const enemiesIn = (u, x, y, rad) => units.filter(e => e.alive && e.team !== u.team && (e.x - x) ** 2 + (e.y - y) ** 2 < (rad + e.r * 0.5) ** 2);

  // Telegraph: register a pending AoE. F1 dodgers inside react now (Boing hops out, Curl hardens).
  function telegraph(u, a, shape, at, apply) {
    pending.push({ u, a, shape, at, apply, released: a.kind === "lob" });
    for (const e of units) if (e.alive && e.team !== u.team && inShape(e, shape)) {
      const B = e.ab.B;
      if (!B || e.cd.B > 0 || e.stunUntil > t) continue;
      if (B.vsOnly && !B.vsOnly.includes(u.form)) continue;  // only reacts to big attackers (never helps against its predator)
      if (B.kind === "dodge" && at - t >= 0.3) {
        const ex = exitOf(e, shape);
        e.cd.B = B.cd;
        if (ex && Math.hypot(ex[0], ex[1]) <= B.leap) { e.x += ex[0]; e.y += ex[1]; }
        else if (B.dr) { e.dr = B.dr; e.drUntil = at + 0.2; }
        if (trace && e.team === 0) trace[B.id] = (trace[B.id] ?? 0) + 1;
      } else if (B.kind === "curl") { e.dr = B.dr; e.drUntil = at + 0.2; e.cd.B = B.cd; }  // curls only for the instant of the hit
    }
  }
  // shortest move that takes e out of a danger shape (+0.5 clearance)
  function exitOf(e, s) {
    const pad = e.r * 0.5 + 0.5;
    if (s.type === "circle" || s.type === "arc") {
      const dx = e.x - s.cx, dy = e.y - s.cy, L = Math.hypot(dx, dy) || 0.01, need = s.r + pad - L;
      let best = [dx / L * need, dy / L * need];
      if (s.type === "arc") {  // or step sideways past the wedge edge
        const half = (s.arc / 2) * Math.PI / 180;
        for (const sgn of [1, -1]) {
          const edge = s.face + sgn * half, nx = -Math.sin(edge) * sgn, ny = Math.cos(edge) * sgn;
          const d = (e.x - s.cx) * nx + (e.y - s.cy) * ny;  // signed distance past this edge
          const mv = pad - d; if (mv > 0 && Math.hypot(nx * mv, ny * mv) < Math.hypot(best[0], best[1])) best = [nx * mv, ny * mv];
        }
      }
      return best;
    }
    if (s.type === "lane") {
      const fx = Math.cos(s.face), fy = Math.sin(s.face), dx = e.x - s.cx, dy = e.y - s.cy;
      const across = -dx * fy + dy * fx, side = across >= 0 ? 1 : -1, need = s.w / 2 + pad - Math.abs(across);
      return [-fy * side * need, fx * side * need];
    }
  }
  function inShape(e, s) {
    if (s.type === "circle") return (e.x - s.cx) ** 2 + (e.y - s.cy) ** 2 < (s.r + e.r * 0.5) ** 2;
    if (s.type === "arc") {
      const dx = e.x - s.cx, dy = e.y - s.cy, L = Math.hypot(dx, dy);
      if (L > s.r + e.r * 0.5) return false;
      const ang = Math.abs(angDiff(Math.atan2(dy, dx), s.face));   // wrapped (before 28 Oct: wrong once a facing wound past 2π)
      return ang <= (s.arc / 2) * Math.PI / 180 || L < e.r;
    }
    if (s.type === "lane") { // from (cx,cy) along face
      const dx = e.x - s.cx, dy = e.y - s.cy, fx = Math.cos(s.face), fy = Math.sin(s.face);
      const along = dx * fx + dy * fy, across = Math.abs(-dx * fy + dy * fx);
      return along > -1 && along < s.len + e.r * 0.5 && across < s.w / 2 + e.r * 0.5;
    }
  }
  const unitsIn = (u, s) => units.filter(e => e.alive && e.team !== u.team && inShape(e, s));

  function bestCluster(u, range, rad, filt = () => true) {
    let best = null, bn = 0;
    for (const e of units) if (e.alive && e.team !== u.team && dist(u, e) < range && filt(e)) {
      const n = enemiesIn(u, e.x, e.y, rad).length;
      if (n > bn) { bn = n; best = e; }
    }
    return [best, bn];
  }

  function useB(u, tgt, dT) {
    const a = u.ab.B; if (!a || u.cd.B > 0) return;
    if (a.kind === "zoneSlow" && enemiesIn(u, u.x, u.y, a.radius).length >= a.trigger) {
      u.cd.B = a.cd; u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => puddles.push({ team: u.team, x: u.x, y: u.y, r: a.radius, slow: a.slow, until: t + a.dur }) });
    } else if (a.kind === "pull" && tgt) {
      const cands = units.filter(e => e.alive && e.team !== u.team && e.form !== "F4" && dist(u, e) < a.range && dist(u, e) > u.r + e.r + 2);
      cands.sort((p, q) => a.prefer.indexOf(p.form) - a.prefer.indexOf(q.form) || d2(u, p) - d2(u, q));
      const e = cands[0]; if (!e) return;
      u.cd.B = a.cd; u.busyUntil = t + (a.tele ?? 0);
      pending.push({ u, a, at: t + (a.tele ?? 0), apply: () => { if (!e.alive) return; const L = dist(u, e); const k = (u.r + e.r + 0.5) / L;
        shove(e, (u.x + (e.x - u.x) * k) - e.x, (u.y + (e.y - u.y) * k) - e.y); stun(e, a.root); if (a.hit) damage(u, e, a.hit, a.id); } });
      if (trace && u.team === 0) trace[a.id] = (trace[a.id] ?? 0) + 1;
    } else if (a.kind === "dr") {
      const attackers = units.filter(e => e.alive && e.team !== u.team && (!a.triggerForms || a.triggerForms.includes(e.form)) && dist(e, u) < e.r + u.r + e.reach + 0.5).length;
      if (attackers >= a.trigger) { u.dr = a.dr; u.drUntil = t + a.dur; u.cd.B = a.cd; }
    } else if (a.kind === "stunRing") {
      const near = units.filter(e => e.alive && e.team !== u.team && e.form !== "F4" && (!a.triggerForms || a.triggerForms.includes(e.form)) && dist(e, u) < a.radius + e.r * 0.5);
      if (near.length >= a.trigger) {
        u.cd.B = a.cd; u.busyUntil = t + a.tele;
        const s = { type: "circle", cx: u.x, cy: u.y, r: a.radius };
        telegraph(u, a, s, t + a.tele, () => { const pr = f => (a.prefer ?? []).includes(f) ? a.prefer.indexOf(f) : 9; for (const e of unitsIn(u, s).filter(e => !a.hitForms || a.hitForms.includes(e.form)).sort((p, q) => pr(p.form) - pr(q.form) || d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (!a.stunForms || a.stunForms.includes(e.form)) stun(e, a.stun); } });
      }
    } else if (a.kind === "lob") {
      if (a.farOnly && units.some(e => e.alive && e.team !== u.team && dist(u, e) < u.r + e.r + a.farOnly)) return;
      const pref = units.filter(e => e.alive && e.team !== u.team && (a.prefer ?? []).includes(e.form) && dist(u, e) < a.range).sort((p, q) => d2(p, u) - d2(q, u))[0];
      const [c0, n] = bestCluster(u, a.range, a.radius); const c = pref ?? c0;
      if (c && (pref || n >= 1)) {
        u.cd.B = a.cd; u.busyUntil = t + (a.lock ?? 0.6);
        const pre = a.pre ?? 0;
        let lx = c.x, ly = c.y;
        const go = () => { if (c.alive) { lx = c.x; ly = c.y; } const s = { type: "circle", cx: lx, cy: ly, r: a.radius };
        telegraph(u, a, s, t + a.tele, () => {
          for (const e of unitsIn(u, s).sort(byShape(s)).slice(0, a.cap)) { damage(u, e, a.hit * mult(a, e), a.id); }
          if (a.slow) puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, slow: a.slow, until: t + a.slowDur });
        }); };
        if (pre > 0) pending.push({ u, a, at: t + pre, apply: go }); else go();
      }
    }
  }

  // ORDER (slot C): dry = only answer "would this unit do something useful right now?"
  const preferPick = (list, pref) => list.sort((p, q) => (pref.indexOf(p.form) + 9) % 9 - (pref.indexOf(q.form) + 9) % 9)[0];
  function useC(u, tgt, dry) {
    const a = u.ab.C; if (!a) return false;
    if (a.kind === "leapOnto") {
      const cands = units.filter(e => e.alive && e.team !== u.team && a.targets.includes(e.form) && dist(u, e) < a.range + e.r);
      if (!cands.length) return false; if (dry) return true;
      const e = cands.filter(c => (c.leapers ?? 0) < (a.perTarget ?? 99)).sort((p, q) => d2(p, u) - d2(q, u))[0];
      if (!e) return false;
      e.leapers = (e.leapers ?? 0) + 1; u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => { e.leapers--; if (!e.alive) return; const ang = rand() * 2 * Math.PI; u.x = e.x + Math.cos(ang) * (e.r + u.r * 0.8); u.y = e.y + Math.sin(ang) * (e.r + u.r * 0.8); u.bonusNext = a.bonus; u.bonusOn = e; } });
      return true;
    } else if (a.kind === "rush") {
      if (!units.some(e => e.alive && e.team !== u.team && a.targets.includes(e.form) && dist(u, e) < a.range + e.r)) return false; if (dry) return true;
      u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => { u.rushUntil = t + a.dur; u.rushSpeed = a.speed; u.dr = a.dr; u.drUntil = t + a.dur; u.bonusNext = a.bonus; u.bonusForms = a.targets; } });
      return true;
    } else if (a.kind === "leapSlam") {
      const [c, n] = bestCluster(u, a.range, a.radius);
      if (!(c && n >= a.trigger)) return false; if (dry) return true;
      u.busyUntil = t + a.tele + 0.3;
      const s = { type: "circle", cx: c.x, cy: c.y, r: a.radius };
      telegraph(u, a, s, t + a.tele, () => {
        u.x = s.cx; u.y = s.cy;
        for (const e of unitsIn(u, s).sort(byShape(s)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (e.form === "F1") stun(e, a.stunF1); }
      });
      return true;
    } else if (a.kind === "shieldBuff") {
      if (!(tgt && dist(u, tgt) < u.r + tgt.r + u.reach + 1)) return false; if (dry) return true;
      u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => {
        u.shield = Math.max(u.shieldUntil > t ? u.shield : 0, a.selfShield); u.shieldUntil = t + a.shieldDur; u.haste = a.haste; u.hasteUntil = t + a.hasteDur;
        for (const f of units) if (f.alive && f !== u && f.team === u.team && dist(f, u) < a.allyRadius) { f.shield = Math.max(f.shieldUntil > t ? f.shield : 0, Math.min(a.allyShield, RULES.shieldCap * f.maxHp)); f.shieldUntil = t + a.shieldDur; }
      } });
      return true;
    } else if (a.kind === "dashLine") {
      if (enemiesIn(u, u.x, u.y, 6).length < a.trigger) return false;
      const [c] = bestCluster(u, 6, 4); if (!c) return false; if (dry) return true;
      const face = Math.atan2(c.y - u.y, c.x - u.x);
      const s = { type: "lane", cx: u.x, cy: u.y, face, len: a.length, w: a.width };
      u.busyUntil = t + a.tele + 0.4;
      telegraph(u, a, s, t + a.tele, () => {
        for (const e of unitsIn(u, s).filter(e => !a.hitForms || a.hitForms.includes(e.form)).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); const side = ((e.x - u.x) * -Math.sin(face) + (e.y - u.y) * Math.cos(face)) >= 0 ? 1 : -1; shove(e, -Math.sin(face) * side * a.knock, Math.cos(face) * side * a.knock); }
        if (a.dash !== 0) { u.x += Math.cos(face) * a.length; u.y += Math.sin(face) * a.length; }
      });
      return true;
    } else if (a.kind === "charge") {
      const cands = units.filter(e => e.alive && e.team !== u.team && dist(u, e) < a.length && (a.prefer ?? ["F2", "F3"]).includes(e.form));
      cands.sort((p, q) => a.prefer.indexOf(p.form) - a.prefer.indexOf(q.form) || d2(u, p) - d2(u, q));
      const e0 = cands[0]; if (!e0) return false; if (dry) return true;
      const face = Math.atan2(e0.y - u.y, e0.x - u.x);
      const s = { type: "lane", cx: u.x, cy: u.y, face, len: Math.min(a.length, dist(u, e0) + 2), w: a.width };
      u.busyUntil = t + a.tele + 0.5;
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));
        const first = e0.alive && hit.includes(e0) ? e0 : (hit.find(h => h.form !== "F1") ?? hit[0]);
        if (first) damage(u, first, a.hit * mult(a, first), a.id);
        for (const h of hit.filter(h => h !== first).slice(0, a.cap - 1)) { damage(u, h, a.side, a.id); shove(h, -Math.sin(face) * a.knock, Math.cos(face) * a.knock); }
        const L = first ? Math.max(0, dist(u, first) - u.r - first.r) : s.len; u.x += Math.cos(face) * L; u.y += Math.sin(face) * L;
      });
      return true;
    } else if (a.kind === "lane") {
      if (!tgt) return false;
      const s = { type: "lane", cx: u.x, cy: u.y, face: u.face, len: a.length + u.r, w: a.width };
      const inLane = unitsIn(u, s); if (!inLane.length || (inLane.length < (a.minHits ?? 1) && !inLane.some(e => e.form === "F3"))) return false; if (dry) return true;
      u.busyUntil = t + (a.lock ?? a.tele + 0.6);
      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { const s = { type: "lane", cx: u.x, cy: u.y, face: u.face, len: a.length + u.r, w: a.width };
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));
        const first = preferPick([...hit], a.prefer) ?? hit[0];
        const rest = hit.filter(h => h !== first).slice(0, a.cap - 1);
        if (first) { damage(u, first, a.hit * mult(a, first), a.id); slow(first, a.slow, a.slowDur); }
        for (const e of rest) { damage(u, e, a.side, a.id); slow(e, a.slow, a.slowDur); }
      }); } });
      return true;
    } else if (a.kind === "zoneBurst") {
      const front = e => Math.abs(angDiff(Math.atan2(e.y - u.y, e.x - u.x), u.face)) < Math.PI / 2;
      const bigs = units.filter(e => e.alive && e.team !== u.team && e.form !== "F1" && dist(u, e) < a.range && front(e));
      const c = preferPick(bigs, a.prefer) ?? bestCluster(u, a.range, a.radius, front)[0];
      if (!c || (c.form !== "F3" && enemiesIn(u, c.x, c.y, a.radius).length < (a.minHits ?? 1))) return false; if (dry) return true;
      u.busyUntil = t + (a.lock ?? a.tele + 1.0);
      let lx = c.x, ly = c.y;
      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { if (c.alive) { lx = c.x; ly = c.y; } const s = { type: "circle", cx: lx, cy: ly, r: a.radius };
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort(byShape(s));
        const first = c.alive && hit.includes(c) ? c : hit[0];
        if (first) damage(u, first, a.hit * mult(a, first), a.id);
        for (const e of hit.filter(h => h !== first).slice(0, a.cap - 1)) damage(u, e, a.side, a.id);
        puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, until: t + a.burnDur, burn: a.burn, cap: a.cap, src: u, id: a.id });
      }); } });
      return true;
    }
    return false;
  }
  const angDiff = (a, b) => { let d = a - b; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; };

  function attack(u, tgt) {
    const a = u.ab.A;
    const F = FORMS[u.form];
    const interval = Math.max(0.1, (a?.every ?? 1) - (a?.lock ?? 0)) / (u.hasteUntil > t ? 1 + u.haste : 1);  // the animation lock is part of the cycle
    u.atk += DT * (1 - slowOf(u)); if (u.atk < interval) return;  // slows also slow attacks (sticky goo / jolted)
    u.atk = 0;
    const base = a ? a.hit : F.dps * interval;
    if (u.bonusOn && !u.bonusOn.alive) { u.bonusNext = 0; u.bonusOn = null; }
    if (u.bonusNext && (u.bonusOn ? tgt === u.bonusOn : !u.bonusForms || u.bonusForms.includes(tgt.form))) { damage(u, tgt, u.bonusNext, u.ab.C?.id ?? "order"); u.bonusNext = 0; u.bonusOn = null; if (!tgt.alive) return; }
    if (!a) { damage(u, tgt, base, "basic"); return; }
    if (a.kind === "surround") {
      let m = 1;
      if (a.surroundMult[tgt.form]) {
        const n = units.filter(f => f.alive && f.team === u.team && f.form === "F1" && dist(f, tgt) < f.r + tgt.r + f.reach + 0.6).length;
        if (n >= a.surroundN) m = a.surroundMult[tgt.form];
      }
      damage(u, tgt, a.hit * m, a.id);
    } else if (a.kind === "cleave") {
      damage(u, tgt, a.hit, a.id);
      if (a.targets > 1) {
        const extra = units.filter(e => e.alive && e !== tgt && e.team !== u.team && a.cleaveVs.includes(e.form) && dist(e, u) < u.r + e.r + u.reach + 1).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.targets - 1);
        for (const e of extra) damage(u, e, a.hit, a.id);
      }
    } else if (a.kind === "melee") {
      damage(u, tgt, a.hit * mult(a, tgt), a.id);
    } else if (a.kind === "arcSlam") {
      u.busyUntil = t + (a.lock ?? a.tele + 0.4); u.slamBusy = true; pending.push({ u, a, at: u.busyUntil, apply: () => { u.slamBusy = false; } });
      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { const s = { type: "arc", cx: u.x, cy: u.y, r: a.radius + u.r, arc: a.arc, face: u.face };
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap);
        hit.forEach((e, i) => { damage(u, e, a.hit * (i === 0 ? 1 : a.splash) * mult(a, e), a.id); if (a.stun && e.form !== "F1") stun(e, a.stun); if (a.slow) slow(e, a.slow, a.slowDur); });
      }); } });
    }
  }

  // ---- main loop
  for (t = 0; t < TMAX; t += DT) {
    // pending effects
    for (let i = pending.length - 1; i >= 0; i--) if (pending[i].at <= t) { const p = pending.splice(i, 1)[0]; if (p.u.alive || p.released) p.apply(); }
    // burn puddles
    for (const p of puddles) if (p.burn && p.until > t) for (const e of units.filter(e => e.alive && e.team !== p.team && d2(e, p) < (p.r + e.r * 0.5) ** 2).sort((q, w) => d2(q, p) - d2(w, p)).slice(0, p.cap ?? 99)) damage(p.src, e, p.burn * DT, p.id);
    const a0 = live(0), a1 = live(1);
    if (!a0.length || !a1.length) break;
    // ORDERS: one button per form. The "player" taps it when at least 30 % of that form's units have a use for it.
    for (const tm of [0, 1]) for (const f of ["F1", "F2", "F3", "F4"]) {
      if ((orderCd[tm][f] -= DT) > 0) continue;
      const all = (tm === 0 ? a0 : a1).filter(u => u.form === f && u.ab.C);
      const mine = all.filter(u => u.stunUntil <= t && u.busyUntil <= t);
      if (!mine.length) continue;
      const nearest = u => { let b = null, bd = 1e9; for (const e of (tm === 0 ? a1 : a0)) { const dd = d2(u, e); if (dd < bd) { bd = dd; b = e; } } return b; };
      const ready = mine.filter(u => useC(u, nearest(u), true));
      if (ready.length >= Math.max(1, Math.ceil(0.3 * all.length))) { for (const u of ready) useC(u, nearest(u), false); orderCd[tm][f] = mine[0].ab.C.cd; if (trace) { trace[tm + ":orders:" + f] = (trace[tm + ":orders:" + f] ?? 0) + 1; trace[tm + ":casters:" + f] = (trace[tm + ":casters:" + f] ?? 0) + ready.length; } }
    }
    for (const u of units) {
      if (!u.alive) continue;
      u.cd.B -= DT;
      if (u.stunUntil > t) continue;
      const foes = u.team === 0 ? a1 : a0;
      let tgt = null, best = 1e9;
      for (const e of foes) if (e.alive) { const dd = d2(u, e) - (e.r * e.r); if (dd < best) { best = dd; tgt = e; } }
      if (!tgt) continue;
      // facing (F4 turns slowly)
      const want = Math.atan2(tgt.y - u.y, tgt.x - u.x);
      const turn = u.form === "F4" ? RULES.f4.turnDegPerSec * Math.PI / 180 * DT : 99;
      const da = angDiff(want, u.face); u.face += Math.max(-turn, Math.min(turn, da));
      if (u.busyUntil > t) { if (u.ab.A?.keepCycle && !u.slamBusy) u.atk += DT; continue; }  // a Titan's slam timer keeps counting while it throws
      useB(u, tgt); if (u.busyUntil > t) continue;
      const gap = dist(u, tgt) - u.r - tgt.r;
      if (gap > u.reach) {
        const sp = u.speed * (1 - slowOf(u)) * (u.rushUntil > t ? 1 + u.rushSpeed : 1) * DT, L = dist(u, tgt);
        u.x += (tgt.x - u.x) / L * Math.min(sp, gap); u.y += (tgt.y - u.y) / L * Math.min(sp, gap);
      } else if (u.form !== "F4" || Math.abs(angDiff(want, u.face)) < Math.PI / 3) attack(u, tgt);
    }
    if (FORMATION === "lane") for (const u of units) if (u.alive) u.y = Math.max(-LANE + u.r * 0.5, Math.min(LANE - u.r * 0.5, u.y));
    // separation (cheap): push overlapping units apart, big ones barely move
    const al = units.filter(u => u.alive);
    for (let i = 0; i < al.length; i++) for (let j = i + 1; j < al.length; j++) {
      const a = al[i], b = al[j], dx = b.x - a.x, dy = b.y - a.y, L = Math.hypot(dx, dy) || 0.01, need = (a.r + b.r) * 0.9;
      if (L < need) { const push = need - L, wa = b.matter / (a.matter + b.matter), wb = 1 - wa; a.x -= dx / L * push * wa; a.y -= dy / L * push * wa; b.x += dx / L * push * wb; b.y += dy / L * push * wb; }
    }
  }
  const score = tm => units.filter(u => u.team === tm && u.alive).reduce((s, u) => s + u.matter * u.hp / u.maxHp, 0);
  const s0 = score(0), s1 = score(1);
  return { win: s0 > s1 ? 0 : s1 > s0 ? 1 : 0.5, left0: s0 / 32, left1: s1 / 32, time: t };
}

const COMP = { F1: { F1: 32 }, F2: { F2: 16 }, F3: { F3: 8 }, F4: { F4: 2 } };
function matchup(rA, cA, rB, cB, runs, off, mulB = 1) {
  let w = 0, lw = 0, tt = 0;
  for (let i = 0; i < runs; i++) {
    // alternate sides so spawn side can't bias
    const flip = i % 2 === 1;
    const r = flip ? battle(rB, cB, rA, cA, 1000 + i, off, null, [mulB, 1]) : battle(rA, cA, rB, cB, 1000 + i, off, null, [1, mulB]);
    // r.win = index of the winning team (0.5 = draw); A is team 0 unless flipped
    w += r.win === 0.5 ? 0.5 : (r.win === (flip ? 1 : 0) ? 1 : 0); lw += Math.max(r.left0, r.left1); tt += r.time;
  }
  return { winA: w / runs, winnerLeft: lw / runs, time: tt / runs };
}

function edge(rA, cA, rB, cB, runs, off) {
  let lo = Math.log(0.25), hi = Math.log(4);
  for (let i = 0; i < 9; i++) { const mid = (lo + hi) / 2; const m = matchup(rA, cA, rB, cB, runs, off, Math.exp(mid)); if (m.winA > 0.5) lo = mid; else hi = mid; }
  return Math.exp((lo + hi) / 2);
}
export { battle, matchup, edge, COMP };

if (process.argv[1]?.replace(/\\/g, "/").endsWith("/sim.mjs")) {   // run directly, not imported (used to crash when imported without a script path)
  const off = new Set(String(args.off ?? "").split(",").filter(Boolean));
  const out = {};
  const forms = ["F1", "F2", "F3", "F4"];
  if (!args.only || args.only === "matrix") {
    for (const [rA, rB] of [["SQUISH", "CRUNCH"], ["SQUISH", "SQUISH"], ["CRUNCH", "CRUNCH"]]) {
      console.log(`\n== ${rA} (rows) vs ${rB} (cols): row win % / winner's matter left % / seconds`);
      console.log("      " + forms.map(f => f.padEnd(17)).join(""));
      for (const fa of forms) {
        let line = fa.padEnd(6);
        for (const fb of forms) {
          const m = matchup(rA, COMP[fa], rB, COMP[fb], RUNS, off);
          out[`${rA}.${fa}|${rB}.${fb}`] = m;
          line += `${(m.winA * 100).toFixed(0).padStart(3)}% ${(m.winnerLeft * 100).toFixed(0).padStart(3)}% ${m.time.toFixed(0).padStart(4)}s  `;
        }
        console.log(line);
      }
    }
  }
  if (args.json) { const fs = await import("node:fs"); fs.writeFileSync(args.json, JSON.stringify(out, null, 1)); }
}
