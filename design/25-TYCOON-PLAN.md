# Alien Fusion: the tycoon plan (1 Nov 2026, Claude + ChatGPT, TYCOON SPEC r2 = GO for slice 1)

James (1 Nov): "the best structure that gives long-term play but very importantly very quickly draws the player in".
Sources: `economy\tycoon-spec-r1.txt` (ChatGPT, live web search: 32 queries, 23 pages cited: Roblox Creator Hub
onboarding / retention / quest docs, DevForum balancing, Grow a Garden, Steal a Brainrot, Pet Sim 99, Merge an Army,
Factory Simulator, Retail Tycoon 2, Mining Simulator 2, Bee Swarm, Military Tycoon, Restaurant Tycoon 2, Newzoo 2026)
-> Claude audit (6 points) -> `economy\tycoon-spec-r2.txt` GO. (ChatGPT Deep Research ran twice with 0 searches:
unusable on this account, use normal Thinking + web search instead.) Builds on `24-MATERIALS-AND-TYCOON.md` (locked).

## Rules taken from the research
- Fun inside ~5 min (Roblox D1 guidance). First buy in 15-30 s, first battle < 60 s, first hatch by min 3.
- A buy every 30-90 s of focused play early on; every buy changes something you SEE or can use. No walls, no empty pads.
- Price = expected income x saving time (not one exponential formula). One green "next" pad + at most 1-2 optional ones.
- Two branches: ARMY (incubator -> launch rigs -> forts -> throne) gets the next-goal arrow; FACTORY is optional.
- Long term without rebirth: collection (rare LOOKS), base decoration, fort challenges, throne prestige, daily goals,
  no punishment for missed days.

## Purchase order (Moon Rock)
| Stage | Buy | Rock | Lands | You see |
|---|---|---|---|---|
| 0 | Launch Pad | free | 0:00 | 8 Drips ready |
| 1 | Rock Drill | 20 | 0:15-0:40 | spinning drill, +8 Rock/min |
| 2 | Incubator (BOTH chambers: Squish + Crunch) | 30 | 1-2 min | two glowing egg chambers |
| 3 | T2 Iron Pick | 40 | 2-4 min | "MINE GOO FASTER" |
| 4 | Launch Rig 12 | 60 | 4-7 min | bigger launch circle |
| 5 | T3 Lunar Pick | 80 | 7-11 min | "MINE DNA FASTER" |
| 6 | Launch Rig 16 | 110 | 10-15 min | second ring |
| 7 | Launch Rig 24 | 180 | 16-22 min | needs Fort 2 |
| 8 | Launch Rig 32 | 280 | 22-30 min | needs Fort 2 |
Critical path = 800 Rock (890 with Dense Rock I). Optional: Refinery 45 (drill 8 -> 12/min), Goo Extractor 65,
Dense Rock I 90, Crystal Extractor 100, T4 160 ("FASTER MINING"), Dense Rock II 160, T5 300 ("FASTEST PICK"),
Dense Refresh 250 (50 -> 30 s), Second Drill 400, Extractor upgrades 450 each, Trophy Hall 200, decor 60-800+.
REMOVED: Second Egg Slot + Hatch Speed (dead buys: 12 s hatches already beat DNA income of 13-30/min).
Fort 2 must be beatable at the 16 cap (else deadlock).

## Eggs + hatching
- 12 matching DNA, 12 s, each chamber has its own REPEAT toggle (keeps hatching while you're out mining).
- New player gets 12 Goo DNA once (= one starter Squish egg). Fort 1 first clear: 60 Rock + 24 Goo + 12 Crystal.
- Hatch reveal anywhere: card top-right 2.5 s (look + name + rarity, e.g. "NEW DRIP! RARE"), the alien appears at the
  incubator, celebrates, walks to its display; queued cards + "+3 NEW ALIENS"; rare = stronger sound/glow + VIEW
  button. Server rolls the look, client only shows it.

## Machines (help, never beat active play)
Drill 8 Rock/min (12% of T1 hand); + Refinery 12; two drills + refinery 24; fully upgraded 36. Goo / Crystal
Extractor 0.8 DNA/min, 1.2 after its fort, 2.5 upgraded (< 1/5 of T1 hand DNA). No Rock -> DNA conversion.
Offline (slice 2, after saving exists): 25 % of machine rate, max 2 h, max 1,080 Rock + 75 of each DNA.

## Plot layout (local x -47.5..47.5, z -42.5 front/crater..42.5 back; walkway x -7..7 kept clear)
| Object | Centre | Size | Pad (6 x 6) centre |
|---|---|---|---|
| Launch Pad / Rig | (0, -31) | 16 x 16 | Rig pad (13, -31) |
| Incubator | (-25, -8) | 14 x 14 | (-12, -8) |
| Drill | (25, -4) | 12 x 12 | (14, -4) |
| Refinery | (26, -20) | 14 x 10 | (14, -20) |
| Goo Extractor | (-29, 22) | 12 x 12 | (-29, 10) |
| Crystal Extractor | (-14, 27) | 12 x 12 | (-13, 14) |
| Pickaxe rack | (-29, -30) | 10 x 8 | (-15, -30) |
| Trophy display | (29, -32) | 10 x 8 | - |
Mining corner (built) x 12..41, z 10..38 incl. empty Dense sockets (12,35) + (41,10): keep clear. Claude checked: no
overlaps with the sockets, the walkway or each other. Verify real mesh bounds in Studio.

## Build slices
- **Slice 1 (one session, no saving):** Drill pad 20 -> 8 Rock/min; Incubator pad 30 -> both chambers; starter 12 Goo;
  Squish + Crunch eggs (12 DNA, 12 s) + repeat; hatch reveal cards; session-only ownership. Pass: James joins, mines,
  buys the Drill, buys the Incubator, hatches a Drip and sees the reveal while away from the plot.
- **Slice 2:** session-locked DataStore saving (balances, purchases, pick tier, aliens + looks, fort progress), then
  offline earnings. Pass: buy + hatch, leave, rejoin = exact state, nothing doubled.
- Before visuals: reference images for every machine + pad (method as mining). Track onboarding events server-side
  (first rock, drill bought, first battle, Fort 1 cleared, incubator bought, first hatch).
- Open: validate DNA + Fort 2 + combat time together before locking the late Launch Rig prices.
