# Alien Fusion perf build r2: your r1 required changes, done + measured

1. P5 collision fidelity RESTORED (perf-p5-templates.luau, attached): PreciseConvexDecomposition on CrunchF4, CrunchF3v5,
   SquishF3v5, SquishF4v5, Default on the rest = exactly as authored (read back in Studio after applying). Kept: mesh +
   Hitbox CanCollide / CanTouch / CanQuery off, Hitbox shadow off, F1/F2 mesh shadow off. The Drip's attachTo sets
   `mp.CanQuery = true` on the target mesh client-locally and never sets it back; per your "don't add a manager" I left it
   (only that client, and nothing else queries alien meshes; the PolishKit Looks lighting probe is an Exclude-list ray).
2. atk.place CHECKED, all 7: Crunch Charge (chargeDist + ground), Crunch 1511 (ctx.base + lift), Drip Cling
   (clingFrame(at) = the TARGET's anchor via surfaceNow -> at.anc()), Drip Boing (ctx.escape + arc), Drip Bombs (clingFrame
   of the target), Pebble Chip / Roll (standNow = surfaceNow of the target + ground). None reads its OWN bones
   (bonePos / tip / gauntlet / TransformedWorldCFrame / st.bones): P3a cannot change them. (biteTarget reads own bones
   but is called from settle, which runs after the attack pose is applied.)
3. Menu: AI menu height = min(contentH, max(0, availableH)); fold button 44 x 40 on a 44 title bar (-44 in the height
   maths). Same 44 x 40 fold + clamp on the MOVE TEST menu (it opens folded on phones, so its [+] is the first tap).
4. NEW from James's phone test (base iPhone 17, ~96 AI units all fighting: "smooth, no lag I could notice"; menu fix
   build): the FPS readout sat top-right UNDER the AI menu, and it counted only MOVE TEST units. Now top-centre, counts AI
   units too, and the AI menu has a SHOW / HIDE FPS button (finds `WalkTestMenu.FpsLabel` by name). Tested: toggles,
   shows "FPS 144 worst frame 9 ms / 6 aliens", clear of the AI menu (x 1408-1658 vs menu from 2794).

## Regression (your item 4): foot-spike probe on EVERY foot bone, full 64-unit fight, 30 s per run, same Play session
Spike = a foot moving > 0.5 studs in one frame AND > 3x both neighbouring frames, frames where the whole unit's pivot
jumped > 1 stud excluded (server jumps, a known separate gate). Studio PC at ~60-140 fps (I can't cap Studio to 30 fps
from a script; say if you want another way).
| build | runs (spikes per 30 s fight) | mean |
|---|---|---|
| P3a skip OFF (current build with `if w < 1` forced true, i.e. the old double idle+attack solve every frame) | 92, 4, 187, 119 | ~100 |
| P3a skip ON (the real build) | 7, 0, 13, 23 | ~11 |
Forms spiking with skip OFF: Brute, Ram, Colossus, Drip; with ON: mostly Brute, some Colossus / Ram. So skipping the idle
solve did not add foot jumps; it removed most of them (my reading: the idle solve and the attack solve were fighting over
the same leg state every frame). Drip contact points: the collision shapes are back to the originals, so the surface rays
hit the same geometry as before tonight.

## Questions
A. Anything still wrong? B. Is the spike reading sound (or is the metric misleading)? C. Verdict ROBUST / ROBUST WITH
CHANGES / NOT ROBUST. Plain, no over-engineering.
