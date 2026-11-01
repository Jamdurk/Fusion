# Alien Fusion: rebuild every form the Colossus v4 way (PHASED PLAN, agreed with James 27 Oct 2026)

James's ask: rebuild every alien from ChatGPT reference images, then give each one its movement, sounds and attacks, each audited by ChatGPT. This was agreed as **phases, not one overnight run**, with **several reference images per form**, plus extra close-ups wherever a part needs them.

**How:** the method is `Flagship\Polish Kit\cards\creature-from-reference.md`. Read it first. This file says what to do, in what order, and the reasons behind each choice.

**The proof it works is the Colossus v4 pilot:**
- model: `assets\blender\scripts\colossus_v4.py`
- movement: `design\06-COLOSSUS-V4-ANIMATION-SPEC.md`
- attacks: `design\07-COLOSSUS-V4-ATTACKS-SPEC.md`
- James's notes, and every fix they led to: `BUILD-LOG.md`, 27 Oct night.

## Why phases (the reasons James agreed to)
1. **James's notes were the biggest quality jump**, and ChatGPT's audits missed all of them: the pebble sound, the quick goofy walk, the upper body not swinging, the sun idea. A phase ends with him watching, not with the next form.
2. **Attacks wait for the power graph.** Picking 3 attacks per form now would clash with the counter loop and get redone. Models and movement don't depend on it.
3. **Leg length must fit the speed.** It's decided per form BEFORE its model sheet (card §1b).
4. **Most forms aren't bipeds.** Each needs its own gait (hop / slide / scuttle / tripod / quadruped). Planted-foot IK only suits the big, slower forms.

## Phase 1: models + movement + sounds (all 7 forms; the Colossus already has its pilot)

