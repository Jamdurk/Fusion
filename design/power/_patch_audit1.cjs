// One-off: applies ChatGPT audit r1 fixes to sim.mjs (kept for the record; safe to delete).
const fs = require("fs"); let s = fs.readFileSync("sim.mjs", "utf8");
const rep = (a, b) => { if (!s.includes(a)) throw new Error("missing: " + a.slice(0, 80)); s = s.replace(a, b); };

// formation option (open / spread / lane)
rep("const RUNS = Number(", "let FORMATION = \"open\";\nexport const setFormation = f => { FORMATION = f; };\nconst RUNS = Number(");
rep("    const spread = form === \"F4\" ? 10 : 9;\n    out.push(makeUnit(team, race, form, sx + (rand() - 0.5) * 12 + (team === 0 ? -1 : 1) * (form === \"F4\" ? 6 : 0), (rand() - 0.5) * 2 * spread * Math.sqrt(n / 4 + 1), off, hpMul, rand));",
  "    const spread = (form === \"F4\" ? 10 : 9) * (FORMATION === \"spread\" ? 2 : 1), depth = FORMATION === \"spread\" ? 24 : FORMATION === \"lane\" ? 30 : 12;\n    let y = (rand() - 0.5) * 2 * spread * Math.sqrt(n / 4 + 1); if (FORMATION === \"lane\") y = Math.max(-LANE + 1, Math.min(LANE - 1, y));\n    out.push(makeUnit(team, race, form, sx + (rand() - 0.5) * depth + (team === 0 ? -1 : 1) * (form === \"F4\" ? 6 : 0), y, off, hpMul, rand));");
rep("const DT = 0.1, TMAX = 150;", "const DT = 0.1, TMAX = 150, LANE = 10;  // lane formation = a 20-stud-wide corridor");

// forced movement budget (8 studs per victim per 3 s; Titans immune)
rep("  const slow = (u, pct, dur) => u.slows.push({ pct, until: t + dur });",
`  const slow = (u, pct, dur) => u.slows.push({ pct, until: t + dur });
  const shove = (u, dx, dy) => {  // pulls, knocks, tosses share one budget per victim
    if (u.form === "F4") return;
    u.shoves = (u.shoves ?? []).filter(m => m.t > t - RULES.shoveWindow);
    const used = u.shoves.reduce((a, m) => a + m.d, 0), L = Math.hypot(dx, dy); if (!L) return;
    const k = Math.min(1, Math.max(0, RULES.shoveBudget - used) / L); if (!k) return;
    u.x += dx * k; u.y += dy * k; u.shoves.push({ t, d: L * k });
  };`);

// Boing bombs bonus is tied to its target; Roll Out bonus only on big targets
rep("u.y = e.y + Math.sin(ang) * (e.r + u.r * 0.8); u.bonusNext = a.bonus; } });",
  "u.y = e.y + Math.sin(ang) * (e.r + u.r * 0.8); u.bonusNext = a.bonus; u.bonusOn = e; } });");
rep("u.dr = a.dr; u.drUntil = t + a.dur; u.bonusNext = a.bonus; } });", "u.dr = a.dr; u.drUntil = t + a.dur; u.bonusNext = a.bonus; u.bonusForms = a.targets; } });");
rep("    if (u.bonusNext) { damage(u, tgt, u.bonusNext, u.ab.C?.id ?? \"order\"); u.bonusNext = 0; if (!tgt.alive) return; }",
  "    if (u.bonusOn && !u.bonusOn.alive) { u.bonusNext = 0; u.bonusOn = null; }\n    if (u.bonusNext && (u.bonusOn ? tgt === u.bonusOn : !u.bonusForms || u.bonusForms.includes(tgt.form))) { damage(u, tgt, u.bonusNext, u.ab.C?.id ?? \"order\"); u.bonusNext = 0; u.bonusOn = null; if (!tgt.alive) return; }");

// pull uses the shove budget (and the root still respects stun immunity)
rep("e.x = u.x + (e.x - u.x) * k; e.y = u.y + (e.y - u.y) * k; stun(e, a.root);", "shove(e, (u.x + (e.x - u.x) * k) - e.x, (u.y + (e.y - u.y) * k) - e.y); stun(e, a.root);");

// claw block: only against swarm attackers
rep("      const attackers = units.filter(e => e.alive && e.team !== u.team && dist(e, u) < e.r + u.r + e.reach + 0.5).length;",
  "      const attackers = units.filter(e => e.alive && e.team !== u.team && (!a.triggerForms || a.triggerForms.includes(e.form)) && dist(e, u) < e.r + u.r + e.reach + 0.5).length;");

