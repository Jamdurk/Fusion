# Alien Fusion AI: where everything came from

Rule (handover §5b): code is copied only from open-licensed projects, with the licence noted here; behaviour + numbers
are lifted from games and rebuilt in our own code.

## Code copied (open licence)
| What | From | Licence | Where it lives here | Changes |
|---|---|---|---|---|
| ORCA local avoidance (linear programs 1-3 + agent ORCA lines) | [snape/RVO2](https://github.com/snape/RVO2) `src/Agent.cc`, commit 6b4eb00 (24 Oct 2026), University of North Carolina | Apache 2.0 (notice kept in the file header) | `design/ai/orca.mjs` (JS port; Luau port later) | agents only (no polygon obstacles: boulders are static agents); per-pair `share` instead of a fixed 0.5 so small units give way to big ones |
| Pathfinding wrapper (for Roblox, not used in the sim) | [00xima/SimplePath](https://github.com/00xima/SimplePath) (author grayzcale) `src/SimplePath.lua` | MIT (c) 2023 grayzcale | not copied yet; candidate for the Roblox build (PathfindingService when the straight line is blocked) | |

The sim's grid A* (`design/ai/nav.mjs`) and everything else in `design/ai/` is our own code.

## Behaviour + numbers lifted (rebuilt fresh)
| Source | How we read it | Used for |
|---|---|---|
| **Lethal Company** creature AI (Baboon Hawk, Eyeless Dog, Thumper, Spore Lizard, Hoarding Bug, Forest Keeper, Snare Flea, Kidnapper Fox, Old Bird, Nutcracker, Coil-Head) | decompiled from James's own install (build 21 Apr 2026) with ilspycmd 9.1 (MIT); James: Zeekers (the creator) said using it is fine, as modders do; James: "download code, pull code, anything you need". Notes: `research-lc-code.md`. The decompiled C# stays outside the repo | the 5 Hz brain, meters (fear / annoyance / suspicion), tells before commitment, burst-and-back-off, courage from group size, speed ramps, per-creature random timers, commitment, cornered-fights |
| StarCraft 2 / RTS unit AI (surround, spread vs splash, auto-acquire, overkill spreading) | ChatGPT Deep Research (`research-deep.md`) + common RTS knowledge | target scoring, slots, marine-split spacing, attack of opportunity |
| Dave Mark's Infinite Axis utility AI | Deep Research | target score = product of considerations (prey value x distance curve x crowding x facing x commitment) |
| Our kit's EntityAI (Brainrot Boss Army) | `Flagship\Kit\src\ServerScriptService.Server.Kit.EntityAI.lua` | the scheduler, mover rig, attack runner and commitment rule we keep in Roblox (`11-ALIEN-AI.md` §7) |
