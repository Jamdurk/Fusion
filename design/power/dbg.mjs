import { battle } from "./sim.mjs";
const pairs = process.argv.slice(2);
for (const p of pairs) {
  const [ra, fa, rb, fb] = p.split(/[.|]/);
  const C = { F1: { F1: 32 }, F2: { F2: 16 }, F3: { F3: 8 }, F4: { F4: 2 } };
  const tot = {}; let w = 0; const N = 20;
  for (let i = 0; i < N; i++) { const tr = {}; const r = battle(ra, C[fa], rb, C[fb], 500 + i, new Set(), tr); if (r.win === 0) w++; for (const k in tr) tot[k] = (tot[k] ?? 0) + tr[k] / N; }
  console.log(p, "A wins", w / N, Object.entries(tot).sort().map(([k, v]) => k + "=" + v.toFixed(0)).join(" "));
}
