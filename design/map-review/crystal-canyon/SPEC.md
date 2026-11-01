# Crystal Canyon kit + layout spec (r1, 31 Oct 2026, Claude)

Zone: X 490..830, Z -330..330 (north = -Z). A rock plateau (y 22-28) cut by two channels (floor y 1-5, 22-32 wide,
walls sloping ~15 studs each side). Entrance strip X 490-515 at y 4-6 faces Plots 5-8 (X 230). References (all in
`design\concepts\hub\`): E (master look), **E2 (hero sheet)**, **E2b (ortho sizes: built from this)**, **E3 (materials,
hex table in `crystal-canyon\E3-reply.txt`)**, E4 (stylised layout mood map; coordinates in `E4-layout-reply.txt`),
E5 (effects). Method = the Goo Marsh (`BIOME-BUILD-METHOD.md`): modelled detail + Cycles-baked PBR, GLB via
`blender.mjs export`. Scripts: `assets\blender\scripts\hub_crystalcanyon.py` (+ `_tex`, `_preview`).

## Look rules (James)
- Jagged amber crystals that read as real translucent quartz (craquelure, veils, bright facet edges, glowing core).
- Cracked MID-GREY basalt, never black (LESSONS 15: ChatGPT's #62636C = 0.12 linear, kept 0.15-0.32), thin seams only
  (~1/3 of the crack network glows: white-yellow core -> orange -> deep red, scorched band beside).
- Sharp angular shapes only. Nothing "Robloxy": no Neon parts, no shiny plastic.

## Kit (Blender space, base at origin, front -Y; built r3, sizes measured)
| Piece | Size (studs) | Meshes | Tris |
|---|---|---|---|
| ccSpire (landmark) | 34 x 31 x 53 (crystals), rock base 30 x 28 x 18 | Rock (fused faceted blocks, remeshed, flat chip faces kept, plate chips in the normal map), Crystal (7 big hexagonal crystals 13-44 long with chamfered edges + growth bands + faceted tips, 16 small) | 6.3k |
| ccClusterL | 13 x 12 x 15 | Rock base + 13 crystals | 1.5k |
| ccClusterS | 6 x 6 x 6.4 | Rock + 9 crystals | 0.8k |
| ccShards | 8.6 x 6 x 2 | 9 small crystals (some broken) + 14 gravel chips | 0.65k |
| ccColumnA / B | 15 x 14 x 24 / 16 x 14 x 15 | packed hexagonal basalt columns (joint grooves every 4-7, tilted tops, a few stumps) | 1.2k / 1.0k |
| ccBoulderA / B / C | 3 / 6.4 / 9 wide | faceted basalt, seams | 0.3 / 0.5 / 0.7k |
| ccVein (amber DNA) | 9 x 8 x 7 | Rock + 12 crystals (big core bursting from the front) | 1.4k |
| ccNest | 34 x 24 x 17 | Rock mound (32 wide, boolean tunnel 9 across), Tunnel lining (glowing core), Crystal crown (6 clumps + mouth frame + foot ring) | 4.8k |
| ccSeamA / B | 20 x 6 / 14 x 5, 1.1 high | polygon slabs + cracks (dense heightfield = bake source) | 1.1k each |
| ccArch | 43 x 9 x 15 (opening 24 x 9) | faceted blocks + boolean opening; 7 crystals on top | 2.85k |

Textures: 9 sets, 1024 (tunnel 256): spireCrystal, spireRock, crystals (atlas), basalt (atlas), columns, nest, tunnel,
arch, seam. colour / roughness / tangent normal + `_emit` mask (EmissiveMaskContent, uploaded separately), metalness 0.
- CRYSTAL: E3 #1 ramp root #A73B1B -> #DD7A2B -> body #F5A029 -> #FFCC6A -> tip #FFF1B9; craquelure (two scales of warped
  Voronoi edges); Bevel-node edge highlight; emit = AO-inside core + fractures + root zone (~0.12 floor), rough 0.22-0.38.
- BASALT: mottled #4A4D57 / #6E6F78 / #9A9CA3 + warm #8F7867, pits, rust specks, lighter chipped edges, dark cracks,
  ~1/3 of cracks = magma seams, faint glow in deep crevices / column joints; rough 0.86 (seams ~0.45).
- SEAM PLATE: slabs + crack ramp #B8320F -> #FF8A2E -> #FFCC5A -> #FFF4B7, scorched band. TUNNEL: ribs, white-hot core.
- EmissiveStrength start (E3 reply): crystals 1.4, magma seams 1.7, rock seams 1.4-1.5, tunnel 2.0.

## Terrain (backup first: ServerStorage.CanyonTerrainBackup)
- Link A (512,100) -> (580,101), 24-wide floor y 3-5, dead end widened to 24 over its last 20-25 studs.
- Link B (805,-15) -> (798,15) -> (803,42) -> (815,73), 24 wide, sloped walls kept. = loop: north entrance -> north
  channel -> east join -> south channel -> south entrance.
- Nest alcoves ~48-50 wide at (645,-160) and (685,197) with 18-wide spurs; small mining bays for veins V1-V6.
- Paint (zone X > 495 only): channel Sand -> Sandstone + MaterialVariant "CanyonFloor" (warm grey #A69A8A + amber grit,
  E3 #6); plateau / walls Rock -> Basalt (existing MoonBasalt variant, mid grey). Re-seat flat props AFTER painting.

## Layout (ChatGPT E4 coordinates, all raycast-seated; 18-wide routes clear)
- Landmark spire (580,-10) on the plateau nose (top ~y 78): must read from Plots 5-8 at eye height 5.
- Nests: N (645,-160) alcove, S (685,197) alcove, Upper (750,-235) plateau (via the north pass); mouths face approaches.
- Veins V1 (552,-84) V2 (625,-95) V3 (739,-10) V4 (611,106) V5 (721,108) V6 (795,124) in wall bays; V7 (640,-272),
  V8 (718,245) on the plateau.
- Arch (705,-77) spanning the north channel N-S, deck at plateau height, 10-12 headroom (scaled ~1.6 high).
- Columns C1-C10 on the channel walls (E4 list), seams M1-M12 flush on the floors along / across the channels,
  crystal groups G1-G12 (3-7 clusters each, large ones on plateau shelves), small clusters + shards along cliff bases
  and channel bends, boulders on floor edges and plateau.
- Estimate placed: spire 6.3k, ~30 L clusters 45k, ~50 S 40k, ~40 shards 26k, 14 columns 15k, ~60 boulders 30k,
  8 veins 11k, 3 nests 14k, 12 seams 13k, arch 3k = ~205k (Goo Marsh 311k passed); ordinary views target 60-120k.
- LevelOfDetail StreamingMesh on models; CanCollide on rock / columns / arch / nest rock; crystals + seams no collide;
  CastShadow off on emissive-heavy parts (crystals small, seams).

## Effects (E5 pending; budget <= 6 shadowless lights per view, 25-60 particles visible)
- 1 warm PointLight at the spire base, 1 per nest tunnel, a few seam glows; embers 1-2/s on a few seams, crystal
  sparkle on the spire + large clusters, low warm dust in the channels. Test at Rate 30 first (LESSONS 19).

## Audit plan
spec -> ChatGPT GO; Blender previews vs E2b / E3 -> GO; Studio shots from Plots 5-8 + inside -> GO; save.

## r2 (31 Oct ~02:50): ChatGPT spec audit r1 = GO WITH CHANGES 8/10 (kit 8.5, tex 8.5, layout 7.5, budget 7.5;
## `spec-audit-r1.txt`); all applied
1. Seating: contact height = lowest + 0.25 x (median - lowest) of 9 samples (shallow burial, no floating corners);
   a levelled 32-wide foundation for the spire (median plateau height); the arch seated from BOTH banks (deck top meets
   the lower bank, piers on the floor, Headroom attribute checked >= 12) + 3 invisible collision boxes (mesh no-collide).
2. Channels widened: both carved at 28 wide (32 at bends), each point at its own smoothed floor; links A/B 24.
3. Lights: spire 1 (range 42, 1.0, #FFB45A), 2 seam lights (12, 0.7, #FF8A2E), nest tunnels (12, 0.8, #FF9A42) = 6 in
   the whole canyon, <= 5 in any view; the rest of the glow is emissive masks.
4. Spire hierarchy: 4 crystals dominate (44 / 33 / 29 / 22), the other 3 shortened to 16 / 12 / 10 and sunk.
5. Texture memory: basalt + columns atlases 512 (secondary); crystals kept 1024 (the craquelure is the "real quartz"
   read and clusters are the most repeated hero piece); tunnel 256.
6. Basalt emit: only seams + crevices glow (checked 70-80 % black). D: vein parts CanQuery = true (mining rays).
Also from E6: column outcrops banked round the spire base, a block rim round the nest mouth, one big chunky vein core.
Particles: ChatGPT's E5 numbers (spec-audit-r1.txt C) are the start; tuned in Studio (LESSONS 19: test at Rate 30).
Geometry finds in Blender: AO must be only_local (every kit piece sits at the origin: AO saw the others, every rock read
as a crevice and glowed orange); the dense seam-plate bake source lost its glow selected-to-active (now the game mesh
bakes its own crack float at 1.6k tris); icosphere chunks read as potatoes on the arch -> chipped boxes ("blocks").
