# Alien Fusion: lessons learnt (newest last)

Read before building creatures, rigs, animation or textures for this game. Each one cost real time once.

## Models
1. **One body plan scaled up is not "distinct".** James: "not distinct enough". Each form needs its own body plan,
   silhouette AND gait (hop / bounce / knuckle-walk / slide; skitter / scuttle / trot / stomp). Brief ChatGPT per form,
   with the body plan spelled out, or its concept sheets just redraw the old designs.
2. **ChatGPT image generation = the concept art.** Ask for one lineup sheet per race (4 forms, front 3/4, plain
   background, size ladder), then build from it in Blender and send renders back for a GO / NO-GO per form.
3. **Plane facet cuts go on core masses only.** Cutting after joining chopped legs and horns clean off.
4. **Check the front view as well as the 3/4 hero view.** The Ram's horns and the Colossus's fists only failed from the front.
5. **Eyes and teeth must sit IN the surface.** Loose parts placed in the air ended up floating in front of the face
   (CRUNCH eyes) or outside the lips (Titan fangs). Ray-cast onto the body and sink them in (`sink_eyes`).

## Rigs + skinning
6. **Read the REWEIGHTED count.** 3,810 Titan verts missed heat weighting, so its skin was hard 0 / 100 % borders and it
   tore while moving. Fix: `follow_surface()`: smooth the vertex groups, then every loose part copies the weights of
   the nearest body vertex.
7. **One bone driving several legs reads as a strafe.** Give every leg that should step on its own its own bone.
8. **Roblox bones can't scale.** A blink needs an eyelid shell on its own bone that swings over the eye.
9. **3D Importer gotchas:** the PrimaryPart's PivotOffset arrives turned 90 deg (reset to the feet); a "Have you imported
   this before?" tip can eat the Import click (check the workspace after every batch); a stray click can start Play
   mode (check `get_studio_state` before an Edit script).

## Animation
10. **Procedural Luau walk cycles are the cheap route** (no uploads, no Animation Editor, tune live). Phase = studs
    walked / stride. Body bob / tilt go on the Root bone, never the model pivot (that's the server's movement).
11. **Streaming: a model can arrive before its bones.** The animator saw 0 bones and never animated it (James saw the
    SQUISH units "sliding"). Fix: Atomic model streaming + re-scan until the bones exist.
12. **James watches live and records video.** Pull frames with ffmpeg into 4x4 contact sheets (scale 640, one frame
    per 1.5 s): cheap to read even from 4K.

## Textures
13. **Blender preview renders are NOT the in-game look.** Judge colours and brightness in Studio under the game's lighting.
14. **Sharpness comes from UV space + detail frequency, not just map size.** Shrink flat-colour parts (eyes, teeth,
    crystals) for the unwrap so the body gets the texels; bake at 2x and downsample; detail at three scales.
15. **Dark stone + bright glowing cracks reads black in game.** Keep the base stone mid-grey (0.17-0.40 linear).
16. **SurfaceAppearance.EmissiveMaskContent works** (bake a 4th "emit" map, upload, set it + EmissiveStrength).

## Process
17. ChatGPT audit before each stage, and James's in-game test after; checkpoint + build log + this file every stage.

## Effects
18. **Particles from a part inside the mesh are hidden by the mesh.** Emit from a box just outside / around the body.
19. **ChatGPT's particle numbers are a start, not a result.** Low rates + clear-at-birth transparency + pale colours read
    as NOTHING on this pale moon ground. Test by temporarily setting Rate 30 to prove the emitter works, then tune down.
20. **A test cleanup that matches by colour can delete the real thing.** Name test instances and delete by name.
21. **Eyelids:** model the open lid tucked fully behind the eye (175 deg); at 120 deg it sat over the eye as a hood.
22. **Every separate piece (eye, tooth, crystal) must be rigid.** Skinned across several bones it ripples "like liquid" as
    the body deforms; give each island one weight set (`rigid_parts`).

