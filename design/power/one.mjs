import { matchup, COMP } from "./sim.mjs";
// node one.mjs SQUISH.F3 CRUNCH.F3 N off1,off2 ...variants separated by spaces after N
const [a, b, n, ...vars] = process.argv.slice(2);
const [ra, fa] = a.split("."), [rb, fb] = b.split(".");
for (const v of (vars.length ? vars : [""])) { const m = matchup(ra, COMP[fa], rb, COMP[fb], Number(n), new Set(v.split(",").filter(Boolean))); console.log((v || "(all on)").padEnd(20), (m.winA * 100).toFixed(0) + "%", "left", (m.winnerLeft * 100).toFixed(0) + "%", m.time.toFixed(0) + "s"); }
