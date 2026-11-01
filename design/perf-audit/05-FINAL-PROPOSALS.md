# Alien Fusion performance: FINAL proposals (29 Oct 2026; Claude's measurements + ChatGPT audit r1 "SOUND WITH
CHANGES", `04-CHATGPT-AUDIT-r1.md`). NOTHING BUILT. Evidence: `01-MEASURED-FINDINGS.md`.

Principle (James): small changes, measured wins, no framework. Each step is measured before the next; stop as soon as
the phone runs well.

## Approved to build
1. **P9a, one source of truth.** The AI test place's animator / Crunch / Drip modules are ahead of the main game's
   copies. Make the main `src` the one canonical copy; the test place keeps only its own server harness and menu.
2. **P1, glow (biggest win: 55 -> 113 fps standing, 46 -> 89 at a fight's start, 64 units, PC Studio).** Set each
   alien's glow once at spawn; remove the per-frame glow writes (3 places). Then test attack glow boosts as at most 3
   fixed levels written only when an attack changes state. Keep them only if they don't eat the win. Measure: fps,
   frame time, draw calls (Render Stats), for original / static / static + attack levels. James judges the look.
3. **P5, physics + shadows (template edits).** Visible mesh: CanCollide / CanTouch off, CollisionFidelity Box,
   CanQuery off if nothing queries it. Hitbox: collisions + touch off; queries off only after checking targeting,
   selection and ground / contact rays don't use it. Shadows off on F1 / F2 (keep F3 / F4).
4. **Phone test NOW** (moved up): private test copy, 64 units, 3 minutes, a midrange Android + an iPhone (James's
   phone at least): fps, frame pacing, memory, heat. This decides everything below.
5. **P3a, bones (low risk).** Cache each bone's rest inverse at setup (recomputed every bone every frame now); cut the
   repeated bone writes in attacks (bones are written 2-3 times per frame now) wherever the contact / reach
   corrections don't read the intermediate pose. No custom skeleton system.

## Only if the phone test shows the matching cost
- **P2, animation level of detail:** ONE rule: small-on-screen / far units animate at ~20-30 Hz, off-screen units skip
  pose + IK but keep their attack clocks, events and world effects running; visibility by a padded screen box, not the
  centre point; thresholds from the real phone camera (how many units are visible and how big).
- **P4, allocations:** start with `newPose()` + `lerp6()` writing into one reusable buffer per unit; only if allocation
  / GC numbers say so; never share a buffer with a detached attack instance.
- **P7, effects:** first drop tiny decorative pieces (droplets, pebbles) at a distance and cap decorative debris;
  NEVER warnings, beams, projectiles, shields; count what the ~1,200 live pieces actually are first. No general pool.
- **P6, network:** first one timestamp per message on the current remote and a REAL bandwidth reading on a separate
  client; only then a packed buffer (coordinates sized to the real map bounds, with a range check; a sequence number
  if it moves to an unreliable remote; spawn / attack / cancel / shield stay reliable). No delta scheme.
- **P8, small:** cache FormName / AiId at setup; ground-raycast caching per foot only if it stays simple;
  RenderStepped -> PreRender as housekeeping (no speed gain).
- **P9b:** strip the test hooks / readouts from the game build with one DEBUG constant (keep the test harness);
  split the 181 KB Attacks module only when creature work needs it.

## Not building (no evidence it's needed)
Parallel Luau / Actors, a custom skeleton renderer, an animation job scheduler, a network delta framework, a general
effects pool, a material manager, server AI optimisation (2.7 ms of 50 ms), dummy Humanoids (tested: no gain),
impostors.
