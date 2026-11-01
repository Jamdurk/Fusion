# Brief for GPT-6 Astra (Codex): Alien Fusion, first part of the next build (30 Oct 2026, written by Claude)

James asked you to do the FIRST part of the next build; Claude continues from your hand-back (Studio import, placing,
in-game audit, save). Your usage is limited: do ONLY the task James named, in the order below, and stop at the hand-back.
If you run low, stop cleanly and write `HANDBACK.md` saying exactly where you stopped.

## Read first (short)
1. `D:\Roblox Game Venture\AGENTS.md`: boundaries (no uploads to Roblox, no publishing, never open the private folders,
   no secrets), Blender rules.
2. `Games\Alien Fusion\00-CHECKPOINT.md` (where the game is) and `LESSONS.md` (models / textures / terrain lessons).
3. `Games\Alien Fusion\design\map-review\map-size-audit.md` (the hub map; read the r4 section at the END: current numbers).
4. `Flagship\Polish Kit\cards\blender.md` + `Flagship\Polish Kit\blender\README.md` (the export tool).

## Where you may write
- `Games\Alien Fusion\plans\astra\<task>\` (spec, prompts, renders, audits, HANDBACK.md);
- NEW scripts in `Games\Alien Fusion\assets\blender\scripts\` (new file names only, e.g. `hub_marsh.py`);
- NEW .blend files in `assets\blender\hub\`, textures in `assets\textures\hub\<task>\`, exports in `roblox-ready\`.
- Do NOT edit existing files, do NOT touch Roblox Studio (Claude's job: two agents in one Studio collide), do NOT upload.
  The live Blender connector (MCP) is not needed: run Blender headless.

## Use ChatGPT (James's ChatGPT, the Thinking model) the way this project always does
- **Reference images FIRST, then build to match them.** James's standing rule; primitive shapes "look Robloxy".
  Make the images yourself if you can; otherwise write the prompts to `<task>\prompts.md` for James to paste into ChatGPT
  and save the images to `<task>\refs\`. Existing refs to reuse: `design\concepts\hub\` (listed per task below).
- **Audit every stage with ChatGPT until it says GO** (spec, then renders vs references). Paste each verdict into
  `<task>\audits\` with the round number. Fix what it asks; argue back with evidence when it is wrong.

## Look + quality rules (from James)
- Not "Robloxy": real modelled detail + baked PBR textures (colour, normal, roughness; metalness 0; max 1024 px).
  Smooth shading on organic shapes. Stylised, chunky, readable on a phone. Kid-safe (players 9-14). No people.
- Palette: grey moon base; cyan = Squish; amber = Crunch; violet accents. Glow sparingly (Neon cores only), and never
  brighter than the aliens. Avoid big transparent surfaces (phone cost): fake translucency with painted colour.
- Budgets: 5-7 unique pieces per kit, reused many times; <= 2,000 tris per piece (a landmark <= 6,000); policy max
  20,000 per mesh. Whole biome placed ~150-250k tris.
- Plain words on anything players read (BUY, START, DNA).

## The proven pipeline (copy it, don't reinvent)
- Example scripts: `assets\blender\scripts\hub_moonwood.py` (meshes) + `hub_moonwood_tex.py` (UVs + Cycles bake) +
  `hub_leaftile.py` (a modelled pattern tile rendered to colour + height, then box-projected and baked).
- Author meshes in ROBLOX space (x right, y up, z), 1 unit = 1 stud, each piece's base at its origin. Before the GLB,
  convert to Blender space with R2B = ((-1,0,0),(0,0,1),(0,1,0)) (see hub_moonwood_tex.py). Bake canopy-like lumpy
  shapes FROM a subdivided copy (smooth light), but thin parts (blades, stalks) from an unsubdivided copy (they shrink).
  Colour ramps: write sRGB targets, convert to linear in the script.
- Save a .blend with ONE collection, then: `node "Flagship\Polish Kit\blender\blender.mjs" export <blend> --collection
  <Name> --out "Games\Alien Fusion\roblox-ready\<name>.glb"`. It must print PASS (warnings about non-manifold are OK).
- Render previews in Blender (Cycles, grey-violet sky, sun) next to the reference for the ChatGPT audit.

## Hand-back (`<task>\HANDBACK.md`)
Files made; tris per piece; texture list; preview renders; every ChatGPT verdict; a PLACEMENT list in hub coordinates
(Roblox X, Z, rotation, scale; north = -Z) as JSON; known issues. Claude imports, places, audits in Studio, saves.

---------------------------------------------------------------------------------------------------------------------
## TASK A: the GOO MARSH kit (west biome)
- **Zone:** Roblox X -830..-490, Z -330..+330 (a 340 x 660 sunken basin, floor about y -6), against the west cliff wall;
  an open moon plain lies between it and the bases (keep it open). Terrain is done (Claude's); you make the props.
  Pool dips already in the terrain at (X, Z, radius): (-600,-120,34) (-700,40,46) (-770,-200,28) (-590,180,30)
  (-760,230,24) (-640,-260,26).
- **Refs:** `design\concepts\hub\D-goo-marsh-chatgpt.png`, `A-master-map-chatgpt.png` (master look), `I-nature-kit-chatgpt.png`.
- **Pieces (5-7):** a GIANT cyan mushroom LANDMARK (25-40 studs tall, must read from the bases ~250 studs away; goes at
  the marsh entrance near X -490, Z 0); 2 smaller mushroom variants; soft blob / goo growths; a goo pool surface that sits
  in the dips (opaque, glossy, cyan); a Squish DNA vein (cyan crystal cluster to mine); a goo NEST (where battles start).
- **Placement plan:** ~40-70 placements total, clustered with open walkways >= 14 wide, the landmark visible from Plots 1-4.
- Order: refs + spec -> ChatGPT GO -> Blender kit + bake -> renders -> ChatGPT GO -> export -> HANDBACK.

## TASK B: the SHOWCASE PLOT (one tycoon base, built properly before it is copied 8 times)
- **Plot 1:** an 85 x 95 flat pad centred at Roblox (-230, top y = 5.2, -190); the crater (shared landmark) is to its
  east at (0, 0); keep the crater side open so the reactor ring stays visible.
- **What's on it** (mechanics `design\21-GAME-MECHANICS.md` §1-§5): walk-on BUY pads (the classic tycoon square) in a set
  order; DRILLS 1-6 (mine moon rock); a REFINERY + CONVEYORS; the INCUBATOR (hatches eggs with DNA, egg wobbles; 2nd and
  3rd slots later); a DNA EXTRACTOR; a BATTLE PAD -> later LAUNCH PAD; a TROPHY HALL (pedestals for rare aliens); a few
  moon rocks to mine by hand. Stage 1 (start) vs fully built.
- **Refs:** `design\concepts\hub\G-plot-start-vs-built-chatgpt.png`, `G2-plot-layout-chatgpt.png`, `H-machines-sheet-chatgpt.png`.
- **Deliver:** a layout spec (every pad + machine with its footprint and position on the pad, walk lanes >= 12 studs,
  the buy order); a machine kit in Blender (drill, incubator, battle pad, buy pad, conveyor segment, extractor, trophy
  pedestal) at real scale (a player is ~5 studs tall; alien sizes in `design\03-FORMS-AND-RULES.md`).
- Order: refs + spec -> ChatGPT GO -> Blender kit + bake -> renders -> ChatGPT GO -> export -> HANDBACK.
