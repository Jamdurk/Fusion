// Balance report as EDGE = how much extra HP side B needs to tie side A (1.30 = A is ~30 % stronger).
// node check.mjs [runs] [offIds] [--json=file]
import { edge, COMP } from "./sim.mjs";
import fs from "node:fs";
const N = Number(process.argv[2] ?? 24);
const off = new Set(String(process.argv[3] ?? "").split(",").filter(Boolean));
const jsonOut = process.argv.find(a => a.startsWith("--json="))?.slice(7);
const combos = [["SQUISH","CRUNCH"],["CRUNCH","SQUISH"],["SQUISH","SQUISH"],["CRUNCH","CRUNCH"]];
const out = { mirror: {}, loop: {}, diag: {} };
let bad = 0; const flag = ok => ok ? "  " : (bad++, "!!");
const f2 = x => x.toFixed(2);
console.log("RACE MIRROR: Squish Fn vs Crunch Fn (target 0.90-1.10)");
for (const f of ["F1","F2","F3","F4"]) { const e = edge("SQUISH", COMP[f], "CRUNCH", COMP[f], N, off); out.mirror[f] = e; console.log(flag(e >= 0.9 && e <= 1.1), f, f2(e)); }
console.log("LOOP: counter side's edge, 4 race combos (target 1.40-3.00: clear, not a wipe)");
for (const [a, b] of [["F1","F4"],["F4","F3"],["F3","F2"],["F2","F1"]]) {
  const es = combos.map(([ra, rb]) => edge(ra, COMP[a], rb, COMP[b], N, off)); out.loop[`${a}>${b}`] = es;
  console.log(flag(es.every(e => e >= 1.4 && e <= 3.0)), `${a}>${b}`, es.map(f2).join("  "));
}
console.log("DIAGONALS: edge (target 0.77-1.30: close)");
for (const [a, b] of [["F1","F3"],["F2","F4"]]) {
  const es = combos.map(([ra, rb]) => edge(ra, COMP[a], rb, COMP[b], N, off)); out.diag[`${a}v${b}`] = es;
  console.log(flag(es.every(e => e >= 0.77 && e <= 1.3)), `${a}v${b}`, es.map(f2).join("  "));
}
console.log(bad ? `${bad} FLAGGED` : "ALL TARGETS MET");
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(out, null, 1));
