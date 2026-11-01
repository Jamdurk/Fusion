-- Alien Fusion: procedural walk cycles, one per form (James, 27 Oct: each form moves its own way). Numbers from the
-- ChatGPT gait audit (27 Oct), starting values to tune live. fn(p, pose, s): p = phase 0-1 of one cycle, s = studs
-- walked. Angles are degrees in MODEL space (X right, Y up, forward -Z): +rx swings a hanging leg FORWARD and lifts
-- the nose; +ry turns left; +rz rolls the right side down. pose.rot(bone, rx, ry, rz, ox, oy, oz); the whole body's
-- bob / tilt go on the Root bone (pose.lift / pitch / roll / yaw / side), never on the model's pivot, which belongs to
-- the server's movement. stride = studs per cycle (cycle time = stride / speed).
local sin, cos, abs, pi = math.sin, math.cos, math.abs, math.pi
local TAU = 2 * pi
local function S(p, off) return sin(TAU * (p - (off or 0))) end
local function C(p, off) return cos(TAU * (p - (off or 0))) end

local G = {}

-- SQUISH F1 DRIP: little hops, all four nub feet together (0.45 s / 10 studs at 22)
G.SquishF1 = { stride = 10, fn = function(p, pose)
	local hop = abs(sin(pi * p))                         -- one hop per cycle
	pose.lift = 0.35 * hop
	pose.pitch = -6 * S(p)                               -- leans into the take-off, back on landing
	pose.rot("Top", 0, 0, 0, 0, 0.18 * (hop - 0.5), 0)   -- stretch in the air, squash on landing
	local tuck = 12 * S(p)
	for _, f in { "FootFL", "FootFR", "FootBL", "FootBR" } do pose.rot(f, tuck) end
end }

-- SQUISH F2 TWIN: bounces on its flat bottom, the top lobe trailing, arms alternating (0.53 s / 10 studs at 19)
G.SquishF2 = { stride = 10, fn = function(p, pose, s)
	local bounce = abs(sin(pi * p))
	pose.lift = 0.45 * bounce
	pose.roll = 8 * sin(pi * s / 10)                    -- a slow side to side over two bounces
	pose.rot("Lower", -4 * S(p), 0, 0, 0, -0.1 * (1 - bounce), 0)
	pose.rot("Upper", 6 * S(p, 0.15), 0, 4 * S(p, 0.15), 0, 0.4 * (abs(sin(pi * (p - 0.15))) - 0.5), 0)
	pose.rot("ArmL", 18 * S(p), 0, -10 * bounce)
	pose.rot("ArmR", -18 * S(p), 0, 10 * bounce)
end }

-- SQUISH F3 BRUTE: a GORILLA knuckle-walk (James, 27 Oct: "like a gorilla", not a gallop): the big arms swing
-- alternately, each with the opposite hind leg a beat behind, a heavy shoulder roll onto the planted arm and the
-- torso twisting with each reach (0.75 s / 12 studs at 16)
G.SquishF3 = { stride = 12, fn = function(p, pose)
	pose.lift = 0.2 * abs(S(p, 0.1))                     -- vaults over each planted arm (ChatGPT lock: 0.2)
	pose.roll = 6 * S(p)                                 -- the weight rolls onto the planted arm
	pose.yaw = 5 * S(p)
	pose.pitch = -2 * abs(S(p))
	local aL, aR = 28 * S(p), 28 * S(p, 0.5)
	pose.rot("ArmL", aL, 0, 5 * S(p)); pose.rot("HandL", -0.6 * aL)        -- (the knuckles land flat)
	pose.rot("ArmR", aR, 0, 5 * S(p, 0.5)); pose.rot("HandR", -0.6 * aR)
	pose.rot("LegR", 20 * S(p, 0.12)); pose.rot("LegL", 20 * S(p, 0.62))   -- each with the opposite arm, a beat late
	pose.rot("Chest", 3 * abs(S(p)), 8 * S(p), 0)                          -- the shoulders twist into each reach
	pose.rot("Head", -3 * abs(S(p)), -6 * S(p), 0)                         -- the head stays level and forward
end }

-- SQUISH F4 TITAN: slides on its skirt, never bounces; travelling waves down the four tentacles (0.92 s / 11 at 12)
local TENT = { FL = 0, FR = 0.25, BR = 0.5, BL = 0.75 }
-- (James, 27 Oct: "slides across the floor while the tentacles kind of flail slowly": the tentacles run on a
-- slower wave than the body, one full flail per ~2 body cycles)
G.SquishF4 = { stride = 11, fn = function(p, pose, s)
	pose.roll = 4 * S(p)
	pose.yaw = 2 * S(p, 0.25)
	pose.rot("Top", 2 * S(p, 0.3), 0, 3 * S(p, 0.1), 0, 0.25 * S(p, 0.2), 0)  -- the slow rolling undulation
	local q = (s / 24) % 1                                                     -- the flail's own slow phase
	for name, ph in TENT do
		local side = (name == "FL" or name == "BL") and 1 or -1                   -- (FL / BL sit at +X)
		pose.rot("Tent" .. name .. "1", 8 * S(q, ph), 22 * S(q, ph), side * 10 * S(q, ph + 0.1))
		pose.rot("Tent" .. name .. "2", 12 * S(q, ph + 0.15), 30 * S(q, ph + 0.15), side * 16 * S(q, ph + 0.25))
	end
end }

-- CRUNCH F1 PEBBLE: a turtle walk on diagonal pairs FL+BR / FR+BL (0.41 s / 9 studs at 22)
G.CrunchF1 = { stride = 9, fn = function(p, pose)
	pose.lift = 0.1 * abs(S(p))
	pose.roll = 4 * S(p)
	pose.rot("LegFL", 22 * S(p)); pose.rot("LegBR", 22 * S(p))
	pose.rot("LegFR", 22 * S(p, 0.5)); pose.rot("LegBL", 22 * S(p, 0.5))
	pose.rot("Head", 3 * S(2 * p))
	pose.rot("Shell", 0, 0, -2 * S(p))
end }

