# Lethal Company creature AI, read from the game code (28 Oct 2026, Claude)

**Source:** James's own Steam install (`Lethal Company_Data\Managed\Assembly-CSharp.dll`, build dated 21 Apr 2026),
decompiled with ilspycmd 9.1 (MIT, from NuGet). James: "I spoke to Zeekers the creator and he said it was fine due to modders
already using it" + "download code, pull code, anything you need". We take BEHAVIOUR + NUMBERS; every line of our code is
written fresh in JS / Luau. The decompiled C# stays in Claude's scratchpad, not in this repo.
Class names: Baboon Hawk = `BaboonBirdAI`, Eyeless Dog = `MouthDogAI`, Thumper = `CrawlerAI`, Spore Lizard = `PufferAI`,
Hoarding Bug = `HoarderBugAI`, Forest Keeper = `ForestGiantAI`, Coil-Head = `SpringManAI`, Snare Flea = `CentipedeAI`,
Kidnapper Fox = `BushWolfEnemy`, Old Bird = `RadMechAI`, Nutcracker = `NutcrackerEnemyAI`. Speeds are Unity units/s (~metres).

## 1. The shared engine (`EnemyAI`): what every creature has
| Piece | How LC does it | Number |
|---|---|---|
| Brain tick | `DoAIInterval` decides (states, targets, destinations); `Update` moves + animates every frame | **AIIntervalTime 0.2 s (5 Hz)**; destination re-sent only when it changed |
| States | `currentBehaviourStateIndex` (0 calm, 1 alert/suspicious, 2 chase/fight, 3 special); every state has an "entered" block (`previousBehaviourState != current`) that rolls its random timers once | |
| Sight | cone + range + "proximity awareness" (sees anything that close, any angle) + line of sight both ways | default width 45°, range 60, proximity -1; Thumper 55° / 65° wide in chase, range 80 |
| Memory | last seen position + time; search routine around the last seen spot, width grows each pass | Thumper search 25 → +10 per pass, max 100 |
| Search | seeded random (seed = start position rounded to 5): same place, same search = consistent, not twitchy | |
| Client smoothing | clients SmoothDamp to the server position (0.22 s), turn LerpAngle 15/s; position only sent past a threshold | `syncMovementSpeed 0.22` |
| Off-screen LOD | animator off past 80, or past 35 if hidden | |
| Stun | `stunNormalizedTimer`; then `postStunInvincibility` | |

## 2. Creature profiles (the parts we lift)
### Baboon Hawk: the PACK (best fit for the swarm + army cohesion)
- States: 0 SCOUT (wander with a group, 25-70 s random), 1 RETURN TO CAMP (rest 15-30 s, 35 % chance to sleep), 2 FOCUS THREAT.
- **Group:** sees another hawk → joins the group of whoever has the higher `leadershipLevel`; members stay within ~6 of
  the leader (re-pick a spot when > 8 off), leave the group if > 60 away or out of sight; 4 s cool-down on join/leave. Speeds: scout 10, follow leader 12, camp 9, fight 9.
- **Fear vs courage (the core):** each look (5 Hz) sums, for every threat seen: `threatLevel / (distance * 0.2)`;
  a threat walking TOWARDS it +1 level, standing / backing off -1; then **subtracts the group size** (`fear -= members`).
  fear > 0 → focus the scariest threat; fear <= 0 → focus the WEAKEST threat (it bullies when it outnumbers you). A threat that already hit it: +2 fear if the group is <= 3, else -(members / 1.5).
- **Comfortable distance** = min(threatLevel x 6, 25) + fear x 2. It keeps that gap and backs off along the line away
  from where the threat is heading (`lastSeen - velocity x 17`), clamped by walls.
- **Escalation ladder = the tell:** mode 0 calm → mode 1 AGGRESSIVE DISPLAY (screams, posture; fightTimer builds
  faster the closer it is: `+0.2 x 10.6 / (dist x 0.3)` per tick) → when **fightTimer > 7** and 4 s since its last fight:
  mode 2 ATTACK (runs at where the threat WILL be: position + velocity x 10).
- **Attacks are short:** in mode 2 it gives up after **4 s** (or 2 s if scared, or when hit by a player) → fightTimer -7,
  back to display. That "rush, swipe, back off, rush again" rhythm is what reads as alive.
- **Memory:** threat unseen 0.55 s = out of view; > 1 s calm down the display; > 3 s drop it if comfortably far; > 5 s forget.
- **Group pull:** if any member is in mode 2, the others don't drop the fight. A hawk that sees another hawk focused on a
  threat "pings interest" at it (looks there, priority 3-4).
- Idle life: random misc animations, head-look rig, peeks; voice pitch randomised per creature.

### Eyeless Dog: the HUNTER with a meter (fits the Brute's "notice then commit" and the Titan's alert)
- States: 0 ROAM 3.5, 1 SUSPICIOUS 4.5, 2 CHASE **13 → 18** (speed +1 per s), 3 LUNGE.
- **Suspicion meter 0-12:** a loud noise within `18 x loudness` (halved through walls) jumps it to 9 = full chase; quieter
  ones +1 each; >= 5 = suspicious. Decays 1 per 4 s (suspicious) / 3 s (chase); chase drops at <= 8, suspicious at <= 1.
- **Imperfect info:** it never goes to the exact noise: a random point within `distance / noiseApproximation`.
- **The tell:** entering chase it STOPS (speed 0.05), howls, 0.5 s + 0.2 s, then runs. The howl calls every other dog to
  that spot (pack alert).
