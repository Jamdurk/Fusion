# Alien Fusion: the alien AI (design v2.2, 28 Oct 2026; ChatGPT r1 + r2 GO WITH CHANGES; r3 code review SHIP)

James: draw from games like **Lethal Company** (the old AI "was a bit iffy"); take proven AI, don't invent it; Zeekers
OK'd using LC's creature behaviour; "download code, pull code, anything you need". Handover: `10-AI-HANDOVER.md`.
**Data:** `ai\profiles.mjs` (every tunable number, like `power\kits.mjs`). **Brain:** `ai\brain.mjs`. **Sim:** `ai\sim.mjs`
(`--ai=old|new`). **Sources + licences:** `ai\SOURCES.md`. **Research:** `ai\research-lc-code.md` (LC's real code),
`ai\research-deep.md` (ChatGPT Deep Research). **Results:** `ai\sim-results.md`. **Audits:** `ai\chatgpt-audit.md`.

## 0. In one paragraph
Every alien runs the same small brain 5 times a second (Lethal Company's tick): it looks around, decides how brave it
feels (more friends = braver, hunters nearby = scared), scores every enemy it could fight (its prey scores high, its hunter
low, a crowded or dying target lower, the current target a bit higher so it doesn't flip-flop), picks a free spot round that
target, and walks there with crowd avoidance (copied from RVO2) and a pathfinder when a boulder is in the way. Each alien's
style is just data: the Drip mobs big targets until 6+ cling, the Twin peels swarmers off its own big friends, the Titan
turns slowly and only walks roughly where it faces. Before it commits to a fight it gives a short "notice" beat (LC's tell).

## 1. Why the old AI felt iffy (read from our own code)
Kit `EntityAI` (Brainrot Boss Army) + the power-graph sim:
| Problem | Where | What players see |
|---|---|---|
| Wander → Chase flips the instant something is in range (no meter, no tell) | `EntityProfiles.Swarm` | robotic, no build-up |
| Everyone targets the NEAREST enemy and walks a straight line at it | Swarm Chase, `sim.mjs` | conga lines, everyone on one target |
| No spacing between friends: overlaps only fixed by a shove | sim separation; EntityAI has none | units stacked inside each other, jittering |
| Wander picks a uniform random point every 2-5 s | Swarm Wander | twitchy, aimless |
| Same speed, same timing for every unit | both | moves in lockstep |
| Stuck = sidestep, then teleport | `checkStuck` | units popping across the map |
| No idea of counters, prey, predators, facing | both | Brutes walk into Titan wedges, Drips feed Packs |
Measured in the sim (§8): the old AI stacks 5-10x more friends on top of each other and switches targets 2-4x more.

## 2. What we lifted, per alien
| Alien | Taken from | Kept | Changed for our kit |
|---|---|---|---|
| **Drip** | LC **Baboon Hawk** (pack, courage from group size) + **Snare Flea** (cling) + SC2 surround | pack courage, gang up on a big target, fear of its hunter | gang-up target 6 (CLING), cap 10 (BOING BOMBS); spreads out round Packs (SC2 marine split); dodging stays the kit's BOING |
| **Pebble** | LC Baboon Hawk + **Thumper** (straight charges) | same pack logic | +1 courage (stubborn: evades later, for 1.5 s not 3), CURL UP instead of fleeing (kit) |
| **Twin** | LC **Hoarding Bug** (guards its nest, annoyance meter, angry chase) | guard radius, the meter (0.2 a tick, angry at 2.5 for 3.25 s) | the "nest" is its own Brutes/Titans: swarmers on them score x1.8 |
| **Pincer** | LC **Nutcracker** (sentry holding a post) + **Spore Lizard** (warn, then act) | hold a line, warning ladder | holds a post between a big friend and the threat for 2 s; guard radius 14 / x1.5, +1 courage; CLAW BLOCK is the kit's |
| **Brute** | LC **Eyeless Dog** (meter, commit, stop-and-howl tell) + **Kidnapper Fox** (grab a runner) | commitment, the tell, grab targets out of reach | stays within 8 of friends (CHEST THUMP range) when picking a spot |
| **Ram** | LC **Thumper** (speed builds on straights, overshoots) + **Eyeless Dog** lunge + **Baboon Hawk** rush-and-back-off | straight-line commitment | the speed build-up (70 → 100 % after 0.6 s straight, worse turning at full); +1 courage; charge lanes = v2 (§5) |
| **Titan** | LC **Forest Keeper** (slow giant, meters, stop-and-look, 2 s commit) + **Old Bird** (siege) | slow ramp-up, facing, commitment | moves only within 60° of where it faces; 6+ swarmers on it → slides to its own Packs |
| **Colossus** | Forest Keeper + Old Bird | same | +1 courage, accel 14 (heavier) |
ChatGPT Deep Research's picks (Part 5 of `aiesearch-deep.md`) ran with no searches and contradict the kits (Colossus
4,800 HP...), so they were not used; ChatGPT's audit r1 kept these sources ("don't replace them, finish the translation").

## 3. The shared brain (`ai\brain.mjs`; numbers `ai\profiles.mjs` BRAIN)
Decisions 5 times a second, each unit on its own random phase (LC `AIIntervalTime` 0.2 s); movement every tick, every unit
planning from the same snapshot before anyone moves (v2, ChatGPT r1 #3).
| Layer | What it does | Key numbers | From |
|---|---|---|---|
| **1 SENSE** | enemies within 60 (open arena). Roblox: a spatial grid (cells ~16 studs) for every "who's near me" query | sense 60; memory 3 s (Roblox only: the sim sees all) | LC sight 60; Baboon Hawk memory 1 / 3 / 5 s |
| **2 APPRAISE** | fear = Σ over hunters within its evade radius of (3, +1 if it is coming at me) / (gap x 0.2), minus friends within 15 / 4, + 1, minus courage. Fear > 0 AND a friend that hunts my hunter is within 60 → EVADE behind the nearest one (Packs/Brutes only if that friend is within 14, the spot behind it is >= 4 studs safer, and they aren't already hitting their prey unless < 30 % HP). Never more than `holdMax`, and blocked on the way = cornered: fight 3 s (swarm) / 6 s (Packs, Brutes). A unit leaving to evade or guard frees its spot | Squish courage 0, evade 22-25, hold 2.5-3 s · Crunch courage 1, evade 16-18, hold 1.5 s | LC Baboon Hawk fear formula; LC Spore Lizard (cornered fights) |
| **3 CHOOSE TARGET** | score = prey value x distance curve x crowding x facing x guard x commitment; the best wins, but the current target is kept for 1 s and needs to be beaten by 1.5x | prey table §4; distance curve 1/(1+(gap/falloff)²); crowding: swarm FOCUSES a big one (x1 → x1.8 as 0 → 6 friends are on it), x0.4 past 10; others x0.55 if it's already dying (the REAL damage coming at it in the next 1.5 s, multipliers included, > 115 % HP), x0.3 if every spot round it is taken, x0.2 if I couldn't find a way to it lately (3 failed paths, or a blocked event: each blockage counts once) | Dave Mark's Infinite Axis (product of considerations); SC2 focus / spread fire; LC Forest Keeper commitment |
| **4 POSITION** | a free spot on a ring round the target (ring = its radius + mine + half my reach), on one shared 24-sector grid per target (a Drip takes 1 sector of a Titan, a Brute 4 of a Pack); kept until the target changes, I'm blocked, or after 1.5 s a spot >= 2 studs shorter to walk to is free (no orbiting); Brutes/Packs avoid a Titan's 120° front wedge (it costs them), Drips a bit (they BOING out and re-cling on the flank); Brutes prefer spots within 8 of friends (CHEST THUMP); vs Packs the swarm spreads its spots 1.6x apart (a double slap then hits one, not two) | 24 sectors; re-pick >= 1.5 s and >= 2 studs better | SC2 surround + "marine split" |
| **5 STEER** | ORCA crowd avoidance (big units barely give way to small ones), acceleration limits, a Titan only walks within 60° of where it faces (and faces its path until its target is close), grid path round boulders when the straight line is blocked (one attempt a second; repath when the goal moves > 2 studs; paths expire after 2 s; a blocked goal → the free cell nearest it; 3 failures = target unreachable 3 s); exact overlaps split by unit id; BLOCKED (reachable goal, < 25 % of the expected movement AND < 25 % closer to the goal over 1.5 s, not just giving way in a crowd) → sidestep + pick another target | ORCA look-ahead 0.4 s, radius 0.8 r; accel 80 / 60 / 40 / 16 (Colossus 14); brake in the last 1.5 studs | RVO2 (Apache 2.0, ported); LC speed ramps (Forest Keeper x1.3, Thumper) |
| **6 ACT** | the kit's passive / auto / Order code is unchanged (`power\sim.mjs` = `kits.mjs` rules). A unit hits its target when in reach; walking past enemies in reach, it hits the best PREY among them (attack of opportunity) unless it is evading | | SC2 auto-acquire |
| **7 SHOW** | first contact: a 0.15-0.45 s "notice" beat (stop, turn, sound); idle look-arounds; Orders ripple across the units over 0.06-0.3 s instead of firing in sync; voice pitch per unit | `TELLS` in profiles.mjs | LC Eyeless Dog howl, Forest Keeper stop-and-look, Old Bird shot gaps |

**What the AI never does:** steer out of a Titan's slam BECAUSE of its warning (only the swarm's kit BOING / CURL UP react to
it: if every Brute walked out of every 1.6 s wedge, Titans would stop countering Brutes). Ordinary movement carries on (units
are never frozen in the wedge, they just get no extra warning-triggered dodge: ChatGPT r1); hit through its wind-ups (the kit's animation
locks still rule); see through walls in Roblox (sight line checks, like LC).

## 4. The profiles (all data: `ai\profiles.mjs`)
**Prey value** (how much a form wants each enemy form): F1 → Titan 3, Brute 2.4, Swarm 1, Pack 0.35 · F2 → Swarm 3,
Pack 1, Titan 0.6, Brute 0.35 · F3 → Pack 3, Brute 1, Swarm 1, Titan 0.3 · F4 → Brute 3, Titan 1, Pack 1, Swarm 0.6.
| Alien | Style in play | The numbers that make it |
|---|---|---|
| Drip | mobs a Titan or Brute until 6+ cling (GOOED), never more than 10 on one; spreads out round Packs; after a BOING re-clings on the flank; runs to its own Packs when Packs hunt it (3 s max) | gangUp 6 / 10, spreadVs Pack 1.6, wedgeAvoid 0.5, evade 25 / 3 s, courage 0 |
| Pebble | same mob, but stubborn: stays planted in front of a Titan and curls (kit), evades later and shorter | wedgeAvoid 0, evade 18 / 1.5 s, courage 1 |
| Twin | bodyguard: swarmers on its own Brutes/Titans within 18 score x1.8; its annoyance meter fills (0.2 a tick) while they're there, then it's angry 3.25 s (x1.3 more) | guard 18 / x1.8, meter 2.5 → 3.25 s |
| Pincer | line holder (LC Nutcracker sentry): next to a big friend that enemy swarmers are within 12 of, with nothing it wants in reach, it holds a post between the friend and the threat for 2 s; guards a tighter 14 at x1.5; braver | hold 2 s / leash 6, guard 14 / x1.5, courage 1 |
| Brute | bully: Packs score 3; keeps its spot within 8 of friends; stays out of Titan wedges; hands Titans to the swarm | stayNear 8 (weight 0.3), wedgeAvoid 1 |
| Ram | charger (LC Thumper): a straight pursuit starts at 70 % speed and builds to 100 % after 0.6 s, turning 20 % worse at full speed; a 45° turn or a block resets it; Packs score 3, braver | ramp 0.7 → 1 over 0.6 + 1 s, courage 1, wedgeAvoid 1 |
| Titan | slow giant: prefers what's in front (x up to 0.4 less for a target behind it), turns at 60°/s and only walks within 60° of its facing; 6+ swarmers on it → slides towards its own Packs | facing 0.6 / cone 60°, accel 16, swarmed 6 → Packs |
| Colossus | the same, heavier and braver | accel 14, courage 1 |
**Squish vs Crunch:** same numbers except courage (0 / 1), evade (sooner and longer / later and shorter) and the Drip's
flank preference. That is the race rule: same budget, different personality.

## 5. Not built in the sim yet (v2, designed only)
- **Ram charge lanes:** in the last 3 s of RAM CHARGE's cooldown, Rams prefer spots 8-18 from a Pack with a clear line
  (so the Order glows more often). Needs the Order glow to be real first.
- **Pebble rolling waves:** ROLL OUT already ripples via `TELLS.orderWave`; a "wave" formation (rows 4 deep) is v2.
- **Titan stop-and-look between fights** (LC Forest Keeper): presentation, Roblox only.
- **Threat memory, sight lines, the player's rally / lane / target controls**: Roblox only (the sim has no walls or players).

## 6. Order "glow" and the bot opponent
**Glow (player hint):** a form's Order button glows when at least 30 % of ALL that form's living units would do something
useful with it right now (BOING BOMBS = a Titan/Brute within 12; BOING SLAM = 2+ enemies in a 5-stud circle within 14;
RAM CHARGE = a Pack/Brute within 18; Titan Orders = 2+ in the lane or a Brute...): the same rule the sim's "player" fires
them by, so it's balance-tested. ChatGPT r1: PASS, plus: 0.3 s before it lights and 0.4 s before it goes out (no
flicker at range edges); READY (normal button) and GOOD MOMENT (an extra pulse) are different looks, and an unlit button
never means "on cooldown"; a player can always fire a ready Order by hand (the glow is advice, the server checks the
target).
**Bot opponent** (testing + empty lobbies). Sees only what's on the field (no fog: what a player sees), never gets extra
HP, damage or matter. The sim found that for every army there's a mix that beats it ~100 % (`aiot-table.txt`), but
ChatGPT r1 pointed out the bot can't REACH that mix in time (each fuse/split is 0.35-1.4 s + a 5 s lock), so the bot
plans ONE legal action at a time instead of picking a target army:
- Every strategic rethink it lists the legal actions: one fuse or one split (units alive, not transforming, not locked,
  not in melee unless about to die), a rally change, hold. Each scores
  `counter value (from bot-table.json / the power graph) + objective + position - time to transform and reach - risk while
  transforming - giving up a working formation`. It acts only if the best beats "hold" by 15 / 10 / 5 % (Easy / Normal /
  Hard: no thrashing).
- Orders are judged every 0.2 s with the same usefulness test as the glow, then the difficulty's delay + chance.
- Regroup when its army is worth < 60 % of the enemy's AND retreating helps; it sticks to that for 3 s.
| | Easy | Normal | Hard |
|---|---|---|---|
| Strategic rethink every | 20 s | 12 s | 6 s |
| Reaction delay | 3 s | 1.5 s | 0.6 s |
| Army changes | at most 1 a match | random among the best 3 legal actions (50 / 30 / 20 %) | the best legal action |
| Needs to beat "hold" by | 15 % | 10 % | 5 % |
| Fires a useful Order | 50 %, after 0.5-2 s | 80 %, after 0.3-1.2 s | 100 %, after 0.3-0.6 s |
| Regroups when losing | no | yes | yes |
| Extra HP / damage / matter | none | none | none |

## 7. Building it in Roblox (later step; not started; ChatGPT r1 checked it against Roblox's docs)
**Extend or replace the kit's EntityAI?** Keep its ideas, replace its core for this game, but only after the 64-unit phone
test passes (keep EntityAI as the rollback until then). EntityAI is one-NPC-at-a-time (each entity ticks itself, moves by
AlignPosition, no idea of friends): right for BBA's ~30 minions, wrong for 64 units that must avoid each other.
| Layer | Rate | What |
|---|---|---|
| Server THINK | 5 Hz, staggered (~5 per frame for 64 units) | fear, target, slot: the `airain.mjs` logic |
| Server MOVE | 20 Hz | snapshot → ORCA → integrate → resolve (the sim runs 10 Hz: re-check behaviour at 20 Hz before trusting it) |
| Server COMBAT | authoritative | damage, stuns, cooldowns, fuse/split (the kit rules) |
| Network | 10 Hz to start | packed positions + facing of units that moved, over an UnreliableRemoteEvent (docs: may arrive out of order or not at all; payloads over 1,000 bytes are dropped). ~8-10 bytes a unit → 64 units ≈ 640 bytes a packet, ≈ 6.4 KB/s per player. Sequence number + server time + a unit "generation" id so a stale packet never moves a unit that has since fused or died. Spawns, deaths, fusions, HP, Orders, tells go RELIABLY |
| Client | every frame | interpolate 100-150 ms behind (≤ 100 ms extrapolation if a packet is lost), drive the animator from the interpolated velocity, effects made locally. This is how `AlienAnimator` already works (the server sets attributes, the client moves and animates its own copy) |
Port the BEHAVIOUR and the maths of `brain / orca / nav.mjs`, not every line (Roblox terrain and paths differ from the
sim's 2D grid). Paths, in three layers: a shared flow field per army to its rally point **per size class** (a Drip fits
where a Colossus doesn't) for general direction; ORCA every steer; PathfindingService only when no clear local route
exists, through ONE global queue: at most 4 new ComputeAsync calls a second, 2 s apart per unit, blocked Titans first,
cached by destination + size, backing off after a failure (docs: ComputeAsync yields, has a 3,000-stud and a
20,000-node limit, and needs AgentRadius / AgentHeight per size). Start single-threaded; Parallel Luau later if the
profiler says so. If interpolation disappoints, server physics rigs (EntityAI's AlignPosition) are a separately
profiled fallback, not an automatic switch.
**Code contracts for the port (code review r3):** process units in stable id order, interleaving the two teams and
alternating which goes first each tick (team 0 first every tick gave it 54 % of mirror fights); units are numeric ids +
generation counters (never object-keyed maps), disposed on death / fusion / split (free their target sectors, paths,
unreachable marks); attacks scheduled by absolute server time (next-attack-at / impact-at), carrying at most one interval;
sectors 0..23 become 1..24 and grid cells 1-based with bounds asserts; config validated once at start, non-finite
velocities never committed; spatial hash for neighbour queries, top-K instead of full sorts; never depend on pairs() order.
**Acceptance gates (ChatGPT r1, ours, not Roblox's):** AI update < 2 ms at the 95th percentile and < 5 ms at the 99th;
>= 30 fps on a mid-range phone in a 64-unit fight; blocked < 3 % of active movement; zero unrecoverable stalls where a
route exists; no packet over 1,000 bytes; no alien frozen or duplicated after packet loss (Script Profiler +
MicroProfiler incl. its network mode).
**Four visual playtests before anyone calls it done** (a phone camera at normal zoom, not a free Studio camera):
| Scene | Should look like | Fails if |
|---|---|---|
| 16 Drips vs 1 Titan | surround, cling, BOING, re-cling | endless circling, hopping in sync |
| 4 Twins guarding 2 Brutes | go for nearby swarmers, intercept them | ignore their Brutes, or wall them in |
| 4 Rams chasing Packs through boulders | find routes, commit to straight runs | sidestepping forever, charges cancelled |
| 1 Colossus vs 8 Brutes | turns deliberately, walks in, lands GROUND SHATTER | flips between targets, slides backwards |
**On-screen "iffy" risks to design out (ChatGPT r1 §8):** orbiting without attacking (spots are now sticky); movement
that fights the body (keep world movement separate from body facing: Rams turn and commit, Pincers face sideways to
their travel, Brutes lead with their knuckles); the notice beat on every target switch (only when entering combat from
calm; in a fight just a head turn or a sound); polite traffic jams (Squish bodies may squash a little; track real
progress); network smoothing that looks like dithering (smooth small corrections, snap only on teleport / fusion, heavy
turning for big units).
- Map rules found by the sim: boulder-plain gaps >= 14 studs (Titan ~11 wide); `02-MAP.md` gives the crater
  breaches as 12 wide (written before the map was doubled; check the built map): if still ~12 they are **too tight for a
  Titan**: widen to >= 16 or accept that Titans can't enter the crater (James's call).

## 8. Results (full tables: `ai\sim-results.md`)
- **Balance holds with the new AI** (60 fights per step): race mirrors 0.96-1.05, Swarm>Titan 1.94-2.57, Titan>Brute
  2.23-2.46, Brute>Pack 2.11-2.81, Pack>Swarm 2.20, diagonals 0.82-1.19: ALL TARGETS MET in the open; spread and
  narrow lane in range except Titan>Brute 3.06 / Brute>Pack 2.93 at the top (the old AI was over there too) and
  **Pack v Titan 0.67-0.69 (old 0.76-0.77)**: in a 20-stud lane Packs can't get round a Titan's front. Mixed
  armies: best mix 73 % (was 76 %), every mix has a counter, but race parity 53.5 / 46.5 (§9, sim-results §3).
- **Behaviour vs the old AI** (20 fights a scenario, open + boulder plain): friends stacked inside each other 3-10x less,
  target switches 2-4x less (except the four-form mix), time inside a hunter's reach 20-35 % less in mixed armies,
  blocked < 0.5 % with traps <= 3.2 s in 16 of 18 scenarios; time spent hitting 7-12 points lower (positioning +
  crowd-yielding), fights 1-5 s longer.
- **Known residue:** the busiest mixed fight (all four forms each side): hitting 33-35 % (old 52-53 %), blocked
  3.8-4.6 % (target < 3 %), traps up to 4.8 s;
  Squish swarm vs Titans 1.9-2.0 while Crunch 2.6 (accepted provisionally by ChatGPT r1); tick rate moves the kit's
  numbers (10 → 20 Hz) for the old AI too.

## 9. Audit trail + what's open
- Research: Lethal Company's real code (`ai\research-lc-code.md`); ChatGPT Deep Research (0 searches, cross-checked and
  mostly corrected: `ai\research-deep.md`); my web checks (DevForum / Creator Hub).
- **ChatGPT r1 (GO WITH CHANGES):** 8 required changes to the brain (all applied: EVADE bug, shared sticky slots,
  snapshot movement + exact overlaps, pathfinder edge cases, a real stuck measure, Ram + Pincer personalities, real
  overkill damage, re-run) + 8 for the bot / glow / Roblox plan (all written into §6-7). `ai\chatgpt-audit.md`.
- **ChatGPT r2: GO WITH CHANGES** ("James can approve this as the AI's design foundation, but should not treat the current
  simulator as the locked reference implementation"). It ran the sim itself; 6 required changes, all applied (v2.1):
  free spots on evade/guard, selective Pack/Brute evade, one-shot blocked events + route progress, A* goal/expiry
  fixes, Pincer guard needs a real swarm threat, attack timer keeps its remainder (20 Hz is now the standard rate).
  Left open by design: the four-form mix is near but not at its targets (hitting 39 % vs 42, a 4.6 s trap in the
  boulders); race parity and the lane Pack v Titan are balance / map items, not AI fixes.
- **ChatGPT r3 CODE REVIEW: NOT READY → SHIP WITH FIXES → SHIP** ("approved as the JavaScript reference implementation
  for the Luau port"). 22 + 6 + 1 findings, each checked before fixing: 1 rebutted outright (it had compared against an old
  power-graph copy; it withdrew), several partly rebutted (accepted), the rest fixed. It found two real bugs that are also
  in the power-graph sim (`design\power\sim.mjs`): AoE caps sorted by a NaN distance, and the Titan wedge test failing once
  a facing winds past 2π. Regression suite `ai\smoke.mjs` (12 tests, 13 assertions on the angle case). Record:
  `ai\chatgpt-audit.md` Round 3.
- **For James:** (1) the race-parity finding (BOING SLAM / STRETCH GRAB) is a power-graph call; (2) crater breaches vs
  Titan width; (3) written permission from Zeekers, if he has it, belongs with the docs (ChatGPT's licensing note);
  (4) when the Roblox build starts: the §7 gates and the four visual playtests decide "not iffy", not the sim.
