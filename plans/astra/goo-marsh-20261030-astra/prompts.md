# Image prompts and provenance

Built-in image_gen tool used; no API or CLI fallback, no secrets accessed. Existing D/I/A images remain primary. The additional image is construction interpretation, not an approval or game asset.

## Round 1 — detail-construction-r1.png

Inputs: existing D-goo-marsh-chatgpt.png and I-nature-kit-chatgpt.png. Output inspected: gill branching and shell thickness visible, but overly fine fernlike gills and excessive specular highlights warranted revision.

```text
Use case: stylized-concept.
Asset type: focused modelling-detail reference supplement for the existing Alien Fusion Goo Marsh game kit.
Input image 1 D-goo-marsh: PRIMARY approved marsh look. Input image 2 I-nature-kit: PRIMARY isolated shapes. These remain authoritative. Create ONE supplementary four-panel close-up construction sheet, not a redesign of the scene or the seven-piece kit.
Purpose: resolve details not visible in the primary images so Blender can model real organic forms instead of primitive approximations.
Canvas: landscape 3:2, clean medium grey-violet background. Four equally sized panels, discreet labels only: A GILLS, B STALK, C NEST FRONT, D NEST SIDE. No other text, no logos.
A: close low three-quarter underside of the reference's giant cyan mushroom. Thick gently irregular cap lip with sparse short attached goo drops, 12 broad branching lilac-violet gill ribs with real thickness, organic radial gills flowing into the stalk crown. Upper cap cyan blue with softly painted paler patches and wet sheen. Closed smooth solid masses, nothing floating, no fine hairlike strands. Show junction clearly.
B: side view closeup of the same mushroom's pale cyan/lilac fibrous stalk crown, smoothly flaring into cap underside. Shallow twisting ridges continue into gills; chunky buttress-like folds; no eyes or faces. Keep same cyan cap and lavender underside.
C: straight front view of the small goo nest seen at centre-right of D and second row of I. Rounded asymmetric cyan mound with several fused soft goo lobes and a wide rounded arch doorway, a shallow violet interior floor, smooth rounded attached rim. Cozy alien habitat/battle-start marker, kid-safe, not monster mouth: no teeth, eyes, tongue, spikes, bones or sharp elements. Flat grounded base. Strong pale cyan rim against darker violet interior. Clearly visible opening wide enough for a player, not a tiny black hole.
D: side three-quarter view of that exact same nest design, with a small local cutaway on the rear quarter to expose thick opaque wall, rounded arch continuity, and shallow floor. This is a modelling cutaway, not a transparent model; all other surfaces remain opaque. A low rounded back rather than a tall tower, matching C's silhouette and lobe positions.
Lighting: flat soft neutral studio illumination, restrained highlights, no bloom or glow haze. Palette cyan blue + violet accents; mid-value surfaces readable in shadow. Wet opaque organic PBR-looking materials, fine restrained surface detail. Avoid glass transparency, neon shell, marble veining, tiled scales, ornamental filigree, oversaturated white-hot highlights, photoreal grime, characters and people. Preserve reference character but make construction visible.
```

## Round 2 — detail-construction-r2.png (preferred construction supplement)

Input: round 1 image. Output inspected: broad continuous gill ribs, smooth twisting stalk folds, grounded rounded nest opening, thick opaque shell and floor. Useful for construction. Still more glossy than the final game's required restrained material balance; do not bake white highlights into albedo or use shell emission. Exact rib count is an implementation target, not proven by generated pixels. Panel D is an explanatory cutaway only; final shell must be closed. This inspection is Astra's image QA, not ChatGPT Thinking GO.

```text
Use case: precise-object-edit. Edit the supplied four-panel Goo Marsh construction sheet without changing its established cyan/lilac design or four-panel framing. This is a production-simplification pass, not a new design.
Keep the nest front C and nest side cutaway D geometry exactly as they are; keep all silhouettes and the thick opaque wall/floor.
Change only the overly fine mushroom surface construction in panels A and B: replace the many fernlike tiny gill ridges with 12 broad smooth radial ribs visible in A, branching only once as they join the flared stalk. Preserve a violet underside between the solid thick gills. Replace tiny chippy/woodlike scale texture on stalk B with 5-7 long continuous shallow twisting folds, pale lilac high ridges and cyan-lilac groove shading. Preserve attached round short drip ends, chunky cap lip, roots and height. No blades, feathers, bark chips, razor edges or fine comb texture. These forms must be realistic to model on a landmark below 6000 triangles.
Across all panels reduce only the blown white specular areas to soft cyan-tinted highlights: opaque wet painted cyan material, no emission, no bloom, no transparent glass. Preserve relative cyan/lavender palette and legibility. Labels A/B/C/D remain. No people, characters or additional objects.
```