## Modelling method
23. **Build FROM a reference model sheet, not from words.** Ask ChatGPT for a front / side / back sheet in flat light and a
    neutral pose, then measure masses off it. Fused boulders (place → remesh → displace) beat separate slabs (v3 read as
    scattered boxes); glowing seams = AO crease mask MAX voronoi cracks.
24. **Blender renders look darker than Studio.** Without baked AO, light stone washes out on the moon: tint the
    SurfaceAppearance (~0.74) and drop EmissiveStrength a notch, or bake AO into the colour map next time.

## Animation
25. **Measure the legs before choosing a stride.** Planted feet can only travel what the leg reaches (~0.5 x leg length each
    way, plus toe-off); stride = that travel / stance share. The v4 Colossus (4.07-stud legs) maxes at 11 studs, so a
    "giant" pace comes from walking slower, not a longer stride. Record the over-reach (`IKOver`) on real terrain.
26. **Rigid pieces near a joint need ONE bone per group.** `rigid_parts` copies the nearest body vertex's weights per
    piece; near the wrist those differ piece to piece, so the gauntlet crystals turned through the gauntlet. Pin whole
    groups (`pin_pieces`).
27. **Judge a sound by its numbers if you can't hear it.** Sound.PlaybackLoudness sampled every 0.1 s shows the attack and
    the tail; the "pebble" rock drop peaked at 61 and was gone in 0.3 s, the giant footstep hits ~300 and rumbles 2.5 s.
28. **Screen capture: the desktop is 3840x2160 physical.** Studio's play viewport is x 4-3836, y 262-1843; a centred 16:9
    grab is `-offset_x 519 -offset_y 266 -video_size 2802x1576`. Game audio goes to James's headset, so videos are silent.
29. **Bone turns ADD down the chain.** A child twisting "opposite" its parent cancels it; for a counter-rotation, turn the
    hips one way and the belly + chest together the other way (shoulders vs hips is what reads). Swing arms by at
    least ~18° when they carry something huge, or the swing disappears.
30. **Library sounds often open with silence.** Measure the envelope (PlaybackLoudness every 0.1 s, in Play; Edit mode
    reads 0) and skip the gap with TimePosition, or the hit lands late. A "whoosh" peaks ~1 s in: start it early.
31. **Effects tied to a pose use the attack's clock, not "time since my first frame".** The sun latched a frame late and
    followed the arm down.