- **Lunge:** within 4 of its guess and lunge cooldown <= 0: a straight 17-unit lunge at 13, slowing 5/s; ends below 1.5,
  0.25 s cooldown. Stunned dogs enrage at whoever stunned them.

### Thumper: the CHARGER (fits the Ram + Pebble Roll Out)
- States: 0 SEARCH (speed 7), 1 CHASE. Notices after **0.2 s** of sight (`noticePlayerTimer`, LOS checked every 0.05 s).
- **Speed builds on straights:** `acceleration = clamp(base - avgVelocity x 2, 4, 40)`: the faster it goes, the worse it
  accelerates and turns, so it overshoots corners. Sudden speed loss (velocity drops > max(17 %, 2)) = it SLAMS into a
  wall (sound + shake). Loses you → searches the last seen spot; after 15 s of nothing, back to search. Hit: 40 dmg.

### Spore Lizard: the ESCALATION LADDER (fits CLAW BLOCK / CURL UP / any "warn before you act")
- 0 ROAM; sees a player within 20 → 1 AVOID: runs to the node farthest from them.
- Cornered or closing in: 0.75 s alert → **fearTimer > 1 s or < 7 away: STOMP** (warning) → **> 3 s or < 5: PUFF** (spores)
  → only after both, 2 ATTACK. Lost sight for 5 s → back to roam. Each step is a visible, readable warning.

### Hoarding Bug: the TERRITORIAL GUARD (fits the Twin bodyguard)
- Guards a nest; an item it owns that a player holds = STOLEN.
- **Annoyance meter:** player within 8 of it while it's calm: +0.2 per tick (5 Hz), chitters; **> 2.5 → angry for 3.25 s**.
  Within 4 (8 while chasing) = angry at once. Hit = angry 4 s at the hitter. Speeds: calm 6, angry chase **18**.
- Waits at the nest 15 s, watches players near it; drops what it carries to fight.

### Forest Keeper: the GIANT (fits the Titan + Colossus)
- **Stealth meter per player (0-1):** fills by `dt / (distance x 0.21) x scrutiny`, drains 0.33/s when unseen (0.2/s
  hidden); **chases when > 0.35**; only switches target after **2 s** on the current one (commitment).
- **Stop and look:** every ~12 s it stops for a random 3-12 s and looks around (the big, slow "thinking" beat).
- **Speed ramps** `x1.3` per tick up to 7 (8 in chase): never jumps to full speed. Out of sight > 9 s → gives up.
- Stares at the same spot 3 s → walks over to investigate.

### Coil-Head: the FREEZE (a readability idea, not a profile)
- Only moves when nobody looks; chase speed 14.5, ramps with Lerp 4.5/s. Lesson: an "is it looking at me?" rule kids get instantly.

### Snare Flea: the CLINGER (fits CLING / BOING BOMBS)
- Waits on the ceiling, drops when a target passes under (spherecast 2.15 wide, 20 down); clings to the head, 10 dmg a
  tick; a target can shake it (stun) off. Ground speed ramps +1.5/s to 5.2; **stuck > 4 s** (no velocity) → re-route.

### Kidnapper Fox: the AMBUSH GRAB (fits STRETCH GRAB)
- Hides in a spot with cover, "spotted meter" (> 0.9 and < 12 away = flee to a new spot); stares at a player
  0.55-4 s before acting; tongue grab, drags the player back to its hiding spot; growls 40-50 % of the time (tells).

### Old Bird: the SIEGE MECH (fits Titan throws)
- Alert timer 1.4 s before engaging; keeps a target 10 s out of sight; fire rate with ±variance (no metronome);
  random 0.06-0.3 s gaps between shots.

### Nutcracker: the SENTRY (fits the Pincer line-holder)
- Patrols at 5.5; every 6-15 s (40 % chance, or always if someone is within 27) it stops and does an INSPECTION TURN
  (scans with its head); in combat 7; forgets after 12 s unseen.

## 3. The patterns that make LC creatures feel alive (and that our old AI lacked)
1. **A meter, not a switch.** Suspicion, annoyance, stealth, fear, fightTimer: everything fills and drains over time, so
   behaviour builds up and the player can see it coming. Our old AI flipped Wander→Chase the instant something was in range.
2. **A tell before every commitment.** Dog howl (0.7 s stop), hawk display, lizard stomp/puff, fox stare, keeper stop-and-look.
3. **Attacks come in bursts with backing off** (hawk 4 s fight → -7 fightTimer). Nobody face-hugs forever.
4. **Courage depends on friends.** Hawks subtract their group size from fear; outnumbered = careful, outnumbering = bold.
5. **Imperfect information.** Guesses (random point near the noise), memory that fades (1 s / 3 s / 5 s), search routines.
6. **Speed has inertia.** Ramps (x1.3 per tick, +1/s), charge acceleration that falls with speed, decelerating lunges.
7. **Per-creature randomness inside fixed ranges.** Timers rolled once per state entry (25-70 s, 15-30 s, 3-12 s), voice
   pitch per creature, ±variance on fire rates. Random, but each creature is consistent within a state.
8. **Slow brain, smooth body.** 5 Hz decisions, every-frame motion, client smoothing (0.22 s): cheap AND not twitchy.
9. **Commitment.** Keeper won't switch target for 2 s; hawks keep a fight if a groupmate is in it.
10. **Cornered = fights.** The lizard only attacks after it can't avoid you: fleeing has a floor.
