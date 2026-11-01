# Alien Fusion: the game mechanics, v4.2 (30 Oct 2026, Claude; ChatGPT r5 GO, F1-F3 applied: ready to build the slice)

James (30 Oct, after v3.1): "The main mechanics that seem good to me is ... being able to merge, mining for stuff, and
then maybe you can use that matter to build an egg or a machine ... like a tycoon ... two materials, one that you mine
to build up your tycoon itself, and then the one that gets you aliens ... walk into the square and it buys it ... an
incubator ... Should we gate the abilities behind levels so they only have one ability at first?" Also: "maybe not the
UFO beam"; "should it be multiple maps? Should it be multiple players on a map?"
History: v2 / v3 / v3.1 + ChatGPT r1-r3 in `mechanics-audit\` (r3: GO for the one-place bot slice; combat, controls,
Roblox networking parts carry over). Builds on the locked docs, never against them: rules lock `03-FORMS-AND-RULES.md`,
power graph `09-POWER-GRAPH.md`, AI `11-ALIEN-AI.md`. **[JAMES]** = his decision. **[TEST]** = a sim / play test decides.

## 0. The game in one paragraph
You crash-land on a moon and claim a base plot next to other players. You mine MOON ROCK to build your base (walk onto a
pad, it buys the next machine: classic tycoon) and ALIEN DNA to hatch aliens in your incubator. Every hatch adds one
alien to your army and rolls a rare look. Your army grows from 8 to 32, and a bigger army unlocks bigger fusions (16 of
one species = your first Titan). Then you battle alien nests and other players, where you never pick attacks: you
decide where your army goes, when it MERGES into bigger forms or SPLITS back into swarms, and when the big Orders fire.

## 1. The loop
```
 MINE rock + DNA ──> BUILD the base (pads) ──> HATCH aliens (incubator + DNA) ──> BATTLE (merge / split) ──┐
       ^                                                                                                   │
       └──────────── rewards: rock, DNA, keys; drills keep mining while you're away ───────────────────────┘
