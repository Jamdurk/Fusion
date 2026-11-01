// Does team 0 (processed first each tick) win more in mirror fights? node side-bias.mjs [fights]
import { battle, setAI } from "./sim.mjs";
import { positiveInt } from "./args.mjs";
const N = positiveInt(process.argv[2] ?? 60), C = { F1: 8, F2: 4, F3: 2, F4: 1 };
for (const ai of ["old", "new"]) {
  setAI(ai); let w = 0, n = 0;
  for (const race of ["SQUISH", "CRUNCH"]) for (let i = 0; i < N; i++) { const r = battle(race, C, race, C, 3000 + i); w += r.win === 0.5 ? 0.5 : r.win === 0 ? 1 : 0; n++; }
  console.log(`${ai}: team 0 wins ${(100 * w / n).toFixed(1)} % of ${n} mirror fights`);
}