// hoof stamp: triggers on its prey, prefers it, no swarm stun
rep("      const near = units.filter(e => e.alive && e.team !== u.team && e.form !== \"F4\" && dist(e, u) < a.radius + e.r * 0.5);\n      if (near.length >= a.trigger) {",
  "      const near = units.filter(e => e.alive && e.team !== u.team && e.form !== \"F4\" && (!a.triggerForms || a.triggerForms.includes(e.form)) && dist(e, u) < a.radius + e.r * 0.5);\n      if (near.length >= a.trigger) {");
rep("telegraph(u, a, s, t + a.tele, () => { for (const e of unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); stun(e, a.stun); } });",
  "telegraph(u, a, s, t + a.tele, () => { const pr = f => (a.prefer ?? []).includes(f) ? a.prefer.indexOf(f) : 9; for (const e of unitsIn(u, s).sort((p, q) => pr(p.form) - pr(q.form) || d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (!a.stunForms || a.stunForms.includes(e.form)) stun(e, a.stun); } });");

// lobs: prefer a Brute (then the densest cluster); animation-timed
rep("      const [c, n] = bestCluster(u, a.range, a.radius);\n      if (c && n >= 1) {\n        u.cd.B = a.cd; u.busyUntil = t + 0.6;\n        const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };\n        telegraph(u, a, s, t + a.tele, () => {",
  "      const pref = units.filter(e => e.alive && e.team !== u.team && (a.prefer ?? []).includes(e.form) && dist(u, e) < a.range).sort((p, q) => d2(p, u) - d2(q, u))[0];\n      const [c0, n] = bestCluster(u, a.range, a.radius); const c = pref ?? c0;\n      if (c && (pref || n >= 1)) {\n        u.cd.B = a.cd; u.busyUntil = t + (a.lock ?? 0.6);\n        const pre = a.pre ?? 0;\n        const go = () => { if (!c.alive) return; const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };\n        telegraph(u, a, s, t + a.tele, () => {");
rep("          if (a.slow) puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, slow: a.slow, until: t + a.slowDur });\n        });\n      }",
  "          if (a.slow) puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, slow: a.slow, until: t + a.slowDur });\n        }); };\n        if (pre > 0) pending.push({ u, a, at: t + pre, apply: go }); else go();\n      }");

// leap slam + side sweep: tosses/knocks use the budget; side sweep sorts by distance before the cap
rep("for (const e of unitsIn(u, s).slice(0, a.cap)) { damage(u, e, a.hit, a.id); if (e.form !== \"F4\") { const side = ((e.x - u.x) * -Math.sin(face) + (e.y - u.y) * Math.cos(face)) >= 0 ? 1 : -1; e.x += -Math.sin(face) * side * a.knock; e.y += Math.cos(face) * side * a.knock; } }",
  "for (const e of unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); const side = ((e.x - u.x) * -Math.sin(face) + (e.y - u.y) * Math.cos(face)) >= 0 ? 1 : -1; shove(e, -Math.sin(face) * side * a.knock, Math.cos(face) * side * a.knock); }");

// ram charge: only at a Pack or Brute (Pack first); chosen primary first, then the nearest others
rep("      const cands = units.filter(e => e.alive && e.team !== u.team && dist(u, e) < a.length && e.form !== \"F1\");\n      cands.sort((p, q) => (p.form === \"F2\" ? 0 : 1) - (q.form === \"F2\" ? 0 : 1) || d2(u, p) - d2(u, q));\n      const e0 = cands[0] ?? (tgt && dist(u, tgt) < a.length ? tgt : null); if (!e0) return false; if (dry) return true;",
  "      const cands = units.filter(e => e.alive && e.team !== u.team && dist(u, e) < a.length && (a.prefer ?? [\"F2\", \"F3\"]).includes(e.form));\n      cands.sort((p, q) => a.prefer.indexOf(p.form) - a.prefer.indexOf(q.form) || d2(u, p) - d2(u, q));\n      const e0 = cands[0]; if (!e0) return false; if (dry) return true;");
rep("        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));\n        const first = hit.find(h => h.form !== \"F1\") ?? hit[0];\n        let n = 0;\n        for (const h of hit) { if (n++ >= a.cap) break; if (h === first) { damage(u, h, a.hit * mult(a, h), a.id); } else { damage(u, h, a.side, a.id); if (h.form !== \"F4\") { h.x += -Math.sin(face) * a.knock; h.y += Math.cos(face) * a.knock; } } }",
  "        const hit = unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u));\n        const first = e0.alive && hit.includes(e0) ? e0 : (hit.find(h => h.form !== \"F1\") ?? hit[0]);\n        if (first) damage(u, first, a.hit * mult(a, first), a.id);\n        for (const h of hit.filter(h => h !== first).slice(0, a.cap - 1)) { damage(u, h, a.side, a.id); shove(h, -Math.sin(face) * a.knock, Math.cos(face) * a.knock); }");

