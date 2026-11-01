const fs = require("fs"); let s = fs.readFileSync("sim.mjs", "utf8");
const start = s.indexOf("  function useC(u, tgt) {"), end = s.indexOf("  const angDiff = (a, b) =>");
if (start < 0 || end < 0) throw new Error("anchors");
const useC = String.raw`  // ORDER (slot C): dry = only answer "would this unit do something useful right now?"
  const preferPick = (list, pref) => list.sort((p, q) => (pref.indexOf(p.form) + 9) % 9 - (pref.indexOf(q.form) + 9) % 9)[0];
  function useC(u, tgt, dry) {
    const a = u.ab.C; if (!a) return false;
    if (a.kind === "leapOnto") {
      const cands = units.filter(e => e.alive && e.team !== u.team && a.targets.includes(e.form) && dist(u, e) < a.range + e.r);
      if (!cands.length) return false; if (dry) return true;
      const e = cands.sort((p, q) => d2(p, u) - d2(q, u))[0];
      u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => { if (!e.alive) return; const ang = Math.random() * 2 * Math.PI; u.x = e.x + Math.cos(ang) * (e.r + u.r * 0.8); u.y = e.y + Math.sin(ang) * (e.r + u.r * 0.8); u.bonusNext = a.bonus; u.atk = 99; } });
      return true;
    } else if (a.kind === "rush") {
      if (!tgt || dist(u, tgt) - u.r - tgt.r < 4) return false; if (dry) return true;
      u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => { u.rushUntil = t + a.dur; u.rushSpeed = a.speed; u.dr = a.dr; u.drUntil = t + a.dur; u.bonusNext = a.bonus; } });
      return true;
    } else if (a.kind === "leapSlam") {
      const [c, n] = bestCluster(u, a.range, a.radius);
      if (!(c && n >= a.trigger)) return false; if (dry) return true;
      u.busyUntil = t + a.tele + 0.3;
      const s = { type: "circle", cx: c.x, cy: c.y, r: a.radius };
      telegraph(u, a, s, t + a.tele, () => {
        u.x = s.cx; u.y = s.cy;
        for (const e of unitsIn(u, s).sort((p, q) => d2(p, s) - d2(q, s)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (e.form === "F1") stun(e, a.stunF1); }
      });
      return true;
    } else if (a.kind === "shieldBuff") {
      if (!(tgt && dist(u, tgt) < u.r + tgt.r + u.reach + 1)) return false; if (dry) return true;
      u.busyUntil = t + a.tele;
      pending.push({ u, a, at: t + a.tele, apply: () => {
        u.shield = Math.max(u.shieldUntil > t ? u.shield : 0, a.selfShield); u.shieldUntil = t + a.shieldDur; u.haste = a.haste; u.hasteUntil = t + a.hasteDur;
        for (const f of units) if (f.alive && f !== u && f.team === u.team && dist(f, u) < a.allyRadius) { f.shield = Math.max(f.shieldUntil > t ? f.shield : 0, a.allyShield); f.shieldUntil = t + a.shieldDur; }
      } });
      return true;
    } else if (a.kind === "dashLine") {
      if (enemiesIn(u, u.x, u.y, 6).length < a.trigger) return false;
      const [c] = bestCluster(u, 6, 4); if (!c) return false; if (dry) return true;
      const face = Math.atan2(c.y - u.y, c.x - u.x);
      const s = { type: "lane", cx: u.x, cy: u.y, face, len: a.length, w: a.width };
      u.busyUntil = t + a.tele + 0.4;
      telegraph(u, a, s, t + a.tele, () => {
        for (const e of unitsIn(u, s).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (e.form !== "F4") { const side = ((e.x - u.x) * -Math.sin(face) + (e.y - u.y) * Math.cos(face)) >= 0 ? 1 : -1; e.x += -Math.sin(face) * side * a.knock; e.y += Math.cos(face) * side * a.knock; } }
        u.x += Math.cos(face) * a.length; u.y += Math.sin(face) * a.length;
      });
      return true;
    } else if (a.kind === "charge") {
      const cands = units.filter(e => e.alive && e.team !== u.team && dist(u, e) < a.length && e.form !== "F1");
      cands.sort((p, q) => (p.form === "F2" ? 0 : 1) - (q.form === "F2" ? 0 : 1) || d2(u, p) - d2(u, q));
      const e0 = cands[0] ?? (tgt && dist(u, tgt) < a.length ? tgt : null); if (!e0) return false; if (dry) return true;
      const face = Math.atan2(e0.y - u.y, e0.x - u.x);
      const s = { type: "lane", cx: u.x, cy: u.y, face, len: Math.min(a.length, dist(u, e0) + 2), w: a.width };
      u.busyUntil = t + a.tele + 0.5;
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));
        const first = hit.find(h => h.form !== "F1") ?? hit[0];
        let n = 0;
        for (const h of hit) { if (n++ >= a.cap) break; if (h === first) { damage(u, h, a.hit * mult(a, h), a.id); } else { damage(u, h, a.side, a.id); if (h.form !== "F4") { h.x += -Math.sin(face) * a.knock; h.y += Math.cos(face) * a.knock; } } }
        const L = first ? Math.max(0, dist(u, first) - u.r - first.r) : s.len; u.x += Math.cos(face) * L; u.y += Math.sin(face) * L;
      });
      return true;
    } else if (a.kind === "lane") {
      if (!tgt) return false;
      const s = { type: "lane", cx: u.x, cy: u.y, face: u.face, len: a.length + u.r, w: a.width };
      if (!unitsIn(u, s).length) return false; if (dry) return true;
      u.busyUntil = t + a.tele + 0.6;
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));
        const first = preferPick([...hit], a.prefer) ?? hit[0];
        const rest = hit.filter(h => h !== first).slice(0, a.cap - 1);
        if (first) { damage(u, first, a.hit * mult(a, first), a.id); slow(first, a.slow, a.slowDur); }
        for (const e of rest) { damage(u, e, a.side * mult(a, e), a.id); slow(e, a.slow, a.slowDur); }
      });
      return true;
    } else if (a.kind === "zoneBurst") {
      const front = e => Math.abs(angDiff(Math.atan2(e.y - u.y, e.x - u.x), u.face)) < Math.PI / 2;
      const bigs = units.filter(e => e.alive && e.team !== u.team && e.form !== "F1" && dist(u, e) < a.range && front(e));
      const c = preferPick(bigs, a.prefer) ?? bestCluster(u, a.range, a.radius, front)[0];
      if (!c) return false; if (dry) return true;
      u.busyUntil = t + a.tele + 1.0;
      const s = { type: "circle", cx: c.x, cy: c.y, r: a.radius };
      telegraph(u, a, s, t + a.tele, () => {
        const hit = unitsIn(u, s).sort((p, q) => d2(p, s) - d2(q, s));
        const first = c.alive && hit.includes(c) ? c : hit[0];
        if (first) damage(u, first, a.hit * mult(a, first), a.id);
        for (const e of hit.filter(h => h !== first).slice(0, a.cap - 1)) damage(u, e, a.side * mult(a, e), a.id);
        puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, until: t + a.burnDur, burn: a.burn, cap: a.cap, src: u, id: a.id });
      });
      return true;
    }
    return false;
  }
`;
s = s.slice(0, start) + useC + s.slice(end);
const rep = (a, b) => { if (!s.includes(a)) throw new Error("missing: " + a.slice(0, 70)); s = s.replace(a, b); };
rep("for (const p of puddles) if (p.burn && p.until > t) for (const e of units) if (e.alive && e.team !== p.team && d2(e, p) < (p.r + e.r * 0.5) ** 2) damage(p.src, e, p.burn * DT * (p.src.ab.C?.mult?.[e.form] ?? 1), p.id);",
  "for (const p of puddles) if (p.burn && p.until > t) for (const e of units.filter(e => e.alive && e.team !== p.team && d2(e, p) < (p.r + e.r * 0.5) ** 2).sort((q, w) => d2(q, p) - d2(w, p)).slice(0, p.cap ?? 99)) damage(p.src, e, p.burn * DT, p.id);");
