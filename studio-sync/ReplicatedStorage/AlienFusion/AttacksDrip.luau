-- Alien Fusion: animation batch 4, the SQUISH DRIP's attacks (split out of Attacks: the 200 000-character source cap).
-- Attacks calls this with its table A and the shared helpers; it adds A.Cling, A.DripBoing, A.Squash, A.Bombs, A.DripHurt,
-- A.DripDefeat, A.TEST_AIMS_ESCAPE, A.gooedCount and A.FOR.SquishF1v5;
-- and batch 5, the CRUNCH PEBBLE (A.Chip, A.Curl, A.Roll, A.PebbleHurt, A.PebbleDefeat, A.FOR.CrunchF1v5: it shares the
-- stick points and the spot claims).
-- ===================== BATCH 4: the SQUISH DRIP (spec design/16-DRIP-BATCH4-SPEC-chatgpt-raw.md) =====================
-- Built to match its reference sheets (design/concepts/drip/: I MOVEMENT (hop, idle, CLING + BITE), attacks/ J1 BOING,
-- J2 BOING BOMBS, J3 HURT + DEFEAT, K EFFECTS). A tiny water balloon: Root -> Body -> Top -> Curl; Lid, ArmL / ArmR,
-- DentL / DentR (new, batch 4) on Body; FootL / FootR on Root. L = its left = -X; arms and feet mirror (rx, -ry, -rz, -ox).
-- New presentation meshes (FX.GooMeshes): pancake1 (BOING failed, eye up), meltcap1 (DEFEAT, lid shut), splat1 / splat2
-- (BOING BOMBS on a flat / rounded back), spiral1 (the dazed eye). It sticks to big enemies through atk.place: the
-- animator puts the whole Drip on a frame this returns (a surface point kept in the target's chest-bone frame, so it
-- breathes and turns with it). MOVE TEST: a Brute stand-in (StandIn attribute) stands beside it.
-- ============================================================================================================
return function(A, E)
local smooth, clamp01, LID_FULL, GSND, SND = E.smooth, E.clamp01, E.LID_FULL, E.GSND, E.SND
local G_RIM, G_FILL, G_CYAN, part, pulse, ahead = E.G_RIM, E.G_FILL, E.G_CYAN, E.part, E.pulse, E.ahead
local sin, cos, pi = math.sin, math.cos, math.pi
local GooMesh = require(script.Parent:WaitForChild("GooMesh"))
local RunService = game:GetService("RunService")
local function gm(ctx, kind, seed, size, cf, extra) return GooMesh.make(kind, seed, size, cf, ctx.holder, extra) end
local function group(list) return { step = function(_, t) local alive = false; for _, f in list do if f:step(t) then alive = true end end; return alive end,
	stop = function() for _, f in list do f:stop() end end } end
-- (shared shapes, as in the Twin / Brute blocks: a keyed goo mesh on a frame, a flung mesh droplet)
local function gooKeyed(ctx, kind, seed, size: Vector3, place: CFrame, keys, extra)
	local m = gm(ctx, kind, seed, size, place, extra)
	if not m then return nil end
	m.Transparency = 1
	return { step = function(_, t)
		if t < keys[1][1] then m.Transparency = 1; return true end
		if t > keys[#keys][1] then return false end
		local a, b = keys[1], keys[#keys]
		for i = 1, #keys - 1 do if t >= keys[i][1] and t <= keys[i + 1][1] then a, b = keys[i], keys[i + 1]; break end end
		local u = smooth((t - a[1]) / math.max(1e-3, b[1] - a[1]))
		local function L(i) return a[i] + (b[i] - a[i]) * u end
		local s = Vector3.new(size.X * L(2), size.Y * L(3), size.Z * L(4))
		m.Size = s
		m.CFrame = place * CFrame.new(0, s.Y / 2, 0)
		m.Transparency = 1 - L(5)
		return true
	end, stop = function() m:Destroy() end, part = m }
end
local function gooDrop(ctx, from: Vector3, vel: Vector3, size, life, t0)
	local d = gm(ctx, "drop", 0, Vector3.new(size, size * 1.45, size), CFrame.new(from))
	if not d then return nil end
	d.Transparency = 1
	local landed, landT
	return { step = function(_, t)
		local e = t - t0
		if e < 0 then d.Transparency = 1; return true end
		if not landed then
			local p = from + vel * e + Vector3.new(0, -32 * e * e / 2, 0)
			local gy = ctx.ground(p.X, p.Z)
			if p.Y <= gy + size * 0.2 or e > life then landed, landT = Vector3.new(p.X, gy, p.Z), e
			else
				local v = vel + Vector3.new(0, -32 * e, 0)
				d.CFrame = CFrame.lookAt(p, p + v) * CFrame.Angles(pi / 2, 0, 0)
				d.Transparency = 0
			end
		end
		if landed then
			local u = clamp01((e - landT) / 0.24)
			if u >= 1 then return false end
			d.Size = Vector3.new(size * 1.5, size * 0.35 * (1 - u) + 0.02, size * 1.4)
			d.CFrame = CFrame.new(landed + Vector3.new(0, d.Size.Y / 2, 0))
			d.Transparency = u
		end
		return true
	end, stop = function() d:Destroy() end }
end
local function groundAt(ctx, p: Vector3) return Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z) end

-- key rows: { t, ease, R = { lift, side, fwd, pitch, roll, yaw }, B (Body) / T (Top) / C (Curl) = { rx, ry, rz, ox, oy, oz },
-- A = left arm, F = left foot (the right ones mirror), L = lid (60 = shut), extra = { Bone = { ... } } }
local function mir(v) v = v or {}; return { v[1] or 0, -(v[2] or 0), -(v[3] or 0), -(v[4] or 0), v[5] or 0, v[6] or 0 } end
local function dripKeys(rows)
	local keys = {}
	for i, r in rows do
		local L = r.L or 0
		local b = { Body = r.B or { 0, 0, 0 }, Top = r.T or { 0, 0, 0 }, Curl = r.C or { 0, 0, 0 }, Lid = { (L >= 0) and (LID_FULL * L / 60) or (-L * 0.5) },
			ArmL = r.A or { 0, 0, 0 }, ArmR = mir(r.A), FootL = r.F or { 0, 0, 0 }, FootR = mir(r.F) }
		for k, v in r.extra or {} do b[k] = v end
		local R = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { R[1] or 0, R[2] or 0, R[3] or 0, R[4] or 0, R[5] or 0, R[6] or 0 }, bones = b }
	end
	return keys
end

-- ---------- sticking to a big enemy ----------
-- the stand-in (MOVE TEST) or, later, the server's target: the nearest unit marked StandIn with the same owner
local function standIn(ctx)
	local units, own = ctx.m.Parent, ctx.m:GetAttribute("Owner")
	-- (AI TEST: the server names the target, AiTgt = its AiId)
	if ctx.m:GetAttribute("Mode") == "ai" then
		local id = ctx.m:GetAttribute("AiTgt")
		for _, u in (units and id and id ~= 0 and units:GetChildren() or {}) do
			if u ~= ctx.m and u:GetAttribute("AiId") == id and u.PrimaryPart then return u end
		end
		return nil
	end
	local best, bd
	for _, u in (units and units:GetChildren() or {}) do
		if u ~= ctx.m and u:IsA("Model") and u:GetAttribute("StandIn") and u:GetAttribute("Owner") == own and u.PrimaryPart then
			local d = (u:GetPivot().Position - ctx.base.Position).Magnitude
			if not bd or d < bd then best, bd = u, d end
		end
	end
	return best
end
-- the frame a surface point rides on: the target's chest / body bone (it breathes and turns with it), else its pivot
-- (29 Oct, many-targets check: a target's collision hull is its REST pose, not its animated skin (on the Titan the
-- GOOED patch floated above its head). So a hull point is stored in its nearest bone's REST frame (WorldCFrame, no
-- animation) and shown in the same bone's ANIMATED frame (TransformedWorldCFrame): it rides the visible skin.
-- Returns now(), rest())
local function anchorOf(t, near: Vector3?)
	local best, bd
	for _, b in t:GetDescendants() do
		-- (never its eyelid or dent bones: the Lid swings 175 deg on every blink and flung a Drip into its neighbour, measured)
		if b:IsA("Bone") and b.Name ~= "Root" and not b.Name:find("Lid") and not b.Name:find("^Dent") then
			local d = near and (b.WorldCFrame.Position - near).Magnitude or ((b.Name == "Chest" or b.Name == "Body") and 0 or 1e9)
			if not bd or d < bd then best, bd = b, d end
		end
	end
	if best then return function() return (best :: Bone).TransformedWorldCFrame end, function() return (best :: Bone).WorldCFrame end end
	return function() return t:GetPivot() end, function() return t:GetPivot() end
