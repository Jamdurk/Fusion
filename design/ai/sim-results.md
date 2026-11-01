# Alien AI: sim results (28 Oct 2026)

All from `design\ai\` (`sim.mjs --ai=old|new`). The old AI in this copy reproduces `design\power\` exactly (diffed).
EDGE = how much extra HP the other side needs to tie (1.00 = even). Race pairings in order S v C · C v S · S v S · C v C.

## 1. Balance with the NEW AI (v2 = audit r1 fixes): `final-run-v4.txt`, 60 fights per search step
| Check | Target | Old AI (power graph) | New AI open | New AI spread | New AI narrow lane |
|---|---|---|---|---|---|
| Race mirror F1-F4 | 0.90-1.10 | 0.96 · 0.99 · 1.05 · 1.01 | 0.96 · 1.03 · 1.04 · 1.05 | 1.02 · 1.00 · 1.05 · 1.04 | 0.96 · 1.05 · 1.05 · 1.04 |
| Swarm > Titan | 1.4-3.0 | 2.33-2.57 | 1.94 · 2.57 · 1.98 · 2.57 | 1.92-2.67 | 1.92 · 2.41 · 1.89 · 2.42 |
| Titan > Brute | 1.4-3.0 | 2.23-2.35 | 2.46 · 2.23 · 2.40 · 2.36 | 2.11-2.36 | 2.79 · 2.87 · 2.95 · **3.06** (old 2.99-3.13) |
| Brute > Pack | 1.4-3.0 | 2.09-2.59 | 2.81 · 2.11 · 2.23 · 2.72 | 2.22-2.59 | **2.93** · 2.11 · 2.14 · 2.72 |
| Pack > Swarm | 1.4-3.0 | 2.20 | 2.20 (all four) | 2.01-2.20 | 2.60 · 2.40 · 2.60 · 2.40 |
| Swarm v Brute | 0.77-1.30 | 1.12-1.27 | 1.07 · 1.10 · 0.98 · 1.19 | 0.96-1.17 | 1.08 · 1.08 · 0.98 · 1.21 |
| Pack v Titan | 0.77-1.30 | 0.82-0.83 | 0.83 · 0.82 · 0.82 · 0.83 | 0.85-0.90 | **0.69 · 0.67 · 0.67 · 0.69** (old 0.76-0.77): Packs can't get round a Titan's front in a 20-stud lane |
| Mixed armies: best mix | — | 76 % | 73 % (`mixed-new.txt`, 8 fights a pair) | | |
| Every mix has a counter >= 65 % | yes | yes | yes (all 44) | | |
| Mixed armies: Squish / Crunch | 49-51 % | 51.9 / 48.1 | **53.5 / 46.5** (see §3) | | |

**Tick rate (ChatGPT r1 #4):** at 20 Hz movement (`--dt=0.05`, the Roblox plan) the new AI's counters stay in range
(Swarm>Titan 1.75-2.36, Titan>Brute 2.36-2.50, Brute>Pack 1.98-2.72, Pack>Swarm 2.60), but the OLD AI moves the same way
(Pack>Swarm 2.20 → 2.40, Swarm>Titan ~2.4 → ~2.2): the kit timing itself is tick-sensitive. Re-check the power graph at
the Roblox tick before locking numbers.

## 2. Behaviour, OLD vs NEW (`metrics.mjs`, 20 fights a scenario, open + boulder plain): `final-run-v4.txt` + `metrics.json`
| Scenario (open / boulders) | Stacked friends old → new | Target switches / unit-min old → new | Time in a hunter's reach old → new | Hitting old → new | BLOCKED (new) | Longest trap (new) |
|---|---|---|---|---|---|---|
| Swarm v Titan | 12.8 → 1.7 / 12.6 → 1.8 | 11.5 → 14.4 | 4.6 → 5.3 % | 59 → 54 % | 0.3 / 0.4 % | 1.6 / 3.2 s |
| Titan v Brute | 0.8 → 0.5 | 5.1 → 2.8 | 53 → 45 % | 50 → 45 % / 47 → 38 % | 0.0 / 0.3 % | 0 / 1.6 s |
| Brute v Pack | 2.4 → 0.9 | 24.5 → 9.6 | 45 → 39 % | 65 → 55 % | 0.0 % | 0 s |
| Pack v Swarm | 5.6 → 1.4 / 6.3 → 1.3 | 43.7 → 13.0 / 48.8 → 12.9 | 43 → 38 % | 60 → 51 % | 0.0 % | 1.6 s |
| Swarm v Brute | 5.7 → 1.0 / 6.2 → 0.9 | 22.9 → 15.2 | 0 % | 68 → 61 % | 0.0 / 0.1 % | 1.6 s |
| Mirror swarm | 4.3 → 0.7 / 4.4 → 0.9 | 43.6 → 14.3 | 0 % | 76 → 65 % | 0.1 % | 1.6 / 3.1 s |
| Mixed A v B | 0.8 → 0.3 | 20.0 → 8.3 | 29 → 20 % / 30 → 19 % | 68 → 59 % | 0.2 / 0.4 % | 3.2 / 1.6 s |
| Mixed C v D | 2.2 → 0.5 | 29.6 → 9.5 | 28 → 20 % / 27 → 22 % | 69 → 57 % | 0.2 / 0.1 % | 3.0 / 1.6 s |
| **Mixed E v E** (all 4 forms each side) | 0.4 → 0.2 | 33.4 → 27.1 / 35.7 → 24.5 | 29 → 16 % / 27 → 14 % | **53 → 35 % / 52 → 33 %** | **4.6 / 3.8 %** | **4.8 s** |
New-AI time split (open, typical): hitting 50-65 %, moving 18-28 %, yielding (giving way in a crowd) 4-15 %, waiting
1-3 %, blocked 0-0.4 %. Fights last 1-5 s longer (positioning costs time). Overkill is about the same (it's set by the
Titan-vs-swarm design). **Weak spot:** the all-four-forms mixed fight: hitting time drops by a third, switches stay high,
blocked 3.8-4.6 % (target < 3 %): evade cycles (run to the protector, 3 s fight, run again) through a dense four-way melee.

## 3. The race-parity finding (for the power graph, not the AI)
New AI, mixed armies: Squish 53.5 % vs Crunch 46.5 % (old AI 51.9 / 48.1; target 49-51). It is NOT the AI's race
personality: with courage, evade, the Drip's flank rule, the Ram ramp and the Pincer post each switched off in turn, the
quick parity check (`parity.mjs`, 384-640 fights, ±2-3 points noise) stays at 53-57 % Squish. Switching off single
ABILITIES: **BOING SLAM off → 49.7 %, STRETCH GRAB off → 51.3 %**; others 52.9-58.1 %. Reading: the new AI makes units
stand in tidy rings round their targets, and the Twin's circle splash (BOING SLAM, 3 targets in 5 studs) catches those
rings better than the Pincer's straight SIDE SWEEP; the Brute's 14-stud grab pulls runners into slots. Kits are read-only
for this job (`design\power\`), so this goes to James / the power graph: a small BOING SLAM trim (or SIDE SWEEP made an
arc) is the likely fix; re-check in Roblox with real clumping first.

## 4. Bot counter table (`bot-table.mjs` → `bot-table.json`, 4 fights a pair, new AI)
For every one of the 22 mixes, in all four race pairings, some mix beats it ~100 % (98-100 % on average): with perfect
answers a bot would crush kids, and (ChatGPT r1) it couldn't reach that mix in time anyway → the bot plans one legal
fuse/split at a time (design §6). The table stays as the bot's "counter value" input.

## 5. What the sim can't tell us
Animation, tells and feel (the "iffy" test is on screen); real terrain, crater, canyon, bases; players moving the rally
point; network smoothing; phone CPU. Those are the design §7 gates and the four visual playtests.

## 6. v2.1 at the standard rate (after ChatGPT r2): 20 Hz, attack timer keeps its remainder, 40 fights per step
| Check | Target | OLD AI (`check-20hz-old.txt`) | NEW AI v2.1 (`check-20hz-new.txt`) |
|---|---|---|---|
| Race mirror F1-F4 | 0.90-1.10 | 0.96 · 0.98 · 1.09 · 0.97 | 1.02 · 1.04 · 1.08 · 1.01 |
| Swarm > Titan | 1.4-3.0 | 2.20 · 2.49 · 2.19 · 2.49 | 1.94 · 2.50 · 1.87 · 2.46 |
| Titan > Brute | 1.4-3.0 | 2.52 · 2.26 · 2.40 · 2.48 | 2.63 · 2.49 · 2.50 · 2.63 |
| Brute > Pack | 1.4-3.0 | 2.59 · 1.98 · 2.01 · 2.46 | 2.72 · 2.01 · 2.11 · 2.63 |
| Pack > Swarm | 1.4-3.0 | 2.20 (all four) | 2.40 · 2.20 · 2.40 · 2.20 |
| Swarm v Brute | 0.77-1.30 | 1.11 · 1.23 · 1.11 · 1.25 | 1.02 · 1.04 · 0.94 · 1.15 |
| Pack v Titan | 0.77-1.30 | 0.84 · 0.83 · 0.83 · 0.84 | 0.90 · 0.86 · 0.86 · 0.90 |
| | | **ALL TARGETS MET** | **ALL TARGETS MET** |
| Race parity, mixed (`parity-20hz.txt`, 640 fights, ±2) | 49-51 | Squish 52.7 % | **Squish 57.5 %** |
So the power graph holds at the Roblox tick with either AI; the new AI widens Squish's lead in MIXED armies by ~5 points
(open item §3, method per ChatGPT r2: compare each ability under old and new AI with paired seeds).
Four-form mix, v2.1, 20 Hz (open / boulders): hitting 39.2 / 38.9 % (old 52 / 51; ChatGPT target 42), blocked 2.2 / 1.5 %,
hunter exposure 20.3 / 20.4 % (old 26.8), switches 9.6 / 9.3 per unit-min (old 34 / 40), longest trap 3.1 / 4.6 s.

## 7. v2.2 FINAL (after the ChatGPT code review, SHIP): 20 Hz, corrected engine (AoE sort, wedge wrap, remainder timer)
`check-20hz-new-final.txt` / `check-20hz-old-final.txt`, 40 fights per step: **ALL TARGETS MET for both AIs.**
NEW: mirrors 1.02-1.08 · Swarm>Titan 1.87-2.54 · Titan>Brute 2.52-2.63 · Brute>Pack 2.05-2.72 · Pack>Swarm 2.40 ·
diagonals 0.84-1.14. OLD: mirrors 0.96-1.09 · counters 1.98-2.59 · diagonals 0.83-1.25.
Race parity (`v22-parity-metrics.txt`, 640 fights each, ±2.8): new 56.1 % vs old 54.1 % Squish: the AI's own effect is
~2 points (noise-level); Squish leads with either AI once the engine bugs are fixed → a kit question for the power graph.
Four-form mix (20 Hz, open / boulders): hitting 41.4 / 40.5 %, blocked 2.3 / 1.4 %, hunter exposure 20.4 / 19.4 %,
switches 9.3 / 8.9 per unit-min; longest trap 4.6 / 7.5 s (still over the 3 s target: open item).
Side bias after interleaving: team 0 wins 52.0 % of 300 new-AI mirror fights (was 54.4 % of 500).
Regression suite: `node smoke.mjs` → 12 / 12 (independently re-run by ChatGPT on Node 22.16).
