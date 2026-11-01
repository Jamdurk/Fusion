# Moonwood texture audit r1 (ChatGPT, 30 Oct 2026 ~20:15) - GO WITH CHANGES
Images: 0-reference-C4.png, 1-elder-player-view.jpg, 2-west-grove.jpg, 3-low-trees-close.jpg, 4-blender-closeup.png
(NB: shots taken while the importer's white MetalnessMap was still on = everything rendered as dark metal; found + cleared after.)
Scores vs C4: leaf texture far 5, close 6; canopy colour 3.5 (far too indigo/dark); rim fringe 3 (reads as crystals/teeth);
bark 5; overall de-Roblox 5.5.
Albedo targets (sRGB): leaf base 150,122,193; mid 195,175,225; tips 232,220,245; deep underside 115,88,159;
pearly bark 240,231,244; bark grooves 180,166,198. Do not fix it with more global ambient.
Fixes:
1 MUST canopy brighter (targets), roughness 0.75-0.85, metalness 0, stronger baked contrast between leaves; test canopy
  CastShadow=false on one tree.
2 MUST rim fringe -> flat slightly curved blades (bend down + out), 2 staggered rows, ~20-30 % fewer, lilac top, violet
  base, pale tip, 4-8 tris each.
3 HIGH bark: 2-3 broad twisting rope ridges following the twist, darker grooves only, stronger grain, roughness 0.5-0.65.
4 HIGH pods: elongated teardrops, thin curved stem, pale lilac non-Neon shell + small Neon core.
5 REQUIRED CHECK low-tree canopy texture (swap in the wide tree's SurfaceAppearance to isolate).
Acceptance: one wide tree at player height (lit top + shaded underside) next to Blender, aim 8/10 vs C4 before all 103.
