# Alien Fusion: the map plan for the tycoon (30 Oct 2026; ChatGPT map audit r1 in `map-review\`)

> **30 Oct ~22:00: SUPERSEDED for size + layout** by `map-review/map-size-audit.md` (one ~1,660 x 1,400 moon since r4, plots at
> X +-230 / N +-65, +-190, an open plain round them, biomes against the cliff walls; ChatGPT-checked). The look / kit
> rules below still stand.

James: "What about the current map? ... I feel like it's cool, but it is a bit bland, is it not? ... Review with
ChatGPT." Sheet of the current map: `map-review\current-map-sheet.jpg` (6 Studio views + a battle still).

## Verdict (ChatGPT, agreed by Claude)
**Keep the moon. Rebuild its look and layout.** 4.5 / 10 for a 9-14, phone-first audience today.
| | Score | Why |
|---|---|---|
| Terrain craftsmanship | 8 | the Blender heightfield + baked moon materials are good |
| Lunar atmosphere | 8 | black sky, stars, cliffs read as "moon" |
| Visual variety | 3 | uninterrupted grey: little reward for moving around |
| Colour + landmarks | 3 | the reactor vanishes from a distance; rocks, crystals, bases, crater all the same brightness |
| Phone readability | 5 | |
| Tycoon fit | 4 | a huge empty battlefield, not a social hub |
"The terrain quality isn't the problem. The art direction is." The cyan Titan is more interesting than anything around
it. Its earlier objection was never the moon itself: it was using a big empty battlefield as the social hub.

## The new look: a dead moon being taken over by two alien species
- **Grey moon** = the neutral base (keep it: it makes the alien colours pop).
- **Cyan SQUISH zone:** goo pools, glowing fungus-like growths, soft organic shapes; Squish DNA veins are mined here.
- **Amber CRUNCH zone:** jagged orange crystal outcrops, cracked basalt, glowing mineral seams; Crunch DNA here.
- Accent violet; no neon everywhere. Palette: charcoal, moon silver, cyan, amber, violet.
- Lighting: keep the starfield; cooler blue-violet ambient fill so shadows read, warm sun, local accent lights on
  landmarks + DNA, a little dust. Glow never washes out the aliens.

## The HUB (8 players)
| | Plan (prototype targets, not locked) |
|---|---|
| Size | ~650 x 500 studs of play space inside the existing 1,008 x 672 terrain (cliff ring kept) |
| Plots | 8, ~85 x 95 studs each, flattened platforms in two staggered groups of 4 around the crater |
| Crater | ~85 studs across: the shared meteorite event area |
| Travel | 10-15 s from any plot to the crater; main paths 14-18 studs wide, lit |
| Landmark | THE CRATER: a giant crashed alien object + the damaged reactor hanging above it + a slowly turning energy structure, seen from all 8 plots; meteorites streak in and light everything up |
| Exploring | a cyan mining region and an amber mining region (reasons to leave the paths); every direction should show something to approach, collect, build or look at |
| Showing off | your plot grows from one structure into a small alien research base; everyone can see across the crater who has the biggest base and the rarest aliens |

## Themed areas (James, 30 Oct: "a bit of forestation ... a lunar forest ... lunar themed areas ... if we could
## realistically expand it performance-wise ... go for it")
The terrain is already 1,008 x 672: the hub core (crater + 8 plots, ~650 x 500) sits in the middle and the outer band
(~180 studs deep, inside the cliff ring) becomes FOUR themed areas, one per side, each a reason to explore:
| Area | Side | Look | What's there to do |
|---|---|---|---|
| **MOONWOOD FOREST** (the lunar forest) | north | tall pale silver-white trees with twisted trunks and soft violet glowing seed-pods, blue-grey moss on the regolith, floating spores (low gravity), little clearings | rock + rare DNA "seed-pods" to mine, a hidden clearing, nest fights in the trees |
| **GOO MARSH** (Squish land) | west | cyan goo pools, glowing mushroom caps, soft blob growths, sticky ground | Squish DNA veins, goo nests |
| **CRYSTAL CANYON** (Crunch land) | east | jagged amber crystal outcrops, cracked dark basalt, glowing orange seams | Crunch DNA veins, crystal nests |
| **LANDER RUINS** (classic moon) | south | an old abandoned moon outpost: lander legs, solar panels, a satellite dish, a moon rover, small meteor craters (no real brands, no flags, no people) | scrap rock, a meteor field, a lookout dish to climb |
**Performance (why expanding is realistic):** the terrain already exists (no new area); every area is built from a SMALL
kit of reused meshes (3-4 tree variants, 5-7 props per biome, each < 2k tris, one shared texture atlas per kit), so the
whole map is mostly instanced copies; StreamingEnabled keeps far areas out of memory; no per-tree scripts, effects only
near the player (the client budget from the perf work: particles nearest first). Budget to check on the phone:
~150-200 trees + ~300 biome props. [TEST] on a budget phone before the outer areas are filled in.

## The BATTLE arena
Cut a smaller arena from the current map (start ~360 x 240, compare a bigger one, rules [TEST] in the mechanics doc):
keep the crater as the objective, the north ridge (narrow) and the south plain (open swarm ground), bases closer.
Mostly neutral grey, with cyan / orange only for teams and objectives, so 64 aliens + their attacks stay readable.

## Build order (each step: Studio screenshots at player height + phone camera, ChatGPT check before the next)
0. **Reference images first** (the rule from the attack batches, `DECISIONS.md` 28 Oct): a reference pack for the hub
   (overview, crater landmark, a cyan zone, an amber zone, one plot at stage 1 and fully built) from ChatGPT, then build
   to match it.
1. **The crater landmark** (crashed object + hanging reactor + energy structure + meteorite strike).
2. **One complete showcase plot** (drill, conveyor, incubator, hatch display, battle pad, trophy spot); judged at player
   height + the phone camera BEFORE copying it 7 more times.
3. **Terrain rework for 8 plots:** flatten the 8 platforms, paths, cut the empty space, keep the cliff ring.
4. **Two biome kits in Blender:** 5-7 cyan organic pieces, 5-7 amber crystal pieces, + terrain material blends round them.
5. **Lighting + atmosphere pass.**
Don't add hundreds of rocks: a few memorable landmarks + repeatable kits.
ChatGPT: "start with the crater landmark and one fully functioning tycoon plot before rebuilding the rest ... The moon
is a good idea. It's the emptiness that needs to go."
