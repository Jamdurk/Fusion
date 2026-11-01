import { battle } from "./sim.mjs";
const tr = {}; const r = battle("SQUISH", { F2: 16 }, "CRUNCH", { F2: 16 }, 11, new Set(), tr);
console.log(JSON.stringify(tr), r.time);