```
First-session targets (measured in the slice):
| By | The player has |
|---|---|
| 30 s | claimed a plot, mined a rock, bought the first pad (a drill) |
| 60 s | started the first battle: the 8 starter Drips vs a tiny nest beside the plot (MOVE, MERGE, SPLIT) |
| 3 min | bought the INCUBATOR and hatched a first alien (guaranteed Glowing look) |
| 5-8 min | owns 16 Drips: merged a first TITAN; species level 3: first ORDER |
| 10 min | done one full mine -> build -> hatch -> battle cycle with all 3 abilities; player battles open; ONE next goal shown |
After every reward the screen shows ONE next goal ("Incubator 2: 40 more rock"), never a list.

## 2. Servers + maps **[JAMES]**
- **Multiple players per map: yes.** A hub server = one moon with **8 base plots** in a ring around a shared crater
  (the standard Roblox tycoon layout: you see everyone's base grow, meteorites fall in the middle and everyone runs).
- **One moon at launch.** More moons later = new worlds unlocked by your base level, each with a new species and its own
  DNA (Mars, Europa...), Pet-Simulator style. Each world = its own place you teleport to.
- **Battles:** the tutorial and early nests (up to 8 v 8 units) happen on a battle pad next to your plot, in the hub
  (no loading). Bigger nest raids (16+ a side) and every player battle teleport to a BATTLE place (one battle per
  reserved server). How many hub fights at once a server can carry: **[TEST]** (start at 3; extra ones wait a few s).
- (30 Oct, map-size audit, James approved) The hub is ONE bigger moon, ~1,660 x 1,400 (r4): crater + 8 plots in the middle in an open plain,
  biomes against the cliff walls: Moonwood N, Goo Marsh W, Crystal Canyon E, Lander Ruins S; in-server fast travel; `map-review/map-size-audit.md`.
  Was: the big 1,008 x 672 moon: its terrain + props become the hub (crater in the middle, plots round it); battle arenas are
  cut from it (§8.5).

## 3. Two materials
| | MOON ROCK (grey) | ALIEN DNA (glowing: cyan for Squish, amber for Crunch) |
|---|---|---|
| Where from | rocks on your own plot (respawn every 20 s), drills (passive), battle rewards | DNA veins in the crater + on your plot (slower), meteorites (lots), battle rewards, the DNA extractor (a slow trickle) |
| Spent on | base pads (machines, upgrades, decoration) | hatching eggs in the incubator |
| Why two | building the base is the steady grind | hatching is the exciting roll; keeping them apart means a big base never skips the hunt |
Mining: tap / click the rock with your pickaxe; better pickaxes (rock pads) mine faster. Meteorites need several
strikes; everyone who hit it gets a share (no stealing, no griefing).

## 4. The base (tycoon)
Pads in a set order with small branches; walk onto one with enough rock and it builds (the classic tycoon square).
| Pad line | What it does |
|---|---|
| Drills 1-6 | mine rock by themselves; while you're offline nothing runs: on your return the server pays `savedRate x min(now - lastSeen, 7200 s)` using ITS clock (os.time on the server, never the client's) and the drill rate SAVED when you left (upgrades bought after you return don't count backwards); the rock and the new lastSeen are written in ONE profile update, so a rejoin, reconnect or retry can never pay the same time twice |
| Refinery + conveyors | more rock per drill |
| **INCUBATOR** (Squish, then Crunch) | hatches eggs with DNA (§5); upgrades = faster hatch, 2nd and 3rd egg slot |
| DNA extractor | a slow DNA trickle (the hunt stays the main source) |
| Pickaxes 1-5 | mine faster |
| Battle pad -> Launch pad | where battles start (pad = hub nests, launch pad = big raids + player battles) |
| Trophy hall | shows your rarest aliens on pedestals for visitors |
| Decoration | lights, flags, alien statues (cosmetic sink) |
No rebirth at launch. Other players can't attack your base (raiding bases = a later idea, its own audit).

## 5. Hatching aliens
- The incubator turns DNA into an egg; the egg hatches in 10-60 s (you can watch it wobble; upgrades shorten it).
- **Each hatch = ONE alien** (a 1-matter swarmer: Drip or Pebble) for your army, with a rolled LOOK (cosmetic only):
  Normal 89.38 % / Glowing 8 % / Crystal 2 % / Shadow 0.5 % / Rainbow 0.1 % / Cosmic 0.02 % (about 1 in 5,000; the full
  table, adding to 100 %, is shown on the incubator; server banner for Cosmic). Your first hatch is always Glowing.
- **The army:** start with 8 Drips; each hatch adds 1. You can own up to 32 of each species, and you take ONE species
  (up to 32 matter) into a battle (pick it on the launch pad). More aliens = bigger merges unlock naturally: 2 for a
  Twin, 4 for a Brute, 16 for a Titan.
- **Fast early growth (r4) [TEST]:** 16 owned (first Titan possible) in 5-8 min of play, 24 in 12-18 min, the full 32
  in 20-30 min. After 32, hatching is for looks (faster / batch hatching comes later).
- **Past 32:** a hatch never replaces anything by itself. If it rolled a look you don't have on that species, you choose
  which alien gets it (or keep the old one); otherwise it becomes DNA + a look fragment (5 fragments of a tier = pick that
  tier for any alien). **Favourite lock:** a locked alien's look is never swapped or merged away.
- **Each alien is a real item (provenance):** it has its own id and look in your profile. A merged alien remembers the
  exact aliens inside it and wears the rarest of their looks; splitting gives back THOSE aliens with THEIR looks. Rarity
  is never duplicated by merging or splitting.
- Between rare finds: every 10 hatches gives a small sure reward (a decoration, a fragment) so the hunt never goes dry.
- Index (the book): every species x look; filling a row gives a title / emote.

## 6. Abilities: unlock them with levels (James's question)
Each alien has 3 abilities (power graph): PASSIVE (how it attacks), AUTO (uses it by itself), ORDER (your button).
- **PASSIVE: always on.** It's how the alien fights, and the whole counter loop (swarm beats Titan...) depends on it.
- **AUTO: unlocks at species level 2 (about 2-3 min in).** **ORDER: unlocks at level 3 (5-8 min in)**: its button
  appears with a short lesson. Unlocks are per SPECIES (all four of its forms at once); the kits don't change.
- Species level comes from battles + hatches (one bar per species, 1-20). Levels 1-3 are the lesson (first session);
  levels 4-20: looks, titles, and in PvE only up to +10 % HP / +10 % damage at level 20.
- **Player battles are fair:** they open at species level 3 (about 10 min in). Everyone fights with the full kit,
  32 matter and the same stats, whatever they own: a player with 8 hatched Drips gets a standard 32-matter army for that
  battle (his own aliens + standard ones to fill up; his looks come with him). PvE nests use only your OWNED army.
- Why it works with the balance: the sim says autos + Orders add 2-40 % in their best matchups and never beat a
  counter; early nests are tuned for passive-only armies.

## 7. Merging + splitting (no beam)
Tap one of your aliens: it and its kind nearby light up (a group). The bottom bar shows what that group can do:
**MERGE** ("4 Drips -> Brute", with a ghost of the result) and **SPLIT**. One tap. The server checks the exact aliens
shown against the locked rules (distances, times, the 5 s lock). The UFO beam is dropped as a control. The battle camera
is an overhead tactical view; the UFO can hover in it as decoration, never in the way **[JAMES]**.

## 8. Battles
### 8.1 Modes
| Mode | Where | Your army | Stats |
|---|---|---|---|
| Tutorial + **hub nests** | battle pad by your plot (in the hub) | up to 8 UNITS a side (units, not matter: a Titan is 1 unit), picked by you from your owned aliens, so your first Titan can fight there | PvE bonus applies |
| **Big nest raids** (harder moons, a boss Titan every 5th) | battle place | your hatched army (nests scale to it) | PvE bonus applies |
| **Player battles** 1v1 (casual, later ranked) | battle place | 32 matter, full kit, everyone equal | normalised |
After every battle: **REMATCH** (one tap) or BACK TO BASE.
### 8.2 Controls
| Verb | Phone | PC | What happens |
|---|---|---|---|
| **SELECT a group** | tap one of your aliens: it and its kind within 12 studs light up | left click | MOVE / MERGE / SPLIT apply to that group |
| SELECT a form / all | form chips, bottom left / ALL chip | 1-4 / ` | all of that form / everything |
| **MOVE** | tap the ground | right click | the selection attack-moves there |
| **MERGE** | the MERGE button (shows the result: "4 Drips -> Brute" + a ghost) | F | the server merges EXACTLY the aliens shown |
| **SPLIT** | the SPLIT button | G | the selected big alien splits |
| FOCUS | tap an enemy | right click it | the selection prefers it (AI score x3, prey rules still apply) |
| **ORDER** | the form's big button, bottom right (from species level 3) | Q W E R | power graph Orders; glow = good moment |
- **Honest preview:** the server checks THOSE alien ids with the locked rules (2 F1 within 6, 2 F2 within 9, four F3
  within 18 studs of THEIR centroid) when you tap. If they drifted apart: "too far apart", nothing spent, no other
  aliens merged. Acceptance test (r3): move the group, start another transformation on one of them, tap MERGE at the
  same moment: rejected cleanly (no matter spent, no lock, no cooldown, nothing else transformed).
