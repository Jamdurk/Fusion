# Hand-over: mining done, tycoon planned (1 Nov 2026 17:45, for a fresh session)

James's game Alien Fusion: Roblox moon tycoon + alien army battles. Usage is tight: work lean, no subagent fan-out,
short plain-word updates, he says "percent" for progress. James does the in-game testing (install + compile-check,
don't run his tests for him unless asked). Audit everything with ChatGPT (Thinking, "Roblox Development Depth" chat,
Claude-in-Chrome device 204741d1) until GO; reference images before anything visual.

## WHERE THINGS ARE (changed today)
- Work in **`C:\Users\AFish\OneDrive\Desktop\Alien Fusion`** = James's GitHub copy (github.com/Jamdurk/fusion); Studio has
  `AlienFusion-map.rbxl` open FROM HERE. Mirror changed files to `D:\Roblox Game Venture\Games\Alien Fusion` at the end.
  Nothing is committed to git (James's call). `studio-sync\` = his sync export, don't hand-edit.
- Save: this Studio has NO Ctrl+S for Save to File. `tools\af-save.ps1 -title "AlienFusion-map" -x 28 -y 50 -x2 76 -y2 358`
  (window with a title bar; maximised = `-x 20 -y 12 -x2 66 -y2 320`; unsure: `-x 28 -y 50 -nosave` and look at
  `shots\<shot>.png`). ALWAYS check the .rbxl file time after. Last save 16:55.
- Install scripts: `node "D:/Roblox Game Venture/Flagship/Kit/tools/kit-serve.mjs" "C:/Users/AFish/OneDrive/Desktop/Alien Fusion" 48734`
  in the background, HttpService:GetAsync("http://127.0.0.1:48734/src/<file>") -> set .Source, loadstring() compile
  check, stop the server straight after. Check James isn't in Play first (get_studio_state).
- Read first: `00-CHECKPOINT.md`, `LESSONS.md` (1 Nov section), `design\25-TYCOON-PLAN.md`.

## MINING (built, James-tested on PC; not phone-tested)
Spec `design\economy\mining-spec-r2.txt` + feel `mining-feel-r1.txt`; files `src\ReplicatedStorage.AlienFusion.MiningConfig.module.luau`,
`src\ServerScriptService.MiningService.server.luau`, `src\StarterPlayer.StarterPlayerScripts.MiningClient.client.luau`,
setup `src\tools\mining-setup.luau` (re-runnable; plot corner, tags, cluster sockets, 5 picks from parts).
- Moon Rock = rocks on YOUR plot (Plot1.Mining: SmallRock1-3, BigRock, GooPocket, 2 empty Dense sockets). DNA = biomes:
  16 veins, 6 rotating clusters per biome (12 sockets, 4 min), 8 Moonwood pods (4 cyan / 4 amber).
- Tap / click = ONE swing, hold = repeat, 0.45 s; HP x1.5 vs r2 (small 8, big 15, vein 42 ...); picks 1/2/3/4/6 dmg.
  Client plays swing + hit + BREAK at once (predicted), server validates (due-time clock, range 12 to the hitbox
  surface, 3-ray LOS incl. terrain, plot OwnerUserId) and pays. Swing pose works on Motor6D AND AnimationConstraint
  rigs (R15 + R6). Pick welded to the right hand, all parts welded.
- MOVE TEST menu (AlienAnimator client) has a PICKAXE section; needs `MiningConfig.TEST_PICKS = true` (TURN OFF at launch).
- Meteorite: James said leave it out. Not built: pick shop pads, Dense pad, hiding the pick in battle, saving.

## TYCOON (planned, ChatGPT r2 GO for slice 1, nothing built)
`design\25-TYCOON-PLAN.md` (summary) from `economy\tycoon-spec-r1.txt` (real web research, 23 sources) + `r2`.
Drill 20 -> Incubator 30 (both egg chambers, repeat hatching) -> T2 40 -> Rig 12 60 -> T3 80 -> Rig 16 110 -> Rig 24 180
-> Rig 32 280 (800 Rock critical path); factory pads optional; plot layout with footprints; hatch reveal card anywhere.

## NEXT (in order)
1. James phone-tests mining (fix what he finds).
2. Tycoon slice 1: reference images (drill, incubator with 2 chambers, purchase pad, hatch card) -> ChatGPT GO ->
   build Drill pad + Incubator pad + starter 12 Goo + eggs (12 DNA, 12 s, repeat) + hatch reveal, session-only, on plot 1
   -> Studio shots -> ChatGPT audit -> save -> docs. Hatching must add a real alien to the army (combat code lives in
   `src-aitest\`, not yet in the map place).
3. Slice 2: session-locked saving, then offline earnings.