// F4 Orders: animation-timed; the Brute multiplier only on the primary hit
rep("      if (!unitsIn(u, s).length) return false; if (dry) return true;\n      u.busyUntil = t + a.tele + 0.6;\n      telegraph(u, a, s, t + a.tele, () => {",
  "      if (!unitsIn(u, s).length) return false; if (dry) return true;\n      u.busyUntil = t + (a.lock ?? a.tele + 0.6);\n      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { const s = { type: \"lane\", cx: u.x, cy: u.y, face: u.face, len: a.length + u.r, w: a.width };\n      telegraph(u, a, s, t + a.tele, () => {");
rep("        for (const e of rest) { damage(u, e, a.side * mult(a, e), a.id); slow(e, a.slow, a.slowDur); }\n      });\n      return true;",
  "        for (const e of rest) { damage(u, e, a.side, a.id); slow(e, a.slow, a.slowDur); }\n      }); } });\n      return true;");
rep("      if (!c) return false; if (dry) return true;\n      u.busyUntil = t + a.tele + 1.0;\n      const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };\n      telegraph(u, a, s, t + a.tele, () => {",
  "      if (!c) return false; if (dry) return true;\n      u.busyUntil = t + (a.lock ?? a.tele + 1.0);\n      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { if (!c.alive) return; const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };\n      telegraph(u, a, s, t + a.tele, () => {");
rep("        for (const e of hit.filter(h => h !== first).slice(0, a.cap - 1)) damage(u, e, a.side * mult(a, e), a.id);\n        puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, until: t + a.burnDur, burn: a.burn, cap: a.cap, src: u, id: a.id });\n      });",
  "        for (const e of hit.filter(h => h !== first).slice(0, a.cap - 1)) damage(u, e, a.side, a.id);\n        puddles.push({ team: u.team, x: s.cx, y: s.cy, r: a.radius, until: t + a.burnDur, burn: a.burn, cap: a.cap, src: u, id: a.id });\n      }); } });");

// chest thump ally shield cap
rep("f.shield = Math.max(f.shieldUntil > t ? f.shield : 0, a.allyShield);", "f.shield = Math.max(f.shieldUntil > t ? f.shield : 0, Math.min(a.allyShield, RULES.shieldCap * f.maxHp));");

// F4 slam: animation-timed (warning at `pre`, hit at pre + tele, locked for `lock`)
rep("    const interval = (a?.every ?? 1) / (u.hasteUntil > t ? 1 + u.haste : 1);",
  "    const interval = Math.max(0.1, (a?.every ?? 1) - (a?.lock ?? 0)) / (u.hasteUntil > t ? 1 + u.haste : 1);  // the animation lock is part of the cycle");
rep("      const s = { type: \"arc\", cx: u.x, cy: u.y, r: a.radius + u.r, arc: a.arc, face: u.face };\n      u.busyUntil = t + a.tele + 0.4;\n      telegraph(u, a, s, t + a.tele, () => {",
  "      u.busyUntil = t + (a.lock ?? a.tele + 0.4);\n      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { const s = { type: \"arc\", cx: u.x, cy: u.y, r: a.radius + u.r, arc: a.arc, face: u.face };\n      telegraph(u, a, s, t + a.tele, () => {");
rep("        hit.forEach((e, i) => { damage(u, e, a.hit * (i === 0 ? 1 : a.splash) * mult(a, e), a.id); if (a.stun && e.form !== \"F1\") stun(e, a.stun); if (a.slow) slow(e, a.slow, a.slowDur); });\n      });",
  "        hit.forEach((e, i) => { damage(u, e, a.hit * (i === 0 ? 1 : a.splash) * mult(a, e), a.id); if (a.stun && e.form !== \"F1\") stun(e, a.stun); if (a.slow) slow(e, a.slow, a.slowDur); });\n      }); } });");

// Order threshold: 30 % of ALL living units of that form
rep("      const mine = (tm === 0 ? a0 : a1).filter(u => u.form === f && u.ab.C && u.stunUntil <= t && u.busyUntil <= t);\n      if (!mine.length) continue;",
  "      const all = (tm === 0 ? a0 : a1).filter(u => u.form === f && u.ab.C);\n      const mine = all.filter(u => u.stunUntil <= t && u.busyUntil <= t);\n      if (!mine.length) continue;");
rep("if (ready.length >= Math.max(1, Math.ceil(0.3 * mine.length)))", "if (ready.length >= Math.max(1, Math.ceil(0.3 * all.length)))");

// lane formation keeps everyone inside the corridor
rep("    // separation (cheap): push overlapping units apart, big ones barely move",
  "    if (FORMATION === \"lane\") for (const u of units) if (u.alive) u.y = Math.max(-LANE + u.r * 0.5, Math.min(LANE - u.r * 0.5, u.y));\n    // separation (cheap): push overlapping units apart, big ones barely move");
fs.writeFileSync("sim.mjs", s);
console.log("patched sim.mjs");
