# Goo Marsh kit + layout spec (draft r1, 30 Oct 2026, Claude)

Zone: X -830..-490, Z -330..330 (north = -Z), sunken basin floor ~y -3..-6, six pool dips. Entry from the plain at
(-490, 0). References: D (master look), D2 (hero sheet), **D2b (orthographic sizes: build from this)**, D3 (materials),
I-nature-kit row 2. NOT used: Astra's detail-construction images. Method = the Moonwood kit (`hub_moonwood*.py`):
modelled detail + Cycles-baked PBR maps, smooth normals, authored in Roblox space then R2B, GLB via `blender.mjs export`.

## Look rules (James)
- Soft wet GLOWING goo: translucent-looking jelly, light from inside, darker teal depth, soft rim sheen. Never shiny
  plastic balls (no perfect spheres, no hard white hot-spots, no single flat blue).
- Glowing lilac / violet gills under every cap; pale pearl fibrous stalks; mid-grey moon rock (not black: lesson 15).

## Kit (Roblox space, base at origin, front -Z, 1 unit = 1 stud)
| Piece | Size (studs) | Meshes (each its own baked SurfaceAppearance) | Tris target |
|---|---|---|---|
| gmGiant (landmark) | 36 tall, cap 40 wide, cap 10 thick, gill underside at ~24 | Stalk (rope-twisted trunk 8 wide mid, flaring to 6-7 root buttresses ~20 wide), Cap (lumpy 3-lobe dome, rolled rim, ~16 hanging drips 2-7 long), Gills (shallow cone, ~64 modelled radial blades 1-1.5 deep) | ~8.5k |
| gmTrumpet (cluster of 3) | 15 / 10 / 8 tall, caps 5 / 4 / 3.5 wide, 12 wide overall | Stalk, Cap, Gills | ~2.2k |
| gmUmbrella | 9 tall, 14 wide, cap ~3.5 thick, stalk 4 wide flaring | Stalk, Cap, Gills | ~2k |
| gmSprout (scatter) | 4-6 tall, cap 3-4 | Stalk, Cap+Gills | ~400 |
| gmBlob A / B | 8 x 4.5 x 7 / 6 x 2.5 x 5 | Goo: metaball lumps merged + thin film spreading on the ground + 2-3 drips (never spheres) | ~900 each |
| gmVein | 8 wide, 8 tall | Rock (fused boulder: place, remesh, displace), Crystal (5-7 faceted shards, flat shading, emissive core), Goo (seep at the base) | ~1.5k |
| gmNest | 32 x 15 x 24 | Shell (metaball jelly dome, arched tunnel at -Z, knobbly horns, base blobs), Tunnel (inner rings, lilac emissive) | ~3k |
| gmPool A / B | 48 across (kidney shapes) | Goo surface (slight dome, thick rounded rim lip 1-1.5 high, ripple normal) | ~1.2k |
| gmStream A / B | 24 long, 4-7 wide, curved | Goo ribbon with rim lips (links pools, like D) | ~400 |
| gmRock A / B / C | 3-7 across | Dark moon rock, one variant goo-coated | ~400-600 |

