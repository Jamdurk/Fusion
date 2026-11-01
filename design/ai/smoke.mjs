// Smoke + regression tests for the AI sim (ChatGPT code review r3 / r3b test list). node smoke.mjs  (exit 1 on failure)
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { battle, setAI, setTerrain, inArc } from "./sim.mjs";
import { createBrain } from "./brain.mjs";
import { createNav } from "./nav.mjs";
import { BRAIN, validateProfiles } from "./profiles.mjs";

const HERE = fileURLToPath(new URL(".", import.meta.url));
const tests = [];
const test = (name, fn) => tests.push([name, fn]);
const finite = r => Number.isFinite(r.left0) && Number.isFinite(r.left1) && Number.isFinite(r.time);
const MIX = { F1: 8, F2: 4, F3: 2, F4: 1 };

// ---- whole battles: edge cases + determinism, both AIs, both terrains ----
for (const ai of ["old", "new"]) for (const terrain of ["open", "boulders"]) test(`battles (${ai}, ${terrain})`, () => {
  setAI(ai); setTerrain(terrain);
  assert.ok(finite(battle("SQUISH", {}, "CRUNCH", {}, 1)), "empty v empty");
  assert.ok(finite(battle("SQUISH", { F1: 1 }, "CRUNCH", {}, 2)), "one v nothing");
  assert.ok(finite(battle("SQUISH", { F1: 1 }, "CRUNCH", { F1: 1 }, 3)), "1 v 1");
  assert.ok(finite(battle("SQUISH", { F4: 2 }, "CRUNCH", { F1: 32 }, 4)), "titans v swarm");
  const a = battle("SQUISH", MIX, "CRUNCH", MIX, 5), b = battle("SQUISH", MIX, "CRUNCH", MIX, 5);
  assert.deepEqual([a.win, a.left0, a.left1, a.time], [b.win, b.left0, b.left1, b.time], "same seed, same result");
});

// ---- r3b regression cases (each one failed before its fix) ----
test("nav: blocked goal + start already on the substitute cell never ends inside the boulder", () => {
  const nav = createNav([{ x: 0, y: 0, r: 3 }]);
  for (const from of [{ x: 4.5, y: 1.5 }, { x: 1.5, y: 4.5 }]) {
    const p = nav.path(from, { x: 0, y: 0 }, 1);
    assert.ok(p === null || p.every(q => !nav.blocked(q, q, 1)), JSON.stringify(p));
  }
});
test("nav: non-finite clearance and out-of-grid points return null (Infinity used to hang)", () => {
  const nav = createNav([{ x: 0, y: 0, r: 3 }]);
  assert.equal(nav.path({ x: 30, y: 30 }, { x: 0, y: 30 }, Infinity), null);
  assert.equal(nav.path({ x: 30, y: 30 }, { x: 0, y: 30 }, NaN), null);
  assert.equal(nav.path({ x: 500, y: 0 }, { x: 0, y: 20 }, 1), null);
});
test("nav: 150 random routes never cross a boulder", () => {
  let s = 7; const R = () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
  for (let k = 0; k < 150; k++) {
    const ob = []; for (let i = 0; i < 5; i++) ob.push({ x: (R() - 0.5) * 60, y: (R() - 0.5) * 60, r: 2.5 + R() * 3.5 });
    const nav = createNav(ob), r = 1 + R() * 4.5, a = { x: -40, y: (R() - 0.5) * 40 }, b = { x: 40, y: (R() - 0.5) * 40 };
    if (nav.blocked(a, a, r) || nav.blocked(b, b, r)) continue;
    const p = nav.path(a, b, r); if (!p) continue;
    let prev = a; for (const q of p) { assert.ok(!nav.blocked(prev, q, r), `route ${k} crosses a boulder`); prev = q; }
  }
});
test("arc: facing wound past 2π still rejects an enemy behind (facing 3π / 4π)", () => {
  assert.equal(inArc(1, 0, 3 * Math.PI, 120), false, "3π faces away from bearing 0");
  assert.equal(inArc(1, 0, 4 * Math.PI, 120), true, "4π faces bearing 0");
  assert.equal(inArc(-1, 0, 4 * Math.PI, 120), false);
  assert.throws(() => inArc(1, 0, Infinity, 120), RangeError, "a non-finite facing fails fast (used to loop forever)");
});
test("brain: EVADE → ENGAGE drops the old route", () => {
  const u = { x: 0, y: 0, r: 1.6, reach: 1.2, form: "F2", race: "SQUISH", team: 0, matter: 2, alive: true, hp: 235, maxHp: 235, face: 0 };
  const brain = createBrain({ units: [u], rand: () => 0.5, DT: 0.1, now: () => 0, obstacles: [] });
  brain.init(u);
  brain.setMode(u, "EVADE"); u.ai.path = [{ x: 9, y: 9 }]; u.ai.detour = { x: 9, y: 9 }; u.ai.detourUntil = 5;
  brain.setMode(u, "ENGAGE");
  assert.equal(u.ai.path, null); assert.equal(u.ai.detour, null);
});
test("profiles: invalid numbers are rejected (speedJitter NaN, senseRange Infinity)", () => {
  for (const [k, v] of [["speedJitter", NaN], ["senseRange", Infinity]]) {
    const old = BRAIN[k]; BRAIN[k] = v;
    try { assert.throws(() => validateProfiles(), RangeError, k); } finally { BRAIN[k] = old; }
  }
  assert.equal(validateProfiles(), true);
});
test("harness: metrics with 0 runs exits 2 instead of printing NaN", () => {
  const r = spawnSync(process.execPath, ["metrics.mjs", "0", "--only=Mixed E"], { cwd: HERE, encoding: "utf8", timeout: 20000 });
  assert.equal(r.status, 2); assert.ok(!/NaN/.test(r.stdout));
});
test("sim: --dt=0 exits 2 instead of hanging", () => {
  const r = spawnSync(process.execPath, ["sim.mjs", "2", "--dt=0", "--only=none"], { cwd: HERE, encoding: "utf8", timeout: 20000 });
  assert.equal(r.status, 2);
});

test("parity contract: --legacy-timer == power sim, --legacy == pre-fix power sim, fight by fight", () => {
  const r = spawnSync(process.execPath, ["legacy-parity.mjs", "1"], { cwd: HERE, encoding: "utf8", timeout: 120000 });
  assert.equal(r.status, 0, r.stdout + r.stderr);
});

let failed = 0;
for (const [name, fn] of tests) {
  try { fn(); console.log("PASS", name); } catch (e) { failed++; console.log("FAIL", name, "-", e.message); }
}
console.log(failed ? `${failed} FAILED` : `all ${tests.length} passed`);
if (failed) process.exitCode = 1;
