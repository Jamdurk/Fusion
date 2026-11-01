# How we build a hub biome (method card, 31 Oct 2026; proven on the Moonwood Forest + the Goo Marsh)

Read with `00-CHECKPOINT.md`, `LESSONS.md` (all of it, esp. the 30 + 31 Oct sections), and the two worked examples:
`design\map-review\scar-and-moonwood-log.md` and `design\map-review\goo-marsh\` (SPEC.md, every audit, asset-ids.md).

## James's standing rules (non-negotiable)
- **SPAM reference images. Egregiously.** James (30 Oct): "exhaust" ChatGPT, "heaps of reference images and generate to
  really make sure effects, textures is good, you work best with those". Before building ANY model, material or effect,
  get a ChatGPT image of it. If a piece is unclear, ask for another image. Re-prompt any image that misses the look.
  Minimum per biome (Goo Marsh needed all of these, more is better): master look (already exists per biome),
  hero sheet, ORTHOGRAPHIC modelling sheet with size bars in studs (front / side / from below), materials close-up sheet
  (6 panels + hex colours + roughness per panel), top-down layout plan, effects sheet (motion arrows, phone-calm), and
  extra close-ups for every special piece (landmark, nest, resource node, effects).
- **Audit everything with ChatGPT until GO**: the spec, the Blender kit (renders), the Studio placement (player-height
  shots), and every fix. Rebut with evidence when it is wrong (lesson 15 kept our rocks mid-grey). Save every verdict.
- Nothing "Robloxy": real modelled detail + baked PBR textures, no plain Neon blobs, no shiny plastic.
- Plain kid words; no people in uploads; uploads only of game meshes/textures; no publishing unless James asks;
  mute Studio when testing; never Ctrl+Shift+S (AMD hotkey: save via File menu / Ctrl+S); stop local servers right after
  use; no parallel agent fleets; short answers in plain words; realistic time estimates.
- **Keep James's display on** during Studio work (monitor off = captures time out + new textures never appear).

## ChatGPT (James's Chrome)
- Claude in Chrome: `list_connected_browsers`, select deviceId 204741d1-9fa2-4895-93eb-79f77a32baa3 ("Browser 1").
  Open your OWN tab (tabs_context_mcp createIfEmpty) and close it at the end. Chat: "Create Master Map Reference"
  (https://chatgpt.com/c/6ae4362e-ae10-83ec-97ab-6888511dcbbe) holds all hub refs + audits; Thinking model.
- Messages: start "Claude here.", one paragraph, no tildes (they become strikethrough). Click the composer (~560,496 at
  0.5-scale screenshot coords x2) then `type`, then key Return. If typing times out, screenshot: it usually sent.
- Attach: `find` "Attach files" -> `file_upload` (files must live in the session scratchpad, so copy them there first),
  wait ~6 s, then type.
- Wait: poll `button[aria-label="Stop"]`; images: `[...document.querySelectorAll('main img')].filter(i=>i.naturalWidth>500)`
  last one -> fetch blob -> `a.download` -> it lands in C:\Users\AFish\Downloads -> move into `design\concepts\hub\`.
  Long replies: Blob of `main.innerText` sliced from the last "ChatGPT said:" -> download -> move into the audit folder.
- Look at every image critically against the master look BEFORE building; re-prompt in words what is wrong.

## Pipeline (copy the Goo Marsh scripts and adapt)
1. Spec (`design\map-review\<biome>\SPEC.md`): pieces, sizes from the ortho sheet, tris, how each is modelled +
   textured, layout counts, effects, budgets -> ChatGPT GO. Budgets that passed: secondary props 0.9-1.8k tris, landmark
   ~7.5k, ~300k placed per biome is OK with streaming, ordinary views 100-160k; <= 6 shadowless lights; particles
   1-3/s each, 25-60 visible.
2. Blender headless (5.2, `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`): `assets\blender\scripts\
   hub_goomarsh.py` (geometry, authored in Blender space, front -Y, base at origin) + `hub_goomarsh_tex.py` (Cycles bake:
   colour / roughness / tangent normal / EMIT mask, baked 2x then downscaled, one 1024 texture set per GROUP = atlas,
   metalness 0) + `hub_goomarsh_preview.py` (ortho + eye-level renders, contact sheet with ffmpeg) + `_fx.py` (particle
   textures) + `_mask.py` / `_poolfix.py` (map post-fixes). Full rebake ~9 min: run in the background.
3. Export: `node "D:\Roblox Game Venture\Flagship\Polish Kit\blender\blender.mjs" export <blend> --collection <Coll>
   --out "...\roblox-ready\<name>.glb"` (must PASS; non-manifold warnings are fine).
4. Studio (MCP studio id from list_roblox_studios; NOTE the window is now bound to the cloud test place 107899003976738):
   3D Importer driven by `scratchpad\af-import.ps1 -file <glb>` then `af-win-modal.ps1 -x 1594 -y 1170` (Import).
   Copies of these helper scripts: previous session scratchpad
   C:\Users\AFish\AppData\Local\Temp\claude\C--\52a1ea9c-830c-4ac9-848e-5d1b1709b586\scratchpad\ (af-*.ps1, serve.mjs).
   Then a kit script like `src\tools\hub-goomarsh-kit.luau` (files the kit in ServerStorage.HubKit.<Biome>, clears the
   importer's WHITE MetalnessMap, sets our uploaded `_emit` masks + strength, DoubleSided on thin fins, overrides).
   Upload maps with Studio MCP `upload_image` from a tiny localhost server (`node serve.mjs <dir> 8766`, stop it at once).
5. Layout script like `src\tools\hub-goomarsh-place.luau`: terrain backup first (CopyRegion with Region3int16 voxel
   coords), raycast-seat everything, keep 18-wide routes clear, sightlines from the 4 nearest plots, re-seat flat props
   AFTER any terrain edit. Effects script like `hub-goomarsh-fx.luau`. (`loadstring` works in the MCP for big scripts.)
6. Shots at player height (eye = ground + ~5) with `screen_capture` (it times out often: retry one at a time, or set
   workspace.CurrentCamera.CFrame and grab the window). Sheet -> ChatGPT audit -> fix -> repeat to GO.
7. Back up the .rbxl first; save (Ctrl+S via `af-save.ps1`, or File menu); BUILD-LOG row, 00-CHECKPOINT rewrite
   (<= 3 KB), LESSONS for new gotchas, memory; before/after image for James (SendUserFile).

## Gotchas that cost time on the Goo Marsh (details in LESSONS.md 31 Oct)
- Roblox culls back faces (Blender doesn't): wind tubes outward, DoubleSided for fins.
- Metaball surface = 0.57 x radius (use x1.75); tunnels by boolean, not negative metaballs.
- Smooth terrain rounds to 4-stud voxels; Read/WriteVoxels shifts the ground: re-seat afterwards.
- An uploaded map can never load (renders flat dark grey, a dead NORMAL map alone does it): diagnose by swapping maps
  on a test clone; fix with a fresh upload (change a pixel).
- AO "inside" thickness needs normalising or everything reads thin/pale. Emissive is multiplied by albedo: keep glow on
  edges / cores, not whole surfaces (ChatGPT's pool blocker).
- From below views of giant props: no player can get them; push back.