32. **Static Blender exports come out as .glb** (blender.mjs export --out ...glb); asking for .fbx writes nothing.
33. **Locals used inside setup() must be declared above it** (fxPart / shakeAt were defined lower in the file = nil).
34. **One-line sed edits can comment out code.** Appending "# (note)" after `x = f(...)` in a line that continues with
    `; bpy.ops...` turns the rest into a comment (the Ram's chest core lost its transform_apply). Put notes at line end.
35. **The animator's LOD skips frames for far units**, so attributes it writes (IKOver) never update when the camera is
    150+ studs away: bring the test player to the arena before measuring.
36. **A shiny goo seen from its shadowed side reads near-black in the moon map**; judge colour from the lit side next to
    the old form before "fixing" the texture.
37. **Short legs + rules speed = frantic cadence.** At 16 studs/s the Ram's 3-stud legs can only carry a 7.7-stud stride
    (a landing every 0.24 s); a deeper crouch buys reach (crouch 0.45 → 0.6 took the late-swing over-reach 0.61 → 0.14).
38. **ChatGPT image chats: the first message of a NEW chat often goes without its attachment** (the reply asks for the
    image). Attach, wait ~15 s for the upload spinner to finish, then type + Enter with real key events; JS
    `insertText` + clicking Send sometimes leaves the text unsent. Several ChatGPT tabs at once can freeze a renderer.
39. **A base that must stay put (a puddle, a skirt) needs its own bone AND hard weights.** Heat weighting gave the
    Twin's puddle to the body + tendrils, so every hop curled it into a wall; `pin_puddle()` = Base only below a
    height, blended into the body above (the skin stretches, never tears).
40. **Per-limb foothold offsets.** A knuckle-walker's arms rest reaching far ahead: plant them nearer (`ik.frontBy`)
    or they over-reach late in the swing.

41. **A fresh 3D Importer model looks whitish**: the importer gives every SurfaceAppearance its own emissive mask at
    EmissiveStrength 1. Always re-apply our `_emit` mask (strength 2) before judging or showing colour.
42. **Setting `WorldPivot` after `PrimaryPart` does nothing useful**: with a PrimaryPart the pivot is
    `PrimaryPart.PivotOffset`; the import pivot kept its -90 deg X tilt and every clone lay on its side. Set
    `mp.PivotOffset = mp.CFrame:Inverse()` for a pivot at the origin.
43. **Any weight edit can create a 5th bone influence**: finish it with vertex_group_clean + limit_total 4 + normalize,
    or the exporter's rule check fails.
44. **Jelly eyes**: in squash-and-stretch goo the eye must ride one bone with the skin round it (`lock_eye`), or the
    goo slides over and past it.

## 29 Oct overnight (Pebble / Pincer / Ram)
- `Bone.WorldCFrame` is NOT the rest frame: it includes every PARENT bone's animation (only the bone's own Transform is
  left out). Rest points / offsets must come from the bone chain (`restCF` in AttacksCrunch: b.CFrame up to the mesh part).
  It cost three wrong measurements (Ram head "offset", Pincer guard drift, Pebble horn).
- Contact solves go AFTER the pose (`atk.settle` whole unit, `atk.post` bones): `atk.place` runs over the idle pose, so a
  tip measured there is wrong. Read the gap only AT contact and ease toward the learned need, else it chases a swinging tip.
- A big form's mesh is not ray-queryable on the client (CanQuery off, turning it on didn't help): use AttachPoints.
- A spec's FK numbers are intent: measure the real rig (Pebble bite buried the mouth, Ram nose-up hit went over a Pack,
  Ram stamp compression lifted the hind hooves). Rig quirks: the Pincer's lower jaw cannot open (added a blade), PinchR
  carries a mis-weighted body chunk.
- Frozen-clock stills skip fades if you jump the clock: verify fades in continuous play.

## 30 Oct (Moonwood textures)
- GLB -> 3D Importer gives EVERY SurfaceAppearance a pure white MetalnessMap (full metal): textured props render dark
  and saturated. Clear `sa.MetalnessMap = ""` after import (hub-moonwood-tex-swap.luau does). Check props/aliens too.
- A single imported MeshPart can come through broken (rendered flat dark grey near, white far, even with another
  texture swapped on). Test a kit clone in the open; re-import fixes it.
- Node-shader "leaves" (Voronoi etc.) read as dots or cobbles. For a shingled leaf look, model a leaf tile in Blender,
  render it top-down to colour + height, box-project + bake.
- Under a dense canopy only Lighting.Ambient reaches the trunks (OutdoorAmbient needs open sky); normal maps do not
  show in that flat light, only albedo contrast does.
- After ANY terrain rewrite, every placed prop can float or sink (James spotted floating trees from his POV): re-lay
  layouts by script (raycast each piece) and run a float check on all loose props (bottom vs ground under it).
- Terrain:WriteVoxels needs the region corner ON the 4-stud voxel grid: an off-grid origin (-630) + ExpandToGrid adds a
  cell and the array is rejected ("317-element array expected"). Snap the corner.
- Workspace.StreamingMinRadius / StreamingTargetRadius / ModelStreamingBehavior can't be set from the MCP / command bar:
  set them in the Properties panel.

## 31 Oct (Goo Marsh)
- **Roblox culls back faces; Blender renders both.** Open sheets (gill blades, a cone underside) and tubes wound inward
  vanish or shade dark in Studio while the Cycles preview looks perfect. Wind faces outward on purpose (don't trust
  recalc_face_normals on open meshes) and set `MeshPart.DoubleSided = true` (scriptable) for true thin fins.
