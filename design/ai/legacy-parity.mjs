// Proves the AI sim's parity contract fight by fight (see the header of sim.mjs). node legacy-parity.mjs [fights]
// Runs each old-AI fight in the AI sim and in the power sim with the same seed; every field must match exactly.
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const HERE = fileURLToPath(new URL(".", import.meta.url));
const N = Number(process.argv[2] ?? 6);
const job = (simPath, flags) => `
  process.argv[1] ??= "parity-runner";   // the frozen pre-fix sim reads argv[1] at import
  process.argv.push(${flags.map(f => JSON.stringify(f)).join(",")});
  const { battle, setAI } = await import(${JSON.stringify(simPath)});
  if (setAI) setAI("old");
  const comps = [{F1:32},{F2:16},{F3:8},{F4:2},{F1:8,F2:4,F3:2,F4:1},{F1:16,F2:8},{F3:4,F4:1}], out = [];
  let seed = 100;
  for (const a of comps) for (const b of comps) for (let k = 0; k < ${N}; k++) for (const [ra, rb] of [["SQUISH","CRUNCH"],["CRUNCH","CRUNCH"]]) {
    const r = battle(ra, a, rb, b, seed++); out.push([r.win, r.left0, r.left1, r.time]);
  }
  console.log(JSON.stringify(out));`;
const run = (sim, flags) => { const r = spawnSync(process.execPath, ["--input-type=module", "-e", job(sim, flags)], { cwd: HERE, encoding: "utf8", maxBuffer: 1 << 26 }); if (r.status) throw new Error(r.stderr); return JSON.parse(r.stdout); };
const url = p => new URL(p, import.meta.url).href;
let bad = 0;
for (const [label, mine, flags, ref] of [
  ["--legacy-timer == design/power/sim.mjs (fixed)", "./sim.mjs", ["--legacy-timer"], "../power/sim.mjs"],
  ["--legacy == design/power/sim-v3-before-fix.mjs", "./sim.mjs", ["--legacy"], "../power/sim-v3-before-fix.mjs"],
]) {
  const a = run(url(mine), flags), b = run(url(ref), []);
  const diff = a.findIndex((x, i) => JSON.stringify(x) !== JSON.stringify(b[i]));
  const ok = a.length === b.length && diff < 0;
  if (!ok) bad++;
  console.log(`${ok ? "IDENTICAL" : "DIFFERENT"}  ${label}  (${a.length} fights${ok ? "" : ", first difference at fight " + diff})`);
}
if (bad) process.exitCode = 1;
