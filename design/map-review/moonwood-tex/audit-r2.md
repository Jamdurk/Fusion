# Moonwood texture audit r2 (ChatGPT, 30 Oct 2026 ~21:00) - GO WITH CHANGES, "Approved ... production material set"
Images: moonwood-textured-before-after.jpg (sheet), r2-elder.jpg, r2-canopy-close.jpg
Scores r1 -> r2: leaf far 5 -> 8; leaf close 6 -> 7.5; canopy colour 3.5 -> 8; rim fringe 3 -> 7.5; bark 5 -> 7.5
("decent now. It finally reads as twisted pearl bark"); overall / not Robloxy 5.5 -> 8.
Remaining "gamey" look = repetition + low-poly canopy forms, not the texture workflow.
Fixes: 1 (most important) break canopy repetition: per-tree hue +-6 RGB, brightness +-8 %, (UV offset per type if easy);
2 softer canopy shading (weighted normals), keep silhouette; 3 pods: husk paler / less pink (~222,196,236), Neon core
smaller / dimmer so the husk silhouette stays visible.
Applied: 1 = per-tree SurfaceAppearance.Color tint (noise across the forest); 3 = core dimmer violet. 2 = NOT done
(needs a canopy re-bake with weighted normals) - optional later polish.
