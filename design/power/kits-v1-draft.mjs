// Alien Fusion power graph v1: base stats (rules lock 03 §3) + 3 abilities per form per race.
// The sim (sim.mjs) reads these numbers directly, so this file IS the graph's source of truth.
// Slots: A = COUNTER MOVE (its job in the loop), B = TOOL (move / defend / control), C = SIGNATURE (the big moment).
// Times in seconds, distances in studs, damage in HP. "tele" = warning time before it lands.

export const FORMS = {
  F1: { matter: 1, hp: 100, dps: 12, speed: 22, r: 1.0, reach: 0.8 },
  F2: { matter: 2, hp: 235, dps: 20, speed: 19, r: 1.6, reach: 1.2 },
  F3: { matter: 4, hp: 560, dps: 44, speed: 16, r: 3.0, reach: 1.8 },
  F4: { matter: 16, hp: 2400, dps: 100, speed: 8, r: 6.0, reach: 3.0 },
};

// Guard rails (checked by sim.mjs --check):
export const RULES = {
  stunMax: 0.6, stunImmunity: 3.0,   // hard CC never chains
  slowCap: 0.4,                       // slows never stack past 40 %
  f4: { vsSmall: { F1: 0.5, F2: 0.65 }, stunImmune: true, pullImmune: true, slowFactor: 0.5, turnDegPerSec: 60 },
  minTele: { aoeR5: 0.6, signature: 0.8 },  // anything radius >= 5 warns >= 0.6 s; signatures >= 0.8 s
};

