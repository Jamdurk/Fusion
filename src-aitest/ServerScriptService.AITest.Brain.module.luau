-- Alien Fusion AI TEST: the shared brain, ported from design/ai/brain.mjs + profiles.mjs + orca.mjs (v2.2, ChatGPT SHIP).
-- Layers per unit: SENSE -> APPRAISE (fear vs courage) -> CHOOSE TARGET (utility score) -> POSITION (slot / evade / guard /
-- facing) -> STEER (ORCA + acceleration + turn limits). Think at 5 Hz (staggered), plan + integrate every fixed step, all
-- units plan from the SAME snapshot, then all move. Not ported: nav.mjs (the grid path round boulders: the test ground is
-- open moon floor) and the sim's bookkeeping metrics.
-- Plane: x, z (studs). Facing f follows AITest: forward = (sin f, -cos f). Slot sectors use math angles in (x, z).
-- Contract with AITest: units carry { x, z, r, reach, fk ("F1".."F4"), race, team, matter, dead, hp, maxHp, face, brain };
-- the caller sets e.brain.attackers before tick() and passes hostile(a, b).
local Brain = {}

-- ===== profiles (design/ai/profiles.mjs: every number's source is there) =====
local BRAIN = {
	thinkEvery = 0.2, senseRange = 60, commit = 1.5, minHold = 1.0, reactRange = { 0.15, 0.45 }, speedJitter = 0.04,
	orca = { horizon = 0.4, neighbourRange = 6, radiusScale = 0.8 },
	evadeFear = 0, noticeAt = 25,
	overkill = { horizon = 1.5, over = 1.15, factor = 0.55 },
	stuck = { window = 1.5, minProgress = 0.25 },
}
local PREY = {
	F1 = { F4 = 3.0, F3 = 2.4, F1 = 1.0, F2 = 0.35 },
	F2 = { F1 = 3.0, F2 = 1.0, F4 = 0.6, F3 = 0.35 },
	F3 = { F2 = 3.0, F3 = 1.0, F1 = 1.0, F4 = 0.3 },
	F4 = { F3 = 3.0, F4 = 1.0, F2 = 1.0, F1 = 0.6 },
}
local PREDATOR = { F1 = "F2", F2 = "F3", F3 = "F4", F4 = "F1" }
local PROFILES = {
	SQUISH = {
		F1 = { name = "Drip", falloff = 12, accel = 80, gangUp = { want = 6, cap = 10, bonus = 1.4, full = 0.4 }, spreadVs = { F2 = 1.6 },
			courage = 0, evade = { radius = 25, holdMax = 3.0 }, wedgeAvoid = 0.5, slotSpacing = 1.0 },
		F2 = { name = "Twin", falloff = 10, accel = 60, guard = { radius = 18, bonus = 1.8, annoyPerTick = 0.2, angryAt = 2.5, angryFor = 3.25 },
			courage = 0, evade = { radius = 22, holdMax = 3.0 }, wedgeAvoid = 0.5, slotSpacing = 1.0 },
		F3 = { name = "Brute", falloff = 14, accel = 40, stayNear = { radius = 8, weight = 0.3 },
			courage = 0, evade = { radius = 25, holdMax = 2.5 }, wedgeAvoid = 1.0, slotSpacing = 1.1 },
		F4 = { name = "Titan", falloff = 12, accel = 16, facing = { weight = 0.6, moveCone = 60 }, swarmed = { count = 6, toFriends = "F2" },
			courage = 0, wedgeAvoid = 0, slotSpacing = 1.0 },
	},
	CRUNCH = {
		F1 = { name = "Pebble", falloff = 12, accel = 80, gangUp = { want = 6, cap = 10, bonus = 1.4, full = 0.4 }, spreadVs = { F2 = 1.6 },
			courage = 1, evade = { radius = 18, holdMax = 1.5 }, wedgeAvoid = 0, slotSpacing = 1.0 },
		F2 = { name = "Pincer", falloff = 10, accel = 60, guard = { radius = 14, bonus = 1.5, annoyPerTick = 0.2, angryAt = 2.5, angryFor = 3.25 },
			hold = { secs = 2.0, leash = 6 }, courage = 1, evade = { radius = 16, holdMax = 1.5 }, wedgeAvoid = 0.5, slotSpacing = 1.0 },
		F3 = { name = "Ram", falloff = 14, accel = 40, ramp = { from = 0.7, after = 0.6, over = 1.0, turnLoss = 0.2, sharp = 45 },
			courage = 1, evade = { radius = 18, holdMax = 1.5 }, wedgeAvoid = 1.0, slotSpacing = 1.1 },
		F4 = { name = "Colossus", falloff = 12, accel = 14, facing = { weight = 0.6, moveCone = 60 }, swarmed = { count = 6, toFriends = "F2" },
			courage = 1, wedgeAvoid = 0, slotSpacing = 1.0 },
	},
}
Brain.BRAIN, Brain.PREY, Brain.PREDATOR, Brain.PROFILES = BRAIN, PREY, PREDATOR, PROFILES

-- (code review r3 #15: a bad number throws at start-up, never NaN later)
local function validate()
	local function pos(v, n) assert(type(v) == "number" and v == v and v > 0 and v < math.huge, "profile " .. n .. " must be > 0") end
	local function nonNeg(v, n) assert(type(v) == "number" and v == v and v >= 0 and v < math.huge, "profile " .. n .. " must be >= 0") end
	pos(BRAIN.thinkEvery, "thinkEvery"); pos(BRAIN.senseRange, "senseRange"); pos(BRAIN.commit, "commit"); nonNeg(BRAIN.minHold, "minHold")
	pos(BRAIN.orca.horizon, "orca.horizon"); pos(BRAIN.orca.radiusScale, "orca.radiusScale"); pos(BRAIN.orca.neighbourRange, "orca.neighbourRange")
	pos(BRAIN.stuck.window, "stuck.window"); assert(BRAIN.reactRange[1] <= BRAIN.reactRange[2], "reactRange min > max")
	for race, forms in PROFILES do
		for form, P in forms do
			local n = race .. "." .. form
			pos(P.falloff, n .. ".falloff"); pos(P.accel, n .. ".accel"); pos(P.slotSpacing, n .. ".slotSpacing"); nonNeg(P.wedgeAvoid, n .. ".wedgeAvoid")
			if P.gangUp then pos(P.gangUp.want, n .. ".gangUp.want"); pos(P.gangUp.cap, n .. ".gangUp.cap") end
			if P.ramp then pos(P.ramp.over, n .. ".ramp.over"); assert(P.ramp.from > 0 and P.ramp.from <= 1, n .. ".ramp.from must be in (0, 1]") end
			if P.evade then pos(P.evade.radius, n .. ".evade.radius") end
			if P.guard then pos(P.guard.radius, n .. ".guard.radius"); pos(P.guard.angryAt, n .. ".guard.angryAt") end
			for f, v in P.spreadVs or {} do pos(v, n .. ".spreadVs." .. f) end
		end
	end
end
validate()

-- ===== ORCA (RVO2, Apache 2.0: design/ai/orca.mjs, itself from snape/RVO2 src/Agent.cc). Vector2 = (x, z) =====
local EPS = 1e-5
local function det(a: Vector2, b: Vector2) return a.X * b.Y - a.Y * b.X end
local function unitOf(a: Vector2) local L = a.Magnitude; return (L > 0) and a / L or a end
local function lp1(lines, no, radius, opt: Vector2, dirOpt: boolean)
	local L = lines[no]
	local dp = L.point:Dot(L.dir)
	local disc = dp * dp + radius * radius - L.point:Dot(L.point)
	if disc < 0 then return nil end
	local sd = math.sqrt(disc)
	local tL, tR = -dp - sd, -dp + sd
	for i = 1, no - 1 do
		local den = det(L.dir, lines[i].dir)
		local num = det(lines[i].dir, L.point - lines[i].point)
		if math.abs(den) <= EPS then
			if num < 0 then return nil end
		else
			local t = num / den
			if den >= 0 then tR = math.min(tR, t) else tL = math.max(tL, t) end
			if tL > tR then return nil end
		end
	end
	if dirOpt then
		return (opt:Dot(L.dir) > 0) and L.point + L.dir * tR or L.point + L.dir * tL
	end
	local t = L.dir:Dot(opt - L.point)
	return L.point + L.dir * math.clamp(t, tL, tR)
end
local function lp2(lines, radius, opt: Vector2, dirOpt: boolean)
	local res
	if dirOpt then res = opt * radius
	elseif opt:Dot(opt) > radius * radius then res = unitOf(opt) * radius
	else res = opt end
	for i = 1, #lines do
		if det(lines[i].dir, lines[i].point - res) > 0 then
			local r = lp1(lines, i, radius, opt, dirOpt)
			if not r then return i, res end
			res = r
		end
	end
	return #lines + 1, res
end
local function lp3(lines, begin, radius, res: Vector2)
	local distance = 0
	for i = begin, #lines do
		if det(lines[i].dir, lines[i].point - res) > distance then
			local proj = {}
			for j = 1, i - 1 do
				local d = det(lines[i].dir, lines[j].dir)
				local point
				if math.abs(d) <= EPS then
					if lines[i].dir:Dot(lines[j].dir) > 0 then continue end
					point = (lines[i].point + lines[j].point) * 0.5
				else
					point = lines[i].point + lines[i].dir * (det(lines[j].dir, lines[i].point - lines[j].point) / d)
				end
				table.insert(proj, { point = point, dir = unitOf(lines[j].dir - lines[i].dir) })
			end
			local fail, r = lp2(proj, radius, Vector2.new(-lines[i].dir.Y, lines[i].dir.X), true)
			if fail > #proj then res = r end
			distance = det(lines[i].dir, lines[i].point - res)
		end
	end
	return res
end
-- me = { p, v, r }; neighbours = { { p, v, r, share } } (share = my part of the avoidance: 0.5 = RVO2, 1 = all mine)
local function computeVelocity(me, prefV: Vector2, maxSpeed: number, nbs, horizon: number, dt: number): Vector2
	local lines = {}
	local inv = 1 / horizon
	for _, o in nbs do
		local relP, relV = o.p - me.p, me.v - o.v
		local distSq, R = relP:Dot(relP), me.r + o.r
		local RSq = R * R
		local dir, u
		if distSq > RSq then
			local w = relV - relP * inv
			local wLenSq, dp = w:Dot(w), w:Dot(relP)
			if dp < 0 and dp * dp > RSq * wLenSq then
				local wLen = math.sqrt(wLenSq)
				local unitW = w / wLen
				dir = Vector2.new(unitW.Y, -unitW.X)
				u = unitW * (R * inv - wLen)
			else
				local leg = math.sqrt(distSq - RSq)
				if det(relP, w) > 0 then dir = Vector2.new(relP.X * leg - relP.Y * R, relP.X * R + relP.Y * leg) / distSq
				else dir = -Vector2.new(relP.X * leg + relP.Y * R, -relP.X * R + relP.Y * leg) / distSq end
				u = dir * relV:Dot(dir) - relV
			end
		else
			local invT = 1 / dt
			local w = relV - relP * invT
			local wLen = math.max(w.Magnitude, EPS)
			local unitW = w / wLen
			dir = Vector2.new(unitW.Y, -unitW.X)
			u = unitW * (R * invT - wLen)
		end
		table.insert(lines, { point = me.v + u * (o.share or 0.5), dir = dir })
	end
	local fail, res = lp2(lines, maxSpeed, prefV, false)
	if fail <= #lines then res = lp3(lines, fail, maxSpeed, res) end
	return res
end
Brain.computeVelocity = computeVelocity

-- ===== helpers =====
local SECTORS = 24          -- audit r1 #2: one shared angular grid per target, whatever the attacker's size
local function wrap(a) a = (a + math.pi) % (2 * math.pi); return a - math.pi end
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end
local function gapOf(a, b) return dist(a, b) - a.r - b.r end
local function heading(dx, dz) return math.atan2(dx, -dz) end   -- (AITest facing of a direction)
local function alive(u) return u and not u.dead end

-- ctx: { units = { unit }, now = () -> number, DT = number, hostile = (a, b) -> boolean, rand = () -> number }
function Brain.new(ctx)
	assert(type(ctx.DT) == "number" and ctx.DT > 0, "brain: DT must be > 0")
	local rand, DT, hostile = ctx.rand or math.random, ctx.DT, ctx.hostile
	local B = {}
	local function ringOf(u, e) return e.r + u.r * 0.9 + u.reach * 0.5 end
	local function spacing(u, e) return (u.brain.prof.spreadVs and u.brain.prof.spreadVs[e.fk]) or u.brain.prof.slotSpacing or 1 end
	-- how many of the target's 24 sectors one attacker covers (a Drip on a Titan: 1; a Brute on a Pack: 4)
	local function need(u, e) return math.max(1, math.ceil(2 * u.r * spacing(u, e) / (2 * math.pi * ringOf(u, e) / SECTORS))) end
	local nextId = 0

	function B.init(u)
		local r0, r1 = BRAIN.reactRange[1], BRAIN.reactRange[2]
		nextId += 1
		u.brain = { id = nextId, prof = PROFILES[u.race][u.fk], target = nil, targetSince = -9, mode = "ENGAGE", goal = nil,
			nextThink = ctx.now() + rand() * BRAIN.thinkEvery, react = r0 + (r1 - r0) * rand(), noticeUntil = 0, met = false,
			speedMul = 1 + (rand() * 2 - 1) * BRAIN.speedJitter, vx = 0, vz = 0, evadeT = 0, fightUntil = 0,
			progAt = ctx.now(), progX = u.x, progZ = u.z, detourUntil = 0, annoy = 0, angryUntil = 0,
			unreach = {}, blocked = false, blockedEvent = 0, blockedSeen = 0, yield = false, pursuit = 0, postUntil = 0,
			attackers = 0, slots = {} }
	end

	-- ---------- slots: sectors of the target this unit holds ----------
	local function holder(e, i, u)
		local o = e.brain.slots[i]
		return o and o ~= u and alive(o) and o.brain.target == e
	end
	local function sectorsFree(e, u) local n = 0; for i = 0, SECTORS - 1 do if not holder(e, i, u) then n += 1 end end; return n end
	local function releaseSlot(u)
		local A = u.brain
		local e = A.slotTarget
		if e and e.brain and A.sectors then for _, i in A.sectors do if e.brain.slots[i] == u then e.brain.slots[i] = nil end end end
		A.slot, A.sectors, A.slotTarget = nil, nil, nil
	end
	local function resetRoute(A)
		A.detour, A.detourUntil, A.progAt, A.progD, A.winYield, A.winTicks = nil, 0, ctx.now(), nil, 0, 0
	end
	function B.clearTarget(u)
		local A = u.brain
		releaseSlot(u); A.target, A.goal, A.saviour, A.evadeFrom = nil, nil, nil, nil; resetRoute(A)
	end
	function B.setMode(u, mode)
		local A = u.brain
		if A.mode == mode then return end
		if mode == "EVADE" or mode == "GUARD" then releaseSlot(u) end   -- (audit r2 #1: leaving the ring frees my sectors)
		A.mode = mode; resetRoute(A)
	end

	-- ---------- target value (Infinite-Axis style: a product of considerations) ----------
	local function score(u, e, incoming)
		local A, P, t = u.brain, u.brain.prof, ctx.now()
		local g = math.max(0, gapOf(u, e))
		local s = PREY[u.fk][e.fk] or 1
		s *= 1 / (1 + (g / P.falloff) ^ 2)                                          -- distance curve
		if P.gangUp and (e.fk == "F4" or e.fk == "F3") then                        -- swarm: FOCUS a big one until 6+ are on it
			local n = (e.brain.attackers or 0) - ((e == A.target) and 1 or 0)
			s *= (n >= P.gangUp.cap) and P.gangUp.full or 1 + (P.gangUp.bonus - 1) * math.min(n, P.gangUp.want) / P.gangUp.want * 2
		elseif (incoming[e] or 0) > e.hp * BRAIN.overkill.over and e ~= A.target then
			s *= BRAIN.overkill.factor                                               -- spread fire (SC2)
		end
		if u.fk ~= "F4" and sectorsFree(e, u) < need(u, e) then s *= 0.3 end       -- no room round it: look elsewhere
		if P.facing then s *= 1 - P.facing.weight * math.abs(wrap(heading(e.x - u.x, e.z - u.z) - u.face)) / math.pi end
		if P.guard and e.fk == "F1" then                                            -- bodyguard: peel swarmers off big friends
			for _, f in ctx.units do
				if f ~= u and alive(f) and not hostile(u, f) and (f.fk == "F3" or f.fk == "F4") and dist(f, u) < P.guard.radius and gapOf(f, e) < 2.5 then
					s *= P.guard.bonus * ((A.angryUntil > t) and 1.3 or 1); break
				end
			end
		end
		if (A.unreach[e] or 0) > t then s *= 0.2 end
		if e == A.target then s *= BRAIN.commit end
		return s
	end

	local function pickTarget(u, pool, incoming, t)
		local A = u.brain
		local best, bs = nil, -1
		for _, e in pool do local s = score(u, e, incoming); if s > bs then bs, best = s, e end end
		local cur = alive(A.target) and A.target or nil
		if cur and best ~= cur and t - A.targetSince < BRAIN.minHold then best = cur end   -- hysteresis
		if best ~= A.target then releaseSlot(u); A.target, A.targetSince, A.pursuit = best, t, 0; resetRoute(A) end
	end

	-- ---------- THINK (5 Hz) ----------
	local function think(u, foes, friends, incoming)
		local A, P, t = u.brain, u.brain.prof, ctx.now()
		if #foes == 0 then B.clearTarget(u); return end
		local pool = {}
		for _, e in foes do if dist(u, e) < BRAIN.senseRange then table.insert(pool, e) end end
		if #pool == 0 then pool = foes end
		-- APPRAISE (LC Baboon Hawk): fear = sum threat / (dist x 0.2) - group + 1 - courage. Only hunters count.
		local fear, pred, predD = 0, nil, 1e9
		if P.evade then
			for _, e in pool do
				if e.fk == PREDATOR[u.fk] then
					local d = math.max(1, gapOf(u, e))
					if d <= P.evade.radius then
						fear += (3 + ((e.brain and e.brain.target == u) and 1 or 0)) / (d * 0.2)
						if d < predD then predD, pred = d, e end
					end
				end
			end
			local group = 0
			for _, f in friends do if f ~= u and dist(f, u) < 15 then group += 1 end end
			fear = fear - group / 4 + 1 - P.courage
		end
		-- EVADE behind the nearest friend that hunts my hunter, never longer than holdMax (LC Spore Lizard: cornered = fight)
		local saviour, sd = nil, 60
		if pred then
			for _, f in friends do
				if f.fk == PREDATOR[pred.fk] and dist(f, u) < sd then saviour, sd = f, dist(f, u) end
			end
		end
		-- Packs and Brutes evade selectively (audit r2 #2): a protector within 14, a spot >= 4 further from the hunter, and
		-- never while already hitting their prey (unless below 30 % HP). The swarm: unchanged.
		if saviour and u.fk ~= "F1" and A.mode ~= "EVADE" then
			local d = math.max(0.1, dist(saviour, pred))
			local off = saviour.r + u.r + 2
			local spot = { x = saviour.x + (saviour.x - pred.x) / d * off, z = saviour.z + (saviour.z - pred.z) / d * off }
			local hittingPrey = A.target and A.target.fk ~= PREDATOR[u.fk] and gapOf(u, A.target) <= u.reach
			if dist(saviour, u) > 14 or dist(spot, pred) - dist(u, pred) < 4 or (hittingPrey and u.hp > 0.3 * u.maxHp) then saviour = nil end
		end
		-- a BLOCKED event is consumed once (audit r2 #3)
		if A.blockedEvent ~= A.blockedSeen then
			A.blockedSeen = A.blockedEvent
			if A.mode == "EVADE" then A.fightUntil = t + ((u.fk == "F1") and 3 or 6); A.evadeT = 0
			elseif A.mode == "ENGAGE" and A.target then A.unreach[A.target] = t + 2; A.targetSince = -9
			elseif A.mode == "GUARD" then A.noHoldUntil = t + ((P.hold and P.hold.secs) or 2) end
		end
		if pred and saviour and fear > BRAIN.evadeFear and t > A.fightUntil then
			A.evadeT += BRAIN.thinkEvery
			if A.evadeT > P.evade.holdMax then A.fightUntil = t + ((u.fk == "F1") and 3 or 6); A.evadeT = 0
			else B.setMode(u, "EVADE"); A.evadeFrom, A.saviour = pred, saviour; return end
		else
			A.evadeT = math.max(0, A.evadeT - BRAIN.thinkEvery)
		end
		if A.mode == "EVADE" then B.setMode(u, "ENGAGE") end
		-- bodyguards (LC Hoarding Bug): swarmers on a big friend nearby fill an annoyance meter; full = angry for a while
		if P.guard then
			local pest = false
			for _, e in pool do
				if e.fk == "F1" then
					for _, f in friends do
						if (f.fk == "F3" or f.fk == "F4") and dist(f, u) < P.guard.radius and gapOf(f, e) < 2.5 then pest = true; break end
					end
				end
				if pest then break end
			end
			A.annoy = pest and A.annoy + P.guard.annoyPerTick or math.max(0, A.annoy - P.guard.annoyPerTick / 2)
			if A.annoy > P.guard.angryAt then A.angryUntil, A.annoy = t + P.guard.angryFor, 0 end
		end
		pickTarget(u, pool, incoming, t)
		if not A.met and A.target and gapOf(u, A.target) < BRAIN.noticeAt then A.met = true; A.noticeUntil = t + A.react end
	end

	-- ---------- POSITION: where to stand ----------
	local function slotCost(u, e, P, friends, c, bear)
		local a, ring = c * 2 * math.pi / SECTORS, ringOf(u, e)
		local cost = math.abs(wrap(a - bear)) * ring                                 -- studs to walk round
		if e.fk == "F4" and P.wedgeAvoid > 0 then
			-- (a big one's front 120 deg wedge: its slam lands there)
			local fx, fz = math.sin(e.face), -math.cos(e.face)
			if math.cos(a) * fx + math.sin(a) * fz > 0.5 then cost += P.wedgeAvoid * math.pi * ring end
		end
		if P.stayNear then
			local sx, sz = e.x + math.cos(a) * ring, e.z + math.sin(a) * ring
			local nf = 1e9
			for _, f in friends do if f ~= u then nf = math.min(nf, math.sqrt((f.x - sx) ^ 2 + (f.z - sz) ^ 2)) end end
			cost += P.stayNear.weight * ring * math.max(0, nf - P.stayNear.radius) / P.stayNear.radius
		end
		return cost
	end
	local function pickSlot(u, e, P, friends)
		local k, bear = need(u, e), math.atan2(u.z - e.z, u.x - e.x)
		local best, bc = -1, 1e9
		for c = 0, SECTORS - 1 do
			local ok = true
			for j = 0, k - 1 do
				if holder(e, (c - k // 2 + j) % SECTORS, u) then ok = false; break end
			end
			if ok then
				local cost = slotCost(u, e, P, friends, c, bear)
				if cost < bc then bc, best = cost, c end
			end
		end
		return best, bc, k
	end

	local function goalFor(u, friends)
		local A, P, e, t = u.brain, u.brain.prof, u.brain.target, ctx.now()
		if A.mode == "EVADE" and alive(A.saviour) and A.evadeFrom then         -- behind the friend that counters my hunter
			local s, p = A.saviour, A.evadeFrom
			local d = math.max(0.1, dist(s, p))
			local off = s.r + u.r + 2
			return { x = s.x + (s.x - p.x) / d * off, z = s.z + (s.z - p.z) / d * off }
		end
		if not e then return nil end
		-- Pincer (LC Nutcracker sentry): next to a big friend with a real swarm threat on it and nothing it wants in reach
		-- -> hold a post between the friend and the threat for 2 s (moves only if the friend walks > 6 off it)
		if P.hold then
			local big, bd = nil, 1e9
			for _, f in friends do
				if (f.fk == "F3" or f.fk == "F4") and dist(f, u) < P.guard.radius and dist(f, u) < bd then
					for _, x in ctx.units do
						if alive(x) and hostile(u, x) and x.fk == "F1" and dist(x, f) < 12 then big, bd = f, dist(f, u); break end
					end
				end
			end
			local preyInReach = gapOf(u, e) <= u.reach
			if A.blocked and A.mode == "GUARD" then A.noHoldUntil = t + P.hold.secs end
			if big and not preyInReach and t > (A.noHoldUntil or 0) then
				if not A.post or t > A.postUntil or dist(big, A.post.anchor) > P.hold.leash then
					local d = math.max(0.1, dist(big, e))
					local off = big.r + u.r + 2
					A.post = { x = big.x + (e.x - big.x) / d * off, z = big.z + (e.z - big.z) / d * off, anchor = { x = big.x, z = big.z } }
					A.postUntil = t + P.hold.secs
				end
				B.setMode(u, "GUARD")
				return { x = A.post.x, z = A.post.z }
			end
			A.post = nil
			if A.mode == "GUARD" then B.setMode(u, "ENGAGE") end
		end
		if u.fk == "F4" then
			-- a giant: walk to reach along the line, but if 6+ swarmers are on it, slide towards its Packs
			local sw = P.swarmed
			if sw then
				local onMe = 0
				for _, f in ctx.units do if alive(f) and hostile(u, f) and f.fk == "F1" and gapOf(f, u) < 2 then onMe += 1 end end
				if onMe >= sw.count then
					local help, hd = nil, 1e9
					for _, f in friends do if f.fk == sw.toFriends and dist(f, u) < hd then help, hd = f, dist(f, u) end end
					if help then return { x = help.x, z = help.z } end
				end
			end
			local d = math.max(0.1, dist(u, e))
			local stand = u.r + e.r + u.reach * 0.5
			return { x = e.x + (u.x - e.x) / d * stand, z = e.z + (u.z - e.z) / d * stand }
		end
		-- melee slot on a shared 24-sector ring: keep it until the target changes, I'm blocked, or after 1.5 s a free spot
		-- is >= 2 studs shorter to walk to (audit r1 #2: no orbiting)
		local ring = ringOf(u, e)
		local lost = false
		if A.slot then for _, i in A.sectors do if holder(e, i, u) then lost = true; break end end end
		if not A.slot or lost or A.blocked or t - A.slot.at > 1.5 then
			local c, cost, k = pickSlot(u, e, P, friends)
			local curCost = (A.slot and not lost and not A.blocked) and slotCost(u, e, P, friends, A.slot.c, math.atan2(u.z - e.z, u.x - e.x)) or 1e9
			if c >= 0 and cost < curCost - 2 then
				releaseSlot(u)
				A.sectors = {}
				for j = 0, k - 1 do local i = (c - k // 2 + j) % SECTORS; table.insert(A.sectors, i); e.brain.slots[i] = u end
				A.slot, A.slotTarget = { c = c, at = t }, e
			elseif c < 0 and (not A.slot or lost) then                                -- ring full: wait a body-width outside it
				releaseSlot(u)
				local d = math.max(0.1, dist(u, e))
				return { x = e.x + (u.x - e.x) / d * (ring + 2 * u.r), z = e.z + (u.z - e.z) / d * (ring + 2 * u.r) }
			elseif A.slot then
				A.slot.at = t
			end
		end
		local a = A.slot.c * 2 * math.pi / SECTORS
		return { x = e.x + math.cos(a) * ring, z = e.z + math.sin(a) * ring }
	end

	-- the per-step entry point: think when due, then the goal follows a moving target (cheap: the slot itself is sticky)
	function B.tick(u, foes, friends, incoming)
		local A, t = u.brain, ctx.now()
		if A.target and not alive(A.target) then B.clearTarget(u) end
		if t >= A.nextThink then A.nextThink = t + BRAIN.thinkEvery; think(u, foes, friends, incoming) end
		A.goal = goalFor(u, friends)
		return A.target
	end

	-- ---------- STEER, phase 1: a velocity from the shared snapshot (nobody has moved yet this step) ----------
	-- speed = the form's top speed now (slows already applied); stop = true when it should stand (in reach / busy)
	function B.plan(u, speed, stop)
		local A, P, t = u.brain, u.brain.prof, ctx.now()
		local goal = (A.detourUntil > t) and A.detour or A.goal
		if stop then goal = nil end
		-- Ram (LC Thumper): a straight pursuit starts at 70 % speed, builds to 100 % after 0.6 s, turns 20 % worse at full
		local rampK, turnK = 1, 1
		if P.ramp and A.mode == "ENGAGE" then
			local k = math.clamp((A.pursuit - P.ramp.after) / P.ramp.over, 0, 1)
			rampK, turnK = P.ramp.from + (1 - P.ramp.from) * k, 1 - P.ramp.turnLoss * k
		end
		local maxV = speed * A.speedMul * rampK
		local pv = Vector2.zero
		A.walkDir = nil
		if goal then
			local dx, dz = goal.x - u.x, goal.z - u.z
			local L = math.sqrt(dx * dx + dz * dz)
			if L > 0.5 then A.walkDir = heading(dx, dz) end
			-- (brake only in the last 1.5 studs: a speed-scaled brake made the swarm crawl the last 8 studs into melee)
			if L > 0.3 and t >= A.noticeUntil then pv = Vector2.new(dx, dz) / L * (maxV * math.min(1, L / 1.5)) end
		end
		if P.ramp then   -- the ramp resets on a sharp turn or when blocked
			local dir = (pv.Magnitude > 0.1) and math.atan2(pv.Y, pv.X) or nil
			if not dir or A.blocked or (A.lastDir and math.abs(wrap(dir - A.lastDir)) > math.rad(P.ramp.sharp)) then A.pursuit = 0 else A.pursuit += DT end
			A.lastDir = dir
		end
		-- ORCA against everyone near; bigger units barely give way to small ones (share = matter split)
		local nb, R = {}, BRAIN.orca.neighbourRange
		for _, o in ctx.units do
			if o == u or not alive(o) or o == A.target then continue end   -- (never steer around the thing I'm trying to hit)
			local d = dist(u, o)
			if d > R + u.r + o.r then continue end
			if o.pinned then                                                          -- (held by an attack: a fixed circle, I do all of it)
				table.insert(nb, { p = Vector2.new(o.x, o.z), v = Vector2.zero, r = o.r * BRAIN.orca.radiusScale, share = 1 })
				continue
			end
			if hostile(u, o) and d > u.r + o.r + 2 then continue end                 -- enemies only matter up close
			local ox, oz = o.x, o.z
			if d < 0.001 then                                                         -- exact overlap: a deterministic split
				local a = math.rad((A.id * 7919 + o.brain.id * 104729) % 360); ox += math.cos(a) * 0.01; oz += math.sin(a) * 0.01
			end
			table.insert(nb, { p = Vector2.new(ox, oz), v = Vector2.new(o.brain.vx, o.brain.vz), r = o.r * BRAIN.orca.radiusScale, share = o.matter / (u.matter + o.matter) })
		end
		local me = { p = Vector2.new(u.x, u.z), v = Vector2.new(A.vx, A.vz), r = u.r * BRAIN.orca.radiusScale }
		local v = (#nb > 0) and computeVelocity(me, pv, maxV, nb, BRAIN.orca.horizon, DT) or pv
		A.yield = pv.Magnitude > 0.5 and v.Magnitude < 0.5 * pv.Magnitude          -- avoidance holding it back (not a failure)
		-- acceleration (LC: speed has inertia; Titans 16 studs/s^2, the swarm 80)
		local acc, amax = v - me.v, P.accel * DT * turnK
		if acc.Magnitude > amax then v = me.v + acc.Unit * amax end
		-- giants move only roughly where they face (turning is the slow part)
		if P.facing and v.Magnitude > 0.01 then
			local off = math.abs(wrap(heading(v.X, v.Y) - u.face))
			v = (off > math.rad(P.facing.moveCone)) and v * 0.15 or v * math.cos(off * 0.5)
		end
		if v.X ~= v.X or v.Y ~= v.Y then v = Vector2.zero end
		A.nv, A.wantGoal, A.maxV = v, goal, maxV
	end

	-- ---------- STEER, phase 2: everyone moves at once ----------
	function B.integrate(u)
		local A, t = u.brain, ctx.now()
		if not A.nv then return end
		A.vx, A.vz, A.nv = A.nv.X, A.nv.Y, nil
		u.x += A.vx * DT; u.z += A.vz * DT
		-- the progress window only covers time spent trying to move: restart it after a fight / stun / busy spell
		if t - (A.lastMoveT or -9) > DT * 1.5 then A.progAt, A.progX, A.progZ, A.winYield, A.winTicks = t, u.x, u.z, 0, 0 end
		A.lastMoveT = t; A.winTicks = (A.winTicks or 0) + 1; if A.yield then A.winYield = (A.winYield or 0) + 1 end
		-- BLOCKED (audit r1 #5): progress over 1.5 s < 25 % of what it should be -> sidestep (LC Snare Flea re-routes)
		if t - A.progAt > BRAIN.stuck.window then
			local goal = A.wantGoal
			local moved = math.sqrt((u.x - A.progX) ^ 2 + (u.z - A.progZ) ^ 2)
			local nowD = goal and math.sqrt((goal.x - u.x) ^ 2 + (goal.z - u.z) ^ 2) or 0
			local closer = (A.progD or nowD) - nowD
			local wanted = goal and nowD > u.r + 1 and t >= A.noticeUntil
			local yielding = A.winYield > A.winTicks / 2
			local minP = BRAIN.stuck.minProgress * A.maxV * BRAIN.stuck.window
			local was = A.blocked
			A.blocked = (wanted and not yielding and moved < minP and closer < minP) and true or false
			if A.blocked and not was then A.blockedEvent += 1 end
			A.winYield, A.winTicks = 0, 0
			if A.blocked and goal then
				local gx, gz = goal.x - u.x, goal.z - u.z
				local gL = math.max(1e-3, math.sqrt(gx * gx + gz * gz))
				local side = (A.id % 2 == 1) and 1 or -1
				A.detour = { x = u.x + (-gz / gL * side) * 6 + gx / gL * 3, z = u.z + (gx / gL * side) * 6 + gz / gL * 3 }
				A.detourUntil = t + 1.0
			end
			A.progAt, A.progX, A.progZ, A.progD = t, u.x, u.z, A.wantGoal and math.sqrt((A.wantGoal.x - u.x) ^ 2 + (A.wantGoal.z - u.z) ^ 2) or nil
		end
	end

	-- a unit stops planning (busy / stunned / riding): it keeps no stale velocity for its neighbours' ORCA
	function B.hold(u) u.brain.vx, u.brain.vz, u.brain.nv = 0, 0, nil end
	B.releaseSlot = releaseSlot
	return B
end

return Brain
