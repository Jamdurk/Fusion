-- Alien Fusion: animation batches 6-7, the CRUNCH PINCER and RAM (and the rock effects the Pebble shares).
-- Built to their reference sheets (design/concepts/<pincer|ram>/attacks/: J1-J4 + K EFFECTS) and ChatGPT specs
-- (design/18-PINCER-..., design/19-RAM-...). Attacks calls this with its table A and its helpers E. Big effects are real
-- meshes (the Colossus's Boulder + CrystalSpike, scaled / tinted); particles only for sparks and dust, through the
-- shared budget (E.takeParticles). No lights, no camera shake.
return function(A, E)
local smooth, clamp01, part, pulse, ahead = E.smooth, E.clamp01, E.part, E.pulse, E.ahead
local dust, sparks, cracks, frag, claimFrag = E.dust, E.sparks, E.cracks, E.frag, E.claimFrag
local onGround, strip, edge, setT = E.onGround, E.strip, E.edge, E.setT
local AMBER, MAGMA, BASALT, W_AMBER, W_UNDER = E.AMBER, E.MAGMA, E.BASALT, E.W_AMBER, E.W_UNDER
local SND = E.SND
local sin, cos, pi = math.sin, math.cos, math.pi
local C3 = Color3.fromRGB
local FIRE_CORE = C3(255, 200, 90)

local function groundAt(ctx, p: Vector3) return Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z) end
local function group(list) return { step = function(_, t) local alive = false; for _, f in list do if f:step(t) then alive = true end end; return alive end,
	stop = function() for _, f in list do f:stop() end end } end
local function fx(ctx) return ctx.FX or game.ReplicatedStorage.AlienFusion:FindFirstChild("FX") end
-- a bone's REST frame in the world: its CFrame chain up to the mesh part. (Bone.WorldCFrame leaves out only the bone's
-- OWN Transform, not its parents': offsets taken from it drifted once an arm had turned, measured on the Pincer's guard)
local function restCF(b: Bone): CFrame
	local cf = b.CFrame
	local p = b.Parent
	while p and p:IsA("Bone") do cf = p.CFrame * cf; p = p.Parent end
	return ((p and p:IsA("BasePart")) and p.CFrame or CFrame.identity) * cf
end

-- ===== the shared rock effects (A.rock: the Pebble's block uses them too) =====
local R = {}
A.rock = R
-- CHIPS (K: chip sparks): small rock shards (Boulder, 0.12-0.30 of a stud) flung out of `pos` along `dir` on ballistic
-- arcs, landing and fading; a few sparks. n <= 6. t0 = the move time it happens
function R.chips(ctx, pos: Vector3, dir: Vector3, n, t0, scale)
	local tmpl = fx(ctx) and fx(ctx):FindFirstChild("Boulder")
	local out = {}
	scale = scale or 1
	if tmpl then
		for i = 1, n do
			local c = frag(tmpl)
			if not c then break end
			local s = (0.12 + math.random() * 0.18) * scale
			c.Size = tmpl.Size * (s / 4)
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			c.Parent = ctx.holder
			local a = (i / n) * 2 * pi
			local side = (math.abs(dir.Y) < 0.9) and dir:Cross(Vector3.yAxis).Unit or Vector3.xAxis
			local up = side:Cross(dir).Unit
			local v = (dir * (4 + math.random() * 3) + side * cos(a) * 3 + up * (2 + sin(a) * 2)) * scale
			local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			table.insert(out, { c = c, v = v, spin = spin })
		end
	end
	sparks(ctx, pos, math.min(4, n), 5 * scale)
	return { step = function(_, t)
		local e = t - t0
		if e > 0.9 then return false end
		for _, k in out do
			local p = pos + k.v * e + Vector3.new(0, -30 * e * e / 2, 0)
			local g = ctx.ground(p.X, p.Z) + k.c.Size.Y / 2
			if p.Y < g then p = Vector3.new(p.X, g, p.Z) end
			k.c.CFrame = CFrame.new(p) * k.spin * CFrame.Angles(e * 6, e * 4, 0)
			k.c.Transparency = smooth((e - 0.6) / 0.3)
		end
		return true
	end, stop = function() for _, k in out do k.c:Destroy() end end }
end
-- a FLASH: a short-lived bright crystal burst (a CrystalSpike star of n spikes) at pos, facing dir; 0.18 s
function R.flash(ctx, pos: Vector3, dir: Vector3, size, t0, n)
	local tmpl = fx(ctx) and fx(ctx):FindFirstChild("CrystalSpike")
	local spikes = {}
	n = n or 5
	if tmpl then
		for i = 1, n do
			local c = frag(tmpl)
			if not c then break end
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			c.Material, c.Color = Enum.Material.Neon, FIRE_CORE
			for _, ch in c:GetChildren() do ch:Destroy() end
			c.Transparency = 1
			c.Parent = ctx.holder
			spikes[i] = c
		end
	end
	local side = (math.abs(dir.Y) < 0.9) and dir:Cross(Vector3.yAxis).Unit or Vector3.xAxis
	local up = side:Cross(dir).Unit
	return { step = function(_, t)
		local e = t - t0
		if e > 0.22 then return false end
		if e < 0 then return true end
		local k = smooth(e / 0.06) * (1 - smooth((e - 0.08) / 0.14))
		for i, c in spikes do
			local a = i / #spikes * 2 * pi
			local d = (dir * 0.6 + side * cos(a) + up * sin(a)).Unit
			local len = size * (0.4 + 0.6 * k) * (0.7 + 0.3 * ((i % 2 == 0) and 1 or 0))
			c.Size = Vector3.new(0.18 * size, len, 0.18 * size)
			c.CFrame = CFrame.lookAt(pos + d * len / 2, pos + d * len) * CFrame.Angles(-pi / 2, 0, 0)
			c.Transparency = 1 - k
		end
		return true
	end, stop = function() for _, c in spikes do c:Destroy() end end }
end
-- RUBBLE (J4 defeat): a pile of n boulders (scaled to `size` studs across) with `crystals` crystal shards, settling in
-- from t0, then sinking 0.6 and fading over the last 0.5 s before tEnd
function R.rubble(ctx, centre: Vector3, size, n, crystals, t0, tEnd, maxH, dim)   -- (dim = { from, to, k }: the glow down to k)   -- (maxH: the pile's height cap, e.g. the Pebble's 0.45)
	local b, c = fx(ctx) and fx(ctx):FindFirstChild("Boulder"), fx(ctx) and fx(ctx):FindFirstChild("CrystalSpike")
	local bits = {}
	local function add(tmpl, s, glow)
		local p = tmpl and claimFrag(tmpl:Clone())
		if not p then return end
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
		p.Size = tmpl.Size * s
		if maxH then p.Size = Vector3.new(math.min(p.Size.X, size * 0.4), math.min(p.Size.Y, maxH), math.min(p.Size.Z, size * 0.4)) end
		if glow then p.Color = AMBER end
		p.Transparency = 1
		p.Parent = ctx.holder
		local a, rr = math.random() * 2 * pi, math.random() ^ 0.6 * size * 0.45
		local g = groundAt(ctx, centre + Vector3.new(cos(a) * rr, 0, sin(a) * rr))
		table.insert(bits, { p = p, g = g + Vector3.new(0, p.Size.Y * 0.3, 0), rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), d = math.random() * 0.25,
			sa = p:FindFirstChildWhichIsA("SurfaceAppearance"), c0 = p.Color, glow = glow, s0 = p:FindFirstChildWhichIsA("SurfaceAppearance") and p:FindFirstChildWhichIsA("SurfaceAppearance").Color })
	end
	for i = 1, n do add(b, (0.08 + math.random() * 0.1) * size / 2) end
	for i = 1, crystals do add(c, (0.08 + math.random() * 0.06) * size / 2, true) end
	return { step = function(_, t)
		local e = t - t0
		if t > tEnd then return false end
		if e < 0 then return true end
		for _, k in bits do
			local u = smooth((e - k.d) / 0.35)
			local sink = 0.6 * smooth((t - (tEnd - 0.5)) / 0.5)
			k.p.CFrame = CFrame.new(k.g + Vector3.new(0, 1.2 * (1 - u) - sink, 0)) * k.rot
			k.p.Transparency = (u <= 0) and 1 or smooth((t - (tEnd - 0.5)) / 0.5)
			if dim then
				-- (the glow dying: the crack map / crystal colour darkened to dim[3] of its brightness)
				local m = 1 - (1 - dim[3]) * smooth((t - dim[1]) / (dim[2] - dim[1]))
				if k.sa and k.s0 then k.sa.Color = Color3.new(k.s0.R * m, k.s0.G * m, k.s0.B * m) end
				if k.glow then k.p.Color = k.c0:Lerp(Color3.fromRGB(60, 40, 25), 1 - m) end
			end
		end
		return true
	end, stop = function() for _, k in bits do k.p:Destroy() end end }
end
-- MATTER MOTES: n amber motes (0.24 Neon balls + a short trail) rising 1.6 from `pos` over 0.85 s, spread 0.75 apart,
-- arcing toward `home` (or up), fading in the last 0.45 s before tEnd. Guarded by the caller (one set per defeat)
-- (Pebble audit r1: a faceted amber crystal (FX.CrystalSpike, `size` studs, default 0.22 x 0.34 x 0.18) with ONE faint
-- 0.65 tail, not a sphere; `rise` studs over 0.85 s (default 1.6))
function R.motes(ctx, pos: Vector3, n, t0, tEnd, home, size: Vector3?, rise, riseT, spread)
	local list = {}
	local side = ctx.base.RightVector
	for i = 1, n do
		local off = side * ((i - (n + 1) / 2) * (spread or 0.75))
		local tmpl = fx(ctx) and fx(ctx):FindFirstChild("CrystalSpike")
		local core
		if tmpl then
			core = tmpl:Clone()
			for _, ch in core:GetChildren() do ch:Destroy() end
			core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
			core.Material, core.Color, core.Transparency = Enum.Material.Neon, AMBER, 1
			core.Size = size or Vector3.new(0.22, 0.34, 0.18)
			core.Parent = ctx.holder
		else
			core = part(ctx, { Material = Enum.Material.Neon, Color = AMBER, Transparency = 1, Size = size or Vector3.new(0.22, 0.34, 0.18) })
		end
		local tail = part(ctx, { Material = Enum.Material.Neon, Color = MAGMA, Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.65) })
		list[i] = { core = core, tail = tail, start = pos + off, ph = i * 1.3 }
	end
	local toHome = home and ((home - pos) * Vector3.new(1, 0, 1)) or Vector3.zero
	toHome = (toHome.Magnitude > 0.1) and toHome.Unit or Vector3.zero
	return { step = function(_, t)
		local e = t - t0
		if t > tEnd then return false end
		if e < 0 then return true end
		for _, m in list do
			local u = smooth(e / (riseT or 0.85))
			local p = m.start + Vector3.new(0, (rise or 1.6) * u, 0) + toHome * 1.5 * smooth((e - 0.6) / 0.8) + ctx.base.RightVector * 0.12 * sin(e * 4 + m.ph)
			local a = math.max(1 - smooth(e / 0.1), smooth((t - (tEnd - 0.45)) / 0.45))
			m.core.CFrame = CFrame.new(p) * CFrame.Angles(0, e * 2.4 + m.ph, 0); m.core.Transparency = a
			m.tail.CFrame = CFrame.lookAt(p - Vector3.new(0, 0.36, 0), p); m.tail.Transparency = 0.65 + 0.35 * a
		end
		return true
	end, stop = function() for _, m in list do m.core:Destroy(); m.tail:Destroy() end end }
end
-- STUN SWIRL (Ram K3): 3 little amber stars circling over a stunned unit's head for `dur`
function R.stun(ctx, unit: Model, t0, dur)
	local stars = {}
	for i = 1, 3 do stars[i] = part(ctx, { Material = Enum.Material.Neon, Color = C3(255, 215, 90), Transparency = 1, Size = Vector3.new(0.28, 0.28, 0.06) }) end
	return { step = function(_, t)
		local e = t - t0
		if e > dur then return false end
		if e < 0 or not unit.Parent then return true end
		local cf, sz = unit:GetBoundingBox()
		local top = cf.Position + Vector3.new(0, sz.Y / 2 + 0.4, 0)
		for i, s in stars do
			local a = e * 6 + i / 3 * 2 * pi
			s.CFrame = CFrame.new(top + Vector3.new(cos(a) * 0.7, 0.12 * sin(a * 2), sin(a) * 0.7)) * CFrame.Angles(0, -a, pi / 4)
			s.Transparency = math.max(1 - smooth(e / 0.08), smooth((e - (dur - 0.15)) / 0.15))
		end
		return true
	end, stop = function() for _, s in stars do s:Destroy() end end }
end
-- WARNING RING on the ground (Crunch language: straight segments, amber on a dark under-edge), radius r, n sides; shows
-- at tShow, fills + pulses toward tHit, gone at tHit
function R.ring(ctx, centre: Vector3, r, tShow, tHit, n)
	n = n or 16
	local lines = {}
	for i = 0, n - 1 do
		local a0, a1 = i / n * 2 * pi, (i + 1) / n * 2 * pi
		edge(ctx, lines, centre + Vector3.new(cos(a0) * r, 0, sin(a0) * r), centre + Vector3.new(cos(a1) * r, 0, sin(a1) * r), 0.22)
	end
	local W = tHit - tShow
	return { step = function(_, t)
		if t >= tHit then return false end
		if t < tShow then setT(lines, 1); return true end
		local fl = (t > tHit - 0.25 * W) and pulse(t, tHit - 0.25 * W, 2, 0.25 * W) or 0
		for i, p in lines do p.Transparency = (i % 2 == 1) and 0.25 or (0.05 - 0.05 * fl) end
		return true
	end, stop = function() for _, p in lines do p:Destroy() end end }
end
-- WARNING LANE (Ram J3): a rectangle from `from` along `dir`, len long, half-wide, outlined + chevrons running along it
function R.lane(ctx, from: Vector3, dir: Vector3, len, half, tShow, tHit)
	dir = (dir * Vector3.new(1, 0, 1)).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local lines, chev = {}, {}
	local a, b = from + side * half, from - side * half
	local c, d = a + dir * len, b + dir * len
	edge(ctx, lines, a, c, 0.30); edge(ctx, lines, b, d, 0.30); edge(ctx, lines, c, d, 0.30); edge(ctx, lines, a, b, 0.30)
	for i, p in lines do p.Color = (i % 2 == 1) and C3(40, 32, 27) or C3(255, 154, 33) end   -- (audit r1: amber, not yellow)
	for i = 1, 4 do
		local m = from + dir * (len * i / 5)
		table.insert(chev, strip(ctx, m - side * half * 0.6 - dir * 0.8, m, 0.16, W_AMBER))
		table.insert(chev, strip(ctx, m + side * half * 0.6 - dir * 0.8, m, 0.16, W_AMBER))
	end
	local fill = strip(ctx, from + dir * 0.01, from + dir * len, half * 2, C3(0, 0, 0), 0.03)
	fill.Material, fill.Color = Enum.Material.SmoothPlastic, C3(75, 40, 25)
	local W = tHit - tShow
	return { step = function(_, t)
		if t >= tHit then return false end
		if t < tShow then setT(lines, 1); setT(chev, 1); fill.Transparency = 1; return true end
		local fl = (t > tHit - 0.25 * W) and pulse(t, tHit - 0.25 * W, 2, 0.25 * W) or 0
		for i, p in lines do p.Transparency = (i % 2 == 1) and 0.25 or (0.05 - 0.05 * fl) end
		local run = ((t - tShow) / 0.5) % 1
		for i, p in chev do p.Transparency = 0.2 + 0.6 * ((math.ceil(i / 2) / 4 - run) % 1) end
		fill.Transparency = 0.75 - 0.15 * fl
		return true
	end, stop = function() for _, p in lines do p:Destroy() end; for _, p in chev do p:Destroy() end; fill:Destroy() end }
