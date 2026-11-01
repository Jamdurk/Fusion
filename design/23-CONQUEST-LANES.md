# Alien Fusion: CONQUEST LANES (draft r1, 31 Oct 2026, Claude) - for ChatGPT audit, then James

## James's idea (30 Oct, his words, trimmed)
"I was playing other Merge games ... Merge an Army ... you merge your army, they passively spawn in your base, then
there's a little army base right in front of yours, and when you're ready you can deploy however many troops, you can
upgrade how many you can deploy. They fight that first mini base. If they die you keep trying again. If they do it,
you conquer it, and then you go to the second base in front, which you have to conquer again. Once you conquer that
one, it goes right to the center, which is the hardest ... it's conquered by another player ... if that player has put
really overpowered troops there, you'll need overpowered troops as well. I wonder if this is the approach we should
take. It would mean spacing out the tycoon bases a bit more."

## What we have now (locked unless James changes it)
- Hub: 8 plots in two columns of 4 (X +-230, Z +-65 / +-190), the crater landmark at 0,0, open plain, 4 biomes on the
  walls. Mechanics v4.2 (`21-GAME-MECHANICS.md`): mine rock -> build pads; DNA -> hatch 1 alien per egg; army 8 -> 32
  per species; battles = hub nests on a battle pad by your plot (<= 8 units a side), big raids + fair 1v1 PvP in a
  separate battle place. You steer the army (MOVE / MERGE / SPLIT / ORDERS), never pick attacks.
- Known risk: 8 players fighting in the hub at once (`map-size-audit.md`: render <= 32-48 full-detail fighters per client).

## The proposal: each plot gets a LANE to the crater
```
 [YOUR PLOT] --> OUTPOST 1 (easy nest fort) --> OUTPOST 2 (harder) --> THE CRATER THRONE (held by a player)
```
1. **Lane:** a straight path from each plot's front edge toward the crater, ~120-160 studs. On it: Outpost 1 (~40% of
   the way) and Outpost 2 (~75%). Each is a small alien fort (walls of rock + a nest + 6-10 defenders + a glowing
   core). 8 lanes = 16 outposts round the crater, each player's own (instanced per player: your outposts, your fights).
2. **Deploy:** on your plot's LAUNCH PAD you pick how many aliens go (DEPLOY CAP: starts 8 units, upgrade pads raise it
   to 12 / 16 / 24 / 32 matter). They march down the lane and you steer the fight like any battle (merge / split / Orders).
   Lose: they come back (no aliens lost, a short cooldown). Win: the outpost flips to your colour, gives a big reward
   once + a small trickle (rock or DNA) while you own it, and opens the next stage.
3. **Outposts are PvE**, tuned to the hatch curve: Outpost 1 = the old "first nest" (8 Drips win at minute 1-3),
   Outpost 2 = needs a Brute / Titan (minute 8-15). Later: harder "tiers" of outposts reset weekly (or with a base
   level) so the lane never runs out.
4. **The CRATER THRONE (centre) = held by ONE player at a time** (the server's King of the Moon). Its garrison = the
   holder's chosen aliens (up to 32 matter of THEIR army), defended by the AI when the holder is busy or away.
   Attacking it = an asynchronous fight: your deployed army vs their garrison (AI). Win = you hold the throne, your
   colour on the reactor, a crown + a passive bonus (e.g. +10 % drill rate, server banner). Holder gets a reward for
   every defence that holds.
5. **Spacing:** the plots move a little further out (X +-230 -> +-290?) so each lane has room; lanes are fan-shaped
   and never cross. The crater stays the centre landmark.

## Tensions with what's locked (ChatGPT, please rule on each)
A. Mechanics v4.2 says player battles are FAIR (same 32 matter, normalised). James's throne is explicitly UNFAIR
   (OP troops win). Keep fair 1v1 PvP in the battle place and make the THRONE the one unfair, async, hub-wide prize?
B. "They passively spawn in your base" (Merge an Army) vs our hatch-from-DNA. Keep hatching (it's our rare-look hook)
   and only borrow the lane / deploy cap / outposts / throne?
C. Hub performance: 8 players each fighting an outpost = up to 8 x (16-32 + defenders) units in one server. Run
   outpost fights in the hub (visible, social) with a per-client LOD / unit cap, or make them instanced so other
   players see only flags flipping?
D. Map: does a lane + 2 outposts + a fortified throne overcrowd the open plain James asked for (r4: "open space round
   the bases")? Exact spacing numbers for 8 lanes in a 650 x 520 hub.
E. Throne snowball: one strong player holds it forever. Rotation ideas: a garrison decays a little per hour, the throne
   resets every 30 min, or each attack weakens it.
F. Is this original enough next to Merge an Army (James: "I know I should be original")? What's our twist: aliens
   MERGE / SPLIT mid-fight, two species, the crater reactor?

## What James decides after the audit
Go / no-go on the lanes; plot spacing; throne fairness (A); passive spawning (B).

## ChatGPT audit r1 (31 Oct ~12:20, "Roblox Development Depth" chat): GO WITH CHANGES 8.5/10
Fun 9, fit 9, originality 7, Roblox feasibility 7. Full text `design\conquest-audit\conquest-lanes-audit-r1.txt`,
layout sketch `conquest-audit\radial-layout-chatgpt.jpg`.
- A: keep fair 1v1 PvP; the THRONE uses your real army (<= 32 matter, PvE bonus capped +10 %), not unlimited power.
- B: keep DNA hatching; borrow only the look of passive spawning (aliens pour out of the base on DEPLOY).
- C: hybrid: Outpost 1 in the hub (max 2 fights at once = 32 units), Outpost 2 + throne instanced.
- D: plots in a RADIAL RING (radius 215, 70 x 70, every 45 deg from 22.5), lanes 16-20 wide, Outpost 1 at r 140,
  Outpost 2 at r 90, throne in the crater.
- E: throne = timed reign (60 s protection, max 10 min, 1 challenge at a time, loser waits 2 min, 60 s reconnect
  grace, then back to an NPC); bonus +5 % rock while you reign; title kept.
- F: original only if MERGE / SPLIT is what wins (test: same army, tactical player must win clearly more).
- Deploy cap in MATTER: 8 -> 12 -> 16 -> 24 -> 32. Outpost 1 = 6-8 matter + ~600 HP core (70-85 % first win),
  Outpost 2 = 14-16 matter + ~1,200 HP core (40-60 %). Loss = no aliens lost, 10 s redeploy.
- Missed: conquered forts stay yours (repeatable harder invasions after); an NPC throne so solo servers aren't stuck;
  first-clear rewards saved in the profile, never paid twice.
- First version to build: ONE plot, ONE 130-stud lane, ONE Outpost 1 in the one-place slice (8 Drips, 8-matter cap,
  LAUNCH PAD, flag flips + rock reward, retry after 10 s). No throne, no extra lanes yet.
