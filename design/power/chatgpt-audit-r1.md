# ChatGPT audit r1 of power graph v2 (28 Oct 2026, Thinking high, 6m47s)
Chat: https://chatgpt.com/c/6ae17ad9-cfa8-83ec-8c4a-a48125563b96 . Inputs: 09-POWER-GRAPH.md, kits.mjs, sim.mjs, final-run.txt.

**Verdict: GO WITH CHANGES** for the ability architecture; HOLD on calling the numbers production-balanced.
Approves F3 650/48 -> 560/44 as the provisional baseline. "Do not nerf F3 again on the all-Brute mixed result."

## Required changes (and what I did, see BUILD notes in 09 §6)
1. BOING: leap 10, dr 0.40 fallback, cd 10 (dodge only works if it leaves the shape). CURL UP: dr 0.85 vs one F4 hit, cd 10.
2. CHEST THUMP ally shield = min(30, 20 % of the ally's max HP) (30 on a Drip = 30 %, broke the guard rail).
3. Orders rebudgeted; F3 multiplier on the PRIMARY hit only: BOING SLAM 20x3, SIDE SWEEP 20x3, RAM CHARGE 60 / 15 side,
   GOO TSUNAMI 240 / 35 side, SOLAR STRIKE 225 / 25 side, burn 8/s for 2 s.
4. CLAW BLOCK needs 2 F1 attackers; HOOF STAMP triggers on an F2 within 5, F2 first, cap 2, no F1 stun;
   RAM CHARGE needs an F2/F3 target (F2 first), never aims at a Titan.
5. Fusion/split state inheritance (engine rule): fused unit takes the latest auto cooldown; split copies it; stun and
   immunity expiry kept; status expiry kept; shields split by matter / summed on fusion (capped 20 % HP); one Order
   cooldown per player + form.
6. Forced-movement budget: 8 studs per victim per rolling 3 s (pull, knock, toss); F4 immune.
7. Colossus damage synced to its animations: SHATTER warning 0.64 s, hit 1.64, anim 3.8; BOULDER warning 2.40, hit 3.40;
   SOLAR ring 2.00, hit 3.20; no attacks during the animation lock.
8. Order threshold = 30 % of ALL living units of that form; SIDE SWEEP sorts by distance before the cap; RAM CHARGE hits
   its chosen primary first; BOING BOMBS clears its bonus if the target dies.
9. Validation: seed every random call; 200 mirrored fights per EDGE step; open / spread / narrow-lane formations; later:
   fusion decisions, bases, 210 s match.

## Optional
- Remove the 20 % slow from TENTACLE SLAM (Titan verbs: crush / trap / overwhelm).
- Titan lobs should prefer F3 and bases over the densest cluster.
- Phones: incoming Order warning gets visual priority; puddles merge; one consolidated danger shape, not 32.

## Fit scores (/10)
Drip CLING 10, BOING 6 (dodge didn't work as coded), BOING BOMBS 9 · Twin DOUBLE SLAP 10, STICKY FLOOR 10, BOING SLAM 9 ·
Brute KNUCKLE POUND 10, STRETCH GRAB 10, CHEST THUMP 9 · Titan TENTACLE SLAM 10, GOO BOMB 8, GOO TSUNAMI 9 ·
Pebble CHIP 8, CURL UP 7 (DR too weak), ROLL OUT 9 · Pincer SCISSOR SNAP 10, CLAW BLOCK 9, SIDE SWEEP 9 ·
Ram HORN GORE 10, HOOF STAMP 9, RAM CHARGE 10 · Colossus GROUND SHATTER 10, BOULDER HURL 9, SOLAR STRIKE 9.

## What it trusts
Loop direction: credible. Exact EDGEs: low confidence (sim not fully seeded at the time). 51/49 race split: not validated.
"Every mix has a counter": limited (static pool). Siege, snowball, fusion: not tested.

# ChatGPT audit r2 (same chat, 4m2s): GO WITH CHANGES, "v3 is nearly ready"
- Accepts all five deviations: (a) Titan scheduling + stronger throws/Orders ACCEPT; (b) Curl 70 % / 12 s, Boing fallback 50 %
  ACCEPT WITH CAVEAT (Curl mitigates a primary slam, doesn't survive it); (c) Stamp/Claw Block on own tier ACCEPT;
  (d) Ram Charge 90/20 ACCEPT; (e) Titan splash 25 % ACCEPT. "Do not revert the deviations to match my r1 numbers."
- Freeze F3 at 560/44; stop tuning base stats and counter multipliers; don't buff Titans because their Orders add little
  in isolated brawls (the sim measures clashes of 9-35 s, not whole matches). Seeded RNG verified (same seed = same result).
- Required (all applied 28 Oct): 1) lobs + Solar Strike keep the target's last known spot and still land if it dies; a
  released boulder lands even if the thrower dies; 2) the "2+ targets or a Brute" rule is only the sim's AI: a player can
  fire an Order at any single enemy or base; bases need real targeting in the game (not in the sim); 3) Hoof Stamp hits only
  Packs/Brutes; Side Sweep only swarms/Packs; 4) Boing jumps to the nearest exit of the actual shape (+0.5, max 10), else
  squashes flat (50 %).
- Before the final lock: a Studio test of the fusion invariants (inherited auto cooldowns, 3 s stun immunity, 8-stud push
  budget, 20 % shield cap) through repeated fuse/split cycles; siege value tested against bases.
- Then: **GO for Roblox playtesting at the v3 numbers.**
- Fit scores changed: BOING 6 → 9, CHIP 8 → 9, CURL UP 7 → 8, GOO BOMB 8 → 9 (other 20 unchanged).