### For each form
1. **Reference pack, from one ChatGPT chat per form:**
   - A: hero concept
   - B: model sheet (front / side / back), with the leg rule in the prompt
   - the close-ups listed for that form below
   - I: pose sheet of its movement
   - K: line-up with its race (once two forms of a race are done)

   Save them to `design\concepts\<form>\`.
2. **Build:** `assets\blender\scripts\<form>_v5.py` (copy the `colossus_v4.py` structure), with the measured masses commented by source sheet.
   - Bones are designed for the gait; print their lengths.
   - Use `pin_pieces` groups for anything that must not turn through itself.
3. **Check:** renders next to the sheets, then the ChatGPT match check, at most 2 fix rounds.
4. **Into Studio:**
   - Export as `<form>_v5.fbx`, then import.
   - Make the template `ServerStorage.Aliens.Forms.<Form>v5`. The current v2 template stays until James approves.
   - Add a MOVE TEST button: "<NAME> NEW".
5. **Movement:** ChatGPT spec (send it the pose sheet + bone lengths), then walk / run / idle in `Gaits` as `<Form>v5`, `<Form>v5Run`, `<Form>v5Idle`.
   - Measure: foot slide < 0.3 where feet plant, reach, no clipping.
   - Whole-body swing; blends into and out of modes.
6. **Sounds:** footfall / hop / slide sounds per race from the licensed library, every one measured (card §6).
   - SQUISH = wet, gooey, bouncy.
   - CRUNCH = stone and crystal.
7. **Audit:** ChatGPT from frame sheets, or from measurements if the recorder is busy. Fix.
8. **Leave it ready for James:**
   - a short clip in `shots\`, ONLY if the recorder is free; otherwise the MOVE TEST button.
   - BUILD-LOG row + checkpoint.

Then the next form.

### Order and per-form notes

Rules speeds: F1 22, F2 19, F3 16, F4 12 studs/s. Biggest forms first: they're the showcase, and the closest to the Colossus work.

| # | Form (v2 plan) | Speed | Gait type | Planted IK? | Close-ups to ask for (beyond A + B + I) |
|---|---|---|---|---|---|
| 1 | SQUISH F4 **Titan**: kaiju dome on a skirt, 4 tentacles | 12 | slide on the skirt, tentacles flail slowly (James) | no: skirt slide; tentacles = bone chains | C top view, H tentacles (segments, taper, suckers), D head/eyes, G goo |
| 2 | CRUNCH F3 **Ram**: horned bull, hump | 16 | heavy quadruped trot | yes, 4 legs, if the legs fit the leg rule | C top, D head + horns, F legs/hooves, G stone |
| 3 | SQUISH F3 **Brute**: goo gorilla | 16 | knuckle-walk (James: "like a gorilla") | yes: 2 feet + 2 knuckles as footholds | C top, E fists/knuckles, F legs, D face |
| 4 | CRUNCH F2 **Pincer**: crab, C-claws, 6 legs | 19 | sideways tripod scuttle (James: individual leg movement) | small: procedural tripod, light foot lock if it reads | C top, E claws, F legs (joints), G shell |
| 5 | SQUISH F2 **Twin**: upright peanut on a puddle, tendril arms | 19 | bounce/slide on the puddle | no | D faces, H tendrils, G goo |
| 6 | CRUNCH F1 **Pebble**: beetle | 22 | fast scuttle (diagonal pairs) | no (too small/fast) | C top, F legs, G shell |
| 7 | SQUISH F1 **Drip**: blob, nub feet | 22 | hops | no | D face, G goo |


**Status 28 Oct ~4 AM: Phase 1 DONE for all 7 in ONE night** (~3.3 h, two forms at a time: one building in Blender while the next one's references generate). Pace actual: ~30 min per form unattended, not 2 h (the estimate above ran ~4x high). Each form: templates `<Race>F<n>v5` side by side with the old ones, menu "NEW v5 MODELS"; swaps wait for James. Results per form: `BUILD-LOG.md` (28 Oct rows).
**Realistic pace**, from the Colossus actuals: about 3.5 h for model + walk + fixes + attacks *with* James's live notes. Phase 1 per form unattended ≈ 2 h. **One night covers ~4 forms**, so Phase 1 is about 2 nights. Stop at a form boundary, never mid-form.

## Phase 2: attacks (after James's power graph)
For each form, ChatGPT picks 3 attacks from `design\03-FORMS-AND-RULES.md` plus the power graph, then:
- writes the keyframe / effect / sound spec (`07-...` is the template)
- props through Blender, then .glb, then `ReplicatedStorage.AlienFusion.FX`
- timelines in the `Attacks` module, plus menu buttons
- measured (IK reach, clearances, sound envelopes), audited

James watches, I fix.

## James's decisions (27-28 Oct)
1. **Leg rule vs speed: big forms SLOWER.** James: "the bigger forms naturally need to be a bit [slower] for sure. That's fine."
   - F4 is now 8 studs/s (rules §3).
   - For each form, size the legs for its speed from the card's §1b rule. Where they can't reach it, propose a slower speed in its build-log row; don't remodel the body to fit.
2. **Hero concept (A): ChatGPT approves it overnight** (James, 28 Oct: "if the hero shot works best for you, then yeah, just do it that way").
   - The hero concept is the first "poster" picture of the new design: one good-looking 3/4 view, used to agree on the LOOK before the measurable model sheet is drawn.
   - James overrides in the morning; v2 stays as the fallback.
5. **START: only when James says go.** He is making a video and the recorder / PC is in use: "I'll let you know when you can start on this whole thing". Don't begin Phase 1 until he does.
3. **Recorder: NOT free** (another session). So:
   - no clips;
   - movement audits use measured numbers + Blender renders (renders don't need the recorder);
   - James reviews each form in game with its MOVE TEST button.
   - Clips only when he says the recorder is free.
4. **Colossus: v4 REPLACES it**, done 28 Oct ~12:15 AM:
   - `CrunchF4` = v4;
   - v2 kept as `_v1.CrunchF4_v2`.

## Done criteria (Phase 1, per form)
- It matches its sheets (ChatGPT match check passed).
- Rigid pieces don't ripple or spin.
- No clipping at extreme poses.
- Movement measured: foot slide < 0.3 where feet are planted, no snaps, the upper body moves with the legs.
- Sounds measured: audible attack, no silent lead-in.
- In Studio as `<Form>v5` with a MOVE TEST button.
- The v2 template is untouched.
- BUILD-LOG + checkpoint updated; kit-serve stopped; place saved (ask before bringing Studio to the front if another session is recording).
