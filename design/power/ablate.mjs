// Each ability's weight: how much stronger the army is WITH it (edge with / edge without, minus 1),
// against every enemy form of the other race. Reports the average and the matchup where it matters most.
// node ablate.mjs [runs] [race.form filter] [--json=file]
import { edge, COMP } from "./sim.mjs";
import { KITS } from "./kits.mjs";
import fs from "node:fs";
const N = Number(process.argv[2] ?? 24);
const filt = process.argv[3] && !process.argv[3].startsWith("--") ? process.argv[3] : null;
const jsonOut = process.argv.find(a => a.startsWith("--json="))?.slice(7);
const out = {}, FS = ["F1", "F2", "F3", "F4"];
for (const race of ["SQUISH", "CRUNCH"]) {
  const other = race === "SQUISH" ? "CRUNCH" : "SQUISH";
  for (const f of FS) {
    if (filt && filt !== `${race}.${f}`) continue;
    const full = Object.fromEntries(FS.map(g => [g, edge(race, COMP[f], other, COMP[g], N, new Set())]));
    const row = [];
    for (const a of KITS[race][f].abilities) {
      const per = {};
      for (const g of FS) per[g] = full[g] / edge(race, COMP[f], other, COMP[g], N, new Set([a.id])) - 1;
      const avg = FS.reduce((s, g) => s + per[g], 0) / 4;
      const best = FS.reduce((b, g) => per[g] > per[b] ? g : b, "F1");
      row.push({ id: a.id, name: a.name, slot: a.slot, avg, best, bestVal: per[best], per });
    }
    out[`${race}.${f}`] = { full, row };
    console.log(`${race.padEnd(6)} ${f} ${KITS[race][f].name.padEnd(9)} ` + row.map(r => `${r.slot}:${r.name} avg ${(r.avg * 100).toFixed(0)}% / best ${(r.bestVal * 100).toFixed(0)}% vs ${r.best}`).join(" | "));
  }
}
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(out, null, 1));