- **Blender metaballs put the surface at ~0.57 x the element radius** (threshold 0.6): multiply radii by 1.75.
  Negative metaballs either seal a tunnel or eat the whole shape: cut tunnels with a BOOLEAN cylinder instead.
- **Smooth terrain rounds to 4-stud voxels**: a "levelled" dip came out 0.35 above the goo sheet and buried it. Seat
  flat props from raycasts of the REAL surface after any terrain edit, with a margin (0.3).
- **ReadVoxels -> WriteVoxels (even material-only) moves the surface by up to ~0.2 (or more in places)**: re-seat props
  after a terrain paint pass.
- **An uploaded texture can silently never load**: fetch status says Success, but the part renders flat dark grey (a dead
  NORMAL map alone does this). Diagnose by swapping maps on a test clone (clear the normal map; give it a known-good
  colour map); fix with a fresh upload (change a pixel so it isn't de-duplicated). Don't assume moderation first.
- **Monitor off = Studio stops drawing**: screen_capture times out and new textures never appear. Ask James to keep the
  display on during Studio work.
- Fake translucency from AO "inside" needs normalising: a 40-wide goo cap is only ~2.5 studs thick, so raw values read
  everything as thin (pale whitewash). Base colour + deeper swirls, glow only on drips / thin edges / sunk spots.

## 31 Oct (Crystal Canyon)
- **Bake AO with `only_local=True`.** Every kit piece is authored at the origin, so they all overlap in the bake scene:
  a normal AO node saw the OTHER pieces, read every rock as a deep crevice (mean AO 0.4 on a lone boulder) and the
  crevice-glow term turned all the basalt orange. Local AO = 0.97 on open rock. (Probably also part of the Goo Marsh
  "everything reads thin" whitewash.) Test a shader term by baking it alone on one piece and printing mean / min / max.
- **Selected-to-active EMIT bakes from a dense copy can come out blank** (seam plates lost every glow). Bake the game
  mesh's own vertex float instead (give it enough tris to hold the crack lines).
- **Icosphere chunks read as potatoes on big built shapes** (the arch). Chipped BOXES (subdivided cube + 4-7 plane cuts)
  read as stacked basalt blocks; keep the GAME mesh un-displaced (flat chip faces + sharp edges > 36 deg split), put the
  noise only in the high copy for the normal map.
- **Hexagonal column packing:** centres d apart in a row, rows d x 0.866, odd rows offset d / 2, circumradius d / 1.732,
  all rotated 30 deg. Random rotation + 1.78 d spacing left 2-stud gaps (a city skyline).
- **Studio menus:** the af-*.ps1 helpers press Alt to focus the window, which closes an open menu: do File + its item in
  ONE call (`af-click2.ps1 -x 28 -y 51 -x2 90 -y2 387` = File > Save to File As), then paste the path into "Save As".
- **Big Luau scripts without pasting:** serve `src\tools` on localhost (`serve2.mjs <dir> 8767`) and run
  `loadstring(HttpService:GetAsync("http://127.0.0.1:8767/<file>"))()` in the MCP (works in Edit; stop the server after).
- ChatGPT's first look at the canyon terrain map drew channels that weren't there ("drifted"); measure the real floor
  (raycasts per X: centre, width) and send numbers, then ask for TEXT coordinates. Its long replies sometimes fail to
  load ("This response couldn't load"): ask again in text only.
- **Moon light washes biome albedo out** (Brightness 2.4 + lilac OutdoorAmbient): baked amber read lemon yellow, mid-grey
  basalt read white-lilac. Tint SurfaceAppearance.Color per texture group in the kit script (crystals 1/0.68/0.48,
  basalt 0.7) instead of rebaking; check in Studio before touching the colour ramp.
- **When the Claude-in-Chrome extension drops** (list_connected_browsers = []), ChatGPT can still be driven by hand:
  bring the Chrome window forward, click the composer, Clipboard.SetImage + Ctrl+V for the sheet, SetText + Ctrl+V +
  Enter for the message, then screenshot / scroll the screen to read the reply.

## 31 Oct (Conquest Lanes: map stretch + Fort 1)
- **To move finished biomes, stretch the finished heightfield; don't regenerate it at shifted coordinates.** Regenerating
  each biome shifted kept its interior but not the masks it blends with (plain edge, highland noise), so a new 8-stud
  ridge appeared at the canyon mouth. `hub_terrain_ring.py` samples the r4 grid through a smooth displacement field
  (0 in the centre, pure whole-voxel shifts across each biome band, the stretch only on the plain + rocky corners):
  every biome incl. its blend band and cliff = 0.00 difference. Then re-cut the passes between their moved ends (the
  corner shear bent them to slopes of 1.8-2.4).
- **Carry hand terrain edits voxel by voxel**: diff the live terrain against what the old grid wrote (in memory), write the
  new grid with the edits folded in at their shifted spots (one WriteVoxels per strip, no read-back round trip), then
  read back + compare (1.8 M voxels, 0 off). Paint passes that ReadVoxels/WriteVoxels a whole box make the WHOLE box look
  edited; a crater pasted from an older map holds old ground out to the box edge (keep only r < 118 as hand work).
- **Shifts must be whole voxels** (4 studs: 100 / 52), or copies and props can't move exactly.
- **screen_capture with camera_position jumps the camera instantly**: freshly written terrain chunks show as black holes
  (sky through the ground). Set workspace.CurrentCamera.CFrame, wait ~4 s, then capture with no position.
- **Roblox Glass hides see-through parts behind it**: a Neon swirl at Transparency 0.15 inside a Glass orb vanished; keep
  inner parts opaque. A goo-kit blob stretched tall reads as a CONE; use a ball / egg mesh for round things.
- **Studio's AI `generate_mesh` = fast but toy-like** (matte single-colour textures): fine for small props (a bone rag
  pole, a tiny drill, an egg SHAPE to re-skin), not for hero pieces. Kit pieces with real baked textures read better.
