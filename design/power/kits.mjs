// Alien Fusion power graph v2: base stats + 3 abilities per form per race.
// The sim (sim.mjs) reads these numbers directly, so this file IS the graph's source of truth.
// Slots (deep research 28 Oct, design/power/deep-research-2026-10-28.md):
//   A = PASSIVE: how it attacks; makes its counter job obvious (no button)
//   B = AUTO: a situational skill the unit uses by itself on a cooldown (no button)
//   C = ORDER: the ONE button per form; every unit of that form does it together (shared cooldown)
// Times in seconds, distances in studs, damage in HP. "tele" = warning time before it lands.

export const FORMS = {
  F1: { matter: 1, hp: 100, dps: 12, speed: 22, r: 1.0, reach: 0.8 },
  F2: { matter: 2, hp: 235, dps: 20, speed: 19, r: 1.6, reach: 1.2 },
  F3: { matter: 4, hp: 560, dps: 44, speed: 16, r: 3.0, reach: 1.8 },   // was 650 / 48 (rules lock): the richest chassis by far
  F4: { matter: 16, hp: 2400, dps: 100, speed: 8, r: 6.0, reach: 3.0 },
};

// Guard rails (sim.mjs enforces the CC ones; check.mjs / guard.mjs report the rest):
export const RULES = {
  stunMax: 0.6, stunImmunity: 3.0,   // hard CC never chains: 3 s immune after any stun
  slowCap: 0.3,                       // slows never stack past 30 %; they also slow attacks
  shieldCap: 0.2,                     // a shield is never more than 20 % of the receiver's max HP
  shoveBudget: 8, shoveWindow: 3,     // pulls / knocks / tosses: max 8 studs per victim per 3 s (audit r1)
  f4: { vsSmall: {}, stunImmune: true, pullImmune: true, slowFactor: 0.5, turnDegPerSec: 60 },
  minTele: { auto: 0.5, order: 0.55, titan: 0.9 },
  orderBudgetPerMatter: 20,           // a damage Order's bonus per unit ~ 20 x matter (640 per full army)
};