-- CRUNCH F2 PINCER: a crab scuttle SIDEWAYS (crabs really walk sideways; it faces out of its loop). Six leg bones now
-- (James's video: one bone per side read as a strafe): an alternating TRIPOD, L1+R2+L3 then R1+L2+R3, each leg
-- lifting (roll about its hip) through its swing and sweeping, with a small ripple down each tripod (0.53 s / 10 at 19)
local TRIPOD = { L1 = 0, R2 = 0.06, L3 = 0.12, R1 = 0.5, L2 = 0.56, R3 = 0.62 }
local function crabLegs(p, pose, lift, sweep)
	for leg, ph in TRIPOD do
		local side = (leg:sub(1, 1) == "L") and 1 or -1     -- (the L legs sit at +X: +rz lifts them)
		local up = math.max(0, S(p, ph))                    -- off the ground through half the cycle
		pose.rot("Leg" .. leg, 0, sweep * S(p, ph + 0.25), side * lift * up)
	end
end
G.CrunchF2 = { stride = 10, sideways = true, fn = function(p, pose)
	pose.lift = 0.1 * abs(S(2 * p))
	pose.roll = 4 * S(p)
	pose.side = 0.1 * S(p)
	crabLegs(p, pose, 22, 14)
	pose.rot("ArmL", 0, 12 * S(p, 0.25), 0); pose.rot("ArmR", 0, -12 * S(p, 0.75), 0)
	local snap = 10 * math.max(0, sin(2 * TAU * p))
	pose.rot("ClawL", snap); pose.rot("ClawR", snap)
end }

-- CRUNCH F3 RAM: a heavy trot, diagonal pairs with staggered contacts (not a rocking horse) (0.81 s / 13 at 16)
G.CrunchF3 = { stride = 13, fn = function(p, pose)
	pose.lift = 0.25 * abs(S(p))
	pose.pitch = 5 * S(p, 0.1)
	pose.rot("LegFL", 26 * S(p)); pose.rot("LegBR", 26 * S(p, 0.1))
	pose.rot("LegFR", 26 * S(p, 0.5)); pose.rot("LegBL", 26 * S(p, 0.6))
	pose.rot("Head", -6 * S(2 * p, 0.1))                -- the head nods twice a cycle, against the pitch
	pose.rot("Shell", 2 * S(2 * p, 0.2))
end }

-- CRUNCH F4 COLOSSUS: a GIANT's march (James, 27 Oct: "like a giant walking"; ChatGPT heavy-walk v2): 18 studs / 1.5 s
-- at 12, a footfall every 0.75 s. Weight transfer, not leg swing: each foot lands with a dip, a held contact and a small
-- shudder; the body shifts and rolls onto the planted leg; the swinging leg (no knee) hikes and swings out to clear the
-- ground; the chest leans forward and counter-turns; the arms and gauntlets swing late and heavy; the head stays level.
local function weighty(x) return sin(x) * (0.75 + 0.25 * abs(sin(x))) end   -- (lingers at the extremes)
local function smooth(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end
-- one leg's pose by its own phase q (0 = this foot lands): its forward swing (deg), out-swing (deg) and hip hike (0-1)
local function giantLeg(q)
	if q < 0.10 then return 19, 0, 0 end                              -- the impact: held planted
	if q < 0.50 then return 19 - 38 * smooth((q - 0.10) / 0.40), 0, 0 end  -- stance: the body rolls over it
	local t = (q - 0.50) / 0.50                                        -- swing: back to front, out and up
	return -19 + 38 * smooth(t), 8 * sin(pi * t), sin(pi * t)
end
-- the body's height over one footfall (h = 0 at impact): a quick drop, the recovery, a rise over the swing
local function giantBob(h)
	if h < 0.08 then return -0.35 * (h / 0.08) end
	if h < 0.25 then return -0.35 + 0.35 * smooth((h - 0.08) / 0.17) end
	if h < 0.60 then return 0.18 * smooth((h - 0.25) / 0.35) end
	return 0.18 * (1 - smooth((h - 0.60) / 0.40))
end
-- (the v2 Colossus's walk, kept for reference; James, 27 Oct: "Colossus V4 definitely replaces it")
G.CrunchF4_v2 = { stride = 18, fn = function(p, pose)
	local w = TAU * p
	local h = (p * 2) % 1                                              -- the footfall phase (both feet)
	local shift = sin(w)                                               -- (+ while the left foot carries the weight)
	pose.lift = giantBob(h)
	pose.side = 0.65 * shift                                           -- the body over the planted foot (L sits at +X)
	pose.roll = -4 * shift                                             -- rolling down onto it
	local shudder = (h < 0.15) and 1.2 * sin(h * 70) * (1 - h / 0.15) or 0
	pose.pitch = shudder
	local fL, oL, kL = giantLeg(p)
	local fR, oR, kR = giantLeg((p + 0.5) % 1)
	pose.rot("LegL", fL, 0, oL, 0, 0.45 * kL, 0)                       -- (+rz swings the +X leg out)
	pose.rot("LegR", fR, 0, -oR, 0, 0.45 * kR, 0)
	pose.rot("Hips", 0, 0, 3 * shift, 0, -0.25 * smooth(1 - h / 0.25) * ((h < 0.25) and 1 or 0), 0)  -- hip drop on loading
	pose.rot("Chest", -7, -6 * sin(w), 0)                              -- leaning forward, turning against the legs
	-- the arms swing opposite the legs, 0.10 late, the gauntlets another 0.08 behind
	local aw = TAU * (p - 0.10)
	pose.rot("ArmL", -11 * cos(aw), 0, 2 * shift); pose.rot("ArmR", 11 * cos(aw), 0, 2 * shift)
	local hw = TAU * (p - 0.18)
	pose.rot("HandL", -8 * cos(hw)); pose.rot("HandR", 8 * cos(hw))
	pose.rot("Head", 5 - 0.7 * shudder, 4 * sin(w), 2.8 * shift)      -- level: ~70 % against the torso's motion
end }

-- ===== RUNS (James, 27 Oct: "the running animation" too; ChatGPT run audit: 1.6x the walk speed, and each run a
-- different gait, not the walk sped up). Names <Form>Run; the server spawns at 1.6x speed in RUN mode =====
-- airborne window: 0 on the ground, rising after `up`, down again by `down` (a leap / boing)
local function air(p, up, down)
	if p < up or p > down then return 0 end
	return sin(pi * (p - up) / (down - up))
end

-- DRIP: big leaps: launch 0.1, airborne 0.2-0.7, land 0.85; 0.85 studs up, leaning into it (14 studs / 0.40 s)
G.SquishF1Run = { stride = 14, fn = function(p, pose)
	local a = air(p, 0.1, 0.85)
	pose.lift = 0.85 * a
	pose.pitch = -12 * (1 - a) + 8 * a                    -- crouched forward on the ground, nose up in the air
	pose.rot("Top", 0, 0, 0, 0, 0.3 * (a - 0.4), 0)
	local tuck = 22 * S(p)
	for _, f in { "FootFL", "FootFR", "FootBL", "FootBR" } do pose.rot(f, tuck) end
end }

-- TWIN: mega boings: compress at 0, the top stretching at 0.25, land 0.85 (13 studs / 0.43 s)
G.SquishF2Run = { stride = 13, fn = function(p, pose, s)
	local a = air(p, 0.08, 0.85)
	pose.lift = 0.8 * a
	pose.pitch = -10 + 10 * S(p)
	pose.roll = 6 * sin(pi * s / 13)
	pose.rot("Lower", -6 * S(p), 0, 0, 0, -0.25 * (1 - a), 0)
	pose.rot("Upper", 8 * S(p, 0.25), 0, 0, 0, 0.9 * air(p, 0.15, 0.9) - 0.3, 0)
	pose.rot("ArmL", 28 * S(p), 0, -16 * a)
	pose.rot("ArmR", -28 * S(p), 0, 16 * a)
end }

-- BRUTE: the GORILLA CHARGE: both arms plant at 0, both hind legs drive at 0.35, airborne 0.55 (17 studs / 0.65 s)
G.SquishF3Run = { stride = 17, fn = function(p, pose)
	pose.lift = 0.5 * math.max(0, S(p, 0.3))
	pose.pitch = -7 - 12 * S(p, 0.1)                     -- leaning hard forward, rocking onto the arms
	pose.roll = 3 * S(p, 0.25)
	local arms = 35 * S(p)
	pose.rot("ArmL", arms, 0, 4); pose.rot("HandL", -0.6 * arms)
	pose.rot("ArmR", arms, 0, -4); pose.rot("HandR", -0.6 * arms)
	local legs = 25 * S(p, 0.35)
	pose.rot("LegL", legs); pose.rot("LegR", legs)
	pose.rot("Chest", 6 * S(p, 0.5)); pose.rot("Head", 8 - 8 * S(p, 0.5))  -- the head stays on the target
end }

-- TITAN: the power slide: never leaves the ground, leaning forward, the tentacles streaming back and rippling
-- (one wave per 19 studs = 1.0 s at 19)
G.SquishF4Run = { stride = 19, fn = function(p, pose)
	pose.lift = 0.08 * S(p)
	pose.pitch = -7
	pose.roll = 3 * S(p)
	pose.rot("Top", -3, 0, 2 * S(p, 0.1), 0, 0.15 * S(p, 0.2), 0)
	for name, ph in TENT do
		local side = (name == "FL" or name == "BL") and 1 or -1
		local back = -side * 22                            -- swept toward the back (+Z)
		pose.rot("Tent" .. name .. "1", 6 * S(p, ph), back + 18 * S(p, ph), side * 12 * S(p, ph + 0.1))
		pose.rot("Tent" .. name .. "2", 10 * S(p, ph + 0.15), back * 0.6 + 30 * S(p, ph + 0.15), side * 18 * S(p, ph + 0.25))
	end
end }

-- PEBBLE: a rapid skitter, tiny quick diagonal steps (9 studs / 0.26 s)
G.CrunchF1Run = { stride = 9, fn = function(p, pose)
	pose.lift = 0.08 * abs(S(p))
	pose.pitch = -6 + 3 * S(2 * p)
	pose.roll = 5 * S(p)
	pose.rot("LegFL", 30 * S(p)); pose.rot("LegBR", 30 * S(p))
	pose.rot("LegFR", 30 * S(p, 0.5)); pose.rot("LegBL", 30 * S(p, 0.5))
	pose.rot("Head", -4)
end }

-- PINCER: a crab sprint sideways: leg banks 0 / 0.5, claws pumping 0.25 / 0.75 and held up (11 studs / 0.37 s)
G.CrunchF2Run = { stride = 11, sideways = true, fn = function(p, pose)
	pose.lift = 0.15 * abs(S(p))
	pose.roll = -6 + 5 * S(p)                            -- leaning into the run, rocking
	pose.side = 0.2 * S(p)
	crabLegs(p, pose, 30, 20)
	pose.rot("ArmL", 20 + 10 * S(p, 0.25), 22 * S(p, 0.25), 0); pose.rot("ArmR", 20 + 10 * S(p, 0.75), -22 * S(p, 0.75), 0)
	local snap = 14 * math.max(0, sin(2 * TAU * p))
	pose.rot("ClawL", snap); pose.rot("ClawR", snap)
end }

-- RAM: a full rotary gallop: hind L/R 0 / 0.12, front R/L 0.48 / 0.60, head down (19 studs / 0.73 s)
G.CrunchF3Run = { stride = 19, fn = function(p, pose)
	pose.lift = 0.55 * math.max(0, S(p, 0.2))
	pose.pitch = 12 * S(p, 0.1)
	pose.roll = 4 * S(p, 0.3)
	pose.rot("LegBL", 35 * S(p)); pose.rot("LegBR", 35 * S(p, 0.12))
	pose.rot("LegFR", 35 * S(p, 0.48)); pose.rot("LegFL", 35 * S(p, 0.6))
	pose.rot("Head", -14 - 6 * S(p, 0.3))                -- head down, horns first
	pose.rot("Shell", 3 * S(p, 0.2))
end }

-- COLOSSUS: a heavy jog: longer stride, arms pumping, a flight beat (17 studs / 0.89 s)
G.CrunchF4_v2Run = { stride = 17, fn = function(p, pose)
	local w = TAU * p
	local legs = weighty(w)
	pose.lift = 0.3 * (abs(sin(w)) - 0.5)                -- up in the flight, down through the stance
	pose.pitch = -9 + 7 * sin(2 * w)
	pose.roll = 5 * sin(w)
	pose.rot("LegL", 30 * legs); pose.rot("LegR", -30 * legs)
	pose.rot("ArmL", -25 * weighty(w - 0.3)); pose.rot("ArmR", 25 * weighty(w - 0.3))
	pose.rot("HandL", 12); pose.rot("HandR", 12)          -- forearms bent into the pump
	pose.rot("Chest", -4, 8 * sin(w), 0)
	pose.rot("Head", 4, -5 * sin(w), 0)
end }

-- ===== COLOSSUS (v4, the game's Colossus since 27 Oct): planted feet (James, 27 Oct: "an animation overhaul that matches it"; ChatGPT spec in
-- design/06-COLOSSUS-V4-ANIMATION-SPEC.md: "plant, compress, drag the weight forward, lift, THOOM"). 15 bones: knees
-- (Shin) and ankles (Foot). The legs are NOT posed here: gait.ik makes the animator solve each leg (2-bone IK) onto a
-- foothold locked to the ground; fn only poses the body. Left foot lands at p = 0, right at 0.5. The left leg sits at
-- -X on this rig. (Measured in Studio: thigh 1.92 + shin 2.16 = 4.07 studs of leg under a 15.5-stud body, so
-- ChatGPT's 14-stud stride is out of reach at the rules' 12 studs/s; the reachable stride is ~11 with a crouch.)
-- ik: stride (studs / cycle), stance (share of the cycle a foot is planted), front (foothold ahead of the hip at
-- contact), lift (swing arc), crouch (the hips lowered so the legs can reach), heel / toe (foot pitch at heel strike
-- and toe-off, degrees)
-- (ChatGPT pilot audit r1, "CONDITIONAL GO": the torso must visibly ABSORB each footfall, the gauntlets need more
-- inertia, the charge more aggression: the numbers below are its r1 values)
-- the body's height over one footfall, by seconds since the contact (t): drop over 0.07 s, hold 0.06 s, recover over
-- 0.16 s to a small rise, then ease back down before the next contact (half = seconds between footfalls)
local function v4Dip(t, half, dip, rise)
	if t < 0.07 then return -dip * smooth(t / 0.07) end
	if t < 0.13 then return -dip end
	if t < 0.29 then return -dip + (dip + rise) * smooth((t - 0.13) / 0.16) end
	return rise * (1 - smooth((t - 0.29) / math.max(0.05, half - 0.29)))
end
-- the gauntlets' overshoot after a footfall: on to +1 by 0.05 s, back to 0 by 0.25 s
local function v4Overshoot(t)
	if t < 0.05 then return smooth(t / 0.05) end
	return 1 - smooth((t - 0.05) / 0.20)
end
local function v4Body(p, pose, k)
	local w = TAU * p
	local h = (p * 2) % 1
	local t = h * k.half                                              -- seconds since the last footfall
	local shift = sin(w)                                              -- (+ while the LEFT foot carries the weight)
	-- the impact rings up through the stone and settles (a damped wobble after each footfall)
	local settle = math.exp(-h * 7) * sin(h * TAU * 1.5)
	local hit = v4Overshoot(t)
	pose.lift = -k.crouch + v4Dip(t, k.half, k.dip, k.rise)
	pose.side = -k.side * shift                                       -- over the planted foot
	-- the upper body SWINGS with the legs (James, 27 Oct: "his upper body or his arms don't sway with his legs"). The
	-- hips turn with the forward leg; the belly, then the chest, twist the other way, each a little later, so the
	-- shoulders lead the opposite arm forward. (The first pass twisted the chest against the belly: they cancelled
	-- and the shoulders stayed square.) Each bone's turn adds to its parent's
	local tw = TAU * (p - 0.05)
	pose.rot("Hips", 0, -k.hipYaw * cos(w), -k.roll * shift)          -- rolling down onto the planted leg
	pose.rot("Belly", -k.lean - 1.5 * settle, k.yaw * cos(tw), 0)     -- leaning in, turning against the legs
	pose.rot("Chest", -0.8 * settle + k.recoil * hit, k.yaw2 * cos(TAU * (p - 0.08)),   -- (the charge: kicks back on impact)
		-k.chestRoll * sin(TAU * (p - 0.08)))                          -- the shoulders rock over the planted leg, late
	-- the arms swing opposite the legs, late, from the twisting shoulders; the gauntlets later still, and they carry
	-- on forward / down after each impact, then settle. (They hang plumb from the leaning torso)
	local aw = TAU * (p - k.armLag)
	local out = k.armOut * shift                                      -- (swinging a little out from the body with the sway)
	pose.rot("ArmL", k.lean * 0.8 - k.arm * cos(aw), 0, -out); pose.rot("ArmR", k.lean * 0.8 + k.arm * cos(aw), 0, -out)
	local hw = TAU * (p - k.armLag - k.handLag)
	pose.rot("HandL", -k.hand * cos(hw) + k.overshoot * hit, 0, 0)
	pose.rot("HandR", k.hand * cos(hw) + k.overshoot * hit, 0, 0)
	-- the head keeps looking ahead: it undoes most of the shoulders' turn and roll
	local turned = k.yaw * cos(tw) + k.yaw2 * cos(TAU * (p - 0.08)) - k.hipYaw * cos(w)
	pose.rot("Head", 0.75 * k.lean + 0.75 * settle - 0.75 * k.recoil * hit, -0.7 * turned, 0.75 * k.roll * shift)
end
-- (half = seconds between footfalls: stride / 2 / speed; the pilot walks at 8 studs/s, charges at 12.8)
-- (hipYaw / yaw / yaw2: the hips' turn and the belly's and chest's twist against it, degrees; the shoulders end up
-- ~13 deg twisted from the hips. arm 18: the old 8 vanished under the gauntlets. armOut: the arms' swing out with the sway)
local V4WALK = { half = 11 / 16, crouch = 1.1, dip = 0.50, rise = 0.16, side = 0.70, roll = 5.5, lean = 6,
	hipYaw = 6, yaw = 6, yaw2 = 7, chestRoll = 2, arm = 18, armOut = 3, armLag = 0.10, hand = 10, handLag = 0.12,
	overshoot = 8, recoil = 0 }
local V4RUN = { half = 13 / 25.6, crouch = 1.6, dip = 0.62, rise = 0.10, side = 0.4, roll = 3, lean = 18,
	hipYaw = 5, yaw = 5, yaw2 = 6, chestRoll = 1.5, arm = 24, armOut = 2, armLag = 0.12, hand = 12, handLag = 0.12,
	overshoot = 10, recoil = 5 }
-- (start = the phase a fresh walker begins at: the right foot planted under the body, the left mid-swing, so the first
-- step out of the idle is a lifted foot, not both feet sliding apart)
G.CrunchF4 = { stride = 11, ik = { stride = 11, stance = 0.55, front = 2.55, lift = 0.95, heel = 9, toe = 13, start = 0.77 },
	fn = function(p, pose) v4Body(p, pose, V4WALK) end }
-- the CHARGE: a stone beast driving forward, not a jog: deeper crouch, big lean, short stance, hard impacts
G.CrunchF4Run = { stride = 13, ik = { stride = 13, stance = 0.46, front = 2.6, lift = 1.35, heel = 9, toe = 20, start = 0.75 },
	fn = function(p, pose) v4Body(p, pose, V4RUN) end }
-- IDLE, a living mountain: a 5.5 s breath, a weight shift every 6-9 s, the gauntlets settling, a slow look around.
-- fn(t, pose): t = seconds; feet stay planted (the animator locks both)
local function rnd(n) return (sin(n * 12.9898 + 78.233) * 43758.5453) % 1 end
G.CrunchF4Idle = { idle = true, stride = 11, ik = { stride = 11, stance = 1, front = 0, lift = 0, heel = 0, toe = 0 },
	fn = function(t, pose)
		local br = sin(TAU * t / 5.5)
		-- weight shifts: hold on one foot, ease across over ~1.6 s, at uneven 6-9 s intervals
		local seg = math.floor(t / 7.5)
		local into = t - seg * 7.5 - rnd(seg) * 1.5
		local from, to = (seg % 2 == 0) and 1 or -1, (seg % 2 == 0) and -1 or 1
		local shift = from + (to - from) * smooth(into / 1.6)
		pose.lift = -0.35 + 0.08 * br
		pose.side = -0.2 * shift
		pose.rot("Hips", 0, 0, -1.5 * shift)
		pose.rot("Belly", -3 - 0.75 * br, 0, 0)
		pose.rot("Chest", -1.5 * br, 0, 0.5 * shift)                    -- the chest swells with the breath
		local lag = sin(TAU * (t - 0.3) / 5.5)
		pose.rot("ArmL", 2.4 + 1.2 * lag, 0, 0); pose.rot("ArmR", 2.4 + 1.2 * lag, 0, 0)
		pose.rot("HandL", 2 * lag, 2, 0); pose.rot("HandR", 2 * lag, -2, 0)   -- (the fists tighten inward)
		-- the look: a new random target every 8-12 s, turned to over ~1.5 s
		local lk = math.floor(t / 10)
		local lt = t - lk * 10
		local a0, a1 = (rnd(lk - 1) * 2 - 1) * 8, (rnd(lk) * 2 - 1) * 8
		local yaw = a0 + (a1 - a0) * smooth((lt - rnd(lk + 7) * 2) / 1.5)
		pose.rot("Head", 2.2 + 3 * sin(TAU * t / 13), yaw, -0.6 * shift)
		pose.glow = 0.12 * br                                             -- the core breathes too
	end }

-- ===== PHASE 1 REBUILD (v5) forms (28 Oct 2026; plan design/08-REBUILD-PLAN.md). Each is built to its ChatGPT
-- reference pack (design/concepts/<form>/), and moves the way its body is built. `beats`: phases of the cycle where
-- the animator plays the form's footfall sound + puff (see AlienAnimator, BEAT_FX) =====

-- a smooth loop through four values at p = 0, .25, .5, .75 (back to the first at 1)
local function key4(p, a, b, c, d)
	local v = { a, b, c, d, a }
	local x = (p % 1) * 4
	local i = math.floor(x)
	local f = smooth(x - i)
	return v[i + 1] + (v[i + 2] - v[i + 1]) * f
end

-- SQUISH TITAN v5: it SLIDES on its goo skirt (no legs). Its pose sheet (design/concepts/titan/I-pose-sheet-chatgpt.png):
-- GATHER (squash, lean back, tentacles in) -> SURGE (stretch tall, lean in, front tentacles reach, back ones trail) ->
-- GLIDE (upright, wobbling) -> SETTLE (overshoot, jiggle). The tentacles also flail slowly on their own clock (James,
-- 27 Oct: "slides across the floor while the tentacles kind of flail slowly"). Bones: Root, Body (skirt->waist),
-- Top (dome), Tent<FL|FR|BL|BR><1..3>, Lid. (FL / BL sit at +X in Studio: the build's -X; model forward is -Z.)
local TITAN_TENTS = { FL = { sx = 1, front = true, ph = 0 }, FR = { sx = -1, front = true, ph = 0.5 },
	BL = { sx = 1, front = false, ph = 0.25 }, BR = { sx = -1, front = false, ph = 0.75 } }
local function titanBody(p, pose, s, k)
	local w = TAU * p
	local settle = (p > 0.7) and math.exp(-(p - 0.7) * 9) * sin((p - 0.7) * TAU * 3) or 0
	pose.lift = k.lift * key4(p, -0.45, 0.35, 0.05, 0.1)
	pose.fwd = k.surge * key4(p, -0.4, 0.55, 0.2, -0.1)
	pose.roll = 2.2 * sin(w + 0.6)
	pose.yaw = 1.5 * sin(w * 0.5)
	pose.rot("Body", k.lean * key4(p, 0.55, -1, 0, -0.45) - 3 * settle, 0, 1.5 * sin(w))
	pose.rot("Top", k.lean * key4(p, 0.3, -0.45, 0.1, -0.2) + 4 * settle + 1.5 * sin(w * 2), 2 * sin(w + 1), 2 * sin(w * 2 + 0.4),
		0, k.stretch * key4(p, -0.55, 0.75, 0.1, 0) + 0.12 * settle, 0)
	-- tentacles: the surge reach + a slow flail running down each one
	local q = (s / k.flailStuds) % 1
	for name, t in pairs(TITAN_TENTS) do
		local reach = t.front and k.reach * key4(p, -0.35, 1, 0.3, -0.2) or -k.reach * key4(p, -0.2, 0.7, 0.4, 0)
		for seg = 1, 3 do
			local wave = sin(TAU * (q - t.ph - seg * 0.12))
			local yaw = (reach * (1.15 - seg * 0.25) + k.flail * wave) * t.sx
			local lift = -t.sx * (k.curl * seg * 0.6 * (0.6 + 0.4 * sin(TAU * (q - t.ph - seg * 0.12 + 0.25))) + 4 * key4(p, 1, -0.5, 0, 0.5))
			pose.rot("Tent" .. name .. seg, 0, yaw, lift)
		end
	end
end
local TITAN_WALK = { lift = 1, surge = 1, lean = 9, stretch = 1, reach = 22, flail = 9, curl = 7, flailStuds = 22 }
local TITAN_RUN = { lift = 1.35, surge = 1.5, lean = 13, stretch = 1.3, reach = 30, flail = 13, curl = 9, flailStuds = 18 }
G.SquishF4v5 = { stride = 9, beats = { 0.25 }, fn = function(p, pose, s) titanBody(p, pose, s, TITAN_WALK) end }
G.SquishF4v5Run = { stride = 13, beats = { 0.25 }, fn = function(p, pose, s) titanBody(p, pose, s, TITAN_RUN) end }
-- IDLE: the dome breathes (a slow swell), the tentacles curl and uncurl lazily, now and then a shiver runs through it
G.SquishF4v5Idle = { idle = true, stride = 9, fn = function(t, pose)
	local br = sin(TAU * t / 4.8)
	local shiver = ((t % 7.3) < 0.6) and math.exp(-(t % 7.3) * 6) * sin((t % 7.3) * 40) or 0
	pose.lift = -0.1 + 0.12 * br
	pose.rot("Body", 1.5 * br, 0, 0)
	pose.rot("Top", -1 * br + 2 * shiver, 2 * sin(TAU * t / 9), 2 * shiver, 0, 0.18 * br, 0)
	for name, tt in pairs(TITAN_TENTS) do
		for seg = 1, 3 do
			local wave = sin(TAU * (t / 6 - tt.ph - seg * 0.15))
			pose.rot("Tent" .. name .. seg, 0, 6 * wave * tt.sx, -tt.sx * (5 * seg * (0.5 + 0.5 * sin(TAU * (t / 7.5 - tt.ph - seg * 0.1)))))
		end
	end
end }

-- CRUNCH RAM v5: a heavy stone bull on four planted hooves (planted-foot IK, the Colossus's, per leg). Its pose sheet
-- (design/concepts/ram/I-pose-sheet-chatgpt.png): a TROT, diagonal pairs (front-left + back-right together), the hooves
-- slam down, the body dips on every pair's landing and rises through the moment between, the head nods against the
-- dip, the hump rolls toward the planted front leg, the tail fan swings. At the rules' 16 studs/s its 3-stud legs need
-- a short suspension (stance 0.4); the RUN is a bounding gallop (the hind pair, then the front pair).
-- Bones: Root, Chest (front half) + Head, Hips (back half) + Tail, Leg / Shin / Foot <FL FR BL BR>. (FL = its left: the
-- build's +X, Studio's -X; model forward is -Z.) Leg reach, measured in the build:
-- front 1.59 + 1.40, hind 1.65 + 1.22 studs under hips 3.45 / 3.3 high.
local RAM_LEGS_TROT = { FL = 0, BR = 0, FR = 0.5, BL = 0.5 }
local RAM_LEGS_GALLOP = { BL = 0.5, BR = 0.58, FL = 0, FR = 0.08 }
local RAM_BACK = { BL = true, BR = true }
-- (sound: Boomy Footsteps, the Colossus's giant stomp, pitched up and softer for a 7-stud beast; measured in Play)
-- (ChatGPT movement audit: a landing every 0.22 s read "too frantic for a heavy ram"; at the rules' 16 studs/s its fallback
-- is an 8.4-stud stride, 0.26 s, but measured that put the swinging hoof 0.61 out of reach; 7.7 + a deeper crouch is
-- the most these 3-stud legs carry at 16 (0.24 s). Its first choice, walk 12.5 studs/s, is James's rules call)
local RAM_IK = { stride = 7.7, stance = 0.36, front = 1.4, lift = 0.65, heel = 4, toe = 22, toeZ = -0.55, heelZ = 0.3,
	legs = RAM_LEGS_TROT, back = RAM_BACK, start = 0.25, thudVol = 0.85, thudPitch = 1.2, shake = 0.05, dust = 4 }
-- (run: measured in Play, stride 10 put the swinging hoof 0.6 out of reach just before contact; 9 + a deeper crouch
-- keeps it within reach: contact 2.5, lift-off 2.6, late swing 2.96 of 2.98 studs)
local RAM_RUN_IK = { stride = 9, stance = 0.3, front = 1.3, lift = 1.1, heel = 4, toe = 28, toeZ = -0.55, heelZ = 0.3,
	legs = RAM_LEGS_GALLOP, back = RAM_BACK, start = 0.2, thudVol = 0.95, thudPitch = 1.15, shake = 0.06, dust = 5 }
local function ramBody(p, pose, k)
	local w = TAU * p
	local h = (p * k.beatsPer) % 1                                       -- (0 at each landing)
	local dip = cos(TAU * (h - 0.1))                                     -- (+1 = lowest, just after a landing)
	local settle = math.exp(-h * 6) * sin(h * TAU * 1.5)
	pose.lift = -k.crouch - k.dip * dip
	pose.pitch = k.pitch * sin(w + k.pitchPh)                             -- (the gallop rocks nose / tail)
	pose.roll = k.roll * sin(w)                                          -- (onto the planted front leg)
	pose.side = -0.08 * sin(w)
	pose.rot("Chest", -k.hump * dip + 1.2 * settle, k.yaw * sin(w), k.roll * 0.5 * sin(w - 0.6))
	pose.rot("Hips", k.hump * 0.6 * dip, -k.yaw * sin(w), -k.roll * 0.5 * sin(w - 0.6))
	-- the head nods down into each landing, then lifts (and keeps looking ahead: it undoes the chest's turn)
	pose.rot("Head", -k.nod * cos(TAU * (h - 0.18)) - 2 * settle - k.lean, -k.yaw * 0.8 * sin(w), 0)
	pose.rot("Tail", 3 + k.tail * 0.35 * cos(TAU * (h - 0.3)), k.tail * sin(w - 1.1), 0)
end
local RAM_TROT = { beatsPer = 2, crouch = 0.6, dip = 0.18, pitch = 0, pitchPh = 0, roll = 2.5, hump = 2, yaw = 3,
	nod = 4, lean = 2, tail = 12 }
local RAM_GALLOP = { beatsPer = 2, crouch = 0.6, dip = 0.1, pitch = 4, pitchPh = 1.2, roll = 1.5, hump = 2.5, yaw = 2,
	nod = 6, lean = 6, tail = 16 }
G.CrunchF3v5 = { stride = 7.7, ik = RAM_IK, fn = function(p, pose) ramBody(p, pose, RAM_TROT) end }
G.CrunchF3v5Run = { stride = 9, ik = RAM_RUN_IK, fn = function(p, pose) ramBody(p, pose, RAM_GALLOP) end }
-- IDLE: snorting breath (the hump swells), a weight shift now and then, a slow look around, the tail fan flicks
G.CrunchF3v5Idle = { idle = true, stride = 7, ik = { stride = 7, stance = 1, front = 0, lift = 0, heel = 0, toe = 0,
	toeZ = -0.55, heelZ = 0.3, legs = RAM_LEGS_TROT, back = RAM_BACK },
	fn = function(t, pose)
		local br = sin(TAU * t / 3.6)
		local snort = ((t % 6.8) < 0.5) and math.exp(-(t % 6.8) * 8) or 0
		local seg = math.floor(t / 8)
		local shift = ((seg % 2 == 0) and 1 or -1) * smooth((t - seg * 8 - rnd(seg) * 2) / 1.4)
		pose.lift = -0.15 + 0.05 * br
		pose.side = -0.12 * shift
		pose.roll = 1.2 * shift
		pose.rot("Chest", -1.2 * br, 0, 0)
		pose.rot("Hips", 0.5 * br, 0, 0)
		local lk = math.floor(t / 9)
		local a0, a1 = (rnd(lk - 1) * 2 - 1) * 14, (rnd(lk) * 2 - 1) * 14
		local yaw = a0 + (a1 - a0) * smooth((t - lk * 9 - rnd(lk + 3) * 2) / 1.2)
		pose.rot("Head", -3 + 2 * br + 6 * snort, yaw, 0)
		local flick = ((t % 4.3) < 0.7) and sin((t % 4.3) / 0.7 * TAU) or 0
		pose.rot("Tail", 2 + 1.5 * br, 18 * flick, 0)
		pose.glow = 0.1 * br + 0.3 * snort
	end }

-- SQUISH BRUTE v5: a goo GORILLA knuckle-walking on planted fists and feet (the animator's 4-leg IK: the arms are its
-- front legs, elbows bending back). Its pose sheet (design/concepts/brute/I-pose-sheet-chatgpt.png): a fist lands, then
-- the opposite foot; the huge shoulders roll over the planted arm, the body rocks side to side, the head stays level.
-- The RUN is the gorilla CHARGE (both fists, then both feet: a bound). Bones: Root, Hips, Chest, Head, Lid,
-- Leg / Shin / Foot <FL FR (arms) BL BR (legs)>.
local BRUTE_WALK_LEGS = { FL = 0, BR = 0.1, FR = 0.5, BL = 0.6 }
local BRUTE_CHARGE_LEGS = { FL = 0, FR = 0.06, BL = 0.5, BR = 0.56 }
local BRUTE_BACK = { FL = true, FR = true }
-- (footfall: the Titan's wet goo slap, a goo splash instead of dust)
-- (measured in Play: stride 6.5 / front 1.3 put the hands + feet 0.9 out of reach late in the swing: its arms already
-- rest reaching 1.15 ahead and its legs are 2.1 long. Now the arms plant 0.5 nearer (frontBy), a deeper crouch, 5.5)
local BRUTE_IK = { stride = 5.5, stance = 0.5,   -- (ChatGPT movement audit: longer knuckle contact)
	 front = 0.95, lift = 0.6, frontBy = { FL = -0.5, FR = -0.5 }, heel = 0, toe = 14, toeZ = -0.45, heelZ = 0.3,
	legs = BRUTE_WALK_LEGS, back = BRUTE_BACK, start = 0.3, goo = true, dust = 6,
	thud = "rbxassetid://9113520180", thudVol = 2.2, thudPitch = 0.95, shake = 0.04 }
local BRUTE_RUN_IK = { stride = 7, stance = 0.3, front = 1.0, lift = 0.9, frontBy = { FL = -0.6, FR = -0.6 }, heel = 0, toe = 18, toeZ = -0.45, heelZ = 0.3,
	legs = BRUTE_CHARGE_LEGS, back = BRUTE_BACK, start = 0.3, goo = true, dust = 8,
	thud = "rbxassetid://9113520180", thudVol = 2.6, thudPitch = 0.9, shake = 0.06 }
local function bruteBody(p, pose, k)
	local w = TAU * p
	local h = (p * 2) % 1                                                 -- (0 at each fist landing)
	local dip = cos(TAU * (h - 0.12))                                     -- (+1 = lowest, just after a landing)
	local settle = math.exp(-h * 6) * sin(h * TAU * 1.5)
	pose.lift = -k.crouch - k.dip * dip
	pose.side = -k.sway * sin(w)                                          -- (over the planted fist)
	pose.roll = k.roll * sin(w)
	pose.pitch = k.pitch * sin(w + 1.3)                                   -- (the charge rocks fists / feet)
	-- the shoulders ROLL over the planted arm and turn with the swinging one (they lead, the hips follow)
	pose.rot("Chest", -k.lean - k.hump * dip + settle, k.yaw * sin(w - 0.4), k.shoulder * sin(w - 0.3))
	pose.rot("Hips", 0, -k.yaw * 0.5 * sin(w), -k.roll * 0.4 * sin(w))
	-- the head stays level and looks ahead: it undoes most of the chest's turn and roll
	pose.rot("Head", k.lean * 0.8 + k.nod * cos(TAU * (h - 0.2)), -k.yaw * 0.8 * sin(w - 0.4), -k.shoulder * 0.75 * sin(w - 0.3))
end
local BRUTE_WALK = { crouch = 0.6, dip = 0.12, sway = 0.25, roll = 4, pitch = 0, yaw = 8, shoulder = 6, lean = 4, hump = 2, nod = 2 }
local BRUTE_CHARGE = { crouch = 0.75, dip = 0.2, sway = 0.1, roll = 2, pitch = 6, yaw = 4, shoulder = 3, lean = 10, hump = 3, nod = 3 }
G.SquishF3v5 = { stride = 5.5, ik = BRUTE_IK, fn = function(p, pose) bruteBody(p, pose, BRUTE_WALK) end }
G.SquishF3v5Run = { stride = 7, ik = BRUTE_RUN_IK, fn = function(p, pose) bruteBody(p, pose, BRUTE_CHARGE) end }
-- IDLE: heavy breathing (the shoulders rise), a weight shift from fist to fist, a slow suspicious look around, and every
-- ~9 s a CHEST PUFF (it rears back and swells); fists + feet stay planted
G.SquishF3v5Idle = { idle = true, stride = 6.5, ik = { stride = 6.5, stance = 1, front = 0, lift = 0, heel = 0, toe = 0,
	toeZ = -0.45, heelZ = 0.3, legs = BRUTE_WALK_LEGS, back = BRUTE_BACK, goo = true },
	fn = function(t, pose)
		local br = sin(TAU * t / 3.2)
		local pt = t % 9.1
		local puff = (pt < 1.4) and sin(math.pi * pt / 1.4) or 0
		local seg = math.floor(t / 7)
		local shift = ((seg % 2 == 0) and 1 or -1) * smooth((t - seg * 7 - rnd(seg + 11) * 2) / 1.3)
		pose.lift = -0.2 + 0.06 * br + 0.12 * puff
		pose.side = -0.15 * shift
		pose.roll = 2 * shift
		pose.rot("Chest", -4 + 1.5 * br + 7 * puff, 0, 1.5 * shift, 0, 0.08 * puff, 0)
		local lk = math.floor(t / 8)
		local a0, a1 = (rnd(lk + 20) * 2 - 1) * 16, (rnd(lk + 21) * 2 - 1) * 16
		local yaw = a0 + (a1 - a0) * smooth((t - lk * 8 - rnd(lk + 5) * 2) / 1.0)
		pose.rot("Head", 3 - 1.5 * br - 6 * puff, yaw, -1.2 * shift)
		pose.glow = 0.1 * br + 0.4 * puff
	end }

-- CRUNCH PINCER v5: a stone crab scuttling SIDEWAYS (it faces out of its loop) on a procedural TRIPOD (L1+R2+L3, then
-- R1+L2+R3). Too small and quick for planted feet at 19 studs/s (the leg rule), so each leg lifts (roll about its hip),
-- tucks its shin and sweeps; the shell bobs twice a cycle and tilts toward the planted tripod; the claws are held up,
-- swaying, and snap. Its pose sheet: design/concepts/pincer/I-pose-sheet-chatgpt.png. Bones: Root, Body,
-- Arm / Claw / Pinch <L R>, Leg / Shin <L1-3 R1-3> (L = its left: the build's +X, Studio's -X, so -rz lifts an L leg).
local PINCER_TRIPOD = { L1 = 0, R2 = 0.05, L3 = 0.1, R1 = 0.5, L2 = 0.55, R3 = 0.6 }
local function pincerBody(p, pose, k)
	local w = TAU * p
	pose.lift = k.bob * abs(sin(w)) - k.crouch
	pose.roll = k.roll * sin(w)
	pose.side = 0.08 * sin(w)
	for leg, ph in PINCER_TRIPOD do
		local side = (leg:sub(1, 1) == "L") and -1 or 1
		local up = math.max(0, sin(TAU * (p - ph)))                       -- (in the air through half the cycle)
		pose.rot("Leg" .. leg, 0, k.sweep * sin(TAU * (p - ph) + math.pi / 2) * side, side * k.lift * up)
		pose.rot("Shin" .. leg, 0, 0, side * k.tuck * up)                 -- (the foot tucks in as it lifts)
	end
	-- the claws: held up, swaying out of phase, a snap every half cycle (the lower jaw opens and bites shut)
	local snap = math.max(0, sin(w + 0.6)) ^ 2                        -- (ChatGPT movement audit: one snap a cycle)
	pose.rot("ArmL", k.armUp, k.sway * sin(w + 0.4), 0); pose.rot("ArmR", k.armUp, -k.sway * sin(w + 0.4 + math.pi), 0)
	pose.rot("ClawL", 6 * sin(w)); pose.rot("ClawR", -6 * sin(w))
	pose.rot("PinchL", -k.snap * snap); pose.rot("PinchR", -k.snap * snap)
end
-- (ChatGPT movement audit: sweep 35 / 45 and claws up 22, like its pose sheet's boxer guard. It walks SIDEWAYS, so a
-- fore-aft sweep cannot hide sideways sliding: 25 / 35, enough to read busy, not paddle)
local PINCER_WALK = { bob = 0.12, crouch = 0.05, roll = 4, lift = 24, tuck = 18, sweep = 25, armUp = 22, sway = 10, snap = 18 }
local PINCER_RUN = { bob = 0.16, crouch = 0.15, roll = 3, lift = 30, tuck = 24, sweep = 35, armUp = 24, sway = 6, snap = 10 }
G.CrunchF2v5 = { stride = 8, sideways = true, fn = function(p, pose) pincerBody(p, pose, PINCER_WALK) end }
G.CrunchF2v5Run = { stride = 11, sideways = true, fn = function(p, pose) pincerBody(p, pose, PINCER_RUN) end }
-- IDLE: the shell breathes, the legs shuffle now and then, the claws open slowly and SNAP shut every ~5 s
G.CrunchF2v5Idle = { idle = true, stride = 8, sideways = true, fn = function(t, pose)
	local br = sin(TAU * t / 2.8)
	pose.lift = -0.05 + 0.03 * br
	local ct = t % 5.3
	local open = (ct < 1.6) and smooth(ct / 1.6) or (ct < 1.75) and 1 - (ct - 1.6) / 0.15 or 0
	pose.rot("PinchL", -26 * open); pose.rot("PinchR", -26 * (t % 7.1 < 1.7 and smooth((t % 7.1) / 1.7) or 0))
	pose.rot("ArmL", 6 + 3 * br, 4 * sin(TAU * t / 6), 0); pose.rot("ArmR", 6 + 3 * br, -4 * sin(TAU * t / 6 + 1), 0)
	local sh = t % 4.1
	if sh < 0.5 then
		local up = sin(math.pi * sh / 0.5)
		pose.rot("LegL2", 0, 0, -14 * up); pose.rot("LegR1", 0, 0, 14 * up)
	end
	pose.rot("Body", 0, 3 * sin(TAU * t / 7), 1.5 * br)
end }

-- SQUISH TWIN v5: an upright goo peanut that BOUNCE-SLIDES on its puddle (no legs). Its pose sheet
-- (design/concepts/twin/I-pose-sheet-chatgpt.png): SQUASH (sinks into the puddle, lobes wide, tendrils down) ->
-- LAUNCH (stretches tall, springs up, tendrils fling up) -> GLIDE (leans forward, the puddle trails) -> LAND (splat +
-- wobble, tendrils swing forward). The puddle (Base) stays on the ground; the lobes ride on Body / Top offsets.
-- Bones: Root, Base, Body, Top, Lid, Tend<L R><1-3> (L = its left, the build's +X).
local function twinBody(p, pose, k)
	local w = TAU * p
	local hop = (p > 0.15 and p < 0.85) and sin(math.pi * (p - 0.15) / 0.7) or 0          -- (up off the puddle)
	local squash = (p < 0.15) and sin(math.pi * p / 0.15) or (p > 0.88) and 0.6 * sin(math.pi * (p - 0.88) / 0.12) or 0
	local wob = (p < 0.4) and math.exp(-p * 8) * sin(p * TAU * 3) or 0                     -- (the landing jiggle)
	pose.fwd = k.surge * sin(w - 0.6)
	pose.roll = 3 * sin(w * 0.5)
	pose.rot("Body", -k.lean * hop + 4 * wob, 0, 3 * wob, 0, k.hop * hop - k.squash * squash, 0)
	pose.rot("Top", -k.lean * 0.6 * hop - 6 * wob, 4 * sin(w), 2 * sin(w * 2), 0, k.stretch * hop - k.squash * 0.6 * squash, 0)
	-- the tendrils: flung up on the launch, swinging forward on the landing, a lagging wave down each
	for s, sx in pairs({ L = -1, R = 1 }) do
		local fling = k.fling * (hop - 0.6 * squash)
		for seg = 1, 3 do
			local lag = sin(w - seg * 0.7)
			pose.rot("Tend" .. s .. seg, k.swing * lag, 0, sx * (fling * (1.2 - seg * 0.25) + 8 * lag))
		end
	end
end
local TWIN_WALK = { hop = 0.55, squash = 0.25, stretch = 0.2, lean = 10, surge = 0.25, fling = 28, swing = 18 }
local TWIN_RUN = { hop = 0.85, squash = 0.3, stretch = 0.3, lean = 16, surge = 0.35, fling = 36, swing = 24 }
G.SquishF2v5 = { stride = 7, beats = { 0.0 }, fn = function(p, pose) twinBody(p, pose, TWIN_WALK) end }
G.SquishF2v5Run = { stride = 10, beats = { 0.0 }, fn = function(p, pose) twinBody(p, pose, TWIN_RUN) end }
-- IDLE: the peanut sways and jiggles on its puddle, the tendrils float, a little hop every 6.2 s
G.SquishF2v5Idle = { idle = true, stride = 7, fn = function(t, pose)
	local br = sin(TAU * t / 2.6)
	local ht = t % 6.2
	local hop = (ht < 0.55) and sin(math.pi * ht / 0.55) or 0
	pose.rot("Body", 2 * br, 0, 3 * sin(TAU * t / 4.1), 0, 0.05 * br + 0.35 * hop, 0)
	pose.rot("Top", -2 * br, 6 * sin(TAU * t / 5.3), -3 * sin(TAU * t / 4.1 + 0.6), 0, 0.06 * br, 0)
	for s, sx in pairs({ L = -1, R = 1 }) do
		for seg = 1, 3 do
			local wv = sin(TAU * (t / 3.1 - seg * 0.12) + (sx > 0 and 1.5 or 0))
			pose.rot("Tend" .. s .. seg, 10 * wv, 0, sx * (6 * wv + 20 * hop))
		end
	end
end }

-- CRUNCH PEBBLE v5: a little stone beetle SCUTTLING forward on a procedural TRIPOD (L1+R2+L3, then R1+L2+R3): too
-- small and quick for planted feet at 22 studs/s. Each leg lifts (about its hip) and swings forward in the air, back
-- on the ground; the shell bobs twice a cycle and rocks toward the planted tripod; the head + horn bob and look about.
-- Bones: Root, Body, Head, Leg / Shin <L1-3 R1-3> (L = its left: the build's +X, Studio's -X, so -rz lifts an L leg).
local PEBBLE_TRIPOD = { L1 = 0, R2 = 0.04, L3 = 0.08, R1 = 0.5, L2 = 0.54, R3 = 0.58 }
local function pebbleBody(p, pose, k)
	local w = TAU * p
	pose.lift = k.bob * abs(sin(w))
	pose.roll = k.roll * sin(w)
	pose.pitch = 1.5 * sin(2 * w)
	for leg, ph in PEBBLE_TRIPOD do
		local side = (leg:sub(1, 1) == "L") and -1 or 1
		local q = TAU * (p - ph)
		local up = math.max(0, sin(q))                                  -- (in the air through half the cycle)
		-- (+rx swings a hanging leg forward: forward in the air, back along the ground)
		pose.rot("Leg" .. leg, k.swing * cos(q), 0, side * k.lift * up)
		pose.rot("Shin" .. leg, 0, 0, side * k.tuck * up)
	end
	pose.rot("Head", k.nod * sin(2 * w + 0.5), k.look * sin(w * 0.5), 0)
end
local PEBBLE_WALK = { bob = 0.05, roll = 3, swing = 22, lift = 20, tuck = 16, nod = 4, look = 6 }
local PEBBLE_RUN = { bob = 0.07, roll = 2, swing = 30, lift = 26, tuck = 22, nod = 6, look = 3 }
-- (ChatGPT movement audit: a 5 Hz tripod at 4.5 studs reads buzzy -> 5.5 / 8: 4 Hz walk, 4.4 Hz run)
G.CrunchF1v5 = { stride = 5.5, fn = function(p, pose) pebbleBody(p, pose, PEBBLE_WALK) end }
G.CrunchF1v5Run = { stride = 8, fn = function(p, pose) pebbleBody(p, pose, PEBBLE_RUN) end }
-- IDLE: the shell breathes, the head turns to look, now and then a leg twitches and the horn tips up
G.CrunchF1v5Idle = { idle = true, stride = 4.5, fn = function(t, pose)
	local br = sin(TAU * t / 2.2)
	pose.lift = 0.02 * br
	local lk = math.floor(t / 4)
	local yaw = (rnd(lk + 30) * 2 - 1) * 20 * smooth((t - lk * 4) / 0.4)
	local tip = ((t % 5.7) < 0.6) and sin(math.pi * (t % 5.7) / 0.6) or 0
	pose.rot("Head", 3 * br + 10 * tip, yaw, 0)
	local tw = t % 3.3
	if tw < 0.25 then pose.rot("LegR2", 0, 0, 16 * sin(math.pi * tw / 0.25)) end
	pose.rot("Body", 0.8 * br, 0, 0)
end }

-- SQUISH DRIP v5: a goo droplet that HOPS on its two nub feet (both together: too small and quick for planted feet
-- at 22 studs/s). SQUASH on the landing, SPRING up with the feet tucked and the curl trailing, a little splat on each
-- landing (its beat). Bones: Root, Body, Top, Curl, Lid, Foot<L R>, Arm<L R>.
local function dripBody(p, pose, k)
	local air = (p > 0.18 and p < 0.92) and sin(math.pi * (p - 0.18) / 0.74) or 0        -- (off the ground)
	local squash = (p < 0.18) and sin(math.pi * p / 0.18) or 0
	local wob = (p < 0.5) and math.exp(-p * 7) * sin(p * TAU * 2.5) or 0
	pose.lift = k.hop * air
	pose.pitch = -k.lean * air + 3 * wob
	pose.rot("Body", 0, 0, 3 * wob, 0, -k.squash * squash, 0)
	pose.rot("Top", -6 * air + 8 * wob, 0, 0, 0, k.stretch * air - 0.5 * k.squash * squash, 0)
	pose.rot("Curl", -k.curl * air + 14 * wob, 0, 0)                        -- (the curl trails, then flops forward)
	pose.rot("FootL", k.tuck * air, 0, 0); pose.rot("FootR", k.tuck * air, 0, 0)
	pose.rot("ArmL", 0, 0, -k.arms * air + 10 * wob); pose.rot("ArmR", 0, 0, k.arms * air - 10 * wob)
end
-- (ChatGPT movement audit: PASS 9/10; landing squash 0.12 -> 0.18)
local DRIP_WALK = { hop = 0.75, lean = 8, squash = 0.18, stretch = 0.12, curl = 18, tuck = 20, arms = 30 }
local DRIP_RUN = { hop = 1.05, lean = 14, squash = 0.15, stretch = 0.16, curl = 26, tuck = 28, arms = 40 }
G.SquishF1v5 = { stride = 8, beats = { 0.0 }, fn = function(p, pose) dripBody(p, pose, DRIP_WALK) end }
G.SquishF1v5Run = { stride = 11, beats = { 0.0 }, fn = function(p, pose) dripBody(p, pose, DRIP_RUN) end }
-- IDLE: it bobs and jiggles in place, looks about, the curl sways, a tiny bounce every 4.7 s
G.SquishF1v5Idle = { idle = true, stride = 8, fn = function(t, pose)
	local br = sin(TAU * t / 1.9)
	local bt = t % 4.7
	local bounce = (bt < 0.4) and sin(math.pi * bt / 0.4) or 0
	pose.lift = 0.25 * bounce
	pose.rot("Body", 1.5 * br, 8 * sin(TAU * t / 5.5), 0, 0, 0.03 * br, 0)
	pose.rot("Top", -2 * br, 0, 3 * sin(TAU * t / 3.3), 0, 0.03 * br, 0)
	pose.rot("Curl", 6 * sin(TAU * t / 2.4) - 10 * bounce, 0, 4 * sin(TAU * t / 3.1))
	pose.rot("ArmL", 0, 0, -8 * br - 25 * bounce); pose.rot("ArmR", 0, 0, 8 * br + 25 * bounce)
end }

return G
