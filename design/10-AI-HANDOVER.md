# Alien Fusion: handover for the AI session (28 Oct 2026, from the power-graph session)

You are picking up ONE job: **design the alien AI** (how every unit thinks, moves, picks targets and uses its abilities),
researched from other games, audited by ChatGPT. Research + design + a simulator prototype. **No Studio, no models, no
animations**: another session is animating the aliens in batches at the same time (see §7 for which files are theirs).

James (the owner) said: draw from games like **Lethal Company**, because the AI I built before "was a bit iffy". He doesn't
want copyright lectures: we copy mechanics and ideas (not code or assets), like every game does.

## 0. File map: read these to get the full picture (absolute paths)
Venture (all Roblox games): `D:\Roblox Game Venture\`
| What | Path |
|---|---|
| Venture entry + rules for every session | `D:\Roblox Game Venture\00-START-HERE.md`, `D:\Roblox Game Venture\00-GLOSSARY.md` |
| **Our existing NPC AI engine (kit 1.4, from Brainrot Boss Army): HFSM, scheduler, mover, leash, profiles** | card `D:\Roblox Game Venture\Flagship\Kit\cards\entityai.md`; code `D:\Roblox Game Venture\Flagship\Kit\src\ServerScriptService.Server.Kit.EntityAI.lua` + `...Server.Kit.EntityProfiles.lua` + debug overlay `D:\Roblox Game Venture\Flagship\Kit\src\StarterPlayer.StarterPlayerScripts.Client.Kit.EntityAIDebug.lua`. Find out why it reads "iffy" and whether to extend it or replace it |
| Kit lessons (mistakes not to repeat) | `D:\Roblox Game Venture\Flagship\Kit\LESSONS.md`, `D:\Roblox Game Venture\Flagship\Kit\API.md` |
| Studio tooling + testing (for later, when it goes in game) | `D:\Roblox Game Venture\Flagship\Kit\cards\studio-mcp.md`, `...\cards\testing.md`, `...\cards\validation.md`, `D:\Roblox Game Venture\Flagship\Playtest Kit\` |
| Kid-safety rules | `D:\Roblox Game Venture\Flagship\Kit\cards\policy-kids.md` |
| Creature method (how the aliens were built and animated) | `D:\Roblox Game Venture\Flagship\Polish Kit\cards\creature-from-reference.md` |
| Game idea research (why this game) | `D:\Roblox Game Venture\Research\alien-army-tycoon-2026-10-27.md` |

This game: `D:\Roblox Game Venture\Games\Alien Fusion\`
| What | Path |
|---|---|
| Resume snapshot, decisions, history, lessons | `...\Alien Fusion\00-CHECKPOINT.md`, `DECISIONS.md`, `BUILD-LOG.md`, `LESSONS.md` |
| **The 24 abilities + results** | `...\Alien Fusion\design\09-POWER-GRAPH.md` |
| Ability numbers (source of truth) | `...\Alien Fusion\design\power\kits.mjs` |
| Battle sim + its test scripts | `...\Alien Fusion\design\power\sim.mjs`, `check.mjs`, `formations.mjs`, `mixed.mjs`, `ablate.mjs`, `guard.mjs` |
| Visual power graph | `...\Alien Fusion\design\power\power-graph.html` |
| Ability deep research + both ChatGPT audits | `...\Alien Fusion\design\power\deep-research-2026-10-28.md`, `...\design\power\chatgpt-audit-r1.md` |
| Locked rules, races, map | `...\Alien Fusion\design\03-FORMS-AND-RULES.md`, `01-ALIENS.md`, `02-MAP.md` |
| Each alien's look + pose sheets (how it moves) | `...\Alien Fusion\design\concepts\<drip, pebble, twin, pincer, brute, ram, titan>\`, Colossus `design\concepts\colossus-v4-model-sheet-chatgpt.png` |
| How they move now (gaits) + the animator (read only) | `...\Alien Fusion\src\ReplicatedStorage.AlienFusion.Gaits.module.luau`, `src\StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau` |
| Colossus attack timings (the AI must respect wind-ups) | `...\Alien Fusion\design\07-COLOSSUS-V4-ATTACKS-SPEC.md`, `src\ReplicatedStorage.AlienFusion.Attacks.module.luau` (read only) |
| Current test spawner (no AI yet) | `...\Alien Fusion\src\ServerScriptService.WalkTest.server.luau` |
| James's preferences + how to drive ChatGPT in Chrome | memory: `C:\Users\AFish\.claude\projects\C--\memory\MEMORY.md` (auto-loaded), esp. `chatgpt-as-auditor.md`, `alien-fusion-game.md`, `realistic-time-estimates.md`, `build-what-was-asked.md` |
Use these to get the context before researching. Anything said below is backed by one of them.

## 1. The game in one paragraph
Roblox, 1v1 PvP, kids on phones. Each player has an army of **32 "matter"** that fuses and splits freely: F1 Swarm (1 matter,
up to 32 units), F2 Pack (2), F3 Brute (4), F4 Titan (16, max 2). Two races with the same numbers and different feel:
**SQUISH** (cyan goo: stick, slow, bounce, stretch) and **CRUNCH** (amber crystal rock: brace, stun, smash, burn).
Counter loop: **Swarm beats Titan → Titan beats Brute → Brute beats Pack → Pack beats Swarm.** Matches ~210 s. Up to 64
units on screen. Server-authoritative. Map: doubled moon arena 1,008 x 672 studs, bases at x = ±395, centre crater,
narrow canyon north, open boulder plain south (`design\02-MAP.md` + rules §4).

## 2. Read these first (in this order)
1. `design\09-POWER-GRAPH.md`: **the 24 abilities**, final numbers, guard rails, results, audit trail. THE key input.
2. `design\power\kits.mjs`: every ability number (the source of truth; the sim reads it).
3. `design\03-FORMS-AND-RULES.md`: locked rules (matter, merge/split timings, counters, map).
4. `design\power\sim.mjs`: the battle sim. Its current "AI" is deliberately dumb (see §5): your work replaces it.
5. `design\power\deep-research-2026-10-28.md`: ability research (autocast vs player buttons, readability for kids).
6. `design\power\chatgpt-audit-r1.md`: both ChatGPT audits of the power graph (what it trusts, what it doesn't).
7. `00-CHECKPOINT.md`, `DECISIONS.md`, `LESSONS.md` (game root).

## 3. Who controls what (decided in the power graph; James still has to OK the Order button)
| Layer | Who | What |
|---|---|---|
| Fuse / split | **player** (button; auto-picks the nearest eligible group) | 0.35-1.4 s transforms, 5 s lock |
| ORDER (slot C) | **player**: ONE button per form, every unit of that form does it | 22-28 s shared cooldown |
| Where the army goes | **player** (rally / lane / target; exact controls not designed yet) | |
| Everything else | **AI (your job)** | movement, spacing, target choice, facing, dodging, autos (slot B), retreat, surround |
The AI must also suggest WHEN an Order is good (button glows) and, for a bot opponent, fire it itself.

## 4. Each alien's fighting style = what its AI profile must express
Bodies come from the v5 models (`design\concepts\<form>\`); gaits from `src\ReplicatedStorage.AlienFusion.Gaits`.
| Alien | Body / gait | Job (prey) / avoid (predator) | Kit (passive / auto / ORDER) | AI style to design |
|---|---|---|---|---|
| **Drip** (Squish F1) | hopping goo droplet, one eye, curled hook tail; hops | kills Titans (x1.75) + Brutes (x2) when 6+ cling / avoid Packs | CLING / BOING (springs out of a Titan's danger shape) / BOING BOMBS (all leap onto big enemies, max 10 per target) | Swarm pack-hunter: flock, flow around Packs, encircle big targets to get 6+ on, scatter out of Titan warnings, re-cling |
| **Pebble** (Crunch F1) | rock beetle, horn, mandibles, 6 legs; tripod scuttle | same | CHIP / CURL UP (hardens in place vs a Titan hit) / ROLL OUT (roll in fast, horn jab) | Swarm like Drip but STUBBORN: stays planted and curls instead of fleeing; charges in rolling waves |
| **Twin** (Squish F2) | goo peanut on a puddle, tendril arms; bounce-slide | cleans swarms (hits 2 at once) / avoid Brutes | DOUBLE SLAP / STICKY FLOOR (5-stud puddle when 3+ close) / BOING SLAM (belly-flop into a crowd) | Bodyguard: hangs near its own big units, peels swarmers off them, drops puddles at chokepoints |
| **Pincer** (Crunch F2) | rock crab, two C-claws, walks SIDEWAYS | same | SCISSOR SNAP / CLAW BLOCK (claws up when swarmed) / SIDE SWEEP (planted sideways swipe) | Line-holder: strafes sideways, braces when swarmed, holds a front; facing matters (sideways crab) |
| **Brute** (Squish F3) | goo gorilla, huge fists; knuckle-walk / charge | smashes Packs (x1.5) / avoid Titans | KNUCKLE POUND / STRETCH GRAB (yanks a runner in from 14) / CHEST THUMP (shields itself + friends) | Bully: hunts Packs, grabs anything kiting it, stays close to friends so the thump covers them, keeps out of Titan slam wedges |
| **Ram** (Crunch F3) | rock bull, crystal horns; trot / gallop | same | HORN GORE / HOOF STAMP (stuns a Pack/Brute within 5) / RAM CHARGE (line charge at a Pack, never a Titan) | Charger: lines up charge lanes, backs off to re-charge, stamps when a Pack gets close |
| **Titan** (Squish F4) | goo kaiju dome on a skirt, 4 tentacles; slow slide, 8 studs/s, turns 60°/s | crushes Brutes (slam 1,000) + bases / avoid swarms | TENTACLE SLAM (forward wedge every 4 s) / GOO BOMB (throws at targets out of reach) / GOO TSUNAMI (forward lane wave) | Siege beast: slow, FACING is everything (forward-only slam), turns to Brutes, throws at what it can't reach, must not get swarmed (retreat to its Packs?) |
| **Colossus** (Crunch F4) | rock giant, crystal gauntlets; heavy IK walk | same | GROUND SHATTER / BOULDER HURL / SOLAR STRIKE (James designed Shatter + Sun) | Same as the Titan, heavier: plants and smashes; the sun is its "boss moment" |
Squish AI should FEEL bouncy and reactive (springs away, flows); Crunch AI stubborn and direct (braces, charges straight).
Same budget, different personality: that's the faction rule from the power graph.

## 5. What exists today (and why it's "iffy")
- `sim.mjs` AI: every unit walks at the nearest enemy and hits it; autos fire on simple triggers; Orders fire when 30 %
  of a form can use them. No flocking, no formation, no retreat, no kiting, no threat memory, no terrain, no bases.
  It was built to measure balance, not to look alive. Keep it working: the balance numbers depend on it.
- In Roblox there is NO combat AI yet. Units only walk test loops (`ServerScriptService.WalkTest`) with the animator.
- Earlier AI work in other games read as "iffy" to James (robotic, predictable, stuck). Find out why that happens
  and how Lethal Company-style AI avoids it (states, senses, personality, surprise, readable tells).

## 5b. James's approach: TAKE proven AI from other games, don't invent it
James (with ChatGPT) wants real, proven creature AI lifted from games that do it well, not just "inspired by" research.
The practical way to do that:
- **Lethal Company profiles → our aliens.** LC is not open source, but its creature AI is thoroughly documented by its
  modding community (the wiki and mod docs list each creature's states, detection ranges, speeds, timers and
  aggro rules, read from the game). Take those behaviour profiles (the state machine, the numbers, the tells) and map
  each one onto an alien whose job fits: e.g. a pack-hunting LC creature → the Drip/Pebble swarm. Write the code fresh in
  Luau: the behaviour and numbers come over, their C# and assets don't (that keeps James's Roblox account safe).
- **Actual code: copy freely from open-licensed projects** (MIT / Apache / CC0 / Roblox open-source modules): behaviour
  trees, state machines, boids/flocking, steering, pathfinding wrappers (e.g. SimplePath), utility-AI scorers. Note the
  licence + source next to anything copied (`design\ai\SOURCES.md`).
- Other games worth lifting profiles from the same way (behaviour + numbers, rebuilt in our code): army/RTS unit AI
  (StarCraft 2 micro, Mechabellum, TABS), horde AI (They Are Billions), and Roblox games whose NPCs feel alive.
- Deliverable for this part: a table per alien: "taken from <game / creature / open project>, what we kept, what we
  changed to fit its kit". ChatGPT audits the fit.

## 6. Your job (suggested order)
1. **Research** (ChatGPT Deep Research is allowed and worked well here): Lethal Company's creature AI (state machines,
   senses / aggro, distinct personalities per creature, tells before attacks, randomness that stays readable); RTS/army
   unit AI (target priority, focus fire vs overkill, flocking/boids, formation, kiting, retreat thresholds, threat maps);
   Roblox performance for 64 units on phones (server tick budget, PathfindingService cost, spatial hashing, LOD for AI,
   network ownership); a bot opponent (when to fuse/split, when to fire Orders) for testing and empty lobbies.
   Then the **lifting pass** (§5b): pick a source profile per alien, pull its states/numbers, find open-licensed code.
2. **Design** `design\11-ALIEN-AI.md`: one shared brain (states, senses, target scoring, movement layers) + one profile
   per alien (§4) as data (weights, ranges, thresholds) so it's tunable like `kits.mjs`. Include the Order "glow" hint
   and the bot opponent.
3. **Prototype in the sim:** copy `design\power\sim.mjs` to `design\ai\` and work there (don't edit `design\power\`).
   Show the new AI keeps the balance (re-run the same checks) and fixes the dumb behaviours (measure: units stuck,
   idle time, overkill, units wasted in predator fights).
4. **ChatGPT audit** each stage (Thinking, high effort; strict; send it files + results). Fix, re-audit, until GO.
5. Hand back: the design doc, the profiles, the sim results, the audit verdicts. Building it into Roblox is a later step.

## 7. Rules for this session
- **Don't touch:** Studio / the place `AlienFusion-map.rbxl`, `src\*` (the animation session is editing `Gaits`,
  `AlienAnimator`, `Attacks`), `assets\`, `design\power\` (read only). Your files: `design\10-*`, `design\11-*`, `design\ai\`.
- ChatGPT = James's ChatGPT in Chrome (Thinking model, high effort), used heavily as the auditor instead of subagents.
  No agent fan-out (James dislikes fleets of agents).
- Plain words in anything players see. Stop any local server right after use. No uploads, purchases or publishing.
- Time estimates: from real past jobs, not guesses (the power graph took one afternoon: research, sim, 2 audit rounds).
- Log in `BUILD-LOG.md` (one row) and `DECISIONS.md` (only James's decisions) when done.

## 8. What the other session is doing at the same time
Animating the aliens **one at a time** (Colossus first, then Titan, then down the tiers): every ability's animation,
effects and sounds, timed to the marks in `09-POWER-GRAPH.md` §3. James ticks each alien off before the next. Combat code
(damage in Roblox) comes after the animations and after your AI design, so your profiles will feed straight into it.
