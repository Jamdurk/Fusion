// Alien Fusion AI profiles: one per alien, as DATA (tunable like design/power/kits.mjs). The shared brain is brain.mjs.
// Every number says where it came from: LC = Lethal Company code (research-lc-code.md), RVO2 = ORCA library,
// SC2 / RTS = Deep Research (research-deep.md), OURS = picked for our kits and checked in the sim (sim-results.md).
// Times in s, distances in studs, speeds in studs/s.

// Shared by every unit (the "engine" numbers).
export const BRAIN = {
  thinkEvery: 0.2,           // LC AIIntervalTime 0.2 s: decisions at 5 Hz, staggered per unit; motion every tick
  senseRange: 60,            // LC default sight range 60; open moon arena, so no cone except the Titans' facing
  memory: 3,                 // LC Baboon Hawk: unseen 3 s → drop if far, 5 s → forget (Roblox only: the sim sees everything)
  commit: 1.5,               // keep the current target unless a new one scores 1.5x (kit EntityAI + LC Forest Keeper)
  minHold: 1.0,              // and never switch more often than this (LC Forest Keeper switches after 2 s; ours are faster)
  reactRange: [0.15, 0.45],  // first-contact "notice" delay per unit (LC Thumper notices after 0.2 s; per-unit jitter)
  speedJitter: 0.04,         // ±4 % per unit (LC rolls per-creature values once; our average stays exactly 1.0)
  // RVO2 time horizon. 1.0 s froze dense melee crowds (everyone yields: the classic ORCA deadlock), so friends look 0.4 s
  // ahead and use 0.8 r (a little squash is fine: the hard separation pass still stops real overlaps).
  orca: { horizon: 0.4, neighbourRange: 6, radiusScale: 0.8 },
  evadeFear: 0,              // LC Baboon Hawk: act when fear > 0 (tried 1: kept the fighting-time cost, lost most of the safety)
  clearance: 0.9,            // physical radius vs boulders (the sim's push-out uses 0.9 r): nav plans with the same
  noticeAt: 25,              // the first-contact beat fires when an enemy first comes this close (not at sight range)
  overkill: { horizon: 1.5, over: 1.15, factor: 0.55 },          // SC2-style "don't all pile on a dying unit" (spread fire)
  stuck: { window: 1.5, minProgress: 0.25 },                       // LC Snare Flea re-routes after 4 s; ours 1.5 s
};

// How much each form WANTS each enemy form (target value). Straight from the counter loop: prey high, predator low.
// (F1 also wants Brutes: x2 when 6+ cling, power graph §3.)
export const PREY = {
  F1: { F4: 3.0, F3: 2.4, F1: 1.0, F2: 0.35 },
  F2: { F1: 3.0, F2: 1.0, F4: 0.6, F3: 0.35 },
  F3: { F2: 3.0, F3: 1.0, F1: 1.0, F4: 0.3 },
  F4: { F3: 3.0, F4: 1.0, F2: 1.0, F1: 0.6 },
};
// Who hunts whom (predator of each form): used for fear / evade.
export const PREDATOR = { F1: "F2", F2: "F3", F3: "F4", F4: "F1" };

// TELLS + LIFE: what each alien SHOWS (Roblox presentation: animator + sounds). Not in the sim (it has no animation);
// the timings are LC's, scaled to our pace. Each is a short, readable beat before or between actions.
export const TELLS = {
  notice: { range: [0.15, 0.45], note: "first contact: stop, turn, a one-shot sound (LC Eyeless Dog howl 0.7 s; ours shorter: an army can't wait)" },
  idleLook: { every: [6, 15], hold: [1.5, 4], note: "out of combat: stop and look around (LC Forest Keeper 3-12 s every ~12 s; Nutcracker every 6-15 s)" },
  voicePitch: [0.9, 1.1],   // LC rolls each creature's voice pitch once (20 % chance of 0.6-1.3)
  orderWave: [0.06, 0.3],   // an Order fires as a ripple: each unit starts after a random 0.06-0.3 s (LC Old Bird shot gaps), not in sync
  perAlien: {
    Drip: "hop-in-place squash before leaping on (0.2 s); after BOING, a wobble on landing, then re-cling on the flank",
    Pebble: "antennae twitch + click before ROLL OUT; curled = shell glint; uncurls with a shake",
    Twin: "both tendrils rise and the puddle ripples when the annoyance meter fills (LC Hoarding Bug chitter, angry screech)",
    Pincer: "claws snap twice before CLAW BLOCK / SIDE SWEEP (LC Spore Lizard stomp before puff)",
    Brute: "chest puff + snort when it locks on a Pack (LC Eyeless Dog stop-and-howl, 0.3 s)",
    Ram: "paws the ground twice before RAM CHARGE (0.85 s warning in the kit); snorts when a Pack is in charge range",
    Titan: "head swings to the new target BEFORE the body turns (turning reads as intent); tentacles curl up on the slam wind-up",
    Colossus: "plants both fists and looks up before SOLAR STRIKE; gauntlet glow builds (the kit's 2.0 s warning)",
  },
};