end
R.group, R.groundAt = group, groundAt

-- (the creature blocks are appended below by the batch-6 / batch-7 builds)
-- @@CRUNCH_FORMS@@

-- (AI TEST: an "ai" unit's foes are the living AI units hostile to it, its server target (AiTgt) first. Shared by the
-- Pincer's and the Ram's `do` blocks, so it lives out here: inside the Pincer's block the Ram's foes() saw nil, and every
-- Ram Charge / Gore / Stamp foe pick failed (found 29 Oct night))
local function isFoe(me: Model, u: Model, own)
	if me:GetAttribute("Mode") ~= "ai" then return u:GetAttribute("Owner") == own end
	if u:GetAttribute("Mode") ~= "ai" or (u:GetAttribute("Hp") or 1) <= 0 then return false end
	local a, b = me:GetAttribute("Team"), u:GetAttribute("Team")
	return a == "ALL" or b == "ALL" or a ~= b
end
local function aiFirst(me: Model, u: Model) return me:GetAttribute("Mode") == "ai" and u:GetAttribute("AiId") == me:GetAttribute("AiTgt") end

-- ===================== BATCH 6: the CRUNCH PINCER (spec design/18-PINCER-BATCH6-SPEC-chatgpt-raw.md) =====================
-- Built to its reference sheets (design/concepts/pincer/attacks/: J1 SCISSOR SNAP, J2 CLAW BLOCK, J3 SIDE SWEEP, J4 HURT +
-- DEFEAT, K EFFECTS). A low six-legged rock crab: Root -> Body; on Body: ArmL -> ClawL -> PinchL (the C-shaped crystal
-- claw stands in the FRONT plane; its fixed blade ends low and outside, the hinged pinch closes onto it), LegL1-3 ->
-- ShinL1-3; R mirrored (L = its left = -X). Contact points from its mesh (assets/blender/scripts/pincer_points.py,
-- Blender -> model space x = -bx, y = bz - 0.05, z = by): blade end / pinch tip L (-2.69, 0.81, -1.37) / (-2.35, 1.30,
-- -1.34), R mirrored (2.67, 0.76, -1.28) / (2.35, 1.30, -1.34); its six toes at x +-3.05, z -0.85 / 0.30 / 1.45.
-- FX meshes (assets/blender/scripts/pincer_fx.py, its own skin): pincerGuardL1 / R1 (the claw's faces pushed out 0.06),
-- pincerClawL1 / R1 (the real claws, detached), pincerRubble1, sweepRibbon1-3. The 3D importer turned them 180 deg about
-- Y: a part's rest place is pivot * (its centre) * yaw 180.
-- ============================================================================================================
do
-- (the baked meshes by their exact names in FX.GooMeshes)
local function meshT(name) local f = fx({}); local g = f and f:FindFirstChild("GooMeshes"); return g and g:FindFirstChild(name) end
local function tmplSize(name) local t = meshT(name); return t and t.Size end
local function gmN(ctx, name, size, cf)
	local t = meshT(name)
	if not t then return nil end
	local p = t:Clone()
	p.Size, p.CFrame = size, cf
	p.Parent = ctx.holder
	return p
end
local YAW180 = CFrame.Angles(0, pi, 0)
local CENTRE = {
	pincerGuardL = Vector3.new(-2.58, 2.162, -1.289), pincerGuardR = Vector3.new(2.574, 2.128, -1.349),
	pincerClawL = Vector3.new(-2.382, 2.161, -1.094), pincerClawR = Vector3.new(2.368, 2.128, -1.033),
	pincerRubble = Vector3.new(0.008, 0.475, 0.364),
	sweepRibbon1 = Vector3.new(-2.552, 1.65, -2.409), sweepRibbon2 = Vector3.new(0, 1.65, -3.647), sweepRibbon3 = Vector3.new(2.552, 1.65, -2.409),
}
local BLADE = { L = Vector3.new(-2.693, 0.807, -1.37), R = Vector3.new(2.671, 0.757, -1.283) }
local PINCH = { L = Vector3.new(-2.345, 1.297, -1.34), R = Vector3.new(2.345, 1.297, -1.34) }
local HIPS = {}
for _, s in { "L", "R" } do for i, z in { -0.30, 0.30, 0.90 } do HIPS[s .. i] = Vector3.new((s == "L") and -1.40 or 1.40, 0.05, z - 0.10) end end
-- (Body is the legs' parent: a body move / turn is undone at each leg (the inverse turn on the leg, and the hip's slide
-- back), so its six feet stay planted (spec 2.4 / 5.4); then the leg's own bend is added)
local function legCounter(B)
	local Rb = CFrame.Angles(math.rad(B[1] or 0), math.rad(B[2] or 0), math.rad(B[3] or 0))
	local ob = Vector3.new(B[4] or 0, B[5] or 0, B[6] or 0)
	local out = {}
	for name, h in HIPS do
		local o = Rb:Inverse() * (h - ob) - h
		out[name] = { -(B[1] or 0), -(B[2] or 0), -(B[3] or 0), o.X, o.Y, o.Z }
	end
	return out
end
-- keys: B Body {rx,ry,rz,ox,oy,oz}, R root, AL / AR / CL / CR arm and claw {rx,ry,rz}, PL / PR pinch rx, legs = { L1 = {rx, ry, rz}, ... } extra bend
local function pinKeys(rows)
	local keys = {}
	for i, r in rows do
		local B = r.B or { 0, 0, 0, 0, 0, 0 }
		local b = { Body = B, ArmL = r.AL or { 0, 0, 0 }, ArmR = r.AR or { 0, 0, 0 }, ClawL = r.CL or { 0, 0, 0 }, ClawR = r.CR or { 0, 0, 0 },
			PinchL = { r.PL or -12, 0, 0 }, PinchR = { r.PR or -12, 0, 0 } }
		local lc = legCounter(B)
		for name, v in lc do
			local add = r.legs and r.legs[name]
			b["Leg" .. name] = add and { v[1] + (add[1] or 0), v[2] + (add[2] or 0), v[3] + (add[3] or 0), v[4], v[5], v[6] } or v
			if add and add[4] then b["Shin" .. name] = { add[4], 0, 0 } end
		end
		for k, v in r.extra or {} do b[k] = v end
		local Rt = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { Rt[1] or 0, Rt[2] or 0, Rt[3] or 0, Rt[4] or 0, Rt[5] or 0, Rt[6] or 0 }, bones = b }
	end
	return keys
end
local EASE_SHARP = "in"                                         -- ("sharp" in the spec: the fast-in curve)
local function EIN(u) u = clamp01(u); return u * u * u end
local function bonePt(m, name, restModel)
	-- a mesh point carried by a bone: its rest place (model space) in the bone's rest frame, shown in the animated frame
	local b = m:FindFirstChild(name, true)
	if not b or not b:IsA("Bone") then return nil end
	local rel = restCF(b):PointToObjectSpace(m:GetPivot() * restModel)
	return function() return b.TransformedWorldCFrame * rel end, b
