# Alien Fusion: power graph v3 (28 Oct 2026): 3 abilities for each of the 8 aliens

James: "start on the power scaling. Each creature should have three abilities ... audit with ChatGPT ... deep research if
that helps ... It must make sense to that specific alien and alien race; it must be diverse from the other abilities the
creature has; ensure everything scales correctly, cross-checking the whole graph."

**Source of truth:** `design\power\kits.mjs` (every number below comes from it; the battle sim reads it directly).
**Research:** ChatGPT Deep Research, 26 sources: `design\power\deep-research-2026-10-28.md`.
**Audits:** ChatGPT r1 GO WITH CHANGES; r2 GO WITH CHANGES "v3 is nearly ready", all required changes applied; then
GO for Roblox playtesting once the Studio fusion test passes (`designpowerchatgpt-audit-r1.md`, §8).
**Cross-check:** battle simulator `design\power\sim.mjs` + test scripts (§7). Results: `design\power\final-run.txt`.
**Visual:** `design\power\power-graph.html` (built by `build-page.mjs`).

## 1. How each alien's three abilities work (one button per form)
With up to 64 units on a phone, three buttons per alien is too much (research: WC3 autocast, SC2, They Are Billions,
Clash Royale 2026 all moved away from it). So every alien gets:

| Slot | What it is | Button? |
|---|---|---|
| **A: PASSIVE** | How it attacks; makes its counter job obvious | no |
| **B: AUTO** | A situational skill it uses by itself on a cooldown (8-12 s) | no |
| **C: ORDER** | The big moment. ONE button per form: every unit of that form does it together (22-28 s) | yes, 1 per form |

On screen: pick a form, one big ORDER button (radial cooldown + sound). At most 4 Order buttons ever.

**Fusion / split can't reset or duplicate anything** (engine rules, audit r1 #5):
- Order cooldown belongs to player + form (shared, survives the form disappearing and coming back).
- A fused unit takes the LATEST auto cooldown of its parts; splitting copies the remaining cooldown to every child.
- Stun, stun-immunity and every status keep their expiry times (no restart, no cleanse).
- Shields: split = divided by matter; fuse = summed, capped at 20 % of the new form's HP.

## 2. Race feel (same budget, different verbs)
| | SQUISH (goo) | CRUNCH (rock) |
|---|---|---|
| Verbs | stick, slow, bounce, stretch, absorb | brace, stun, smash, charge, burn |
| Danger shapes | circles, ripples, puddles | wedges, cracks, straight lines |
| Control style | slows (also slow attacks), pulls | short stuns, knock-aside |
| Defence style | shields, jump out of danger | harden (curl, claws, rolling) |

## 3. The 24 abilities
Damage in HP, times in s, distances in studs. "warn" = the danger shape shows this long before it lands.

### SWARM (F1, 1 matter, 100 HP): job = kill Titans
| | DRIP (Squish) | PEBBLE (Crunch) |
|---|---|---|
| A passive | **CLING**: hops on and sticks. 6+ Drips on a big one = GOOED: x1.75 on a Titan, x2 on a Brute | **CHIP**: chips cracks in rock, bites chunks out of goo. 6+ on a big one = CRACKED: x1.75 Titan, x2 Brute |
| B auto | **BOING** (10 s): a Titan's hit is coming? Springs to the nearest edge of the danger shape (up to 10 studs); if it can't get clear it squashes flat and takes half. Titans only | **CURL UP** (12 s): a Titan's hit is coming? Curls into a stone ball and stays put: 70 % of that hit bounces off. Titans only |
| C ORDER | **BOING BOMBS** (24 s, warn 0.55): every Drip within 12 springs ONTO the nearest Titan/Brute (max 10 per target), first bite +15 (lost if that target dies first) | **ROLL OUT** (24 s, warn 0.55): every Pebble rolls at the nearest Titan/Brute: +60 % speed, 30 % damage cut for 2.5 s, first jab on a big one +20 |
Why it fits: the Drip is a hopping droplet with a curled hook (sticks, springs away); the Pebble is a beetle with mandibles
and a horn (chips, curls into its shell, horn jab). Diverse: damage multiplier / survive a Titan hit / gap-closer.