end
-- a surface point on the target: a ray at its collision hull, sideways at the flank ("wall": CLING) or straight down onto
-- the back ("top": BOING BOMBS); `slot` spreads several Drips. Stored in the anchor's frame. The wall normal is the hull
-- normal blended 50/50 with the radial direction (the hull's facets tilt it by up to ~35 deg, measured)
-- the stored surface point: in the frame of the target's nearest bone, with its normal and the outward direction
local function mkAt(t, cf, pos: Vector3, n: Vector3, to: Vector3)
	local radial = (pos - cf.Position) * Vector3.new(1, 0, 1)
	radial = (radial.Magnitude > 0.05) and radial.Unit or Vector3.new(to.X, 0, to.Z).Unit
	local anc, rest = anchorOf(t, pos)
	local f = rest()
	return { t = t, anc = anc, lp = f:PointToObjectSpace(pos), ln = f:VectorToObjectSpace(n),
		mode = (n.Y < 0.55) and "wall" or "top", out = radial }
end
-- a surface point on the target. TOP (BOING BOMBS): a ray straight down onto its back, off the spine (a ray down the
-- middle hit a fin tip). WALL (CLING, audit r1): candidates on its REAR flank (local +Z = behind its shoulders: the
-- front flank is all arm, a Drip put there sank 0.73 into the arm), on the Drip's side, spread by slot; a ray at its
-- mesh finds each point (the bounding-box ellipsoid was 1.2-2.3 outside its body there: the box is wide because of the
-- arms, measured); then accept(at) places the Drip there for real and checks it is clear of the mesh.
-- The first accepted candidate wins, else the least-bad one
-- (many Drips on one enemy, measured 29 Oct: 10 on a Brute = 9 overlapping pairs, 10 on a Colossus = 12. Every target
-- keeps its CLAIMED spots, in its own pivot frame: a candidate within SPACING of one is skipped. A spot is released when
-- its Drip's move ends or it goes. Candidates: 8 angles back along the flank x 3 heights (0.28 / 0.42 / 0.56 of the
-- target's height: on a Titan or a Colossus a fixed 2.6 up was its ankles) on the Drip's side, then the other side)
local CLAIMS = {}                                                   -- target -> { { p = local point, owner = drip } }
local SPACING = 2.2                                                -- (1.7 left Drip centres 0.9 apart: they hug cheek-on, measured)
local spacingNow = SPACING                                          -- (a second, tighter pass when a target is full)
-- (the spot AND where the Drip's body will be, 0.9 out along the normal: two spots 2.2 apart on a curved back put two
-- Drips' bodies 0.6 apart, measured on a Brute)
local function claimFree(t, cf, p: Vector3, me, n: Vector3?, body: Vector3?)
	local lp = cf:PointToObjectSpace(p)
	local lc = body and cf:PointToObjectSpace(body) or (n and cf:PointToObjectSpace(p + n * 0.9)) or lp
	for _, c in CLAIMS[t] or {} do
		if c.owner ~= me and c.owner.Parent and ((c.p - lp).Magnitude < spacingNow or (c.c - lc).Magnitude < spacingNow - 0.3) then return false end
	end
	return true
end
local function claim(t, cf, p: Vector3, me, n: Vector3?, body: Vector3?)
	local list = CLAIMS[t] or {}
	CLAIMS[t] = list
	for i = #list, 1, -1 do if list[i].owner == me or not list[i].owner.Parent then table.remove(list, i) end end
	table.insert(list, { p = cf:PointToObjectSpace(p), c = cf:PointToObjectSpace(body or (p + (n or Vector3.zero) * 0.9)), owner = me })
end
local function unclaim(t, me)
	local list = t and CLAIMS[t]
	if not list then return end
	for i = #list, 1, -1 do if list[i].owner == me then table.remove(list, i) end end
	if #list == 0 then CLAIMS[t] = nil end
end
A.claimCount = function(t) return CLAIMS[t] and #CLAIMS[t] or 0 end
local POINTS = require(script.Parent:WaitForChild("AttachPoints"))
local clingFrame                                                    -- (defined below; fromPoints places the Drip with it)
-- (authored stick points: candidates in order, the Drip's side first, behind the shoulders first, near 0.42 of its height
-- (wall) / near the middle of its back (top); each claimed like a ray hit. Points ride the nearest bone (mkAt))
local function fromPoints(ctx, t, cf, mode, slot, accept, to)
	local set = POINTS[t:GetAttribute("FormName") or ""]
	local list = set and set[(mode == "wall") and "wall" or "top"]
	if not list or #list == 0 then return nil, false end
	local me = ctx.m
	local side = (cf:VectorToObjectSpace(to).X >= 0) and 1 or -1
	local order = {}
	for i, p in list do
		local score
		if mode == "wall" then
			score = ((p[1] * side >= 0) and 0 or 100) + ((p[3] >= -0.2 * set.H) and 0 or 30) + math.abs(p[2] / set.H - 0.42) * 40 + ((i * 7 + slot * 13) % 11) * 0.3
		else
			-- (behind its head first: on its head the GOOED patch tilted with the head like a halo, measured on the Brute)
			score = Vector2.new(p[1], p[3]).Magnitude + ((p[3] < 0) and 6 or 0) + ((i * 7 + slot * 13) % 11) * 0.15
		end
		table.insert(order, { p = p, s = score })
	end
	table.sort(order, function(a, b) return a.s < b.s end)
	local bestAt, bestScore, bestPos, first, bestN
	for _, o in order do
		local p = o.p
		local pos = cf * Vector3.new(p[1], p[2], p[3])
		local nl = Vector3.new(p[4], p[5], p[6])
		local n = (nl.Magnitude > 0.5) and cf:VectorToWorldSpace(nl).Unit or nil
		local at = n and mkAt(t, cf, pos, n, to)
		-- (where its body will really be: on its side it hugs cheek-on, its body off to the side of the spot)
		local body = at and (clingFrame(at, 0) * Vector3.new(0, 0.9, 0))
		if at and claimFree(t, cf, pos, me, nil, body) then                  -- (a point with no normal would give a NaN Drip)
			first = first or at
			local okk, sc = true, 0
			if accept then okk, sc = accept(at) end
			if okk then claim(t, cf, pos, me, nil, body); return at, true end
			if not bestScore or sc > bestScore then bestAt, bestScore, bestPos, bestN = at, sc, pos, body end
		end
	end
	if bestPos then claim(t, cf, bestPos, me, nil, bestN) end
	return bestAt, true
end
-- (a target full at 2.2 apart on BOTH its sides and its back (10 on a Brute, measured) takes the last ones at 1.5)
local function squeezed(f, ...)
	spacingNow = 1.5
	local ok, at = pcall(f, ...)
	spacingNow = SPACING
	return ok and at or nil
end
local REAR = { 25, 45, 10, 60, 35, 75, 0, 90 }                       -- (degrees back from straight out to the side)
local HEIGHTS = { 0.42, 0.28, 0.56 }
local function attachTo(ctx, t, mode, slot, accept)
	if not t then return nil end
	slot = slot or 0
	local mp = t.PrimaryPart
	mp.CanQuery = true                                               -- (client-local: the target's mesh answers the ray)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { mp }   -- (its mesh only: not its Hitbox box)
	local cf = t:GetPivot()
	local to = (ctx.base.Position - cf.Position) * Vector3.new(1, 0, 1)
	local me = ctx.m
	do
		local at, had = fromPoints(ctx, t, cf, mode, slot, accept, to)
		if had then return at end                                    -- (it has authored points: no rays at its hull)
	end
	local _, bsz = t:GetBoundingBox()
	local reach = math.max(bsz.X, bsz.Z) / 2 + 8
	if mode ~= "wall" then
		-- (its back: 12 angles x 3 rings off the spine (a ray down the middle hit a fin tip), starting from the slot; the
		-- first free hit that faces up (normal Y > 0.35) wins)
		local a0 = math.atan2(to.Z, to.X)
		local R0 = math.min(bsz.X, bsz.Z) / 2
		for k = 0, 59 do                                                  -- (12 angles x 5 rings: 10 on a Brute filled 3 rings, measured)
			local kk = (k + slot * 5) % 60
			local a = a0 + (kk % 12) / 12 * 2 * pi
			local rr = R0 * (0.22 + (kk // 12) * 0.14)
			local hit = workspace:Raycast(cf.Position + Vector3.new(cos(a), 0, sin(a)) * rr + Vector3.new(0, bsz.Y + 10, 0), Vector3.new(0, -(bsz.Y + 16), 0), rp)
			if hit and hit.Normal.Y > 0.35 and claimFree(t, cf, hit.Position, me) then
				claim(t, cf, hit.Position, me)
				return mkAt(t, cf, hit.Position, hit.Normal, to)
			end
		end
		return nil
	end
	local side = (cf:VectorToObjectSpace(to).X >= 0) and 1 or -1
	local cands = {}
	for _, sd in { side, -side } do
		for hi, hf in HEIGHTS do
			for ai, deg in REAR do table.insert(cands, { sd = sd, h = hf, deg = deg, pri = (sd == side and 0 or 100) + (hi - 1) * 8 + ai }) end
		end
	end
	table.sort(cands, function(x, y) return x.pri < y.pri end)
	local first, bestAt, bestScore, bestPos
	local nC = #cands
	for k = 0, nC - 1 do
		local c = cands[((k + ((k < nC / 2) and slot * 3 or 0)) % nC) + 1]
		local dl = Vector3.new(c.sd * cos(math.rad(c.deg)), 0, sin(math.rad(c.deg)))   -- (local: +X its right, +Z behind)
		local d = cf:VectorToWorldSpace(dl)
		local hit = workspace:Raycast(cf.Position + d * reach + Vector3.new(0, bsz.Y * c.h, 0), -d * (reach + 2), rp)
		local inner = hit and ((hit.Position - cf.Position) * Vector3.new(1, 0, 1)).Magnitude < 0.45 * math.min(bsz.X, bsz.Z) / 2
		if hit and not inner and claimFree(t, cf, hit.Position, me) then        -- (inner: under its belly / between its legs: hidden)
			local radial = (hit.Position - cf.Position) * Vector3.new(1, 0, 1)
			local n = (radial.Magnitude > 0.05) and (hit.Normal + radial.Unit).Unit or hit.Normal   -- (its facets tilt the normal: half radial)
			local at = mkAt(t, cf, hit.Position, n, to)
			first = first or at
			local okk, score = true, 0
			if accept then okk, score = accept(at) end
			if okk then claim(t, cf, hit.Position, me); return at end
			if not bestScore or score > bestScore then bestAt, bestScore, bestPos = at, score, hit.Position end
		end
	end
	if bestPos then claim(t, cf, bestPos, me) end
	return bestAt or first
end
local function surfaceNow(at)
	local f = at.anc()
	return f * at.lp, f:VectorToWorldSpace(at.ln)
end
-- the Drip's frame when stuck. WALL: facing into the surface, upright, its top leaning 18 deg off the wall; its sticky
-- patch (model (0, 0.64, -0.72), its mouth) on P + 0.06 N; then the eye's front (model (0, 1.12, -0.88)) is kept >= 0.10
-- outside (spec priority 2). TOP: standing on the surface along its normal, facing outward, soles on P + 0.06 N.
-- dn = an extra push along the normal (the bite: - toward the enemy)
local PATCH, EYE = Vector3.new(0, 0.64, -0.72), Vector3.new(0, 1.12, -0.88)
local PUPIL = Vector3.new(-0.07, 0.87, -1.025)   -- (the pupil's front + 0.02, in the Body bone's frame: Blender pupil (0.07, -1.005, 1.12), the eye is 100 % Body-weighted)
local WALL_TILTS = { 24, 26, 28, 22, 20 }                          -- (audit r1: 24 deg first, then +-4)
local WALL_TURN = math.rad(70)                                     -- (audit r2 visibility check: at 30 deg 0 of 9 eye points showed from a gameplay camera)
local CHEEKS = { Vector3.new(0.80, 0.82, -0.05), Vector3.new(-0.80, 0.82, -0.05) }   -- (its DentL / DentR cheeks)
clingFrame = function(at, dn)
	local P, N = surfaceNow(at)
	if at.mode == "wall" then
		-- (audit r2: it hugs the flank with its CHEEK, turned 70 deg, so its eye looks out along the surface: face-first,
		-- the eye looked into the enemy and could not be seen. Leaning its top off the wall first (24, then 20-28 deg), then
		-- turning about its own up; the cheek on the wall side sits on P + 0.05 N; the eye kept >= 0.10 off)
		-- (turned toward the enemy's TAIL: turned toward its front, the eye looked straight into its shoulder and arm)
		if not at.turn then
			local tl = at.t:GetPivot().LookVector
			local f1 = CFrame.lookAt(Vector3.zero, -N) * CFrame.Angles(0, WALL_TURN, 0)
			at.turn = (f1.LookVector:Dot(tl) < 0) and 1 or -1
		end
		local F, eyeD
		for _, tilt in WALL_TILTS do
			local f = CFrame.lookAt(Vector3.zero, -N) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.Angles(0, WALL_TURN * at.turn, 0)
			local c = CHEEKS[1]
			if f:VectorToWorldSpace(CHEEKS[2]):Dot(N) < f:VectorToWorldSpace(c):Dot(N) then c = CHEEKS[2] end
			F = f + (P + N * (0.05 + dn) - f:VectorToWorldSpace(c))
			eyeD = (F * EYE - P):Dot(N)
			if eyeD >= 0.10 then break end
		end
		if eyeD < 0.10 then F = F + N * (0.10 - eyeD) end                    -- (last resort)
		return F, P, N
	end
	local fwd = at.out - N * at.out:Dot(N); fwd = (fwd.Magnitude > 0.05) and fwd.Unit or Vector3.zAxis
	return CFrame.fromMatrix(P + N * (0.06 + dn), N:Cross(-fwd), N), P, N
end
local CHECK = { Vector3.new(0, 1.12, -0.88), Vector3.new(-0.66, 0.74, -0.18), Vector3.new(0.66, 0.74, -0.18), Vector3.new(0, 1.9, 0) }
local function wallClear(at)
	local F = clingFrame(at, 0)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { at.t.PrimaryPart }
	local _, N = surfaceNow(at)
	local look = -N
	local worst = math.huge
	for i, lp in CHECK do
		local w = F * lp
		local hit = workspace:Raycast(w - look * 2.0, look * 3.0, rp)
		local g = hit and (w - hit.Position):Dot(-look) or 3                  -- (clearance: + outside the mesh, - inside)
		worst = math.min(worst, (i == 1) and g or (g + 0.12))
	end
	return worst >= 0, worst
end
-- the wind-up: turning on the spot to face the target (over the first 0.20 s), so the launch goes straight at it
local function faceToward(S: CFrame, at, t)
	local P = surfaceNow(at)
	local v = (P - S.Position) * Vector3.new(1, 0, 1)
	if v.Magnitude < 0.1 then return nil end
	return S.Rotation:Lerp(CFrame.lookAt(Vector3.zero, v), smooth(t / 0.20)) + S.Position
end
-- a hop from S to F: straight across, lifted 4 h u (1 - u) (peak h), turning on the way
local function arc(S: CFrame, F: CFrame, u, h)
	u = clamp01(u)
	local p = S.Position:Lerp(F.Position, u) + Vector3.new(0, 4 * h * u * (1 - u), 0)
	return S.Rotation:Lerp(F.Rotation, smooth(u)) + p
end
-- the BITE's push along the normal over its 0.50 s cycle (spec 5C: hold 0, wind +0.08, lunge -0.13, rebound +0.06)
local BITE_DN = { { 0, 0 }, { 0.10, 0.08 }, { 0.24, -0.13 }, { 0.33, 0.06 }, { 0.50, 0 } }
local function biteDn(e)
	e %= 0.5
	for i = 1, #BITE_DN - 1 do
		local a, b = BITE_DN[i], BITE_DN[i + 1]
		if e <= b[1] then return a[2] + (b[2] - a[2]) * smooth((e - a[1]) / (b[1] - a[1])) end
	end
	return 0
end
-- bite sounds: at most 3 a second on this client, however many Drips bite (spec 11)
local biteSounds = {}
local function biteSound(ctx, pos)
	local now = os.clock()
	for i = #biteSounds, 1, -1 do if now - biteSounds[i] > 1 then table.remove(biteSounds, i) end end
	if #biteSounds < 3 then table.insert(biteSounds, now); ctx.sound(GSND.pop, pos, 0.30, 1.9) end
end
-- the BITE SPLAT (cell 4): a 6-spike crown 0.60 x 0.20 on the surface, 0.30 -> 1 in 0.07 s, gone by 0.20 s; no particles
local function biteSplat(ctx, at, t0)
	local P, N = surfaceNow(at)
	local c = gm(ctx, "crown", 3, Vector3.new(0.6, 0.2, 0.6), CFrame.new(P), 6)
	if not c then return nil end
	c.Transparency = 1
	return { step = function(_, t)
		local e = t - t0
		if e > 0.20 then return false end
		if e < 0 then return true end
		local s = 0.3 + 0.7 * smooth(e / 0.07)
		local p, n = surfaceNow(at)
		local up = n
		local fx = (math.abs(up.Y) < 0.95) and Vector3.yAxis:Cross(up).Unit or Vector3.xAxis
		c.Size = Vector3.new(0.6 * s, 0.2 * s, 0.6 * s)
		c.CFrame = CFrame.fromMatrix(p + up * c.Size.Y / 2, fx, up)
		c.Transparency = 0.1 + 0.9 * smooth((e - 0.10) / 0.10)
		return true
	end, stop = function() c:Destroy() end }
end
-- the CLING STICK (cell 3): the six-strand pin between the Drip and the surface, 0.95 wide, 0.2 -> 1 in 0.14 s, kept;
-- + three sticky strands (audit r1): its left / right nub and its chin to the surface contacts of spec 5B
-- (P -+ 0.48 R + 0.12 U, P - 0.34 U), drawn between the two ends every frame (so they stretch and sag with the bite)
local NUBS = { Vector3.new(-0.66, 0.74, -0.18), Vector3.new(0.66, 0.74, -0.18), Vector3.new(0, 0.42, -0.62) }
local function clingPin(ctx, at, t0, tEnd)
	local pin = gm(ctx, "pin", 2, Vector3.new(0.95, 0.5, 0.95), CFrame.new())
	if not pin then return nil end
	pin.Transparency = 1
	local strands = {}
	for i = 1, 3 do strands[i] = gm(ctx, "rope", 1, Vector3.new(0.09, 0.5, 0.09), CFrame.new()) end
	local function drawStrands(e, p, n)
		local up = Vector3.yAxis - n * n.Y; up = (up.Magnitude > 0.05) and up.Unit or n:Cross(Vector3.xAxis).Unit
		local right = up:Cross(n)
		local dc = ctx.m:GetPivot()
		local ends = { p - right * 0.48 + up * 0.12, p + right * 0.48 + up * 0.12, p - up * 0.34 }
		for i, st in strands do
			if st then
				local a, b = dc * NUBS[i], ends[i] + n * 0.02
				local L = (b - a).Magnitude
				if L < 0.05 or L > 1.2 then st.Transparency = 1
				else
					st.Size = Vector3.new(0.09, L, 0.09)
					st.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(-pi / 2, 0, 0)
					st.Transparency = 0.2 + 0.8 * (1 - smooth(e / 0.14))
				end
			end
		end
	end
	return { step = function(_, t)
		local e = t - t0
		if t > tEnd then return false end                                  -- (unstuck when the move ends)
		if e < 0 then return true end
		local s = 0.2 + 0.8 * smooth(e / 0.14)
		local p, n = surfaceNow(at)
		local fx = (math.abs(n.Y) < 0.95) and Vector3.yAxis:Cross(n).Unit or Vector3.xAxis
		pin.Size = Vector3.new(0.95 * s, 0.5 * s, 0.95 * s)
		pin.CFrame = CFrame.fromMatrix(p + n * pin.Size.Y * 0.35, fx, n)
		pin.Transparency = 0.15
		drawStrands(e, p, n)
		return true
	end, stop = function() pin:Destroy(); for _, st in strands do if st then st:Destroy() end end end }
end

-- ---------- GOOED (5D): one shared overlay per target once 6+ Drips cling to it ----------
local CLINGS = {}                                                   -- target -> { drips = { [drip] = true }, n, overlay }
local gooedLoop
local function gooedOverlay(t)
	-- (the flattest of 6 points on its back: one ray hit a fin's slope and stood the overlay on end, audit r1 stills)
	local at, bestY
	for k = 0, 5 do
		local c = attachTo({ base = t:GetPivot() * CFrame.new(0, 0, 4), m = t }, t, "top", k)
		if c then
			local _, n = surfaceNow(c)
			if not bestY or n.Y > bestY then at, bestY = c, n.Y end
		end
	end
	if not at then return nil end
	local _, bb = t:GetBoundingBox()
	local w = math.clamp(math.max(bb.X, bb.Z) * 0.4, 2.4, 3.2)
	local folder = workspace:FindFirstChild("GooShields") or Instance.new("Folder", workspace)
	folder.Name = "GooShields"
	local s = GooMesh.make("splat", 0, Vector3.new(w, 0.12, w * 1.1), CFrame.new(), folder)
	if not s then return nil end
	s.Transparency = 1
	local rim = GooMesh.make("splat", 0, Vector3.new(w + 0.16, 0.10, w * 1.1 + 0.16), CFrame.new(), folder)
	if rim then for _, c in rim:GetChildren() do c:Destroy() end; rim.Material = Enum.Material.SmoothPlastic; rim.Color = Color3.fromRGB(58, 26, 104); rim.Transparency = 1 end
	local edge = GooMesh.make("ring", 1, Vector3.new(w + 0.10, 0.06, w * 1.1 + 0.10), CFrame.new(), folder)
	if edge then for _, c in edge:GetChildren() do c:Destroy() end; edge.Material = Enum.Material.Neon; edge.Color = G_CYAN; edge.Transparency = 1 end
	local sa = s:FindFirstChildOfClass("SurfaceAppearance")
	return { part = s, rim = rim, edge = edge, at = at, sa = sa, es = sa and sa.EmissiveStrength or 1, born = os.clock(), w = w }
end
local function gooedSet(target, drip, on)
	if not target then return end
	local e = CLINGS[target] or { drips = {}, n = 0 }
	CLINGS[target] = e
	if on and not e.drips[drip] then e.drips[drip] = true; e.n += 1
	elseif not on and e.drips[drip] then e.drips[drip] = nil; e.n -= 1 end
	if gooedLoop then return end
	gooedLoop = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for tg, g in CLINGS do
			for d in g.drips do if not d.Parent then g.drips[d] = nil; g.n -= 1 end end
			if not tg.Parent then if g.overlay then g.overlay.kill() end; CLINGS[tg] = nil; continue end
			tg:SetAttribute("GooedN", g.n)                                    -- (readout: Drips stuck on it, this client)
			if g.n >= 6 and not g.overlay and now > (g.retry or 0) then
				g.overlay = gooedOverlay(tg); g.fade = 0; g.lastT = now
				if not g.overlay then g.retry = now + 1                        -- (no surface: try again in 1 s, not every frame)
				else local o = g.overlay; o.kill = function() o.part:Destroy(); if o.rim then o.rim:Destroy() end; if o.edge then o.edge:Destroy() end end end
			end
			local o = g.overlay
			if o then
				local dt = now - (g.lastT or now); g.lastT = now
				g.fade = math.clamp((g.fade or 0) + ((g.n < 6) and dt / 0.30 or -dt / 0.12), 0, 1)   -- (audit r2: 6 -> 5 -> 6 reverses, no rebuild)
				local p, n = surfaceNow(o.at)
				local fwd = o.at.out - n * o.at.out:Dot(n); fwd = (fwd.Magnitude > 0.05) and fwd.Unit or Vector3.zAxis
				local e0 = now - o.born
				local s = 0.9 + 0.1 * smooth(e0 / 0.45)
				local frame = CFrame.fromMatrix(p, n:Cross(-fwd), n)
				o.part.Size = Vector3.new(o.w * s, 0.12, o.w * 1.1 * s)
				o.part.CFrame = frame + n * 0.09
				local fade = smooth(g.fade)
				local tr = (1 - smooth(e0 / 0.45)) * 0.9 + 0.1 + 0.9 * fade
				o.part.Transparency = tr
				if o.rim then o.rim.Size = Vector3.new(o.w * s + 0.16, 0.10, o.w * 1.1 * s + 0.16); o.rim.CFrame = frame + n * 0.07; o.rim.Transparency = tr end
				if o.edge then
					o.edge.Size = Vector3.new(o.w * s + 0.10, 0.06, o.w * 1.1 * s + 0.10); o.edge.CFrame = frame + n * 0.12
					o.edge.Transparency = math.min(1, tr + 0.25 - 0.2 * ((e0 < 0.45) and sin(e0 / 0.45 * pi) or 0.4 * sin(now * 2 * pi)))
				end
				if o.sa then                                         -- (one 0.45 s flare +30 %, then a subtle 1 s pulse)
					local flare = (e0 < 0.45) and sin(e0 / 0.45 * pi) * 0.3 or 0
					o.sa.EmissiveStrength = o.es * (1 + flare + 0.08 * sin(now * 2 * pi))
				end
				if g.fade >= 1 and g.n < 6 then o.kill(); g.overlay = nil; g.fade = nil; g.lastT = nil end
			end
			if g.n <= 0 and not g.overlay then CLINGS[tg] = nil end
		end
		if next(CLINGS) == nil then gooedLoop:Disconnect(); gooedLoop = nil end
	end)
end
A.gooedCount = function(target) local e = CLINGS[target]; return e and e.n or 0, e and e.overlay ~= nil end
-- (test readout)

-- ===================== CLING (passive attack): hop onto the enemy's flank, stick, bite every 0.50 s =====================
-- 0.00-0.16 crouch, 0.20 launch, 0.43 apex, 0.68 surface contact, 0.82 clinging, bites at 0.82 + k * 0.50 (+0.24 = the
-- lunge, the bite splat) for 5 bites in the MOVE TEST (3.32). Damage is the server's clock (one bite per 0.50 s)
-- (finding its spot, again until it jumps: 29 Oct, 6 Drips started before a Titan / Ram / Colossus stand-in had arrived on
-- the client (big models stream in later) and found NO TARGET, so they never left the ground)
local function findCling(ctx)
	local tg = standIn(ctx)
	if not tg then return nil end
	local sl = ctx.m:GetAttribute("Slot")
	return attachTo(ctx, tg, "wall", sl, wallClear) or attachTo(ctx, tg, "top", sl) or squeezed(attachTo, ctx, tg, "wall", sl, wallClear)
end
local function findBomb(ctx)
	local tg = standIn(ctx)
	if not tg then return nil end
	local sl = ctx.m:GetAttribute("Slot")
	return attachTo(ctx, tg, "top", sl) or attachTo(ctx, tg, "wall", sl, wallClear) or squeezed(attachTo, ctx, tg, "top", sl)
end
local CLING_BASE = { B = { -10, 0, 0, 0, -0.06, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, -55, 10, -0.04 }, F = { 20, 0, 0, 0, 0.10, 0.12 } }
local function clingRows()
	local rows = {
		{ 0.00, "smooth", C = { -10, 0, 0 } },
		{ 0.12, "in", B = { 0, 0, 0, 0, -0.16 }, T = { 0, 0, 0, 0, -0.10 }, C = { 28, 0, 0 }, A = { 0, 0, 12 }, F = { 0, 0, 0, -0.04 } },
		{ 0.20, "out", B = { 0, 0, 0, 0, 0.10 }, T = { 0, 0, 0, 0, 0.12 }, C = { 32, 0, 0 }, F = { 20, 0, 0, 0, 0.12, 0.10 } },
		{ 0.43, "smooth", T = { 0, 0, 0, 0, 0.06 }, C = { 18, 0, 0 }, A = { 0, -20, 25 }, F = { 25, 0, 0, 0, 0.14, 0.08 } },
		{ 0.60, "smooth", B = { -12, 0, 0 }, T = { 0, 0, 0, 0, -0.08 }, C = { -12, 0, 0 }, A = { 0, -50, 15, -0.04 }, F = { 15, 0, 0, 0, 0.08, 0.06 } },
		{ 0.68, "out", B = { -14, 0, 0, 0, -0.10, -0.16 }, T = { 0, 0, 0, 0, -0.20 }, C = { -25, 0, 0 }, A = { 0, -60, 8, -0.05 }, F = { 22, 0, 0, 0, 0.10, 0.12 }, L = 12 },
		{ 0.82, "smooth", B = CLING_BASE.B, T = CLING_BASE.T, C = CLING_BASE.C, A = CLING_BASE.A, F = CLING_BASE.F },
	}
	local function add(v, d) local o = table.clone(v); for i, x in d do o[i] = (o[i] or 0) + x end; return o end
	for k = 0, 4 do
		local b0 = 0.82 + k * 0.5
		table.insert(rows, { b0 + 0.10, "smooth", B = add(CLING_BASE.B, { 7 }), T = add(CLING_BASE.T, { 0, 0, 0, 0, 0.10 }), C = { 18, 0, 0 }, A = CLING_BASE.A, F = CLING_BASE.F })
		table.insert(rows, { b0 + 0.24, "in", B = add(CLING_BASE.B, { -11 }), T = add(CLING_BASE.T, { 0, 0, 0, 0, -0.04 }), C = { -32, 0, 0 }, A = add(CLING_BASE.A, { 0, -12 }), F = CLING_BASE.F, L = 18 })
		table.insert(rows, { b0 + 0.33, "out", B = add(CLING_BASE.B, { 4 }), T = add(CLING_BASE.T, { 0, 0, 0, 0, 0.09 }), C = { 15, 0, 0 }, A = CLING_BASE.A, F = CLING_BASE.F })
		table.insert(rows, { b0 + 0.50, "smooth", B = CLING_BASE.B, T = CLING_BASE.T, C = CLING_BASE.C, A = CLING_BASE.A, F = CLING_BASE.F })
	end
	return rows
end
A.Cling = {
	boneKeys = true, dur = 3.32, lock = 3.32,
	keys = dripKeys(clingRows()),
	-- (the whole Drip: hop from the ground onto the flank 0.20-0.68, then stuck there, pushed in and out by each bite)
	place = function(ctx, t)
		local at = ctx.cling
		if not at or not at.t.Parent then return nil end
		if t < 0.20 then return faceToward(ctx.base, at, t) end
		local F, P, N = clingFrame(at, (t >= 0.82) and biteDn(t - 0.82) or 0)
		if ctx.m:GetAttribute("FreezeTT") then                        -- (test readout: the patch and eye off the surface, the radius)
			local cg = math.min((F * CHEEKS[1] - P):Dot(N), (F * CHEEKS[2] - P):Dot(N))
			ctx.m:SetAttribute("PatchGap", cg); ctx.m:SetAttribute("EyeGap", (F * EYE - P):Dot(N))
			ctx.m:SetAttribute("ClingR", ((P - at.t:GetPivot().Position) * Vector3.new(1, 0, 1)).Magnitude)
		end
		if t < 0.68 then return arc(faceToward(ctx.base, at, 1) or ctx.base, F, (t - 0.20) / 0.48, math.clamp(1.2 + 0.4 * math.abs(F.Y - ctx.base.Y), 1.5, 6)) end
		return F
	end,
	events = {
		{ t = 0, fn = function(ctx)
			-- (its flanks full (10 on a Brute left 4 with no free spot, measured): the overflow sticks on its back instead)
			ctx.cling = findCling(ctx)
			ctx.sound(GSND.wobble, ctx.base.Position, 0.45, 1.8)                                   -- (rubber tension chirp)
			local me = ctx.m
			return { step = function(_, t)
				if not ctx.cling and t < 0.20 then ctx.cling = findCling(ctx) end              -- (target not here yet: look again)
				me:SetAttribute("StuckTo", ctx.cling and ctx.cling.t.Name or "NONE")             -- (test readout)
				return t <= 3.32
			end, stop = function() unclaim(ctx.cling and ctx.cling.t, me) end }                -- (its spot, freed at the end)
		end },
		-- LAUNCH PUFF (cell 2): a low mound + 2 drops at the take-off point, 0.70 wide, gone by +0.32
		{ t = 0.20, fn = function(ctx)
			local g = groundAt(ctx, ctx.base.Position)
			local fx = {}
			local md = gooKeyed(ctx, "mound", 1, Vector3.new(0.7, 0.22, 0.7), CFrame.new(g) * ctx.base.Rotation, {
				{ 0.20, 0.3, 0.3, 0.3, 1 }, { 0.27, 1, 1, 1, 1 }, { 0.52, 1.1, 0.2, 1.1, 0 } })
			if md then table.insert(fx, md) end
			for i = 1, 2 do
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.2, 0), Vector3.new((i - 1.5) * 3, 5, 0), 0.14, 0.4, 0.20)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
		-- surface contact: the sticky shlup, a little contact splash (to 1.08), the pin that holds it on (to the end)
		{ t = 0.68, fn = function(ctx)
			local at = ctx.cling
			if not at then return end
			local P = surfaceNow(at)
			ctx.sound(GSND.goo, P, 0.55, 1.5)
			local fx = {}
			local c = biteSplat(ctx, at, 0.68)
			if c then table.insert(fx, c) end
			local pin = clingPin(ctx, at, 0.70, 3.32)
			if pin then table.insert(fx, pin) end
			-- (it counts as stuck from 0.82: the target's GOOED overlay is keyed to the target, not the Drip)
			local reg = false
			table.insert(fx, { step = function(_, t)
				if t >= 0.82 and not reg then reg = true; gooedSet(at.t, ctx.m, true) end
				return t <= 3.32
			end, stop = function() if reg then gooedSet(at.t, ctx.m, false) end end })
			return group(fx)
		end },
	},
}
for k = 0, 4 do
	table.insert(A.Cling.events, { t = 0.82 + k * 0.5 + 0.24, fn = function(ctx)
		local at = ctx.cling
		if not at then return end
		biteSound(ctx, (surfaceNow(at)))
		return biteSplat(ctx, at, 0.82 + k * 0.5 + 0.24)
	end })
end

-- ===================== BOING (auto, vs a Titan's danger): SAFE = spring clear up to 10 studs =====================
-- 0.00 alert, 0.08 crouch, 0.12 spring (launch), 0.30 flight apex 2.10 up, 0.52 land, 0.62 wobble, 0.70 safe. s = +1 for
-- an escape to its right (+X): the lateral channels are authored for s = +1 and flipped by `extra`. MOVE TEST: an escape
-- point from TEST_AIMS_ESCAPE each repeat (the server will choose the real one)
A.TEST_AIMS_ESCAPE = { { 8, -90 }, { 10, 90 }, { 6, -60 }, { 9, 120 } }
A.DripBoing = {
	boneKeys = true, dur = 0.95, lock = 0.70, testLock = 0.95, aims = true, testAims = "TEST_AIMS_ESCAPE",
	keys = dripKeys({
		{ 0.00, "smooth", B = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 35 }, L = -30 },
		{ 0.08, "in", B = { 0, 0, 0, 0, -0.22 }, T = { 0, 0, 0, 0, -0.14 }, C = { -12, 0, 18 }, A = { 0, 0, 30 }, F = { 0, 0, 0, -0.10 } },
		{ 0.12, "out", B = { 0, 0, 0, 0, 0.18 }, T = { 0, 0, 0, 0, 0.16 }, C = { 0, 0, 30 }, A = { 0, 20, 20 }, F = { 25, 0, 0, 0, 0.12, 0.16 } },
		{ 0.30, "smooth", B = { 0, 0, 0, 0, 0.12 }, T = { 0, 0, 0, 0, 0.10 }, C = { 0, 0, 50 }, A = { 0, 35, 10 }, F = { 30, 0, 0, 0, 0.16, 0.12 } },
		{ 0.45, "in", C = { 0, 0, 25 }, A = { 0, 10, 15 } },
		{ 0.52, "out", B = { 0, 0, 0, 0, -0.17 }, T = { 0, 0, 0, 0, -0.10 }, C = { -32, 0, 0 }, A = { 0, 0, 25, -0.06 }, F = { 0, 0, 0, -0.06 } },
		{ 0.62, "smooth", B = { 0, 0, 9 }, T = { 0, 0, -6 }, C = { 0, 0, -18 } },
		{ 0.70, "smooth" },
		{ 0.95, "smooth" },
	}),
	extra = function(t, p, ctx)
		local s = ctx and ctx.escS or 1
		p.glowMul = 1 + 0.2 * (1 - smooth(t / 0.12))                               -- (alert: the cracks +20 %)
		if s < 0 then
			p.root[2] = -p.root[2]; p.root[5] = -p.root[5]; p.root[6] = -p.root[6]
			for _, v in p.bones do v[2] = -v[2]; v[3] = -v[3]; v[4] = -v[4] end
		end
	end,
	-- (audit r1: the whole Drip tilts toward its actual flight direction, about its middle (1.0 up): 0.08-0.12 to 18,
	-- 0.30 55, 0.45 25, 0.52 0; the 2.10 arc and the 0.52 landing are kept)
	place = function(ctx, t)
		local F = ctx.escape
		if not F or t < 0.08 then return nil end
		local A0 = (t < 0.12) and ctx.base or arc(ctx.base, F, (t - 0.12) / 0.40, 2.10)
		local d = (F.Position - ctx.base.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude < 0.1 then return A0 end
		local tilt = (t < 0.12) and 18 * smooth((t - 0.08) / 0.04) or (t < 0.30) and 18 + 37 * smooth((t - 0.12) / 0.18)
			or (t < 0.45) and 55 - 30 * smooth((t - 0.30) / 0.15) or 25 * (1 - smooth((t - 0.45) / 0.07))
		local axis = Vector3.yAxis:Cross(d.Unit)
		local mid = A0.Position + Vector3.new(0, 1.0, 0)
		local rot = CFrame.fromAxisAngle(axis, math.rad(tilt))
		return (rot * (A0 - mid)) + mid
	end,
	events = {
		{ t = 0, fn = function(ctx)
			local a = ctx.aim or ahead(ctx, 0, 8)
			local v = ctx.base:PointToObjectSpace(a) * Vector3.new(1, 0, 1)
			if v.Magnitude > 10 then v = v.Unit * 10 end
			ctx.escS = (v.X >= 0) and 1 or -1
			local w = ctx.base * v
			ctx.escape = CFrame.new(groundAt(ctx, w)) * ctx.base.Rotation
			ctx.sound(GSND.wobble, ctx.base.Position, 0.45, 1.9)
		end },
		{ t = 0.12, fn = function(ctx)                                       -- (launch: the boing, the puff stays where it stood)
			ctx.sound(GSND.pop, ctx.base.Position, 0.75, 1.25)
			local g = groundAt(ctx, ctx.base.Position)
			local fx = {}
			local md = gooKeyed(ctx, "mound", 1, Vector3.new(0.7, 0.22, 0.7), CFrame.new(g) * ctx.base.Rotation, {
				{ 0.12, 0.3, 0.3, 0.3, 1 }, { 0.19, 1, 1, 1, 1 }, { 0.44, 1.1, 0.2, 1.1, 0 } })
			if md then table.insert(fx, md) end
			for i = 1, 2 do
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.2, 0), Vector3.new((i - 1.5) * 3, 5, 0), 0.14, 0.4, 0.12)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
		{ t = 0.20, fn = function(ctx) return gooDrop(ctx, ctx.bonePos("Body"), Vector3.new(0, -2, 0), 0.13, 0.5, 0.20) end },
		{ t = 0.34, fn = function(ctx) return gooDrop(ctx, ctx.bonePos("Body"), Vector3.new(0, -2, 0), 0.11, 0.5, 0.34) end },
		{ t = 0.52, fn = function(ctx)                                       -- (landing: ring + puddle, a 1.20 splat)
			if not ctx.escape then return end
			local g = ctx.escape
			ctx.sound(GSND.goo, g.Position, 0.4, 1.7)
			local fx = {}
			local rg = gooKeyed(ctx, "ring", 1, Vector3.new(1.2, 0.08, 1.2), g, { { 0.52, 0.4, 1, 0.4, 1 }, { 0.62, 1, 1, 1, 1 }, { 0.80, 1.05, 0.6, 1.05, 0 } })
			if rg then table.insert(fx, rg) end
			local pd = gooKeyed(ctx, "puddle", 1, Vector3.new(0.9, 0.05, 0.9), g, { { 0.52, 0.5, 1, 0.5, 1 }, { 0.60, 1, 1, 1, 1 }, { 0.80, 1.05, 0.5, 1.05, 0 } })
			if pd then table.insert(fx, pd) end
			return group(fx)
		end },
	},
}

-- ===================== BOING failed: SQUASHED flat (its own pancake mesh, eye on top), takes half damage, pops back up ====
-- 0.00 squint + curl jolts up, 0.03-0.06 collapse (the rig hides, the pancake is there at full size by 0.06), 0.06-0.40
-- hold (a faint tremor), 0.40-0.56 the pancake pulls in, 0.52-0.60 the rig is back, 0.62 pop (Top +0.12), rebound to 0.80
A.Squash = {
	boneKeys = true, dur = 0.95, lock = 0.80,
	keys = dripKeys({
		{ 0.00, "smooth", L = 30, C = { 25, 0, 0 } },
		{ 0.03, "in", B = { 0, 0, 0, 0, -0.30 }, T = { 0, 0, 0, 0, -0.30 }, C = { 30, 0, 0 }, L = 45 },
		{ 0.06, "in", B = { 0, 0, 0, 0, -0.45 }, T = { 0, 0, 0, 0, -0.45 }, C = { 10, 0, 0 }, L = 45 },
		{ 0.52, "smooth", B = { 0, 0, 0, 0, -0.30 }, T = { 0, 0, 0, 0, -0.20 }, L = 20 },
		{ 0.62, "out", T = { 0, 0, 0, 0, 0.12 }, C = { -10, 0, 0 } },
		{ 0.70, "smooth", C = { -25, 0, 0 } },
		{ 0.80, "smooth", C = { 12, 0, 0 } },
		{ 0.95, "smooth" },
	}),
	events = {
		{ t = 0.03, fn = function(ctx)
			ctx.sound(GSND.goo, ctx.base.Position, 0.65, 1.1)                                      -- (compressed wet fwup)
			local pan = gm(ctx, "pancake", 1, Vector3.new(2.1, 0.22, 1.8), CFrame.new())
			local parts, was = {}, {}
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(parts, d); was[d] = d.LocalTransparencyModifier end end
			if pan then pan.Transparency = 1 end
			local g = groundAt(ctx, ctx.base.Position)
			return { step = function(_, t)
				if t > 0.70 then return false end
				local on = math.min(smooth((t - 0.03) / 0.03), 1 - smooth((t - 0.52) / 0.08))         -- (the rig hidden 0.06-0.52)
				for _, d in parts do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], on) end end
				if pan then
					local pull = smooth((t - 0.40) / 0.16)                                              -- (pulls inward, eye last)
					local trem = (t < 0.40) and 1 + 0.03 * sin(t * 70) or 1
					local sx = (0.6 + 0.4 * smooth((t - 0.03) / 0.03)) * (1 - 0.45 * pull) * trem
					pan.Size = Vector3.new(2.1 * sx, 0.22 * (1 + 0.6 * pull), 1.8 * sx / trem)
					pan.CFrame = CFrame.new(g + Vector3.new(0, pan.Size.Y / 2, 0)) * ctx.base.Rotation   -- (its curl trails behind)
					pan.Transparency = 1 - math.min(smooth((t - 0.03) / 0.03), 1 - smooth((t - 0.50) / 0.08))
				end
				return true
			end, stop = function() if pan then pan:Destroy() end; for _, d in parts do if d.Parent then d.LocalTransparencyModifier = was[d] end end end }
		end },
		{ t = 0.45, fn = function(ctx)                                       -- (release: one little ripple, 0.85 across)
			local g = groundAt(ctx, ctx.base.Position)
			return gooKeyed(ctx, "ring", 1, Vector3.new(0.85, 0.06, 0.85), CFrame.new(g), { { 0.45, 0.5, 1, 0.5, 1 }, { 0.58, 1, 1, 1, 0.8 }, { 0.75, 1.1, 0.5, 1.1, 0 } })
		end },
		{ t = 0.56, fn = function(ctx) ctx.sound(GSND.pop, ctx.base.Position, 0.55, 1.6) end },
	},
}

-- ===================== BOING BOMBS (ORDER, warn 0.55): spring onto the nearest big enemy's back, splat on, CLING ==========
-- 0.00-0.55 wind-up (ONE mark on the target: a cyan ring on its back), 0.60 launch, 0.91 ball at the apex, 1.10 dive,
-- 1.25 SPLAT ON (the slope splat, 0.30 -> 1 by +0.17, fading +0.45..+0.80 into the cling pin), 1.31 first bite (+15),
-- 1.45 hand-off to CLING (bites every 0.50 s). Flight Q(u) = lerp + 4 h u (1 - u), h = clamp(2.5 + 0.4 |dy|, 2.5, 9)
local MARKS = {}                                                    -- target -> { expiry, owner } of its one mark
A.marksCount = function() local n = 0; for _ in MARKS do n += 1 end; return n end
A.Bombs = {
	boneKeys = true, dur = 3.07, lock = 3.07,
	keys = dripKeys({
		{ 0.00, "smooth", R = { 0, 0, 0, -5 }, B = { 0, 0, 0, 0, -0.08 }, C = { 10, 0, 0 } },
		{ 0.40, "in", R = { 0, 0, 0, -12 }, B = { 0, 0, 0, 0, -0.23 }, T = { 0, 0, 0, 0, -0.14 }, C = { 38, 0, 0 }, A = { 0, 0, -10, 0.06 } },
		{ 0.55, "in", R = { 0, 0, 0, -12 }, B = { 0, 0, 0, 0, -0.26 }, T = { 0, 0, 0, 0, -0.16 }, C = { 42, 0, 0 }, A = { 0, 0, -10, 0.06 } },
		{ 0.60, "out", B = { 0, 0, 0, 0, 0.16 }, T = { 0, 0, 0, 0, 0.18 }, C = { 32, 0, 0 }, F = { 30, 0, 0, 0, 0.12, 0.18 } },
		{ 0.91, "smooth", B = { 0, 0, 0, 0, -0.06 }, T = { 0, 0, 0, 0, -0.08 }, C = { 15, 0, 0 }, A = { 0, 0, -25, 0.10 }, F = { 35, 0, 0, 0, 0.18, 0.08 } },
		{ 1.10, "in", B = { -35, 0, 0 }, T = { 0, 0, 0, 0, -0.06 }, C = { 45, 0, 0 }, A = { 0, 0, -25, 0.10 }, F = { 35, 0, 0, 0, 0.18, 0.08 } },
		{ 1.25, "out", B = { -8, 0, 0, 0, -0.24 }, T = { 0, 0, 0, 0, -0.18 }, C = { -28, 0, 0 }, A = { 0, 0, 30, -0.08 }, F = { 0, 0, 0, -0.08 } },
		{ 1.31, "in", B = { -14, 0, 0, 0, -0.20 }, T = { 0, 0, 0, 0, -0.12 }, C = { -36, 0, 0 }, A = { 0, 0, 30, -0.08 }, L = 18 },
		{ 1.45, "smooth", B = { -4, 0, 0, 0, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		-- (audit r2: regular bites every 0.50 after the bonus bite at 1.31: cycles start 1.57 / 2.07 / 2.57; wind +0.10,
		-- lunge +0.24 (1.81 / 2.31 / 2.81), rebound +0.33, settle +0.50)
		{ 1.57, "smooth", B = { -4, 0, 0, 0, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 1.67, "out", B = { 3, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.02 }, C = { 18, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 1.81, "in", B = { -14, 0, 0, 0, -0.12 }, T = { 0, 0, 0, 0, -0.10 }, C = { -32, 0, 0 }, A = { 0, 0, 25, -0.06 }, L = 18 },
		{ 1.90, "out", B = { 0, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.03 }, C = { 15, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.07, "smooth", B = { -4, 0, 0, 0, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.17, "out", B = { 3, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.02 }, C = { 18, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.31, "in", B = { -14, 0, 0, 0, -0.12 }, T = { 0, 0, 0, 0, -0.10 }, C = { -32, 0, 0 }, A = { 0, 0, 25, -0.06 }, L = 18 },
		{ 2.40, "out", B = { 0, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.03 }, C = { 15, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.57, "smooth", B = { -4, 0, 0, 0, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.67, "out", B = { 3, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.02 }, C = { 18, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 2.81, "in", B = { -14, 0, 0, 0, -0.12 }, T = { 0, 0, 0, 0, -0.10 }, C = { -32, 0, 0 }, A = { 0, 0, 25, -0.06 }, L = 18 },
		{ 2.90, "out", B = { 0, 0, 0, 0, -0.08 }, T = { 0, 0, 0, 0, -0.03 }, C = { 15, 0, 0 }, A = { 0, 0, 25, -0.06 } },
		{ 3.07, "smooth", B = { -4, 0, 0, 0, -0.10 }, T = { 0, 0, 0, 0, -0.06 }, C = { -12, 0, 0 }, A = { 0, 0, 25, -0.06 } },
	}),
	place = function(ctx, t)
		local at = ctx.bomb
		if not at or not at.t.Parent then return nil end
		if t < 0.60 then return faceToward(ctx.base, at, t) end
		local dn = 0
		if t >= 1.25 and t < 1.45 then dn = (t < 1.31) and -0.10 * smooth((t - 1.25) / 0.06) or -0.10 * (1 - smooth((t - 1.31) / 0.14))
		elseif t >= 1.57 then dn = biteDn(t - 1.57) * 0.6 end                     -- (audit r2: the regular cycle from 1.57)
		local F = clingFrame(at, dn)
		if t < 1.25 then
			local h = math.clamp(2.5 + 0.4 * math.abs(F.Y - ctx.base.Y), 2.5, 9)
			return arc(faceToward(ctx.base, at, 1) or ctx.base, F, (t - 0.60) / 0.65, h)
		end
		return F
	end,
	events = {
		-- the target's mark (one per target, however many Drips come): a cyan ring 1.50 across on its back + a dark rim
		{ t = 0, fn = function(ctx)
			-- (its back full (10 on a Ram or a Colossus left 2-4 on the ground, measured): the overflow lands on its flanks)
			ctx.bomb = findBomb(ctx)
			ctx.sound(GSND.wobble, ctx.base.Position, 0.45, 1.6)
			local me = ctx.m
			local holdSpot = { step = function(_, t)
				if not ctx.bomb and t < 0.60 then ctx.bomb = findBomb(ctx) end                -- (target not here yet: look again)
				me:SetAttribute("StuckTo", ctx.bomb and ctx.bomb.t.Name or "NONE")              -- (test readout)
				return t <= 3.07
			end, stop = function() unclaim(ctx.bomb and ctx.bomb.t, me) end }                 -- (its spot, freed at the end)
			local at = ctx.bomb
			if not at then return holdSpot end                                               -- (no mark without a target yet)
			local now = os.clock()
			local cur = MARKS[at.t]
			if cur and cur.expiry > now and cur.owner.Parent then return holdSpot end
			local token = { expiry = now + 0.6, owner = ctx.m }                       -- (audit r2: the mark owns its entry)
			MARKS[at.t] = token
			workspace:SetAttribute("AFMarks", A.marksCount())                          -- (test readout)
			local target = at.t
			local function release() if MARKS[target] == token then MARKS[target] = nil end; workspace:SetAttribute("AFMarks", A.marksCount()) end
			task.delay(0.65, release)                                                  -- (gone 0.65 s after the cast, even if nothing stops it)
			local rg = gm(ctx, "ring", 1, Vector3.new(1.5, 0.10, 1.5), CFrame.new())
			local under = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = G_RIM, Transparency = 1, Size = Vector3.new(0.03, 1.78, 1.78) })
			local fill = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = G_FILL, Transparency = 1, Size = Vector3.new(0.035, 1.5, 1.5) })
			local mark = { step = function(_, t)
				if t > 0.60 then return false end
				local p, n = surfaceNow(at)
				local fx = (math.abs(n.Y) < 0.95) and Vector3.yAxis:Cross(n).Unit or Vector3.xAxis
				local s = 0.85 + 0.15 * smooth(t / 0.40)
				local fl = (t > 0.40) and pulse(t, 0.40, 2, 0.15) or 0
				local frame = CFrame.fromMatrix(p + n * 0.06, fx, n)
				if rg then rg.Size = Vector3.new(1.5 * s, 0.10, 1.5 * s); rg.CFrame = frame; rg.Transparency = 0.15 - 0.15 * fl end
				under.CFrame = frame * CFrame.new(0, -0.02, 0) * CFrame.Angles(0, 0, pi / 2); under.Size = Vector3.new(0.03, 1.78 * s, 1.78 * s); under.Transparency = 0.25
				fill.CFrame = frame * CFrame.new(0, -0.01, 0) * CFrame.Angles(0, 0, pi / 2); fill.Size = Vector3.new(0.035, 1.5 * s, 1.5 * s); fill.Transparency = 0.55 - 0.15 * fl
				return true
			end, stop = function() release(); if rg then rg:Destroy() end; under:Destroy(); fill:Destroy() end }
			local markDone = false
			return { step = function(_, t)                                       -- (the mark to 0.60, the spot held to 3.07)
				if not markDone and not mark:step(t) then markDone = true; mark:stop() end
				return holdSpot:step(t)
			end, stop = function() if not markDone then markDone = true; mark:stop() end; holdSpot:stop() end }
		end },
		{ t = 0.40, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.4, 2.1) end },
		{ t = 0.60, fn = function(ctx)                                       -- (launch: a higher spring + the puff where it stood)
			ctx.sound(GSND.pop, ctx.base.Position, 0.65, 1.45)
			local g = groundAt(ctx, ctx.base.Position)
			local fx = {}
			local md = gooKeyed(ctx, "mound", 1, Vector3.new(0.8, 0.24, 0.8), CFrame.new(g) * ctx.base.Rotation, {
				{ 0.60, 0.3, 0.3, 0.3, 1 }, { 0.67, 1, 1, 1, 1 }, { 0.92, 1.1, 0.2, 1.1, 0 } })
			if md then table.insert(fx, md) end
			for i = 1, 2 do
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.2, 0), Vector3.new((i - 1.5) * 3, 6, 0), 0.15, 0.4, 0.60)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
		{ t = 0.78, fn = function(ctx) return gooDrop(ctx, ctx.bonePos("Body"), Vector3.new(0, -1, 0), 0.14, 0.6, 0.78) end },
		{ t = 0.95, fn = function(ctx) return gooDrop(ctx, ctx.bonePos("Body"), Vector3.new(0, -1, 0), 0.12, 0.6, 0.95) end },
		-- SPLAT ON: the slope splat on its back (the rounded variant on a curved back), riding the target; the pin from +0.45
		{ t = 1.25, fn = function(ctx)
			local at = ctx.bomb
			if not at then return end
			local P = surfaceNow(at)
			ctx.sound(GSND.slap, P, 0.8, 1.6)
			local fx = {}
			local rounded = (at.mode == "top")
			local sp = gm(ctx, "splat", rounded and 1 or 0, Vector3.new(2.6, 0.45, 2.3), CFrame.new())   -- (rounded on a back, flat else; 2.6 wide, not 1.85: at the spec size the Drip itself hid it, measured)
			local rim = gm(ctx, "splat", rounded and 1 or 0, Vector3.new(2.8, 0.40, 2.5), CFrame.new())   -- (audit r1: a dark-violet edge 0.10 wider)
			if rim then for _, c in rim:GetChildren() do c:Destroy() end; rim.Material = Enum.Material.SmoothPlastic; rim.Color = Color3.fromRGB(58, 26, 104); rim.Transparency = 1 end
			if sp then
				sp.Transparency = 1
				local sa = sp:FindFirstChildOfClass("SurfaceAppearance")
				if sa then sa.EmissiveStrength = sa.EmissiveStrength * 2.2 end                     -- (brighter cyan cracks)
				table.insert(fx, { step = function(_, t)
					local e = t - 1.25
					if e > 0.80 then return false end
					local p, n = surfaceNow(at)
					local down = Vector3.new(0, -1, 0) - n * (-n.Y)                          -- (its drips run down the slope)
					down = (down.Magnitude > 0.05) and down.Unit or -at.out
					local s = 0.3 + 0.7 * smooth(e / 0.17)
					-- (audit r1: it was centred 0.04 off the surface, half of it buried. The flat splat's bottom sits 0.04 above
					-- the surface; the rounded one's CENTRE does (its rim drapes down the back), its mound 0.17 of its height)
					local h = 0.45 * s
					local lift = rounded and (0.04 + 0.17 * h - h / 2) or (0.04 + h / 2)
					local frame = CFrame.fromMatrix(p, n:Cross(down), n) * CFrame.Angles(0, pi, 0)
					sp.Size = Vector3.new(2.6 * s, h, 2.3 * s)
					sp.CFrame = frame + n * lift + down * 0.6                                -- (spread 0.6 down the slope: centred, the Drip hid all but 0.25 of it)
					sp.Transparency = smooth((e - 0.45) / 0.35)
					if rim then
						rim.Size = Vector3.new(2.8 * s, 0.40 * s, 2.5 * s)
						rim.CFrame = frame + n * (lift - 0.03) + down * 0.6
						rim.Transparency = 0.1 + 0.9 * smooth((e - 0.45) / 0.35)
					end
					return true
				end, stop = function() sp:Destroy(); if rim then rim:Destroy() end end })
			end
			for i = 1, 2 do
				local dr = gooDrop(ctx, P + Vector3.new(0, 0.3, 0), Vector3.new((i - 1.5) * 4, 4, 0), 0.12, 0.35, 1.33)
				if dr then table.insert(fx, dr) end
			end
			local pin = clingPin(ctx, at, 1.70, 3.07)
			if pin then table.insert(fx, pin) end
			local reg = false
			table.insert(fx, { step = function(_, t)
				if t >= 1.45 and not reg then reg = true; gooedSet(at.t, ctx.m, true) end
				return t <= 3.07
			end, stop = function() if reg then gooedSet(at.t, ctx.m, false) end end })
			return group(fx)
		end },
	},
}
for _, bt in { 1.31, 1.81, 2.31, 2.81 } do
	table.insert(A.Bombs.events, { t = bt, fn = function(ctx)
		local at = ctx.bomb
		if not at then return end
		biteSound(ctx, (surfaceNow(at)))
		return biteSplat(ctx, at, bt)
	end })
end

-- ===================== HURT (0.52, additive; keys for a hit on its LEFT (-X), pushing it toward +X) =====================
-- the left cheek dents in (DentL, 0.16), the body leans away, the curl swings, a squint; a jelly overshoot past upright
A.DripHurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,
	keys = dripKeys({
		{ 0.00, "smooth" },
		{ 0.07, "out", R = { 0, 0, 0, 0, -19 }, B = { 0, 0, 0, 0.10, -0.06 }, T = { 0, 0, -11 }, C = { 0, 0, 32 }, L = 26, extra = { DentL = { 0, 0, 0, 0.16, 0, 0 } } },
		{ 0.16, "smooth", R = { 0, 0, 0, 0, -12 }, B = { 0, 0, 0, 0.07 }, T = { 0, 0, -6 }, C = { 0, 0, 20 }, L = 20, extra = { DentL = { 0, 0, 0, 0.10, 0, 0 } } },
		{ 0.27, "smooth", R = { 0, 0, 0, 0, 9 }, B = { 0, 0, 0, -0.05 }, T = { 0, 0, 7 }, C = { 0, 0, -22 }, L = 8, extra = { DentL = { 0, 0, 0, -0.025, 0, 0 } } },
		{ 0.40, "smooth", R = { 0, 0, 0, 0, -3 }, T = { 0, 0, -2 }, C = { 0, 0, 8 } },
		{ 0.52, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			ctx.sound(GSND.goo, ctx.hurtAt or ctx.base.Position, 0.5, 1.9)                         -- (tiny startled squeak + wet)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local at = ctx.bonePos((out:Dot(ctx.base.RightVector) > 0) and "DentR" or "DentL")
			local fx = {}
			for i = 1, 3 do
				local dr = gooDrop(ctx, at, out * (2 + i * 0.6) + Vector3.new(0, 3 + i * 0.5, (i - 2) * 0.8), 0.10 + 0.05 * i, 0.30, 0.03)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
	},
}

-- ===================== DEFEAT (3.70, terminal): dazed (spiral eye), melt into a mound, a flat puddle, ONE mote ==========
A.DripDefeat = {
	boneKeys = true, dur = 3.70,
	keys = dripKeys({
		{ 0.00, "smooth", B = { 4, 0, 0 }, L = 10 },
		{ 0.30, "out", B = { 0, 0, 12, 0, -0.10 }, T = { 0, 0, -9 }, C = { -28, 0, 0 }, A = { 0, 0, -20 }, L = 12 },
		{ 0.55, "smooth", B = { 0, 0, -8, 0, -0.14 }, T = { 0, 0, 6 }, C = { -42, 0, 0 }, A = { 0, 0, -30 }, L = 20 },
		{ 0.85, "smooth", B = { 0, 0, 0, 0, -0.35 }, T = { 0, 0, 0, 0, -0.20 }, C = { -55, 0, 0 }, A = { 0, 0, -40 }, L = 35 },
		{ 1.20, "in", B = { 0, 0, 0, 0, -0.55 }, T = { 0, 0, 0, 0, -0.45 }, C = { -60, 0, 0 }, A = { 0, 0, -45 }, L = 50 },
		{ 1.65, "in", B = { 0, 0, 0, 0, -0.80 }, T = { 0, 0, 0, 0, -0.72 }, C = { -60, 0, 0 }, A = { 0, 0, -45 }, L = 60 },
		{ 3.70, "smooth", B = { 0, 0, 0, 0, -0.80 }, T = { 0, 0, 0, 0, -0.72 }, C = { -60, 0, 0 }, A = { 0, 0, -45 }, L = 60 },
	}),
	extra = function(t, p) p.glowMul = 1 - smooth((t - 1.2) / 0.9) end,
	events = {
		{ t = 0, fn = function(ctx)
			-- (each part's own transparency, kept for a cancelled defeat; MOVE TEST repeats show it again first)
			ctx.defeatWas = {}
			local replay = ctx.m:GetAttribute("MoveTest")
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then
					if replay then d.LocalTransparencyModifier = 0 end
					ctx.defeatWas[d] = d.LocalTransparencyModifier
				end
			end
			ctx.castAt = os.clock()
			ctx.sound(GSND.gurgle, ctx.base.Position, 0.45, 1.5)
		end },
		-- the DAZED eye: a spiral on the iris, a half turn over 0.45 s, then gone by 0.95
		{ t = 0.30, fn = function(ctx)
			local sp = gm(ctx, "spiral", 1, Vector3.new(0.34, 0.02, 0.34), CFrame.new())
			if not sp then return end
			sp.Transparency = 1
			sp.Material, sp.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(18, 8, 30)   -- (near-black on the purple iris: sheet J3)
			local body = ctx.m:FindFirstChild("Body", true)
			return { step = function(_, t)
				if t > 0.95 then return false end
				local f = (body and body:IsA("Bone")) and (body :: Bone).TransformedWorldCFrame or ctx.base
				local spin = pi * smooth((t - 0.30) / 0.45)
				sp.CFrame = f * CFrame.new(PUPIL) * CFrame.Angles(-pi / 2, 0, 0) * CFrame.Angles(0, spin, 0)   -- (its face toward -Z, out of the eye)
				sp.Transparency = 0.05 + 0.95 * math.max(1 - smooth((t - 0.30) / 0.06), smooth((t - 0.80) / 0.15))
				return true
			end, stop = function() sp:Destroy() end }
		end },
		{ t = 0.85, fn = function(ctx) ctx.sound(GSND.gurgle, ctx.base.Position, 0.55, 1.25) end },        -- (falling watery warble)
		-- the MELT: the body fades 1.30-2.05 while the melt cap (lid shut) takes over, sinks and goes; the flat puddle grows
		-- 1.20-2.20 and fades 3.20-3.70. Terminal once faded (2.05): never restored
		{ t = 1.20, fn = function(ctx)
			local g = groundAt(ctx, ctx.base.Position)
			local fx = {}
			local pd = gooKeyed(ctx, "puddle", 2, Vector3.new(2.2, 0.09, 2.0), CFrame.new(g + Vector3.new(0, 0.01, 0)) * ctx.base.Rotation, {
				{ 1.20, 0.5, 1, 0.5, 1 }, { 2.20, 1, 1, 1, 1 }, { 3.20, 1, 1, 1, 1 }, { 3.70, 1.03, 0.6, 1.03, 0 } })
			if pd then table.insert(fx, pd) end
			local cap = gm(ctx, "meltcap", 1, Vector3.new(2.2, 0.65, 1.9), CFrame.new())
			if cap then
				cap.Transparency = 1
				table.insert(fx, { step = function(_, t)
					if t > 2.35 then cap.Transparency = 1; return true end
					local on = smooth((t - 1.30) / 0.25)
					local h = 0.65 * (1 - 0.75 * smooth((t - 1.65) / 0.55))
					cap.Size = Vector3.new(2.2 * (0.85 + 0.15 * on), h, 1.9 * (0.85 + 0.15 * on))
					cap.CFrame = CFrame.new(g + Vector3.new(0, h / 2, 0)) * ctx.base.Rotation
					cap.Transparency = 1 - on * (1 - smooth((t - 2.05) / 0.25))
					return true
				end, stop = function() cap:Destroy() end })
			end
			local hidden, was, done = {}, ctx.defeatWas or {}, false
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); if was[d] == nil then was[d] = d.LocalTransparencyModifier end end end
			table.insert(fx, { step = function(_, t)
				if t >= 2.05 then done = true end
				local gone = smooth((t - 1.30) / 0.75)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], gone) end end
				return true
			end, stop = function() if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end end })
			return group(fx)
		end },
		-- exactly ONE matter mote: a cyan core 0.22 across with one faint trailing ribbon 0.75 long, rising 1.60 in 0.85 s
		{ t = 2.35, fn = function(ctx)
			if ctx.moteAt == ctx.castAt and ctx.castAt then return end                         -- (guard: one mote per defeat)
			ctx.moteAt = ctx.castAt
			ctx.sound(SND.glass, ctx.base.Position, 0.45, 2.0, 0.6)
			local o = groundAt(ctx, ctx.base.Position) + Vector3.new(0, 0.1, 0)
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = G_CYAN, Transparency = 1, Size = Vector3.one * 0.22, CFrame = CFrame.new(o) })
			local tail = gm(ctx, "rope", 1, Vector3.new(0.07, 0.75, 0.07), CFrame.new(o))
			if tail then tail.Material = Enum.Material.Neon; tail.Color = G_CYAN; for _, c in tail:GetChildren() do c:Destroy() end end
			local side = ctx.base.RightVector
			return { step = function(_, t)
				if t > 3.70 then return false end
				local e = t - 2.35
				local u = smooth(e / 0.85)
				local p = o + Vector3.new(0, 1.6 * u, 0) + side * 0.16 * sin(e * 4)
				local a = math.max(1 - smooth(e / 0.10), smooth((t - 3.20) / 0.45))
				core.CFrame = CFrame.new(p); core.Transparency = a
				if tail then
					local back = p - Vector3.new(0, 0.42, 0) - side * 0.08 * cos(e * 4)
					tail.CFrame = CFrame.lookAt((p + back) / 2, back) * CFrame.Angles(-pi / 2, 0, 0)
					tail.Transparency = 0.55 + 0.45 * a
				end
				return true
			end, stop = function() core:Destroy(); if tail then tail:Destroy() end end }
		end },
	},
}
A.FOR.SquishF1v5 = { Cling = A.Cling, Boing = A.DripBoing, Squash = A.Squash, Bombs = A.Bombs, Defeat = A.DripDefeat, Hurt = A.DripHurt }

-- (every timeline's events in time order)
for _, atk in { A.Cling, A.DripBoing, A.Squash, A.Bombs, A.DripHurt, A.DripDefeat } do table.sort(atk.events, function(x, y) return x.t < y.t end) end

-- ===================== BATCH 5: the CRUNCH PEBBLE (spec design/17-PEBBLE-BATCH5-SPEC-chatgpt-raw.md) =====================
-- Built to its reference sheets (design/concepts/pebble/attacks/: J1 CHIP, J2 CURL UP, J3 ROLL OUT, J4 HURT + DEFEAT,
-- K EFFECTS). A 2.4-stud rock beetle: Root -> Body -> Head (horn + mandibles, rigid), Leg / Shin <L1-3 R1-3> on Body
-- (L = its left = -X). It fights big enemies FROM THE GROUND: a "low" stick point (AttachPoints, 0.4-1.6 studs up the
-- target's real mesh) is the hit point, the Pebble stands off it facing in, and its horn tip is pulled onto it by moving
-- the whole unit (atk.place, at most 0.35). CURL UP / ROLL OUT swap in the stone ball (FX.GooMeshes.pebbleBall1).
-- Rock effects: A.rock (AttacksCrunch). Many Pebbles on one target claim spots 3.2 apart (squeeze to 2.2).
-- ============================================================================================================
do
local function R() return A.rock end
local C3, dust, sparks, AMBER, claimFrag = Color3.fromRGB, E.dust, E.sparks, E.AMBER, E.claimFrag
local FXF = game.ReplicatedStorage.AlienFusion:FindFirstChild("FX")
-- (the horn tip / the mandible front in the Head bone's own frame (its axes are Blender's, not the model's): model-space
-- (0, 1.40, -2.56) / (-0.10, 0.34, -2.17) through the rest Head bone, measured in Play)
local HORN, MAND = Vector3.new(0, 1.449, 1.147), Vector3.new(-0.10, 1.342, 0.023)
-- (the horn tip in the JAB pose, up / ahead of the pivot. Audit r1 check: 0.84 was read off a frame that already had the
-- solver's lift in it; the unsolved need over 8 Pebbles on a Brute and a Ram was a steady 0.31-0.43 DOWN, so 1.19)
local HORN_Y, HORN_Z = 1.19, 2.86
-- (legs are children of Body: a Body dip / pitch would push the feet into the ground. Each leg gets the opposite offset)
local FEET = { L1 = -1.28, R1 = -1.28, L2 = -0.08, R2 = -0.08, L3 = 1.0, R3 = 1.0 }   -- (toe z from the Body origin)
local TOE_Y = -0.61
local function pebKeys(rows)
	local keys = {}
	for i, r in rows do
		local B = r.B or { 0, 0, 0 }
		local b = { Body = B, Head = r.H or { 0, 0, 0 } }
		local rx, oy, oz = math.rad(B[1] or 0), B[5] or 0, B[6] or 0
		for leg, z in FEET do
			local dy = (math.cos(rx) - 1) * TOE_Y - math.sin(rx) * z            -- (how far the toe moves with the body)
			local side = (leg:sub(1, 1) == "L") and -1 or 1
			local v = (r.legs and r.legs[leg:sub(2, 2)]) or { 0, 0, 0 }
			b["Leg" .. leg] = { v[1] or 0, (v[2] or 0) * side, (v[3] or 0) * -side, 0, -(oy + dy), -oz }
			b["Shin" .. leg] = { (v[4] or 0), 0, 0 }
		end
		for k, v in r.extra or {} do b[k] = v end
		local Rt = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { Rt[1] or 0, Rt[2] or 0, Rt[3] or 0, Rt[4] or 0, Rt[5] or 0, Rt[6] or 0 }, bones = b }
	end
	return keys
end
-- the skitter (its walk), layered on in `extra` while it runs to its spot / rolls back out: the tripod lift + swing
local TRIPOD = { L1 = 0, R2 = 0.04, L3 = 0.08, R1 = 0.5, L2 = 0.54, R3 = 0.58 }
local function skitter(p, t, w)
	if w <= 0 then return end
	local ph = (t * 4) % 1
	for leg, o in TRIPOD do
		local side = (leg:sub(1, 1) == "L") and -1 or 1
		local q = 2 * pi * (ph - o)
		local up = math.max(0, sin(q))
		local L, S = p.bones["Leg" .. leg] or { 0, 0, 0, 0, 0, 0 }, p.bones["Shin" .. leg] or { 0, 0, 0, 0, 0, 0 }
		L[1] += 22 * cos(q) * w; L[3] += side * 20 * up * w
		S[3] = (S[3] or 0) + side * 16 * up * w
		p.bones["Leg" .. leg], p.bones["Shin" .. leg] = L, S
	end
end
local function bonePoint(ctx, name, off)
	local b = ctx.m:FindFirstChild(name, true)
	return (b and b:IsA("Bone")) and (b :: Bone).TransformedWorldCFrame * off or nil
end
-- a ground spot facing a LOW point on the target: horn height (0.8-1.7 up), the Pebble's side first, claimed 3.2 apart
-- (then 2.2). Returns { at, stand } (stand = the frame its pivot stands on, facing the point)
-- (a stand is good when none of the target's own surface points (its low + wall sets, the real mesh) sit in the strip the
-- Pebble fills: from the point out to its pivot, 1.3 to each side, 0-1.6 up. A target's mesh is not ray-queryable on the
-- client (CanQuery off; turning it on did not help, measured), so its authored points stand in for it)
local function standClear(set, cf: CFrame, stand: CFrame, pos: Vector3)
	local back = -stand.LookVector
	local right = stand.RightVector
	local gy = stand.Y
	for _, list in { set.low, set.wall } do
		for _, p in list do
			local w = cf * Vector3.new(p[1], p[2], p[3])
			local d = w - pos
			local along, side, up = d:Dot(back), math.abs(d:Dot(right)), w.Y - gy
			if along > 0.35 and along < HORN_Z + 0.4 and side < 1.3 and up > -0.2 and up < 1.6 then return false end
		end
	end
	return true
end
local function groundSpot(ctx, t, slot)
	local set = POINTS[t:GetAttribute("FormName") or ""]
	if not set or not set.low then return nil end
	local cf = t:GetPivot()
	local me = ctx.m
	local to = (ctx.base.Position - cf.Position) * Vector3.new(1, 0, 1)
	-- (its pivot rides this high over the ground: the stand keeps it. A point counts only where the horn tip, 0.84 over the
	-- pivot in its jab, can reach it within 1.0 up or down (its head aims): the low points' heights are from the target's pivot, not the ground)
	local hover = ctx.base.Y - ctx.ground(ctx.base.X, ctx.base.Z)
	local order = {}
	local cands = table.clone(set.low)
	for _, p in set.wall do table.insert(cands, p) end                     -- (low flanks: the Ram has few low points, measured)
	for i, p in cands do
		local pos = cf * Vector3.new(p[1], p[2], p[3])
		local n = cf:VectorToWorldSpace(Vector3.new(p[4], 0, p[6]))
		local radial = (pos - cf.Position) * Vector3.new(1, 0, 1)
		-- (facing out from the target: the low band is full of inner-leg faces that point at its belly, measured: a Pebble
		-- stood between a Brute's legs)
		if n.Magnitude > 0.4 and radial.Magnitude > 0.1 and n.Unit:Dot(radial.Unit) > 0.25 then
			local q = pos + n.Unit * HORN_Z
			local dy = pos.Y - (ctx.ground(q.X, q.Z) + hover + HORN_Y)
			if math.abs(dy) <= 1.0 then                                -- (sorted: the closest heights first; the Ram has few)
				local dir = Vector3.new(p[1], 0, p[3])
				local facing = (dir.Magnitude > 0.1 and to.Magnitude > 0.1) and (1 - cf:VectorToWorldSpace(dir).Unit:Dot(to.Unit)) or 1
				table.insert(order, { p = p, dy = dy, s = facing * 1.5 + math.abs(dy) * 4 + ((i * 7 + slot * 13) % 11) * 0.25 })
			end
		end
	end
	table.sort(order, function(a, b) return a.s < b.s end)
	local nClaim, nClear = 0, 0
	for _, gap in { 3.2, 2.2 } do
		spacingNow = gap
		for _, o in order do
			local p = o.p
			local pos = cf * Vector3.new(p[1], p[2], p[3])
			local n = cf:VectorToWorldSpace(Vector3.new(p[4], 0, p[6])).Unit       -- (horizontal: it stands on the ground)
			local q = pos + n * HORN_Z
			local g = Vector3.new(q.X, ctx.ground(q.X, q.Z) + hover, q.Z)
			local stand = CFrame.lookAt(g, g - n)
			-- (Pebbles are spaced by their BODIES (stand points), their hit points only 0.5 apart: on a Ram nearly every point at
			-- horn height is on one of its 4 legs, and point spacing let only 4 of 6 in, measured; two can work one leg from two sides)
			local free = true
			local lp, lc = cf:PointToObjectSpace(pos), cf:PointToObjectSpace(g)
			for _, c in CLAIMS[t] or {} do
				if c.owner ~= me and c.owner.Parent and ((c.p - lp).Magnitude < 0.5 or (c.c - lc).Magnitude < spacingNow) then free = false; break end
			end
			local clear = free and standClear(set, cf, stand, pos)
			if not free then nClaim += 1 elseif not clear then nClear += 1 end
			if free and clear then
				spacingNow = SPACING
				claim(t, cf, pos, me, nil, g)
				-- (aim: the head pitch, in degrees, that lifts / drops the horn tip (1.85 from the head joint) onto the point's height)
				-- (the spot rides the target's PIVOT, not its nearest bone: a quadruped's IK legs sit far from their rest bones, measured
				-- on the Ram: a horn 8.7 off its point)
				local at = { t = t, anc = function() return t:GetPivot() end, lp = cf:PointToObjectSpace(pos), ln = cf:VectorToObjectSpace(n), mode = "wall", out = n }
				return { at = at, stand = stand, hover = hover, aim = math.deg(math.asin(math.clamp(o.dy / 1.85, -0.45, 0.45))) }
			end
		end
	end
	spacingNow = SPACING
	if me:GetAttribute("MoveTest") or me:GetAttribute("Keep") then me:SetAttribute("SpotDbg", string.format("hover %.2f order %d taken %d blocked %d", hover, #order, nClaim, nClear)) end
	return nil
end
-- the horn (or mouth) pulled onto the surface: where the pivot must be so that tip -> P + 0.03 N, from the tip's place
-- relative to the pivot NOW (last frame's pose). At most 0.35 studs, blended by w
-- where it stands NOW: off its point (which rides the target's pivot) along the point's level normal, on the ground (a big
-- enemy that turns or steps keeps its Pebbles at its feet; a stand-in turned after the spot was picked left one 10 studs
-- off, measured). ok(sp): the point is still at horn height (else it is picked again)
local function standNow(ctx, sp)
	local P, N = surfaceNow(sp.at)
	local n = N * Vector3.new(1, 0, 1)
	n = (n.Magnitude > 0.05) and n.Unit or sp.stand.LookVector * -1
	local q = P + n * HORN_Z
	local g = Vector3.new(q.X, ctx.ground(q.X, q.Z) + sp.hover, q.Z)
	return CFrame.lookAt(g, g - n), P
end
local function spotOk(ctx, sp)
	local S, P = standNow(ctx, sp)
	return math.abs(P.Y - (S.Y + HORN_Y)) <= 1.1
end
-- the BITE: the mandibles go straight in along the surface normal onto the surface plane in front of them (the mouth is
-- 1.06 below the horn: a fixed point under the jab point was 0.57 off, measured)
local function biteTarget(ctx, F, P, N)
	local tip = bonePoint(ctx, "Head", MAND)
	if not tip then return P end
	local w = F * ctx.m:GetPivot():PointToObjectSpace(tip)
	return w - N * ((w - P):Dot(N) - 0.03), w
end
-- (audit r1 check: pulling the tip that is still SWINGING in made nudges of 0.35 at 0.2-0.3 a frame (the raw gap mid-swing
-- is 0.5-1.3). Now the gap is read only AT the contact (w > 0.95) and kept per spot (memo[key], in the pivot's frame); the
-- body eases toward that learned need with the window's weight. The first contact of a spot takes its need in one frame:
-- <= 0.15 measured over 8 Pebbles)
local function onTarget(ctx, F, tipOff, boneName, P, N, w, maxD, memo, key)
	if w <= 0 then return F end
	local tip = bonePoint(ctx, boneName, tipOff)
	if not tip then return F end
	local rel = ctx.m:GetPivot():PointToObjectSpace(tip)
	local want = (P + N * 0.03) - F.Rotation:VectorToWorldSpace(rel)
	local raw = want - F.Position
	if w > 0.95 then
		if memo then memo[key] = F:VectorToObjectSpace(raw) end
		if ctx.m:GetAttribute("Keep") or ctx.m:GetAttribute("MoveTest") then ctx.m:SetAttribute((tipOff == HORN) and "NeedH" or "NeedB", F:VectorToObjectSpace(raw)) end
	end
	local need = (w > 0.95) and raw or (memo and memo[key] and F:VectorToWorldSpace(memo[key])) or (memo and Vector3.zero) or raw
	local d = need * smooth(w)
	d = Vector3.new(d.X, math.clamp(d.Y, -0.10, 0.10), d.Z)                    -- (feet stay down: height is the head aim's job)
	if d.Magnitude > (maxD or 0.35) then d = d.Unit * (maxD or 0.35) end
	-- (audit r1: never more than 0.08 of change from one frame to the next (the first contact of a spot jumped 0.16-0.20))
	if memo then
		local prev = (memo.dAt and os.clock() - memo.dAt < 0.1) and memo.dLast or Vector3.zero
		local step = d - prev
		if step.Magnitude > 0.08 then d = prev + step.Unit * 0.08 end
		memo.dLast, memo.dAt = d, os.clock()
	end
	-- (test readout, audit r1: the largest nudge, and the largest change of it from one frame to the next)
	if ctx.m:GetAttribute("Keep") or ctx.m:GetAttribute("MoveTest") then
		local m = ctx.m
		local last = ctx.lastNudge or Vector3.zero
		if d.Magnitude > (m:GetAttribute("NudgeMax") or 0) then m:SetAttribute("NudgeAt", string.format("w %.2f raw %.2f tip %s", w, (want - F.Position).Magnitude, tostring(tipOff == HORN))) end
		m:SetAttribute("NudgeMax", math.max(m:GetAttribute("NudgeMax") or 0, d.Magnitude))
		m:SetAttribute("NudgeStep", math.max(m:GetAttribute("NudgeStep") or 0, (d - last).Magnitude))
		ctx.lastNudge = d
	end
	return F + d
end
-- CHIP sounds: at most 3 a second on this client (spec 11)
local chipSounds = {}
local function chipSound(ctx, id, pos, vol, pitch)
	local now = os.clock()
	for i = #chipSounds, 1, -1 do if now - chipSounds[i] > 1 then table.remove(chipSounds, i) end end
	if #chipSounds < 3 then table.insert(chipSounds, now); ctx.sound(id, pos, vol, pitch) end
end
local function isGoo(t) return (t:GetAttribute("FormName") or ""):sub(1, 6) == "Squish" end
-- the GOO TEAR (K2): a cyan goo lump stretched out of the bite point + 2 strands, retracting by +0.24
local function gooTear(ctx, at, t0)
	local P, N = surfaceNow(at)
	local lump = gm(ctx, "lump", 1, Vector3.new(0.7, 0.5, 0.55), CFrame.new(P))
	local s1, s2 = gm(ctx, "rope", 1, Vector3.new(0.06, 0.5, 0.06), CFrame.new()), gm(ctx, "rope", 1, Vector3.new(0.05, 0.4, 0.05), CFrame.new())
	return { step = function(_, t)
		local e = t - t0
		if e > 0.26 then return false end
		if e < 0 then return true end
		local p, n = surfaceNow(at)
		local k = 0.5 + 0.5 * smooth(e / 0.08)
		local out = p + n * (0.25 + 0.35 * smooth(e / 0.12))
		if lump then lump.Size = Vector3.new(0.7, 0.5, 0.55) * k * (1 - 0.5 * smooth((e - 0.12) / 0.12)); lump.CFrame = CFrame.lookAt(out, out + n); lump.Transparency = smooth((e - 0.16) / 0.1) end
		for i, st in { s1, s2 } do
			if st then
				local a = p + Vector3.new(0, (i - 1.5) * 0.18, 0)
				local L = (out - a).Magnitude * (1 - smooth((e - 0.10) / 0.14))
				st.Size = Vector3.new(0.06, math.max(0.02, L), 0.06)
				st.CFrame = CFrame.lookAt(a + (out - a).Unit * L / 2, out) * CFrame.Angles(-pi / 2, 0, 0)
				st.Transparency = (L < 0.05) and 1 or 0.1
			end
		end
		return true
	end, stop = function() if lump then lump:Destroy() end; if s1 then s1:Destroy() end; if s2 then s2:Destroy() end end }
end
-- the contact burst for a jab / bite on `at`: rock (shards + a crystal flash) or goo (the tear) by the target's material
local function contactFx(ctx, at, t0, big, bite)
	local P, N = surfaceNow(at)
	local fx = {}
	if isGoo(at.t) then
		if bite or big then table.insert(fx, gooTear(ctx, at, t0)) end
		chipSound(ctx, GSND.pop, P, 0.38, 2.2)
	else
		if not bite or big then
			table.insert(fx, R().chips(ctx, P + N * 0.1, N, big and 6 or 3, t0, big and 1.3 or 0.8))
			table.insert(fx, R().flash(ctx, P + N * 0.08, N, big and 1.15 or 0.6, t0, big and 7 or 5))
		end
		chipSound(ctx, SND.glass, P, big and 0.8 or 0.43, big and 1.6 or 2.3)
	end
	return group(fx)
end

-- ---------- CRACKED (5): one amber fissure network on the target once 6+ Pebbles chip it ----------
local CHIPPERS = {}                                                 -- target -> { pebs = { [peb] = at }, n, net }
local crackLoop
local function crackNet(t)
	local set = POINTS[t:GetAttribute("FormName") or ""]
	local e = CHIPPERS[t]
	if not set or not e then return nil end
	local cf = t:GetPivot()
	-- (Pebble audit r2: on the Colossus the network sat on the inner leg, mostly hidden. Now it climbs ONE outward face: from
	-- the chipping Pebble whose contact faces out the most (its normal along its own radial), 0.5-3.3 above it, within
	-- 1.3 sideways of that column, on surface points facing the same way; the lowest first, so it grows up the leg)
	local best, bs
	for _, at in e.pebs do
		local P, N = surfaceNow(at)
		local radial = (P - cf.Position) * Vector3.new(1, 0, 1)
		local sc = (radial.Magnitude > 0.1) and (N * Vector3.new(1, 0, 1)).Unit:Dot(radial.Unit) or -1
		-- (and in the open: every point of the target itself standing in front of that column (within 2.5 out along its
		-- normal, 1.3 sideways, 0.5-3.3 up: a Colossus's hanging fist hid it, measured) costs 0.15)
		local lp, ln = cf:PointToObjectSpace(P), cf:VectorToObjectSpace(N * Vector3.new(1, 0, 1)).Unit
		for _, list in { set.wall, set.top } do
			for _, q in list do
				local d = Vector3.new(q[1], q[2], q[3]) - lp
				local along = d:Dot(ln)
				if along > 0.3 and along < 2.5 and (d - ln * along - Vector3.new(0, d.Y, 0)).Magnitude < 1.3 and d.Y > 0.5 and d.Y < 3.3 then sc -= 0.15 end
			end
		end
		if not bs or sc > bs then best, bs = { P = cf:PointToObjectSpace(P), N = cf:VectorToObjectSpace(N) }, sc end
	end
	if not best then return nil end
	local pts = {}
	for _, list in { set.wall, set.low, set.top } do
		for _, p in list do
			local v = Vector3.new(p[1], p[2], p[3])
			local d = (v - best.P) * Vector3.new(1, 0, 1)
			local n = Vector3.new(p[4], p[5], p[6])
			if d.Magnitude < 1.3 and v.Y > best.P.Y + 0.5 and v.Y < best.P.Y + 3.3 and n:Dot(best.N) > 0.2 then table.insert(pts, p) end
		end
	end
	if #pts < 3 then                                                  -- (too few on that face: the nearest points, as before)
		for _, list in { set.wall, set.low } do for _, p in list do table.insert(pts, p) end end
		local c = best.P + Vector3.new(0, 1.2, 0)
		table.sort(pts, function(a, b) return (Vector3.new(a[1], a[2], a[3]) - c).Magnitude < (Vector3.new(b[1], b[2], b[3]) - c).Magnitude end)
	else
		table.sort(pts, function(a, b) return a[2] < b[2] end)
	end
	-- (r2 check: the Pebbles themselves (1.6 tall) hid a network at their own height: it starts 0.5 over their contact and
	-- climbs to 3.3, where the camera sees it over them)
	local used = {}
	for i = 1, math.min(9, #pts) do table.insert(used, pts[i]) end
	-- (Pebble audit r1: on the Colossus its own amber cracks hid ours: there, orange #FF6B18, 0.15 / 0.09 wide, a dark line
	-- 0.14 wider, a +50 % first pulse)
	local colossus = (t:GetAttribute("FormName") == "CrunchF4")
	local col = colossus and C3(255, 107, 24) or C3(255, 156, 32)
	-- a branching tree: each point joins its nearest earlier point
	local segs = {}
	for i = 2, #used do
		local a = Vector3.new(used[i][1], used[i][2], used[i][3])
		local best, bd
		for j = 1, i - 1 do local b = Vector3.new(used[j][1], used[j][2], used[j][3]); local d = (a - b).Magnitude; if not bd or d < bd then best, bd = j, d end end
		if bd and bd < 2.6 then
			local na, nb = Vector3.new(used[i][4], used[i][5], used[i][6]), Vector3.new(used[best][4], used[best][5], used[best][6])
			local ma = mkAt(t, cf, cf * a, cf:VectorToWorldSpace(na).Unit, Vector3.xAxis)
			local mb = mkAt(t, cf, cf * Vector3.new(used[best][1], used[best][2], used[best][3]), cf:VectorToWorldSpace(nb).Unit, Vector3.xAxis)
			local under = part({ holder = t }, { Material = Enum.Material.SmoothPlastic, Color = C3(40, 32, 27), Transparency = 1, Size = Vector3.one * 0.1 })
			local line = part({ holder = t }, { Material = Enum.Material.Neon, Color = col, Transparency = 1, Size = Vector3.one * 0.1 })
			under.Parent, line.Parent = workspace:FindFirstChild("GooShields") or workspace, workspace:FindFirstChild("GooShields") or workspace
			table.insert(segs, { a = ma, b = mb, under = under, line = line, w = colossus and ((best == 1) and 0.15 or 0.09) or ((best == 1) and 0.09 or 0.055),
				uw = colossus and 0.14 or 0.06, delay = (i / #used) * 0.3 })
		end
	end
	return { segs = segs, born = os.clock(), pulse0 = colossus and 0.5 or 0.3 }
end
local function chipperSet(target, peb, at)
	if not target then return end
	local e = CHIPPERS[target] or { pebs = {}, n = 0 }
	CHIPPERS[target] = e
	if at and not e.pebs[peb] then e.pebs[peb] = at; e.n += 1
	elseif not at and e.pebs[peb] then e.pebs[peb] = nil; e.n -= 1 end
	if crackLoop then return end
	crackLoop = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for tg, g in CHIPPERS do
			for pb in g.pebs do if not pb.Parent then g.pebs[pb] = nil; g.n -= 1 end end
			local function kill() if g.net then for _, s in g.net.segs do s.under:Destroy(); s.line:Destroy() end; g.net = nil end end
			if not tg.Parent then kill(); CHIPPERS[tg] = nil; continue end
			tg:SetAttribute("CrackedN", g.n)
			local dt = now - (g.lastT or now); g.lastT = now
			if g.n >= 6 and not g.net then g.net = crackNet(tg); g.fade = 0 end
			local net = g.net
			if net then
				g.fade = math.clamp((g.fade or 0) + ((g.n < 6) and dt / 0.30 or -dt / 0.12), 0, 1)
				local e0 = now - net.born
				for _, s in net.segs do
					local pa, na = surfaceNow(s.a)
					local pb2, nb = surfaceNow(s.b)
					local grow = smooth((e0 - s.delay) / 0.12)
					local tip = pa:Lerp(pb2, grow)
					local n = (na + nb).Unit
					local len = (tip - pa).Magnitude
					if len < 0.02 then s.line.Transparency = 1; s.under.Transparency = 1
					else
						local mid = (pa + tip) / 2 + n * 0.03
						s.line.Size = Vector3.new(s.w, 0.03, len); s.line.CFrame = CFrame.lookAt(mid, mid + (tip - pa), n)
						s.under.Size = Vector3.new(s.w + s.uw, 0.025, len + 0.04); s.under.CFrame = s.line.CFrame - n * 0.012
						local pul = (e0 < 0.45) and net.pulse0 * sin(math.min(1, e0 / 0.45) * pi) or 0.12 * sin(now * 2 * pi / 1.2)
						s.line.Transparency = math.clamp(0.05 - pul + g.fade, 0, 1); s.under.Transparency = math.clamp(0.3 + g.fade, 0, 1)
					end
				end
				if g.fade >= 1 and g.n < 6 then kill() end
			end
			if g.n <= 0 and not g.net then CHIPPERS[tg] = nil end
		end
		if next(CHIPPERS) == nil then crackLoop:Disconnect(); crackLoop = nil end
	end)
end

-- ===================== CHIP (passive): run to its spot at the big one's foot, brace, horn jab, mandible bite, repeat ===
-- MOVE TEST timeline: 0.00-0.50 skitter in, then 4 cycles of 0.96 (spec 4A, offset by 0.50): brace 0.12-0.22, draw back
-- 0.32, HORN JAB 0.40, recoil 0.50, bite wind 0.59, BITE 0.65, back off 0.78; 0.50 + 3.84 = 4.34, then 0.40 back out
local CHIP_T0, CHIP_CYC, CHIP_N = 0.50, 0.96, 4
local CHIP_ROWS = {
	{ 0.00, "smooth" },
	{ 0.12, "smooth", B = { -5, 0, 0, 0, -0.08 }, H = { 8, 0, 0 } },
	{ 0.22, "out", B = { -8, 0, 0, 0, -0.15 }, H = { 14, 0, 0, 0, 0, 0.06 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	{ 0.32, "smooth", B = { 4, 0, 0, 0, -0.10 }, H = { 20, 0, 0, 0, 0, 0.10 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	{ 0.40, "in", B = { -7, 0, 0, 0, -0.06 }, H = { -9, 0, 0, 0, 0, -0.18 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	{ 0.50, "out", B = { 3, 0, 0, 0, -0.08 }, H = { 12, 0, 0, 0, 0, 0.04 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	-- (the BITE, refit to the real rig (measured): its mandibles sit 0.30 over the ground under a horn 1.06 higher and 0.39
	-- further out, so the spec's head-down bite (rx -17) put the mouth into the ground. Head UP 16-24 brings the mouth level
	-- with the horn tip (both 1.33 ahead of the head joint): it rears and chomps forward under its horn)
	{ 0.59, "smooth", B = { -3, 0, 0, 0, -0.10 }, H = { 24, 0, 0, 0, 0, 0.06 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	-- (audit r1 check: the mouth still needed a steady 0.44-0.51 forward at the bite (8 Pebbles): body in 0.22, head out 0.47;
	-- the legs take back the body's slide, see pebKeys)
	{ 0.65, "in", B = { -4, 0, 0, 0, -0.12, -0.22 }, H = { 16, 0, 0, 0, 0, -0.47 }, legs = { ["1"] = { -11, 0, 3, 12 }, ["3"] = { 10, 0, 3, -8 } } },
	{ 0.78, "out", B = { 0, 0, 0, 0, 0.03 }, H = { 8, 0, 0 } },
	{ 0.96, "smooth" },
}
local function chipRows()
	local rows = { { 0.00, "smooth" }, { CHIP_T0, "smooth" } }
	for c = 0, CHIP_N - 1 do
		for i = 2, #CHIP_ROWS do
			local r = table.clone(CHIP_ROWS[i])
			r[1] = CHIP_T0 + c * CHIP_CYC + r[1]
			table.insert(rows, r)
		end
	end
	table.insert(rows, { CHIP_T0 + CHIP_N * CHIP_CYC + 0.40, "smooth" })
	return rows
end
local function chipPhase(t) local c = t - CHIP_T0; if c < 0 or c >= CHIP_N * CHIP_CYC then return nil end; return c % CHIP_CYC end
A.Chip = {
	boneKeys = true, dur = CHIP_T0 + CHIP_N * CHIP_CYC + 0.40, lock = CHIP_T0 + CHIP_N * CHIP_CYC + 0.40,
	keys = pebKeys(chipRows()),
	extra = function(t, p, ctx)
		local endT = CHIP_T0 + CHIP_N * CHIP_CYC
		skitter(p, t, (t < CHIP_T0) and 1 - smooth((t - 0.38) / 0.12) or smooth((t - endT) / 0.1))
		local sp = ctx and ctx.chip
		if sp and sp.aim ~= 0 then
			local H = p.bones.Head or { 0, 0, 0, 0, 0, 0 }
			H[1] += sp.aim * smooth((t - CHIP_T0 + 0.2) / 0.2) * (1 - smooth((t - endT) / 0.3))
			p.bones.Head = H
		end
	end,
	place = function(ctx, t)
		local sp = ctx.chip
		if not sp or not sp.at.t.Parent then return nil end
		local S = standNow(ctx, sp)
		local endT = CHIP_T0 + CHIP_N * CHIP_CYC
		local a0 = sp.found or 0                                                  -- (found late: it runs in from then)
		if t < a0 + 0.5 then return (sp.from or ctx.base):Lerp(S, smooth((t - a0) / 0.5)) end
		if t > endT then return S:Lerp(ctx.base, smooth((t - endT) / 0.40)) end
		local ph = chipPhase(t) or 0
		-- (the visual push: forward 0.10 into the jab, back 0.12 on the back-off; then the horn / mouth pulled on)
		local fwd = 0.10 * math.max(0, 1 - math.abs(ph - 0.40) / 0.12) - 0.12 * math.max(0, 1 - math.abs(ph - 0.78) / 0.15)
		return S + S.LookVector * fwd
	end,
	-- (after the pose: the horn tip pulled onto the point at the jab, the mandibles onto the surface plane at the bite)
	settle = function(ctx, t)
		local sp = ctx.chip
		local ph = chipPhase(t)
		if not sp or not ph or not sp.at.t.Parent then return nil end
		local P, N = surfaceNow(sp.at)
		local F = ctx.m:GetPivot()
		local wJ = math.max(0, 1 - math.abs(ph - 0.40) / 0.08)
		local wB = math.max(0, 1 - math.abs(ph - 0.65) / 0.08)
		if wJ > 0 then F = onTarget(ctx, F, HORN, "Head", P, N, wJ, nil, sp, "h") end
		local bP = biteTarget(ctx, F, P, N)
		if wB > 0 then F = onTarget(ctx, F, MAND, "Head", bP - N * 0.03, N, wB, nil, sp, "b") end
		if ctx.m:GetAttribute("FreezeTT") then
			-- (test readout: the jab / bite targets; the test reads the horn / mandible after the frame lands)
			ctx.m:SetAttribute("HitP", P + N * 0.03); ctx.m:SetAttribute("BiteP", bP)
		end
		return F
	end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.chip = nil
			local me = ctx.m
			local function find()
				local tg = standIn(ctx)
				if tg then ctx.chip = groundSpot(ctx, tg, me:GetAttribute("Slot") or 0) end
			end
			find()
			local reg = false
			return { step = function(_, t)
				-- (its target moved under it, at any time (audit r1 check: on a Titan / a Colossus the first Pebble's point ended
				-- 2.1 over its horn): drop the spot and pick again, running in from where it stands)
				if ctx.chip and not spotOk(ctx, ctx.chip) then
					if reg then reg = false; chipperSet(ctx.chip.at.t, me, nil) end
					unclaim(ctx.chip.at.t, me); ctx.chip = nil
				end
				if not ctx.chip and t < CHIP_T0 + CHIP_N * CHIP_CYC then find(); if ctx.chip then ctx.chip.found = math.max(0, t - 0.05); ctx.chip.from = me:GetPivot() end end   -- (the target may stream in late)
				me:SetAttribute("StuckTo", ctx.chip and ctx.chip.at.t.Name or "NONE")
				if ctx.chip and t >= CHIP_T0 and t < CHIP_T0 + CHIP_N * CHIP_CYC and not reg then reg = true; chipperSet(ctx.chip.at.t, me, ctx.chip.at) end
				if reg and t >= CHIP_T0 + CHIP_N * CHIP_CYC then reg = false; chipperSet(ctx.chip.at.t, me, nil) end
				return t <= A.Chip.dur
			end, stop = function() if reg and ctx.chip then chipperSet(ctx.chip.at.t, me, nil) end; unclaim(ctx.chip and ctx.chip.at.t, me) end }
		end },
		{ t = 0.05, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.2, 2.4, 0.3) end },        -- (skitter ticks)
	},
}
for c = 0, CHIP_N - 1 do
	local T = CHIP_T0 + c * CHIP_CYC
	table.insert(A.Chip.events, { t = T + 0.40, fn = function(ctx) if ctx.chip then return contactFx(ctx, ctx.chip.at, T + 0.40, false, false) end end })
	table.insert(A.Chip.events, { t = T + 0.65, fn = function(ctx)
		if not ctx.chip then return end
		-- (the bite: its own lower point on the same surface, for the goo tear)
		local at = ctx.chip.at
		local low = { t = at.t, anc = function() return CFrame.new(0, -0.55, 0) * at.anc() end, lp = at.lp, ln = at.ln, mode = at.mode, out = at.out }   -- (0.55 lower, in the world)
		return contactFx(ctx, low, T + 0.65, false, true)
	end })
end

-- ---------- the stone ball: the rig hidden, the ball shown (CURL UP, ROLL OUT) ----------
-- ballOn(ctx, tIn, tOut): rig hidden + ball visible tIn..tOut with 0.05 s overlaps; ball(F) places it (centre 1.23 up)
local BALL = Vector3.new(2.90, 2.45, 2.95)
local function ballSwap(ctx, tIn, tOut, placeFn)
	local ball = gm(ctx, "pebbleBall", 0, BALL, CFrame.new())
	local parts, was = {}, {}
	for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(parts, d); was[d] = d.LocalTransparencyModifier end end
	if ball then ball.Transparency = 1 end
	return { step = function(_, t)
		if t > tOut + 0.08 then return false end
		local on = math.min(smooth((t - tIn) / 0.05), 1 - smooth((t - tOut) / 0.05))
		for _, d in parts do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], on) end end
		if ball then
			local cf = placeFn(t)
			if cf then ball.CFrame = cf end
			ball.Transparency = 1 - on
		end
		return true
	end, stop = function() if ball then ball:Destroy() end; for _, d in parts do if d.Parent then d.LocalTransparencyModifier = was[d] end end end, ball = ball }
end

-- ===================== CURL UP (auto, vs a Titan's hit): tuck into the ball, the hit bounces off, uncurl ===================
-- MOVE TEST: the hit at tHit = 0.55 (the server's in a match). 0.10 tuck, 0.18 deep, 0.23 ball, tHit bounce (<= 6 deg
-- wobble), tHit + 0.24 uncurl, + 0.38 legs down, + 0.48 shake, + 0.56 ready
local CURL_HIT = 0.55
A.Curl = {
	boneKeys = true, dur = CURL_HIT + 0.56, lock = CURL_HIT + 0.56,
	keys = pebKeys({
		{ 0.00, "smooth", B = { 3, 0, 0, 0, -0.04 }, H = { 12, 0, 0 } },
		{ 0.10, "in", B = { -9, 0, 0, 0, -0.16 }, H = { -22, 0, 0, 0, 0, 0.12 }, legs = { ["1"] = { 0, 0, -25, 25 }, ["2"] = { 0, 0, -25, 25 }, ["3"] = { 0, 0, -25, 25 } } },
		{ 0.18, "in", B = { -18, 0, 0, 0, -0.22 }, H = { -38, 0, 0 }, legs = { ["1"] = { 0, 0, -40, 35 }, ["2"] = { 0, 0, -40, 35 }, ["3"] = { 0, 0, -40, 35 } } },
		{ CURL_HIT + 0.24, "smooth", B = { -12, 0, 0, 0, -0.18 }, H = { -20, 0, 0 }, legs = { ["1"] = { 0, 0, -30, 25 }, ["2"] = { 0, 0, -35, 30 }, ["3"] = { 0, 0, -35, 30 } } },
		{ CURL_HIT + 0.38, "out", B = { 0, 0, 0, 0, -0.10 }, H = { 10, 0, 0 } },
		{ CURL_HIT + 0.44, "smooth", B = { 0, 0, 7 }, H = { 0, -8, 0 } },
		{ CURL_HIT + 0.50, "smooth", B = { 0, 0, -5 }, H = { 0, 6, 0 } },
		{ CURL_HIT + 0.56, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.4, 1.9, 0.2) end },           -- (gritty tightening)
		{ t = 0.18, fn = function(ctx)
			local g = R().groundAt(ctx, ctx.base.Position)
			return ballSwap(ctx, 0.20, CURL_HIT + 0.26, function(t)
				local wob = (t > CURL_HIT and t < CURL_HIT + 0.12) and math.rad(6) * sin((t - CURL_HIT) / 0.12 * pi) or 0
				return CFrame.new(g + Vector3.new(0, BALL.Y / 2 + 0.04, 0)) * ctx.base.Rotation * CFrame.Angles(wob, 0, 0)
			end)
		end },
		-- the hit lands and BOUNCES OFF (K5). Pebble audit r1: the 3.4 deflection ring sits ON the ball where the blow lands
		-- (0.04 out, facing the blow: here from the front and above, the test hit), a 0.45 crystal flash there, and a
		-- separate horizontal dust ring on the ground (+0.04)
		{ t = CURL_HIT, fn = function(ctx)
			local g = R().groundAt(ctx, ctx.base.Position)
			local centre = g + Vector3.new(0, BALL.Y / 2 + 0.04, 0)
			local hn = (ctx.hitFrom and (ctx.hitFrom - centre).Unit) or (ctx.base.LookVector + Vector3.new(0, 1.3, 0)).Unit
			local at = centre + hn * (BALL.Y / 2 + 0.04)
			ctx.sound(SND.glass, at, 0.72, 1.3)
			ctx.sound(SND.shale, at, 0.4, 1.8)
			sparks(ctx, at, 3, 6)
			local fx = { R().flash(ctx, at, hn, 0.45, CURL_HIT, 6) }
			local ring = gm(ctx, "ring", 1, Vector3.new(3.4, 0.08, 3.4), CFrame.new(at))
			local dustRing = gm(ctx, "ring", 1, Vector3.new(3.0, 0.06, 3.0), CFrame.new(g + Vector3.new(0, 0.04, 0)))
			if ring then for _, c in ring:GetChildren() do c:Destroy() end; ring.Material, ring.Color = Enum.Material.Neon, C3(255, 214, 140) end
			if dustRing then for _, c in dustRing:GetChildren() do c:Destroy() end; dustRing.Material, dustRing.Color = Enum.Material.SmoothPlastic, C3(120, 108, 96) end
			local face = CFrame.lookAt(at, at + hn) * CFrame.Angles(-pi / 2, 0, 0)          -- (the ring's flat face across the blow)
			table.insert(fx, { step = function(_, t)
				local e = t - CURL_HIT
				if e > 0.3 then return false end
				local sc = 0.45 + 0.55 * smooth(e / 0.10)
				if ring then ring.Size = Vector3.new(3.4 * sc, 0.08, 3.4 * sc); ring.CFrame = face; ring.Transparency = smooth((e - 0.08) / 0.20) end
				if dustRing then
					local d = 0.5 + 0.5 * smooth(e / 0.2)
					dustRing.Size = Vector3.new(3.0 * d, 0.06, 3.0 * d); dustRing.CFrame = CFrame.new(g + Vector3.new(0, 0.04, 0))
					dustRing.Transparency = 0.35 + 0.65 * smooth((e - 0.06) / 0.22)
				end
				return true
			end, stop = function() if ring then ring:Destroy() end; if dustRing then dustRing:Destroy() end end })
			return group(fx)
		end },
	},
}

-- ===================== ROLL OUT (ORDER, warn 0.55): curl, roll at the big one (35.2 studs/s), bounce open, BIG HORN JAB ===
-- MOVE TEST: it starts 17.6 studs off its spot (0.5 s of rolling): 0.00-0.55 warning ring + curl, 0.55-1.05 roll (spin =
-- distance / 1.23), 1.05-1.23 a 0.45 bounce, uncurl from 1.11, BIG JAB at tC = 1.23, land 1.48, chip pose 1.65
local ROLL_REL, ROLL_ARRIVE, ROLL_TC = 0.55, 1.05, 1.23
A.TEST_ROLL_DIST = 17.6
-- the bounce off the ground at the target (J3 4): up to 0.45 by tC - 0.16, landing at tC + 0.25
local function rollHop(t)
	local tp, tl = ROLL_TC - 0.16, ROLL_TC + 0.25
	if t <= ROLL_ARRIVE or t >= tl then return 0 end
	if t < tp then return 0.45 * sin(0.5 * pi * (t - ROLL_ARRIVE) / (tp - ROLL_ARRIVE)) end
	return 0.45 * cos(0.5 * pi * (t - tp) / (tl - tp))
end
A.Roll = {
	boneKeys = true, dur = ROLL_TC + 0.62, lock = ROLL_TC + 0.62,
	keys = pebKeys({
		{ 0.00, "smooth", B = { -4, 0, 0, 0, -0.06 }, H = { 9, 0, 0 } },
		{ 0.25, "smooth", B = { -9, 0, 0, 0, -0.14 }, H = { -12, 0, 0 }, legs = { ["1"] = { 0, 0, -15, 15 }, ["2"] = { 0, 0, -15, 15 }, ["3"] = { 0, 0, -15, 15 } } },
		{ 0.42, "in", B = { -17, 0, 0, 0, -0.22 }, H = { -32, 0, 0, 0, 0, 0.12 }, legs = { ["1"] = { 0, 0, -40, 35 }, ["2"] = { 0, 0, -40, 35 }, ["3"] = { 0, 0, -40, 35 } } },
		{ ROLL_TC - 0.07, "out", B = { -8, 0, 0 }, H = { -10, 0, 0 }, legs = { ["1"] = { -20, 0, -10, 10 }, ["2"] = { -10, 0, -10, 10 }, ["3"] = { 25, 0, -15, 10 } } },
		{ ROLL_TC - 0.02, "in", B = { -12, 0, 0 }, H = { -18, 0, 0, 0, 0, -0.16 }, legs = { ["1"] = { -20, 0, -5, 10 }, ["3"] = { 25, 0, -10, 10 } } },
		{ ROLL_TC + 0.12, "out", B = { 6, 0, 0 }, H = { 12, 0, 0 } },
		{ ROLL_TC + 0.25, "smooth", B = { -5, 0, 0, 0, -0.10 }, H = { 4, 0, 0 } },
		{ ROLL_TC + 0.42, "smooth", B = { -8, 0, 0, 0, -0.15 }, H = { 14, 0, 0, 0, 0, 0.06 } },
		{ ROLL_TC + 0.62, "smooth" },
	}),
	place = function(ctx, t)
		local sp = ctx.roll
		if not sp or not sp.at.t.Parent then return nil end
		local S = standNow(ctx, sp)
		local face = CFrame.lookAt(ctx.base.Position, ctx.base.Position + (S.Position - ctx.base.Position) * Vector3.new(1, 0, 1))
		if t < ROLL_REL then return ctx.base.Rotation:Lerp(face.Rotation, smooth(t / 0.25)) + ctx.base.Position end
		if t < ROLL_ARRIVE then return face.Rotation + ctx.base.Position:Lerp(S.Position, (t - ROLL_REL) / (ROLL_ARRIVE - ROLL_REL)) end
		return S + Vector3.new(0, rollHop(t), 0)
	end,
	settle = function(ctx, t)
		local sp = ctx.roll
		local w = math.max(0, 1 - math.abs(t - ROLL_TC) / 0.09)
		if not sp or w <= 0 or not sp.at.t.Parent then return nil end
		local P, N = surfaceNow(sp.at)
		if ctx.m:GetAttribute("FreezeTT") then ctx.m:SetAttribute("HitP", P + N * 0.03) end
		return onTarget(ctx, ctx.m:GetPivot(), HORN, "Head", P, N, w, 0.7)   -- (mid-bounce, in the air: it can shift more)
	end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.roll = nil
			local me = ctx.m
			local function find() local tg = standIn(ctx); if tg then ctx.roll = groundSpot(ctx, tg, me:GetAttribute("Slot") or 0) end end
			find()
			ctx.sound(SND.tumble, ctx.base.Position, 0.5, 1.5)                                       -- (rising gritty rattle)
			local g = R().groundAt(ctx, ctx.base.Position)
			local warn = R().ring(ctx, g, 1.2, 0, ROLL_REL, 12)
			return { step = function(_, t)
				if not ctx.roll and t < ROLL_REL then find() end
				me:SetAttribute("StuckTo", ctx.roll and ctx.roll.at.t.Name or "NONE")
				if warn and not warn:step(t) then warn:stop(); warn = nil end
				return t <= A.Roll.dur
			end, stop = function() if warn then warn:stop() end; unclaim(ctx.roll and ctx.roll.at.t, me) end }
		end },
		-- the ball: in 0.50-ROLL_TC-0.07, rolling 0.55-1.05 with a spin by distance (r 1.23), bounce + uncurl at the target
		{ t = 0.48, fn = function(ctx)
			local sp = ctx.roll
			if not sp then return end
			local S = standNow(ctx, sp)
			local from = ctx.base.Position
			local dir = (S.Position - from) * Vector3.new(1, 0, 1)
			local dist = dir.Magnitude
			dir = (dist > 0.1) and dir.Unit or ctx.base.LookVector
			local axis = Vector3.yAxis:Cross(dir)
			local fx = {}
			table.insert(fx, ballSwap(ctx, 0.50, ROLL_TC - 0.07, function(t)
				local s = (t < ROLL_REL) and 0 or math.min(dist, (t - ROLL_REL) / (ROLL_ARRIVE - ROLL_REL) * dist)
				local hop = rollHop(t)
				local p = from + dir * s
				local g = Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
				return CFrame.new(g + Vector3.new(0, BALL.Y / 2 + 0.04 + hop, 0)) * CFrame.fromAxisAngle(axis, s / 1.23) * CFrame.lookAt(Vector3.zero, dir).Rotation
			end))
			-- the trail (K4; audit r1 + r2): a ground-skimming dust ribbon (2.8 x 1.1 x 0.30, grey lobes, two 0.055 amber
			-- streaks) whose leading edge rides 0.10 behind the ball's ground contact; every 0.17 s it is left on the ground
			-- (fading within 0.40 s) and the next one takes over: 1 riding + at most 2 fading, a continuous trail
			local segs = {}
			for k = 1, 3 do
				local lob = gm(ctx, "puddle", k, Vector3.new(1.1, 0.30, 2.8), CFrame.new())
				if lob then for _, c in lob:GetChildren() do c:Destroy() end; lob.Material, lob.Color, lob.Transparency = Enum.Material.SmoothPlastic, C3(128, 118, 106), 1 end
				local st = {}
				for j = 1, 2 do st[j] = part(ctx, { Material = Enum.Material.Neon, Color = C3(255, 160, 50), Transparency = 1, Size = Vector3.new(0.055, 0.04, 2.2 - j * 0.4) }) end
				segs[k] = { lob = lob, st = st, t0 = ROLL_REL + (k - 1) * 0.17 }
			end
			local lastPuff = 0
			local function ballPos(t) return from + dir * math.min(dist, math.max(0, (t - ROLL_REL) / (ROLL_ARRIVE - ROLL_REL) * dist)) end
			local function put(sg, cf, a, as)
				if sg.lob then sg.lob.CFrame = cf; sg.lob.Transparency = a end
				for j, st in sg.st do st.CFrame = cf * CFrame.new((j - 1.5) * 0.36, 0.12, 0.1 * j); st.Transparency = as end
			end
			table.insert(fx, { step = function(_, t)
				if t > ROLL_ARRIVE + 0.45 then return false end
				for k, sg in segs do
					local tOff = math.min(sg.t0 + 0.17, ROLL_ARRIVE)
					if t < sg.t0 then put(sg, CFrame.new(), 1, 1)
					else
						local riding = t < tOff
						local p = ballPos(riding and t or tOff)
						local g = Vector3.new(p.X, ctx.ground(p.X, p.Z) + 0.06, p.Z)
						-- (its front edge 0.10 behind the ball's contact: the ribbon's centre 1.4 + 0.1 back)
						local c = g - dir * (BALL.Z / 2 * 0 + 1.5)
						local cf = CFrame.lookAt(c, c + dir)
						local e = riding and 0 or (t - tOff)
						put(sg, cf, 0.3 + 0.7 * smooth(e / 0.40), 0.15 + 0.85 * smooth(e / 0.35))
					end
				end
				local p = ballPos(t)
				if t > ROLL_REL and t < ROLL_ARRIVE and t - lastPuff > 0.12 then lastPuff = t; dust(ctx, Vector3.new(p.X, ctx.ground(p.X, p.Z) + 0.25, p.Z) - dir * 0.8, 1, 1.1) end
				return true
			end, stop = function() for _, sg in segs do if sg.lob then sg.lob:Destroy() end; for _, st in sg.st do st:Destroy() end end end })
			return group(fx)
		end },
		{ t = ROLL_REL, fn = function(ctx) ctx.sound(SND.avalanche, ctx.base.Position, 0.35, 2.2, 0.4) end },  -- (the rolling rumble)
		-- BIG HORN JAB (J3 5): 6 shards, the amber burst 1.15 wide, a dust puff, the louder crack
		{ t = ROLL_TC, fn = function(ctx)
			if not ctx.roll then return end
			local P = surfaceNow(ctx.roll.at)
			ctx.sound(SND.shale, P, 0.8, 1.7)
			dust(ctx, R().groundAt(ctx, P), 2, 1.4)
			return contactFx(ctx, ctx.roll.at, ROLL_TC, true, false)
		end },
	},
}

-- ===================== HURT (0.50, additive; keys for a hit on its LEFT (-X), pushing it toward +X) =====================
A.PebbleHurt = {
	boneKeys = true, dur = 0.50, additive = true, pushX = true,
	keys = pebKeys({
		{ 0.00, "smooth" },
		{ 0.06, "out", R = { 0, 0, 0, 0, -13 }, B = { 0, 0, -7, 0.10 }, H = { 0, 0, 5 } },
		{ 0.13, "out", R = { 0, 0, 0, 0, -20 }, B = { 0, 0, 0, 0.16, -0.06 }, H = { 0, 0, 9 } },
		{ 0.28, "smooth", R = { 0, 0, 0, 0, 8 }, B = { 0, 0, 4, -0.04 }, H = { 0, 0, -7 } },
		{ 0.39, "smooth", R = { 0, 0, 0, 0, -3 }, H = { 0, 0, 2 } },
		{ 0.50, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local p = ctx.base * Vector3.new((out:Dot(ctx.base.RightVector) > 0) and 1.25 or -1.25, 1.12, -0.2)
			ctx.sound(SND.tumble, p, 0.45, 2.6, 0.15)
			return R().chips(ctx, p, out, 3, 0.03, 0.7)
		end },
	},
}

-- ===================== DEFEAT (3.20, terminal): stunned, legs give way, shell cracks apart, rubble, ONE mote =================
A.PebbleDefeat = {
	boneKeys = true, dur = 3.20,
	keys = pebKeys({
		{ 0.00, "smooth", B = { 0, 0, 5 }, H = { -8, 0, 0 } },
		{ 0.25, "smooth", B = { 0, 0, -7, 0, -0.08 }, H = { -14, 0, 0 } },
		{ 0.55, "in", B = { -8, 0, 0, 0, -0.27 }, H = { -18, 0, 0 }, legs = { ["1"] = { 0, 0, -30, 30 }, ["2"] = { 0, 0, -30, 30 }, ["3"] = { 0, 0, -12, 10 } } },
		{ 0.90, "in", B = { -15, 0, 0, 0, -0.45 }, H = { -24, 0, 0 }, legs = { ["1"] = { 0, 0, -45, 40 }, ["2"] = { 0, 0, -45, 40 }, ["3"] = { 0, 0, -40, 35 } } },
		{ 3.20, "smooth", B = { -15, 0, 0, 0, -0.45 }, H = { -24, 0, 0 }, legs = { ["1"] = { 0, 0, -45, 40 }, ["2"] = { 0, 0, -45, 40 }, ["3"] = { 0, 0, -40, 35 } } },
	}),
	extra = function(t, p)
		local flick = (t < 1.2) and (0.6 + 0.4 * sin(t * 37) * sin(t * 13)) or 1
		p.glowMul = flick * (1 - smooth((t - 1.6) / 0.6))
	end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.defeatWas = {}
			ctx.castAt = os.clock()
			local replay = ctx.m:GetAttribute("MoveTest")
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then
					if replay then d.LocalTransparencyModifier = 0 end
					ctx.defeatWas[d] = d.LocalTransparencyModifier
				end
			end
		end },
		{ t = 0.55, fn = function(ctx) dust(ctx, R().groundAt(ctx, ctx.base.Position), 2, 1.4); ctx.sound(SND.tumble, ctx.base.Position, 0.4, 2.0) end },
		-- SHELL FRACTURE 1.20 (Pebble audit r1: no crossfade): the rig is gone by 1.27; 6 OPAQUE shell plates + 2 crystal
		-- pieces take its place at once and split apart (>= 0.15 on every seam by 1.35), break up and drop by 1.75, fade
		-- 1.75-1.95 as the rubble pile settles in; the rubble's glow is down to 15 % by 2.15
		{ t = 1.20, fn = function(ctx)
			ctx.sound(SND.shaleBig, ctx.base.Position, 0.55, 2.0)
			local g = R().groundAt(ctx, ctx.base.Position)
			local fx = {}
			local hidden, was, done = {}, ctx.defeatWas or {}, false
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); if was[d] == nil then was[d] = d.LocalTransparencyModifier end end end
			table.insert(fx, { step = function(_, t)
				if t >= 1.27 then done = true end
				local gone = smooth((t - 1.20) / 0.07)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], gone) end end
				return t <= 3.2
			end, stop = function() if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end end })
			-- the shell plates: 6 boulder pieces around the shell, pushed out along their own direction, then dropping
			local b, c = FXF and FXF:FindFirstChild("Boulder"), FXF and FXF:FindFirstChild("CrystalSpike")
			local plates = {}
			for i = 1, 8 do
				local tmpl = (i <= 6) and b or c
				local p = tmpl and claimFrag(tmpl:Clone())
				if p then
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					p.Size = (i <= 6) and Vector3.new(0.75, 0.42, 0.70) * (0.9 + 0.2 * ((i * 5) % 3) / 2) or Vector3.new(0.16, 0.48, 0.16)   -- (plates sized to the shell: 6 round it with gaps)
					if i > 6 then p.Color = AMBER end
					p.Parent = ctx.holder
					local a = (i <= 6) and i / 6 * 2 * pi or i / 8 * 2 * pi
					local dir = ctx.base.Rotation * Vector3.new(cos(a), 0.5, sin(a)).Unit
					p.Transparency = 1
					table.insert(plates, { p = p, o = g + ctx.base.Rotation * ((i <= 6) and Vector3.new(cos(i / 6 * 2 * pi) * 0.80, 0.45, sin(i / 6 * 2 * pi) * 0.85) or Vector3.new((i - 7.5) * 0.5, 0.75, -0.2)), dir = dir, out = 0.22 + 0.16 * (i % 3) / 2, drop = 0.15 + 0.3 * ((i * 7) % 5) / 4, rot = CFrame.Angles(math.rad(10 + i * 2), math.rad(i * 37), 0) })
				end
			end
			table.insert(fx, { step = function(_, t)
				local e = t - 1.27
				if t > 1.98 then for _, k in plates do k.p.Transparency = 1 end; return false end   -- (its group lives on: hide them here)
				for _, k in plates do
					local push = k.out * smooth(e / 0.08) + 0.25 * smooth((e - 0.08) / 0.40)       -- (split by 1.35, break up to 1.75)
					local fall = (k.drop + 0.35) * smooth((e - 0.08) / 0.40)
					k.p.CFrame = CFrame.new(k.o + k.dir * push - Vector3.new(0, fall, 0)) * k.rot * CFrame.Angles(math.max(0, e) * 1.6, 0, 0)
					k.p.Transparency = (e < 0) and 1 or smooth((t - 1.75) / 0.20)
				end
				return true
			end, stop = function() for _, k in plates do k.p:Destroy() end end })
			-- the rubble pile 2.7 x 0.45 x 2.8, in from 1.75, still at 3.20
			table.insert(fx, R().rubble(ctx, g, 2.7, 8, 3, 1.75, 3.6, 0.45, { 1.95, 2.15, 0.15 }))
			return group(fx)
		end },
		-- exactly ONE matter mote at 2.25, rising 1.55 over 0.85 s, gone by 3.20
		{ t = 2.25, fn = function(ctx)
			if ctx.moteAt == ctx.castAt and ctx.castAt then return end
			ctx.moteAt = ctx.castAt
			ctx.sound(SND.glass, ctx.base.Position, 0.42, 2.2, 0.6)
			return R().motes(ctx, R().groundAt(ctx, ctx.base.Position) + Vector3.new(0, 0.4, 0), 1, 2.25, 3.20, ctx.home, Vector3.new(0.22, 0.34, 0.18), 1.55)
		end },
	},
}
A.FOR.CrunchF1v5 = { Chip = A.Chip, Curl = A.Curl, Roll = A.Roll, Defeat = A.PebbleDefeat, Hurt = A.PebbleHurt }
for _, atk in { A.Chip, A.Curl, A.Roll, A.PebbleHurt, A.PebbleDefeat } do table.sort(atk.events, function(x, y) return x.t < y.t end) end
end

end