// Throws on any value that would divide by zero or go NaN (code review r3 #15). Called by createBrain().
export function validateProfiles(brain = BRAIN, profiles = PROFILES) {
  const pos = (v, name) => { if (!(Number.isFinite(v) && v > 0)) throw new RangeError(`profile ${name} must be > 0 (got ${v})`); };
  const nonNeg = (v, name) => { if (!(Number.isFinite(v) && v >= 0)) throw new RangeError(`profile ${name} must be >= 0 (got ${v})`); };
  const fin = (v, name) => { if (!Number.isFinite(v)) throw new RangeError(`profile ${name} must be finite (got ${v})`); };
  const unit = (v, name) => { if (!(Number.isFinite(v) && v >= 0 && v <= 1)) throw new RangeError(`profile ${name} must be in [0, 1] (got ${v})`); };
  pos(brain.senseRange, "BRAIN.senseRange"); nonNeg(brain.memory, "BRAIN.memory"); nonNeg(brain.noticeAt, "BRAIN.noticeAt");
  unit(brain.speedJitter, "BRAIN.speedJitter"); fin(brain.evadeFear, "BRAIN.evadeFear"); pos(brain.orca.neighbourRange, "BRAIN.orca.neighbourRange");
  if (!(Array.isArray(brain.reactRange) && brain.reactRange.length === 2)) throw new RangeError("BRAIN.reactRange must be [min, max]");
  nonNeg(brain.reactRange[0], "BRAIN.reactRange[0]"); nonNeg(brain.reactRange[1], "BRAIN.reactRange[1]");
  if (brain.reactRange[0] > brain.reactRange[1]) throw new RangeError("BRAIN.reactRange min > max");
  pos(brain.overkill.horizon, "BRAIN.overkill.horizon"); pos(brain.overkill.over, "BRAIN.overkill.over"); unit(brain.overkill.factor, "BRAIN.overkill.factor");
  unit(brain.stuck.minProgress, "BRAIN.stuck.minProgress");
  pos(brain.thinkEvery, "BRAIN.thinkEvery"); pos(brain.commit, "BRAIN.commit"); nonNeg(brain.minHold, "BRAIN.minHold");
  pos(brain.orca.horizon, "BRAIN.orca.horizon"); pos(brain.orca.radiusScale, "BRAIN.orca.radiusScale"); pos(brain.clearance, "BRAIN.clearance");
  pos(brain.stuck.window, "BRAIN.stuck.window");
  for (const race of Object.keys(profiles)) for (const form of Object.keys(profiles[race])) {
    const P = profiles[race][form], n = `${race}.${form}`;
    pos(P.falloff, n + ".falloff"); pos(P.accel, n + ".accel"); pos(P.slotSpacing ?? 1, n + ".slotSpacing");
    fin(P.courage, n + ".courage"); nonNeg(P.wedgeAvoid, n + ".wedgeAvoid");
    if (P.gangUp) { pos(P.gangUp.want, n + ".gangUp.want"); pos(P.gangUp.cap, n + ".gangUp.cap"); pos(P.gangUp.bonus, n + ".gangUp.bonus"); nonNeg(P.gangUp.full, n + ".gangUp.full"); }
    if (P.ramp) {
      pos(P.ramp.over, n + ".ramp.over"); nonNeg(P.ramp.after, n + ".ramp.after"); unit(P.ramp.turnLoss, n + ".ramp.turnLoss"); pos(P.ramp.sharp, n + ".ramp.sharp");
      if (!(P.ramp.from > 0 && P.ramp.from <= 1)) throw new RangeError(n + ".ramp.from must be in (0, 1]");
    }
    if (P.stayNear) { pos(P.stayNear.radius, n + ".stayNear.radius"); nonNeg(P.stayNear.weight, n + ".stayNear.weight"); }
    if (P.evade) { pos(P.evade.radius, n + ".evade.radius"); nonNeg(P.evade.holdMax, n + ".evade.holdMax"); }
    if (P.facing) { pos(P.facing.moveCone, n + ".facing.moveCone"); unit(P.facing.weight, n + ".facing.weight"); }
    if (P.guard) { pos(P.guard.radius, n + ".guard.radius"); pos(P.guard.bonus, n + ".guard.bonus"); pos(P.guard.annoyPerTick, n + ".guard.annoyPerTick"); pos(P.guard.angryAt, n + ".guard.angryAt"); pos(P.guard.angryFor, n + ".guard.angryFor"); }
    if (P.hold) { pos(P.hold.secs, n + ".hold.secs"); pos(P.hold.leash, n + ".hold.leash"); }
    if (P.swarmed) pos(P.swarmed.count, n + ".swarmed.count");
    for (const [f, v] of Object.entries(P.spreadVs ?? {})) pos(v, `${n}.spreadVs.${f}`);
  }
  return true;
}

