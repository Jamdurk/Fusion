# Alien Fusion performance audit: measured findings (29 Oct 2026, Claude)

Test bed: `AlienFusion-AI-Testing.rbxl`, Studio Play on James's desktop PC (server + client in one process).
Instrumented with test-only timers and switches in `src-aitest` (player attributes `AnimMs`, `AnimAiMs`, `AnimFps`,
`AnimBoneWrites`, `AnimEvMs`, `AnimFxMs`; switches `DbgNoAnim`, `DbgNoBones`, `DbgNoPivot`, `DbgNoGlow`, `DbgNoRay`;
server `SimStepMs`, `SimStepMaxMs`). 64 units = 32 a side, every form.

## Client, 64 units standing (AI off, so no attacks)
| what was switched off | fps | animator script ms / frame |
|---|---|---|
| nothing (normal) | 52-55 | 3.4-3.6 |
| per-frame glow write (`SurfaceAppearance.EmissiveStrength`) | **113** | 3.3 |
| ground raycasts | 56 | 2.9 |
| bone writes | 55-57 | 2.2 |
| model moves (`PivotTo`) | 56 | 2.5 |
| bones + moves + glow | 144 (cap) | 1.2 |
| all AI animation | 144 (cap) | 0.05 |
Bone writes: about 1,150-1,190 per frame (all 11-20 bones of every unit, every frame).
Models are lean: 2 parts each (1 skinned MeshPart + hitbox), 11-20 bones.

## Client, 64-unit fight
- Normal: 46 fps at the start, 33-41 fps mid-fight; animator script 6-14 ms / frame.
- Glow writes off: 89 fps at the start, 48-65 mid-fight.
- Mid-fight script split (glow off): attack effects ticking 1.3-2.1 ms, attack events firing (creating effects)
  0.5-0.8 ms, **everything else 7-9 ms** (attack posing: keyframe interpolation into new tables per bone, bones written
  2-3 times per frame, contact / reach corrections reading bone world positions, plus walking units).
- Up to about 1,200 effect instances alive at once; the particle budget (34/s) sat at its cap.
- Bone writes in a fight: about 1,740-1,840 per frame (attacks write bones more than once).

## Server
- 20 Hz step: 0.26 ms standing, 2.7 ms average / 4.8-7.9 ms worst in a 64-unit fight (budget 50 ms): fine.
- Network: 9.4 messages / s, each with all 64 unit states as 6 plain numbers (id, the same timestamp repeated per
  unit, x, z, facing, speed) + about 19 events / s. Estimated (8 bytes per number + table overhead, Studio doesn't
  report local bytes): about 4 KB per message, about 40 KB/s per player.

## Static findings (code)
- `apply()` recomputes `rest:Inverse()` for every bone every call and writes every bone, even unchanged / identity.
- `newPose()` allocates a table, a closure and a 6-number table per bone per call; `Attacks.pose` allocates a 6-number
  table per bone per frame (`lerp6`); attacks build a `held` table of every bone per frame; local `at()` closures per
  unit per frame.
- Hot-path `GetAttribute` reads per unit per frame (FormName, AiId, FreezeTT, MoveTest, AimTest, AiAimX/Z).
- Test scaffolding in runtime paths: test hooks (force / ghost / arm / preshield / kill / dodge), readout attributes
  written every 15 frames for every unit, profiler wrappers, `Dbg*` switches.
- Two diverging copies: `src` vs `src-aitest` (AlienAnimator, AttacksCrunch, AttacksDrip). `Attacks.module` is 181 KB.
- Effect parts are already cheap (Anchored, CanCollide / CanQuery / CanTouch / CastShadow off, parented last).