- Merging / splitting aliens can't attack, take x1.25 damage, show a 0.3 s tell. Max 2 transformations at once.
- Tutorial teaches MOVE, MERGE, SPLIT only. HOLD = double-tap the rally ring; RETREAT = all home at 1.3x speed, can't
  attack, 8 s cooldown. Every button >= 64 px; no drags.
- **[TEST]** on a real phone: can a 10-12 year old pick the right group, merge, split, in under 3 s each?
### 8.3 A player battle (1v1), start to finish (210 s, cap 240)
| Time | Phase | |
|---|---|---|
| -20 s | DEPLOY | pick race + starting mix: ANY legal split of 32 matter (presets SWARM / BALANCED / TITAN are shortcuts only); hidden until 0:00 |
| 0:00 | GATES OPEN | armies drop through their forward gates |
| 2:30 | OVERCHARGE | Order cooldowns x0.75, core shields off for good, music + sky change |
| 3:30 | TIME | healthier core % wins; within 1 % = 30 s sudden death; then draw |
### 8.4 Arena rules (ALL [TEST] in the sim before they lock)
| Thing | Rule (one each, no overlaps) |
|---|---|
| Matter Core | 12,000 HP. **Shield rule: takes 50 % damage while its owner holds the Fusion Reactor; never after 2:30.** |
| Fusion Reactor (crater) | capture speed = your units in the ring minus the enemy's (units, not matter); held: your Order cooldowns x0.85 |
| Fusion vents | units on a vent fuse in HALF the animation time; the 5 s lock stays (locked rule) |
| Defence pylons (2 per base) | 1,500 HP, 40 dps, x2 vs swarm |
| Respawn | defeated matter returns after 12 s as F1 at the gate |
Sim questions before locking (the power sim gets bases, a reactor and respawns): does the swarm's capture edge + the
reactor's cooldown cut snowball? Is a Titan killed (16 matter back in 12 s, as Drips) better or worse for its owner
than 16 Drips dying one by one? Average match length 160-240 s? Comebacks: the side behind at 1:30 wins >= 20 %?
### 8.5 The arena map **[JAMES] [TEST]**
Prototype a smaller arena (about the original 360 x 240 design: bases, crater, canyon, boulder plain) cut from the big
moon; keep the big 1,008 x 672 arena to compare bot-vs-bot (first contact time, fights per minute, match length). The
rest of the moon becomes the hub (§2).

