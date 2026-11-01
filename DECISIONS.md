# Alien Fusion: decisions (James's rules + approvals)

- 27 Oct 2026: build the alien army idea as a PvP game. Core twist = REVERSIBLE FUSE / SPLIT of a fixed army
  (research: `..\..\Research\alien-army-tycoon-2026-10-27.md`). Prototype = 1v1 PvP arena, no tycoon/planets yet.
- 27 Oct: FIRST PART = the map itself + two alien types (Claude + ChatGPT decide the types). "Very Blender heavy":
  map terrain, textures and environment + alien models made in Blender, in depth. Use our Lighting Kit.
  James: "Go ahead. I'll talk to you once this whole part is done." = approval to import these Blender meshes /
  textures into Studio (that uploads them to his account). Rocks, terrain, aliens only; no people.
- Working title "Alien Fusion" (not final; James names the game).
- 27 Oct (night): **Colossus v4 replaces the Colossus** (James: "Colossus V4 definitely replaces it"). Template
  `ServerStorage.Aliens.Forms.CrunchF4` = the v4 build; the v2 one is `_v1.CrunchF4_v2`.
- 27 Oct (night): **F4 speed 12 → 8** (James, on "keep the speed + longer legs, or slow big forms down": "the bigger
  forms naturally need to be a bit [slower] for sure. That's fine"). F3 and below unchanged for now; each form's
  speed vs leg length is checked in its Phase 1 rebuild (`design\08-REBUILD-PLAN.md`).
- 27 Oct (night): **rebuild every form in PHASES** (models + movement + sounds first; attacks "devised once we get to
  that stage"), several reference images per form + close-ups. Plan `design\08-REBUILD-PLAN.md`.
- 27 Oct (night): the screen recorder is NOT free (another session); no clips until James says.
- 28 Oct: ChatGPT approves each form's hero concept overnight (James: "if the hero shot works best for you, then
  yeah, just do it that way"); Phase 1 starts ONLY on James's go (he's making a video: "I'll let you know").
- 28 Oct ~12:40 AM: **Phase 1 GO** (James, going to bed: "start the animation stuff ... follow that formula"; "models
  ... using multiple references ... ChatGPT audit too ... animations for every model ... depending on the type").
- 28 Oct (night) **PENDING JAMES: F3 speed.** Measured in the rebuilds: at the rules' 16 studs/s the F3s' legs
  (Ram 3.0 studs, Brute 2.1 + 3.1-stud arms) can only carry a short stride, so they land every 0.24 s (Ram) /
  0.17 s (Brute). ChatGPT's movement audits (both): "too frantic for a heavy" form → walk **12.5**, run **20**. Kept
  16 for now (rules); the gaits are tuned to fit either (they read stride from studs walked).
- 28 Oct (day): **Power graph v3 built** (James: "start on the power scaling. Each creature should have three abilities ...
  audit with ChatGPT ... deep research"). `design\09-POWER-GRAPH.md` + `design\power\`. ChatGPT r2: GO WITH CHANGES
  "nearly ready" (all applied) → GO for playtesting after a Studio fusion/split test. **PENDING JAMES:** (1) F3 base stats
  650/48 → 560/44 (rules lock §3 change; ChatGPT approved, deep research flagged the same); (2) one ORDER button per form
  (passive + auto + 1 Order) as the control scheme; (3) swap any of the 24 abilities he'd design differently.
- 28 Oct (evening): **AI from proven games.** James: "draw from games like Lethal Company"; "I give you explicit permission
  to use [Lethal Company] as I spoke to Zeekers the creator and he said it was fine due to modders already using it"
  (verbal; keep anything written with the docs); "download code, pull code, anything you need". → LC's creature AI was
  read from his own install and its behaviour + numbers lifted; all our code is written fresh. Design `design\11-ALIEN-AI.md`.
- 28 Oct (night): **Titan batch 2 APPROVED** ("I like it"). NOTE TO FIX LATER: the GOO TSUNAMI's actual wave (the crest/
  sheet goo, not the warning) "looks very Robloxy" (squashed-sphere lobes) -> rebuild it as a proper wave asset later.
  **Rule for every later batch:** make REFERENCE IMAGES for each attack and for what it produces (the effects: projectiles,
  puddles, waves, shields...), like the model reference packs, and build the attacks + effects to match them.
  Next: batch 3 = the BRUTE (SquishF3v5) and the TWIN (SquishF2v5), from the power graph (design\09, kits.mjs).
- 30 Oct: **the game = a moon TYCOON + merge battles** (mechanics `design\21-GAME-MECHANICS.md` v4.2, ChatGPT r5 GO).
- 30 Oct (eve): James: the map is "a bit bland"; wants "a lunar forest and lunar themed areas"; "use ChatGPT reference
  images for everything". **HUB MASTER LOOK = reference image A** (`design\concepts\hub\A-master-map-chatgpt.png`;
  James: "I really liked this iteration of the map"): the moon taken over by aliens, crater landmark with the hanging
  reactor ring, 8 plots round it, lunar forest N / goo marsh W / crystal canyon E / lander ruins S. Every hub area is
  built to match it (pack A-J in `design\concepts\hub\`, prompts `design\map-review\reference-prompts.md`).
- 30 Oct (eve): the Moonwood trees looked "very Robloxy" -> real textures + a leaf fringe ("do the texture now, because I
  want to see how it looks first"; "make sure the bark texture is also decent"). Approved: soften the canopy shading.
- 30 Oct (~21:40): **map structure = ChatGPT option C** ("Okay yes to ChatGPT's recommendation"): ONE shared moon with all
  biomes + the 8 bases; NO portals to biomes; big battles + future moons stay separate places.
- 30 Oct (~22:10): **open space round the bases** (standing rule for the hub): "I don't want ... the biomes just straight
  up against the tycoon buildings ... some space all around the tycoon buildings to run ... to get to the biomes that are
  quite large and against the walls." -> biomes hug the cliff walls, an open plain separates them from the plots.
- 30 Oct (~22:20): next biome asked; Claude answered Goo Marsh (or the G2 showcase plot first). James to choose.
