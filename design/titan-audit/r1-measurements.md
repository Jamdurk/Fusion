# Titan batch 2: measured in Roblox Play (28 Oct)

Built from your Titan spec (design/13). Everything below was measured with the attack frozen at exact times (FreezeTT) on the client, heights from a downward raycast to the terrain.

## Deviations from your spec (each measured, reasons)
1. **SLAM tentacle FK.** Your keys put the front tentacle joints 3.4-5.2 studs UNDER the ground at 1.64-1.86. Cause: on this rig the tentacles hang off the Body bone, and Body (-11) + root pitch (-7) already drop them; then F1 -23 drives them through the floor. Solved live: 1.64 F1 (18,2,1) F2 (-32,0,1); 1.86 F1 (27,1,-3) F2 (-39,0,-1) F3 (0,0,-4). Result: FL2/FL3 hold 0.30-0.34 above the ground from 1.64 to 1.86 (FR side 0.6-1.0: the ground slopes). Contact zone x=+/-3.8, z=-12.3 (inside the 16-stud wedge). Before 1.60 the tips are still 2.4-4.5 up (the "in" ease from 1.44), so visible contact starts at 1.62, not 1.54.
2. **TSUNAMI 3.00/3.20 and BOMB 2.55/2.60 lunges**: same problem (wave 3.20: tips 6.6 under; bomb 2.55: 1.2 under). Solved: wave 3.00 F1 (8,2,4) F2 (-18,0,5); 3.20 F1 (34,1,-4) F2 (-40,0,-6). Bomb 2.55 F1 (8,0,-2) F2 (-25,0,-3); 2.60 F1 (1,0,-2) F2 (-22,0,-1) (solved at k=1, the deepest lunge). Sweep of each whole move afterwards: lowest tentacle joint >= -0.03.
3. **DEFEAT drape**: fronts were 2.7-4.8 under from 1.70; back-left 1.6 under at 1.42 (the sway roll). Now 1.70 F1 (10,0,-12) F2 (-40,0,-16); 2.05/3.80 F1 (8,0,-15) F2 (-41,0,-14); 1.42 B1 rz -12 -> +10. Lowest joint -0.09 at 2.05 (it is melting into the cap there).
4. **Melt puddle sizes**: I first read 10.5x8.5 etc as radii; now DIAMETERS (1.86 = the body's own footprint).
5. **Wave crest**: crest front 6->30 over 3.04-3.20 (150 studs/s), height 2.5->4.5 at the hit; then 3.20-4.30 it rolls on 30->33 while collapsing 4.5->1.2; sheet drains from the back; gone by 5.30. (My first build snapped the crest back to 8 studs at 3.20 and rolled it again: fixed.)
6. **Danger fills**: cyan SmoothPlastic vanished on the sunlit ground; bright cyan Neon bloomed white. Fills are now dark teal Neon RGB(0,105,125) at T 0.72-0.42. Long planks sank into terrain bumps, so the wedge fill is 12 slices x 4 radial chunks, the lane fill 6x3 chunks, and every outline edge is split into <= 2-stud pieces, each placed on the ground.
7. **Rings**: inward ripples, slam splash ripples and the bomb's mint splash ring are 16-20-piece rings (first build used cylinders = filled discs).
8. **Lid**: spec L>=0 maps to our lid angle LID_ANGLE(-175) * L/60 (60 = shut); negative L (wide eye) = tuck the lid back by -L*0.5 degrees.

## Timing / behaviour measured
- SLAM: wedge 0.74, ripple arcs 1.34 / 1.49, pulse 1.60-1.64, hit 1.64, wedge gone 1.64, lock 3.40 then 0.25 s blend, effects end 3.80.
- BOMB: mouth bulge 1.85-2.55 at the mouth (~4.3 ahead, 8 up), circle (r=5) 2.40-3.40, spit 2.55, flight 2.55-3.40 (0.85 s, peak ~6 above the line for a 15-stud target), landing 3.40 at the post, puddle 3.40-5.55, gone 5.80. Body lock 2.60.
- TSUNAMI: lane 6-30 x 12 from 2.10, swells 2.75-3.04, surge 3.04-3.20, hit 3.20, crest collapse to 4.30, fade by 5.30.
- HURT: per-bone additive; a hit on the +X side shoves the root -0.135 at 0.13 s, on the -X side +0.134 (mirrored, with left/right tentacle chains swapped). Weight 0.35 during a committed attack.
- DEFEAT: body fades 1.86-2.10 into the cap (LocalTransparencyModifier), cap 10.5x8.5 at 1.86 -> 12.5x10.5 at 2.25 -> 0 at 3.80; motes in groups of 4 at 2.20/2.45/2.70/2.95 (counted 4/8/12/12), streaking 45 studs toward home.

## Budget (two Titans doing the same move at once)
| Move x2 | particles/s max | lights | fragments | worst frame |
|---|---|---|---|---|
| Slam | 24 | 0 | 0 | 23 ms |
| Bomb | 28 | 0 | 0 | 13 ms |
| Tsunami | 34 (the shared cap clamps it) | 0 | 0 | 10 ms |
| Defeat | 14 | 0 | 0 | 14 ms |
No camera shake anywhere. Danger shapes are never budgeted.

## Known open points (your call)
- A. The defeat slump (1.10-1.86): Top oy -0.90 abs pulls the dome down into the body; the skin bunches into a flat "brim" on one side (sheet panel 8). Keep (reads as deflating) or soften the Top drop?
- B. The crest (panel 7) is 4 overlapping squashed spheres tilted forward 25 deg + 3 mint foam lines; it reads as a goo roll, not a breaking curl. Good enough, or add a lip row?
- C. MOVE TEST aims include a 14-stud target at 25 deg: the radius-5 puddle then overlaps the Titan's own front tentacle (panel 5). Gameplay should keep bomb targets >= 12 + 5 away, or is overlap fine?
- D. Sounds are Roblox library IDs (Body Hit Wet slap, Water Splash Big, Drain Gurgle, Bubble Magic, Mouth Pop/Spit, Wobble Board, Body Wiggle, Goo, Waves, Wave Crash). Not yet listened to on a phone speaker.
