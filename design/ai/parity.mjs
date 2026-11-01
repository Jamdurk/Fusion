// Quick race parity on MIXED armies (Squish vs Crunch, both sides, same comps): the new-AI proxy for mixed.mjs's race line.
// node parity.mjs [fightsPerPair] [--squishHold=s] [--squishRadius=n] [--crunchCourage=n]
import { battle, setAI } from "./sim.mjs";
import { PROFILES } from "./profiles.mjs";
setAI(process.argv.includes("--old") ? "old" : "new");
import { BRAIN } from "./profiles.mjs";
if (process.argv.includes("--noevade")) BRAIN.evadeOn = false;
if (process.argv.includes("--nowedge")) for (const f of ["F1","F2","F3"]) PROFILES.SQUISH[f].wedgeAvoid = PROFILES.CRUNCH[f].wedgeAvoid;
if (process.argv.includes("--noramp")) PROFILES.CRUNCH.F3.ramp = null;
if (process.argv.includes("--nohold")) PROFILES.CRUNCH.F2.hold = null;
if (process.argv.includes("--samecourage")) for (const f of ["F1","F2","F3","F4"]) PROFILES.CRUNCH[f].courage = 0;
const arg = k => { const a = process.argv.find(x => x.startsWith("--" + k + "=")); return a ? Number(a.split("=")[1]) : null; };
for (const f of ["F1", "F2", "F3"]) {
  if (arg("squishHold") != null) PROFILES.SQUISH[f].evade.holdMax = arg("squishHold");
  if (arg("squishRadius") != null) PROFILES.SQUISH[f].evade.radius = arg("squishRadius");
  if (arg("crunchCourage") != null) { PROFILES.CRUNCH[f].courage = arg("crunchCourage"); }
}
import { positiveInt } from "./args.mjs";
const N = positiveInt(process.argv[2] ?? 4);
const OFF = new Set((process.argv.find(x => x.startsWith("--off=")) ?? "--off=").slice(6).split(",").filter(Boolean));
const comps = [{ F1: 8, F2: 4, F3: 4 }, { F1: 16, F2: 8 }, { F2: 4, F3: 2, F4: 1 }, { F1: 8, F2: 4, F3: 2, F4: 1 }, { F1: 16, F3: 4 },
  { F2: 8, F3: 4 }, { F1: 8, F2: 12 }, { F1: 16, F4: 1 }, { F3: 4, F4: 1 }, { F1: 8, F2: 4, F3: 1 , F4: 1 }].filter(c => Object.entries(c).reduce((s, [f, n]) => s + n * { F1: 1, F2: 2, F3: 4, F4: 16 }[f], 0) === 32);
let sq = 0, g = 0, seed = 900;
for (const a of comps) for (const b of comps) for (let k = 0; k < N; k++) {
  const flip = k % 2; const r = flip ? battle("CRUNCH", b, "SQUISH", a, seed++, OFF) : battle("SQUISH", a, "CRUNCH", b, seed++, OFF);
  sq += r.win === 0.5 ? 0.5 : r.win === (flip ? 1 : 0) ? 1 : 0; g++;
}
console.log(`${comps.length} mixes, ${g} fights: SQUISH ${(100 * sq / g).toFixed(1)} %  CRUNCH ${(100 - 100 * sq / g).toFixed(1)} %`, process.argv.slice(3).join(" "));
