// Bot opponent's COUNTER TABLE: for every enemy army mix, which of our mixes beats it best (new AI, open field).
// The in-game bot snaps what it SEES to the nearest mix and looks the answer up (no simulation, no hidden info).
// node bot-table.mjs [fightsPerPair] → bot-table.json
import { battle, setAI } from "./sim.mjs";
import fs from "node:fs";
setAI("new");
import { positiveInt } from "./args.mjs";
const N = positiveInt(process.argv[2] ?? 4);
const comps = [];
for (let f4 = 0; f4 <= 2; f4++) for (let f3 = 0; f3 <= 8; f3 += 2) for (let f2 = 0; f2 <= 16; f2 += 4) {
  const f1 = 32 - 16 * f4 - 4 * f3 - 2 * f2; if (f1 < 0 || f1 % 4) continue;
  comps.push({ F1: f1, F2: f2, F3: f3, F4: f4 });
}
const clean = c => Object.fromEntries(Object.entries(c).filter(([, n]) => n > 0));
const name = c => `${c.F4}T ${c.F3}B ${c.F2}P ${c.F1}S`;
const table = {};
let seed = 1;
for (const me of ["SQUISH", "CRUNCH"]) for (const them of ["SQUISH", "CRUNCH"]) {
  const rows = [];
  for (const e of comps) {
    const res = comps.map(c => {
      let w = 0;
      for (let k = 0; k < N; k++) { const r = k % 2 ? battle(them, clean(e), me, clean(c), seed++) : battle(me, clean(c), them, clean(e), seed++); w += r.win === 0.5 ? 0.5 : r.win === (k % 2 ? 1 : 0) ? 1 : 0; }
      return { comp: c, win: w / N };
    }).sort((a, b) => b.win - a.win);
    rows.push({ enemy: e, best: res.slice(0, 3).map(r => ({ comp: r.comp, win: r.win })) });
  }
  table[`${me}>${them}`] = rows;
  const hard = rows.filter(r => r.best[0].win < 0.65).map(r => name(r.enemy));
  console.log(`${me} answering ${them}: best answer wins ${(100 * rows.reduce((s, r) => s + r.best[0].win, 0) / rows.length).toFixed(0)} % on average; mixes with no >= 65 % answer: ${hard.length ? hard.join(", ") : "none"}`);
}
fs.writeFileSync(new URL("./bot-table.json", import.meta.url), JSON.stringify({ comps, fightsPerPair: N, table }, null, 0));
