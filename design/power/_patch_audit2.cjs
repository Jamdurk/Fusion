// One-off: applies ChatGPT audit r2 fixes to sim.mjs (kept for the record; safe to delete).
const fs = require("fs"); let s = fs.readFileSync("sim.mjs", "utf8");
const rep = (a, b) => { if (!s.includes(a)) throw new Error("missing: " + a.slice(0, 80)); s = s.replace(a, b); };

// r2 #1: Titan lobs + Solar Strike keep the target's last known spot; they still land if it dies
rep("        const go = () => { if (!c.alive) return; const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };",
  "        let lx = c.x, ly = c.y;\n        const go = () => { if (c.alive) { lx = c.x; ly = c.y; } const s = { type: \"circle\", cx: lx, cy: ly, r: a.radius };");
rep("      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { if (!c.alive) return; const s = { type: \"circle\", cx: c.x, cy: c.y, r: a.radius };",
  "      let lx = c.x, ly = c.y;\n      pending.push({ u, a, at: t + (a.pre ?? 0), apply: () => { if (c.alive) { lx = c.x; ly = c.y; } const s = { type: \"circle\", cx: lx, cy: ly, r: a.radius };");
// a released boulder lands even if the thrower died (pending effects normally need a living caster)
rep("if (pending[i].at <= t) { const p = pending.splice(i, 1)[0]; if (p.u.alive) p.apply(); }",
  "if (pending[i].at <= t) { const p = pending.splice(i, 1)[0]; if (p.u.alive || p.released) p.apply(); }");
rep("    pending.push({ u, a, shape, at, apply });", "    pending.push({ u, a, shape, at, apply, released: a.kind === \"lob\" });");

// r2 #3: Hoof Stamp only hurts Packs and Brutes; Side Sweep only hits swarms and Packs
rep("for (const e of unitsIn(u, s).sort((p, q) => pr(p.form) - pr(q.form) || d2(p, u) - d2(q, u)).slice(0, a.cap)) {",
  "for (const e of unitsIn(u, s).filter(e => !a.hitForms || a.hitForms.includes(e.form)).sort((p, q) => pr(p.form) - pr(q.form) || d2(p, u) - d2(q, u)).slice(0, a.cap)) {");
rep("for (const e of unitsIn(u, s).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); const side =",
  "for (const e of unitsIn(u, s).filter(e => !a.hitForms || a.hitForms.includes(e.form)).sort((p, q) => d2(p, u) - d2(q, u)).slice(0, a.cap)) { damage(u, e, a.hit, a.id); const side =");

// r2 #4: Boing jumps to the nearest real exit of the danger shape (+0.5 clearance, max `leap`), else squashes flat
rep("      if (B.kind === \"dodge\" && at - t >= 0.3) {\n        const dx = e.x - shape.cx, dy = e.y - shape.cy, L = Math.hypot(dx, dy) || 1;\n        e.x += dx / L * B.leap; e.y += dy / L * B.leap; e.cd.B = B.cd;\n        if (B.dr) { e.dr = B.dr; e.drUntil = at + 0.2; }",
  `      if (B.kind === "dodge" && at - t >= 0.3) {
        const ex = exitOf(e, shape);
        e.cd.B = B.cd;
        if (ex && Math.hypot(ex[0], ex[1]) <= B.leap) { e.x += ex[0]; e.y += ex[1]; }
        else if (B.dr) { e.dr = B.dr; e.drUntil = at + 0.2; }`);
rep("  function inShape(e, s) {",
`  // shortest move that takes e out of a danger shape (+0.5 clearance)
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
  function inShape(e, s) {`);
fs.writeFileSync("sim.mjs", s);
let k = fs.readFileSync("kits.mjs", "utf8");
const q = (a, b) => { if (!k.includes(a)) throw new Error("missing kit: " + a.slice(0, 70)); k = k.replace(a, b); };
q('triggerForms: ["F2", "F3"], prefer: ["F2", "F3"], stunForms: ["F2", "F3"] }', 'triggerForms: ["F2", "F3"], prefer: ["F2", "F3"], stunForms: ["F2", "F3"], hitForms: ["F2", "F3"] }');
q("length: 7, width: 6, hit: 20, cap: 3, knock: 2, dash: 0, trigger: 2 }", "length: 7, width: 6, hit: 20, cap: 3, knock: 2, dash: 0, trigger: 2, hitForms: [\"F1\", \"F2\"] }");
q('"ORDER: every Pincer plants its legs and swings both claws in a wide sideways sweep, batting little ones aside."', '"ORDER: every Pincer plants its legs and swings both claws in a wide sideways sweep, batting little ones and Packs aside."');
q("It springs 10 studs out of the danger zone (if it can't get clear,", "It springs to the nearest edge of the danger zone, up to 10 studs (if it can't get clear,");
fs.writeFileSync("kits.mjs", k);
console.log("patched r2");