Textures: 1024 colour / normal / roughness + a 4th `_emit` map (EmissiveMaskContent, lesson 16). Metalness 0 everywhere
(clear the importer's white MetalnessMap).
- GOO: fake translucency baked from THICKNESS (Blender AO node "Inside" = how thick the jelly is): thin rims, drips and
  films = bright cyan + emissive; thick middles = deeper teal. Glow spots = soft Voronoi spots under the surface
  (blurred, in colour + emit, not stickers). Tiny suspended bubbles = fine lighter dots. Roughness ~0.25 (soft wet).
- GILLS: modelled blades; albedo lilac -> violet into the depth; emit mask brightest deep between the blades near the
  stalk; roughness ~0.6.
- STALK: C4-bark-style grain along the twist, pearl crests, lilac-grey grooves, sparse dark pores; roughness ~0.6.
- ROCK: mid-grey basalt 0.17-0.40 linear, cracks + pits; roughness ~0.85. CRYSTAL: pale cyan, frosted, emissive core.
- Colours: from ChatGPT's D3 hex list.

## Effects (light budget <= 4-6 lights per view)
- 1 lilac PointLight under each giant cap (range ~30), 1 cyan in each nest tunnel.
- ParticleEmitters (test at Rate 30 first, lesson 19): slow drips falling from giant caps, bubbles rising + popping on
  pools, a few drifting cyan spores. Reference sheet requested (D5).

## Layout (Astra's placement-draft.json as the start, then densified + checked)
- Keep: landmark gmGiant at (-511, -35) by the entrance; 6 pools in the existing dips ((-600,-120) (-700,40)
  (-770,-200) (-590,180) (-760,230) (-640,-260), each seated just below its own rim); 3 nests at the route ends
  facing +X; routes 18 wide (entry, east spine X -535, three nest approaches).
- Add: 2 more giants deeper in (visible over the groves from the plain), streams linking pools, mushroom groves banked
  against the cliff walls, dark rocks round pools. Target counts: 3 giants, ~30 trumpets, ~28 umbrellas, ~40 sprouts,
  ~35 blobs, 8 veins, 3 nests, 6 pools, ~10 stream pieces, ~40 rocks = ~250k tris placed, target 60-90k per view.
- Every piece raycast-seated (bottom checked against the ground); the plain between the plots and X -490 stays open;
  the landmark cap must show from Plots 1-4 (eye height 5 at X -230, Z +-65 / +-190).
- LevelOfDetail SLIM on the models; CanCollide only on stalks, rocks, nests; CastShadow off on emissive parts.

## Audit plan
spec -> ChatGPT GO; Blender previews vs D2b / D3 -> GO; Studio shots from the plots + inside -> GO; save.

## r2 (30 Oct ~23:30): ChatGPT spec audit r1 = GO WITH CHANGES (8.5 / 8 / 6.5 / 7, `spec-audit-r1.txt`); all applied
1. Secondary mushrooms cut: trumpet 1,753 tris, umbrella 1,268, sprout 454 (giant 7,552). Target 175-200k placed,
   40-65k per view.
2. More goo: 8 pools (6 dips + 1 more dip at (-622, 75) + 2 big ones at x1.5 / x1.7 = 72 / 80 across), 7 trickle
   links of stream pieces, 12 gmFilmA/B film patches (30 x 19 / 28 x 15), 5 gmDrape cliff drapes (12 x 15).
3. Giant gills: 14 broad wedge blades (keel 2.4 deep); fine grooves baked into colour + normal.
4. Landmark at (-578, -62): clear of the X -540 spine and the nest-1 approach; routes 18 wide kept clear.
5. Particles: drips 2/s on the 3 giants only, bubbles 1.5/s on 4 pools, spores 1/s, cascade splashes 2/s; 6 shadowless
   lights (3 gill glows range ~36, 3 tunnel glows range 16). Reference D5 (effects sheet).
6. Textures: 11 sets (giant cap / gills / stalk, mush atlas, goo atlas, nest, tunnel 256, pool A, pool B, flats atlas,
   rocks atlas), 1024 max, baked at 2x. Emissive mask NOT in the GLB: uploaded `_emit` maps set by the kit script.
Geometry fixes found in Blender previews (`blender\geo-sheet.jpg`): metaball radius x1.75 (Blender puts the surface at
0.57 x radius: blobs / nest / drapes came out tiny), thick domed caps with the rim dropped (cr x 0.22) so the violet gill
band shows from the side, vase-flared stalks, fat teardrop drips. Texture r2: goo = base cyan body + deeper teal swirls
and crevices, glow only on drips / thin edges / sunk spots (r1 read every cap as "thin" = whitewash).
Layout: `src\tools\hub-goomarsh-place.luau` (D4 composition), effects `hub-goomarsh-fx.luau`, kit `hub-goomarsh-kit.luau`.
