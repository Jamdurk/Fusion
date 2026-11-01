# Titan REDO build r3 (your r2 NO-GO list, done). Attached: build-r3-stills.jpg (Play mode, real geometry, the 4
# stills you asked for + 1 wide + a Blender preview) and AttacksTitan-r3.luau.txt (the module).

## Your r2 list -> what changed
1. K1 crown rounded + outer tilt: 8 smooth arms (7 rings x 10 sides, radius 0.95 -> 0.45 into a 1.25x round bulb), the 4
   outer arms lean ~25 deg further out; footprint back to 8.6 wide (8.66 x 4.95 x 7.24, 2,052 tris).
   ALSO found + fixed (all 24 K meshes): the OBJ export wrote NO vertex normals, so Roblox shaded every face flat; that is
   what read as "angular crystalline". Now smooth per-vertex normals (rocks stay faceted on purpose). Arm bulbs sub-2.
2. J2 handoffs: ball visible to 3.44, fading 3.40 -> 3.44; splat 0.70 at 3.40 -> 1 by 3.46; puddle event moved 3.45 -> 3.40
   (full 10 wide by 3.70, held to 5.90). Still J2-343: ball 0.75 inside the splat (0.15) + puddle starting.
3. K8 wave: crest overhang 5.8, tip z -6.9 (was -5.0), hollow ~5.5 deep, upper third rolls forward. NEW: both ends taper to
   ~12 % over the last 2.4 studs (a rounded roll-off): the old 65 % ends were flat 19-sided caps that read as big crystal
   facets in every 3/4 view. Placed by its crest tip (-(front - 6.9)).
4. Crash handoff: wave visible to 3.27 (overlaps the wall 3.20 -> 3.27); wall opacity 0.65 at 3.20 -> 1 by 3.26.
   K9 wall: same rounded ends; its 5 bulbs now sit ON the spike tips (they were at the outline height and floated).
5. Sound: Food Valley 5 "mushy" (9114519760) is the main impact on slam, bomb splat, wave release + crash, defeat; the wet
   slap is the accent at 0.25-0.30.
6. Flood: three 12 x 10 sections, each on its own ground height (+0.03).
7. Trail cap: 8 reused drops.
8. Shock rim: 16 segments x 7.5 deg, each r * rad(7.5) * 1.3 long (30 % overlap), up to 2.0 high / 3.0 thick.

## Measured (Play, MOVE TEST)
- Contact solver error (tip bone vs target): Slam 1.64 = 0.000, 1.88 = 0.000; Wave 2.10 = 0.11, 2.28 = 0.17 studs.
- PHYSICAL mesh tip (Blender, rest pose, lowest vertex weighted >= 0.5 within 2 studs of each tip bone head): the mesh
  underside sits FL 0.144 / FR 0.06 / BL 0.918 / BR 0.618 below the bone head. Front bones are held 0.12 over ground ->
  underside -0.02 (FL) / +0.06 (FR): touching. Back bones now held at their own underside: BL 0.92, BR 0.62 (was one 0.6:
  BL would have sunk 0.3). Rest-pose numbers; skinning in the pose can move them a little.
- Two Titans doing the same attack at once (attack2, window in front): peak visible FX MeshParts Slam 64, Bomb 34,
  Wave 38, Defeat 66; frame median 7.0 ms, 95th 8.2-8.6 ms, worst 10.3-17.5 ms.
- 0 warnings / errors (client + server): MOVE TEST all 4 moves + a 3 v 3 AI fight (Titans vs Colossi) in the AI-test place.
  (13 pre-existing "asset type does not match" lines come from the shared Polish Kit sound list, not the Titan.)

## Not done, and why
- Goo 10-15 % lighter: the colour is the GooSkin SurfaceAppearance texture; Color tint on a SurfaceAppearance can only
  darken (it multiplies), never brighten. Lighter = a new texture bake. Ask: worth a separate bake, or leave?
- Cosmetic recovery keys after the server lock: unchanged from r2 (Slam lock 3.40, Bomb 2.60, Wave 3.20; recovery keys
  play to each move's end, the next order waits for the lock only).

## Honest notes on the stills
- J1-195: the rim reads as a chain of rounded beads, not one ring (16 separate meshes, each with rounded ends).
- J3-323 "same 3/4": the wave has travelled to the crash point right beside that camera, so it shows the wave's END (now
  rounded) and the wall edge-on. The wide shot shows it from the side.
- The thin cyan pillar in old stills was the MOVE TEST target marker (test only); hidden here.

## Please answer
A. Per attack GO / NO-GO now (exact numbers for any NO-GO).
B. Code issues. Plain, no over-engineering.
