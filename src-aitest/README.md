# AI testing ground (`AlienFusion-AI-Testing.rbxl` only)

**v2, 29 Oct (all 8 aliens).** Fresh copy of `AlienFusion-map.rbxl` as saved 29 Oct 4:12 AM (all 7 animation batches),
plus the files below. The previous test place (Colossus + Titan only) is kept as `AlienFusion-AI-Testing.pre-29Oct.rbxl`.
**One source (29 Oct night, perf P9a):** the animator, AttacksCrunch and AttacksDrip now live ONLY in `src\` (moved from
here; the AI additions are inert for non-AI models). This folder holds only the test harness (server, Brain, menu). The
AI-test place installs those three plus `src\`. Pre-merge copies: `backups\pre-P9a-29Oct\`.

| In the place | File here | What |
|---|---|---|
| `ServerScriptService.AITest` (Script) | `ServerScriptService.AITest.server.luau` | combat for all 8 forms: `KITS` = passive / auto / ORDER per form (numbers `design\power\kits.mjs`, hit marks from the attack modules); fixed 20 Hz step; HP, shields, damage reduction, slows, stuns (F4 immune, 3 s immunity), shoves (8 studs / 3 s cap); Orders shared per side + form (fires when it lands for 30 % of them, 0.06-0.3 s ripple, first one 3-9 s in); the menu's commands |
| `ServerScriptService.AITest.Brain` (ModuleScript) | `ServerScriptService.AITest.Brain.module.luau` | `design\ai\brain.mjs` + `profiles.mjs` + `orca.mjs` ported: utility target scoring (prey table, gang-up to 6, spread fire, guard bonus, commit / min hold), fear + evade behind a protector, 24-sector surround slots, Pincer guard post, Titan swarmed-slide, Ram speed build-up, ORCA steering, stuck detour. NOT ported: `nav.mjs` (boulder pathing; the test floor is open) |
| `StarterPlayerScripts.AITestMenu` (LocalScript) | `StarterPlayer.StarterPlayerScripts.AITestMenu.client.luau` | the AI TEST menu (right side): SPAWN ON team A / B / hostile to all; **HOW MANY 1 / 3 / 6 / 12**; SPAWN per form (biggest first); ALL AI ON / OFF; HEAL ALL; CLEAR AI; scrolling unit list (team, AI on / off, X) |
| `StarterPlayerScripts.AlienAnimator` | `src\StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau` | the game's animator incl. AI mode: `setup()` builds ctx for `Mode = "ai"`; `hurtTick()` plays the server's hurt events; aimed attacks take `AiAimX/Z`; `aiWalk()` + `aiFrame()`; the RenderStepped loop sends AI units to `aiFrame` (+ the 29 Oct MOVE TEST menu-fit fix the 4:12 save didn't have) |
| `ReplicatedStorage.AlienFusion.AttacksDrip` | `src\...AttacksDrip.module.luau` | `standIn()`: an AI unit's stick target = the unit whose `AiId` = its `AiTgt` (Cling, Bombs, Chip, Roll) |
| `ReplicatedStorage.AlienFusion.AttacksCrunch` | `src\...AttacksCrunch.module.luau` | `littleOnes()` / `foes()`: an AI unit's foes = living AI units of a hostile team, its server target first (Snap, Sweep, Gore, Charge) |

## How the client stays in step (one clock)
The server sends ONE `AlienFusion.AIState` message every 0.1 s: `(states, events)`. states = `{ id, server time, x, z,
facing, speed }` per unit; events = `{ id, "atk", name, t0, aimX, aimZ, targetId, slot }` and `{ id, "hurt", t, side }`.
Each unit is drawn on its own steady clock 0.35 s behind the newest sample (the 28 Oct stutter fix), and its attacks and
hurts are played on that SAME clock. So a bite, the body it lands on, and the jump an attack carries a unit through all
line up. When an attack event comes due, the client sets `AiTgt` / `Slot` / `AiAimX/Z` on its local copy of the model,
which is where the attack modules read them. Attacks that move the whole unit (Twin Boing, Drip Boing, Bombs, Roll,
Charge) keep the server position still during the attack, then JUMP at its end (two samples 1 ms apart). The HP bar
updates 0.35 s after the hit, so it drops when the hit is seen.

## The kits (what each does by itself)
| Form | Passive | Auto | ORDER |
|---|---|---|---|
| Colossus | Slam 400, arc 120 (x2.5 Brute, stuns small 0.3) | Boulder 160 when nothing is within 6 | Sun beam 300 + burn |
| Titan | Slam 400 (x2.5 Brute) | Goo Bomb 160 + slow | Tsunami lane 300 / 60 + slow |
| Brute | Pound 55 / 1.25 s (x1.5 Pack) | Stretch Grab: a runner 2-14 off, root 0.5, 30, yank in | Chest Thump: shield 70 self / 30 friends within 8, punches 20 % faster 4 s |
| Ram | Gore 55 / 1.25 s (x1.5 Pack) | Hoof Stamp: Pack / Brute within 5: 30 + stun 0.5 | Charge at a Pack / Brute 4-26 ahead: 90 first, 20 others, knock 4 |
| Twin | Double Slap 20 (+20 on a 2nd little one) | Sticky Floor: 3+ within 5 = slow 25 % 2.5 s | Boing Slam onto the thickest crowd within 14: 20 to 3, stun Drips |
| Pincer | Snap 20 (+20 on a 2nd little one) | Claw Block: 2+ small within reach = -30 % for 3 s | Side Sweep: 2+ small ahead: 20 to 3, knock 2 |
| Drip | Cling: rides the target, 5 bites of 6; 6+ on a big one = GOOED (x1.75 / x2) | Boing out of a giant's slam / Order (up to 10 studs), else Squash (half damage) | Boing Bombs onto a big one within 12: +15, then bites |
| Pebble | Chip at the big one's foot: 8 bites of 6; 6+ = CRACKED | Curl Up under a giant's hit: -70 % 1.2 s | Roll Out at a big one 2-16 off: -30 % rolling, +20 jab |

## Known limits (test ground, not the game)
- Clings / Chips on LITTLE targets (a Drip on a Twin) deal damage, but the stick animation only has attach points on
  the 4 big forms, so it may look odd on small ones.
- A swarm on a big one: the hurt animation replays at most every 0.9 s (unless a hit is ≥ 4 % of its HP).
- The server's landing spots after Charge / Roll / Bombs are estimates (body radius, hook 5.4 ahead), so a unit may
  slide a stud or two as the attack ends.
- No boulder pathing (nav.mjs not ported): test on open ground.

**Add a new form:** add a `KITS` entry (key = its template in `ServerStorage.Aliens.Forms`, `anim` names = its
`Attacks.FOR[form]` keys, numbers from `kits.mjs`, hit times from its attack module). It shows up in the menu by itself.

**Checked at install (29 Oct, Edit mode, no Play):** all 6 scripts compile; Brain dry run in Edit: 6 Drips v 1 Titan
all picked the Titan and spread to 6 different sectors, finishing 0.0-0.5 studs off its body. In-game testing = James.

## Fixes from James's first test (29 Oct; ChatGPT robustness audit r1-r5 = ROBUST / ROBUST, GO / GO, in `design\aitest-fixes\`)
**Legs (Colossus / Ram / Brute "flick back and up" as attacks start)**
- Attack footholds were planted `st.s` studs BEHIND the unit (distance walked since spawning): `at(u) = base * (0,0,-u)`.
- `resetFeet` + FOOT HANDOFF: every foothold reset (attack start, travel on/off, walk <-> idle, leg owner change, a server
  jump >= 1.5 studs) makes each foot step from where it RENDERED last frame, low arc, `T = max(0.18, d/10)` (<= 15
  studs/s); a gap over 2x the leg's reach is a real teleport and snaps. Applied last, after attack targets / kneel.
- POSE HANDOFF: the hip-carrying bones (Root + each leg's parent chain) ease from the last rendered pose over 0.18 s.
- `st.legOwner` ("atk" / "walk"), the post-lock tail latched per attack event (`st.tailFor = cur`).
- Ram Gore: hooves step with the lunge (`A.Gore.travel`, anchored at the cast spot `gore.o`, dropped if knocked > 1.5
  off it); the body steps back 0.92-1.25 (the server never carries the gore step: that is the server-combat gate).
- Measured: foot spikes (> 0.5 in one frame, > 3x neighbours) 15 per fight -> 0-1 per fight; 103 Gore casts with 12
  knockbacks: 0 spikes, 0 stretched legs.
**Anti-cling (a Colossus walked around while Drips kept biting it)**
- Riders ride in the carrier's frame (`rideA / rideC`, turn with it, as the client draws them).
- Any carrier whose target rides its body stands (no chase) and never turns toward it; every carrier can hit its own
  rider (giant slam: `slamHits` = its wedge OR riding its body within reach; melee / cleave: contact distance).
- Per-rider watchdog (`svcFor`, `tried`, `antiCling`): shaken off (`shakeOff`: Boing to the first clear spot past the
  body, 1 s no-re-cling on that carrier) after 2 picked-and-missed hits, or after `svcAllow` = max(30 s, queue / cap x
  cycle + 2 cycles) never served. Slam picks its riders longest-unserved first. Carrier death releases its riders.
- Measured: Colossus / Titan v 2 / 12 / 32 Drips: no stalls, 0 needless shake-offs; unhittable rider always shaken off.
- Test hooks: `AITest:FireServer("flag", "AITestSlamMiss", true)` (slams deal 0), `("flag", "AITestNoDmgId", id)`;
  readouts: model attributes `ShakeOffs`, `FeetResets`.
- OPEN (release gates, not this test place): shake-off landing vs real-map walls / edges; phone 30-60 fps check; a Gore
  that misses server-side still shows its contact burst; body jumps 4-18 studs at a Charge landing / knockback (server
  jumps drawn as a snap).

## Attacks always play out (29 Oct evening; James: "AI has to commit and finish an attack"; ChatGPT design r1 UNSOUND ->
r2 SOUND WITH CHANGES; build audits in `design\aitest-fixes\commit-*.md`)
- **Server:** `BODY[kit][anim]` = when each attack's own body animation ends (from the keys). `playAnim` is the one place an
  attack begins: it REFUSES a start before the current body has finished (no id, no event), gives each attack an id
  (`atkId`) and sends it. Every start function checks `gate(u)` first. `later()` actions belong to their attack id:
  stale ones never run. Thrown attacks (`RELEASE`: Boulder / Bomb 2.55, Wave 2.10) hand their hit to the projectile at
  release (`handOver`). Only authorised interrupts cut a move short (`INTERRUPTS`: a Drip's Boing / Squash out of its
  own Cling, a Pebble's Curl out of its Chip; plus the shake-off, defeat, a carrier's death) via `interrupt()`, which
  tells the client by id. Orders are a per-unit reservation (`pendingOrder`, `runOrder`, `resolveOrder`), not a delayed
  start. Thump shields carry their cast (`shieldSrc`); `shieldEnd` says when one is gone.
- **Client:** each attack is an instance; a new attack DETACHES the old one (its own ctx, effects, event cursor) so its
  effects play to the end; a cancel ends the body and keeps only a thrown projectile (`f._t`, `f.worldAt`); events are
  handled in time order by id; hasted swings play faster (`speed`). The shield manager (`Attacks.endShield`) ends a
  shell by its cast. Thump now shells friends only (it shelled enemies too).
- **Balance (James accepted):** Colossus v 12 Drips used to end with 680-965 HP, now 126-167 (Sun = 6.2 s committed).
- **Test hooks:** `force` / `dodge` / `ghost` / `preshield` / `kill` / `arm` (probe at an exact time into an attack);
  readouts `AITestIllegalOverlaps`, `AITestStaleBlocked`, `AITestOrders_*` (workspace), `AiFxCutEarly`, `AiSkipped`,
  `AiLiveFx` (player), `AiFx` / `AiDetIds` (unit models).
