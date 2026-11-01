# Colossus v4: three attacks spec (ChatGPT Thinking high, 27 Oct 2026 ~10:50 PM; verdict GO)

James asked for three attack animations on the v4 pilot to test the method before the full power design. He specified A and B; C was mine to design (Boulder Hurl). ChatGPT kept C because it gives one close ground hit, one charged beam and one heavy projectile.

## Conventions
ChatGPT's tables use these:
- **Body pitch:** positive means bending forward. I negate it for `pose.rot`, where +rx lifts the nose.
- **Arms and hands:** positive means swinging forward and up.
- **Root F:** positive means along −Z (forward).

All values are offsets from rest. Easing:
- Anticipation: cubic ease-out.
- Hang: still, with a 1–2° tremor.
- Strike: cubic ease-in.
- Impact: a 0.06 s compression.
- Recovery: smoothstep with a small overshoot.

Attacks blend in and out over 0.15–0.25 s. Feet stay world-locked (IK).

## A. GROUND SHATTER (3.80 s)
**Read:** both huge fists smash down and a circle of amber crystals bursts up. It is the ground breaking, not a fire explosion.

Key poses (R = root lift / side / fwd / pitch; H/B/C/N = hips / belly / chest / head pitch):

| t | R | H/B/C/N | Arms | Hands | Moment |
|---|---|---|---|---|---|
| 0.40 | +0.15, 0, −0.2, −6 | −4/−7/−5/+4 | +65 | +12 | fists rise |
| 1.10 | +0.25, 0, −0.4, −9 | −5/−9/−7/+6 | +158 | +15 | overhead |
| 1.32 | +0.20, 0, −0.4, −10 | −5/−9/−8/+7 | +165 | +15 | hang |
| 1.64 | −0.85, 0, +0.6, +22 | +12/+22/+20/−12 | −10 | −12 | **impact** |
| 1.83 | −1.0, 0, +0.75, +25 | +12/+23/+18/−10 | −15 | −15 | follow-through |
| 2.45 | −0.45, 0, +0.3, +12 | +5/+9/+8/−5 | +15 | +4 | recovery |
| 3.40 | 0 | 0 | 0 | 0 | neutral |

At 1.64 the gauntlets are IK-solved to ground points 4–6 studs in front and 3.5–4.5 apart.

**Effects:**
- 0.85: glow 1.4 → 1.8, wrist sparks.
- 1.32: 2 amber lights.
- 1.64: 14 dust (#756F69).
- 1.67: crack ring, radius 3 → 13 over 0.3 s.
- 1.73: 12 crystals, 1.4–3.2 tall, rising in 0.22 s.
- 2.05: the crystals crack and tilt 10–20°.
- 2.35–3.2: the crystals sink.

**Shake:** 0.22 for 0.24 s within 25 studs, fading out by 75.

**Sounds:**
- 0.35: stone grinding
- 1.08: charge rumble
- 1.64: heavy stone impact (mid-range crack over a short bass hit)
- 1.70: crystal break
- 2.35: gravel

## B. SOLAR STRIKE (5.30 s)
The right arm charges and the left braces. **Read:** one glowing fist straight up, a mini sun visibly growing, then a thick beam hitting the ground.

| t | R | H/B/C/N | Arms L/R | Hands L/R | Moment |
|---|---|---|---|---|---|
| 0.40 | −0.15, +0.15, 0, −4 | −3/−4/−5/+5 | +20/+70 | +12/+10 | draw up |
| 0.95 | 0, +0.25, −0.2, −7 | −4/−6/−5/+7 | +25/+160 | +15/+15 | fist skyward |
| 1.80 | 0, +0.25, −0.2, −8 | −4/−7/−5/+9 | +25/+165 | +15/+15 | sun grows, tremble |
| 2.35 | −0.12, +0.2, 0, −10 | −5/−8/−6/+10 | +30/+170 | +12/+15 | peak charge |
| 2.55 | −0.35, 0, +0.2, +9 | +5/+8/+12/−8 | +20/+125 | +8/+15 | **fire** |
| 3.10 | −0.25, 0, +0.15, +7 | +4/+6/+7/−5 | +15/+95 | +8/+10 | follow-through |
| 4.15 | 0 | 0 | +5/+25 | 0/+5 | settle |

Yaw from 0.95 to 2.35 is +4/+6/+5/−8 (hips / belly / chest / head), back to 0 by 2.55. Wrist tremor is ±1.5° at 12 Hz.

**Effects:**
- Sun: 0.8 → 3.4 across, with a ~4.5 corona.
- Light on the right hand: 1 → 2.5, range 14.
- 2.35: warning circle, 8 across.
- 2.55: beam, 2.4 wide.
- 2.62–5.12: burn patch, 9 across, with embers.
- Colours: core #FFE69A, corona #FFAC24, beam #FFF2B5, burn #C95A16.

**Shake:** 0.12 at the target.

**Sounds:**
- 0.9: hum
- 1.8: crackle
- 2.35: charge peak
- 2.55: blast
- 2.62: fire burst
- 2.7–5.1: burning

## C. BOULDER HURL (4.70 s)
**Read:** both fists tear a massive rock from the ground, raise it above the crown, and throw it across the battlefield.

| t | R | H/B/C/N | Arms | Hands | Moment |
|---|---|---|---|---|---|
| 0.40 | −0.55, 0, +0.3, +13 | +9/+15/+12/−9 | +15 | +12 | reach down |
| 0.85 | −1.05, 0, +0.6, +20 | +13/+22/+15/−12 | −10 | +18 | grip |
| 1.20 | −0.65, 0, +0.3, +10 | +7/+12/+8/−6 | +45 | +12 | rip free |
| 1.85 | +0.15, 0, −0.25, −9 | −5/−8/−6/+5 | +145 | +18 | overhead |
| 2.25 | +0.2, −0.3, −0.5, −13 | −7/−12/−8/+8 | +155 | +15 | wind-up |
| 2.55 | −0.25, +0.2, +0.65, +17 | +10/+15/+17/−10 | +85 | +20 | **release** |
| 2.85 | −0.35, +0.2, +0.7, +19 | +10/+16/+15/−9 | +40 | +8 | follow-through |
| 3.65 | −0.1, 0, +0.2, +7 | +4/+5/+6/−4 | +10 | +5 | recover |

**Yaw** (hips / belly / chest / head):
- Wind-up: +8/+10/+6/−6.
- Release: −10/−8/−7/+7.

**Grip:** from 0.7 to 1.2 the hands are IK-solved onto the boulder. After that the boulder rides between the two hands.

**Flight:** 0.85 s over 30 studs, with an arc of `4 × 9 × u × (1 − u)`.

**Impact (3.40):**
- 8 fragments
- 12 dust particles

**Shake:** 0.16.

**Sounds:**
- 0.40: cracking
- 0.85: rock tearing
- 1.20: scrape
- 2.25: creak
- 2.55: whoosh
- 3.40: smash
- 3.50: gravel

## Budget and video checks
**Budget:**
- 2 fully detailed attacks at once.
- Fewer than 35 extra particles per second.
- 24 fragments.
- 2 lights.
- One camera shake at a time.
- Full detail within 60 studs, reduced to 120, minimal beyond.
- Pool everything; no physics debris.

**Video checks:**
- Each attack is recognisable muted and without labels.
- Hips, belly and chest all carry weight.
- Feet are locked (under 0.3 slide).
- The gauntlets never pass through the body.
- The crystals stay rigid.
- Impacts are audible on a phone.
