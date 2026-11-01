# Impact scar + Moonwood Forest: build log (30 Oct 2026)

## Impact scar (crater)
Reference `design\concepts\hub\K-impact-scar-chatgpt.png`. Script `src\tools\hub-crater-scar.luau` (v1) + live fixes.
- Terrain paint: Slate (MaterialService has no Slate override; colour 56,53,60) in a noisy 120 x 100 ellipse with a
  dithered 8-12 stud edge, 7 broken tapering ejecta streaks (gaps, ~3-4 -> 0.5 wide) to ~125 studs, debris at the ends.
  Gotcha: the first paint looked missing because the burnt zone sat under the big shell: check a top-down material map
  before assuming paint failed. Basalt is overridden by MoonBasalt (pale) so it can't be the dark scar material.
- 3 radial cracks 0.5-0.7 wide with cyan / violet Neon accents; 2 detached plates (12 x 6 @30 deg, 8 x 5 @45 deg)
  with inset cyan fractures; 22 debris rocks; 3 petals offset.
- ChatGPT scar audit r1: GO WITH CHANGES (match 5.5, "crashed here" 7, perf 9.5); its 3 fixes then applied.

## Moonwood Forest (north)
References C (eye level), C2 (tree sheet), C3 (layout). Kit `assets\blender\scripts\hub_moonwood.py` ->
`roblox-ready\hub-moonwood.obj` (17 pieces: 3 trees + elder x Bark/Canopy/Pods, pod cluster Cups/Glow/Core, moss,
spore). Layout `src\tools\hub-moonwood-place.luau` (kit filed in ServerStorage.HubKit.Moonwood; forest in
workspace.Hub.MoonwoodForest).
- 103 trees (51 tall, 4 wide, 48 low) + the ELDER (own mesh, x2.4), 7 crystal DNA pod clusters (3 clearings r17 +
  4 at the elder r32 clearing), ~98 moss, ~22 boulders, 8 spores, a 14-wide winding path painted Sand. ~138k tris
  placed (ChatGPT: OK with instancing + streaming + LOD; target per view 45-70k at eye level).
- Lighting (map-wide): OutdoorAmbient 72,76,90 -> 118,112,150, Ambient 21,24,32 -> 46,44,64 (old values saved in
  Lighting attribute PreForestLighting).
| Round | ChatGPT | Scores (C3 / C / C2 / explore / phone) |
|---|---|---|
| r1 | GO WITH CHANGES: too dark, blocky canopies, neon-blob pods, path + clearings, banding | 7 / 4.5 / 6 / 5.5 / 8.5 |
| r2 | **GO, "production-viable"**; last polish: elder landmark, canopy/bark colours, ground near path + clearings (all applied after) | 8 / 6.5 / 7.5 / 7 / 8.5 |
Saved in `AlienFusion-map.rbxl` 19:45 (backup `backups\AlienFusion-map.pre-moonwood-30Oct.rbxl`).
Not done: spore drift animation, phone test, mining / nest gameplay hooks (pods carry attribute DNA = "Moonwood").

## 30 Oct ~19:50-21:00: MOONWOOD TEXTURES (James: trees "very Robloxy"; + "make sure the bark texture is also decent")
Reference C4 (`design\concepts\hub\C4-moonwood-materials-chatgpt.png`). Work + audits in `design\map-review\moonwood-tex\`.
- Pipeline: `hub_moonwood.py` + `hub_moonwood_tex.py` (+ `hub_leaftile.py`) -> `assets\blender\hub\moonwood_tex.blend`
  (collection MoonwoodTex) -> `blender.mjs export` -> `roblox-ready\hub-moonwood-tex.glb` -> 3D Importer -> run
  `src\tools\hub-moonwood-tex-swap.luau` (files the kit, clears the importer's metal maps, rebuilds all 104 trees from
  their bark). Textures in `assets\textures\hub\mw*_{color,normal,rough}.png` (1024).
- Canopy: a MODELLED shingled-leaf tile (node shaders only gave dots/cobbles), box-projected + baked; albedo = ChatGPT
  targets. Rim: curved flat leaf blades (16 tris, own gradient via vertex float leafT). Bark: 5 twisting rope strands,
  grain along the strands, 1024. Pods: pale husk + stem (Pods) + Neon drop (PodGlow).
- Found: the importer gives every SurfaceAppearance a pure WHITE MetalnessMap (= full metal, renders dark indigo);
  the swap script clears it. One mesh upload (low canopy) came through broken; a re-import fixed it.
- Lighting.Ambient 46,44,64 -> 104,102,120 (under dense canopy only Ambient lights the trunks). Old value in the
  Lighting attribute PreBarkAmbient. Map-wide, only affects covered spots.
- ChatGPT r1 GO WITH CHANGES (colour 3.5, fringe 3, bark 5) -> r2 **GO WITH CHANGES, approved as the production
  material set** (leaf 8 / 7.5, colour 8, fringe 7.5, bark 7.5 "decent now", overall 8). r2 fixes 1 (per-tree canopy
  tint) + 3 (dimmer violet core) applied; fix 2 (weighted normals on the canopy lobes, needs a re-bake) NOT done.
- Map saved 21:00 (backup `backups\AlienFusion-map.pre-moonwood-tex-30Oct.rbxl`). Flat OBJ kit kept in
  ServerStorage.HubKit.MoonwoodFlat for rollback.
- 30 Oct ~21:15: r2 fix 2 (soften canopy faceting) BUILT in Blender: canopies bake colour / rough / normal FROM a
  Catmull-Clark level-2 copy of the lobes (blades bake from an unsubdivided copy, else they shrink and go black);
  tris unchanged. GLB exported. NOT yet imported: the AlienFusion-map Studio was found in Play (not started by Claude
  or the Break Physics session; left for James). Swap script now also applies the r2 per-tree tint + pod colours.
