# Colossus animation batch 1 (28 Oct 2026): spec (ChatGPT Thinking high, "GO WITH IMPLEMENTATION CHANGES")

First of the per-alien animation batches (James: "you do all the animations for one monster, I check them, tick it off,
then the next"). Keeps the three attacks from `07-COLOSSUS-V4-ATTACKS-SPEC.md`; adds what the power graph
(`09-POWER-GRAPH.md`) needs plus HURT and DEFEAT. Code: `src\ReplicatedStorage.AlienFusion.Attacks.module.luau`
(timelines), `src\StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau` (playback), `src\ServerScriptService.WalkTest.server.luau` (MOVE TEST).

## Timing contract (three clocks: server combat, actor pose, world effects)
| | Warning | Hit | Body free (lock) | Effects end |
|---|---|---|---|---|
| GROUND SHATTER | 0.64 | 1.64 | 3.40 | 3.80 |
| BOULDER HURL | 2.40 | 3.40 | 2.60 (after release) | 4.70 |
| SOLAR STRIKE | 2.00 | 3.20 | 3.20 | 6.20 |
| HURT | - | - | no lock (additive) | 0.52 |
| DEFEAT | - | - | terminal | 3.80 |
After the lock the pose blends back in 0.25 s; projectiles, beams and burns keep playing at their captured world spots.

## Danger shapes (CRUNCH = wedges, cracks, straight lines; the whole boundary shows at once and never shrinks)
- SHATTER: 120-degree wedge, 16 studs from the centre; dim area + a bright fill advancing r = 6 + 10*smoothstep((t-0.64)/1.0);
  2 pulses from 1.44; 6 straight fracture lines; gone at 1.64. The crystal ring after the hit may be bigger (spectacle).
- BOULDER: jagged octagon, true radius 4, fill 15 -> 40 %, 4 inward fracture marks lighting in turn 2.90-3.25, a strike
  cross, 2 pulses 3.25-3.40. The spot is fixed when the throw starts.
- SOLAR: fractured 12-sided target, radius 8, 4 thick crosshair bars, 8 inner cracks; fill brightens 2.00-2.70, cracks
  glow 2.70-3.05, crosshair flares 3.05, 2 flashes to 3.20.
- Colours: basalt #756F69, amber #FFAA28, magma #FF6E19, near-white #FFE6A0. Emissive strips, no lights.
- (Added in testing) every amber outline line has a darker basalt edge under it: on sunlit ground the amber alone faded.

## Aiming (Boulder + Sun aim at a world point picked at cast start; d = distance, theta = angle off facing, left +)
- k = clamp((d - 12) / 18, 0, 1). At theta = +30: root +10, hips +2, belly +5, chest +9, head +4, shoulders +4 (scaled,
  mirrored). Boulder turns 0.40-1.85, Sun 0.40-1.60, then holds through the release / strike.
- BOULDER by distance (12 / 21 / 30): overhead arms 145 / 150 / 155; release arms 105 / 95 / 85; release hands 24 / 22 / 20;
  root fwd .35 / .50 / .65; root pitch 12 / 14.5 / 17; belly 11 / 13 / 15; chest 12 / 14.5 / 17; arc height 5 + 4k; flight
  always 0.85 s. Wind-up / release torso twist cut to about +5 / -3 so it never faces away from the target.
- SUN by distance (12 / 30): right arm 162 / 172 at 2.30, drive 95 / 105 at 3.20, right hand 13 / 16, left brace 25 / 30;
  the sun hangs clamp(0.55 d, 8, 16) studs along the line to the target, 30 up; the beam hits the target.

## HURT (0.52 s, additive; full in walk / idle, 35 % during an attack; stun-immune)
Keys (R lift, side, fwd, pitch | P H/B/C/N | yaw H/B/C/N | arms L/R | hands L/R), for a hit pushing it right (mirror for left):
0.05 out (-.04, +.06, -.04, -1 | -1/-2/-3/+2 | 0/+1/+2/-1 | -4/-7 | -2/-3); 0.13 in (-.12, +.14, -.09, -3 | -1/-3/-5/+3 |
+1/+2/+3/-2 | -9/-12 | -4/-5); 0.24 smooth (-.06, +.10, -.04, -1 | 0/-1/-3/+1 | 0/+1/+2/-1 | -5/-7 | -2/-3); 0.40 smooth
(0, +.03, 0, 0 | 0/0/-1/0 | 0/0/+1/0 | -2/-2 | -1/-1); 0.52 zero. Trigger: a single hit >= 8 % max HP (192), 0.65 s cooldown.
Effects: 0.00 two stone chips + a quiet shale crack; 0.08 three sparks + a small crystal tick; 0.13 magma -12 % for 0.08 s +
a low stone knock. No shake, no light. Added into the pose BEFORE the leg IK so the planted feet never move.

## DEFEAT (3.8 s, kid-safe)
Keys: 0.16 out (-.12, +.16, -.10, -3 | -2/-3/-3/+2 | +2/+3/-3/+1 | -12/-20 | -6/-8); 0.48 out (-.30, +.28, -.15, -7 |
-4/-6/-8/+5 | +3/+4/-6/+2 | -25/-32 | -9/-12); 0.80 smooth (-.25, -.10, +.05, +3 | +1/+3/+4/-3 | -1/-3/+4/-1 | +8/+14 |
+4/+6); 1.10 in (-.90, +.35, +.20, +9 | +5/+8/+9/-5 | +2/+4/-3/+1 | -8/+30 | -7/+9); 1.42 in (-1.75, +.55, +.38, +14 |
+8/+11/+12/-8 | +3/+5/-5/+1 | -18/+38 | -12/+11) right knee down; 1.65 out (-1.95, +.58, +.47, +17 | +9/+13/+15/-9 |
+3/+3/-3/+1 | -25/+16 | -15/+5); 2.05 smooth (-2.10, +.65, +.52, +22 | +11/+15/+17/-10 | +3/+2/-2/0 | -30/-12 | -15/-8), held.
Left gauntlet braces on the ground 1.35-2.1 (IK). Magma dims from 0.72, dead by 2.1; crack flash 1.90.
2.10: the body is replaced by 8 scripted rock groups (crown, 2 gauntlets, 2 shoulders, torso, 2 hips), 2-5 studs out,
1-3 up, 30-90 degrees of tumble; 5 fade by 3.1, 3 stay as rubble and sink 0.9 by 3.8. 2.20-3.45: exactly 16 amber motes
(4 groups of 4) rise 1-4 studs, then streak ~45 studs toward the home base and fade (no lights, no emitters).
Sounds: shale (0.00), tumble (0.35), lava fading (0.72), stomp + shale accent (1.42), quiet low glass (1.90), short
avalanche (2.10), soft power tail (2.20), whoosh (2.65), quiet tumble (3.10).
The matter refund and damage are SERVER rules (never depend on the client finishing the animation).

## Budget (from 07, enforced)
2 detailed attacks at once, < 35 extra particles/s, 24 fragments, 2 lights, 1 camera shake. Per event: Shatter 4 charge
sparks, 8 dust + 6 sparks, 4 later; Boulder 6 / 4 / 8 dust + 4 sparks; Sun 6 pre-hit, 8 dust + 6 sparks, continuous
emitters ~13/s combined during the brief overlap; Hurt 3 sparks + 2 chips; Defeat 5 + 7 dust, 3 sparks, 8 rocks, 16 motes.

## Studio checklist (batch 1)
Shatter wedge 0.64 -> 1.64; Boulder hits its target at 12-30 studs / -30..+30 degrees; walking can blend from 2.60; Sun
ring 2.00, sun 2.30, beam 3.20, its spot stays put; Hurt 0.52 additive, no stun; Defeat knee ~1.42, 8 chunks, 16 motes,
clean by 3.80; feet slide < 0.3; within budget.