export const KITS = {
  SQUISH: {
    F1: { name: "Drip", abilities: [
      { slot: "A", id: "cling", name: "CLING", kind: "surround", tag: "counter",
        text: "Drips hop on and stick. 6+ Drips on a big one = GOOED: they hit it much harder (x1.75 Titan, x2 Brute).",
        hit: 6, every: 0.5, surroundN: 6, surroundMult: { F4: 1.75, F3: 2 } },
      { slot: "B", id: "boing", name: "BOING", kind: "dodge", tag: "mobility",
        text: "About to be hit by a Titan? Boing! It springs to the nearest edge of the danger zone, up to 10 studs (if it can't get clear, it squashes flat and takes half).", cd: 10, leap: 10, dr: 0.5, vsOnly: ["F4"] },
      { slot: "C", id: "boingbombs", name: "BOING BOMBS", kind: "leapOnto", tag: "order",
        text: "ORDER: every Drip springs onto the nearest big enemy and lands with a splat.", cd: 24, tele: 0.55, range: 12, bonus: 15, perTarget: 10, targets: ["F4", "F3"] },
    ]},
    F2: { name: "Twin", abilities: [
      { slot: "A", id: "doubleslap", name: "DOUBLE SLAP", kind: "cleave", tag: "counter",
        text: "Both tendrils slap at once: hits two little ones together.", hit: 20, every: 1.0, targets: 2, cleaveVs: ["F1"] },
      { slot: "B", id: "stickyfloor", name: "STICKY FLOOR", kind: "zoneSlow", tag: "control",
        text: "Spreads its puddle wide: everything in it gets stuck and slow.", cd: 9, tele: 0.5, radius: 5, slow: 0.25, dur: 2.5, trigger: 3 },
      { slot: "C", id: "boingslam", name: "BOING SLAM", kind: "leapSlam", tag: "order",
        text: "ORDER: every Twin bounces sky-high and belly-flops into a crowd, tossing little ones up.", cd: 22, tele: 0.8, range: 14, radius: 5, hit: 20, cap: 3, stunF1: 0.4, trigger: 2 },
    ]},
    F3: { name: "Brute", abilities: [
      { slot: "A", id: "pound", name: "KNUCKLE POUND", kind: "melee", tag: "counter",
        text: "Two-fist pound: extra hard on Packs (x1.5 vs F2).", hit: 55, every: 1.25, mult: { F2: 1.5 } },
      { slot: "B", id: "grab", name: "STRETCH GRAB", kind: "pull", tag: "control",
        text: "A stretchy goo arm grabs a runner, yanks it in and slams it down.", cd: 8, tele: 0.5, range: 14, hit: 30, root: 0.5, prefer: ["F2", "F1", "F3"] },
      { slot: "C", id: "thump", name: "CHEST THUMP", kind: "shieldBuff", tag: "order",
        text: "ORDER: every Brute beats its chest: a goo shield for it and its friends, and it punches faster.", cd: 26, tele: 0.8, selfShield: 70, allyShield: 30, allyRadius: 8, shieldDur: 6, haste: 0.2, hasteDur: 4 },
    ]},
    F4: { name: "Titan", abilities: [
      { slot: "A", id: "tentacle", name: "TENTACLE SLAM", kind: "arcSlam", tag: "counter",
        text: "Its attack: two tentacles crush the ground in front: huge on a Brute, wasted on a tiny Drip.", every: 4.0, pre: 0.74, tele: 0.9, lock: 3.4, keepCycle: true, radius: 10, arc: 120, hit: 400, splash: 0.25, cap: 2, mult: { F3: 2.5 } },
      { slot: "B", id: "goobomb", name: "GOO BOMB", kind: "lob", tag: "siege",
        text: "Nothing in reach? Spits a giant goo ball far away (Brutes first, x2.5 vs bases); it leaves a sticky puddle.", cd: 12, pre: 2.4, tele: 1.0, lock: 2.6, farOnly: 6, range: 30, radius: 5, hit: 160, cap: 3, prefer: ["F3"], base: 2.5, slow: 0.25, slowDur: 2.5 },
      { slot: "C", id: "tsunami", name: "GOO TSUNAMI", kind: "lane", tag: "order",
        text: "ORDER: rears up and crashes forward: a goo wave flattens the first big enemy and slows the rest.", cd: 28, pre: 2.1, tele: 1.1, lock: 3.2, minHits: 2, length: 24, width: 12, hit: 300, side: 60, cap: 4, mult: { F3: 2.5 }, prefer: ["F3", "F4", "F2"], slow: 0.25, slowDur: 2, base: 2.5 },
    ]},
  },
  CRUNCH: {
    F1: { name: "Pebble", abilities: [
      { slot: "A", id: "chip", name: "CHIP", kind: "surround", tag: "counter",
        text: "Mandibles chip cracks in rock (and bite chunks out of goo). 6+ Pebbles on a big one = CRACKED: they hit it much harder (x1.75 Titan, x2 Brute).",
        hit: 6, every: 0.5, surroundN: 6, surroundMult: { F4: 1.75, F3: 2 } },
      { slot: "B", id: "curl", name: "CURL UP", kind: "curl", tag: "defense",
        text: "About to be hit by a Titan? Curls into a stone ball and stays put: the hit mostly bounces off its shell (70 % less).", cd: 12, dr: 0.7, dur: 1.2, vsOnly: ["F4"] },
      { slot: "C", id: "rollout", name: "ROLL OUT", kind: "rush", tag: "order",
        text: "ORDER: every Pebble curls up and rolls at the nearest big enemy (hard to hurt while rolling), then pops open with a horn jab.", cd: 24, tele: 0.55, range: 16, dur: 2.5, speed: 0.6, dr: 0.3, bonus: 20, targets: ["F4", "F3"] },
    ]},
    F2: { name: "Pincer", abilities: [
      { slot: "A", id: "snap", name: "SCISSOR SNAP", kind: "cleave", tag: "counter",
        text: "Each claw snaps a different target: hits two little ones together.", hit: 20, every: 1.0, targets: 2, cleaveVs: ["F1"] },
      { slot: "B", id: "block", name: "CLAW BLOCK", kind: "dr", tag: "defense",
        text: "Swarmed (by little ones or Packs)? Raises both claws like a shield: takes less damage for a moment.", cd: 10, dr: 0.3, dur: 3, trigger: 2, triggerForms: ["F1", "F2"] },
      { slot: "C", id: "sweep", name: "SIDE SWEEP", kind: "dashLine", tag: "order",
        text: "ORDER: every Pincer plants its legs and swings both claws in a wide sideways sweep, batting little ones and Packs aside.", cd: 22, tele: 0.7, length: 7, width: 6, hit: 20, cap: 3, knock: 2, dash: 0, trigger: 2, hitForms: ["F1", "F2"] },
    ]},
    F3: { name: "Ram", abilities: [
      { slot: "A", id: "gore", name: "HORN GORE", kind: "melee", tag: "counter",
        text: "Horn hook: extra hard on Packs (x1.5 vs F2).", hit: 55, every: 1.25, mult: { F2: 1.5 } },
      { slot: "B", id: "stamp", name: "HOOF STAMP", kind: "stunRing", tag: "control",
        text: "A Pack or Brute close by? Rears and stamps: the ground jolts and stuns it for a blink (little ones only get dusted).", cd: 9, tele: 0.5, radius: 5, hit: 30, stun: 0.5, cap: 2, trigger: 1, triggerForms: ["F2", "F3"], prefer: ["F2", "F3"], stunForms: ["F2", "F3"], hitForms: ["F2", "F3"] },
      { slot: "C", id: "charge", name: "RAM CHARGE", kind: "charge", tag: "order",
        text: "ORDER: every Ram paws the ground, then charges in a line at a Pack (or a Brute) and smashes it.", cd: 24, tele: 0.85, length: 18, width: 4, hit: 90, side: 20, cap: 3, mult: { F2: 1.5 }, prefer: ["F2", "F3"], knock: 4 },
    ]},
    F4: { name: "Colossus", abilities: [
      { slot: "A", id: "shatter", name: "GROUND SHATTER", kind: "arcSlam", tag: "counter",
        text: "Its attack: both fists smash down in front and crystals burst up: huge on a Brute, wasted on a tiny Pebble.", every: 4.0, pre: 0.64, tele: 1.0, lock: 3.4, keepCycle: true, radius: 10, arc: 120, hit: 400, splash: 0.25, cap: 2, mult: { F3: 2.5 }, stun: 0.3 },
      { slot: "B", id: "boulder", name: "BOULDER HURL", kind: "lob", tag: "siege",
        text: "Nothing in reach? Rips a boulder out of the ground and throws it far (Brutes first, x2.5 vs bases).", cd: 12, pre: 2.4, tele: 1.0, lock: 2.6, farOnly: 6, range: 30, radius: 4, hit: 160, cap: 3, prefer: ["F3"], base: 2.5 },
      { slot: "C", id: "sun", name: "SOLAR STRIKE", kind: "zoneBurst", tag: "order",
        text: "ORDER: charges a mini sun over its fist, then a beam blasts the first big enemy and leaves the ground burning.", cd: 28, pre: 2.0, tele: 1.2, lock: 3.2, minHits: 2, range: 30, radius: 8, hit: 300, side: 50, cap: 4, mult: { F3: 2.5 }, prefer: ["F3", "F4", "F2"], burn: 8, burnDur: 2, base: 2.5 },
    ]},
  },
};
