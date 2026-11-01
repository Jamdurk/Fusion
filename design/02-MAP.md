# Map 1: the Moon arena (1v1) — design (27 Oct 2026, Claude; ChatGPT audit pending)

> **SUPERSEDED (30 Oct 2026):** this is the original 1v1 arena design. The game is now a moon tycoon; the hub map is
> `map-review/map-size-audit.md` (one ~1,660 x 1,400 moon, 8 plots, 4 biomes). The old arena structures are archived in
> the place (ServerStorage.ArchiveArenaV1); battle arenas will be cut from this design later (mechanics §8.5).

## Shape (top view; X = long axis, base to base; studs)
- Playable area 360 × 240, point-symmetric (turn it 180° and it's the same), so neither side has the better start.
- **Bases** at x = ±150: a raised landing plateau (+6) with the player's Matter Core and the army's spawn pad.
- **Centre crater** at (0, 0): rim radius 42, rim +8, floor −6. The contested **Fusion Reactor** sits on the floor.
  Two breaches in the rim, on the base-facing sides, 12 wide: chokepoints (mediums are good there).
- **North flank: Crystal Canyon.** A winding canyon 14-18 wide between ridges (+14), pale white-blue quartz clusters.
  Narrow = mediums and Titans; slow for a swarm to surround anything.
- **South flank: Boulder Plain.** Open dusty plain with big boulders and small craters. Open = swarm country.
- **Edge:** tall crater-wall cliffs ring the arena (dark basalt only out here). Outside: rolling far terrain, black sky,
  stars, Earth low over one base and the Sun's glare over the other's side wall (same lighting angle for both).
- Distances: base to centre ≈ 150 studs ≈ 9-10 s for the swarm, ~20 s for a Titan. Base to base ≈ 300.

## Palette (from 01-ALIENS)
Bright neutral grey regolith (the main read), cooler grey crater floors, darker ejecta rays around craters, dark basalt
only on the outer cliffs. Quartz = white-blue. No cyan and no amber anywhere in the world: those belong to the aliens.

## How it's built (Blender-heavy, phone-safe)
1. **Ground shape: sculpted in Blender** (heightfield: bases, crater, canyon, plain, cliffs, dozens of small craters),
   then written into Roblox **Terrain** from a sampled height grid. Why Terrain and not mesh tiles for the ground:
   collision, LOD, streaming and soft material blending come for free and run well on phones; a 360×240 mesh ground
   at good detail needs ~40 tiles of 20k tris and loses blending between materials.
2. **Ground textures: made in Blender.** Procedural moon materials (regolith, crater-floor dust, ejecta, basalt cliff)
   baked as seamless 1024 PBR sets (colour / normal / roughness) → Roblox **MaterialVariants** on the Terrain.
3. **Hero meshes: modelled in Blender** with high-detail sculpts baked to normal maps: crater rim rock walls, canyon
   ridges, boulder set (4), quartz clusters (3), the two Matter Cores, the Fusion Reactor, spawn pads. Each ≤ 20k tris,
   most 2-8k; reused copies (instancing) instead of unique rocks.
4. **Sky + light: Lighting Kit `void` look** (space: no air, starfield, moon key light) + Blender-rendered Earth/Sun
   sky textures if the stock sky doesn't sell it.
5. Exports only via `blender.mjs export` → `roblox-ready\`; Studio import; screenshots each step; ChatGPT audit each stage.
