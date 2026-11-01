# Alien Fusion perf build r1: please audit the BUILT code (you approved the plan as "SOUND WITH CHANGES" earlier in this chat)

Built tonight, exactly the four you approved first, plus a phone menu fix James asked for mid-way. Nothing else changed.

1. P9a one source: AlienAnimator / AttacksCrunch / AttacksDrip moved from src-aitest\ into src\ (the AI-test copies were
   strict supersets of src\: src\ versions 03:00-11:44, AI copies made from them at ~12:00). Verified at install: all 7
   scripts in the AI-test place are byte-identical to the files. src-aitest\ now holds only the harness (server, Brain, menu).
2. P1 glow: `setGlow(st, es)` (see animator.diff) replaces the 3 per-frame `EmissiveStrength` writes. 3 levels per form:
   out (es < 0.5 x base) -> 0, base, bright (es >= base + 0.25) -> base + 0.6. Written only when the level changes.
   Form bases are 1.0-2.0. Attack beats add +0.4 / +0.8; Thump flare glowMul up to ~1.9; hurt dip glowMul 0.88; defeat
   glowMul -> 0; idle breath +0.10-0.12 (now below the threshold, so gone); MOVE TEST footfall pulse +0.6.
   NOT touched (P7 territory, short-lived effect parts): the gooed overlay pulse (one per gooed target), the defeat
   rubble seams (1.7 s).
3. P5 templates (perf-p5-templates.luau): all 15 templates: mesh + Hitbox CanCollide / CanTouch / CanQuery off, mesh
   CollisionFidelity Box, Hitbox CastShadow off, F1 / F2 meshes CastShadow off. Checked every script in the place for
   Raycast / Hitbox / Touched / GetPartsIn / Mouse.Target: ground rays include Terrain only; the Drip's surface rays
   include ONLY the target's mesh and set `mp.CanQuery = true` client-locally themselves; PolishKit Looks rays are an
   Exclude-list lighting probe. No click selection exists.
4. P3a bones: `e.inv` = rest:Inverse() cached at setup. In runAttack the idle pose under an attack (apply(ip) + an idle
   solveLegs + the `held` snapshot) now runs only when the blend weight w < 1 (blend-in 0.2 s, blend-out 0.25 s, and
   after the body ends). w is computed BEFORE (same formula, moved up; 0 once tt >= dur). Full runAttack and solveLegs
   are attached so you can check the state side effects of skipping the idle solve (leg.stand, leg.from handoff T,
   plants, lastK, st.over, drawnP). Note: non-travel attacks called the idle solve and the attack solve with IDENTICAL
   arguments; travel attacks (Ram charge) called the idle solve with (base, 0, at, standing) then the travel solve with
   (pivot, trS, trAt, trStand). The Titan contact re-apply (0.26 s window) is left as is.
5. Phone menu (menu.diff + the MOVE TEST part of animator.diff): James on his phone: "menus massive, can't minimise the
   AI one, can't scroll it" (it was ~800 tall on a ~390-tall screen, only an inner list scrolled). Now a title bar with
   [-] fold, one ScrollingFrame body capped to the screen, UIScale clamp(viewportY / 600, 0.8, 1); MOVE TEST starts
   folded on touch-only screens. Tested in Studio: fits (1391 of 1471), canvas 1788 scrolls, fold -> 30 tall, unfold ok.

## Measured (Studio Play on James's PC, 64 units = 32 a side, all 8 forms, same session, same fight script)
| build | standing fps | fight start fps | mid-fight fps (13 samples x 2 runs) | animator ms mid-fight |
|---|---|---|---|---|
| ORIGINAL animator (P5 templates in place) | 49-62 | 50-56 | 30-46, median ~38 | 8-16 |
| NEW animator + P5 | 116-129 | 99-114 | 36-69, median ~47 | 7-13 |
| NEW animator, P5 reverted | 114-124 | 100-107 | 36-72, median ~50 | 7-13 |
Static glow (no writes at all) vs the 3 levels, standing: 123-129 vs 116-129 (same within noise).
Mid-fight switch test (new build): DbgNoBones 72-81, DbgNoPivot 39-62, DbgNoAnim 119-141 -> the remaining fight cost is
attack posing (script ~10 ms), i.e. P2 / P4 territory, waiting on the phone test as you ordered.
P5 shows no PC gain (honest); kept because it is the standard cheap setting and may matter on phones.

## Questions
A. Any correctness bug in setGlow, P3a's skip, or the menu? (Especially: P3a state side effects for travel attacks and
   for the first frame after a resetFeet; setGlow when st.glow is 0; UIScale + AbsoluteContentSize math.)
B. Is keeping P5 (no measured PC gain) right, or revert it?
C. Verdict: ROBUST / ROBUST WITH CHANGES / NOT ROBUST, with exact required changes. Plain, no over-engineering.