## 9. Why players come back
Builder (finish the base, every pad), collector (Index, a Cosmic look on every form), grinder (level 20 on both species, every nest moon), competitor (casual now,
ranked later). Daily tasks (3, plain words) and a weekly meteor shower come after the slice.

## 10. Money (launch: cosmetics only)
Base decorations, pickaxe skins, UFO / incubator skins, emotes, private servers. NOT at launch: luck boosts (paid-random-items rules: odds +
regional limits), equip slots, battle pass. NEVER: matter, stats, rock / DNA, hatch looks or Index finds for Robux (no paid eggs: paid-random-items rules).

## 11. Roblox build
### 11.1 The slice: ONE place
One plot + battle pad + a bot arena in one place, no saving. Proves the loop before any cross-server work.
### 11.2 After the slice: two places (hub + battle), done right
- **Match making (r2 fixes T1-T3):**
  - Queues: `MemoryStoreService:GetQueue("q_<mode>_<band>", 30)` (the 2nd argument is the 30 s invisibility timeout)
    per mode AND band (casual: by MMR band; ranked: rating band of 100). After 15 s waiting a player is
    ALSO put in the neighbouring band; after 30 s, a bot match.
  - Pairing: `local items, readId = queue:ReadAsync(2, true, 5)` (count, allOrNothing = true: a full pair or nothing,
    wait 5 s). Those entries are hidden from every other server until the timeout.
  - **Player lease** (one entry, one match per player): a sorted map `player:<userId>` holds {state, matchId, until}.
    The pairing server sets BOTH leases with `UpdateAsync` only if each is "queued" (not "matched" or expired); if
    either fails, it releases the one it took and lets the queue items time out back (no RemoveAsync).
  - Only when both leases are held: write `match:<id>` (only if absent), `RemoveAsync(readId)`, then teleport.
    Entries older than 60 s or whose player left the hub are rejected at the lease step.
  - Rewards: settled exactly once by M3 below (reward + permanent processed-match record in one profile update).
- **Reserved servers:** `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` (verified in the live docs
  30 Oct: ReserveServer access codes and ShouldReserveServer are deprecated); the same id routes a reconnect.
- **One absent-player rule (T4):** from the start of the match, a player who isn't there (never arrived, or dropped) has
  his army played by the Normal bot. He has **45 s** from the moment he went missing to (re)join the same reserved
  server and take control back mid-match (no restart). After 45 s he FORFEITS (M4 below): the opponent gets the win
  whatever the stand-in bot does afterwards.
- **Teleport failures:** handle TeleportInitFailed (3 retries, backoff). If the teleport finally fails after the hub
  let go of the profile, the hub re-takes the lock and puts the player back in the queue screen; nothing is lost.
- **Profiles between places:** session-locked profiles (ProfileStore pattern). The battle server waits for the lock with
  the store's built-in retry (the hub may still be releasing it: the documented fast-transition race) before admitting
  the player; rewards are written with the match id so a retry can't double them.
- **Admission (T5):** the battle server never trusts TeleportData: on PlayerAdded it reads `match:<id>` from MemoryStore
  and checks UserId, team and that the match is live; anyone else is kicked to the hub.