// Per-alien profiles. Race personality (handover §4): SQUISH bouncy + reactive (evades sooner, scatters wider);
// CRUNCH stubborn + direct (higher courage, holds ground, straighter lines).
export const PROFILES = {
  SQUISH: {
    F1: { name: "Drip", from: "LC Baboon Hawk pack + Snare Flea cling + Reynolds surround",
      falloff: 12, accel: 80, gangUp: { want: 6, cap: 10, bonus: 1.4, full: 0.4 },   // CLING needs 6+, BOING BOMBS caps 10
      spreadVs: { F2: 1.6 },   // SC2 "marine split": stand further apart round a Pack so its double slap hits one, not two
      courage: 0, evade: { radius: 25, holdMax: 3.0 }, wedgeAvoid: 0.5, slotSpacing: 1.0 },   // bouncy: re-clings on a Titan's flank after a BOING
    F2: { name: "Twin", from: "LC Hoarding Bug (guards a nest = its big friends) + annoyance meter",
      falloff: 10, accel: 60, guard: { radius: 18, bonus: 1.8, annoyPerTick: 0.2, angryAt: 2.5, angryFor: 3.25 },
      courage: 0, evade: { radius: 22, holdMax: 3.0 }, wedgeAvoid: 0.5, slotSpacing: 1.0 },
    F3: { name: "Brute", from: "LC Eyeless Dog (meter, commit) + Kidnapper Fox (grab a runner)",
      falloff: 14, accel: 40, stayNear: { radius: 8, weight: 0.3 },               // CHEST THUMP shields friends within 8
      courage: 0, evade: { radius: 25, holdMax: 2.5 }, wedgeAvoid: 1.0, slotSpacing: 1.1 },
    F4: { name: "Titan", from: "LC Forest Keeper (slow giant, meters, stop-and-look) + Old Bird (siege)",
      falloff: 12, accel: 16, facing: { weight: 0.6, moveCone: 60 }, swarmed: { count: 6, toFriends: "F2" },
      courage: 0, evade: null, wedgeAvoid: 0, slotSpacing: 1.0 },
  },
  CRUNCH: {
    F1: { name: "Pebble", from: "LC Baboon Hawk pack + Thumper (straight rolling waves)",
      falloff: 12, accel: 80, gangUp: { want: 6, cap: 10, bonus: 1.4, full: 0.4 },
      spreadVs: { F2: 1.6 },
      courage: 1, evade: { radius: 18, holdMax: 1.5 }, wedgeAvoid: 0, slotSpacing: 1.0 },
    F2: { name: "Pincer", from: "LC Nutcracker (sentry that holds a line) + Spore Lizard (warn, then block)",
      falloff: 10, accel: 60, guard: { radius: 14, bonus: 1.5, annoyPerTick: 0.2, angryAt: 2.5, angryFor: 3.25 },
      hold: { secs: 2.0, leash: 6 },   // LC Nutcracker sentry: hold a post between a big friend and the threat for 2 s (audit r1 #6)
      courage: 1, evade: { radius: 16, holdMax: 1.5 }, wedgeAvoid: 0.5, slotSpacing: 1.0 },
    F3: { name: "Ram", from: "LC Thumper (speed builds on straights) + Eyeless Dog lunge + Baboon Hawk rush-and-back-off",
      falloff: 14, accel: 40, stayNear: null,
      ramp: { from: 0.7, after: 0.6, over: 1.0, turnLoss: 0.2, sharp: 45 },   // LC Thumper: speed builds on a straight pursuit (audit r1 #6)
      courage: 1, evade: { radius: 18, holdMax: 1.5 }, wedgeAvoid: 1.0, slotSpacing: 1.1 },
    F4: { name: "Colossus", from: "LC Forest Keeper (heavier) + Old Bird",
      falloff: 12, accel: 14, facing: { weight: 0.6, moveCone: 60 }, swarmed: { count: 6, toFriends: "F2" },
      courage: 1, evade: null, wedgeAvoid: 0, slotSpacing: 1.0 },
  },
};
