# Titan REDO build r1: please audit against YOUR spec (20-TITAN-REDO-SPEC v1.0, this chat's J1 / J2 / J3 / J4 / K sheets)

Attached: the whole new module (AttacksTitan.luau.txt, replaces the batch 2 Titan in A.FOR.SquishF4v5) and 12 Play-mode
stills from the real rebuilt geometry on the moon map (frozen attack clock, MOVE TEST), named by sheet and time.

## What was built
- K library (G6): titan_k.py -> one OBJ, 24 meshes imported into FX.GooMeshes: K1 crown 8.6 x 4.6 x 7.1, K2 crack 9.7 x 0.14
  (17 slate plates) + a cyan glow disc under it, K3 4 rocks, K4 3 drops, K5 ball 3.0, K6 splat 10.2 x 5.0 x 10.6, K7 puddle
  10.2 x 1.0 x 9.7 (domes), K8 wave 12.0 x 9.9 x 5.1 (920 tris, thick swept profile, 1.2 lip), K9 splash wall 14 x 11 x 3.9,
  K10 flood 12.5 x 0.23 x 30, K11 melt 13 x 1.45 x 12.4, K12 mote 0.62; functional: shock segment, whip ribbon, foam crest
  12.5 x 1.7 x 2.3, gather wall 12 x 5.6 x 4; defeat collapse shell + melt heap cut from the Titan's OWN mesh (its UVs + skin,
  decimated to ~3k tris each; 21.7 wide = its tentacle span). Goo meshes wear the SQUISH goo skin (UVs in its pure-goo
  patch); rocks slate, glow pieces neon. Still 00-K-meshes.
- G1 axis calibration (each chain turned 20 deg about each axis on the real rig): front spec rx = -X, front rz = +Z (+X side);
  back spec rx = +Y, back rz = -Z; Body / Top spec rx = -X; root P = -pitch. Mirrors (a, -b, -c).
- Keys = your tables except where measured (below). Ease codes E/O/I/L. Gameplay timing = the server's (slam hit 1.64 lock
  3.40; bomb spit 2.55 hit 3.40 lock 2.60; tsunami release 2.10 hit 3.20 lock 3.20); keys past a lock blend back over 0.25 s.
- Contact solver (post-pose, world space): an exact two-bone solve per chain (joint 2 bends to the target distance by the law
  of cosines, then joint 1 aims), capped at 16 deg per joint (= your 8 deg x 2 passes) x the contact weight; the back chains
  30 deg (your note "rear tips require a proper reach test"). A 2-joint CCD could not SHORTEN a reach (0.6-2.2 left over).
- Effects on your curves: K1 / K2 / K6 / K8 / K9 / K10 / K12 scale + opacity keys, the 8.4 shock table (12 authored segments
  round the 120-degree arc), 8.5 deterministic debris, the 5.4 bomb path (apex 13.2 measured), d(t) tsunami front edge,
  the 7.3 crossfades (body -> collapse shell 1.05-1.30 -> heap 1.70-2.55 -> K11 puddle), 16 golden-angle motes at 3.80
  (counted: 16). Sounds = your 9.2-9.5 layer times with licensed ProSoundEffects clips (Giant Crab Monster Roar 2.9 / 4.1 s,
  Body Impact for the falls, the existing wet slap / gurgle / splash / avalanche / quake), roll-off 10 / 85, EQ low -6 / mid +2,
  pitch +-4 %, gains x2 (this game's level; the old slam was 2.6), hierarchy kept.

## Measured deviations (please judge each)
1. Your contact keys buried the tips on this rig (slam 1.64: front tips 5 studs under ground; tsunami 2.10: 6.4 under;
   defeat 1.20: 7.2 under). Retuned UPSTREAM per your rule, driven by a raw-pose readout: slam front seg-1 rx +28 -> -37
   (1.64), +30 -> -35 (1.82), +15 -> -20 (2.08); tsunami front (-55, +70, 24) / (-53.., +72..) and back seg-1 rx 38 -> 70 with
   rz (73, -22, -16) (segments 2-3 fold IN: on this rig they point up from the elbow, so "down" opened the fold);
   defeat front seg-1 lifted ~55 from 1.20. RESULT (final, after the solver): slam both tips 0.00 from target, 0.12 over
   the ground (raw pose 0.93 / 1.05); tsunami all four 0.11 max (raw front 1.1-1.3, raw back 1.3-1.9).
2. Lean: your root P and Body rx STACK on this rig (Body is Root's child): slam 1.48 = 29 deg back (Top 19), stills show a big
   backward lean with the coiled tentacles in front of the face (J1-148-peak-front). Did you mean Body rx relative to root
   (stacking) or absolute? Should I halve it?
3. No Titan_SwellShell, no throat / cheek bulge meshes: the swell is your Top separation + crown lift + the glow ramp (you
   allowed it; I judged a transparent shell = the double contour you warned about). The bomb grows IN the mouth from 1.80.
4. The tsunami wave launches from the gather wall at 9.5 studs (not 0): the wall stands in front of the 6.5-stud body; the
   front edge then runs linearly to 30 by 3.20. Flood lane is one flat mesh at the cast's ground height (bumpy ground may
   cover bits).
5. Puddle / flood hold while the SERVER's slow lasts (bomb to 5.90, tsunami to 5.20), then fade 0.2-0.25 s (your 5.55 / 5.00
   were shorter than the real hazards).
6. No pooling (clone per cast, destroyed on stop): the perf audit you signed earlier rejected a general pool; per cast peak
   ~30-40 MeshParts.
7. Warnings stay the ground-hugging strip shapes (wedge / circle / lane, already audited in batch 2) rather than flat meshes
   (bumpy terrain), now shown from t = 0 (lock at 0.74 / 2.40 / 2.10 via their pulses).
8. My own look notes from the stills: crown and splat ARMS read thin (tubes 0.62 -> 0.24), K1 / K6 show fat blobby arms; the
   wave front reads as a thick slab (curl only visible from the side); K-goo is darker / bluer than the teal body.

## Verified in Play (main place)
All 25 attacks of all 8 forms 0 warnings (MOVE TEST), Titan Slam / Bomb / Wave / Defeat / Hurt 0 warnings; 16 motes.

## Please answer
A. Against your sheets + spec, per attack: GO / NO-GO, and the exact changes (numbers) for each NO-GO.
B. Rule on deviations 1-8 (keep / change).
C. Anything in the code that is wrong or fragile. Plain, no over-engineering.