- **A `--` comment added by a search-and-replace can swallow the rest of the line again** (the banner chevron lost its
  colour + material args: "Expected ')'"). Put the comment after the full statement, then re-check the line.
- Make decorative parts CanQuery = false and give a combat target one invisible ground-to-top hitbox, so small units hit
  it without climbing and rocks never catch hits or clicks. Measure visibility with rays (eye 5 above ground, many
  points over the silhouette) instead of eyeballing.
- **Smooth terrain is never truly flat**: exact -2.00 voxels still rendered 0.8-2.0 (half-full top voxel ~1.6 bumps,
  full ~0.9). Spawn floors / shelves get a thin flat slab over the levelled pad.
- **Clearance: measure with every obstacle, every degree.** Wreck-only rays said 15.9; with the pylon + lip rocks the
  real pinch was 9 (the wreck sits off-centre). Fixed by moving the pylons to the open sides, not by squeezing.
- **Neon blooms lighter**: violet #B86BFF read pink on the ground; use a deeper #7A3CFF.
- **One client controller + server-time phase** for decorative motion (rest poses as RestCF attributes, stream-safe);
  slow an animation with a continuous clock offset (t - 0.75 x clamp(t - breakAt, 0, 3)), never a speed flag, or it snaps.
- **Never remember "the original colour" as whatever a script first sees**: a preview left the reactor in a test colour,
  the next controller run took that as the original, and losing the throne returned it blue. Store originals as
  RestColor attributes in Edit and restore to those. Run state round-trip checks (held -> lost) after every preview.
- The `--` comment trap struck twice more today (a pocket floor never got Anchored/parented; a beam lost LightEmission).
  After any scripted edit, grep for `-- ... ; statement` on one line.