### PACK (F2, 2 matter, 235 HP): job = clean up swarms
| | TWIN (Squish) | PINCER (Crunch) |
|---|---|---|
| A passive | **DOUBLE SLAP**: two tendrils, 20 dmg to two little ones at once (1 s) | **SCISSOR SNAP**: each claw snaps a different little one, 20 dmg (1 s) |
| B auto | **STICKY FLOOR** (9 s, warn 0.5): its puddle spreads 5 studs: enemies 25 % slower (moving AND attacking) for 2.5 s, when 3+ are close | **CLAW BLOCK** (10 s): swarmed by 2+ little ones or Packs? Claws up like a shield: 30 % less damage for 3 s |
| C ORDER | **BOING SLAM** (22 s, warn 0.8): bounces up to 14 studs into a crowd and belly-flops: 20 dmg to 3, tosses little ones up (0.4 s) | **SIDE SWEEP** (22 s, warn 0.7): plants its legs and swings both claws sideways: 20 dmg to the 3 nearest swarmers/Packs, bats them 2 studs aside (never hits a Brute) |
Why it fits: the Twin stands on a puddle with tendril arms and bounce-slides; the Pincer is a sideways crab with two
C-claws. Diverse: multi-hit / zone or defence / burst Order.

### BRUTE (F3, 4 matter, 560 HP): job = smash Packs
| | BRUTE (Squish goo gorilla) | RAM (Crunch horned bull) |
|---|---|---|
| A passive | **KNUCKLE POUND**: 55 dmg every 1.25 s, x1.5 vs Packs | **HORN GORE**: 55 dmg every 1.25 s, x1.5 vs Packs |
| B auto | **STRETCH GRAB** (8 s, warn 0.5): a stretchy arm grabs a unit up to 14 away (Packs first), yanks it in, slams it: 30 dmg + held 0.5 s | **HOOF STAMP** (9 s, warn 0.5): a Pack or Brute within 5? Rears and stamps: 30 dmg + 0.5 s stun to 2 Packs/Brutes (Packs first); little ones only get dusted (no damage) |
| C ORDER | **CHEST THUMP** (26 s, warn 0.8): every Brute beats its chest: goo shield 70 (13 % HP) for itself, 30 for friends within 8 (max 20 % of their HP), 6 s; punches 20 % faster for 4 s | **RAM CHARGE** (24 s, warn 0.85): every Ram charges up to 18 studs at a Pack (or a Brute, never a Titan): 90 to it (135 vs a Pack), 20 to up to 2 more, knocked aside |
Why it fits: gorilla = chest beat + long goo arms; bull = rear-and-stamp + charge. Diverse: hit / pull or stun / team
shield or line charge.