end
-- a little enemy's surface facing a point: its middle, 0.7 up, pulled toward `from` by its radius (half its width)
-- (yRef: the height the claw reaches; the point is kept within 0.2 of it (spec 2.3: clamped to the claw's reach))
local function surfaceOf(u: Model, from: Vector3, yRef: number?)
	local cf, size = u:GetBoundingBox()
	local c = cf.Position - Vector3.new(0, size.Y / 2, 0) + Vector3.new(0, math.min(1.2, size.Y * 0.45), 0)
	if yRef then c = Vector3.new(c.X, math.clamp(c.Y, yRef - 0.2, yRef + 0.2), c.Z) end
	local d = (from - c) * Vector3.new(1, 0, 1)
	d = (d.Magnitude > 0.05) and d.Unit or Vector3.zAxis
	return c + d * math.min(size.X, size.Z) * 0.42, d
end
local SMALL = { SquishF1v5 = true, CrunchF1v5 = true, SquishF2v5 = true, SquishF1 = true, CrunchF1 = true, SquishF2 = true }
-- the up-to-n nearest little ones in reach (MOVE TEST: this player's idle stand-ins)
local function littleOnes(ctx, reach, n)
	local units, own = ctx.m.Parent, ctx.m:GetAttribute("Owner")
	local list = {}
	for _, u in (units and units:GetChildren() or {}) do
		if u ~= ctx.m and u:IsA("Model") and u.PrimaryPart and isFoe(ctx.m, u, own) and SMALL[u:GetAttribute("FormName") or ""] then
			local d = ((u:GetPivot().Position - ctx.base.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d <= reach then table.insert(list, { u = u, d = aiFirst(ctx.m, u) and -1 or d }) end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local out = {}
	for i = 1, math.min(n, #list) do out[i] = list[i].u end
	return out
end
-- turn one bone (in its current animated pose) by the world rotation that carries `tip` toward `want` about the bone's
-- origin, at most maxDeg; returns the angle used
local function turnBone(bone: Bone, tip: Vector3, want: Vector3, maxDeg, w)
	local twc = bone.TransformedWorldCFrame
	local p = twc.Position
	local v1, v2 = tip - p, want - p
	if v1.Magnitude < 0.05 or v2.Magnitude < 0.05 then return 0 end
	local axis = v1:Cross(v2)
	if axis.Magnitude < 1e-5 then return 0 end
	local ang = math.acos(math.clamp(v1.Unit:Dot(v2.Unit), -1, 1))
	ang = math.min(ang, math.rad(maxDeg)) * w
	local rot = CFrame.fromAxisAngle(axis.Unit, ang)
	local newWorld = CFrame.new(p) * rot * (twc - p)
	local parent = bone.Parent
	local pw = (parent and parent:IsA("Bone")) and parent.TransformedWorldCFrame or (parent and parent:IsA("BasePart") and parent.CFrame) or CFrame.identity
	bone.Transform = (pw * bone.CFrame):Inverse() * newWorld
	return math.deg(ang)
end
-- THE LOWER JAW BLADE (audit r1: the rig's own lower jaw is a 0.4 block nested in the C and never opens, so the snap read
-- as a double punch). A crystal blade (the shared CrystalSpike, 0.16 thick) rides the Pinch bone, from the pinch joint to
-- the blade end of the C (0.99 long at rest: its tip ON the blade end = closed). The jaw angle (deg, about the claw's own
-- front axis) opens it: jawOpen(ctx, s, deg). PINCH_O = the Pinch joints (rest, model space)
local PINCH_O = { L = Vector3.new(-2.08, 1.59, -1.34), R = Vector3.new(1.98, 1.62, -1.41) }
local function jawBlade(ctx, s)
	local m = ctx.m
	local pin, claw = m:FindFirstChild("Pinch" .. s, true), m:FindFirstChild("Claw" .. s, true)
	local tmpl = fx(ctx) and fx(ctx):FindFirstChild("CrystalSpike")
	if not (pin and claw and tmpl) then return nil end
	local pv = m:GetPivot()
	local o, e = pv * PINCH_O[s], pv * BLADE[s]
	local L = (e - o).Magnitude
	local p = tmpl:Clone()
	for _, ch in p:GetChildren() do if not ch:IsA("SurfaceAppearance") then ch:Destroy() end end
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
	p.Material, p.Color = Enum.Material.Glass, C3(255, 178, 60)
	p.Size = Vector3.new(0.16, L, 0.22)
	p.Parent = ctx.holder
	local rest = CFrame.lookAt((o + e) / 2, e) * CFrame.Angles(-pi / 2, 0, 0)        -- (its long axis Y along the jaw)
	local pr, cr = restCF(pin), restCF(claw)
	return { p = p, pin = pin, claw = claw, off = pr:ToObjectSpace(rest),
		tipRel = pr:PointToObjectSpace(e), endRel = cr:PointToObjectSpace(e),
		oRel = cr:PointToObjectSpace(o), nRel = cr:VectorToObjectSpace(pv:VectorToWorldSpace(Vector3.zAxis)), L = L }
end
-- open the jaw to deg (0 = closed on the blade end): the BLADE turns about the pinch joint (in the claw's frame), not the
-- Pinch bone (PinchR carries a mis-weighted rock chunk at the body centre that swung out loose, measured); returns the gap
local function jawOpen(j, deg)
	if not j or not j.claw.Parent then return nil end
	local cw = j.claw.TransformedWorldCFrame
	local o, e = cw * j.oRel, cw * j.endRel
	local n = cw:VectorToWorldSpace(j.nRel)
	local tip = o + CFrame.fromAxisAngle(n, math.rad(deg)) * (e - o)
	j.p.CFrame = CFrame.lookAt((o + tip) / 2, tip) * CFrame.Angles(-pi / 2, 0, 0)
	return (tip - e).Magnitude
end
-- turn an arm (<= maxDeg) so a point it carries (its claw's bite centre / the guard centre) goes to a world point
local function armTo(armBone: Bone, pt: Vector3, want: Vector3, maxDeg, w)
	return turnBone(armBone, pt, want, maxDeg, w)
end
-- a snap burst (K1): the shared crystal star, 1.05 across, along the surface normal, on the curve of spec 8.3
local function snapBurst(ctx, pos, n, t0, scale)
	return A.rock.flash(ctx, pos, n, 1.05 * (scale or 1), t0, 7)
end

-- ===================== A. SCISSOR SNAP (passive, 1.00 s cycle, both claws close at 0.38 on two different little ones) ======
local SNAP_ROWS = {
	{ 0.00, "smooth" },
	{ 0.12, "out", B = { 3, 0, 0, 0, -0.08 }, AL = { 6, 0, -5 }, AR = { 6, 0, 5 }, CL = { 5, 0, 0 }, CR = { 5, 0, 0 }, PL = -25, PR = -25 },
	{ 0.27, "in", B = { 5, 0, 0, 0, -0.15 }, AL = { 11, 0, -8 }, AR = { 11, 0, 8 }, CL = { 12, 0, -4 }, CR = { 12, 0, 4 }, PL = -43, PR = -43 },
	{ 0.34, EASE_SHARP, B = { -2, 0, 0, 0, -0.04 }, AL = { -4, 0, -3 }, AR = { -4, 0, 3 }, CL = { -4, 0, 0 }, CR = { -4, 0, 0 }, PL = -24, PR = -24 },
	{ 0.38, EASE_SHARP, B = { -4, 0, 0, 0, 0.04 }, AL = { -9, 0, 0 }, AR = { -9, 0, 0 }, CL = { -10, 0, 0 }, CR = { -10, 0, 0 }, PL = 2, PR = 2 },
	{ 0.43, "smooth", B = { 0, 0, 0, 0, 0.02 }, AL = { -7, 0, 0 }, AR = { -7, 0, 0 }, CL = { -8, 0, 0 }, CR = { -8, 0, 0 }, PL = 2, PR = 2 },
	{ 0.56, "out", B = { 3, 0, 0, 0, -0.07 }, AL = { 4, 0, 0 }, AR = { 4, 0, 0 }, CL = { 5, 0, 0 }, CR = { 5, 0, 0 }, PL = -16, PR = -16 },
	{ 0.75, "smooth", B = { 0, 0, 0, 0, 0.02 } },
	{ 1.00, "smooth" },
}
-- the aim yaw for each claw (aL / aR, +-24 deg), worked into the arm keys: full from 0.27, half at 0.12 and 0.56
local AIMW = { [0.12] = 0.5, [0.27] = 1, [0.34] = 1, [0.38] = 1, [0.43] = 1, [0.56] = 0.5 }
local function snapKeys(aL, aR)
	local rows = {}
	for i, r in SNAP_ROWS do
		local c = table.clone(r)
		local w = AIMW[r[1]] or 0
		if c.AL then c.AL = { c.AL[1], aL * w, c.AL[3] } elseif w > 0 then c.AL = { 0, aL * w, 0 } end
		if c.AR then c.AR = { c.AR[1], aR * w, c.AR[3] } elseif w > 0 then c.AR = { 0, aR * w, 0 } end
		rows[i] = c
	end
	return pinKeys(rows)
end
A.Snap = {
	boneKeys = true, dur = 1.0, cycle = 1.0, lock = 0.58,
	keys = snapKeys(0, 0),
	events = {
		-- 0.00: pick up to two different little ones (left claw: the one most to its left), aim each claw (yaw of its bite
		-- centre toward its target, +-24 deg); the keys are rebuilt with those aims
		{ t = 0, fn = function(ctx)
			local m = ctx.m
			ctx.snap = { L = nil, R = nil }
			local list = littleOnes(ctx, 6.5, 2)
			table.sort(list, function(a, b) return ctx.base:PointToObjectSpace(a:GetPivot().Position).X < ctx.base:PointToObjectSpace(b:GetPivot().Position).X end)
			if #list == 1 then
				local x = ctx.base:PointToObjectSpace(list[1]:GetPivot().Position).X
				if x < 0 then ctx.snap.L = list[1] else ctx.snap.R = list[1] end
			else ctx.snap.L, ctx.snap.R = list[1], list[2] end
			local aims = {}
			for _, s in { "L", "R" } do
				local u = ctx.snap[s]
				aims[s] = 0
				if u then
					local arm = ctx.base * Vector3.new((s == "L") and -1.45 or 1.45, 1.45, -0.60)
					local mid = (BLADE[s] + PINCH[s]) / 2
					local restDir = ctx.base:VectorToWorldSpace(mid - Vector3.new((s == "L") and -1.45 or 1.45, 1.45, -0.60)) * Vector3.new(1, 0, 1)
					local want = (surfaceOf(u, arm) - arm) * Vector3.new(1, 0, 1)
					if restDir.Magnitude > 0.05 and want.Magnitude > 0.05 then
						local a = math.deg(math.atan2(restDir.Unit:Cross(want.Unit).Y, restDir.Unit:Dot(want.Unit)))
						aims[s] = math.clamp(a, -24, 24)
					end
				end
			end
			ctx.keys = snapKeys(aims.L, aims.R)
			ctx.jaws = nil
			m:SetAttribute("SnapAims", string.format("%.1f / %.1f", aims.L, aims.R))
			m:SetAttribute("SnapTargets", (ctx.snap.L and 1 or 0) + (ctx.snap.R and 1 or 0))
			ctx.sound(SND.tumble, ctx.base.Position, 0.35, 2.6, 0.2)                  -- (two-sided hinge creak, 0.10)
			-- (the jaw blades live for the cycle: made by the post solve, removed with this effect)
			return { step = function(_, t) return t < 0.999 end, stop = function()
				for _, J in ctx.jaws or {} do if J then J.p:Destroy() end end
				ctx.jaws = nil
			end }
		end },
		-- 0.38: both close at once; one burst per real contact, one composite clack per Pincer
		{ t = 0.38, fn = function(ctx)
			local fx = {}
			local any = false
			for _, s in { "L", "R" } do
				local u = ctx.snap and ctx.snap[s]
				if u and u.Parent then
					any = true
					local p, n = surfaceOf(u, ctx.m:GetPivot().Position)
					p = (ctx.snapHitAt and ctx.snapHitAt[s]) or p                    -- (where the claw actually closed)
					table.insert(fx, snapBurst(ctx, p, n, 0.38))
					sparks(ctx, p, 1, 4)
				end
			end
			if any then ctx.sound(SND.glass, ctx.base.Position, 0.85, 1.9) end
			ctx.sound(SND.tumble, ctx.base.Position, 0.25, 3.0, 0.1)                   -- (recoil reset)
			return group(fx)
		end },
	},
	-- after the pose: each claw is turned (<= 8 deg about its arm) so its bite centre lands on its target's surface over
	-- 0.27-0.38 (held to 0.43, out by 0.56)
	post = function(ctx, t, bones)
		local m = ctx.m
		ctx.snapPts = ctx.snapPts or {}
		for _, s in { "L", "R" } do
			local pp = ctx.snapPts[s]
			if not pp then
				local blade = bonePt(m, "Claw" .. s, BLADE[s])
				local pinch = bonePt(m, "Pinch" .. s, PINCH[s])
				pp = { blade = blade, pinch = pinch }
				ctx.snapPts[s] = pp
			end
			if not pp.blade or not pp.pinch then continue end
			local armE, pinE = bones["Arm" .. s], bones["Pinch" .. s]
			local u = ctx.snap and ctx.snap[s]
			local w = (t < 0.27) and smooth(t / 0.27) * 0.0 or (t < 0.38) and smooth((t - 0.27) / 0.11) or (t < 0.43) and 1 or (1 - smooth((t - 0.43) / 0.13))
			local turned = 0
			if u and u.Parent and armE and w > 0 then
				local bc = (pp.blade() + pp.pinch()) / 2
				local want = surfaceOf(u, bc, bc.Y)                              -- (r2: the face toward the claw itself)
				ctx.snapHitAt = ctx.snapHitAt or {}
				ctx.snapHitAt[s] = want
				turned = turnBone(armE.b, bc, want, 8, w)
				-- (then the claw itself, the final joint, <= 8 more (spec 2.3), from where the arm turn left the bite centre)
				local clawE = bones["Claw" .. s]
				if clawE then turned += turnBone(clawE.b, (pp.blade() + pp.pinch()) / 2, want, 8, w) end
				-- (audit r2: 0.28 / 0.22 left: a second small pass, arm then claw, inside the same per-joint 8-deg budget
				-- (8 total per joint across both passes: the first pass used what it needed, this one the rest))
				local used = turnBone(armE.b, (pp.blade() + pp.pinch()) / 2, want, math.max(0, 8 - math.min(8, turned)), w)
				turned += used
				if clawE then turned += turnBone(clawE.b, (pp.blade() + pp.pinch()) / 2, want, 4, w) end
			end
			-- (the jaw blade: open 0 -> 40 deg by 0.27 (the spec's pinch track, -43 = wide), shut to 0 (on the blade end) at 0.38)
			ctx.jaws = ctx.jaws or {}
			if not ctx.jaws[s] then ctx.jaws[s] = jawBlade(ctx, s) or false end
			local J = ctx.jaws[s]
			if J then
				local deg = (t < 0.12) and 11 + 12 * smooth(t / 0.12) or (t < 0.27) and 23 + 17 * smooth((t - 0.12) / 0.15)
					or (t < 0.34) and 40 - 18 * EIN((t - 0.27) / 0.07) or (t < 0.38) and 22 * (1 - EIN((t - 0.34) / 0.04))
					or (t < 0.43) and 0 or (t < 0.56) and 15 * smooth((t - 0.43) / 0.13) or 15 - 4 * smooth((t - 0.56) / 0.2)
				local gap = jawOpen(J, deg)
				if m:GetAttribute("FreezeTT") and gap then m:SetAttribute("Jaw" .. s, gap) end
			end
			if m:GetAttribute("FreezeTT") then
				local bc = (pp.blade() + pp.pinch()) / 2
				m:SetAttribute("Gap" .. s, (pp.pinch() - pp.blade()).Magnitude)
				m:SetAttribute("Turn" .. s, turned)
				if u and u.Parent then m:SetAttribute("Hit" .. s, (bc - surfaceOf(u, bc, bc.Y)).Magnitude) end
			end
		end
	end,
}

-- ===================== B. CLAW BLOCK (auto; guard up by 0.23, held, -30 % for 3.00 s, down by 3.55) =====================
-- (front stills, 29 Oct: this rig's C-claws stand at its SIDES (claw centres x +-2.4, shoulders +-1.45): the spec's guard
-- angles only raised them there, and yaw alone turned them face-on but left the face open. ROLL about the forward axis
-- carries each claw up and in over its shoulder (rz -55 left / +55 right: centre to about x -1.3, y 2.6), yaw 30 brings it
-- forward of the face)
A.Block = {
	-- (no lock: the animator blends a pose out after its lock, and the guard must hold the whole 3 s; "body free 0.36" is
	-- the server letting it move, the arms stay up)
	boneKeys = true, dur = 3.55,
	keys = pinKeys({
		{ 0.00, "smooth" },
		{ 0.10, "in", R = { 0, 0, 0, 2 }, B = { 0, 0, 0, 0, -0.08 }, AL = { 8, -15, -28 }, AR = { 8, 15, 28 }, CL = { 6, -8, 0 }, CR = { 6, 8, 0 }, PL = -8, PR = -8 },
		{ 0.23, EASE_SHARP, R = { 0, 0, 0, 4 }, B = { 0, 0, 0, 0, -0.15 }, AL = { 15, -30, -55 }, AR = { 15, 30, 55 }, CL = { 10, -15, 0 }, CR = { 10, 15, 0 }, PL = -3, PR = -3 },
		{ 0.36, "out", R = { 0, 0, 0, 2 }, B = { 0, 0, 0, 0, -0.08 }, AL = { 14, -28, -51 }, AR = { 14, 28, 51 }, CL = { 9, -14, 0 }, CR = { 9, 14, 0 }, PL = -3, PR = -3 },
		{ 1.60, "smooth", R = { 0, 0, 0, 2 }, B = { 0, 0, 0, 0, -0.10 }, AL = { 15, -29, -53 }, AR = { 15, 29, 53 }, CL = { 10, -14, 0 }, CR = { 10, 14, 0 }, PL = -3, PR = -3 },
		{ 3.22, "smooth", R = { 0, 0, 0, 2 }, B = { 0, 0, 0, 0, -0.08 }, AL = { 14, -28, -51 }, AR = { 14, 28, 51 }, CL = { 9, -14, 0 }, CR = { 9, 14, 0 }, PL = -3, PR = -3 },
		{ 3.36, "out", B = { 0, 0, 0, 0, -0.03 }, AL = { 6, -12, -20 }, AR = { 6, 12, 20 }, CL = { 4, -6, 0 }, CR = { 4, 6, 0 }, PL = -8, PR = -8 },
		{ 3.55, "smooth" },
	}),
	-- (audit r1: the C-rings still flanked the head. After the pose each arm is turned (<= 35 deg) so its claw's guard centre
	-- (the sheen part's rest centre, carried by the claw bone) sits at (+-1.00, 2.45, -2.05): forward of the eyes, a 0.4 gap)
	post = function(ctx, t, bones)
		local m = ctx.m
		local w = smooth(t / 0.23) * (1 - smooth((t - 3.23) / 0.32))
		if w <= 0 then return end
		ctx.guardPts = ctx.guardPts or {}
		for _, s in { "L", "R" } do
			local claw = m:FindFirstChild("Claw" .. s, true)
			local armE = bones["Arm" .. s]
			if claw and armE then
				local gp = ctx.guardPts[s]
				if not gp then gp = restCF(claw):PointToObjectSpace(m:GetPivot() * CENTRE["pincerGuard" .. s]); ctx.guardPts[s] = gp end
				-- (audit r2: both eyes must show: the C-rings are 2.3 wide, so centres at +-1.40 leave a 0.5 gap between their inner
				-- edges in front of the eyes (measured: at +-1.20 they met in the middle))
				local want = ctx.base * Vector3.new((s == "L") and -1.40 or 1.40, 2.60, -2.05)
				armTo(armE.b, claw.TransformedWorldCFrame * gp, want, 50, w)
				if m:GetAttribute("FreezeTT") then
					local c = ctx.base:PointToObjectSpace(claw.TransformedWorldCFrame * gp)
					m:SetAttribute("Guard" .. s, string.format("%.2f, %.2f, %.2f", c.X, c.Y, c.Z))
				end
			end
		end
	end,
	extra = function(t, p)
		-- (a small 1-2 deg breathing in the held guard)
		if t > 0.36 and t < 3.22 then
			local b = sin((t - 0.36) * 2 * pi / 1.4) * 1.5
			for _, n in { "ArmL", "ArmR" } do local v = p.bones[n]; if v then v[1] += b end end
		end
	end,
	events = {
		{ t = 0.08, fn = function(ctx) ctx.sound(SND.shale, ctx.base.Position, 0.7, 1.4, 0.05) end },        -- (stone plates lock)
		-- 0.23: the amber sheen on both raised claws (K2): their own faces pushed out 0.06, riding the claw bones;
		-- 0 -> 0.25 by 0.31, 0.18-0.28 held, out 3.23-3.35. Test hits on the guard every 0.8 s (a 0.55 snap burst + 1 spark)
		{ t = 0.23, fn = function(ctx)
			local m = ctx.m
			local sheens = {}
			for _, s in { "L", "R" } do
				local kind = "pincerGuard" .. s
				local size = tmplSize(kind .. "1")
				local g = size and gmN(ctx, kind .. "1", size, CFrame.new())
				local claw = m:FindFirstChild("Claw" .. s, true)
				if g and claw then
					-- (a thin amber shimmer, not a glow: Neon at 0.23 opacity still blazed over the claws, front still r2)
					g.Material, g.Color = Enum.Material.Glass, C3(255, 176, 70)
					g.Transparency = 1
					local rest = m:GetPivot() * CFrame.new(CENTRE[kind]) * YAW180
					table.insert(sheens, { p = g, b = claw, off = restCF(claw):ToObjectSpace(rest) })
				end
			end
			local lastHit = 0.23
			local fx = {}
			table.insert(fx, { step = function(_, t)
				if t > 3.36 then return false end
				local a = (t < 0.31) and 0.25 * smooth((t - 0.23) / 0.08) or (t < 3.23) and (0.23 + 0.05 * sin(t * 2.3)) or 0.23 * (1 - smooth((t - 3.23) / 0.12))
				-- (a test hit on the guard: the opacity +0.15 for 0.10 s and a small burst on a claw face)
				if m:GetAttribute("MoveTest") and t > 0.6 and t < 3.0 and t - lastHit > 0.8 then
					lastHit = t
					local sh = sheens[(math.floor(t / 0.8) % 2) + 1]
					if sh then
						local face = sh.b.TransformedWorldCFrame * sh.off
						local at = face.Position + m:GetPivot().LookVector * 0.6
						table.insert(fx, snapBurst(ctx, at, m:GetPivot().LookVector, t, 0.55))
						sparks(ctx, at, 1, 5)
						ctx.sound(SND.glass, at, 0.55, 2.4)
					end
				end
				local bump = (t - lastHit < 0.10) and 0.15 or 0
				for _, sh in sheens do
					sh.p.CFrame = sh.b.TransformedWorldCFrame * sh.off
					sh.p.Transparency = 1 - math.min(0.4, a + bump)
				end
				return true
			end, stop = function() for _, sh in sheens do sh.p:Destroy() end end })
			return group(fx)
		end },
	},
}

-- ===================== C. SIDE SWEEP (ORDER, warn 0.70, both claws swing across the front, bats 3 little ones 2 studs) ====
-- default: wind toward -X, sweep toward +X. Feet planted (Body moves are undone at each leg, see pinKeys)
local SWEEP_R0, SWEEP_R1, SWEEP_ARC = 1.40, 4.20, 70                     -- (the wedge: 140 deg about forward)
-- (audit r1: the claws must visibly load to -X together and strike across to +X. Bite-centre path (spec 5.3, cast frame):
-- t, left (x, y, z), right (x, y, z); after the pose each arm is turned (<= 60 deg) to put its bite centre there)
local SWEEP_PATH = {
	{ 0.22, Vector3.new(-2.8, 1.35, -1.45), Vector3.new(1.4, 1.40, -1.75) },
	{ 0.50, Vector3.new(-3.0, 1.55, -1.85), Vector3.new(-0.75, 1.70, -2.05) },
	{ 0.62, Vector3.new(-1.65, 1.55, -2.15), Vector3.new(0.45, 1.65, -2.15) },
	{ 0.70, Vector3.new(0.45, 1.55, -2.05), Vector3.new(3.05, 1.65, -1.85) },
	{ 0.81, Vector3.new(0.80, 1.65, -1.70), Vector3.new(3.25, 1.75, -1.45) },
	{ 0.96, Vector3.new(-1.5, 1.45, -1.55), Vector3.new(2.6, 1.45, -1.45) },
}
local function sweepAt(t, s)
	local a, b = SWEEP_PATH[1], SWEEP_PATH[#SWEEP_PATH]
	if t <= a[1] or t >= b[1] then return nil end
	for i = 1, #SWEEP_PATH - 1 do if t >= SWEEP_PATH[i][1] and t <= SWEEP_PATH[i + 1][1] then a, b = SWEEP_PATH[i], SWEEP_PATH[i + 1]; break end end
	local u = smooth((t - a[1]) / (b[1] - a[1]))
	local k = (s == "L") and 2 or 3
	return a[k]:Lerp(b[k], u)
end
A.Sweep = {
	boneKeys = true, dur = 1.35, lock = 1.08,
	post = function(ctx, t, bones)
		local m = ctx.m
		ctx.sweepCast = ctx.sweepCast or ctx.base
		local w = smooth((t - 0.10) / 0.12) * (1 - smooth((t - 0.96) / 0.16))
		if w <= 0 then return end
		ctx.snapPts = ctx.snapPts or {}
		for _, s in { "L", "R" } do
			local pp = ctx.snapPts[s]
			if not pp then pp = { blade = bonePt(m, "Claw" .. s, BLADE[s]), pinch = bonePt(m, "Pinch" .. s, PINCH[s]) }; ctx.snapPts[s] = pp end
			local lp = sweepAt(math.clamp(t, 0.23, 0.95), s)
			local armE = bones["Arm" .. s]
			if lp and armE and pp.blade and pp.pinch then
				local bc = (pp.blade() + pp.pinch()) / 2
				local want = ctx.sweepCast * lp
				armTo(armE.b, bc, want, 60, w)
				local nb = (pp.blade() + pp.pinch()) / 2
				ctx.sweepTip = ctx.sweepTip or {}
				ctx.sweepTip[s] = nb
				if m:GetAttribute("FreezeTT") then
					m:SetAttribute("SweepErr" .. s, (nb - want).Magnitude)
					local lp = ctx.sweepCast:PointToObjectSpace(nb)
					m:SetAttribute("SweepBC" .. s, string.format("%.2f, %.2f, %.2f", lp.X, lp.Y, lp.Z))
				end
			end
		end
	end,
	keys = pinKeys({
		{ 0.00, "smooth", B = { 0, 0, 0, 0, -0.05 } },
		{ 0.22, "in", B = { 0, 4, 0, 0, -0.18 }, AL = { 4, 24, 6 }, AR = { 4, 24, -4 }, CL = { 4, 8, 0 }, CR = { 4, 8, 0 }, PL = -10, PR = -10,
			legs = { L1 = { 0, 0, -12, 10 }, L2 = { 0, 0, -12, 10 }, L3 = { 0, 0, -12, 10 }, R1 = { 0, 0, 12, 10 }, R2 = { 0, 0, 12, 10 }, R3 = { 0, 0, 12, 10 } } },
		{ 0.50, "in", B = { 0, 6, 0, 0, -0.25 }, AL = { 8, 38, 8 }, AR = { 8, 28, -7 }, CL = { 6, 18, 0 }, CR = { 6, 15, 0 }, PL = -10, PR = -10,
			legs = { L1 = { 0, 0, -14, 12 }, L2 = { 0, 0, -14, 12 }, L3 = { 0, 0, -14, 12 }, R1 = { 0, 0, 14, 12 }, R2 = { 0, 0, 14, 12 }, R3 = { 0, 0, 14, 12 } } },
		{ 0.62, EASE_SHARP, B = { 0, 1, 0, 0, -0.10 }, AL = { -4, 6, 0 }, AR = { -4, 2, 0 }, CL = { -6, 2, 0 }, CR = { -6, 2, 0 }, PL = -10, PR = -10,
			legs = { L1 = { 0, 0, -8, 6 }, L2 = { 0, 0, -8, 6 }, L3 = { 0, 0, -8, 6 }, R1 = { 0, 0, 8, 6 }, R2 = { 0, 0, 8, 6 }, R3 = { 0, 0, 8, 6 } } },
		{ 0.70, EASE_SHARP, B = { 0, -6, 0, 0.10, 0.06 }, AL = { -9, -38, -4 }, AR = { -9, -33, 4 }, CL = { -10, -15, 0 }, CR = { -10, -12, 0 }, PL = -10, PR = -10 },
		{ 0.81, "out", B = { 0, -9, 0, 0.06, 0.03 }, AL = { -5, -46, -4 }, AR = { -5, -42, 4 }, CL = { -5, -18, 0 }, CR = { -5, -16, 0 }, PL = -10, PR = -10 },
		{ 0.96, "out", B = { 0, -3, 0, 0, -0.06 }, AL = { 3, -16, 0 }, AR = { 3, -15, 0 }, CL = { 4, -5, 0 }, CR = { 4, -5, 0 }, PL = -10, PR = -10 },
		{ 1.18, "smooth" },
		{ 1.35, "smooth" },
	}),
	events = {
		-- 0.00: the warning wedge (140 deg, r 1.40-4.20, fixed at the cast): dark rim + amber outline (18 segments on the
		-- ground), a warm fill that advances 0-0.45, the edge brightening 0.45-0.60, two edge pulses 0.60-0.67, a border
		-- pulse 0.67-0.70, gone at 0.70
		{ t = 0, fn = function(ctx)
			local base = ctx.base
			ctx.sweepCast, ctx.sweepTip = ctx.base, nil
			local lines, fills = {}, {}
			local N = 18
			local function at(r, a) return base * Vector3.new(-math.sin(math.rad(a)) * r, 0, -math.cos(math.rad(a)) * r) end
			for i = 0, N - 1 do
				local a0, a1 = -SWEEP_ARC + 2 * SWEEP_ARC * i / N, -SWEEP_ARC + 2 * SWEEP_ARC * (i + 1) / N
				edge(ctx, lines, at(SWEEP_R1, a0), at(SWEEP_R1, a1), 0.20)
				-- (audit r1: the amber inner arc read as a yellow patch: the inner rim is dark only)
				local inner = strip(ctx, at(SWEEP_R0, a0), at(SWEEP_R0, a1), 0.30, W_UNDER, 0.05); inner.Material = Enum.Material.SmoothPlastic
				table.insert(lines, inner)
				-- (the fill: a ground strip from the inner to the outer radius at this angle, warm brown)
				local f = strip(ctx, at(SWEEP_R0, (a0 + a1) / 2), at(SWEEP_R1, (a0 + a1) / 2), (SWEEP_R1 * 2 * pi * (2 * SWEEP_ARC / 360)) / N * 1.05, C3(74, 43, 24), 0.03)
				f.Material = Enum.Material.SmoothPlastic
				fills[i + 1] = f
			end
			edge(ctx, lines, at(SWEEP_R0, -SWEEP_ARC), at(SWEEP_R1, -SWEEP_ARC), 0.20)
			edge(ctx, lines, at(SWEEP_R0, SWEEP_ARC), at(SWEEP_R1, SWEEP_ARC), 0.20)
			return { step = function(_, t)
				if t >= 0.70 then return false end
				local adv = smooth(t / 0.45)
				for i, f in fills do f.Transparency = ((i - 0.5) / #fills <= adv) and 0.45 or 1 end
				local edgeB = (t > 0.45) and smooth((t - 0.45) / 0.15) or 0
				local pulseE = (t > 0.60 and t < 0.67) and (0.5 + 0.5 * sin((t - 0.60) / 0.035 * pi)) or 0
				local border = (t > 0.67) and 1 or 0
				for i, p in lines do p.Transparency = (i % 2 == 1) and 0.25 or math.max(0, 0.35 - 0.3 * edgeB - 0.2 * pulseE - 0.35 * border) end
				return true
			end, stop = function() for _, p in lines do p:Destroy() end; for _, p in fills do p:Destroy() end end }
		end },
		{ t = 0.16, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.45, 1.6, 0.3) end },          -- (gravel crouch)
		{ t = 0.62, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.65, 1.8, 0.4) end },          -- (air shear)
		-- 0.56-0.96: the sweep ribbon (K3): three authored arc sections revealed in turn with the claws (0.56 / 0.62 /
		-- 0.70), full at 0.70, thinning 0.79, gone by 0.96
		{ t = 0.56, fn = function(ctx)
			local base = ctx.base
			local secs = {}
			for k = 1, 3 do
				local kind = "sweepRibbon" .. k
				local size = tmplSize(kind)
				local p = size and gmN(ctx, kind, size, base * CFrame.new(CENTRE[kind]) * YAW180)
				if p then p.Transparency = 1; secs[k] = { p = p, t0 = ({ 0.56, 0.62, 0.68 })[k], size = size, kind = kind } end
			end
			-- (audit r1 + r2: K3 amber-orange; the ribbon is BOUND to the leading (right) claw's measured bite centre: the whole
			-- 140-deg arc is turned about the cast pivot so its leading end sits on the claw (its radius and height too), and a
			-- section shows only where the claw has already swept (its turned start past -70 deg): a trail growing behind it)
			for _, sc in secs do sc.p.Color = C3(255, 128, 34); sc.p.Material = Enum.Material.Neon end
			local A0 = { -70, -23.3, 23.3 }
			return { step = function(_, t)
				if t > 0.97 then return false end
				local tip = ctx.sweepTip and ctx.sweepTip.R
				local ang, rad, y = -90, 3.8, 1.65
				if tip then
					local lp = base:PointToObjectSpace(tip)
					ang = math.deg(math.atan2(lp.X, -lp.Z)); rad = Vector2.new(lp.X, lp.Z).Magnitude; y = lp.Y
				end
				local delta = ang - 70
				local kR = math.clamp(rad / 3.8, 0.4, 1.3)
				local turn = CFrame.Angles(0, -math.rad(delta), 0)
				local off = smooth((t - 0.79) / 0.17)
				for k, sc in secs do
					local start = A0[k] + delta
					local on = (start >= -70) and smooth((start + 70) / 12) or 0
					local sz = sc.size
					sc.p.Size = Vector3.new(sz.X * kR, sz.Y * 0.6, sz.Z * kR)
					local c = CENTRE[sc.kind]
					sc.p.CFrame = base * turn * CFrame.new(c.X * kR, y, c.Z * kR) * YAW180
					sc.p.Transparency = 1 - 0.75 * on * (1 - off)
				end
				-- (test readout: the leading end (the arc's +70 end, turned) to the claw)
				if tip and ctx.m:GetAttribute("FreezeTT") then
					local lead = base * (turn * Vector3.new(math.sin(math.rad(70)) * 3.8 * kR, y, -math.cos(math.rad(70)) * 3.8 * kR))
					ctx.m:SetAttribute("RibbonLead", (lead - tip).Magnitude)
				end
				return true
			end, stop = function() for _, sc in secs do sc.p:Destroy() end end }
		end },
		-- 0.70: the strike: up to 3 little ones hit (a burst on each, the rock crack), dust at the feet 0.76; MOVE TEST:
		-- each target slides 2.00 studs along the sweep (+X) by 1.00 (client-side show: the server owns knockback)
		{ t = 0.70, fn = function(ctx)
			local fx = {}
			ctx.sound(SND.shaleBig, ctx.base.Position, 0.95, 1.5)
			local hit = littleOnes(ctx, SWEEP_R1 + 1.0, 3)
			ctx.m:SetAttribute("SweepHits", #hit)
			for _, u in hit do
				local p, n = surfaceOf(u, ctx.base.Position)
				table.insert(fx, snapBurst(ctx, p, n, 0.70, 0.8))
				sparks(ctx, p, 1, 5)
			end
			return group(fx)
		end },
		{ t = 0.76, fn = function(ctx)
			for _, z in { -0.85, 1.45 } do for _, x in { -3.05, 3.05 } do dust(ctx, A.rock.groundAt(ctx, ctx.base * Vector3.new(x, 0, z)), 1, 1.2) end end
		end },
	},
}

-- ===================== HURT (0.52, additive; keys for a hit on its LEFT (-X), shoving it toward +X) =====================
A.PincerHurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,
	keys = pinKeys({
		{ 0.00, "smooth" },
		{ 0.06, EASE_SHARP, R = { 0, 0.14 }, B = { 0, -3, -9 }, AL = { 18, 0, 0 }, CL = { 12, 0, 0 },
			legs = { L1 = { 0, 0, 10, -8 }, L2 = { 0, 0, 8, -6 } } },
		{ 0.14, "out", R = { 0, 0.22 }, B = { 0, -5, -15 }, AL = { 34, 0, 0 }, CL = { 18, 0, 0 },
			legs = { L1 = { 0, 0, 16, -12 }, L2 = { 0, 0, 12, -10 } } },
		{ 0.27, "out", R = { 0, -0.08 }, B = { 0, 0, 8 }, AL = { -8, 0, 0 } },
		{ 0.38, "smooth", R = { 0, 0.04 }, B = { 0, 0, -4 }, AL = { 4, 0, 0 } },
		{ 0.52, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local p = ctx.base * Vector3.new((out:Dot(ctx.base.RightVector) > 0) and 1.6 or -1.6, 1.6, 0.1)
			ctx.sound(SND.shale, p, 0.6, 2.4, 0.1)
			return A.rock.chips(ctx, p, out, 3, 0.06, 0.8)
		end },
	},
}

-- ===================== DEFEAT (3.60, terminal): slump, the shell breaks, both claws drop off, rubble, TWO motes ==========
A.PincerDefeat = {
	boneKeys = true, dur = 3.60,
	keys = pinKeys({
		{ 0.00, "smooth" },
		{ 0.35, "smooth", B = { 0, 0, 4, 0, -0.10 }, AL = { -14, 0, 0 }, AR = { -14, 0, 0 }, CL = { -6, 0, 0 }, CR = { -6, 0, 0 } },
		{ 0.80, "in", B = { 0, 0, -6, 0, -0.42 }, AL = { -30, 0, 8 }, AR = { -30, 0, -8 }, CL = { -12, 0, 0 }, CR = { -12, 0, 0 },
			legs = { L1 = { 0, 0, 20, -15 }, L2 = { 0, 0, 20, -15 }, L3 = { 0, 0, 20, -15 }, R1 = { 0, 0, -20, -15 }, R2 = { 0, 0, -20, -15 }, R3 = { 0, 0, -20, -15 } } },
		{ 1.30, "in", B = { 8, 0, 0, 0, -0.72 }, AL = { -38, 0, 14 }, AR = { -38, 0, -14 }, CL = { -16, 0, 0 }, CR = { -16, 0, 0 },
			legs = { L1 = { 0, 0, 34, -25 }, L2 = { 0, 0, 34, -25 }, L3 = { 0, 0, 34, -25 }, R1 = { 0, 0, -34, -25 }, R2 = { 0, 0, -34, -25 }, R3 = { 0, 0, -34, -25 } } },
		{ 3.60, "smooth", B = { 8, 0, 0, 0, -0.72 }, AL = { -38, 0, 14 }, AR = { -38, 0, -14 }, CL = { -16, 0, 0 }, CR = { -16, 0, 0 },
			legs = { L1 = { 0, 0, 34, -25 }, L2 = { 0, 0, 34, -25 }, L3 = { 0, 0, 34, -25 }, R1 = { 0, 0, -34, -25 }, R2 = { 0, 0, -34, -25 }, R3 = { 0, 0, -34, -25 } } },
	}),
	extra = function(t, p)
		local flick = (t > 0.35 and t < 1.45) and (0.6 + 0.4 * sin(t * 31) * sin(t * 11)) or 1
		local flash = (t > 1.45 and t < 1.72) and 1.8 or 1
		p.glowMul = flick * flash * (1 - smooth((t - 1.85) / 0.3))
	end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.castAt = os.clock()
			ctx.defeatWas = {}
			local replay = ctx.m:GetAttribute("MoveTest")
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then
					if replay then d.LocalTransparencyModifier = 0 end
					ctx.defeatWas[d] = d.LocalTransparencyModifier
				end
			end
		end },
		{ t = 0.35, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.65, 1.5) end },
		{ t = 0.80, fn = function(ctx) dust(ctx, A.rock.groundAt(ctx, ctx.base.Position), 2, 1.6) end },
		-- 1.65 the shell fractures: the rig goes 1.72-1.90 under a dust burst; the rubble mesh (its own shell, flattened:
		-- 5.2 x 1.05 x 4.3) and its two real claws (detached: tipping 45-60 deg outward, dropping 0.45-0.75) take its place,
		-- settled by 2.15; the rubble's glow down by 2.65 and dark by 3.35
		{ t = 1.65, fn = function(ctx)
			local m = ctx.m
			ctx.sound(SND.shaleBig, ctx.base.Position, 0.85, 1.6)
			local base = ctx.base
			local fx = {}
			local hidden, was, done = {}, ctx.defeatWas or {}, false
			for _, d in m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); if was[d] == nil then was[d] = d.LocalTransparencyModifier end end end
			table.insert(fx, { step = function(_, t)
				if t >= 1.90 then done = true end
				local gone = smooth((t - 1.72) / 0.18)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], gone) end end
				return t <= 3.6
			end, stop = function() if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end end })
			table.insert(fx, { step = function(_, t) if t > 1.72 and not ctx.dustDone then ctx.dustDone = true; dust(ctx, A.rock.groundAt(ctx, base.Position), 3, 2.4) end; return t < 1.8 end, stop = function() end })
			-- the rubble
			local rub = gmN(ctx, "pincerRubble1", Vector3.new(5.2, 1.05, 4.3), CFrame.new())
			local sa = rub and rub:FindFirstChildWhichIsA("SurfaceAppearance")
			local sa0 = sa and sa.Color
			-- the two claws
			local claws = {}
			for _, s in { "L", "R" } do
				local kind = "pincerClaw" .. s
				local size = tmplSize(kind .. "1")
				local c = size and gmN(ctx, kind .. "1", size, CFrame.new())
				if c then
					local rest = base * CFrame.new(CENTRE[kind]) * YAW180
					c.Transparency = 1
					table.insert(claws, { p = c, rest = rest, side = (s == "L") and -1 or 1, tip = (s == "L") and 95 or 88 })
				end
			end
			table.insert(fx, { step = function(_, t)
				if t > 3.6 then return false end
				if rub then
					local u = smooth((t - 1.72) / 0.43)
					rub.CFrame = base * CFrame.new(0, 0.525 * (0.8 + 0.2 * u) - 0.05, 0.25) * YAW180
					rub.Size = Vector3.new(5.2, 1.05 * (0.85 + 0.15 * u), 4.3) * (0.85 + 0.15 * u)
					rub.Transparency = (t < 1.72) and 1 or (1 - smooth((t - 1.72) / 0.10))
					if sa and sa0 then local k = 1 - 0.75 * smooth((t - 2.15) / 0.5) - 0.15 * smooth((t - 2.65) / 0.7); sa.Color = Color3.new(sa0.R * k, sa0.G * k, sa0.B * k) end
				end
				-- (audit r1: they stood up as tall C-rings: now each tips 88-95 deg outward and comes to rest LYING on the ground
				-- beside the pile: its rotated box's lowest point 0.10 over the ground, 0.6 further out)
				for _, c in claws do
					local u = smooth((t - 1.85) / 0.30)
					local start = CFrame.new(0, -0.72, 0) * c.rest                     -- (the slumped body is 0.72 low)
					-- (the C-ring stands in the front plane: it lies down by turning about its own X axis (about Z only spun it in place))
					local rot = start.Rotation * CFrame.Angles(-math.rad(c.tip) * u, 0, math.rad(12) * c.side * u)
					local s2 = c.p.Size / 2
					local half = math.abs(rot.XVector.Y) * s2.X + math.abs(rot.YVector.Y) * s2.Y + math.abs(rot.ZVector.Y) * s2.Z
					local pos = start.Position + base:VectorToWorldSpace(Vector3.new(c.side * 0.6 * u, 0, 0))
					local gy = ctx.ground(pos.X, pos.Z) + half * 0.62 + 0.10                     -- (the C-ring fills ~60 % of its rotated box: its true lowest point, from the shadow gap)
					pos = Vector3.new(pos.X, pos.Y + (gy - pos.Y) * u, pos.Z)
					c.p.CFrame = CFrame.new(pos) * rot
					c.p.Transparency = (t < 1.72) and 1 or 0
					if ctx.m:GetAttribute("FreezeTT") then ctx.m:SetAttribute("ClawTop" .. ((c.side < 0) and "L" or "R"), pos.Y + half - ctx.ground(pos.X, pos.Z)) end
				end
				return true
			end, stop = function() if rub then rub:Destroy() end; for _, c in claws do c.p:Destroy() end end })
			return group(fx)
		end },
		{ t = 2.00, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.5, 1.8, 0.2) end },
		-- exactly TWO matter motes at 2.65, at -0.42 / +0.42, 0.80 up, rising 1.10-1.45, gone by 3.35
		{ t = 2.65, fn = function(ctx)
			if ctx.moteAt == ctx.castAt and ctx.castAt then return end
			ctx.moteAt = ctx.castAt
			ctx.sound(SND.glass, ctx.base.Position, 0.4, 2.3, 0.6)
			-- (audit r1: they read as tiny spikes: 0.40 x 0.48 x 0.40, 0.95 apart, 1.15 up by 3.00)
			return A.rock.motes(ctx, A.rock.groundAt(ctx, ctx.base.Position) + Vector3.new(0, 0.80, 0), 2, 2.65, 3.35, ctx.home, Vector3.new(0.40, 0.48, 0.40), 1.2, 0.40, 0.95)
		end },
	},
}
A.FOR.CrunchF2v5 = { Snap = A.Snap, Block = A.Block, Sweep = A.Sweep, Defeat = A.PincerDefeat, Hurt = A.PincerHurt }
for _, atk in { A.Snap, A.Block, A.Sweep, A.PincerHurt, A.PincerDefeat } do table.sort(atk.events, function(x, y) return x.t < y.t end) end
end


-- ===================== BATCH 7: the CRUNCH RAM (spec design/19-RAM-BATCH7-SPEC-chatgpt-raw.md) =====================
-- Built to its reference sheets (design/concepts/ram/attacks/: J1 HORN GORE, J2 HOOF STAMP, J3 RAM CHARGE, J4 HURT +
-- DEFEAT, K EFFECTS). An 11.6-stud four-legged lava bull: Root -> Chest (-> Head, LegFL/FR) and Hips (-> Tail, LegBL/BR);
-- its legs are the animator's planted IK (atk.limbs pulls a hoof to a point). Model space (+X right, -Z forward); its
-- horn hooks (the head's most forward points, from its mesh: assets/blender/scripts/ram_fx.py) L (-0.24, 3.74, -5.53),
-- R (0.27, 3.06, -5.29), carried by the Head bone. FX meshes from its own mesh: ramHornL1 / R1 (the real horns, detached),
-- ramRubble1 (the rest, squashed to 1.5 high). The 3D importer turned them 180 deg about Y.
-- ============================================================================================================
do
local function meshT(name) local f = fx({}); local g = f and f:FindFirstChild("GooMeshes"); return g and g:FindFirstChild(name) end
local function gmR(ctx, name, size, cf)
	local t = meshT(name)
	if not t then return nil end
	local p = t:Clone()
	p.Size, p.CFrame = size or t.Size, cf or CFrame.new()
	p.Parent = ctx.holder
	return p
end
local YAW180 = CFrame.Angles(0, pi, 0)
local HOOK = { L = Vector3.new(-0.244, 3.735, -5.529), R = Vector3.new(0.265, 3.055, -5.294) }
-- (the hook points are the mesh's bind pose = the bones' rest chain (restCF): no offset. A -0.40 / -0.39 "offset" read off
-- Bone.WorldCFrame was the idle's Chest motion, which WorldCFrame includes)
local HEAD_DELTA = Vector3.zero
local CENTRE = { ramHornL = Vector3.new(-1.4, 3.685, -3.267), ramHornR = Vector3.new(1.382, 3.669, -3.152), ramRubble = Vector3.new(0.015, 0.75, 0.214) }
-- keys: R root {lift, side, fwd, pitch, roll, yaw}; Chest / Hips / Head / Tail {rx, ry, rz, ox, oy, oz}
local function ramKeys(rows)
	local keys = {}
	for i, r in rows do
		local b = { Chest = r.Chest or { 0, 0, 0 }, Hips = r.Hips or { 0, 0, 0 }, Head = r.Head or { 0, 0, 0 }, Tail = r.Tail or { 0, 0, 0 } }
		local R = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { R[1] or 0, R[2] or 0, R[3] or 0, R[4] or 0, R[5] or 0, R[6] or 0 }, bones = b }
	end
	return keys
end
-- a hoof target track: rows { t, w, x, y, z } (cast frame; y = the hoof bone over the ground: the sole is 0.58 under it)
local function hoofTrack(rows)
	return function(tt, ctx)
		if tt <= rows[1][1] or tt >= rows[#rows][1] then return nil end
		local a, b = rows[1], rows[#rows]
		for i = 1, #rows - 1 do if tt >= rows[i][1] and tt <= rows[i + 1][1] then a, b = rows[i], rows[i + 1]; break end end
		local u = smooth((tt - a[1]) / math.max(1e-3, b[1] - a[1]))
		local w = a[2] + (b[2] - a[2]) * u
		if w <= 0 then return nil end
		local lp = Vector3.new(a[3] + (b[3] - a[3]) * u, 0, a[5] + (b[5] - a[5]) * u)
		local y = a[4] + (b[4] - a[4]) * u
		local p = ctx.cast * lp
		return { p = Vector3.new(p.X, ctx.ground(p.X, p.Z) + y - 0.58, p.Z), w = w }
	end
end
local function hookPt(m, s)
	local head = m:FindFirstChild("Head", true)
	if not head or not head:IsA("Bone") then return nil end
	local rel = restCF(head):PointToObjectSpace(m:GetPivot() * (HOOK[s] + HEAD_DELTA))
	return function() return head.TransformedWorldCFrame * rel end, head
end
local PACK = { SquishF2v5 = true, SquishF2 = true, SquishF3v5 = true, SquishF3 = true, CrunchF2v5 = true }
local function foes(ctx, reach, n, kinds)
	local units, own = ctx.m.Parent, ctx.m:GetAttribute("Owner")
	local list = {}
	for _, u in (units and units:GetChildren() or {}) do
		if u ~= ctx.m and u:IsA("Model") and u.PrimaryPart and isFoe(ctx.m, u, own) and (not kinds or kinds[u:GetAttribute("FormName") or ""]) then
			local d = ((u:GetPivot().Position - ctx.base.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d <= reach then table.insert(list, { u = u, d = aiFirst(ctx.m, u) and -1 or d }) end
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	local out = {}
	for i = 1, math.min(n, #list) do out[i] = list[i].u end
	return out
end
-- a target's visible surface facing a point, at a height (clamped inside its box)
local function faceOf(u: Model, from: Vector3, y: number?)
	local cf, size = u:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local c = Vector3.new(cf.X, math.clamp(y or (bottom + size.Y * 0.5), bottom + 0.3, bottom + size.Y - 0.2), cf.Z)
	local d = (from - c) * Vector3.new(1, 0, 1)
	d = (d.Magnitude > 0.05) and d.Unit or Vector3.zAxis
	-- (0.28 of the box, not 0.45: a goo Pack's box is its wide puddle; its body is narrower (the hook stopped 2 short, measured))
	return c + d * math.min(size.X, size.Z) * 0.28, d
end
local function turnBone(bone: Bone, tip: Vector3, want: Vector3, maxDeg, w)
	local twc = bone.TransformedWorldCFrame
	local p = twc.Position
	local v1, v2 = tip - p, want - p
	if v1.Magnitude < 0.05 or v2.Magnitude < 0.05 then return 0 end
	local axis = v1:Cross(v2)
	if axis.Magnitude < 1e-5 then return 0 end
	local ang = math.min(math.acos(math.clamp(v1.Unit:Dot(v2.Unit), -1, 1)), math.rad(maxDeg)) * w
	local newWorld = CFrame.new(p) * CFrame.fromAxisAngle(axis.Unit, ang) * (twc - p)
	local parent = bone.Parent
	local pw = (parent and parent:IsA("Bone")) and parent.TransformedWorldCFrame or CFrame.identity
	bone.Transform = (pw * bone.CFrame):Inverse() * newWorld
	return math.deg(ang)
end
-- an authored K mesh on a curve: keys { dt, sx, sy, sz, opacity } (from t0), at frame cf(t) with full size `full`;
-- opacity is how visible (1 = solid). The importer turned meshes 180 deg about Y: YAW180 applied here
local function keyed(ctx, name, full: Vector3, t0, keys, cfAt)
	local p = gmR(ctx, name, full * 0.1, CFrame.new())
	if not p then return nil end
	p.Transparency = 1
	return { step = function(_, t)
		local e = t - t0
		if e > keys[#keys][1] then return false end
		if e < 0 then p.Transparency = 1; return true end
		local a, b = keys[1], keys[#keys]
		for i = 1, #keys - 1 do if e >= keys[i][1] and e <= keys[i + 1][1] then a, b = keys[i], keys[i + 1]; break end end
		local u = (b[1] > a[1]) and smooth((e - a[1]) / (b[1] - a[1])) or 1
		local function L(i) return a[i] + (b[i] - a[i]) * u end
		p.Size = Vector3.new(full.X * L(2), full.Y * L(3), full.Z * L(4))
		p.CFrame = cfAt(t, p.Size) * YAW180
		p.Transparency = 1 - L(5)
		return true
	end, stop = function() p:Destroy() end, part = p }
end
local NOFX = { step = function() return false end, stop = function() end }
-- the GORE BURST (K1, audit r1: authored): 7 tapered amber crystal blades + 5 grey splinters fanned from one contact
-- centre along the surface normal, 3.2 x 2.2 x 1.3 (x1.35 at the charge); 0.40 at spawn, 1.0 at +0.055, gone +0.31;
-- centroid 0.08 out; + 3 pooled rock chips
local GORE_KEYS = { { 0, 0.40, 0.35, 0.40, 0.90 }, { 0.055, 1, 1, 1, 1 }, { 0.16, 1.12, 0.75, 1.05, 0.60 }, { 0.31, 1.15, 0.20, 1.1, 0 } }
local function goreBurst(ctx, pos, n, t0, scale, posFn, up)
	local cfAt = function()
		local p = posFn and posFn() or pos
		return CFrame.lookAt(p, p + n, up or Vector3.yAxis) * CFrame.Angles(0, pi, 0)   -- (the mesh's normal is its +z)
	end
	return group({
		keyed(ctx, "ramGoreBlades1", Vector3.new(3.2, 2.2, 1.3) * scale, t0, GORE_KEYS, cfAt) or { step = function() return false end, stop = function() end },
		keyed(ctx, "ramGoreSplint1", Vector3.new(2.2, 0.9, 1.0) * scale, t0, GORE_KEYS, cfAt) or { step = function() return false end, stop = function() end },
		A.rock.chips(ctx, pos + n * 0.1, n, 3, t0, 1.0 * scale),
	})
end

-- ===================== A. HORN GORE (passive, 1.25 s cycle; hit 0.55) =====================
-- reach gate (spec A): the gap g from the chosen horn hook to the target's face; the Ram steps L = clamp(g - 0.35, 0, 2.65)
-- forward over 0.37-0.55 (MOVE TEST: client-side; in a match the server owns that step)
local GORE_ROWS = {
	{ 0.00, "smooth", Head = { 3, 0, 0 } },
	{ 0.16, "smooth", R = { -0.02, 0, 0, -2 }, Hips = { -3, 0, 0 }, Chest = { -6, 0, 0, 0, -0.08 }, Head = { -10, 0, 0 }, Tail = { 5, 0, 0 } },
	{ 0.37, "smooth", R = { -0.06, 0, 0.05, -4 }, Hips = { -5, 0, 0 }, Chest = { -10, 0, 0, 0, -0.12 }, Head = { -18, 0, 0 }, Tail = { 8, 0, 0 } },
	-- (measured: the spec's nose-up hit (Head +20, Chest +11) put the hook 6.0 up, over a Pack's 4.5 top; the horns ride
	-- 3.7 up at rest, so the hook comes level and forward at the hit (Head +3 / Chest +3) and lifts in the recoil (0.70))
	{ 0.48, "in", R = { 0.01, 0, 0.55, 0 }, Hips = { 1, 0, 0 }, Chest = { 0, 0, 0, 0, 0.04 }, Head = { -4, 0, 0 }, Tail = { -4, 0, 0 } },
	{ 0.55, "in", R = { 0.02, 0, 1.00, 1 }, Hips = { 2, 0, 0 }, Chest = { 3, 0, 0, 0, 0.06 }, Head = { 3, 5, 0 }, Tail = { -9, 0, 0 } },
	-- (audit r2: the contact pose HELD to 0.63 so the burst reads on the horn)
	{ 0.63, "smooth", R = { 0.02, 0, 1.00, 1 }, Hips = { 2, 0, 0 }, Chest = { 3, 0, 0, 0, 0.06 }, Head = { 3, 5, 0 }, Tail = { -9, 0, 0 } },
	{ 0.70, "out", R = { 0.03, 0, 1.00, 2 }, Hips = { 3, 0, 0 }, Chest = { 7, 0, 0, 0, 0.07 }, Head = { 14, 2, 0 }, Tail = { -4, 0, 0 } },
	{ 0.92, "smooth", R = { 0, 0, 1.00, -1 }, Hips = { -1, 0, 0 }, Chest = { -2, 0, 0 }, Head = { -3, 0, 0 }, Tail = { 3, 0, 0 } },
	-- (AI TEST, 29 Oct: the server never carries the step, so the body stepped back by snapping L at the attack's end. It
	-- now steps back over 0.92-1.25, its hooves stepping with it (A.Gore.travel). The real gore step is the server gate)
	{ 1.05, "smooth", R = { 0, 0, 0.30 } },
	{ 1.25, "smooth", R = { 0, 0, 0 } },
}
local function goreKeys(L, side)
	local rows = {}
	for i, r in GORE_ROWS do
		local c = table.clone(r)
		if c.R then c.R = { c.R[1], c.R[2] or 0, (c.R[3] or 0) * L, c.R[4] or 0 } end
		if c.Head and c.Head[2] ~= 0 then c.Head = { c.Head[1], c.Head[2] * side, 0 } end
		rows[i] = c
	end
	return ramKeys(rows)
end
A.Gore = {
	boneKeys = true, dur = 1.25, cycle = 1.25, lock = 1.05,
	keys = goreKeys(0, 1),
	-- (AI TEST, 29 Oct, James: the hind legs "flicking" on the gore. The lunge carries the body up to 2.65 forward over
	-- 0.37-0.55 while all four hooves stayed planted at the start: the hind legs stretched back past their reach and lifted.
	-- Over 0.37-0.92 the hooves stand under the stepped body (the animator's foot handoff walks them there in 0.18 s, the
	-- lunge's own length), then step back as the body does)
	travel = function(ctx, t)
		-- (L and the spot are fixed at the cast (gore.o, audit r2): a shove or the target dying mid-lunge can't move them)
		local gr = ctx.gore
		if not gr or gr.L < 0.3 or t < 0.37 or t >= 0.92 then return nil end
		-- (knocked off its cast spot (> 1.5 studs) mid-lunge: the hooves stand under it again, not at the old line)
		if ((ctx.base.Position - gr.o.Position) * Vector3.new(1, 0, 1)).Magnitude > 1.5 then gr.L = 0; return nil end
		local b = gr.o
		local f = (b.LookVector * Vector3.new(1, 0, 1)).Unit
		local function at(d)
			local p = b.Position + f * d
			local g = Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
			return CFrame.lookAt(g, g + f)
		end
		return gr.L, at, true
	end,
	events = {
		{ t = 0, fn = function(ctx)
			local m = ctx.m
			ctx.gore = nil
			local t = foes(ctx, 14, 1)[1]
			local L, side = 0, 1
			if t then
				-- the hook nearer the target, and the gap along the forward plane at the hit height (2.3-3.4 over its ground)
				local best, bd, bs
				for _, s in { "L", "R" } do
					local hp = ctx.base * (HOOK[s] + HEAD_DELTA)
					local face = faceOf(t, hp, hp.Y)
					local d = (face - hp).Magnitude
					if not bd or d < bd then best, bd, bs = face, d, s end
				end
				local hp = ctx.base * (HOOK[bs] + HEAD_DELTA)
				local g = ((best - hp) * Vector3.new(1, 0, 1)):Dot(ctx.base.LookVector)
				-- (the spec's g - 0.35 left the hook 0.45 short at the hit, measured: this rig's hit pose carries the hook back 0.3)
				L = math.clamp(g - 0.05, 0, 2.65)
				side = (bs == "L") and 1 or -1                           -- (+ry turns the head to its left)
				ctx.gore = { t = t, s = bs, L = L, o = ctx.base }
				m:SetAttribute("GoreGap", g); m:SetAttribute("GoreL", L); m:SetAttribute("GoreHorn", bs)
			end
			ctx.keys = goreKeys(L, side)
		end },
		{ t = 0.16, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.35, 1.7, 0.2) end },
		{ t = 0.37, fn = function(ctx) ctx.sound(SND.shale, ctx.base.Position, 0.48, 1.3, 0.05) end },
		{ t = 0.55, fn = function(ctx)
			local gr = ctx.gore
			if not gr or not gr.t.Parent then return end
			local _, n0 = faceOf(gr.t, ctx.m:GetPivot().Position)
			local n = (ctx.goreN and ctx.goreN.Magnitude > 0.05) and ctx.goreN.Unit or n0
			local p = ctx.goreAt or faceOf(gr.t, ctx.m:GetPivot().Position)
			ctx.sound(SND.glass, p, 1.0, 1.5)
			ctx.sound(SND.shale, p, 0.6, 1.9)
			sparks(ctx, p, 2, 5)
			-- (the fan follows the held contact point; its blades turned toward the Ram's side so they read edge-on, not end-on)
			return goreBurst(ctx, p + n * 0.08, n, 0.55, 1, function() return (ctx.goreAt or p) + n * 0.08 end, ctx.m:GetPivot().RightVector)
		end },
	},
	-- after the pose: the chosen hook turned onto the target's face (head +-7 deg yaw / +-6 deg pitch) over 0.37-0.55
	post = function(ctx, t, bones)
		local gr = ctx.gore
		if not gr or not gr.t.Parent then return end
		local m = ctx.m
		ctx.hookFn = ctx.hookFn or {}
		local f = ctx.hookFn[gr.s]
		if not f then f = hookPt(m, gr.s); ctx.hookFn[gr.s] = f end
		local head = bones.Head
		if not f or not head then return end
		local w = (t < 0.37) and 0 or (t < 0.55) and smooth((t - 0.37) / 0.18) or (t < 0.63) and 1 or (t < 0.75) and 1 - smooth((t - 0.63) / 0.12) or 0
		local tip = f()
		local want = faceOf(gr.t, m:GetPivot().Position, tip.Y)
		if w > 0 then turnBone(head.b, tip, want, 7, w) end
		-- (audit r2: the burst sits at the MIDPOINT of the hook and the surface; it follows the hook while the pose is held)
		ctx.goreAt = (f() + want) / 2
		ctx.goreN = (want - gr.t:GetPivot().Position) * Vector3.new(1, 0, 1)
		if m:GetAttribute("FreezeTT") then m:SetAttribute("GoreHook", (f() - want).Magnitude); m:SetAttribute("GoreMid", ((f() - want) / 2).Magnitude) end
	end,
}

-- ===================== B. HOOF STAMP (auto; warning ring 0.00-0.50, both front hooves land at 0.68) ==================
-- the rear rotates the whole body nose-up about the hind-hoof midpoint P = (0, 0.58, 3.30): lift / fwd from the spec
-- (pivot compensation); the front hooves are pulled through their TARGET tracks, the hind ones stay planted
A.Stamp = {
	boneKeys = true, dur = 1.35, lock = 1.16,
	keys = ramKeys({
		{ 0.00, "smooth" },
		{ 0.12, "out", R = { 0.47, 0, 0.05, 8 }, Hips = { 2, 0, 0 }, Chest = { 4, 0, 0, 0, 0.03 }, Head = { -4, 0, 0 }, Tail = { -5, 0, 0 } },
		{ 0.30, "out", R = { 1.39, 0, -0.05, 24 }, Hips = { 3, 0, 0 }, Chest = { 7, 0, 0, 0, 0.10 }, Head = { -7, 0, 0 }, Tail = { -11, 0, 0 } },
		{ 0.44, "out", R = { 1.84, 0, -0.19, 32 }, Hips = { 4, 0, 0 }, Chest = { 9, 0, 0, 0, 0.12 }, Head = { -8, 0, 0 }, Tail = { -16, 0, 0 } },
		{ 0.50, "smooth", R = { 1.84, 0, -0.19, 32 }, Hips = { 4, 0, 0 }, Chest = { 9, 0, 0, 0, 0.12 }, Head = { -8, 0, 0 }, Tail = { -16, 0, 0 } },
		{ 0.60, "in", R = { 0.93, 0, 0.03, 16 }, Hips = { -3, 0, 0 }, Chest = { -5, 0, 0, 0, -0.06 }, Head = { 9, 0, 0 }, Tail = { 7, 0, 0 } },
		-- (measured: the spec's impact compression (pitch -2, Hips -7) lifted both hind hooves 0.24 off: the hind legs are near
		-- full stretch. Root down 0.22 instead, Hips -2: the compression is in the chest)
		{ 0.68, "in", R = { -0.22, 0, 0.08, -1 }, Hips = { -2, 0, 0 }, Chest = { -9, 0, 0, 0, -0.16 }, Head = { 12, 0, 0 }, Tail = { 12, 0, 0 } },
		{ 0.82, "out", R = { -0.16, 0, 0.04, -1 }, Hips = { -1, 0, 0 }, Chest = { -7, 0, 0, 0, -0.12 }, Head = { 9, 0, 0 }, Tail = { 6, 0, 0 } },
		{ 1.04, "smooth", R = { 0, 0, 0, 1 }, Hips = { 1, 0, 0 }, Chest = { 2, 0, 0 }, Head = { -2, 0, 0 }, Tail = { -3, 0, 0 } },
		{ 1.16, "smooth" },
		{ 1.35, "smooth" },
	}),
	limbs = function(tt, ctx)
		ctx.cast = ctx.cast or ctx.base
		local out = {}
		for _, s in { "L", "R" } do
			local x = (s == "L") and -1 or 1
			local tr = ctx["stampTr" .. s]
			if not tr then
				tr = hoofTrack({
					{ 0.00, 0, 1.85 * x, 0.58, -1.30 }, { 0.12, 0.75, 1.80 * x, 1.85, -0.93 }, { 0.30, 1, 1.67 * x, 2.80, -0.10 },
					{ 0.44, 1, 1.57 * x, 3.55, 0.40 }, { 0.50, 1, 1.57 * x, 3.55, 0.40 }, { 0.60, 1, 1.72 * x, 2.25, -0.60 },
					{ 0.68, 1, 1.75 * x, 0.58, -1.65 }, { 0.82, 1, 1.75 * x, 0.58, -1.65 }, { 1.04, 1, 1.85 * x, 0.58, -1.30 }, { 1.16, 0, 1.85 * x, 0.58, -1.30 },
				})
				ctx["stampTr" .. s] = tr
			end
			local v = tr(tt, ctx)
			if v then out["F" .. s] = v end
		end
		return out
	end,
	events = {
		-- 0.00: the warning ring (r 5.0 round its cast pivot, dark rim + amber, 6 scorch ticks), pulses 0.46 / 0.49, gone 0.50
		{ t = 0, fn = function(ctx)
			ctx.cast = ctx.base
			ctx.stampTrL, ctx.stampTrR = nil, nil
			local c = ctx.base.Position
			local ring = A.rock.ring(ctx, c, 5.0, 0, 0.50, 24)
			local ticks = {}
			for i = 1, 6 do
				local a = i / 6 * 2 * pi + 0.3
				table.insert(ticks, strip(ctx, c + Vector3.new(cos(a) * 3.6, 0, sin(a) * 3.6), c + Vector3.new(cos(a) * 4.5, 0, sin(a) * 4.5), 0.16, C3(92, 54, 28)))
			end
			ctx.sound(SND.tumble, c, 0.3, 1.2, 0.3)
			return group({ ring, { step = function(_, t)
				if t >= 0.50 then return false end
				for _, p in ticks do p.Transparency = 0.35 end
				return true
			end, stop = function() for _, p in ticks do p:Destroy() end end } })
		end },
		{ t = 0.24, fn = function(ctx) ctx.sound(SND.shale, ctx.base.Position, 0.45, 1.1, 0.1) end },
		{ t = 0.50, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.6, 0.3) end },
		-- 0.68: both hooves land: the cracked disc (Colossus crack strips round the two hooves, 9 veins), the dust bank (a
		-- low grey ring 0.9 -> 5.0 by 0.89, fading by 1.16), 4 chips; up to 2 Packs / Brutes in 5 get the stun swirl to 1.18
		{ t = 0.68, fn = function(ctx)
			local c = ctx.base * Vector3.new(0, 0, -1.65)
			local g = A.rock.groundAt(ctx, c)
			ctx.sound(SND.shaleBig, g, 1.0, 1.4)
			ctx.sound(SND.stomp, g, 0.6, 1.3)
			-- (audit r1: authored K2 meshes. The crack disc 10 x 0.07 x 10 (0.18 -> 0.68 at 0.08 -> 1 at 0.21, fading 0.44-0.65),
			-- the dust bank 10 x 0.8 x 10 (0.18 -> 0.75 at 0.12 -> 1 at 0.21 -> 1.12 / 0.55 tall at 0.35, gone 0.48); the
			-- Colossus strips stay as supporting cracks)
			local yaw = ctx.base.Rotation
			local fx = { cracks(ctx, g, 9, 2.5, 4.6, 0.12, 0.65, MAGMA, true), A.rock.chips(ctx, g + Vector3.new(0, 0.3, 0), Vector3.yAxis, 4, 0.68, 1.1) }
			table.insert(fx, keyed(ctx, "ramCrackDisc1", Vector3.new(10, 0.07, 10), 0.68,
				{ { 0, 0.18, 1, 0.18, 0.95 }, { 0.08, 0.68, 1, 0.68, 1 }, { 0.21, 1, 1, 1, 0.95 }, { 0.44, 1, 1, 1, 0.35 }, { 0.65, 1, 1, 1, 0 } },
				function(_, sz) return CFrame.new(g + Vector3.new(0, 0.035, 0)) * yaw end))
			table.insert(fx, keyed(ctx, "ramDustBank1", Vector3.new(10, 0.8, 10), 0.68,
				{ { 0, 0.18, 0.30, 0.18, 0.40 }, { 0.12, 0.75, 1, 0.75, 0.60 }, { 0.21, 1, 1, 1, 0.55 }, { 0.35, 1.12, 0.55, 1.12, 0.25 }, { 0.48, 1.12, 0.4, 1.12, 0 } },   -- (r3: 0.60 visible at 0.80)
				function(_, sz) return CFrame.new(g + Vector3.new(0, sz.Y / 2 + 0.08, 0)) * yaw end))
			-- (audit r2: warm grey, not the dark lit-from-above grey; the bank is a ring (open centre) round the cracks)
			for _, e in fx do if e and e.part and e.part.Name == "ramDustBank1" then e.part.Color = C3(195, 180, 165); e.part.Material = Enum.Material.SmoothPlastic end end   -- (r3: lighter)
			dust(ctx, g, 4, 2.2)
			-- the stun: Packs first, then Brutes, at most 2, within 5 of the cast pivot (MOVE TEST: the stand-ins in front)
			local stunned = foes(ctx, 10, 2, PACK)
			ctx.m:SetAttribute("StampStunned", #stunned)
			-- (audit r1: the authored K3 swirl, 1.65 x 0.32 x 1.65, 0.85 over each stunned head, turning +-100 deg, 0.50 s)
			for _, u in stunned do
				local cf, size = u:GetBoundingBox()
				local top = cf.Position + Vector3.new(0, size.Y / 2 + 0.85, 0)
				table.insert(fx, keyed(ctx, "ramStunSwirl1", Vector3.new(1.65, 0.32, 1.65), 0.68,
					{ { 0, 1, 1, 1, 0 }, { 0.08, 1, 1, 1, 1 }, { 0.42, 1, 1, 1, 0.8 }, { 0.50, 1, 1, 1, 0 } },
					function(t) return CFrame.new(top) * CFrame.Angles(0, math.rad(200) * clamp01((t - 0.68) / 0.30) - math.rad(100), 0) end))
			end
			return group(fx)
		end },
		{ t = 1.03, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.35, 2.0, 0.2) end },
	},
}

-- ===================== C. RAM CHARGE (ORDER; lane 0.00-0.85, gallop from 0.85 at 24 studs/s, horns-first hit) =========
local CHARGE_V, CHARGE_MAX = 24, 18
local function chargeDist(ctx, t)
	local c = ctx.charge
	if not c or t < 0.85 then return 0 end
	local e = t - 0.85
	local s = (e < 0.12) and 24 * (0.5 * e * e / 0.12) or (24 * 0.06 + 24 * (e - 0.12))      -- (0.12 s ramp)
	return math.min(s, c.d)
end
A.Charge = {
	boneKeys = true, dur = 2.6, lock = 2.5,
	keys = ramKeys({
		{ 0.00, "smooth", Head = { 3, 0, 0 } },
		{ 0.20, "smooth", R = { 0, 0, 0, -2 }, Chest = { -4, 0, 0 }, Head = { -7, 0, 0 }, Tail = { 7, 0, 0 } },
		{ 0.46, "smooth", R = { 0, 0, 0, -4 }, Hips = { 3, 0, 0 }, Chest = { -9, 0, 0, 0, -0.08 }, Head = { -19, 0, 0 }, Tail = { 10, 0, 0 } },
		{ 0.85, "smooth", R = { 0, 0, 0, -5 }, Hips = { 4, 0, 0 }, Chest = { -10, 0, 0 }, Head = { -18, 0, 0 }, Tail = { 15, 0, 0 } },
		{ 2.6, "smooth", R = { 0, 0, 0, -5 }, Hips = { 4, 0, 0 }, Chest = { -10, 0, 0 }, Head = { -18, 0, 0 }, Tail = { 15, 0, 0 } },
	}),
	-- (the impact recoil / skid keys ride on top, relative to tBrake: extra)
	extra = function(t, p, ctx)
		local c = ctx and ctx.charge
		if not c or not c.tB then
			-- (the gallop bob while running, 0.17 max)
			if t > 0.85 then p.root[1] += 0.12 * math.abs(sin((t - 0.85) * pi * 6)) end      -- (audit r2: <= 0.35 lift)
			return
		end
		local tau = t - c.tB
		local function k(a, b, u) return a + (b - a) * smooth(u) end
		local R4, Ch, Hd, Hp, Tl
		if tau < 0.12 then local u = tau / 0.12; R4, Ch, Hd, Hp, Tl = k(2, -8, u), k(7, -10, u), k(12, 7, u), k(0, -5, u), k(-12, 0, u)
		elseif tau < 0.27 then local u = (tau - 0.12) / 0.15; R4, Ch, Hd, Hp, Tl = k(-8, -4, u), k(-10, -5, u), k(7, 3, u), k(-5, -2, u), 0
		elseif tau < 0.36 then local u = (tau - 0.27) / 0.09; R4, Ch, Hd, Hp, Tl = k(-4, 0, u), k(-5, 0, u), k(3, 0, u), k(-2, 0, u), 0
		else R4, Ch, Hd, Hp, Tl = 0, 0, 0, 0, 0 end
		-- (relative to the charge pose: its -5 / -10 / -18 / +4 / +15 are taken back over the brake)
		local back = smooth(tau / 0.36)
		p.root[4] += R4 + 5 * back
		local C, H, P, T = p.bones.Chest, p.bones.Head, p.bones.Hips, p.bones.Tail
		if C then C[1] += Ch + 10 * back end
		if H then H[1] += Hd + 18 * back end
		if P then P[1] += Hp - 4 * back end
		if T then T[1] += Tl - 15 * back end
	end,
	-- the paw (FL, or FR when the target bears right): up 0.22 and forward 0.35 at 0.20, down at 0.38, planted by 0.52
	limbs = function(tt, ctx)
		local c = ctx.charge
		if not c or tt > 0.62 then return nil end
		ctx.cast = ctx.cast or ctx.base
		local x = (c.paw == "L") and -1 or 1
		c.pawTr = c.pawTr or hoofTrack({ { 0.00, 0, 1.85 * x, 0.58, -1.30 }, { 0.20, 1, 1.85 * x, 0.80, -1.65 }, { 0.38, 1, 1.85 * x, 0.58, -1.66 }, { 0.52, 1, 1.85 * x, 0.58, -1.66 }, { 0.62, 0, 1.85 * x, 0.58, -1.66 } })
		local v = c.pawTr(tt, ctx)
		return v and { ["F" .. c.paw] = v } or nil
	end,
	-- the whole unit runs the line (MOVE TEST: client-side; in a match the server moves it), skids 0.27 after the brake
	place = function(ctx, t)
		local c = ctx.charge
		if not c or t < 0.85 then return nil end
		local s = chargeDist(ctx, t)
		if not c.tB and s >= c.d - 1e-3 then c.tB = t end
		local skid = c.tB and math.min(0.6, 0.6 * smooth((t - c.tB) / 0.27)) or 0
		local p = c.from + c.dir * (s + skid)
		local g = Vector3.new(p.X, ctx.ground(p.X, p.Z) + c.hover, p.Z)
		return CFrame.lookAt(g, g + c.dir)
	end,
	travel = function(ctx, t)
		local c = ctx.charge
		if not c or t < 0.85 then return nil end
		local s = chargeDist(ctx, t) + (c.tB and math.min(0.6, 0.6 * smooth((t - c.tB) / 0.27)) or 0)
		local function at(d)
			local p = c.from + c.dir * d
			return CFrame.lookAt(Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z), Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z) + c.dir)
		end
		-- (the gallop's leg timing: the Ram's run gait (its feet swing and plant along the line))
		local G = require(script.Parent:WaitForChild("Gaits"))
		return s, at, (c.tB ~= nil and t > c.tB + 0.27), G.CrunchF3v5Run and G.CrunchF3v5Run.ik
	end,
	events = {
		-- 0.00: the target (the nearest foe ahead, never a Titan), the run distance d (to 0.35 short of its face from the
		-- hook, <= 18), the lane (6.4 wide, d long; 4 chevrons; fill 0-0.60, pulses 0.77 / 0.82, gone 0.85)
		{ t = 0, fn = function(ctx)
			ctx.cast = ctx.base
			local m = ctx.m
			local t = foes(ctx, 26, 1)[1]
			local dir = ctx.base.LookVector * Vector3.new(1, 0, 1)
			local d = CHARGE_MAX
			if t then
				local v = (t:GetPivot().Position - ctx.base.Position) * Vector3.new(1, 0, 1)
				if v.Magnitude > 0.1 then dir = v.Unit end
				local hookAhead = 5.4                                                   -- (the hooks 5.3-5.5 ahead of the pivot)
				local face = faceOf(t, ctx.base.Position)
				d = math.clamp(((face - ctx.base.Position) * Vector3.new(1, 0, 1)).Magnitude - hookAhead - 0.05, 0, CHARGE_MAX)
			end
			dir = dir.Unit
			ctx.charge = { t = t, d = d, dir = dir, from = ctx.base.Position, hover = ctx.base.Y - ctx.ground(ctx.base.X, ctx.base.Z),
				paw = (ctx.base:VectorToObjectSpace(dir).X > 0.1) and "R" or "L" }
			m:SetAttribute("ChargeD", d)
			ctx.sound(SND.tumble, ctx.base.Position, 0.45, 1.0, 0.3)
			return A.rock.lane(ctx, ctx.base.Position, dir, math.max(2, d + 5.5), 3.2, 0, 0.85)
		end },
		{ t = 0.20, fn = function(ctx) dust(ctx, A.rock.groundAt(ctx, ctx.base * Vector3.new(-1.85, 0, -1.65)), 1, 0.9) end },
		{ t = 0.38, fn = function(ctx) dust(ctx, A.rock.groundAt(ctx, ctx.base * Vector3.new(-1.85, 0, -1.65)), 2, 1.1); ctx.sound(SND.tumble, ctx.base.Position, 0.3, 2.4, 0.1) end },
		-- 0.85: the run: a dust ribbon behind the hooves (3 lobed puddle segments riding / left behind) + 2 amber speed
		-- streaks along its flanks; the rushing rasp; hoof beats every 0.17 s
		{ t = 0.85, fn = function(ctx)
			local c = ctx.charge
			if not c then return end
			ctx.sound(SND.avalanche, ctx.base.Position, 0.45, 1.8, 0.3)
			-- (audit r1: the authored K4 meshes. Dust ribbon 4.8 x 1.25 x 7.0 behind the hooves, z 0.25 -> 1 by +0.12, a
			-- 0.94-1.06 wobble, fading over 0.55 after the brake; speed streaks 4.5 x 1.0 x 5.8 (3 orange + 2 grey arcs),
			-- full by +0.12, length pulsing 0.85-1.15, gone 0.16 after the impact. Both follow the TRAVEL line, not the yaw)
			local look = CFrame.lookAt(Vector3.zero, -c.dir).Rotation                     -- (the meshes' +z = behind)
			local dust = gmR(ctx, "ramChargeDust1", Vector3.new(4.8, 1.25, 7.0), CFrame.new())
			local sO = gmR(ctx, "ramStreaksO1", Vector3.new(4.5, 1.0, 5.8), CFrame.new())
			local sG = gmR(ctx, "ramStreaksG1", Vector3.new(2.45, 0.45, 5.8), CFrame.new())
			for _, p in { dust, sO, sG } do if p then p.Transparency = 1 end end
			if dust then dust.Color, dust.Material = C3(175, 160, 145), Enum.Material.SmoothPlastic end   -- (r3: matte warm grey, not black slabs)
			local lastBeat = 0.85
			return { step = function(_, t)
				local tB = c.tB or 99
				if t > tB + 0.64 then return false end
				local e = t - 0.85
				local pv = ctx.m:GetPivot()
				-- (audit r2: the hind-hoof midpoint is 3.30 behind the pivot; the ribbon's centre 3.5 behind that, lower edge 0.10 up)
				local hind = Vector3.new(pv.X, ctx.ground(pv.X, pv.Z), pv.Z) - c.dir * 3.30
				local back = hind - c.dir * 3.5
				if dust then
					local zs = 0.25 + 0.75 * smooth(e / 0.12)
					local wob = 1 + 0.06 * sin(t * 23)
					dust.Size = Vector3.new(4.8 * wob, 1.25, 7.0 * zs)
					dust.CFrame = CFrame.new(back + Vector3.new(0, dust.Size.Y / 2 + 0.10, 0)) * look * YAW180   -- (centred 3.5 behind, lower edge 0.10 up)
					dust.Transparency = (t < tB) and (1 - 0.62 * smooth(e / 0.12)) or (0.38 + 0.62 * smooth((t - tB) / 0.55))   -- (r3: 0.62 visible)
				end
				for i, p in { sO, sG } do
					if p then
						local full = (i == 1) and Vector3.new(4.5, 1.0, 5.8) or Vector3.new(2.45, 0.45, 5.8)
						local pul = 1 + 0.15 * sin(t * 17 + i)
						p.Size = Vector3.new(full.X, full.Y, full.Z * (0.3 + 0.7 * smooth(e / 0.12)) * pul)
						-- (along the rear flanks: their front ends at the hind hooves, trailing back)
						p.CFrame = CFrame.new(hind + Vector3.new(0, 1.0, 0)) * look * CFrame.new(0, 0, -p.Size.Z / 2) * YAW180
						p.Transparency = (t < tB) and (1 - 0.85 * smooth(e / 0.12)) or (0.15 + 0.85 * smooth((t - tB) / 0.16))
					end
				end
				if t < tB and t - lastBeat > 0.17 then lastBeat = t; ctx.sound(SND.tumble, pv.Position, 0.25, 2.2, 0.1) end
				return true
			end, stop = function() for _, p in { dust, sO, sG } do if p then p:Destroy() end end end }
		end },
		-- the hit (at the brake, on a real target only): the gore burst x1.35 at the hook, 4 chips, CRACK, side dust
		{ t = 0.86, fn = function(ctx)
			local c = ctx.charge
			if not c or not c.t then return end
			local done = false
			local fx = {}
			table.insert(fx, { step = function(_, t)
				if done then return false end
				if c.tB and t >= c.tB then
					done = true
					local p, n = faceOf(c.t, ctx.m:GetPivot().Position, ctx.m:GetPivot().Y + 3.0)
					ctx.sound(SND.glass, p, 1.0, 1.3)
					ctx.sound(SND.shaleBig, p, 0.8, 1.6)
					table.insert(fx, goreBurst(ctx, p + n * 0.08, n, t, 1.35))
					dust(ctx, A.rock.groundAt(ctx, p), 3, 1.8)
					ctx.m:SetAttribute("ChargeHit", true)
				end
				return true
			end, stop = function() end })
			return group(fx)
		end },
	},
}

-- ===================== HURT (0.52, additive; keys for a hit on its LEFT shoulder (-X), staggering it toward +X) =========
A.RamHurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,
	keys = ramKeys({
		{ 0.00, "smooth" },
		{ 0.09, "out", R = { 0, 0.12, 0, 0, -4 }, Chest = { 0, 0, -7, 0.10 }, Hips = { 0, 0, -3, 0.06 }, Head = { 0, 11, -7 }, Tail = { 0, 0, 5 } },
		{ 0.18, "out", R = { 0, 0.24, 0, 0, -7 }, Chest = { 0, 0, -11, 0.17 }, Hips = { 0, 0, -5, 0.10 }, Head = { 0, 16, -10 }, Tail = { 0, 0, 9 } },
		{ 0.31, "smooth", R = { 0, -0.07, 0, 0, 2.5 }, Chest = { 0, 0, 4, -0.05 }, Hips = { 0, 0, 2, -0.03 }, Head = { 0, -5, 4 }, Tail = { 0, 0, -4 } },
		{ 0.43, "smooth", R = { 0, 0.02, 0, 0, -1 }, Chest = { 0, 0, -2, 0.02 }, Hips = { 0, 0, -1 }, Head = { 0, 2, -1 }, Tail = { 0, 0, 2 } },
		{ 0.52, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local p = ctx.base * Vector3.new((out:Dot(ctx.base.RightVector) > 0) and 2.4 or -2.4, 3.6, -1.6)
			ctx.sound(SND.shale, p, 0.6, 2.0, 0.1)
			sparks(ctx, p, 2, 5)
			return A.rock.chips(ctx, p, out, 3, 0.02, 1.0)
		end },
		{ t = 0.40, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.25, 2.4, 0.2) end },
	},
}

-- ===================== DEFEAT (3.65, terminal): stagger, knees buckle, falls on its side, breaks; horns + FOUR motes ====
A.RamDefeat = {
	boneKeys = true, dur = 3.65,
	keys = ramKeys({
		{ 0.00, "smooth", Head = { -8, 0, 0 } },
		{ 0.35, "smooth", R = { -0.10, 0, 0, -5, 2 }, Chest = { -11, 0, 3, 0, -0.10 }, Hips = { -4, 0, 1, 0, -0.03 }, Head = { -17, 2, 3 }, Tail = { -9, 0, 0 } },
		{ 0.85, "in", R = { -0.40, 0, 0, -12, 5 }, Chest = { -18, 0, 7, 0, -0.25 }, Hips = { -8, 0, 3, 0, -0.10 }, Head = { -22, 5, 6 }, Tail = { -15, 0, 0 } },
		{ 1.30, "in", R = { -0.63, 0, 0, -16, 20 }, Chest = { -23, 0, 13, 0, -0.34 }, Hips = { -12, 0, 9, 0, -0.20 }, Head = { -18, 9, 15 }, Tail = { -18, 0, 0 } },
		-- (audit r1: broadside, not curled: roll 75 at 1.75 (was 54), the torso kept long)
		{ 1.75, "in", R = { -0.67, 0, 0, -8, 75 }, Chest = { -8, 0, 16, 0, -0.34 }, Hips = { -6, 0, 18, 0, -0.20 }, Head = { -10, 12, 22 }, Tail = { -12, 0, 0 } },
		{ 3.65, "smooth", R = { -0.67, 0, 0, -8, 75 }, Chest = { -8, 0, 16, 0, -0.34 }, Hips = { -6, 0, 18, 0, -0.20 }, Head = { -10, 12, 22 }, Tail = { -12, 0, 0 } },
	}),
	extra = function(t, p)
		local flick = (t < 1.5) and (0.6 + 0.4 * sin(t * 29) * sin(t * 9)) or 1
		local flash = (t > 1.50 and t < 1.75) and 1.8 or 1
		p.glowMul = flick * flash * (1 - smooth((t - 2.12) / 0.4))
	end,
	-- (lying on its side: the body rolls 75 deg; it is lifted so its flank rests on the ground (spec 6.1: no mesh deeper than
	-- 0.08): 1.6 up at full roll on the rig's 2.9 half-width)
	place = function(ctx, t)
		local u = smooth(clamp01((t - 0.85) / 0.9))
		return ctx.base + Vector3.new(0, 1.6 * u * u, 0)
	end,
	-- (audit r1: the hind legs stood up out of the fallen body: from 0.85 all four hooves are pulled in under the body
	-- (folded, in the cast frame), so the highest hoof stays <= 2.2 over the ground)
	limbs = function(tt, ctx)
		if tt < 0.85 then return nil end
		local w = smooth((tt - 0.85) / 0.45)
		local out = {}
		for _, k in { { "FL", -0.6, 0.9, -1.0 }, { "FR", 0.6, 0.9, -1.0 }, { "BL", -0.6, 0.9, 2.2 }, { "BR", 0.4, 0.8, 2.0 } } do
			local p = ctx.base * Vector3.new(k[2], 0, k[4])
			out[k[1]] = { p = Vector3.new(p.X, ctx.ground(p.X, p.Z) + k[3], p.Z), w = w, raw = true }
		end
		return out
	end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.castAt = os.clock()
			ctx.defeatWas = {}
			local replay = ctx.m:GetAttribute("MoveTest")
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then
					if replay then d.LocalTransparencyModifier = 0 end
					ctx.defeatWas[d] = d.LocalTransparencyModifier
				end
			end
			ctx.sound(SND.tumble, ctx.base.Position, 0.5, 0.9, 0.3)
		end },
		{ t = 0.84, fn = function(ctx) ctx.sound(SND.shale, ctx.base.Position, 0.7, 0.9, 0.2); dust(ctx, A.rock.groundAt(ctx, ctx.base * Vector3.new(0, 0, -1.6)), 2, 1.8) end },
		-- 1.65 the split: the rig goes 1.75-2.12 under dust; the rubble (its own mesh, flattened, 8.8 x 1.5 x 6.3 along its
		-- fallen body) and its two REAL horns (tipping 40-85 deg, arcing out to land 2.6 apart by 2.48) take its place; the
		-- glow 0.60 at 2.12 -> 0.15 at 2.48 -> 0 at 3.00
		{ t = 1.65, fn = function(ctx)
			local m = ctx.m
			ctx.sound(SND.shaleBig, ctx.base.Position, 0.9, 1.1)
			local base = ctx.base
			local fx = {}
			local hidden, was, done = {}, ctx.defeatWas or {}, false
			for _, d in m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); if was[d] == nil then was[d] = d.LocalTransparencyModifier end end end
			table.insert(fx, { step = function(_, t)
				if t >= 2.12 then done = true end
				local gone = smooth((t - 1.75) / 0.37)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], gone) end end
				return t <= 3.65
			end, stop = function() if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end end })
			table.insert(fx, { step = function(_, t) if t > 1.78 and not ctx.dustDone then ctx.dustDone = true; dust(ctx, A.rock.groundAt(ctx, base.Position), 4, 3.0) end; return t < 1.9 end, stop = function() end })
			-- (audit r1: a flattened intact shell is not rubble: the transition = 9 big masses cut from its mesh (7.5 x 2.8 x
			-- 5.5, in 1.72 -> 1.85, squashed to 0.72 tall by 2.22, out by 2.48), the pile = 14 boulders (8.8 x 1.5 x 6.3, 0.86
			-- -> 1.0 across 2.12-2.48, 0.9 tall), both from its own skin)
			local mid = gmR(ctx, "ramRubbleMid1", Vector3.new(5.5, 2.8, 7.5), CFrame.new())
			if mid then mid.Transparency = 1 end
			table.insert(fx, { step = function(_, t)
				if not mid then return false end
				if t > 2.5 then mid.Transparency = 1; return t <= 3.65 end
				local ys = 1 - 0.28 * smooth((t - 1.85) / 0.37)
				mid.Size = Vector3.new(5.5, 2.8 * ys, 7.5)
				mid.CFrame = base * CFrame.new(0.4, mid.Size.Y / 2, 0.2) * YAW180
				mid.Transparency = (t < 1.72) and 1 or (t < 1.85) and (1 - smooth((t - 1.72) / 0.13)) or smooth((t - 2.30) / 0.18)
				return true
			end, stop = function() if mid then mid:Destroy() end end })
			local rub = gmR(ctx, "ramRubblePile1", Vector3.new(6.3, 1.5, 8.8), CFrame.new())
			local sa = rub and rub:FindFirstChildWhichIsA("SurfaceAppearance")
			local sa0 = sa and sa.Color
			local horns = {}
			for _, s in { "L", "R" } do
				local h = gmR(ctx, "ramHorn" .. s .. "1")
				if h then
					h.Transparency = 1
					table.insert(horns, { p = h, rest = base * CFrame.new(CENTRE["ramHorn" .. s]) * YAW180, side = (s == "L") and -1 or 1, tip = (s == "L") and 70 or 55 })
				end
			end
			table.insert(fx, { step = function(_, t)
				if t > 3.65 then return false end
				if rub then
					local u = smooth((t - 2.12) / 0.36)
					rub.Size = Vector3.new(6.3 * (0.86 + 0.14 * u), 1.5 * (1 - 0.1 * u), 8.8 * (0.86 + 0.14 * u))
					rub.CFrame = base * CFrame.new(0.4, rub.Size.Y / 2, 0.2) * YAW180
					rub.Transparency = (t < 2.12) and 1 or (1 - smooth((t - 2.12) / 0.20))
					-- (the glow dies, the rock stays grey: the skin darkens to 0.5, not black (it read as a black hole, measured))
					if sa and sa0 then local k = 1 - 0.3 * smooth((t - 2.12) / 0.36) - 0.2 * smooth((t - 2.48) / 0.52); sa.Color = Color3.new(sa0.R * k, sa0.G * k, sa0.B * k) end
				end
				for _, h in horns do
					local u = smooth((t - 1.78) / 0.70)
					local arc = sin(u * pi) * 0.8
					-- (from its place on the fallen head to the ground beside the pile: out along the Ram's OWN side axis (a world-X
					-- push put both horns in the middle, measured), +-1.4 + 0.2 = about 3 apart, the spec's ~2.6)
					local out = base:VectorToWorldSpace(Vector3.new(h.side * 0.2 * u, 0, 0))
					local drop = -2.6 * u
					h.p.CFrame = CFrame.new(out + Vector3.new(0, drop + arc, 0)) * h.rest * CFrame.Angles(math.rad(h.tip * u) * 0.4, 0, math.rad(h.tip * u) * h.side)
					h.p.Transparency = (t < 1.78) and 1 or 0
				end
				return true
			end, stop = function() if rub then rub:Destroy() end; for _, h in horns do h.p:Destroy() end end })
			return group(fx)
		end },
		{ t = 2.13, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.6, 1.4, 0.2) end },
		-- exactly FOUR motes from 2.72, rising 2.7-3.25 by 3.52, gone 3.65
		{ t = 2.72, fn = function(ctx)
			if ctx.moteAt == ctx.castAt and ctx.castAt then return end
			ctx.moteAt = ctx.castAt
			ctx.sound(SND.glass, ctx.base.Position, 0.45, 2.0, 0.5)
			return A.rock.motes(ctx, A.rock.groundAt(ctx, ctx.base.Position) + Vector3.new(0, 1.4, 0), 4, 2.72, 3.65, ctx.home, Vector3.new(0.30, 0.40, 0.28), 2.9)
		end },
	},
}
A.FOR.CrunchF3v5 = { Gore = A.Gore, Stamp = A.Stamp, Charge = A.Charge, Defeat = A.RamDefeat, Hurt = A.RamHurt }
for _, atk in { A.Gore, A.Stamp, A.Charge, A.RamHurt, A.RamDefeat } do table.sort(atk.events, function(x, y) return x.t < y.t end) end
end

end
