// "Dumb behaviour" metrics, OLD AI vs NEW AI on the same seeded fights.
// node metrics.mjs [runs] [--json=file]   (runs per scenario, default 20)
// fight % = unit-time spent hitting something · stuck % = far from its target but not moving · overkill % = damage past
// the last HP · predator % = time inside a hunter's reach · switches = target changes per unit-minute ·
// stacked = friendly pairs whose centres overlap by half (sampled each second) · secs = fight length
// NEW AI only (audit r1 #5): moving / yielding (crowd avoidance holding it back) / waiting / path-fail per tick, and
// BLOCKED = a reachable goal but < 25 % of the expected progress over 1.5 s (target < 3 %), longest trap in a row (target < 3 s)
import { battle, setAI, setTerrain, setFormation } from "./sim.mjs";
import fs from "node:fs";
import { positiveInt } from "./args.mjs";
const N = positiveInt(process.argv[2] ?? 20);
const jsonOut = process.argv.find(a => a.startsWith("--json="))?.slice(7);
const ONLY = process.argv.find(a => a.startsWith("--only="))?.slice(7);   // e.g. --only="Mixed E"
const C = (f1, f2, f3, f4) => Object.fromEntries(Object.entries({ F1: f1, F2: f2, F3: f3, F4: f4 }).filter(([, n]) => n));
const SCEN = [
  ["Swarm v Titan", C(32), C(0, 0, 0, 2)],
  ["Titan v Brute", C(0, 0, 0, 2), C(0, 0, 8)],
  ["Brute v Pack", C(0, 0, 8), C(0, 16)],
  ["Pack v Swarm", C(0, 16), C(32)],
  ["Swarm v Brute", C(32), C(0, 0, 8)],
  ["Mirror swarm", C(32), C(32)],
  ["Mixed A v B", C(8, 4, 4), C(0, 0, 4, 1)],
  ["Mixed C v D", C(16, 8), C(0, 4, 2, 1)],
  ["Mixed E v E", C(8, 4, 2, 1), C(8, 4, 2, 1)],
];
const out = {};
const row = (m, n, wins) => {
  const pct = (a, b) => b > 0 ? (100 * a / b).toFixed(1) : "n/a";   // never print NaN (code review r3 #17)
  const p = k => pct(m[k], m.unitT).padStart(5);
  return `fight${p("fightT")}%  stuck${p("stuckT")}%  overkill${pct(m.wasted, m.dmg).padStart(5)}%  pred${p("predT")}%  ` +
    `switch${(m.unitT > 0 ? 60 * m.switches / m.unitT : 0).toFixed(2).padStart(5)}  stacked${(m.overlapS / Math.max(1, m.overlapN)).toFixed(2).padStart(5)}  ` +
    `secs${(m.time / n).toFixed(0).padStart(4)}  A-win${(100 * wins / n).toFixed(0).padStart(4)}%` +
    (m.posT ? `
${"".padEnd(19)}moving${p("posT")}%  yielding${p("yieldT")}%  waiting${p("waitT")}%  path-fail${p("pathFailT")}%  BLOCKED${p("blockedT")}%  longest trap ${m.trapMax.toFixed(1)} s` : "");
};
for (const terrain of ["open", "boulders"]) {
  setTerrain(terrain); setFormation("open");
  console.log(`\n== ${terrain.toUpperCase()} (${N} fights each, Squish A v Crunch B, sides alternate)`);
  for (const [name, a, b] of SCEN.filter(s => !ONLY || s[0].includes(ONLY))) for (const ai of ["old", "new"]) {
    setAI(ai);
    const m = {}; let wins = 0; m.time = 0;
    for (let i = 0; i < N; i++) {
      const flip = i % 2 === 1;
      const r = flip ? battle("CRUNCH", b, "SQUISH", a, 5000 + i, new Set(), null, [1, 1], m) : battle("SQUISH", a, "CRUNCH", b, 5000 + i, new Set(), null, [1, 1], m);
      wins += r.win === 0.5 ? 0.5 : (r.win === (flip ? 1 : 0) ? 1 : 0); m.time += r.time;
    }
    out[`${terrain}|${name}|${ai}`] = { ...m, runs: N, wins };
    console.log(`${(ai === "old" ? name : "").padEnd(14)} ${ai}  ${row(m, N, wins)}`);
  }
}
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify(out, null, 1));
