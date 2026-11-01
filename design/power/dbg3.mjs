import { battle } from "./sim.mjs";
for (const [ra, ca, rb, cb] of [["CRUNCH", { F2: 16 }, "SQUISH", { F1: 32 }], ["SQUISH", { F2: 16 }, "CRUNCH", { F1: 32 }]]) {
  const tr = {}; const r = battle(ra, ca, rb, cb, 21, new Set(), tr, [1, 2]); console.log(JSON.stringify(tr), r.time.toFixed(1), r.win);
}
