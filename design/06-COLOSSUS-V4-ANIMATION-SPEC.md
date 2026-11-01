# Colossus v4: animation overhaul spec (ChatGPT, Thinking high, 27 Oct 2026 ~9:50 PM)

This is the pilot only. James asked for "an animation overhaul that matches it" and will decide after he sees a video. The text below is condensed from ChatGPT's answer, numbers kept exact. ChatGPT's verdict was **GO**: rebuild the rig to 15 bones and get the walk IK working first.

## Rig: 15 bones (LOCK)
Ten existing bones, plus:
- **ShinL / ShinR:** knee at ~23 % of height.
- **FootL / FootR:** ankle at ~6 %.
- **Belly:** between Hips and Chest, ~55 %.

Hierarchy: Root → Hips → Belly → Chest → Head. Legs hang off Hips, arms off Chest.

An optional Crown bone was skipped; the crown stays rigid to Chest. Stone plates are rigid to their bone, so the deformation hides in the magma gaps.

## WALK (12 studs/s)
**Timing:** stride 14 studs per cycle. A full cycle takes 1.167 s, so an impact lands every 0.583 s.

**Feet and legs:**
- Foot lift 0.95.
- Knee bend: 12° at impact, 38° at passing.
- Foot pitch: heel strike +9°, toe-off −13°.

**Body:**
- Hips shift ±0.55 toward the supporting foot and roll ±4.5°.
- Root dips −0.32 over 0.10 s at impact, then rises +0.16 in recovery.
- Constant forward lean of 6°.
- Counter-yaw: Belly ±5°, Chest ±4° (opposite to Belly).
- Arms swing ±10°, 0.10 of a cycle late. Hands lag ±7°, a further 0.08 late.
- Head cancels about 75 % of the chest's pitch and roll.

**Per-foot phase q** (left foot contacts at p = 0, right at p = 0.5):

| q | What happens |
|---|---|
| 0 | Heel contact and a short dip |
| 0–.08 | Contact hold; chest and gauntlets keep settling |
| .08–.40 | Weight rolls over the planted foot |
| .40–.54 | Heel rises, toe-off |
| .54–.74 | Swing; knee flexes toward 38° |
| .74–.92 | Foot comes down; leg extends |
| .92–1 | Brake into the next contact |

Swing motion uses quintic smootherstep.

**Foot lock:**
- On contact, cache the foot's world target. Through stance, solve the 2-bone IK against that fixed point.
- During swing, move from the last plant to the next raycast-grounded target on an arc that peaks at 0.95.
- Knee pole points forward.
- **Measure the real bone lengths.** If the stride isn't reachable, cut it to 12–13 rather than clamping and calling it a lock.
- Root offsets are cosmetic only; never move the model pivot to solve IK.

## RUN: "stone charge" (19.2 studs/s)
**Changes from the walk:**
- Stride 20, cycle 1.042 s.
- Foot lift 1.35, passing knee 52°.
- Lean 14°.
- Lateral shift ±0.4, dip −0.48, roll ±3°.
- Arms ±16°; gauntlet lag 0.12.

**Feel:**
- Stance is ~50 % of the cycle, with almost no double support.
- The swing leg moves early, then brakes hard before contact.
- The chest stays fairly rigid and the fists trail behind the body.
- No jumping.

## IDLE
**Body:**
- Breathing cycle 5.5 s: chest expands 1.5°, torso moves ±0.08.
- A weight shift every 6–9 s: ±0.20 sideways, hip roll ±1.5°.

**Gauntlets, head, feet:**
- Gauntlets settle ±2°, 0.3 s late.
- Head looks around: random ±8° yaw every 8–12 s, pitch ±3°.
- Feet stay world-locked.

**Glow and fists:** the core pulses faintly with each breath. The fists tighten with a slight inward rotation.

## Footfall feedback
Every effect fires on the gait's contact events, never on a separate timer.

**Essential:**
- A heavy thud per planted foot.
- Dust: 6–8 particles, 0.4–0.7 s lifetime, 1–3 studs/s.
- Emissive pulse: 1.4 → 2.0 → 1.4 over 0.30 s.

**Important:** camera shake up to 0.10 studs for 0.18 s within 35 studs, fading to zero by 70. Global cooldown 0.35 s.

**Optional:** a 1–2 particle steam burst (0.6–0.9 s). Pebbles are deferred.

**Budget:**
- About 24 burst particles/s per client, on top of the aura budget.
- 2 particles per burst at 60–120 studs; none beyond that.
- Use `:Emit(n)` on disabled emitters.

## Video PASS checks
- Planted feet slide less than 0.3 studs.
- Knees flex; no wooden legs.
- The body shifts over the support leg.
- Gauntlets lag, then settle.
- Head stays steady.
- Sound, dust and pulse land on the actual contact.
- No plate separation, knee inversion, floating feet or ground penetration.

**Footage to capture:**
- Walk: 8 s front three-quarter, then 6 s side view on a slope.
- Charge: 6 s side view.
- Idle: 5 s, then into the walk.
- One close-up of a footfall.

**Signature:** "Plant → compress → drag the weight forward → lift → THOOM."
