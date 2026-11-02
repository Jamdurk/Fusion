# Alien Fusion: resume snapshot (1 Nov 2026 16:05, Claude)

Moon TYCOON + merge battles. Rules `DECISIONS.md`, history `BUILD-LOG.md`, **read `LESSONS.md` first**. Previous snapshot
(map / conquest / throne detail): `history\00-CHECKPOINT.2026-11-01-pre-mining.md`.

## WORKING COPY (James, 1 Nov)
`C:\Users\AFish\OneDrive\Desktop\Alien Fusion` = the GitHub copy (github.com/Jamdurk/fusion) and the place Studio has
open. Work + save HERE; `D:\Roblox Game Venture\Games\Alien Fusion` is a mirror (copied back at the end of a session).
`studio-sync\` = James's sync export of the Studio scripts (don't hand-edit).

## VERIFIED (1 Nov 15:56)
- `AlienFusion-map.rbxl` saved 16:55 (3,796,336 B) via File > Save to File (this Studio has NO Ctrl+S for it):
  `tools\af-save.ps1 -title "AlienFusion-map" -x 28 -y 50 -x2 76 -y2 358` (window with a title bar; maximised =
  `-x 20 -y 12 -x2 66 -y2 320`; unsure: `-x 28 -y 50 -nosave` + look at the shot). Check the file time. Backup before mining:
  `D:\...\backups\AlienFusion-map.pre-mining-1Nov.rbxl`. NOT published.
- **MINING built** (ChatGPT spec r2 GO, build audit GO WITH 2 FIXES -> both fixed + tested). Files:
  `src\ReplicatedStorage.AlienFusion.MiningConfig.module.luau` (all numbers), `src\ServerScriptService.MiningService.server.luau`,
  `src\StarterPlayer.StarterPlayerScripts.MiningClient.client.luau`, setup `src\tools\mining-setup.luau` (re-runnable).
  Spec `design\economy\mining-spec-r2.txt`, audit `mining-build-audit-r1.txt`, refs `design\concepts\mining\`.
  - Moon Rock on YOUR plot (Plot1.Mining: SmallRock1-3, BigRock, GooPocket, 2 empty Dense sockets); DNA in the biomes:
    16 veins + 6 rotating clusters per biome (12 sockets) + 8 Moonwood pods (4 cyan / 4 amber). 5 picks T1-T5.
  - Server-timed in Play: small 3.00 s, big 6.50 s (20 taps/s = no speed-up), T2 Goo vein 9.31 s, empty refused,
    other owner's plot refused (`Plot1` attr OwnerUserId), terrain wall blocks.

## NOT VERIFIED / OPEN
- Hit / break effects, auto-walk, HUD on a real phone (James tests). Cluster 4-min rotation live. 5-minute rate run
  (targets: T1 plot 50-75 rock/min, T1 biome 12-18 DNA/min). Two-player independence test.
- Mining feel r3 (16:39): tap = one swing, hold = repeat, 0.45 s, HP x1.5; swing pose works on any rig. MOVE TEST
  menu PICKAXE section (T1-T5) needs `MiningConfig.TEST_PICKS = true`; TURN OFF at launch.
- NOT built: meteorite (James: leave it), pickaxe shop pads, Dense Rock pad, hiding the pick in battle, saving currency.
- Still from before: Fort 1 gameplay, throne combat, Lander Ruins greybox, phone perf of the canyon.

## NEXT
Fresh session: read `design\TYCOON-HANDOFF.md` first. James phone-tests mining -> tycoon slice 1 (plan
`design\25-TYCOON-PLAN.md`, ChatGPT r2 GO: Drill pad 20, Incubator pad 30 with both egg chambers + repeat hatching +
hatch reveal card, starter 12 Goo; session-only) -> slice 2 saving + offline.