- **Still required before multiplayer is built (ChatGPT r3, NO-GO until done; they don't hold up the bot slice):**
  - M1 one queue-session token per player (entering the neighbouring band re-uses it); pairing checks the token, so a
    stale entry in another band is rejected after a match; a rollback releases only leases this exact attempt owns
    (conditional UpdateAsync on the attempt id), never one another server took.
  - M2 the 30 s bot fallback flips the player's lease to "bot" atomically (no PvP pairing after it); leases and match
    records carry an expiry covering the match + reconnect window, so a crashed pairing server recovers by itself.
  - M3 rewards = one settlement step: the reward and the processed match id are written to the profile in the SAME
    profile update (permanent, not a last-20 list), so a retry finds it already settled.
  - M4 leavers: after the 45 s grace the absent player FORFEITS: the opponent gets the win whatever the stand-in bot does
    afterwards; no rating is earned for the rest of that fight; leaver penalties are a separate rule.
- **Tycoon + collection data (r4):** one session-locked profile per player holds: bought pad ids + upgrade levels, rock +
  DNA balances, eggs in progress (with the server time they finish), every alien (id, species, look, locked flag, the
  ids inside a merged one), looks fragments, species levels, Index, lastSeen (server time). Pad purchases are
  server-only and idempotent: check plot owner, the pad's prerequisite, not already bought, enough rock; deduct and
  record the pad in ONE profile update (a double tap or a lag retry buys nothing twice). DNA and rock are never sold
  for Robux, directly or indirectly (paid-random-items rules); no paid luck.
### 11.3 Authority + network
- Client sends INTENTS only (select / move / focus / merge / split / order / retreat; mine strike; buy pad; start hatch):
  rate-limited, validated (owner, alive, cooldown, distance, matter sums, phase, target exists and is legal), with a
  per-player sequence number (no replays).
- Server: THINK 5 Hz staggered, MOVE 20 Hz, combat authoritative. Positions 10 Hz on UnreliableRemoteEvent packed in a
  `buffer`, < 1,000 bytes (chunk if over), sequence numbers: a client drops any snapshot older than the newest it has
  applied (and any for a unit generation that no longer exists); a reliable full-state correction every 2 s carries
  its own server time and only overwrites state older than it (reliable and unreliable channels don't share ordering).
  **Measure the real packet size** (the 640 B figure is an estimate). 5 / 20 / 10 Hz are starting values, not budgets.
- Hatch looks, meteorite shares and pad purchases decided on the server (the shown odds come from the same table);
  pads check rock + order + plot owner; mining checks strike rate + distance.
### 11.4 Performance: what's proven and what isn't
- Proven: CLIENT rendering, 96 AI units at 60 fps on a base iPhone 17.
- NOT proven (the next measurements): a LIVE two-client match on Roblox servers: server frame time (target < 16.7 ms
  steady), AI CPU per tick, network KB/s per player, 30-min session memory; a budget phone at 64 units incl. thermal
  throttling; the hub with 8 bases fully built + effects + meteorites + pets + avatars + 3 hub fights at once (48 AI units): server
  CPU + memory and a low-end phone. Build one full plot first, then load-test eight.


## 12. Build order
1. **The slice, ONE place, no saving:** one plot of the hub (rocks, 3 drills, incubator, battle pad), MOON ROCK + DNA,
   hatching with looks, the 8-Drip army growing, hub nests with MOVE / MERGE / SPLIT, abilities unlocking at levels 2 and 3
   (levels 2 and 3), REMATCH.
2. **Bot battle in full** (32 v 32 vs the bot, arena rules §8.4) in the same place; sim the arena rules.
3. **Play test** on a phone: James + someone new. Questions: do they understand that splitting a giant into smaller
   aliens can turn a losing fight around? Do they want the next pad / next hatch? Do they start another battle by
   themselves?
4. Then: 8-plot hub, saving (base, army, looks, levels), offline drills, the battle place + matchmaking (M1-M4, §11.2),
   player battles, daily tasks, cosmetics shop. Later: more moons, base raids (own audit).

## 13. Open for James (short; ChatGPT r4 agrees with every pick)
1. **Base:** 8 players per server, each with a plot round a shared crater, one moon at launch?
2. **Two materials:** MOON ROCK builds the base, ALIEN DNA hatches aliens (James's idea)?
3. **Hatching:** one alien per egg, your own 32 in about 20-30 min, each alien keeps its own rolled look?
4. **Abilities:** passive from the start, auto at level 2 (~3 min), Order at level 3 (~6 min), player battles at ~10 min?
5. **Merge:** tap a group + MERGE / SPLIT buttons (no beam), overhead camera with the UFO as decoration?
6. Still open: F3 560 HP / 44 DPS (ChatGPT: approve provisionally), F3 speed 16, one Order button per form.