### TITAN (F4, 16 matter, 2,400 HP, max 2): job = crush Brutes (and bases)
| | TITAN (Squish kaiju) | COLOSSUS (Crunch rock giant) |
|---|---|---|
| A passive | **TENTACLE SLAM**: its attack, every 4 s: 400 dmg in front (x2.5 = 1,000 on a Brute), one more target at 25 %. Huge on a Brute, mostly wasted on a 100-HP Drip | **GROUND SHATTER** (James's design): every 4 s: 400 in front (1,000 on a Brute), one more at 25 %, crystals jolt them (0.3 s stun, not swarms) |
| B auto | **GOO BOMB** (12 s): nothing in reach? Spits a goo ball up to 30 away (Brutes first): 160 dmg to 3 + sticky puddle (25 % slow, 2.5 s); x2.5 vs bases | **BOULDER HURL** (12 s): nothing in reach? Rips up a boulder and throws it up to 30 (Brutes first): 160 dmg to 3; x2.5 vs bases |
| C ORDER | **GOO TSUNAMI** (28 s): rears up and crashes forward: a 24 x 12 goo wave: the first big enemy takes 300 (750 if a Brute), 60 to 3 more, all slowed 25 % for 2 s; x2.5 vs bases | **SOLAR STRIKE** (James's design) (28 s): mini sun, then a beam on the first big enemy up to 30 away: 300 (750 if a Brute), 50 to 3 more, ground burns 8/s (max 4) for 2 s; x2.5 vs bases |
Why it fits: James's two Colossus attacks stay (smash = its attack, sun = its Order) and Boulder Hurl is its siege auto;
the Titan mirrors them in goo (tentacles crush, a spat goo ball, a goo wave): crush / trap / overwhelm. The anti-Brute
bonus applies to the PRIMARY hit only. A thrown boulder / goo ball / sun beam lands on the spot even if its target
dies first. The player can fire an Order at any single enemy or a base (the sim's AI waits for 2+ targets or a Brute).

**Timings = the animations** (audit r1 #7; from `07-COLOSSUS-V4-ATTACKS-SPEC.md`; the Titan's Phase 2 animations must
hit the same marks):
| | Danger shape shows | Hit lands | Busy until | Spec |
|---|---|---|---|---|
| SHATTER / TENTACLE SLAM | 0.64 s (Titan 0.74) | 1.64 s | 3.4 s (back to neutral) | impact 1.64, neutral 3.40 |
| BOULDER HURL / GOO BOMB | 2.40 s | 3.40 s | 2.6 s (after release) | release 2.55, impact 3.40 |
| SOLAR STRIKE / TSUNAMI | 2.0 s (2.1) | 3.2 s | 3.2 s | BOOF 3.20 |
While a Titan throws or does its Order, its slam timer keeps counting (it swings again as soon as it recovers).
The crystal ring, crater and shockwave can stay as big as they look now: effects can be bigger than the damage shape
(wedge 10 studs, beam circle 8).

## 4. Base stats (one change proposed, audit r1 approved it)
| Form | HP | DPS | Speed | Note |
|---|---|---|---|---|
| F1 | 100 | 12 | 22 | |
| F2 | 235 | 20 | 19 | |
| F3 | **560** (was 650) | **44** (was 48) | 16 | **PROPOSED, needs James.** At 650/48 a full Brute army has 5,200 HP and the same total damage as 32 swarmers with 3,200 HP: about 1.6x anyone else's raw power. Deep research found the same independently. All-Brute armies won 91 % of mixed fights before the change |
| F4 | 2,400 | 100 | 8 | |
Rules lock §3's flat multipliers are now these passives: F4 vs F3 x2.5 on the slam (was 1.8); swarm bonus x1.75 on Titans
(was x2) and x2 on Brutes (new); F2 cleave and F3 x1.5 vs F2 unchanged.

## 5. Guard rails (`guard.mjs` checks them)
- Warnings: autos >= 0.5 s, Orders >= 0.55 s, anything a Titan does >= 0.9 s. Danger shape first, spectacle after.
- Stuns <= 0.6 s, then 3 s immune (no stun-lock). Titans can't be stunned, grabbed or pushed; slows work half on them.
- Pushes (grab, knock, toss) share one budget: max 8 studs per victim per 3 s.
- Slows <= 30 % and <= 2.5 s (they slow attacks too). Shields <= 20 % of the receiver's HP, never stack (they replace).
- Short damage cuts only (<= 3 s); the swarm's one-hit dodges are allowed up to 85 % because they only answer a Titan hit.
- No heal-on-kill anywhere. Every area hit has a cap (2-4 targets).
- Order budget: about 20-30 bonus damage per matter per cast (Titan Orders count the slam they replace: see §8).
- Each auto helps against its prey or its own tier, never against its predator.

## 6. Cross-check results
**28 Oct ~8:30 PM: two sim bugs fixed and everything re-run** (found by the AI session's ChatGPT code review,
`11-ALIEN-AI.md` §9): (1) capped area hits (GOO BOMB / BOULDER HURL, BOING SLAM, SOLAR STRIKE) sorted their targets by a
distance that was always NaN, so they took enemies in list order instead of the nearest to the centre; (2) the Titan /
Colossus wedge test went wrong once a facing had turned past 2π. Also: `mixed.mjs` put SQUISH on team 0 in every
cross-race fight (now alternates), and `sim.mjs` crashed when imported without a script path. Effect: small. All targets
still met; Swarm>Titan +0.06 on two pairings, mixed race split 51.9 → 51.6 % Squish, Twin's DOUBLE SLAP weighs less
(21 → 14 %) because BOING SLAM now lands on the nearest 3. The old sim is kept as `powersim-v3-before-fix.mjs` (+ old
results `final-run-v3-before-fix.txt`); `designailegacy-parity.mjs` proves both versions fight by fight.
Final run 28 Oct, re-run ~8:30 PM after two sim bugs were fixed (`powerinal-run.txt`, 200 fights per search step, every random number seeded).
EDGE = how much extra HP the other side needs to tie (2.00 = twice as strong; 1.00 = even).
Race pairings in order S v C · C v S · S v S · C v C.

| Check | Target | Open field | Spread out | Narrow lane |
|---|---|---|---|---|
| Same form, Squish vs Crunch | 0.90-1.10 | 0.96 · 0.98 · 1.05 · 1.01 (F1-F4) | 0.96 · 0.97 · 1.05 · 1.04 | 1.02 · 0.96 · 1.05 · 1.01 |
| Swarm beats Titan | 1.4-3.0 | 2.41 · 2.52 · 2.40 · 2.56 | 2.45-2.60 | 2.27-2.42 |
| Titan beats Brute | 1.4-3.0 | 2.33 · 2.23 · 2.23 · 2.35 | 2.22-2.23 | **2.91-3.16** |
| Brute beats Pack | 1.4-3.0 | 2.59 · 2.09 · 2.11 · 2.59 | 2.14-2.59 | 1.98-2.59 |
| Pack beats Swarm | 1.4-3.0 | 2.20 (all four) | 2.01-2.20 | 2.20 |
| Swarm vs Brute (close) | 0.77-1.30 | 1.14 · 1.24 · 1.12 · 1.27 | 1.04-1.21 | **1.24-1.43** |
| Pack vs Titan (close) | 0.77-1.30 | 0.83 (all four) | 0.85-0.87 | 0.77 |
| Mixed armies: Squish / Crunch | 49-51 % | **51.6 % / 48.4 %** (22 mixes per race, 12 fights per pair, sides alternated) | | |
| Every army mix has a counter | >= 65 % | yes, all 44 (best mix 77 %, its counter wins 100 %) | | |
| Guard rails | all | all met | | |
In a narrow lane nobody can flank, so a Titan's front slam finds Brutes easily and swarms surround less: that's terrain
doing its job, and maps should mix open ground and lanes.

**Each ability's weight** (army strength with it vs without it; average over the 4 enemy forms / its best matchup):
| | A passive | B auto | C ORDER |
|---|---|---|---|
| Drip | CLING 50 % / 87 % vs Brute | BOING 2 % / 8 % vs Titan | BOING BOMBS 3 % / 8 % vs Titan |
| Pebble | CHIP 44 % / 82 % vs Brute | CURL UP 4 % / 15 % vs Titan | ROLL OUT 5 % / 16 % vs Brute |
| Twin | DOUBLE SLAP 14 % / 57 % vs Swarm | STICKY FLOOR 6 % / 10 % vs Swarm | BOING SLAM 12 % / 20 % vs Pack |
| Pincer | SCISSOR SNAP 21 % / 83 % vs Swarm | CLAW BLOCK 8 % / 22 % vs Swarm | SIDE SWEEP 0 % / 10 % vs Swarm |
| Brute | KNUCKLE POUND 19 % / 56 % vs Pack | STRETCH GRAB 13 % / 40 % vs Swarm | CHEST THUMP 11 % / 28 % vs Swarm |
| Ram | HORN GORE 1 % / 38 % vs Pack | HOOF STAMP 5 % / 13 % vs Pack | RAM CHARGE 4 % / 10 % vs Pack |
| Titan | TENTACLE SLAM 42 % / 118 % vs Brute | GOO BOMB 1 % / 5 % | GOO TSUNAMI 1 % / 4 % |
| Colossus | GROUND SHATTER 39 % / 112 % vs Brute | BOULDER HURL 0 % / 0 % | SOLAR STRIKE 1 % / 6 % |
Reading it: every passive is strongest exactly against its prey. Autos and Orders add 2-40 % in their best matchup and
never help against their predator. The swarm's Boing/Curl only matter when a Titan swings at them, and the swarm
already wins that fight 2.3-2.6x, so their numbers are small by design. **The Titans' throw and Order add almost nothing in a pure brawl**: their slam already
does 1,000 to a Brute, so anything else is a swap of time. Their real jobs are ones the sim can't see yet (hitting things
out of reach, sieging bases at x2.5, the big moment). If play tests show players ignoring them, they get a buff there.

**What changed on the way** (each found by the sim or the audit, not guessed):
- all-Brute armies won 91 % → F3 stats trimmed (best mix now 76 %);
- a hidden "Titans do half to swarms" rule → overkill + 2-target caps;
- the swarm's dodges also blocked the Packs' Orders → they only react to Titans;
- Side Sweep's dash carried the Pincer out of the fight → an in-place swipe;
- both players' first Orders on the same tick → players tap at different moments;
- audit r1: Boing/Curl didn't save a swarmer, Chest Thump over-shielded Drips, Titan Orders doubled their Brute bonus,
  Colossus hits landed before its animation, unseeded randomness, prey-only triggers, a push budget;
- after r1, the animation locks made Titan throws and Orders cost more than they gave → throws only at targets out of
  reach, Orders only on 2+ targets or a Brute, the slam timer keeps counting during them, Orders hit like a bigger slam.

**Not trusted yet** (audit r1 agrees): no terrain, bases or real fusion/split decisions in the sim; mixed-army ranking
depends on the pool of mixes; snowball after losing a Titan is untested. Real tuning happens in play tests.

## 7. How to re-run (from `design\power\`)
- `node guard.mjs`: the rules above (no fights).
- `node check.mjs 200`: equal-matter fights, all 4 race pairings; prints EDGE = how much extra HP the other side needs to tie.
- `node formations.mjs 40`: the same in a spread-out formation and a narrow 20-stud lane.
- `node mixed.mjs 12`: 22 army mixes x 2 races, round robin; best mixes and their counters.
- `node ablate.mjs 40`: each ability switched off in turn = how much it adds.
- `node uplift.mjs 30`: how much B + C add to each form.
- `node build-page.mjs`: rebuilds `power-graph.html` from the latest results.
Sim limits: no terrain, bases or real fusion/split decisions; units fight the nearest enemy; Orders fire when 30 % of
that form can use them. It's a balance check, not the game; real numbers get tuned again in play tests.

## 8. Audit trail + what's left
- **ChatGPT r1** (strict, read the sim code): GO WITH CHANGES; 9 required changes, all applied (Boing/Curl actually save a
  swarmer, shield cap, Brute bonus on the primary only, prey triggers, push budget, animation timings, seeded sim...).
- **ChatGPT r2**: GO WITH CHANGES, "v3 is nearly ready"; accepted all 5 of my deviations from its r1 numbers; 4 small
  mechanic fixes, all applied. Fit scores: 20 abilities at 9-10, CURL UP 8 (avg 9.5 / 10). "Freeze F3 at 560/44."
- **Left before the final lock (Phase 2, in Studio):** fusion/split test of the invariants in §1 (repeat fuse/split
  cycles), bases + siege values, a real match with players choosing Orders. Then GO for playtesting at these numbers.
- **Needs James:** (1) OK the F3 change 650/48 -> 560/44 (rules lock §3); (2) the one-button-per-form control scheme;
  (3) any ability he wants swapped for one of his own ideas (he designed SHATTER + SOLAR STRIKE).