export const KITS = {
  SQUISH: {
    F1: { name: "Drip", abilities: [
      { slot: "A", id: "cling", name: "CLING", kind: "surround", tag: "counter",
        text: "Drips hop on and stick. 6+ Drips on a big one = it's GOOED: they hit it x2 (Titan) / x1.5 (Brute).",
        hit: 6, every: 0.5, surroundN: 6, surroundMult: { F4: 2, F3: 2 } },
      { slot: "B", id: "boing", name: "BOING", kind: "dodge", tag: "mobility",
        text: "Standing in a warning circle? Boing! A big hop out of it.", cd: 9, leap: 10 },
      { slot: "C", id: "splat", name: "SPLAT", kind: "deathSlow", tag: "control",
        text: "When it pops it leaves a sticky puddle: enemies in it are slowed.", radius: 3, slow: 0.25, dur: 2 },
    ]},
    F2: { name: "Twin", abilities: [
      { slot: "A", id: "doubleslap", name: "DOUBLE SLAP", kind: "cleave", tag: "counter",
        text: "Both tendrils slap at once: hits two little ones together.", hit: 20, every: 1.0, targets: 2, cleaveVs: ["F1"] },
      { slot: "B", id: "stickyfloor", name: "STICKY FLOOR", kind: "zoneSlow", tag: "control",
        text: "Spreads its puddle wide: everything in it gets stuck and slow.", cd: 10, tele: 0.4, radius: 6, slow: 0.3, dur: 3, trigger: 3 },
      { slot: "C", id: "boingslam", name: "BOING SLAM", kind: "leapSlam", tag: "burst",
        text: "Bounces sky-high and belly-flops into a crowd, tossing little ones up.", cd: 16, tele: 0.8, range: 14, radius: 6, hit: 30, cap: 4, stunF1: 0.4, trigger: 3 },
    ]},
    F3: { name: "Brute", abilities: [
      { slot: "A", id: "pound", name: "KNUCKLE POUND", kind: "melee", tag: "counter",
        text: "Two-fist pound: extra hard on Packs (x1.5 vs F2).", hit: 55, every: 1.25, mult: { F2: 1.5 } },
      { slot: "B", id: "grab", name: "STRETCH GRAB", kind: "pull", tag: "control",
        text: "A stretchy goo arm grabs a runner, yanks it in and slams it down.", cd: 8, range: 14, hit: 30, root: 0.5, prefer: ["F2", "F1", "F3"] },
      { slot: "C", id: "thump", name: "CHEST THUMP", kind: "shieldBuff", tag: "defense",
        text: "Beats its chest: a goo shield for it and its friends, and it punches faster.", cd: 18, tele: 1.0, selfShield: 80, allyShield: 30, allyRadius: 8, shieldDur: 6, haste: 0.2, hasteDur: 5 },
    ]},
    F4: { name: "Titan", abilities: [
      { slot: "A", id: "tentacle", name: "TENTACLE SLAM", kind: "arcSlam", tag: "counter",
        text: "Two tentacles slam the ground in front (x1.8 vs Brutes) and leave them sticky.", every: 4.0, tele: 0.8, radius: 10, arc: 120, hit: 400, splash: 0.35, cap: 3, mult: { F3: 2.5 }, slow: 0.2, slowDur: 1.5 },
      { slot: "B", id: "goobomb", name: "GOO BOMB", kind: "lob", tag: "siege",
        text: "Spits a giant goo ball far away (x2.5 vs bases); it leaves a sticky puddle.", cd: 12, tele: 1.0, range: 30, radius: 5, hit: 100, cap: 3, base: 2.5, slow: 0.3, slowDur: 3 },
      { slot: "C", id: "tsunami", name: "GOO TSUNAMI", kind: "lane", tag: "signature",
        text: "Rears up and crashes forward: a goo wave rolls down a lane, slowing all it hits.", cd: 24, tele: 1.4, length: 24, width: 12, hit: 150, cap: 5, mult: { F3: 2.2 }, slow: 0.4, slowDur: 3, base: 2.5 },
    ]},
  },
  CRUNCH: {
    F1: { name: "Pebble", abilities: [
      { slot: "A", id: "chip", name: "CHIP", kind: "surround", tag: "counter",
        text: "Mandibles chip cracks in the rock. 6+ Pebbles on a big one = it's CRACKED: they hit it x2 (Titan) / x1.5 (Brute).",
        hit: 6, every: 0.5, surroundN: 6, surroundMult: { F4: 2, F3: 2 } },
      { slot: "B", id: "curl", name: "CURL UP", kind: "curl", tag: "defense",
        text: "Standing in a warning circle? Curls into a stone ball and takes much less.", cd: 9, dr: 0.7, dur: 1.5 },
      { slot: "C", id: "shards", name: "SHARD BURST", kind: "deathBurst", tag: "burst",
        text: "When it breaks, sharp crystal shards fly out and nick nearby enemies.", radius: 3.5, hit: 8, cap: 2 },
    ]},
    F2: { name: "Pincer", abilities: [
      { slot: "A", id: "snap", name: "SCISSOR SNAP", kind: "cleave", tag: "counter",
        text: "Each claw snaps a different target: hits two little ones together.", hit: 20, every: 1.0, targets: 2, cleaveVs: ["F1"] },
      { slot: "B", id: "block", name: "CLAW BLOCK", kind: "dr", tag: "defense",
        text: "Raises both claws like a shield: takes much less damage for a moment.", cd: 10, dr: 0.5, dur: 3, trigger: 2 },
      { slot: "C", id: "sweep", name: "SIDE SWEEP", kind: "dashLine", tag: "burst",
        text: "Claws wide, it scuttles sideways straight through a crowd, knocking them aside.", cd: 16, tele: 0.6, length: 10, width: 5, hit: 32, cap: 4, knock: 4, trigger: 3 },
    ]},
    F3: { name: "Ram", abilities: [
      { slot: "A", id: "gore", name: "HORN GORE", kind: "melee", tag: "counter",
        text: "Horn hook: extra hard on Packs (x1.5 vs F2).", hit: 55, every: 1.25, mult: { F2: 1.5 } },
      { slot: "B", id: "stamp", name: "HOOF STAMP", kind: "stunRing", tag: "control",
        text: "Rears and stamps: the ground jolts and stuns everyone close for a blink.", cd: 9, tele: 0.5, radius: 5, hit: 30, stun: 0.5, cap: 2, trigger: 1 },
      { slot: "C", id: "charge", name: "RAM CHARGE", kind: "charge", tag: "signature",
        text: "Paws the ground, then charges in a straight line and smashes the first big target.", cd: 12, tele: 0.8, length: 18, width: 4, hit: 115, side: 25, cap: 5, mult: { F2: 1.5 }, knock: 4 },
    ]},
    F4: { name: "Colossus", abilities: [
      { slot: "A", id: "shatter", name: "GROUND SHATTER", kind: "arcSlam", tag: "counter",
        text: "Both fists smash down in front and crystals burst up (x1.8 vs Brutes), jolting them.", every: 4.0, tele: 1.0, radius: 10, arc: 120, hit: 400, splash: 0.35, cap: 3, mult: { F3: 2.5 }, stun: 0.3 },
      { slot: "B", id: "boulder", name: "BOULDER HURL", kind: "lob", tag: "siege",
        text: "Rips a boulder out of the ground and throws it far (x2.5 vs bases).", cd: 12, tele: 1.0, range: 30, radius: 4, hit: 115, cap: 3, base: 2.5 },
      { slot: "C", id: "sun", name: "SOLAR STRIKE", kind: "zoneBurst", tag: "signature",
        text: "Charges a mini sun over its fist, then a beam blasts the ground and leaves it burning.", cd: 24, tele: 1.6, range: 30, radius: 8, hit: 150, cap: 5, burn: 15, burnDur: 2.5, mult: { F3: 1.8 }, base: 2.5 },
    ]},
  },
};
