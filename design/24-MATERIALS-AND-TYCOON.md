# Alien Fusion: materials, mining + the tycoon (1 Nov 2026, Claude + ChatGPT; LOCKED by James 1 Nov)

James (1 Nov): "start thinking about the systems ... the mining ... what are the THREE materials? How will they tie into
the monsters / aliens you get? What are the parts of the tycoon you upgrade to get monsters, and how does it all
function?" Building on ONE base for now. No prices yet (numbers come later).
ChatGPT ("Roblox Development Depth" chat): r1 proposal `economy\materials-tycoon-r1.txt`; Claude pushed back on 6 points
(launch pad order, empty buys, Lander Ruins, late-game sinks, phone HUD, when Crunch starts) -> r2 **GO with all 6 applied**
(`economy\materials-tycoon-r2.txt`). Replaces section 3 + 4 of `21-GAME-MECHANICS.md` (v4.2) once James agrees.

**The rule:** Rock builds your factory. DNA grows your aliens. Your aliens conquer forts. Conquered forts help your
factory grow. (Mining -> want to hatch -> want to merge -> want to conquer.)

## The three materials (each has ONE job)
| Material | Colour | Where it comes from | Spent on | Aliens |
|---|---|---|---|---|
| **MOON ROCK** | grey | rocks on your plot, drills, refinery; fort + meteor bonuses | every build pad, upgrades, decorations, Meteor Beacon | none directly |
| **GOO DNA** | cyan | Goo Marsh veins (main), Moonwood pods, goo nests / Fort 1, meteorites, Goo Extractor | SQUISH EGGS | hatches DRIPS -> Twin, Brute, Titan |
| **CRYSTAL DNA** | amber | Crystal Canyon veins (main), crystal nests / Fort 2, meteorites, Crystal Extractor | CRUNCH EGGS | hatches PEBBLES -> Pincer, Ram, Colossus |
- Changed from v4.2: one ALIEN DNA split into GOO DNA + CRYSTAL DNA (where you mine = which army grows). No 4th currency,
  no keys. Merging + splitting cost nothing. Rarity = the egg's rolled LOOK only (Normal ... Cosmic), never stats.
- Map fit: your plot = rock; Goo Marsh (W) = Goo DNA; Crystal Canyon (E) = Crystal DNA (open from the start, never gated
  by a fort); Moonwood (N) = extra Goo DNA pods + discovery events; crater meteorites = all three; Lander Ruins (S) =
  LATER (salvage area: spend rock to repair old machines -> cosmetics + mining events). Fort 1 boosts Goo DNA, Fort 2
  boosts Crystal DNA, the throne = prestige + a temporary production bonus.
- Phone HUD: Moon Rock + ONE DNA counter (the family you have selected; tap it to see both). No backpack, no selling:
  mined material goes straight to your counter with a floating "+Rock" / "+DNA". The incubator shows both DNA next to
  its two eggs.

## The tycoon (build order; every pad costs MOON ROCK and does something you can SEE)
| Pad | Machine | What you get |
|---|---|---|
| start | **Launch Pad** (already built) | deploy 8 matter at once: first battle inside 60 s |
| 1 | Rock Drill | animated drill making Moon Rock |
| 2 | **Incubator** | hatch your first alien (pick a cyan SQUISH egg or amber CRUNCH egg, pay the matching DNA, wait) |
| 3 | Refinery | a working conveyor, more rock |
| 4 | Goo Extractor | slow Goo DNA trickle |
| 5 | Incubator Upgrade | faster hatching |
| 6 | Launch Rig | deploy cap 8 -> 12 |
| 7 | Crystal Extractor | slow Crystal DNA trickle |
| 8 | Launch Rig II | 16 (later 24, 32) |
| 9 | Second Egg Slot | two eggs at once |
| 10 | Meteor Beacon | spend rock to call a bonus DNA meteorite (server cooldown; everyone nearby shares, the buyer gets a bit extra) |
| 11 | Trophy Hall | show your rarest aliens to visitors |
| 12+ | Base Expansion | more machines, advanced upgrades, decorations |
Dropped from r1: Rock Collector + DNA Scanner (nothing to see). Fort wins unlock the strongest extractor / launch upgrades.
The chain: rock -> Incubator -> mine DNA -> egg -> 1 alien (own id + rolled look) -> army grows (32 per species, ONE
species per battle) -> merge / split in battle -> conquer forts -> better extractors -> more DNA.

## A first session
| When | What happens |
|---|---|
| minute 1 | claim plot, mine rock, buy the drill, deploy the 8 starter Drips at Fort 1 |
| minutes 3-5 | build the Incubator, hatch a Glowing Drip; the first Fort 1 win gives enough Crystal DNA for a Pebble -> meet CRUNCH, go to the canyon |
| minutes 5-10 | 16 Squish matter -> first Titan, first Order, launch upgrades, aim at Fort 2 |
| ~30 minutes | a full 32 Squish army; Crunch growing; base growing; conquering |
| hour 2+ | rare looks, base expansion + decorations, fort replays (harder, extra rock / DNA, never reset), the throne |
After the army is full: rock -> expansions, decorations, machine skins, Meteor Beacon; DNA -> look hunting + collection.
No rebirth, no stat inflation at launch.

## James decided (1 Nov)
- The three materials: YES (Moon Rock / Goo DNA / Crystal DNA).
- ONE incubator with two eggs.
- Mining: by hand + slow machines (drills, extractors; small capped offline amount).
- Rare eggs change LOOKS only (fights stay fair).

## First build (one plot, ChatGPT)
Starter Launch Pad + Rock Drill + mineable rock + one Goo DNA vein + Incubator + a hatch that adds a Drip to your army
+ Fort 1. Then Crystal DNA + the second egg. Then Fort 1's reward into Goo DNA. Not all 12 machines at once.
