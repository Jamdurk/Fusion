# ChatGPT audits of the alien AI (Thinking, high effort; power-graph chat
https://chatgpt.com/c/6ae17ad9-cfa8-83ec-8c4a-a48125563b96)

## Round 1 (28 Oct ~6:45 PM): GO WITH CHANGES, "do not port v1 verbatim"
Inputs: 11-ALIEN-AI.md, brain / profiles / orca / nav / sim (JS), kits.js, research-lc-code.md, research-deep.md,
check-new-ai.txt. Raw reply: `chatgpt-audit-r1-raw.md` (the reply stops partway through its §5 bot section; the
bot / Roblox / "iffy" answers are asked again in round 2).
"Architecture: approved. Implementation: not yet. A better foundation than the old nearest-enemy AI." It compared the
ORCA port with RVO2's Agent.cc: **lp1 / lp2 / lp3 PASS**, the per-pair `share` (m_B / (m_A + m_B), the two sides sum to 1)
"mathematically sound".

| # | Required change | What I did (v2) |
|---|---|---|
| 1 | EVADE never fired: the saviour test excluded exactly the form that hunts the hunter | Found the same bug myself while it was thinking; fixed (nearest alive friend whose form hunts my hunter). Effect in the full mixed fight: time inside a hunter's reach 23 % → 14 %, hitting time 48 % → 36 % (evaders spend time getting behind protectors). Tried a stricter trigger (fear > 1): kept the cost, lost most of the safety → back to LC's fear > 0 |
| 2 | Slots keyed by per-size indices (a Drip's slot 2 ≠ a Brute's slot 2), released without checking the owner, re-picked every 0.6-1 s (orbiting) | One shared 24-sector ring per target; an attacker holds as many sectors as its width needs; release only my own; keep the spot until the target changes, I'm blocked, or after 1.5 s a free spot is >= 2 studs shorter to walk to |
| 3 | ORCA: exact overlap gives zero velocity; units updated one after another (later ones see earlier ones' new positions) | Deterministic split direction from unit ids for exact overlaps (ORCA and the hard separation, new AI only so the old AI stays identical); two-phase movement: every unit plans from the same snapshot, then all integrate |
| 4 | A*: blocked cells allowed near ANY start; blocked goal appended; failed paths retried every tick | Retry limiter: one path attempt per second whether or not it worked; 3 failures → that target is "unreachable" for 3 s (scored x0.2); blocked units drop a target for 2 s. Blocked cells may only be crossed when the unit's OWN start cell is blocked (stepping out); a blocked goal → the nearest free cell, and a blocked destination is never appended (tested: a boulder in the way, a goal inside a boulder, a unit pressed into one) |
| 5 | "Stuck 4-12 % = price of positioning" not accepted: split fighting / positioning / yielding / blocked / path-failed; blocked < 3 %, no trap > 3 s | Done (`metrics.mjs`). The first split showed my window counted fight time as blocked (fixed: the window restarts after any non-moving spell) and crowd-yielding as blocked (now its own state). Blocked evaders/guards now fight instead (LC: cornered = fight) |
| 6 | Personalities exist in comments, not code (Pincer, Ram, Brute, Titan, Colossus) | Ram: Thumper ramp (70 % → 100 % speed after 0.6 s of straight pursuit, turns 20 % worse at full, resets on a 45° turn or block). Pincer: Nutcracker post (holds a spot between a big friend and the threat for 2 s; moves if the friend walks > 6 off it or prey comes into reach). Brute meter / Titan stop-and-look: presentation, in `TELLS` (Roblox) |
| 7 | Overkill estimate used base DPS (a Titan slam is 250 DPS vs a Brute); attack of opportunity took the first enemy in the list | Effective per-target damage (passive hit x multiplier / interval, swarm bonus when 6+ are on it); opportunity attacks pick the best prey in reach |
| 8 | Re-run everything + new checks after the fixes; don't touch power-graph numbers | `final-run-v4.txt`, `mixed-new.txt`, `metrics.json` |
Its other answers: LC fidelity "generally sensible as inspiration", not every alien a faithful port yet; fit scores Drip 9,
Pebble 8, Twin 9, Pincer 7, Brute 7, Ram 7, Titan 8, Colossus 7 ("don't replace the sources; finish the translation").
Squish 1.98 vs Crunch 2.64 vs Titans: **accept provisionally**, re-check after the evade fix; worry if one swarm is > 30 %
stronger with nothing in return. Titan-slam rule: agree with no warning-triggered dodging for F2/F3, but don't freeze
them either (ordinary movement continues): that is what the code does; the design wording is clarified. Licences: keep
RVO2's notice (done); keep any written permission from Zeekers with the project docs (James has it verbally only).

### Round 1, second half (asked to finish §5-8; same chat): GO WITH CHANGES
"The bot and networking architecture are worth keeping", checked against Roblox's docs with web search this time.
| # | Required change | Where it went |
|---|---|---|
| 1 | Bot: not "the 3rd-best static mix" (it can't reach a mix in time): a one-step utility planner over LEGAL single actions; Normal = random among the best 3 (50/30/20); keep 20/12/6 s rethinks, 3/1.5/0.6 s reactions | design §6 (+ change thresholds 15/10/5 %, Orders judged every 0.2 s, 3 s regroup commitment) |
| 2 | Transformations really reachable: real 0.35-1.4 s, 5 s lock, one per decision, invariants, no transforming in melee unless James changes that | design §6 |
| 3 | Glow: keep 30 % of ALL living units; 0.3 s on / 0.4 s off hysteresis; manual Orders never need the glow | design §6 |
| 4 | 20 Hz server movement with snapshot ORCA, 5 Hz think; validate the time step against the JS sim | design §7 (sim runs 10 Hz: open item) |
| 5 | Per-size navigation clearance; ONE global path queue (start 4 ComputeAsync/s, 2 s per unit) | design §7 |
| 6 | Sequenced compact unreliable snapshots at 10 Hz; reliable spawn / death / fusion / combat events; test loss + delay | design §7 |
| 7 | Per-creature presentation tests (facing, tells, switch transitions, commitment, stuck recovery): "a passing combat sim is not enough" | design §7, four visual playtests |
| 8 | 64-unit phone stress test before replacing EntityAI; keep a rollback | design §7 |
Verified facts it cited (Roblox Creator Hub): UnreliableRemoteEvent may drop / reorder, payload limit 1,000 bytes;
ComputeAsync yields, 3,000-stud start-finish limit, 20,000-node budget, AgentRadius / AgentHeight; manual server
network ownership can jitter; client-owned physics can't be trusted for competitive play. The "150 paths lag a server"
figure is one DevForum report, not a platform limit. Its rates for 64 units: 320 decisions/s at 5 Hz, 1,280 steering
updates/s at 20 Hz, ~5.3 decisions per frame (workload, not measured cost).


## Round 2 (28 Oct ~8 PM): GO WITH CHANGES, "approve the design direction, not a final balance lock"
Inputs: the v2 design + sim-results + final-run-v4 + v2 code. Raw: `chatgpt-audit-r2-raw.md`. It RAN the sim itself on
the four-form mix (20 paired trials) and showed the weak spot is EVADE: all evade 35.6 % uptime / 3.9 % blocked / 14.8 %
hunter exposure; only F1 evades 44.3 / 1.7 / 21.5; evade off 48.3 / 0.2 / 21.7; its selective-evade copy 42.2 / 2.5 / 19.9.
Disposition for James: shared brain APPROVED; ORCA + snapshot APPROVED (keep hard separation); 24-sector slots APPROVED
(fix lifecycle); the eight identities APPROVED subject to the visual tests; EVADE + A* REVISE; power graph provisionally
approved (re-run at 20 Hz); race parity an open balance item (no kit changes now); Roblox §7 APPROVED for implementation
planning; **the v2 sim as a literal Luau port NOT approved** (port behaviour + maths).
| # | Required change | What I did (v2.1) |
|---|---|---|
| 1 | A unit going EVADE / GUARD kept its 5 melee sectors reserved (it reproduced this) | Spots are released on entering EVADE or GUARD; a fresh one is taken on returning to ENGAGE; dead units' sectors already count as free |
| 2 | Selective F2/F3 evade: protector within 14, the spot behind it >= 4 studs further from the hunter, not while already hitting prey (unless < 30 % HP), 6 s commitment to ENGAGE afterwards, keep the target in memory while evading | Done exactly as specified (F1 unchanged, 3 s) |
| 3 | BLOCKED handled every think tick (re-extending timers / penalties); progress measured as displacement only | One-shot blocked EVENTS (each consumed once); blocked = < 25 % displacement AND < 25 % closer to the goal over the window |
| 4 | Blocked-goal fallback took the first free cell on an expanding square; cached paths survived goal moves < 4 studs | Free cell nearest the real goal (ties: nearest the start), or a real failure; repath when the goal moves > 2 studs (1 s minimum), paths expire after 2 s or at their last waypoint |
| 5 | Pincer GUARD fired whenever a big friend existed | Needs a living enemy swarmer within 12 of that friend |
| 6 | Attack timer dropped the remainder (a 1.25 s attack ran at 1.3 s at 10 Hz: ~4 %, tick-sensitive); make 20 Hz canonical | Remainder kept (never banks a second attack); `--legacy-timer` reproduces the power graph exactly for comparison; 20 Hz re-runs: `check-20hz-new.txt` / `check-20hz-old.txt` / `parity-20hz.txt` |
Four-form mix after v2.1, 20 Hz, 20 fights (open / boulders): hitting 39.2 / 38.9 % (its target 42; it also warned
fightT under-counts Titan locks and "don't tune the whole AI to a fightT percentage"), blocked 2.2 / 1.5 % (target < 3 ✓),
hunter exposure 20.3 / 20.4 % (target <= 20: on the line), target switches 9.6 / 9.3 per unit-minute (was 27 / 24),
longest trap 3.1 / 4.6 s (target 3: still over in the boulders).
Its other answers: race parity = a power-graph interaction, not proven to be BOING SLAM alone; compare each ability under
old AND new AI with paired seeds before trying "BOING SLAM 20 → 18" or "SIDE SWEEP as a 160° arc" (playtest candidates,
not approved changes). Lane Pack v Titan 0.67: accept only if the corridor is optional (Packs can go round); test a Titan
holding a corridor on the real map. Lower hitting time: acceptable in ordinary fights, not yet in the four-form mix.
Precision note it asked for: Brute>Pack 2.93 is inside the 3.0 limit (only Titan>Brute 3.06 is over).


## Round 3: CODE REVIEW (28 Oct ~9 PM): NOT READY → fixed (v2.2); each finding checked, not just accepted
James: "ensure no buggy code, robust, expert dev code standards" + "don't just accept what it says: if you disagree or
think there's more nuance, rebut". Raw: `chatgpt-audit-r3-code-raw.md`. It ran the code (Node 22).
| # | Finding (severity) | Claude's check | Outcome |
|---|---|---|---|
| 1 | AoE caps sort with d2(unit, shape) = NaN (shapes use cx/cy) (BLOCKER) | CONFIRMED, and it's in `design/power/sim.mjs` too (the power-graph numbers carry it) | Fixed: nearest to the shape centre, ties by unit id; `--legacy` keeps the old comparator for bit-exact reproduction. Flag for the power graph |
| 2 | The brain can pick dead targets from the tick's stale lists (BLOCKER) | CONFIRMED (low impact: damage() ignores the dead, but a wasted tick) | Fixed: think() filters to living units; clearTarget() everywhere |
| 3 | A* paths cut through boulders, 19 of 77 (BLOCKER) | CONFIRMED (my test: 17/80, then 53/200). Also found the root cause it missed: nav planned at 0.8 r while the sim pushes units out at 0.9 r | Rewritten: 1-stud grid inflated by clearance + half a cell diagonal, smoothing at full clearance, every leg proved, unsmoothed fallback, a pressed-in unit steps radially out first. Now **0 / 289** unsafe |
| 4 | `--ai=old --legacy-timer` doesn't reproduce the power graph (BLOCKER) | **REBUTTED**: full matrix (12 runs) and check.mjs are byte-identical to the CURRENT `design/power/sim.mjs`; it compared against an older copy from the power-graph audits | Contract made explicit: `--legacy` = bit-for-bit current power sim; default = corrected engine |
| 5 | Mixed harness puts SQUISH on team 0 in every cross-race fight (BLOCKER) | CONFIRMED for `mixed.mjs` (inherited from the power graph: its 51.9 / 48.1 has the same bias). But my race-parity delta came from `parity.mjs`, which already alternates sides | Fixed mixed.mjs (alternating orientation); the parity finding stands, re-measured below |
| 6 | --dt=0 hangs, NaN / negative accepted (BLOCKER) | CONFIRMED (dt 0 never advances) | --dt must be 0.01-0.2 or exit 2; check.mjs rejects bad run counts |
| 7 | Unit at a boulder's exact centre never pushed out (MAJOR) | CONFIRMED | Deterministic direction by unit id |
| 8 | Separation can push units back into boulders (MAJOR) | CONFIRMED | Boulders resolve again after separation (they get the last word) |
| 9 | Nav silently clamps out-of-grid points (MAJOR) | CONFIRMED | path() returns null (a real failure) |
| 10 | Blocked-goal fallback may be unreachable (MAJOR) | CONFIRMED (edge case) | Tries the 3 nearest free cells with A* |
| 11 | No-enemies branch leaves sectors reserved (MAJOR) | CONFIRMED | clearTarget() releases the slot and clears goal / saviour / route |
| 12 | Path / progress state outlives a target change (MAJOR) | CONFIRMED | resetRoute() on every target change. **Partly rebutted:** version tags are not needed in a single-threaded sim where the reset happens at the change itself |
| 13 | Decisions are order-dependent (MAJOR) | CONFIRMED BY MEASUREMENT: team 0 (processed first) won 54.4 % of 500 new-AI mirror fights (old AI 48.4 %) | Teams interleaved, first mover alternating each tick: 52.0 % of 300 (noise). **Partly rebutted:** a full claim-resolution phase is overkill for a 5 Hz brain; the Luau contract = stable-id order, alternating teams |
| 14 | ORCA accepts invalid numbers (MAJOR) | Partly: no invalid input reaches it today | **Partly rebutted:** no per-call throws in the hottest loop; DT + profiles validated once in createBrain(), non-finite velocities replaced with 0 before commit |
| 15 | Mutable profiles, no validation (MAJOR) | CONFIRMED | validateProfiles() on every createBrain(). **Rebutted:** freezing: the ablation harnesses mutate profiles on purpose, and they get validated too |
| 16 | Math.random fallback in makeUnit (MAJOR) | CONFIRMED (never used, but a trap) | Seeded rand required (throws otherwise) |
| 17 | Harnesses don't fail CI; NaN on zero denominators (MAJOR) | CONFIRMED | check.mjs exits 1 on a flagged target; metrics prints "n/a" |
| 18 | Attack-timer contract (MINOR) | **Rebutted in part:** the carry is already capped at one interval (no bursts) | Absolute-timestamp scheduling written into the Roblox plan (design §7) |
| 19 | No disposal contract for per-unit state (MINOR) | **Rebutted for the sim:** all state is battle-scoped and discarded | Disposal (ids + generation counters, dispose on death / fusion) written into the Roblox plan |
| 20 | Hot-loop allocations / full scans (MINOR) | True, but the sim isn't the runtime | Spatial hash, top-K selection, scratch reuse = Roblox plan items |
| 21 | Brain coupled to sim internals (MINOR) | True | The brain's unit contract is now written at the top of brain.mjs; a UnitSnapshot interface is a port item |
| 22 | Nits: stale header, unused dT, opaque preferPick (NIT) | CONFIRMED + one it missed: the "run directly" check crashed when sim.mjs was imported without a script path | All fixed |
Verification after the fixes: `--legacy` still byte-identical to the power sim (matrix + check); `smoke.mjs` (empty v
empty, 1 v nothing, 1 v 1, Titans v 32 swarm, same seed twice = identical, old + new AI, open + boulders) passes;
`node sim.mjs --dt=0` exits 2 with a message.

### Round 3b (re-review of v2.2 after my rebuttals): SHIP WITH FIXES
Raw: `chatgpt-audit-r3b-code-raw.md`. It ran smoke + side-bias itself and reproduced 52.0 % (300 fights).
Rebuttals: **#4 ACCEPTED** ("my earlier comparison used an older power-graph snapshot. I will not maintain that
objection"); #14, #18, #19, #20, #21 ACCEPTED; #13 PARTIAL then withdrawn ("I withdraw the earlier claim that the reference
needs a full simultaneous slot-claim resolution stage"); #15 freezing not required (validation incomplete: fixed).
Six new merge-gate items, ALL reproduced by me before fixing (no rebuttals): (1) A* empty chain returned a point INSIDE
the boulder when the start already sat on the substitute cell; (2) EVADE → ENGAGE kept the old route (now one setMode()
for every mode change: frees sectors, resets the route); (3) clearance = Infinity hung nav (finite checks, obstacles
validated, grid loops clamped); (4) **the Titan wedge test was wrong once a facing wound past 2π** (also in
`design/power/sim.mjs`: flag for the power graph; fixed via an exported `inArc()`, original kept under `--legacy`);
(5) validateProfiles now covers every number the brain reads; (6) a shared `args.mjs` positiveInt() for every harness.
`smoke.mjs`: 12 tests incl. its exact counterexamples.

### Round 3c (final): **SHIP**: "approved as the JavaScript reference implementation for the Luau port"
Raw: `chatgpt-audit-r3c-code-raw.md`. Ran smoke.js on Node 22.16: 12 / 12. All six fixes ACCEPTED. One non-blocking
MINOR: the new angleBetween() looped forever on an infinite angle → fixed anyway (constant-time atan2(sin, cos) wrap,
throws on non-finite; brain's helper too) + a 13th assertion. Its caveats: the power-graph parity comparison is my
reported result (that file wasn't in its upload); SHIP doesn't certify Luau performance, networking or animation
integration. "The next engineering work should be differential testing between Luau and the frozen JS reference."
