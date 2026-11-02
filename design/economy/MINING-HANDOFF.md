# Mining system: hand-over (1 Nov 2026, for a fresh session)

James (1 Nov): build the PICKAXE system + how deposits spawn (rock, Goo DNA, Crystal DNA, meteorites) + the frequency,
"that whole system first", designed and audited with ChatGPT. Usage is tight ($50 of credits): work lean.
Read first: `00-CHECKPOINT.md`, `design\24-MATERIALS-AND-TYCOON.md` (LOCKED: Moon Rock / Goo DNA / Crystal DNA, one
incubator with two eggs, hand mining + slow machines, rare eggs = looks only), `LESSONS.md` (31 Oct + 1 Nov sections).

## State
- ChatGPT was ASKED for the MINING SYSTEM SPEC (pickaxe feel on phone + PC, 5 tiers, hits per node, deposit types + HP
  + yield + respawn, plot rock spawning, biome nodes per server, meteorite events, rates at min 1 / 10 / 60 vs the
  hatch targets 16 owned in 5-8 min / 32 in 20-30, anti-abuse, streaming, what to build first). Its ANSWER is the
  last reply in the "Roblox Development Depth" chat (https://chatgpt.com/c/6ae34b2c-7d90-83ec-8279-31454633801a),
  NOT yet saved: save it as `design\economy\mining-spec-r1.txt`, audit it (push back with numbers), then build.
- Studio: `AlienFusion-map.rbxl` is open (saved 31 Oct 15:18). Nothing for mining exists in the place yet.
- Placed resource props already in the map: Goo Marsh 8 veins (workspace.Hub.GooMarsh.Veins), Crystal Canyon 8 veins
  (CrystalCanyon.Veins, attr Resource="CrunchDNA", CanQuery on), Moonwood 8 DNA pod clusters (attr DNA="Moonwood").
  Plot 1 = lane 1, centre r 380 at 22.5 deg (85 x 95, faces the crater).
- Tools: ChatGPT via Claude-in-Chrome device 204741d1 (if not connected: Start-Process chrome, wait ~25 s). Big Luau via
  `serve2.mjs` + HttpService GetAsync + loadstring; save via `af-save.ps1 -title "AlienFusion-map"` (Ctrl+S on the
  local file); stop servers after; back up the .rbxl to `backups\` before changes; James does in-game testing.

## Next steps
1. Save + audit ChatGPT's mining spec to GO. 2. Reference images (pickaxe tiers, rock node, hit / break effects) before
anything visual. 3. Build: server MiningService + node spawner, pickaxe Tool + phone input, HUD counters (+Rock / +DNA
pops), on plot 1 + the existing veins. 4. Studio shots -> ChatGPT audit -> save -> docs + memory.
