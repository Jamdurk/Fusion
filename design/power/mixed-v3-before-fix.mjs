// Mixed armies: every 32-matter composition on a coarse grid, both races, round robin.
// Checks: no composition dominates the field, and Squish vs Crunch stays even overall.
// node mixed.mjs [runsPerPair] [--json=file]
import { battle } from "./sim.mjs";
import fs from "node:fs";
const N = Number(process.argv[2] ?? 6);
const jsonOut = process.argv.find(a => a.startsWith("--json="))?.slice(7);
const comps = [];
for (let f4 = 0; f4 <= 2; f4++) for (let f3 = 0; f3 <= 8; f3 += 2) for (let f2 = 0; f2 <= 16; f2 += 4) {
  const f1 = 32 - 16 * f4 - 4 * f3 - 2 * f2; if (f1 < 0 || f1 % 4) continue;
  comps.push({ F1: f1, F2: f2, F3: f3, F4: f4 });
}
const name = c => `${c.F4}T ${c.F3}B ${c.F2}P ${c.F1}S`;
const clean = c => Object.fromEntries(Object.entries(c).filter(([, n]) => n > 0));
const entries = [];
for (const race of ["SQUISH", "CRUNCH"]) for (const c of comps) entries.push({ race, c, w: 0, g: 0 });
const pair = {};
let seed = 1, raceW = { SQUISH: 0, CRUNCH: 0 }, raceG = 0;
for (let i = 0; i < entries.length; i++) for (let j = i + 1; j < entries.length; j++) {
  const A = entries[i], B = entries[j];
  for (let k = 0; k < N; k++) {
    const r = battle(A.race, clean(A.c), B.race, clean(B.c), seed++);
    const aw = r.win === 0.5 ? 0.5 : r.win === 0 ? 1 : 0;
    pair[i + "," + j] = (pair[i + "," + j] ?? 0) + aw / N; pair[j + "," + i] = (pair[j + "," + i] ?? 0) + (1 - aw) / N;
    A.w += aw; B.w += 1 - aw; A.g++; B.g++;
    if (A.race !== B.race) { raceW[A.race] += aw; raceW[B.race] += 1 - aw; raceG++; }
  }
}
entries.forEach((e, i) => { let bj = -1, bw = 1; entries.forEach((f, j) => { if (j !== i && pair[i + "," + j] < bw) { bw = pair[i + "," + j]; bj = j; } }); e.counter = { by: entries[bj], win: 1 - bw }; });
entries.sort((a, b) => b.w / b.g - a.w / a.g);
console.log(`${comps.length} compositions x 2 races, ${N} fights per pair`);
console.log("TOP 8 (and its hardest counter):"); for (const e of entries.slice(0, 8)) console.log(` ${(100 * e.w / e.g).toFixed(0).padStart(3)}%  ${e.race.padEnd(6)} ${name(e.c).padEnd(14)} countered by ${e.counter.by.race} ${name(e.counter.by.c)} (${(100 * e.counter.win).toFixed(0)}%)`);
const uncountered = entries.filter(e => e.counter.win < 0.65);
console.log(uncountered.length ? `!! ${uncountered.length} compositions with no counter >= 65%: ` + uncountered.map(e => e.race[0] + " " + name(e.c)).join(", ") : "Every composition has a counter that beats it >= 65%");
console.log("BOTTOM 5:"); for (const e of entries.slice(-5)) console.log(` ${(100 * e.w / e.g).toFixed(0).padStart(3)}%  ${e.race.padEnd(6)} ${name(e.c)}`);
console.log(`Cross-race overall: SQUISH ${(100 * raceW.SQUISH / raceG).toFixed(1)}%  CRUNCH ${(100 * raceW.CRUNCH / raceG).toFixed(1)}%`);
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify({ entries: entries.map(e => ({ race: e.race, comp: e.c, win: e.w / e.g, counter: { race: e.counter.by.race, comp: e.counter.by.c, win: e.counter.win } })), race: { SQUISH: raceW.SQUISH / raceG, CRUNCH: raceW.CRUNCH / raceG } }, null, 1));