rep("    const a0 = live(0), a1 = live(1);\n    if (!a0.length || !a1.length) break;",
`    const a0 = live(0), a1 = live(1);
    if (!a0.length || !a1.length) break;
    // ORDERS: one button per form. The "player" taps it when at least 30 % of that form's units have a use for it.
    for (const tm of [0, 1]) for (const f of ["F1", "F2", "F3", "F4"]) {
      if ((orderCd[tm][f] -= DT) > 0) continue;
      const mine = (tm === 0 ? a0 : a1).filter(u => u.form === f && u.ab.C && u.stunUntil <= t && u.busyUntil <= t);
      if (!mine.length) continue;
      const nearest = u => { let b = null, bd = 1e9; for (const e of (tm === 0 ? a1 : a0)) { const dd = d2(u, e); if (dd < bd) { bd = dd; b = e; } } return b; };
      const ready = mine.filter(u => useC(u, nearest(u), true));
      if (ready.length >= Math.max(1, Math.ceil(0.3 * mine.length))) { for (const u of ready) useC(u, nearest(u), false); orderCd[tm][f] = mine[0].ab.C.cd; if (trace) trace[tm + ":orders:" + f] = (trace[tm + ":orders:" + f] ?? 0) + 1; }
    }`);
rep("  const pending = [];   // telegraphed effects", "  const pending = [];   // telegraphed effects\n  const orderCd = [{ F1: 4, F2: 4, F3: 4, F4: 4 }, { F1: 4, F2: 4, F3: 4, F4: 4 }];  // shared per player + form (fusion can't reset it)");
rep("      useC(u, tgt); if (u.busyUntil > t) continue;\n", "");
rep("      u.cd.B -= DT; u.cd.C -= DT;", "      u.cd.B -= DT;");
rep("        const sp = u.speed * (1 - slowOf(u)) * DT, L = dist(u, tgt);", "        const sp = u.speed * (1 - slowOf(u)) * (u.rushUntil > t ? 1 + u.rushSpeed : 1) * DT, L = dist(u, tgt);");
rep("    u.atk = 0;\n    const base = a ? a.hit : F.dps * interval;", "    u.atk = 0;\n    const base = a ? a.hit : F.dps * interval;\n    if (u.bonusNext) { damage(u, tgt, u.bonusNext, u.ab.C?.id ?? \"order\"); u.bonusNext = 0; if (!tgt.alive) return; }");
rep("      const e = cands[0]; if (!e) return;\n      const L = dist(u, e); const k = (u.r + e.r + 0.5) / L;\n      e.x = u.x + (e.x - u.x) * k; e.y = u.y + (e.y - u.y) * k; stun(e, a.root); if (a.hit) damage(u, e, a.hit, a.id); u.cd.B = a.cd;",
  "      const e = cands[0]; if (!e) return;\n      u.cd.B = a.cd; u.busyUntil = t + (a.tele ?? 0);\n      pending.push({ u, a, at: t + (a.tele ?? 0), apply: () => { if (!e.alive) return; const L = dist(u, e); const k = (u.r + e.r + 0.5) / L;\n        e.x = u.x + (e.x - u.x) * k; e.y = u.y + (e.y - u.y) * k; stun(e, a.root); if (a.hit) damage(u, e, a.hit, a.id); } });");
fs.writeFileSync("sim.mjs", s);
console.log("patched");
