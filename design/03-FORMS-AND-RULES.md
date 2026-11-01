# Forms + core rules — RULES LOCK v1 (27 Oct 2026)

James's ask: 4 forms per race. Base → 2nd (merge 2 base) → 3rd (merge 2 of the 2nd) → 4th (merge 4 of the 3rd).
Audited by ChatGPT (Thinking, "Rules Lock v1: GO WITH CHANGES"); Claude agreed. Change this file only with a new audit.
Items marked ★ are new design choices from the audit that James hasn't seen yet — confirm with him.

## 1. Matter maths (LOCKED)
| Form | Name | Made from | Matter | Max per army (32) |
|---|---|---|---|---|
| F1 | Swarm | — | 1 | 32 |
| F2 | Pack | 2 × F1 | 2 | 16 |
| F3 | Brute | 2 × F2 | 4 | 8 |
| F4 | Titan | 4 × F3 | 16 | 2 |
- **Army = 32 matter per player** (was 24: 24 can't make two Titans). Mixes are allowed (e.g. 16 + 8 + 4 + 4).
- 1v1 full swarm = **64 small units** on screen. Design + profile for that.
- Split = the exact reverse. Max two Titans comes from the cap, no extra rule.

## 2. Merge / split rules (proposed canonical)
| Change | Needs | Animation |
|---|---|---|
| F1 → F2 | two F1 within 6 studs | 0.45 s |
| F2 → F3 | two F2 within 9 studs | 0.70 s |
| F3 → F4 | four F3 within 18 studs of their centre | 1.40 s |
| F4 → F3 | one F4 → four F3 | 0.90 s |
| F3 → F2 | one F3 → two F2 | 0.55 s |
| F2 → F1 | one F2 → two F1 | 0.35 s |
- 5 s transformation lock on the result (no instant merge/split flipping). Vulnerable while transforming.
- Player-commanded with an auto-pick of the nearest eligible group (no fiddly dragging on phones).
- Damage carries through as the matter-weighted average HP %; merging/splitting never heals.
- ★ Defeated matter returns to the base reserve after **12 s** and respawns as F1 (32 = slots, not lives).
- Server-authoritative: matter conservation, cooldowns, combat.

## 3. Counters + starting stats (prototype values, both races identical)
Loop: **Swarm beats Titan → Titan beats Brute → Brute beats Pack → Pack beats Swarm.**
| Form | HP | DPS | Speed (studs/s) | Special |
|---|---|---|---|---|
| F1 | 100 | 12 | 22 | ×2 vs F4 when 6+ F1 surround it |
| F2 | 235 | 20 | 19 | cleaves up to two F1 |
| F3 | 650 | 48 | 16 | ×1.5 vs F2 |
| F4 | 2,400 | 100 | **8** (was 12; James 27 Oct: big forms slower is fine, their legs can't take giant steps at 12) | ×1.8 vs F3, ×2.5 vs bases; forward attack + slow turn (no 360° wipe) |
Acceptance = automated equal-matter battles show each advantage without a fixed winner.

## 4. Map (James: "double")
- World **1,008 × 672** (2× length and width). Main combat footprint ~720 × 440. Bases at x = ±395 (790 apart).
- ★ **Forward deployment gates** at x = ±220 (launch beam / orbital drop): first swarm contact ~10 s.
- Crater radius 80-85. ★ Crater relay: capture to weaken the enemy base shield (no extra matter).
- ★ Small fusion-charge vents on the north + south routes (temporary fusion-cooldown edge).
- ~160-220 placed props (not 368), cheaper background dressing.
- Streaming: Enabled, MinRadius 64, TargetRadius 512 (test 1024), ModelStreamingBehavior Improved,
  IntegrityMode PauseOutsideLoadedArea, StreamOut Opportunistic; Atomic for compact structures.
- Match 210 s (cap 240). Final size lock after a **64-unit phone stress test**; keep the smaller map buildable (A/B).

## 5. The eight models
One armature per race, same bone names + compatible rest pose for all four forms; new geometry around it.
| | F1 | F2 | F3 | F4 |
|---|---|---|---|---|
| SQUISH | Droplet 2.5×2, 2.2k | Doubleblob 4×3.5, 3k: wider double-lobed body, 2 glowing spots, oversized eye | Blobster 6.5×6, 4.5k: four-lobed beast, 4 luminous cores, broad feet, raised head | Mega Squish 13×11, 7.5k: giant cyclops, wobbling crown, 16 spots in 4 clusters, massive feet |
| CRUNCH | Pebblebug 2×3, 2.6k | Shellback 3.5×4.5, 3.5k: broader, 2 paired shell sections, bigger forelegs | Shardhorn 6×8, 5.5k: 4 interlocked shell sections, thick angular body, big crystal horn | Mountainback 12×14, 9k: huge quadruped, 4 plate ridges holding 16 shards, enormous horn |
- Rigs: SQUISH 7 bones (Root, Body, Top, FootFL/FR/BL/BR); CRUNCH 8 (Root, Body, Head, Shell, LegFL/FR/BL/BR).
  Extra lobes / crowns / plates follow existing bones (no extra bones).
- Textures: F1-F3 512 PBR (F3 may go 1024 if it visibly helps), F4 1024. Hero meshes < ~10k tris. No transparent shells.
- Animation reuse: F1/F2 share locomotion (size-adjusted); F3 heavier variant; F4 its own locomotion, attacks,
  collapse/split. Verify reuse in Studio (same bone names ≠ same motion when proportions differ).

## 6. Intimidation progression + auras (ChatGPT GO, 27 Oct; James: "cool, more intimidating as it progresses, aura effects")
Silhouette test at phone size: **Baby → Troublemaker → Monster → Boss** — readable WITHOUT the aura (effects amplify, never rescue).
| | SQUISH | CRUNCH |
|---|---|---|
| F1 | keep exactly (innocent cyclops) | keep (cute beetle) |
| F2 | one side of the brow lowered, deeper cyan, sharper twin peaks | broader legs, forward-leaning shell, thicker horn |
| F3 | heavy asymmetric brow, narrow (slit) pupil, sideways sneer with two blunt fangs, three big swept-back goo spines | jagged shoulder armour, sharper crystal ridge, narrowed glowing eyes |
| F4 | broad + low, head leaning forward, massive overhanging brow, 5-6 SUBSTANTIAL goo horns (not thin spikes), wide dark angular mouth with 4-6 blunt cartoon fangs, indigo underneath / cyan top + bright cyan veins, big front feet | huge forward horn, raised dorsal crystal blades, glowing magma fissures, massive forelegs |
Kid-safe (Mild): no saliva, blood or realistic horror. Keep SQUISH's giant single eye on every form.

**Auras (client-budgeted, built in Roblox; Blender renders the flipbooks):**
| Form | Particles/s | Lights | Effect |
|---|---|---|---|
| F1, F2 | 0 | 0 | none (64-unit swarms cost nothing) |
| F3 | 1-2 | 0 | SQUISH small rising cyan bubbles + pulsing spots; CRUNCH sparse falling orange sparks (0.5-0.8 s life) |
| F4 | 5-8 | ≤1 (budgeted) | SQUISH bigger bubbles, violet accents, slow vein pulse, goo ripple ring on stomp/fuse; CRUNCH rising embers, footstep dust bursts, fissure pulse, impact ring |
Whole client: ~50 aura particles/s cap; nearest F4 then F3 first; no aura particles beyond ~100 studs; ≤2 alien PointLights near the camera (Shadows off, range 10-14); fusion/split bursts via Emit(); one ground ring per Titan attack; no transparent aura spheres or continuous dust clouds.
**Rigs:** keep SQUISH 7 / CRUNCH 8 bones; brows/spines/crowns follow Top or Body, horn → Head, armour/crystals → Shell; rigid parts get mostly single-bone weights. Optional SQUISH F4 Jaw bone only if the mouth must open (default: static open mouth).

## 7. Model sign-off (ChatGPT r3, 27 Oct): ALL 8 GO
- Built by `assets\blender\scripts\aliens_forms.py`; renders `assets\textures\aliens\*_hero.png`, sheet `shots\05-forms-sheet.png`.
- Heights (studs): SQUISH 2.3 / 3.9 / 6.1 / 11.6; CRUNCH 2.6 / 3.7 / 6.6 (9.5 with crest) / 17.8 (with plates + horn).
- **Colliders:** simple body-sized box per form; crest, horn, plates and crystals never drive collision or path width.
  Combat hit detection is separate from movement collision.
- Before animation export: every form keeps the same upright rest orientation, root convention and foot-contact plane.
- Animation QA: test extreme poses (attack, idle squash) for clipping of SQUISH F4 teeth/maw and CRUNCH horns/spikes.
