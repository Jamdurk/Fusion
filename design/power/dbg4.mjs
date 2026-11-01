import { battle } from "./sim.mjs";
for (const [ra, rb, cb] of [["SQUISH","CRUNCH",{F3:8}],["CRUNCH","SQUISH",{F3:8}],["SQUISH","CRUNCH",{F2:16}]]) {
  const tr = {}; const r = battle(ra, { F4: 2 }, rb, cb, 5, new Set(), tr); console.log(ra, JSON.stringify(cb), JSON.stringify(tr), r.time.toFixed(1), "win", r.win); }
