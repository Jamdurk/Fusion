-- Alien Fusion: attack animations + their effects and sounds (James, 27 Oct: "give him 3 animation attacks", tested on
-- the Colossus v4 pilot first; spec design/07-COLOSSUS-V4-ATTACKS-SPEC.md, ChatGPT GO). Client-side visuals only: the
-- AlienAnimator plays an attack from the unit's attributes (server time), so every client sees the same thing; hits,
-- damage and targets will be the server's.
--   keys: poses by time. R = whole body (lift / side / fwd studs, pitch deg); H/B/C/N = hips / belly / chest / head
--   pitch, + = bending FORWARD (ChatGPT's tables); yaw = hips / belly / chest / head turn, + = to the left; arms /
--   hands L, R: + = swung forward / up. ease = how the pose arrives at this key: "out" (anticipation, fast then
--   slowing), "in" (a strike, slow then fast), "smooth".
--   ik(t, ctx) -> weight, targetL, targetR: arms reaching for world points (the gauntlets' tips) over the posed arms.
--   events: { t, fn(ctx) } fired once per play; an effect can return an object with :step(t) (false = finished) and
--   :stop() (cleans up).
--   (AI test attack commit, 29 Oct) ownership for a thrown / summoned attack whose caster falls after the release: an
--   event tagged `world = true` belongs to the released projectile / hazard (it still fires, its effect plays on); an
--   effect made earlier that BECOMES the projectile says `worldAt = <release time>`. Everything else is the body's and
--   stops with it.
local A = {}
local sin, cos, pi, rad = math.sin, math.cos, math.pi, math.rad
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x); return x * x * (3 - 2 * x) end
local NS, NR, CS, C3 = NumberSequence.new, NumberRange.new, ColorSequence.new, Color3.fromRGB
local SMOKE, SPARK, FIRE = "rbxasset://textures/particles/smoke_main.dds", "rbxasset://textures/particles/sparkles_main.dds", "rbxasset://textures/particles/fire_main.dds"
local function curve(a, b, c) return NS({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) }) end
local AMBER, MAGMA, BASALT = C3(255, 170, 40), C3(255, 110, 25), C3(117, 111, 105)

-- ===== sounds: ProSoundEffects (Roblox's free licensed library). Loudness measured in Studio (PlaybackLoudness)
local SND = {
	stomp = "9125404774",    -- Boomy Footsteps, Giant, Thumpy 2: instant hit + 2.5 s rumble
	shale = "9119037874",    -- Shale Break 15: huge blast, slam, shatter, low end (0.8 s)
	shaleBig = "9119042093", -- Shale Break 12: huge sharp rocks slam, shatter, tumbling (2 s)
	glass = "9114592102",    -- Glass Breaks 11: breaks, hits and bounces, debris shards (2.2 s)
	quake = "9114221862",    -- Earthquake Debris, Rock Burst, Scattering, Rumbling, Crackling (5.4 s)
	avalanche = "9113220118",-- Avalanche, Huge Explosive Boulders, Rock Debris Crashing (7.7 s)
	tumble = "9118693444",   -- Rocks Tumble, Rubble Loosens, Falls (2.9 s)
	power = "9117876319",    -- Power Explosion, Big, Heavy, Searing, Boom (5.8 s)
	lava = "9112823552",     -- Lava Rumble, Thick, Rumbling, Eruptive, Loop (46 s): the sun's charge + the burn
	whoosh = "9120724273",   -- Whoosh, Giant Swish By (2.9 s)
}
A.SOUNDS = SND

-- ===== the client-wide FX budget (ChatGPT batch-1 audit): a rolling 1 s particle limit of 34, at most 2 lights and 24
-- fragments (cloned rock / crystal props) alive, across every unit. Danger shapes are never counted or cut; spectacle is.
-- (The one-camera-shake rule lives in the animator's shakeAt.)
local BUDGET = { particles = 34, lights = 2, frags = 24 }
local spent, streams, lights, frags = {}, {}, {}, {}
local function alive(list) for i = #list, 1, -1 do if not list[i].Parent then table.remove(list, i) end end return #list end
local function particlesLeft()
	local now, used = os.clock(), 0
	for i = #spent, 1, -1 do if now - spent[i][1] > 1 then table.remove(spent, i) else used += spent[i][2] end end
	for i = #streams, 1, -1 do local e = streams[i]; if not e.Parent then table.remove(streams, i) elseif e.Enabled then used += e.Rate end end
	return BUDGET.particles - used
end
local function takeParticles(n)
	local k = math.clamp(math.floor(particlesLeft()), 0, n)
	if k > 0 then table.insert(spent, { os.clock(), k }) end
	return k
end
-- a continuous emitter: its Rate counts against the budget every second (capped to what is left when it starts)
local function stream(e) e.Rate = math.min(e.Rate, math.max(0, particlesLeft())); table.insert(streams, e); return e end
-- a light, if fewer than 2 are alive (else nil: callers skip it)
local function newLight(parent, color, range, brightness)
	if alive(lights) >= BUDGET.lights then return nil end
	local l = Instance.new("PointLight"); l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false; l.Parent = parent
	table.insert(lights, l)
	return l
end
-- fragment clones of a prop, as many as the budget allows
local function fragsLeft() return BUDGET.frags - alive(frags) end
local function frag(tmpl) if fragsLeft() <= 0 then return nil end; local c = tmpl:Clone(); table.insert(frags, c); return c end   -- (nil when the budget is full)
-- a scripted (non-cloned) loose piece takes a fragment slot too; nil when the budget is full (audit r1, batch 2)
local function claimFrag(p) if fragsLeft() <= 0 then p:Destroy(); return nil end; table.insert(frags, p); return p end
A.budgetStats = function() return { particles = BUDGET.particles - particlesLeft(), lights = alive(lights), frags = alive(frags) } end

-- a short-lived part in the effects folder
local function part(ctx, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do (p :: any)[k] = v end
	p.Parent = ctx.holder
	return p
end
local function emitterAt(ctx, pos, props, n)
	local p = part(ctx, { Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos) })
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in props do (e :: any)[k] = v end
	e.Parent = p
	n = takeParticles(n)                          -- (the shared budget may cut a burst, never a danger shape)
	if n > 0 then e:Emit(n) end
	game:GetService("Debris"):AddItem(p, 3)
end
local function dust(ctx, pos, n, size)
	emitterAt(ctx, pos, { Texture = SMOKE, Lifetime = NR(0.45, 0.75), Speed = NR(2.5, 5.5), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -3, 0), Drag = 2.5, Size = curve(0.7, size or 2.4, size and size * 1.3 or 3.0),
		Transparency = curve(0.2, 0.5, 1), Color = CS(BASALT), Rotation = NR(0, 360), RotSpeed = NR(-50, 50),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume }, n)
end
local function sparks(ctx, pos, n, speed)
	emitterAt(ctx, pos, { Texture = SPARK, Lifetime = NR(0.3, 0.6), Speed = NR(speed or 4, (speed or 4) * 2), SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1, Size = curve(0.5, 0.35, 0), Color = CS(C3(255, 220, 120), MAGMA), Acceleration = Vector3.new(0, -6, 0), Drag = 1 }, n)
end

-- the camera-ground frame for a point `fwd` studs ahead and `right` studs to the right of the unit, on the ground
local function ahead(ctx, fwd, right)
	local p = ctx.base * Vector3.new(right or 0, 0, -fwd)
	return Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
end

-- glowing cracks running out over the ground from `centre` (n lines, lengths r0..r1, grown over `grow` seconds)
local function cracks(ctx, centre, n, r0, r1, grow, life, color, glow)
	local lines = {}
	for i = 1, n do
		local a = (i / n) * 2 * pi + (math.random() - 0.5) * 0.5
		lines[i] = { a = a, len = r0 + math.random() * (r1 - r0), w = 0.18 + math.random() * 0.2,
			p = part(ctx, { Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic, Color = color, Size = Vector3.new(0.2, 0.06, 0.1) }) }
	end
	local t0
	return { step = function(self, t)
		t0 = t0 or t
		local e = t - t0
		if e > life then return false end
		local k = smooth(e / grow)
		local fade = smooth((e - (life - 0.4)) / 0.4)
		for _, l in lines do
			local len = math.max(0.1, l.len * k)
			local dir = Vector3.new(cos(l.a), 0, sin(l.a))
			local mid = centre + dir * (len / 2 + 0.6)
			l.p.Size = Vector3.new(l.w, 0.06, len)
			l.p.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.04, 0), mid + dir + Vector3.new(0, 0.04, 0))
			l.p.Transparency = fade
		end
		return true
	end, stop = function() for _, l in lines do l.p:Destroy() end end }
end

-- ===== danger shapes (power graph 09 §3; ChatGPT batch-1 spec, design/12-COLOSSUS-BATCH1-SPEC.md) =====
-- CRUNCH language: wedges, cracks, straight lines. The WHOLE hit boundary shows from the first frame (it never shrinks
-- or moves); then it fills and pulses toward the hit. Emissive flat strips on the ground, no lights.
local W_AMBER, W_MAGMA, W_WHITE = C3(255, 170, 40), C3(255, 110, 25), C3(255, 230, 160)
local function onGround(ctx, p) return Vector3.new(p.X, ctx.ground(p.X, p.Z) + 0.07, p.Z) end
-- a flat strip on the ground from a to b
local function strip(ctx, a, b, w, color, h)
	a, b = onGround(ctx, a), onGround(ctx, b)
	local len = math.max(0.05, (b - a).Magnitude)
	return part(ctx, { Material = Enum.Material.Neon, Color = color, Transparency = 1, Size = Vector3.new(w, h or 0.06, len),
		CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit) })
end
local W_UNDER = C3(40, 32, 27)
-- an outline line with a dark, wider, non-glowing edge under it (audit: the amber alone washed out on sunlit ground)
local function edge(ctx, list, a, b, w)
	local under = strip(ctx, a, b, w + 0.3, W_UNDER, 0.05)
	under.Material = Enum.Material.SmoothPlastic
	under.CFrame -= Vector3.new(0, 0.04, 0)                   -- (clearly under the amber line: no flicker)
	table.insert(list, under)
	table.insert(list, strip(ctx, a, b, w, W_AMBER, 0.07))
end
local function setT(list, tr) for _, p in list do p.Transparency = tr end end
local function pulse(t, t0, n, dur) local u = clamp01((t - t0) / dur); return 0.5 - 0.5 * cos(u * n * 2 * pi) end

-- GROUND SHATTER: a 120-degree wedge from the body out to 16 studs. Shows at tShow, hit at tHit
local function dangerWedge(ctx, centre: Vector3, face: Vector3, tShow, tHit)
	local R0, R1, HALF, N = 6, 16, rad(60), 12
	local function dir(a) local c, s = cos(a), sin(a); return Vector3.new(face.X * c - face.Z * s, 0, face.X * s + face.Z * c) end
	local outline, dim, hot, cracksL = {}, {}, {}, {}
	for i = 0, N - 1 do
		local a0, a1 = -HALF + 2 * HALF * i / N, -HALF + 2 * HALF * (i + 1) / N
		edge(ctx, outline, centre + dir(a0) * R1, centre + dir(a1) * R1, 0.32)
		local am, wmid = (a0 + a1) / 2, 2 * HALF / N
		-- (the area: a fan of tiles, one per slice; dim = the whole hit area, hot = the fill that advances)
		-- (two bands, each as wide as its outer chord: no gaps at the rim, little overlap at the centre)
		table.insert(dim, strip(ctx, centre + dir(am) * 2, centre + dir(am) * 9, wmid * 9 + 0.2, W_AMBER, 0.03))
		table.insert(dim, strip(ctx, centre + dir(am) * 9, centre + dir(am) * R1, wmid * R1 + 0.2, W_AMBER, 0.03))
		table.insert(hot, { a = am, w = wmid })
	end
	edge(ctx, outline, centre + dir(-HALF) * 2, centre + dir(-HALF) * R1, 0.32)
	edge(ctx, outline, centre + dir(HALF) * 2, centre + dir(HALF) * R1, 0.32)
	for i = 1, 6 do                                             -- six straight fracture lines pointing out
		local a = -HALF + 2 * HALF * (i - 0.5) / 6 + (math.random() - 0.5) * 0.12
		table.insert(cracksL, strip(ctx, centre + dir(a) * (R0 + 1), centre + dir(a) * (R1 - 0.8), 0.14, W_WHITE))
	end
	local fill = {}
	for i, h in hot do fill[i] = strip(ctx, centre, centre + dir(h.a) * R0, h.w * R0 + 0.2, W_MAGMA, 0.045) end
	return { step = function(_, t)
		if t >= tHit then return false end
		local e = t - tShow
		local front = R0 + (R1 - R0) * smooth(e / 1.0)          -- (the progress front, not a changing hit radius)
		for i, h in hot do
			local p = fill[i]
			local a, b = onGround(ctx, centre), onGround(ctx, centre + dir(h.a) * front)
			p.Size = Vector3.new(h.w * front + 0.2, 0.045, (b - a).Magnitude)
			p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit)
		end
		local pl = (t > tHit - 0.2) and pulse(t, tHit - 0.2, 2, 0.2) or 0
		setT(outline, 0.1 - 0.1 * pl)
		setT(dim, 0.82 - 0.25 * pl)
		setT(fill, 0.55 - 0.3 * pl)
		setT(cracksL, (t > tHit - 0.2) and 0.15 or 1)
		return true
	end, stop = function() for _, l in { outline, dim, fill, cracksL } do for _, p in l do p:Destroy() end end end }
end

-- BOULDER HURL: a jagged octagon (true radius 4), four inward fracture marks and a strike cross
local function dangerJagged(ctx, centre: Vector3, r, tShow, tHit)
	local outline, marks = {}, {}
	local pts = {}
	local ro = r / cos(pi / 8)                              -- (circumscribed: the whole radius-4 circle is inside)
	for i = 0, 7 do
		local a = i / 8 * 2 * pi + (math.random() - 0.5) * 0.06
		pts[i] = centre + Vector3.new(cos(a) * ro, 0, sin(a) * ro)
	end
	for i = 0, 7 do edge(ctx, outline, pts[i], pts[(i + 1) % 8], 0.36) end
	for i = 0, 3 do
		local a = i / 4 * 2 * pi + pi / 4
		marks[i + 1] = strip(ctx, centre + Vector3.new(cos(a) * r, 0, sin(a) * r), centre + Vector3.new(cos(a) * r * 0.45, 0, sin(a) * r * 0.45), 0.18, W_WHITE)
	end
	local cross = { strip(ctx, centre + Vector3.new(-0.9, 0, 0), centre + Vector3.new(0.9, 0, 0), 0.2, W_WHITE),
		strip(ctx, centre + Vector3.new(0, 0, -0.9), centre + Vector3.new(0, 0, 0.9), 0.2, W_WHITE) }
	local g = onGround(ctx, centre)
	local disc = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = W_AMBER, Transparency = 1,
		Size = Vector3.new(0.04, r * 2, r * 2), CFrame = CFrame.new(g) * CFrame.Angles(0, 0, pi / 2) })
	return { step = function(_, t)
		if t >= tHit then return false end
		local e = t - tShow
		local pl = (t > tHit - 0.15) and pulse(t, tHit - 0.15, 2, 0.15) or 0
		setT(outline, 0.1 - 0.1 * pl)
		disc.Transparency = 0.85 - 0.25 * smooth(e / 0.5) - 0.2 * pl          -- (15 % -> 40 % intensity)
		for i, m in marks do m.Transparency = 1 - 0.9 * smooth((t - (tShow + 0.5 + (i - 1) * 0.09)) / 0.08) end
		setT(cross, 0.3 - 0.3 * pl)
		return true
	end, stop = function() for _, p in outline do p:Destroy() end; for _, p in marks do p:Destroy() end; for _, p in cross do p:Destroy() end; disc:Destroy() end }
end

-- SOLAR STRIKE: a fractured 12-sided target (radius 8), four thick crosshair bars, eight thin inner cracks
local function dangerSolar(ctx, centre: Vector3, r, tShow, tHit)
	local outline, bars, inner = {}, {}, {}
	local ro = r / cos(pi / 12)                             -- (circumscribed 12-gon: the whole radius-8 circle is inside)
	for i = 0, 11 do
		local a0, a1 = i / 12 * 2 * pi + 0.03, (i + 1) / 12 * 2 * pi - 0.03     -- (small gaps = fractured)
		edge(ctx, outline, centre + Vector3.new(cos(a0) * ro, 0, sin(a0) * ro), centre + Vector3.new(cos(a1) * ro, 0, sin(a1) * ro), 0.42)
	end
	for i = 0, 3 do
		local a = i / 4 * 2 * pi
		table.insert(bars, strip(ctx, centre + Vector3.new(cos(a) * 2, 0, sin(a) * 2), centre + Vector3.new(cos(a) * (r + 0.6), 0, sin(a) * (r + 0.6)), 0.4, W_AMBER))
	end
	for i = 0, 7 do
		local a = i / 8 * 2 * pi + pi / 8 + (math.random() - 0.5) * 0.3
		table.insert(inner, strip(ctx, centre + Vector3.new(cos(a) * 1.5, 0, sin(a) * 1.5), centre + Vector3.new(cos(a) * r * 0.75, 0, sin(a) * r * 0.75), 0.1, W_WHITE))
	end
	local g = onGround(ctx, centre)
	local disc = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = W_AMBER, Transparency = 1,
		Size = Vector3.new(0.04, r * 2, r * 2), CFrame = CFrame.new(g) * CFrame.Angles(0, 0, pi / 2) })
	local core = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = W_WHITE, Transparency = 1,
		Size = Vector3.new(0.05, 3, 3), CFrame = CFrame.new(g + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, 0, pi / 2) })
	return { step = function(_, t)
		if t >= tHit then return false end
		local e = t - tShow
		local fl = (t > tHit - 0.15) and pulse(t, tHit - 0.15, 2, 0.15) or 0
		setT(outline, 0.1 - 0.1 * fl)
		disc.Transparency = 0.85 - 0.3 * smooth(e / 0.7) - 0.25 * fl
		setT(inner, 1 - 0.85 * smooth((t - (tShow + 0.7)) / 0.35))
		for _, b in bars do b.Transparency = 0.35 - 0.3 * smooth((t - (tHit - 0.15)) / 0.05) - 0.05 * fl; b.Color = (t > tHit - 0.15) and W_WHITE or W_AMBER end
		core.Transparency = 1 - 0.7 * smooth((t - (tShow + 0.7)) / 0.35) - 0.3 * fl
		return true
	end, stop = function() for _, l in { outline, bars, inner } do for _, p in l do p:Destroy() end end; disc:Destroy(); core:Destroy() end }
end

-- ===== aiming (ChatGPT batch-1 spec §3): Boulder + Sun aim at a world point chosen at cast start
-- d = distance, theta = angle off its facing (left +), k = (d - 12) / 18. The turn is an extra layer over the poses:
-- at theta = +30: root +10, hips +2, belly +5, chest +9, head +4, shoulders +4 (scaled with theta, mirrored right)
function A.setAim(atk, ctx, aim: Vector3?)
	ctx.aim, ctx.aimD, ctx.aimTheta, ctx.aimK, ctx.keys = nil, nil, nil, nil, nil
	if not aim or not atk.aims then return end
	local v = ctx.base:PointToObjectSpace(aim)
	ctx.aim = aim
	ctx.aimD = Vector2.new(v.X, v.Z).Magnitude
	ctx.aimTheta = math.clamp(math.deg(math.atan2(-v.X, -v.Z)), -30, 30)
	ctx.aimK = clamp01((ctx.aimD - 12) / 18)
	ctx.keys = atk.keysFor and atk.keysFor(ctx.aimK) or nil
end
local function aimLayer(ctx, t, p, tIn0, tIn1)
	if not ctx or not ctx.aimTheta then return end
	local s = (ctx.aimTheta / 30) * smooth((t - tIn0) / (tIn1 - tIn0))
	p.rootYaw += 10 * s
	p.yaw[1] += 2 * s; p.yaw[2] += 5 * s; p.yaw[3] += 9 * s; p.yaw[4] += 4 * s
	p.armYaw += 4 * s
end
local function copyKeys(keys)
	local out = {}
	for i, k in keys do
		local c = {}
		for f, v in k do c[f] = (type(v) == "table") and table.clone(v) or v end
		out[i] = c
	end
	return out
end
-- the ground point `fwd` studs along the aim (or straight ahead if there is no aim)
local function towardAim(ctx, fwd)
	if not ctx.aim then return ahead(ctx, fwd, 0) end
	local o = ctx.base.Position
	local d = Vector3.new(ctx.aim.X - o.X, 0, ctx.aim.Z - o.Z).Unit
	local p = o + d * fwd
	return Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
end
A.TEST_AIMS = { { 26, 0 }, { 14, 25 }, { 30, -30 }, { 20, 12 } }
A.TEST_AIMS_SHORT = { { 14, 0 }, { 10, 25 }, { 12, -30 }, { 7, 12 } }   -- (the Twin's boing: 14 at most)  -- (MOVE TEST: distance, degrees left; a new one each repeat)

-- ===================== A. GROUND SHATTER (3.8 s) =====================
A.Slam = {
	dur = 3.8,
	lock = 3.4,              -- (power graph: busy until 3.4, back to neutral)
	keys = {
		{ t = 0, R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
		{ t = 0.40, ease = "out", R = { 0.15, 0, -0.2, -6 }, P = { -4, -7, -5, 4 }, arms = { 65, 65 }, hands = { 12, 12 } },
		{ t = 1.10, ease = "out", R = { 0.25, 0, -0.4, -9 }, P = { -5, -9, -7, 6 }, arms = { 158, 158 }, hands = { 15, 15 } },
		{ t = 1.32, ease = "smooth", R = { 0.20, 0, -0.4, -10 }, P = { -5, -9, -8, 7 }, arms = { 165, 165 }, hands = { 15, 15 } },
		{ t = 1.64, ease = "in", R = { -0.85, 0, 0.6, 22 }, P = { 12, 22, 20, -12 }, arms = { -10, -10 }, hands = { -12, -12 } },
		{ t = 1.83, ease = "out", R = { -1.0, 0, 0.75, 25 }, P = { 12, 23, 18, -10 }, arms = { -15, -15 }, hands = { -15, -15 } },
		{ t = 2.45, ease = "smooth", R = { -0.45, 0, 0.3, 12 }, P = { 5, 9, 8, -5 }, arms = { 15, 15 }, hands = { 4, 4 } },
		{ t = 3.40, ease = "smooth", R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
	},
	-- the hang: a fine tremor while the magma charges
	extra = function(t, pose)
		if t > 1.1 and t < 1.5 then local q = 1.2 * sin(t * 2 * pi * 11); pose.arms[1] += q; pose.arms[2] -= q end
		pose.glow = (t > 0.85 and t < 1.64) and 0.4 * smooth((t - 0.85) / 0.6) or (t >= 1.64 and t < 2.4) and 0.4 * (1 - smooth((t - 1.64) / 0.7)) or 0
	end,
	-- the fists meet the ground: 5 studs ahead, 4 apart
	ik = function(t, ctx)
		local w = (t < 1.49) and 0 or (t < 1.64) and smooth((t - 1.49) / 0.15) or (t < 1.95) and 1 or 1 - smooth((t - 1.95) / 0.25)
		if w <= 0 then return 0 end
		ctx.slamAt = ctx.slamAt or ahead(ctx, 5.2, 0)
		local c, r = ctx.slamAt, ctx.base.RightVector
		return w, c - r * 2.1, c + r * 2.1          -- (on the ground itself: ChatGPT audit r1, 0.3 above left them 0.7 up)
	end,
	events = {
		{ t = 0.35, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.4, 0.75, 0.25) end },
		-- the danger WEDGE: 120 degrees, 16 studs from its centre, shown 1 s before the hit (power graph 09)
		{ t = 0.64, fn = function(ctx) local o = ctx.base.Position; return dangerWedge(ctx, Vector3.new(o.X, 0, o.Z), Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z).Unit, 0.64, 1.64) end },
		{ t = 0.85, fn = function(ctx) sparks(ctx, ctx.gauntlet("L"), 2, 3); sparks(ctx, ctx.gauntlet("R"), 2, 3) end },
		-- the charge rumble rises until the slam
		{ t = 1.08, fn = function(ctx) return ctx.soundRamp(SND.lava, ctx.base.Position, 0.25, 0.9, 0.75, 1.0, 0.56) end },
		{ t = 1.32, fn = function(ctx)
			local lights = {}
			for _, s in { "L", "R" } do
				local p = part(ctx, { Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(ctx.gauntlet(s)) })
				newLight(p, AMBER, 9, 1.5)
				lights[s] = p
			end
			local t0
			return { step = function(_, t)
				t0 = t0 or t
				if t - t0 > 0.7 then return false end
				for s, p in lights do p.CFrame = CFrame.new(ctx.gauntlet(s)) end
				return true
			end, stop = function() for _, p in lights do p:Destroy() end end }
		end },
		-- IMPACT: the hit, the dust, the shake, then the crack ring and the crystals
		{ t = 1.64, fn = function(ctx)
			local c = ctx.slamAt or ahead(ctx, 5.2, 0)
			ctx.sound(SND.avalanche, c, 1.6, 1.0)
			ctx.sound(SND.stomp, c, 2.0, 0.85)
			dust(ctx, c, 8, 3.6)                      -- (budget, batch-1 spec: 8 dust + 6 sparks)
			sparks(ctx, c, 6, 6)
			ctx.shake(c, 0.22, 0.24, 25, 75)
			return cracks(ctx, c, 9, 6, 13, 0.30, 1.9, MAGMA, true)
		end },
		{ t = 1.70, fn = function(ctx)
			local c = ctx.slamAt or ahead(ctx, 5.2, 0)
			ctx.sound(SND.glass, c, 2.0, 0.85, 0.65)
		end },
		-- 12 amber crystals burst out of the ground in a ring (3.5-12 studs out), crack and tilt, then sink
		{ t = 1.73, fn = function(ctx)
			local c = ctx.slamAt or ahead(ctx, 5.2, 0)
			local tmpl = ctx.FX:FindFirstChild("CrystalSpike")
			if not tmpl then return end
			local g0 = tmpl:GetAttribute("GroundOffset") or 1.74
			local list = {}
			for i = 1, math.min(12, fragsLeft()) do
				local a = (i / 12) * 2 * pi + (math.random() - 0.5) * 0.4
				local r = 3.5 + ((i % 3) / 2) * 6 + math.random() * 2.5     -- three loose rings
				local p = Vector3.new(c.X + cos(a) * r, 0, c.Z + sin(a) * r)
				p = Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
				local s = 0.55 + math.random() * 0.45                        -- 2.3-4.3 studs tall
				local m = frag(tmpl)
				if not m then break end
				m.Size = tmpl.Size * s
				m.Parent = ctx.holder
				local out = Vector3.new(cos(a), 0, sin(a))
				list[i] = { m = m, p = p, s = s, out = out, spin = math.random() * 2 * pi, lean = rad(8 + math.random() * 14),
					crack = rad(10 + math.random() * 10), delay = (r - 3.5) / 40, g0 = g0 * s, H = m.Size.Y }
			end
			local t0
			return { step = function(_, t)
				t0 = t0 or t
				local e = t - t0
				if e > 1.6 then return false end
				for _, k in list do
					local ek = e - k.delay
					local rise = (ek < 0) and 0 or (ek < 0.22) and (1 - (1 - ek / 0.22) ^ 3) * 1.08 or 1.08 - 0.08 * smooth((ek - 0.22) / 0.12)
					local tilt = k.lean + ((ek > 0.32) and k.crack * smooth((ek - 0.32) / 0.1) or 0)
					local sink = smooth((e - 0.85) / 0.75)             -- (standing ~0.6 s before they sink: ChatGPT audit r1)
					-- the centre: standing = g0 over the ground; fully buried = a whole height lower (overshoots 8 % as it bursts out)
					local y = k.g0 - k.H * (1 - rise) - k.H * sink
					local axis = Vector3.yAxis:Cross(k.out).Unit
					local cf = CFrame.new(k.p + Vector3.new(0, y, 0)) * CFrame.fromAxisAngle(axis, tilt) * CFrame.Angles(0, k.spin, 0)
					k.m.CFrame = cf
					k.m.Transparency = smooth((e - 1.35) / 0.25)
				end
				return true
			end, stop = function() for _, k in list do k.m:Destroy() end end }
		end },
		{ t = 2.05, fn = function(ctx)
			local c = ctx.slamAt or ahead(ctx, 5.2, 0)
			ctx.sound(SND.glass, c, 1.0, 1.15, 0.65)
			sparks(ctx, c + Vector3.new(0, 1.5, 0), 4, 5)
		end },
		{ t = 2.35, fn = function(ctx) ctx.sound(SND.tumble, ctx.slamAt or ctx.base.Position, 0.5, 1.05, 0.25) end },
		{ t = 3.6, fn = function(ctx) ctx.slamAt = nil end },
	},
}

-- ===================== B. SUN BEAM (6.2 s) =====================
-- James, 27 Oct (2nd pass): "he sticks his hand into the air ... his whole gauntlet gets brighter and brighter, like
-- blinding. And then a mini sun, still somewhat big, appears quite high in the air, a few meters in front of him. And
-- then it goes like a zapping sound, and then just goes boof, and sends this massive beam down that destroys [the]
-- location. So he's summoning a sun that's up in the air, far away from him, in front of him."
--   0.95-2.30 the raised gauntlet brightens to blinding  ->  2.30 the sun appears 30 up, 16 ahead (a streak from the
--   fist)  ->  2.95 ZAP  ->  3.20 BOOF: a massive beam down onto a spot 26 ahead; the spot is blasted and burns
local SUN_CORE, SUN_CORONA, BEAM_C, BURN = C3(255, 236, 170), C3(255, 172, 36), C3(255, 246, 205), C3(201, 90, 22)
SND.zap = "9116277062"        -- Lightning Flash, Quick Electrical Burst, Searing, Crackle (2.4 s; instant, peak 484)
SND.crackle = "9116279763"    -- the same family, longer (3.1 s): the gauntlet crackling as it charges
SND.boof = "9126102254"       -- Time Warp, Big Explosion Blast, Boom, Tonal Tail (5.8 s; instant, peak ~1180)
local SUN_UP, SUN_AHEAD, HIT_AHEAD = 30, 16, 26
A.Sun = {
	dur = 6.2,
	lock = 3.2,              -- (power graph: the body is free once the beam lands; the sun, beam and burn play on)
	aims = true,
	keys = {
		{ t = 0, R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
		{ t = 0.40, ease = "out", R = { -0.15, 0.15, 0, -4 }, P = { -3, -4, -5, 5 }, arms = { 20, 70 }, hands = { 12, 10 } },
		{ t = 0.95, ease = "out", R = { 0, 0.25, -0.2, -7 }, P = { -4, -6, -5, 7 }, yaw = { 4, 6, 5, -8 }, arms = { 25, 160 }, hands = { 15, 15 } },
		{ t = 1.80, ease = "smooth", R = { 0, 0.25, -0.2, -8 }, P = { -4, -7, -5, 9 }, yaw = { 4, 6, 5, -8 }, arms = { 25, 165 }, hands = { 15, 15 } },
		{ t = 2.30, ease = "smooth", R = { -0.12, 0.2, 0, -10 }, P = { -5, -8, -6, 10 }, yaw = { 4, 6, 5, -8 }, arms = { 30, 172 }, hands = { 12, 15 } },
		-- the sun appears: he looks up at it, the fist still raised, holding it there
		{ t = 2.70, ease = "out", R = { -0.1, 0.15, -0.1, -9 }, P = { -6, -9, -7, -6 }, arms = { 30, 170 }, hands = { 12, 15 } },
		{ t = 3.05, ease = "smooth", R = { -0.15, 0.15, -0.1, -10 }, P = { -6, -10, -8, -5 }, arms = { 32, 174 }, hands = { 12, 16 } },
		-- FIRE: the fist drives down at the target, the whole body behind it
		{ t = 3.20, ease = "in", R = { -0.4, 0, 0.25, 10 }, P = { 6, 9, 12, -8 }, arms = { 20, 105 }, hands = { 8, 15 } },
		{ t = 3.70, ease = "out", R = { -0.3, 0, 0.2, 7 }, P = { 4, 6, 7, -5 }, arms = { 15, 85 }, hands = { 8, 10 } },
		{ t = 4.90, ease = "smooth", R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 5, 25 }, hands = { 0, 5 } },
		{ t = 6.20, ease = "smooth", R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
	},
	-- (aimed: a near target gets a lower raise and drive; batch-1 spec: right arm 162-172 at 2.30, 95-105 at 3.20,
	-- right hand 13-16, left brace 25-30, for 12-30 studs)
	keysFor = function(k)
		local keys = copyKeys(A.Sun.keys)
		for _, key in keys do
			if key.t >= 2.29 and key.t <= 3.06 then key.arms[2] -= 10 * (1 - k); key.arms[1] -= 5 * (1 - k); key.hands[2] -= 3 * (1 - k) end
			if key.t == 3.20 then key.arms[2] -= 10 * (1 - k) end
		end
		return keys
	end,
	-- the raised fist trembles harder as it charges (12 Hz, up to 2.4 deg), and again holding the sun before it fires
	extra = function(t, pose, ctx)
		aimLayer(ctx, t, pose, 0.40, 1.60)        -- (turns to the target by 1.6, holds through the strike)
		local k = (t > 1.1 and t < 2.3) and 0.5 + 1.9 * smooth((t - 1.1) / 1.2) or (t >= 2.75 and t < 3.2) and 1.6 or 0
		if k > 0 then pose.arms[2] += k * sin(t * 2 * pi * 12); pose.hands[2] += 0.7 * k * sin(t * 2 * pi * 13 + 1) end
		pose.glow = (t > 0.95 and t < 2.3) and 0.8 * smooth((t - 0.95) / 1.2) or (t >= 2.3 and t < 3.0) and 0.8 * (1 - smooth((t - 2.3) / 0.5)) or 0
	end,
	events = {
		-- the GAUNTLET: brighter and brighter until it's blinding, then the light leaves it for the sky
		{ t = 0.95, fn = function(ctx)
			local shell = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = C3(255, 200, 100), Transparency = 1, Size = Vector3.new(3, 3, 3) })
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = C3(255, 252, 235), Transparency = 1, Size = Vector3.new(2, 2, 2) })
			local light = newLight(core, C3(255, 210, 120), 14, 1)
			local glint = Instance.new("ParticleEmitter")
			glint.Texture = SPARK; glint.LightEmission = 1; glint.Rate = 0; glint.Lifetime = NR(0.25, 0.45); glint.Speed = NR(2, 5)
			glint.SpreadAngle = Vector2.new(180, 180); glint.Size = curve(1.2, 0.8, 0); glint.Color = CS(C3(255, 250, 220), SUN_CORONA); glint.Parent = core
			stream(glint)
			local rise = ctx.soundRamp(SND.lava, ctx.base.Position, 0.3, 1.2, 0.6, 1.6, 1.35)      -- (a rising roar)
			local crackle
			return { step = function(_, t)
				if t > 3.0 then return false end
				rise:step(t)
				if t > 1.6 and not crackle then crackle = ctx.soundRamp(SND.crackle, ctx.gauntlet("R"), 0.3, 1.0, 0.9, 1.15, 0.7) end
				if crackle then crackle:step(t) end
				local gc = ctx.gauntlet("R")
				local b = smooth((t - 0.95) / 1.3)                   -- (0 -> 1 by 2.25)
				local out = smooth((t - 2.32) / 0.45)                -- (the light leaves for the sky)
				local fl = 0.04 * sin(t * 47) + 0.03 * sin(t * 71)
				shell.CFrame, core.CFrame = CFrame.new(gc), CFrame.new(gc)
				shell.Size = Vector3.one * (3.0 + 1.6 * b * b + 0.2 * sin(t * 33))
				shell.Transparency = math.clamp(1 - 0.95 * b + fl + out, 0, 1)
				core.Size = Vector3.one * (1.6 + 1.8 * b)
				core.Transparency = math.clamp(1 - 1.3 * smooth((t - 1.6) / 0.6) + out, 0, 1)
				if light then
					light.Brightness = (1 + 11 * b * b) * (1 - out)
					light.Range = 14 + 26 * b
					if out >= 1 then light:Destroy(); light = nil end   -- (frees the light for the sun)
				end
				glint.Rate = (t < 2.3) and math.min(10 * b, math.max(0, particlesLeft() + glint.Rate)) or 0
				return true
			end, stop = function() rise:stop(); if crackle then crackle:stop() end; shell:Destroy(); core:Destroy() end }
		end },
		-- the SUN: summoned high in the sky in front of him
		{ t = 2.30, fn = function(ctx)
			-- (aimed: the sun hangs 8-16 studs along the line to the target, 30 up; both stay where they were cast)
			local ground = ctx.aim and towardAim(ctx, math.clamp(0.55 * ctx.aimD, 8, 16)) or ahead(ctx, SUN_AHEAD, 0)
			ctx.sunAt = ground + Vector3.new(0, SUN_UP, 0)
			ctx.sunTarget = ctx.sunTarget or (ctx.aim and Vector3.new(ctx.aim.X, ctx.ground(ctx.aim.X, ctx.aim.Z), ctx.aim.Z)) or ahead(ctx, HIT_AHEAD, 0)
			local sp = ctx.sunAt
			-- the streak: the light leaving the fist for the sky
			local holder = part(ctx, { Transparency = 1, Size = Vector3.one, CFrame = CFrame.new() })
			local a0 = Instance.new("Attachment"); a0.Parent = holder
			local a1 = Instance.new("Attachment"); a1.Parent = holder
			local streak = Instance.new("Beam")
			streak.Attachment0, streak.Attachment1 = a0, a1; streak.Color = CS(C3(255, 250, 225)); streak.LightEmission = 1; streak.LightInfluence = 0
			streak.FaceCamera = true; streak.Width0, streak.Width1 = 1.2, 0.5; streak.Parent = holder
			local sun = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = SUN_CORE, Size = Vector3.one * 0.1, CFrame = CFrame.new(sp) })
			local halo = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = SUN_CORONA, Transparency = 0.15, Size = Vector3.one * 0.1, CFrame = CFrame.new(sp) })
			local light = newLight(sun, C3(255, 200, 110), 40, 0)      -- (audit: range 60 -> 40, peak 5 -> 3: it washed out the warning)
			local corona = Instance.new("ParticleEmitter")
			corona.Texture = SMOKE; corona.LightEmission = 1; corona.Rate = 4; corona.Lifetime = NR(0.5, 0.9); corona.Speed = NR(1, 3)
			corona.SpreadAngle = Vector2.new(180, 180); corona.Size = curve(6, 10, 12); corona.Transparency = curve(0.35, 0.55, 1)
			corona.Color = CS(SUN_CORONA, C3(255, 100, 20)); corona.RotSpeed = NR(-60, 60); corona.Rotation = NR(0, 360); corona.Parent = sun
			stream(corona)
			local flares = Instance.new("ParticleEmitter")
			flares.Texture = SPARK; flares.LightEmission = 1; flares.Rate = 3; flares.Lifetime = NR(0.4, 0.7); flares.Speed = NR(8, 14)
			flares.SpreadAngle = Vector2.new(180, 180); flares.Size = curve(2.2, 1.4, 0); flares.Color = CS(SUN_CORE, SUN_CORONA); flares.Parent = sun
			stream(flares)
			ctx.sound(SND.power, sp, 1.2, 1.35, 0.35)                 -- (it bursts into being)
			ctx.sound(SND.glass, sp, 0.8, 1.5, 0.65)
			return { step = function(_, t)
				if t > 5.6 then return false end
				local e = t - 2.30
				-- the streak from the fist for the first 0.3 s
				a0.WorldPosition, a1.WorldPosition = ctx.gauntlet("R"), sp
				local s = 1 - smooth(e / 0.3)
				streak.Width0, streak.Width1 = 1.2 * s, 0.5 * s
				-- the sun: bursts to 10 studs across (overshoot), breathes, swells just before it fires, collapses after
				local grow = (e < 0.45) and (1 - (1 - e / 0.45) ^ 3) * 1.12 or 1.12 - 0.12 * smooth((e - 0.45) / 0.2)
				local swell = (t > 2.95 and t < 3.2) and 0.15 * smooth((t - 2.95) / 0.25) or 0
				local die = smooth((t - 4.85) / 0.5)
				local d = 10 * grow * (1 + swell + 0.03 * sin(t * 9)) * (1 - die)
				sun.Size = Vector3.one * math.max(0.05, d)
				halo.Size = Vector3.one * math.max(0.05, d * 1.3 + 0.4 * sin(t * 13))
				corona.Size = curve(d * 0.6, d * 1.0, d * 1.25)
				if light then light.Brightness = 3 * grow * (1 - die) + ((t > 3.2 and t < 3.5) and 2.5 or 0) end
				if die >= 1 then sun.Transparency = 1; halo.Transparency = 1; corona.Enabled = false; flares.Enabled = false end
				return true
			end, stop = function() holder:Destroy(); sun:Destroy(); halo:Destroy() end, worldAt = 3.20 }
		end },
		-- the danger TARGET where it will hit: radius 8, shown at 2.00 (before the sun), beam at 3.20 (power graph 09)
		{ t = 2.00, fn = function(ctx)
			ctx.sunTarget = (ctx.aim and Vector3.new(ctx.aim.X, ctx.ground(ctx.aim.X, ctx.aim.Z), ctx.aim.Z)) or ahead(ctx, HIT_AHEAD, 0)
			return dangerSolar(ctx, ctx.sunTarget, 8, 2.00, 3.20)
		end },
		-- ZAP: the sun crackles, charging the shot
		{ t = 2.95, fn = function(ctx)
			local sp = ctx.sunAt or ahead(ctx, SUN_AHEAD, 0) + Vector3.new(0, SUN_UP, 0)
			sparks(ctx, sp, 6, 14)
			return ctx.soundRamp(SND.zap, sp, 2.0, 2.0, 1.0, 1.0, 0.75)
		end },
		-- BOOF: the massive beam slams down and destroys the spot
		{ world = true, t = 3.20, fn = function(ctx)
			local tgt = ctx.sunTarget or ahead(ctx, HIT_AHEAD, 0)
			local from = ctx.sunAt or ahead(ctx, SUN_AHEAD, 0) + Vector3.new(0, SUN_UP, 0)
			ctx.sound(SND.boof, tgt, 2.5, 1.0)
			ctx.sound(SND.power, tgt, 1.4, 0.95, 0.35)
			ctx.sound(SND.avalanche, tgt, 1.8, 1.0)
			ctx.sound(SND.stomp, tgt, 2.0, 0.8)
			ctx.shake(tgt, 0.35, 0.45, 40, 110)
			local holder = part(ctx, { Transparency = 1, Size = Vector3.one, CFrame = CFrame.new() })
			local a0 = Instance.new("Attachment"); a0.Parent = holder
			local a1 = Instance.new("Attachment"); a1.Parent = holder
			a0.WorldPosition, a1.WorldPosition = from, tgt + Vector3.new(0, 0.3, 0)
			local function beam(w0, w1, color, transp)
				local b = Instance.new("Beam")
				b.Attachment0, b.Attachment1 = a0, a1
				b.Width0, b.Width1 = w0, w1
				b.Color = CS(color); b.LightEmission = 1; b.LightInfluence = 0; b.FaceCamera = true; b.Segments = 1
				b.Transparency = NS(transp); b.Parent = holder
				return b
			end
			local beams = { { beam(5, 6.5, BEAM_C, 0), 5, 6.5 }, { beam(10, 12, C3(255, 214, 110), 0.35), 10, 12 }, { beam(17, 20, SUN_CORONA, 0.7), 17, 20 } }
			-- the blast at the spot: a white flash ball, a shockwave ring, debris, glowing cracks, a crater that burns
			local flash = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = C3(255, 245, 210), Size = Vector3.one, CFrame = CFrame.new(tgt) })
			local wave = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = SUN_CORONA, Transparency = 0.2,
				Size = Vector3.new(0.4, 2, 2), CFrame = CFrame.new(tgt + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, pi / 2) })
			local scorch = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = C3(26, 20, 18), Transparency = 0.15,
				Size = Vector3.new(0.08, 20, 20), CFrame = CFrame.new(tgt + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, pi / 2) })
			local patch = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = BURN, Transparency = 0.1,
				Size = Vector3.new(0.1, 13, 13), CFrame = CFrame.new(tgt + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, pi / 2) })
			local fire = part(ctx, { Transparency = 1, Size = Vector3.new(10, 0.2, 10), CFrame = CFrame.new(tgt + Vector3.new(0, 0.3, 0)) })
			local flame = Instance.new("ParticleEmitter")
			flame.Texture = FIRE; flame.LightEmission = 0.9; flame.Rate = 5; flame.Lifetime = NR(0.5, 0.9); flame.Speed = NR(4, 9)
			flame.SpreadAngle = Vector2.new(15, 15); flame.Size = curve(3.0, 4.6, 1.2); flame.Transparency = curve(0.1, 0.35, 1)
			flame.Color = CS(C3(255, 220, 120), C3(255, 90, 20)); flame.Acceleration = Vector3.new(0, 5, 0); flame.EmissionDirection = Enum.NormalId.Top
			flame.Shape = Enum.ParticleEmitterShape.Box; flame.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume; flame.Parent = fire
			stream(flame)
			local smoke = Instance.new("ParticleEmitter")
			smoke.Texture = SMOKE; smoke.Rate = 1; smoke.Lifetime = NR(1.4, 2.2); smoke.Speed = NR(4, 7); smoke.SpreadAngle = Vector2.new(15, 15)
			smoke.Size = curve(3, 6, 9); smoke.Transparency = curve(0.45, 0.6, 1); smoke.Color = CS(C3(60, 52, 48)); smoke.EmissionDirection = Enum.NormalId.Top
			smoke.Parent = fire
			stream(smoke)
			local hl = newLight(fire, C3(255, 150, 60), 40, 6)
			dust(ctx, tgt, 8, 6)                       -- (budget, batch-1 spec: 8 dust + 6 sparks)
			sparks(ctx, tgt, 6, 16)
			local cr = cracks(ctx, tgt, 11, 9, 20, 0.35, 2.4, MAGMA, true)
			-- rock debris thrown out of the crater (pieces of the boulder prop; scripted, no physics)
			local rocks = {}
			local tmpl = ctx.FX:FindFirstChild("Boulder")
			if tmpl then
				for i = 1, math.min(10, fragsLeft()) do
					local f = frag(tmpl); if not f then break end; f.Size = tmpl.Size * (0.16 + math.random() * 0.14); f.Parent = ctx.holder
					local a = i / 10 * 2 * pi + math.random() * 0.5
					local sp = 10 + math.random() * 10
					rocks[i] = { f = f, v = Vector3.new(cos(a) * sp, 14 + math.random() * 10, sin(a) * sp), rot = Vector3.new(math.random() * 9, math.random() * 9, math.random() * 9) }
				end
			end
			local burnSnd = ctx.soundRamp(SND.lava, tgt, 1.2, 1.2, 1.0, 1.0, 2.6)
			return { step = function(_, t)
				local e = t - 3.20
				if e > 2.75 then return false end
				burnSnd:step(t); cr:step(t)
				a0.WorldPosition = ctx.sunAt or from
				-- the beam: a fat slam that settles to a roaring column, held 1.6 s, then gone in 0.3 s
				local on = 1 - smooth((e - 1.6) / 0.3)
				local slam = 1 + 0.6 * (1 - smooth(e / 0.25))
				local fl = 0.88 + 0.12 * sin(t * 45) + 0.06 * sin(t * 73)
				for _, b in beams do b[1].Width0, b[1].Width1 = b[2] * slam * fl * on, b[3] * slam * fl * on end
				-- the flash and the shockwave
				flash.Size = Vector3.one * (2 + 16 * smooth(e / 0.3))
				flash.Transparency = smooth(e / 0.45)
				local wr = 2 + 36 * smooth(e / 0.55)
				wave.Size = Vector3.new(0.4, wr, wr)
				wave.Transparency = 0.2 + 0.8 * smooth(e / 0.6)
				-- the crater: glowing while it burns, then cooling
				local cool = smooth((e - 2.2) / 0.5)
				patch.Transparency = 0.1 + 0.2 * (1 - fl) + 0.9 * cool
				scorch.Transparency = 0.15 + 0.85 * smooth((e - 2.4) / 0.35)
				local burning = e < 2.3
				flame.Enabled, smoke.Enabled = burning, burning
				if hl then hl.Brightness = burning and (e < 0.3 and 10 or 6 * fl) or 0 end
				for _, k in rocks do
					local p = tgt + k.v * e + Vector3.new(0, -32 * e * e / 2, 0)
					local gy = ctx.ground(p.X, p.Z) + k.f.Size.Y * 0.4
					if p.Y < gy then p = Vector3.new(p.X, gy, p.Z) end
					k.f.CFrame = CFrame.new(p) * CFrame.Angles(k.rot.X * e, k.rot.Y * e, k.rot.Z * e)
					k.f.Transparency = smooth((e - 1.0) / 0.3)
				end
				return true
			end, stop = function()
				burnSnd:stop(); cr:stop(); holder:Destroy(); flash:Destroy(); wave:Destroy(); scorch:Destroy(); patch:Destroy(); fire:Destroy()
				for _, k in rocks do k.f:Destroy() end
			end }
		end },
		{ world = true, t = 6.15, fn = function(ctx) ctx.sunAt = nil; ctx.sunTarget = nil end },
	},
}

-- ===================== C. BOULDER HURL (4.7 s) =====================
A.Boulder = {
	dur = 4.7,
	lock = 2.6,              -- (power graph: free to walk once the rock leaves its hands; it flies on)
	aims = true,
	keys = {
		{ t = 0, R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
		{ t = 0.40, ease = "out", R = { -0.55, 0, 0.3, 13 }, P = { 9, 15, 12, -9 }, arms = { 15, 15 }, hands = { 12, 12 } },
		{ t = 0.85, ease = "smooth", R = { -1.05, 0, 0.6, 20 }, P = { 13, 22, 15, -12 }, arms = { -10, -10 }, hands = { 18, 18 } },
		{ t = 1.20, ease = "out", R = { -0.65, 0, 0.3, 10 }, P = { 7, 12, 8, -6 }, arms = { 45, 45 }, hands = { 12, 12 } },
		{ t = 1.85, ease = "smooth", R = { 0.15, 0, -0.25, -9 }, P = { -5, -8, -6, 5 }, arms = { 145, 145 }, hands = { 18, 18 } },
		{ t = 2.25, ease = "out", R = { 0.2, -0.3, -0.5, -13 }, P = { -7, -12, -8, 8 }, yaw = { 1, 2, 2, 0 }, arms = { 155, 155 }, hands = { 15, 15 } },
		{ t = 2.55, ease = "in", R = { -0.25, 0.2, 0.65, 17 }, P = { 10, 15, 17, -10 }, yaw = { -1, -1, -1, 0 }, arms = { 85, 85 }, hands = { 20, 20 } },
		{ t = 2.85, ease = "out", R = { -0.35, 0.2, 0.7, 19 }, P = { 10, 16, 15, -9 }, yaw = { -1, -1, -1, 0 }, arms = { 40, 40 }, hands = { 8, 8 } },
		{ t = 3.65, ease = "smooth", R = { -0.1, 0, 0.2, 7 }, P = { 4, 5, 6, -4 }, arms = { 10, 10 }, hands = { 5, 5 } },
		{ t = 4.70, ease = "smooth", R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
	},
	-- (aimed: a near throw is a higher, compact lob, a far one a stronger forward release; batch-1 spec, k = 0 at 12
	-- studs, 1 at 30: overhead arms 145-155, release arms 105-85, hands 24-20, root fwd .35-.65, pitch 12-17)
	keysFor = function(k)
		local keys = copyKeys(A.Boulder.keys)
		for _, key in keys do
			if key.t == 2.25 then key.arms = { 145 + 10 * k, 145 + 10 * k } end
			if key.t == 2.55 then
				key.arms = { 105 - 20 * k, 105 - 20 * k }; key.hands = { 24 - 4 * k, 24 - 4 * k }
				key.R[3], key.R[4] = 0.35 + 0.3 * k, 12 + 5 * k
				key.P[2], key.P[3] = 11 + 4 * k, 12 + 5 * k
			end
		end
		return keys
	end,
	-- (the arms close in on the boulder while they carry it, so the gauntlets grip its sides)
	extra = function(t, pose, ctx)
		aimLayer(ctx, t, pose, 0.40, 1.85)        -- (turns to the target while it lifts, steady through the release)
		local hold = smooth((t - 0.6) / 0.3) * (1 - smooth((t - 2.45) / 0.15))
		pose.armsIn = 9 * hold
	end,
	-- the gauntlets grip the boulder's sides as it comes out of the ground
	ik = function(t, ctx)
		local w = (t < 0.6) and 0 or (t < 0.8) and smooth((t - 0.6) / 0.2) or (t < 1.15) and 1 or 1 - smooth((t - 1.15) / 0.2)
		if w <= 0 then return 0 end
		ctx.rockAt = ctx.rockAt or ahead(ctx, 4.6, 0)
		local c, r = ctx.rockAt, ctx.base.RightVector
		local y = ctx.rockY or 0
		return w, c + Vector3.new(0, y - 0.6, 0) - r * 2.5, c + Vector3.new(0, y - 0.6, 0) + r * 2.5
	end,
	events = {
		{ t = 0.40, fn = function(ctx) ctx.rockAt = ahead(ctx, 4.6, 0); ctx.sound(SND.quake, ctx.rockAt, 0.9, 1.0)
			return cracks(ctx, ctx.rockAt, 6, 2.5, 5.5, 0.45, 1.5, C3(40, 34, 30), false) end },
		-- the boulder: rises out of the ground into the gauntlets, rides between them, flies, shatters
		{ t = 0.80, fn = function(ctx)
			local tmpl = ctx.FX:FindFirstChild("Boulder")
			if not tmpl then return end
			local rock = tmpl:Clone(); rock.Parent = ctx.holder
			local c = ctx.rockAt or ahead(ctx, 4.6, 0)
			local rad0 = rock.Size.Y / 2
			local spin = CFrame.Angles(math.random() * 2, math.random() * 2, math.random() * 2)
			local throwFrom, target, landed
			local frags
			return { step = function(self, at)                     -- (at = the attack's time)
				if at < 1.2 then
					-- tearing out of the ground: from buried to sitting in the grip
					local up = smooth((at - 0.8) / 0.4)
					ctx.rockY = -rad0 + (rad0 + 1.9) * up
					rock.CFrame = CFrame.new(c + Vector3.new(0, ctx.rockY, 0)) * spin
				elseif at < 2.55 then
					-- carried: between the two gauntlets as it comes up, then ON TOP of the fists overhead. (ChatGPT audit
					-- r1: held between the gauntlets overhead it sat right on the crown's centre crystal, 15.5 up; on the
					-- fists it clears it)
					local midG = (ctx.gauntlet("L") + ctx.gauntlet("R")) / 2
					local midT = (ctx.tip("L") + ctx.tip("R")) / 2 + Vector3.new(0, rad0 * 0.7, 0)   -- (0.55 measured 0.54 clearance; 0.75 wanted)
					local mid = midG:Lerp(midT, smooth((at - 1.25) / 0.4))
					local blend = smooth((at - 1.2) / 0.15)
					local held = c + Vector3.new(0, ctx.rockY or 1.9, 0)
					local shake = (at > 2.25) and Vector3.new(0.06 * sin(at * 70), 0.05 * sin(at * 83), 0) or Vector3.zero
					rock.CFrame = CFrame.new(held:Lerp(mid, blend) + shake) * spin
					throwFrom = rock.Position
				elseif at < 3.40 then
					-- flight: 0.85 s to the target (30 straight ahead if none), an arc 5-9 studs high (higher = nearer), tumbling
					target = target or (ctx.rockHit or ahead(ctx, 30, 0)) + Vector3.new(0, rad0 * 0.6, 0)
					local u = clamp01((at - 2.55) / 0.85)
					local arc = 5 + 4 * (ctx.aimK or 1)
					local p = (throwFrom or rock.Position):Lerp(target, u) + Vector3.new(0, 4 * arc * u * (1 - u), 0)
					rock.CFrame = CFrame.new(p) * spin * CFrame.Angles(-u * 7, u * 2, 0)
				else
					if not landed then
						landed = true
						rock.Transparency = 1
						local hit = target or rock.Position
						ctx.sound(SND.avalanche, hit, 2.0, 1.0)
						ctx.sound(SND.stomp, hit, 1.4, 0.85)
						ctx.shake(hit, 0.16, 0.2, 30, 75)
						dust(ctx, hit, 8, 3.8)                 -- (budget, batch-1 spec: 8 dust + 4 sparks)
						sparks(ctx, hit, 4, 7)
						-- 8 fragments of the boulder, flung out and falling (scripted, no physics)
						frags = {}
						for i = 1, math.min(8, fragsLeft()) do
							local f = frag(tmpl)
							if not f then break end
							f.Size = tmpl.Size * (0.26 + math.random() * 0.16)
							f.Parent = ctx.holder
							local a = i / 8 * 2 * pi + math.random() * 0.4
							frags[i] = { f = f, p0 = hit, v = Vector3.new(cos(a) * (8 + math.random() * 6), 9 + math.random() * 6, sin(a) * (8 + math.random() * 6)),
								rot = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8) }
						end
					end
					local e = at - 3.40
					for _, k in frags do
						local p = k.p0 + k.v * e + Vector3.new(0, -30 * e * e / 2, 0)
						local gy = ctx.ground(p.X, p.Z) + k.f.Size.Y * 0.4
						if p.Y < gy then p = Vector3.new(p.X, gy, p.Z) end
						k.f.CFrame = CFrame.new(p) * CFrame.Angles(k.rot.X * e, k.rot.Y * e, k.rot.Z * e)
						k.f.Transparency = smooth((e - 0.6) / 0.25)
					end
					if e > 0.9 then return false end
				end
				return true
			end, stop = function() rock:Destroy(); if frags then for _, k in frags do k.f:Destroy() end end; ctx.rockY = nil end,
			-- (AI TEST attack commit: this one effect is the rock from the rip to the impact; from the throw (2.55, the server's
			-- release) it is a WORLD object: if the Colossus falls after the throw, the rock flies on and lands)
			worldAt = 2.55 }
		end },
		{ t = 0.85, fn = function(ctx) local c = ctx.rockAt or ctx.base.Position; ctx.sound(SND.avalanche, c, 1.2, 0.85); dust(ctx, c, 6, 2.8) end },
		{ t = 1.20, fn = function(ctx) local c = ctx.rockAt or ctx.base.Position; ctx.sound(SND.tumble, c, 0.5, 0.95, 0.25); dust(ctx, c, 4, 2.2) end },
		-- the landing circle: radius 4 on the target, 1 s before the rock lands (power graph 09); the spot is fixed at the cast
		{ t = 2.40, fn = function(ctx)
			local a = ctx.aim or ahead(ctx, 30, 0)
			ctx.rockHit = Vector3.new(a.X, ctx.ground(a.X, a.Z), a.Z)
			return dangerJagged(ctx, ctx.rockHit, 4, 2.40, 3.40)
		end },
		{ t = 2.25, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position + Vector3.new(0, 14, 0), 0.3, 0.75, 0.25) end },
		-- (the whoosh peaks ~1 s in: started at 1.55 so it peaks on the release)
		{ t = 1.55, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 1.6, 1.0) end },
		{ world = true, t = 3.55, fn = function(ctx) ctx.sound(SND.tumble, ctx.rockHit or ahead(ctx, 30, 0), 0.6, 1.05, 0.25) end },
		{ world = true, t = 4.6, fn = function(ctx) ctx.rockAt = nil; ctx.rockHit = nil end },
	},
}

-- ===================== HURT (0.52 s, additive) =====================
-- ChatGPT batch-1 spec §4: a heavy blow rattles the plating, the torso shifts a fraction, the giant steadies at once.
-- Added over the walk / idle (35 % during an attack); never moves the planted feet, never delays anything.
-- Keys are for a hit pushing it to its right (side +1); the animator mirrors side + yaw (and swaps the arms) for a left hit.
A.Hurt = {
	dur = 0.52,
	additive = true,
	keys = {
		{ t = 0, R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, yaw = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
		{ t = 0.05, ease = "out", R = { -0.04, 0.06, -0.04, -1 }, P = { -1, -2, -3, 2 }, yaw = { 0, 1, 2, -1 }, arms = { -4, -7 }, hands = { -2, -3 } },
		{ t = 0.13, ease = "in", R = { -0.12, 0.14, -0.09, -3 }, P = { -1, -3, -5, 3 }, yaw = { 1, 2, 3, -2 }, arms = { -9, -12 }, hands = { -4, -5 } },
		{ t = 0.24, ease = "smooth", R = { -0.06, 0.10, -0.04, -1 }, P = { 0, -1, -3, 1 }, yaw = { 0, 1, 2, -1 }, arms = { -5, -7 }, hands = { -2, -3 } },
		{ t = 0.40, ease = "smooth", R = { 0, 0.03, 0, 0 }, P = { 0, 0, -1, 0 }, yaw = { 0, 0, 1, 0 }, arms = { -2, -2 }, hands = { -1, -1 } },
		{ t = 0.52, ease = "smooth", R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, yaw = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
	},
	-- the magma core dips ~12 % for 0.08 s
	extra = function(t, pose) if t > 0.13 and t < 0.21 then pose.glowMul = 0.88 end end,
	events = {
		-- two tiny stone chips break off where it was hit; a quiet mid-range stone crack (no bass, no shake)
		{ t = 0, fn = function(ctx)
			ctx.sound(SND.shale, ctx.hurtAt or ctx.base.Position, 0.35, 1.25)
			local tmpl = ctx.FX:FindFirstChild("Boulder")
			if not tmpl then return end
			local at = ctx.hurtAt or (ctx.base.Position + Vector3.new(0, 6, 0))
			local chips = {}
			for i = 1, math.min(2, fragsLeft()) do
				local c = frag(tmpl); if not c then break end; c.Size = tmpl.Size * 0.07; c.Parent = ctx.holder
				local out = (ctx.hurtOut or ctx.base.RightVector) + Vector3.new(0, 0.3, 0)
				chips[i] = { c = c, v = (out.Unit * (3 + i) + Vector3.new(0, 2 + i, 0)) + ctx.base.LookVector * (i - 1.5) * 2 }
			end
			local t0
			return { step = function(_, t)
				t0 = t0 or t
				local e = t - t0
				if e > 0.5 then return false end
				for _, k in chips do
					local p = at + k.v * e + Vector3.new(0, -30 * e * e / 2, 0)
					k.c.CFrame = CFrame.new(p) * CFrame.Angles(e * 9, e * 7, 0)
					k.c.Transparency = smooth((e - 0.24) / 0.26)
				end
				return true
			end, stop = function() for _, k in chips do k.c:Destroy() end end }
		end },
		{ t = 0.08, fn = function(ctx)
			sparks(ctx, ctx.hurtAt or ctx.base.Position, 3, 4)
			ctx.sound(SND.glass, ctx.hurtAt or ctx.base.Position, 0.25, 1.4, 0.65)       -- (a small crystal tick)
		end },
		{ t = 0.13, fn = function(ctx) ctx.sound(SND.stomp, ctx.hurtAt or ctx.base.Position, 0.45, 1.5) end },  -- (a low stone knock)
	},
}

-- ===================== DEFEAT (3.8 s) =====================
-- ChatGPT batch-1 spec §5 (kid-safe): an internal fracture, it tries to stay up, drops onto its right knee and braces
-- with the left gauntlet, cracks run through it, it breaks into 8 rock groups, the magma dies, and its 16 matter
-- escape as 16 amber motes that streak off toward its home base. Nothing is left: the last rubble sinks.
A.Defeat = {
	dur = 3.8,
	keys = {
		{ t = 0, R = { 0, 0, 0, 0 }, P = { 0, 0, 0, 0 }, yaw = { 0, 0, 0, 0 }, arms = { 0, 0 }, hands = { 0, 0 } },
		{ t = 0.16, ease = "out", R = { -0.12, 0.16, -0.10, -3 }, P = { -2, -3, -3, 2 }, yaw = { 2, 3, -3, 1 }, arms = { -12, -20 }, hands = { -6, -8 } },
		{ t = 0.48, ease = "out", R = { -0.30, 0.28, -0.15, -7 }, P = { -4, -6, -8, 5 }, yaw = { 3, 4, -6, 2 }, arms = { -25, -32 }, hands = { -9, -12 } },
		{ t = 0.80, ease = "smooth", R = { -0.25, -0.10, 0.05, 3 }, P = { 1, 3, 4, -3 }, yaw = { -1, -3, 4, -1 }, arms = { 8, 14 }, hands = { 4, 6 } },
		{ t = 1.10, ease = "in", R = { -1.20, 0.35, 0.20, 9 }, P = { 5, 8, 9, -5 }, yaw = { 2, 4, -3, 1 }, arms = { -8, 30 }, hands = { -7, 9 } },
		{ t = 1.42, ease = "in", R = { -2.45, 0.55, 0.38, 14 }, P = { 8, 11, 12, -8 }, yaw = { 3, 5, -5, 1 }, arms = { -18, 4 }, hands = { -12, 4 } },
		{ t = 1.65, ease = "out", R = { -2.65, 0.58, 0.47, 17 }, P = { 9, 13, 15, -9 }, yaw = { 3, 3, -3, 1 }, arms = { -25, -6 }, hands = { -15, 0 } },
		{ t = 2.05, ease = "smooth", R = { -2.75, 0.65, 0.52, 22 }, P = { 11, 15, 17, -10 }, yaw = { 3, 2, -2, 0 }, arms = { -30, -12 }, hands = { -15, -8 } },
		{ t = 3.80, ease = "smooth", R = { -2.75, 0.65, 0.52, 22 }, P = { 11, 15, 17, -10 }, yaw = { 3, 2, -2, 0 }, arms = { -30, -12 }, hands = { -15, -8 } },
	},
	-- the right leg kneels: its foot slides back 2.4 and tips onto the toe 0.95-1.42 (audit: the knee must reach the ground)
	kneel = { side = "R", t0 = 0.95, t1 = 1.42, back = 2.4, up = 0.45, toe = -55 },
	-- the magma dims from 0.72 and is dead by 2.1; a crack flash runs through it at 1.90
	extra = function(t, pose)
		pose.glowMul = 1 - smooth((t - 0.72) / 1.38)
		if t > 1.9 and t < 2.05 then pose.glow = 0.6 * (1 - (t - 1.9) / 0.15) end
	end,
	-- the left gauntlet braces on the ground beside it (1.35-2.1)
	ik = function(t, ctx)
		local w = (t < 1.35) and 0 or (t < 1.55) and smooth((t - 1.35) / 0.2) or (t < 2.0) and 1 or 1 - smooth((t - 2.0) / 0.1)
		if w <= 0 then return 0 end
		ctx.braceAt = ctx.braceAt or ahead(ctx, 3.8, -3.2)
		return w, ctx.braceAt, nil
	end,
	events = {
		{ t = 0, fn = function(ctx) sparks(ctx, ctx.bonePos("Chest"), 3, 3); ctx.sound(SND.shale, ctx.base.Position, 0.5, 1.0) end },
		{ t = 0.35, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.45, 0.9, 0.25) end },
		{ t = 0.72, fn = function(ctx) return ctx.soundRamp(SND.lava, ctx.base.Position, 0.7, 0.0, 0.9, 0.6, 1.4) end },   -- (the magma dying)
		-- the right knee hits the ground
		{ t = 1.42, fn = function(ctx)
			local k = ctx.bonePos("ShinR")
			local g = Vector3.new(k.X, ctx.ground(k.X, k.Z), k.Z)
			dust(ctx, g, 5, 2.6)
			ctx.sound(SND.stomp, g, 1.6, 0.85)
			ctx.sound(SND.shaleBig, g, 0.6, 1.0)
		end },
		{ t = 1.90, fn = function(ctx)
			ctx.sound(SND.glass, ctx.base.Position, 0.6, 0.8, 0.65)
			local o = ctx.base.Position
			return cracks(ctx, Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z), 7, 2, 5, 0.15, 0.6, MAGMA, true)
		end },
		-- the body breaks into 8 groups (scripted, no physics). Audit: at least 4 must read as the Colossus's own parts, so
		-- the two GAUNTLETS are crystal clusters, the CROWN a rock with its crystal spikes, the TORSO a rock with the glowing
		-- chest core; then 2 shoulder rocks and 2 hip rocks. The body fades out over 2.10-2.22 while they appear; their
		-- magma seams die to 10 % by 3.10 (the giant is out).
		{ t = 2.10, fn = function(ctx)
			local boulder, spike = ctx.FX:FindFirstChild("Boulder"), ctx.FX:FindFirstChild("CrystalSpike")
			if not (boulder and spike) then return end
			local o, right, look = ctx.base.Position, ctx.base.RightVector, ctx.base.LookVector
			local function sized(tmpl, size)
				local c = frag(tmpl); if not c then return nil end
				c.Size = tmpl.Size * (size / math.max(tmpl.Size.X, tmpl.Size.Y, tmpl.Size.Z)); c.Parent = ctx.holder; return c
			end
			-- (12 pieces per Colossus, audit r2: two defeats at once stay inside the 24-fragment budget)
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = MAGMA, Size = Vector3.one * 1.3 })
			local groups = {
				{ main = { spike, 2.6, CFrame.new(0, 0.9, 0) }, extra = { { spike, 2.1, CFrame.Angles(0, 0, 0.5) * CFrame.new(0, 0.9, 0) } }, from = ctx.bonePos("HandL") },
				{ main = { spike, 2.6, CFrame.new(0, 0.9, 0) }, extra = { { spike, 2.1, CFrame.Angles(0, 0, -0.5) * CFrame.new(0, 0.9, 0) } }, from = ctx.bonePos("HandR") },
				{ main = { boulder, 1.8, CFrame.identity }, extra = { { spike, 1.9, CFrame.new(0.5, 0.6, 0) * CFrame.Angles(0, 0, -0.35) }, { spike, 1.6, CFrame.Angles(0, pi, 0) * CFrame.new(0.5, 0.6, 0) * CFrame.Angles(0, 0, -0.35) } }, from = ctx.bonePos("Head") },
				{ main = { boulder, 3.4, CFrame.identity }, from = ctx.bonePos("Belly"), core = core, stays = true },
				{ main = { boulder, 2.8, CFrame.identity }, from = ctx.bonePos("Chest") - right * 1.8, stays = true },
				{ main = { boulder, 2.8, CFrame.identity }, from = ctx.bonePos("Chest") + right * 1.8 },
				{ main = { boulder, 2.5, CFrame.identity }, from = ctx.bonePos("ShinL") },
				{ main = { boulder, 2.5, CFrame.identity }, from = ctx.bonePos("ShinR"), stays = true },
			}
			for _, g in groups do                                   -- (main pieces first)
				g.parts = {}
				local m = sized(g.main[1], g.main[2])
				if m then table.insert(g.parts, { m, g.main[3] }) end
			end
			for _, g in groups do                                   -- (then the decorative spikes, if there is room)
				for _, e in g.extra or {} do
					local x = sized(e[1], e[2])
					if x then table.insert(g.parts, { x, e[3] }) end
				end
				if g.core then table.insert(g.parts, { g.core, CFrame.new(0, 0.2, -1.5) }) end
			end
			for i, g in groups do
				local out = Vector3.new(g.from.X - o.X, 0, g.from.Z - o.Z)
				out = (out.Magnitude > 0.2) and out.Unit or (look * -1)
				local to = g.from + out * (2 + math.random() * 3)
				g.to = Vector3.new(to.X, ctx.ground(to.X, to.Z) + 1.0, to.Z)
				g.lift, g.dur = 1 + math.random() * 2, 0.5 + math.random() * 0.3
				g.rot = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * rad(30 + math.random() * 60)
				g.face = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z)).Rotation
				for _, pp in g.parts do
					local sa = pp[1]:FindFirstChildOfClass("SurfaceAppearance")
					if sa then pp.sa, pp.es = sa, sa.EmissiveStrength end
				end
			end
			local hidden = {}
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d) end
			end
			local c0 = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			dust(ctx, c0, 7, 3.4); sparks(ctx, c0 + Vector3.new(0, 3, 0), 3, 5)
			local rumble = ctx.soundRamp(SND.avalanche, c0, 1.4, 1.0, 1.0, 1.0, 0.8)
			return { step = function(_, t)
				local e = t - 2.10
				if e > 1.7 then return false end
				rumble:step(t)
				local gone = smooth(e / 0.12)                                   -- (the intact body fades out over 0.12 s)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = gone end end
				local seam = 1 - 0.9 * smooth(e / 1.0)                          -- (magma seams to 10 % by 3.10)
				for _, g in groups do
					local u = clamp01(e / g.dur)
					local p = g.from:Lerp(g.to, 1 - (1 - u) ^ 2) + Vector3.new(0, 4 * g.lift * u * (1 - u), 0)
					local sink = g.stays and 0.9 * smooth((t - 3.10) / 0.6) or 0       -- (3 stay as rubble, then sink 0.9)
					local cf = CFrame.new(p - Vector3.new(0, sink, 0)) * g.face * CFrame.fromAxisAngle(g.rot.Unit, g.rot.Magnitude * u)
					local tr = math.max(1 - gone, g.stays and smooth((t - 3.55) / 0.2) or smooth((t - 2.85) / 0.25))
					for _, pp in g.parts do
						pp[1].CFrame = cf * pp[2]
						pp[1].Transparency = tr
						if pp.sa then pp.sa.EmissiveStrength = pp.es * seam end
					end
					if g.core then g.core.Color = MAGMA:Lerp(C3(60, 40, 30), 1 - seam) end
				end
				return true
			end, stop = function()
				rumble:stop()
				for _, g in groups do for _, pp in g.parts do pp[1]:Destroy() end end
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = 0 end end
			end }
		end },
		-- the 16 matter escape: four groups of four motes rise, then streak off toward home (no lights, no emitters)
		{ t = 2.20, fn = function(ctx)
			ctx.sound(SND.power, ctx.base.Position, 0.4, 1.2, 1.2)
			local o = ctx.base.Position
			local home = ctx.home or (o + ctx.base.LookVector * -100)
			local toHome = Vector3.new(home.X - o.X, 0, home.Z - o.Z).Unit
			local side = Vector3.new(-toHome.Z, 0, toHome.X)
			local motes = {}
			for i = 1, 16 do
				local g = (i - 1) // 4
				local a = i * 2.39996
				local start = o + Vector3.new(cos(a) * (0.5 + (i % 4) * 0.5), 3 + (i % 5) * 0.6, sin(a) * (0.5 + (i % 4) * 0.5))
				local m = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = (i % 3 == 0) and W_WHITE or AMBER,
					Transparency = 1, Size = Vector3.one * (0.45 + (i % 3) * 0.08), CFrame = CFrame.new(start) })
				motes[i] = { m = m, born = 2.20 + g * 0.117, start = start, rise = 1 + (i % 4), curve = ((i % 2 == 0) and 1 or -1) * (2 + (i % 5)), up = 1 + (i % 3) }
			end
			return { step = function(_, t)
				if t > 3.5 then return false end
				for _, k in motes do
					local e = t - k.born
					if e < 0 then k.m.Transparency = 1; continue end
					local top = k.start + Vector3.new(0, k.rise, 0)
					local p
					if t < 2.70 then
						p = k.start:Lerp(top, 1 - (1 - clamp01(e / (2.70 - k.born))) ^ 2)
					else
						local u = clamp01((t - 2.70) / 0.75)
						p = top + toHome * 45 * u * u + side * k.curve * sin(u * pi) + Vector3.new(0, k.up * sin(u * pi), 0)
					end
					k.m.CFrame = CFrame.new(p)
					k.m.Transparency = math.max(1 - clamp01(e / 0.12), smooth((t - 3.2) / 0.25)) * 0.9 + 0.05
				end
				return true
			end, stop = function() for _, k in motes do k.m:Destroy() end end }
		end },
		{ t = 2.65, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.9, 1.1) end },
		{ t = 3.10, fn = function(ctx) ctx.sound(SND.tumble, ctx.base.Position, 0.3, 0.9, 0.25) end },
		{ t = 3.75, fn = function(ctx) ctx.braceAt = nil end },
	},
}

-- the pose at time t: interpolated between keys with each segment's easing
local EASE = {
	out = function(u) return 1 - (1 - u) ^ 3 end,
	["in"] = function(u) return u * u * u end,
	smooth = smooth,
	lin = function(u) return u end,
}
function A.pose(atk, t, ctx)
	local keys = (ctx and ctx.keys) or atk.keys
	local k0, k1 = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then k0, k1 = keys[i], keys[i + 1]; break end
	end
	local u = (k1.t > k0.t) and clamp01((t - k0.t) / (k1.t - k0.t)) or 1
	u = (EASE[k1.ease or "smooth"] or smooth)(u)
	if atk.boneKeys then                               -- (per-bone keys: { root = { lift, side, fwd, pitch, roll, yaw }, bones = { Name = { rx, ry, rz, ox, oy, oz } } })
		local function lerp6(a, b)
			local o = table.create(6, 0)
			for i = 1, 6 do o[i] = ((a and a[i]) or 0) + (((b and b[i]) or 0) - ((a and a[i]) or 0)) * u end
			return o
		end
		local p = { root = lerp6(k0.root, k1.root), bones = {}, glow = 0, glowMul = 1 }
		local names = {}
		for n in k0.bones or {} do names[n] = true end
		for n in k1.bones or {} do names[n] = true end
		for n in names do p.bones[n] = lerp6(k0.bones and k0.bones[n], k1.bones and k1.bones[n]) end
		if atk.extra then atk.extra(t, p, ctx) end
		return p
	end
	local function mix(a, b, n)
		local out = table.create(n, 0)
		for i = 1, n do out[i] = (a and a[i] or 0) + ((b and b[i] or 0) - (a and a[i] or 0)) * u end
		return out
	end
	local p = { R = mix(k0.R, k1.R, 4), P = mix(k0.P, k1.P, 4), yaw = mix(k0.yaw, k1.yaw, 4), arms = mix(k0.arms, k1.arms, 2),
		hands = mix(k0.hands, k1.hands, 2), glow = 0, glowMul = 1, armsIn = 0, rootYaw = 0, armYaw = 0 }
	if atk.extra then atk.extra(t, p, ctx) end
	return p
end

-- ============================================================================================================
-- ===================== BATCH 2: the SQUISH TITAN (ChatGPT spec design/13-TITAN-BATCH2-SPEC.md) ================
-- A heavy liquid mass: it redistributes a viscous body while its tentacles lag behind and catch up. Same timing
-- contract as the Colossus: SLAM warn 0.74 / hit 1.64 / free 3.40; BOMB warn 2.40 / spit 2.55 / hit 3.40 / free 2.60;
-- TSUNAMI warn 2.10 / hit 3.20 / free 3.20. Per-bone keys (any rig): root { lift, side, fwd, pitch, roll, yaw },
-- bones { Name = { rx, ry, rz, ox, oy, oz } } in model axes. Tentacles mirror: left (FL/BL, sx +1) = (a, b, c), right
-- (FR/BR) = (a, -b, -c), so +b swings forward and +c lifts on both sides. Titan uses no lights and no camera shake.
-- ============================================================================================================
local G_CYAN, G_VIOLET, G_MINT, G_RIM = C3(55, 245, 255), C3(165, 107, 255), C3(165, 255, 216), C3(40, 32, 27)
local G_FILL = C3(0, 105, 125)   -- (danger fills)
local GSND = {
	slap = "9113520180",     -- Body Hit Wet: the heavy wet slap (measured with the walk)
	thump = "9125404774",    -- Boomy Footsteps Giant (pitched down: the mass under the slap)
	splash = "9120585252",   -- Water Splash, Big, Dive In (3.6 s)
	gurgle = "9125498766",   -- Drain, Bubbling Liquid, Gurgle (1.5 s)
	bubbles = "9125408763",  -- Bubble Magic, Gurgly, Very Wet (2.8 s)
	pop = "9113607285",      -- Bubbling Gurgling, Juicy, Mouth Pop, Spit (2.2 s)
	wobble = "9120784957",   -- Wobble Board, plexiglass warps (1.8 s)
	wiggle = "9113536416",   -- Body Wiggle, wet, squishy, gooshy (14 s: always ramped out)
	goo = "9114631769",      -- Goo (2.9 s)
	waves = "9120617240",    -- Waves, medium to large, rolling in with impacts (3.8 s)
	crash = "9120611182",    -- Wave Crash, massive water impact (21 s: always ramped out)
}
A.GSOUNDS = GSND
local LID_FULL = -175        -- (the animator's lid: -175 swings it from tucked back to fully over the eye)

-- goo droplets (cyan, falling) and bubbles (rising), through the shared particle budget
local function droplets(ctx, pos, n, speed)
	emitterAt(ctx, pos, { Texture = SPARK, Lifetime = NR(0.35, 0.65), Speed = NR(speed or 5, (speed or 5) * 1.8), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -30, 0), LightEmission = 0.5, Size = curve(0.6, 0.5, 0.1),
		Color = CS(C3(120, 240, 255), C3(70, 150, 255)), Transparency = curve(0, 0.15, 1) }, n)
end
local function bubbles(ctx, pos, n)
	emitterAt(ctx, pos, { Texture = SPARK, Lifetime = NR(0.6, 1.0), Speed = NR(1.5, 3), SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 3, 0), LightEmission = 0.4, Size = curve(0.35, 0.5, 0.2),
		Color = CS(G_MINT, G_CYAN), Transparency = curve(0.1, 0.3, 1) }, n)
end
-- a SQUISH outline line: bright on the exact boundary, a dark rim 0.30 wider just under it
-- (a long edge is laid in pieces of 2 studs or less, each on the ground: measured in Play, a single 24-stud plank sank
-- into the terrain's bumps and only bits of the lane's sides showed)
local function gooEdge(ctx, list, a, b, w, color)
	local n = math.max(1, math.ceil((b - a).Magnitude / 2))
	for i = 1, n do
		local p, q = a:Lerp(b, (i - 1) / n), a:Lerp(b, i / n)
		local under = strip(ctx, p, q, w + 0.3, G_RIM, 0.05)
		under.Material = Enum.Material.SmoothPlastic
		under.CFrame -= Vector3.new(0, 0.04, 0)
		table.insert(list, under)
		table.insert(list, strip(ctx, p, q, w, color or G_CYAN, 0.07))
	end
end
-- a thin ring on the ground (n short pieces): ripples and splash rings (a cylinder was a filled disc, not a ring)
local function gooRing(ctx, color, n)
	local segs = {}
	for i = 1, n do segs[i] = part(ctx, { Material = Enum.Material.Neon, Color = color, Transparency = 1, Size = Vector3.new(0.25, 0.06, 1) }) end
	local o = {}
	function o.set(centre, r, tr, w)
		for i, p in segs do
			local a0, a1 = (i - 1) / n * 2 * pi, i / n * 2 * pi
			local a = onGround(ctx, centre + Vector3.new(cos(a0) * r, 0, sin(a0) * r))
			local b = onGround(ctx, centre + Vector3.new(cos(a1) * r, 0, sin(a1) * r))
			p.Size = Vector3.new(w or 0.25, 0.06, (b - a).Magnitude + 0.05)
			p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit) + Vector3.new(0, 0.02, 0)
			p.Transparency = tr
		end
	end
	function o.hide() for _, p in segs do p.Transparency = 1 end end
	function o.destroy() for _, p in segs do p:Destroy() end end
	return o
end
-- a ctx whose ground lookups are remembered on a 0.5-stud grid: a danger shape redraws every frame, the ground doesn't move
local function memoGround(ctx)
	local cache, g = {}, ctx.ground
	return setmetatable({ ground = function(x, z)
		local ix, iz = math.floor(x * 2), math.floor(z * 2)   -- (each cell sampled at its own centre: the same height whatever asks first)
		local k = ix .. ":" .. iz
		local y = cache[k]
		if not y then y = g((ix + 0.5) * 0.5, (iz + 0.5) * 0.5); cache[k] = y end
		return y
	end }, { __index = ctx })
end
-- a flat ellipsoid of goo (a sphere mesh squashed): puddles, the melt cap, the wave crests
local function gooBlob(ctx, color, material)
	local p = part(ctx, { Material = material or Enum.Material.SmoothPlastic, Color = color, Size = Vector3.one, Transparency = 1 })
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	return p, m
end

-- TENTACLE SLAM danger: the exact 120-degree wedge (16 from the centre), a goo fill r = 16 * smooth((t - 0.74) / 0.9),
-- two rounded ripples (1.34 cyan, 1.49 mint) rolling out, two pulses 1.60-1.64
local function gooWedge(ctx, centre: Vector3, face: Vector3, tShow, tHit)
	ctx = memoGround(ctx)
	local R1, HALF, N = 16, rad(60), 32
	local function dir(a) local c, s = cos(a), sin(a); return Vector3.new(face.X * c - face.Z * s, 0, face.X * s + face.Z * c) end
	local outline, fill, rip = {}, {}, { {}, {} }
	for i = 0, N - 1 do
		gooEdge(ctx, outline, centre + dir(-HALF + 2 * HALF * i / N) * R1, centre + dir(-HALF + 2 * HALF * (i + 1) / N) * R1, 0.42)
	end
	gooEdge(ctx, outline, centre, centre + dir(-HALF) * R1, 0.42)     -- (audit r1: the whole boundary, from the centre)
	gooEdge(ctx, outline, centre, centre + dir(HALF) * R1, 0.42)
	local FN = 12
	for i = 1, FN do
		fill[i] = { ps = {}, a = -HALF + 2 * HALF * (i - 0.5) / FN }
		for j = 1, 4 do fill[i].ps[j] = strip(ctx, centre, centre + dir(fill[i].a), 1, G_FILL, 0.04) end
	end
	for k = 1, 2 do for i = 1, 16 do rip[k][i] = strip(ctx, centre, centre + Vector3.new(0, 0, 1), 0.22, (k == 1) and G_CYAN or G_MINT, 0.06) end end
	local w = 2 * HALF / FN
	local function arcAt(list, r, tr)
		for i, p in list do
			local a0, a1 = -HALF + 2 * HALF * (i - 1) / #list, -HALF + 2 * HALF * i / #list
			local a, b = onGround(ctx, centre + dir(a0) * r), onGround(ctx, centre + dir(a1) * r)
			p.Size = Vector3.new(0.22, 0.06, (b - a).Magnitude + 0.05)
			p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit)
			p.Transparency = tr
		end
	end
	return { step = function(_, t)
		if t >= tHit then return false end
		local r = math.max(0.3, R1 * smooth((t - tShow) / 0.9))
		for _, f in fill do
			for j, p in f.ps do
				local a, b = onGround(ctx, centre + dir(f.a) * (r * (j - 1) / 4)), onGround(ctx, centre + dir(f.a) * (r * j / 4))
				p.Size = Vector3.new(w * r * j / 4 + 0.25, 0.04, (b - a).Magnitude + 0.1)
				p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit)
			end
		end
		local pl = (t >= tHit - 0.04) and pulse(t, tHit - 0.04, 2, 0.04) or 0
		setT(outline, 0.05 - 0.05 * pl)
		for _, f in fill do for _, p in f.ps do p.Transparency = 0.72 - 0.3 * pl end end
		for k, t0 in { 1.34, 1.49 } do
			local u = (t - t0) / 0.3
			if u > 0 and u < 1 then arcAt(rip[k], 3 + 13 * u, 0.2 + 0.8 * u) else setT(rip[k], 1) end
		end
		return true
	end, stop = function() for _, l in { outline, rip[1], rip[2] } do for _, p in l do p:Destroy() end end; for _, f in fill do for _, p in f.ps do p:Destroy() end end end }
end

-- GOO BOMB danger: a smooth radius-5 circle (not an octagon), three inward violet-to-mint ripples, a centre dot
-- (opt.grow: the fill spreads out from the centre; every pulse scales with the warning's length W, 1.0 s for the bomb)
local function gooCircle(ctx, centre: Vector3, r, tShow, tHit, opt)
	ctx = memoGround(ctx)
	local W = tHit - tShow
	local outline, N = {}, 18                                   -- (18 sides + 3 rings of 9: ~65 warning pieces per cast, audit r1 batch 3)
	local ro = r / cos(pi / N)                                -- (circumscribed: the true circle sits inside the line)
	for i = 0, N - 1 do
		local a0, a1 = i / N * 2 * pi, (i + 1) / N * 2 * pi
		gooEdge(ctx, outline, centre + Vector3.new(cos(a0) * ro, 0, sin(a0) * ro), centre + Vector3.new(cos(a1) * ro, 0, sin(a1) * ro), 0.36)
	end
	local g = onGround(ctx, centre)
	local disc = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = G_FILL, Transparency = 1,
		Size = Vector3.new(0.04, r * 2, r * 2), CFrame = CFrame.new(g) * CFrame.Angles(0, 0, pi / 2) })
	local dot = part(ctx, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = G_MINT, Transparency = 1,
		Size = Vector3.new(0.05, 1.2, 1.2), CFrame = CFrame.new(g + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, 0, pi / 2) })
	local rings = {}
	for k = 1, 3 do rings[k] = gooRing(ctx, (k == 2) and G_MINT or G_VIOLET, 9) end
	return { step = function(_, t)
		if t >= tHit then return false end
		local e = t - tShow
		local fl = (t > tHit - 0.2 * W) and pulse(t, tHit - 0.2 * W, 2, 0.2 * W) or 0
		setT(outline, 0.05 - 0.05 * fl)
		disc.Transparency = 0.85 - 0.13 * smooth(e / (0.5 * W)) - ((t > tHit - 0.2 * W) and 0.12 or 0)    -- (fill 0.15 -> 0.28 -> 0.40)
		if opt and opt.grow then local d = 2 * r * math.max(0.04, smooth(e / (0.8 * W))); disc.Size = Vector3.new(0.04, d, d) end
		dot.Transparency = 0.6 - 0.5 * fl
		for k, ring in rings do                                 -- (rings run inward 2.90-3.20; decoration only)
			local u = (t - (tShow + 0.5 * W) - (k - 1) * 0.08 * W) / (0.3 * W)
			if u > 0 and u < 1 then ring.set(centre, r * (1 - u) + 0.3, 0.35 + 0.5 * u) else ring.hide() end
		end
		return true
	end, stop = function() for _, p in outline do p:Destroy() end; disc:Destroy(); dot:Destroy(); for _, rg in rings do rg.destroy() end end }
end

-- GOO TSUNAMI danger: the exact lane rectangle (all four corners), a fill running out from the Titan, three swell lines
local function gooLane(ctx, origin: Vector3, face: Vector3, f0, f1, half, tShow, tHit)
	ctx = memoGround(ctx)
	local side = Vector3.new(-face.Z, 0, face.X)
	local function P(f, s) return origin + face * f + side * s end
	local outline = {}
	gooEdge(ctx, outline, P(f0, -half), P(f1, -half), 0.42); gooEdge(ctx, outline, P(f0, half), P(f1, half), 0.42)
	gooEdge(ctx, outline, P(f0, -half), P(f0, half), 0.42); gooEdge(ctx, outline, P(f1, -half), P(f1, half), 0.42)
	local fill = {}
	for j = 1, 18 do fill[j] = strip(ctx, P(f0, 0), P(f0 + 0.5, 0), half * 2 / 3, G_FILL, 0.04) end   -- (6 along x 3 across, each on the ground)
	local swells = {}
	for k = 1, 3 do swells[k] = strip(ctx, P(f0, -half), P(f0, half), 0.35, (k == 2) and G_MINT or G_VIOLET, 0.06) end
	return { step = function(_, t)
		if t >= tHit then return false end
		local reach = f0 + (f1 - f0) * smooth((t - tShow) / 0.65)
		local fl = (t > tHit - 0.16) and 1 or 0
		local len = math.max(0.3, reach - f0)
		for j, p in fill do
			local row, col = (j - 1) // 3, (j - 1) % 3
			local s = -half + half * 2 * (col + 0.5) / 3
			local a, b = onGround(ctx, P(f0 + len * row / 6, s)), onGround(ctx, P(f0 + len * (row + 1) / 6, s))
			p.Size = Vector3.new(half * 2 / 3 + 0.05, 0.04, (b - a).Magnitude + 0.1); p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + (b - a).Unit)
			p.Transparency = 0.7 - 0.3 * fl
		end
		setT(outline, 0.05)
		for k, sw in swells do                                  -- (three swell lines pulse forward 2.75-3.04)
			local u = (t - (tShow + 0.65) - (k - 1) * 0.07) / 0.22
			if u > 0 and u < 1 then
				local f = f0 + (f1 - f0) * u
				local p0, p1 = onGround(ctx, P(f, -half + 0.3)), onGround(ctx, P(f, half - 0.3))
				sw.CFrame = CFrame.lookAt((p0 + p1) / 2, (p0 + p1) / 2 + (p1 - p0).Unit); sw.Size = Vector3.new(0.35, 0.06, (p1 - p0).Magnitude)
				sw.Transparency = 0.2 + 0.6 * u
			else sw.Transparency = 1 end
		end
		return true
	end, stop = function() for _, p in outline do p:Destroy() end; for _, p in fill do p:Destroy() end; for _, p in swells do p:Destroy() end end }
end

-- the key-table builder: rows { t, ease, R, D, T(+oy), L } + tentacle rows { F1, F2, F3 } / { B1, B2, B3 } (mirrored)
local EZ = { O = "out", I = "in", S = "smooth" }
local function titanKeys(rows, front, back, opt)
	-- (audit r1: a stray comment once ate key rows silently; every table must line up with the timeline)
	assert(not front or #front == #rows, "Titan front key count mismatch")
	assert(not back or #back == #rows, "Titan back key count mismatch")
	local keys = {}
	for i, r in rows do
		local b = {}
		b.Body = { r[4][1], r[4][2], r[4][3] }
		b.Top = { r[5][1], r[5][2], r[5][3], 0, (r[5][4] or 0.75) - (opt and opt.absOy and 0 or 0.75), 0 }   -- (oy relative to the idle dome)
		local L = r[6] or 0                                   -- (spec L: +60 = shut; a negative L widens: tuck the lid back a little)
		b.Lid = { (L >= 0) and (LID_FULL * L / 60) or (-L * 0.5) }
		for k, pre in { "F", "B" } do
			local tab = (k == 1) and front or back
			local row = tab and tab[i]
			if row then
				for seg = 1, 3 do
					local v = row[seg]
					if opt and opt.literal then                         -- (hurt: literal chains for a push toward +X)
						b["Tent" .. pre .. "L" .. seg] = { v[1], v[2], v[3] }
						local w = row[seg + 3]
						b["Tent" .. pre .. "R" .. seg] = { w[1], w[2], w[3] }
					else
						b["Tent" .. pre .. "L" .. seg] = { v[1], v[2], v[3] }
						b["Tent" .. pre .. "R" .. seg] = { v[1], -v[2], -v[3] }
					end
				end
			end
		end
		local n = 0; for _ in b do n += 1 end
		assert(n == 3 + (front and 6 or 0) + (back and 6 or 0), "Titan key " .. r[1] .. " is missing bones")
		keys[i] = { t = r[1], ease = EZ[r[2]] or "smooth", root = { r[3][1], r[3][2], r[3][3], r[3][4], r[3][5], r[3][6] }, bones = b }
	end
	return keys
end

-- ===================== A. TENTACLE SLAM (crush) =====================
A.TSlam = {
	boneKeys = true, dur = 3.8, lock = 3.4,
	-- (both front tips held 0.08-0.18 above the ground at the hit: in 1.60-1.64, out 1.73-1.86; a tip moves 0.155 studs per
	-- degree of its root, measured; at most 12 deg of extra turn)
	contact = { chains = { "TentFL", "TentFR" }, t0 = 1.60, t1 = 1.64, t2 = 1.73, t3 = 1.86, target = 0.13, perDeg = 0.155, maxDeg = 12 },
	keys = titanKeys({
		{ 0.00, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
		{ 0.25, "O", { -0.18, 0, -0.12, 5, 0, 0 }, { 6, 0, 0 }, { 4, 0, 0, 0.30 }, -5 },
		{ 0.74, "S", { 0, 0, -0.05, 7, 0, 0 }, { 9, 0, 0 }, { 6, 0, 0, 0.95 }, -10 },
		{ 1.16, "O", { 0.18, 0, -0.15, 9, 0, 0 }, { 11, 0, 0 }, { 8, 0, 0, 1.18 }, -12 },
		{ 1.44, "I", { 0.08, 0, 0.20, 1, 0, 0 }, { -3, 0, 0 }, { -2, 0, 0, 0.95 }, 0 },
		{ 1.64, "I", { -0.22, 0, 0.58, -7, 0, 0 }, { -11, 0, 0 }, { -8, 0, 0, 0.18 }, 3 },
		{ 1.86, "O", { -0.30, 0, 0.66, -9, 0, 0 }, { -13, 0, 0 }, { -11, 0, 0, 0.08 }, 6 },
		{ 2.25, "O", { -0.08, 0, 0.22, -2, 0, 0 }, { -4, 0, 0 }, { -2, 0, 0, 0.55 }, 0 },
		{ 2.90, "S", { 0.05, 0, -0.05, 2, 0, 0 }, { 2, 0, 0 }, { 1, 0, 0, 0.86 }, 0 },
		{ 3.40, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 10, 2, 3 }, { 8, 1, 5 }, { -8, 0, 6 } }, { { 24, 3, 7 }, { 22, 1, 11 }, { -18, 0, 5 } },
		{ { 32, 2, 10 }, { 25, 0, 14 }, { -23, 0, 7 } }, { { 8, 2, 4 }, { 6, 0, 8 }, { -5, 0, 2 } }, { { 18, 2, 1 }, { -32, 0, 1 }, { 0, 0, -2 } },
		{ { 27, 1, -3 }, { -39, 0, -1 }, { 0, 0, -4 } }, { { -7, 0, 3 }, { 4, 0, 4 }, { 9, 0, 5 } }, { { 4, 0, 5 }, { 2, 0, 3 }, { -2, 0, 2 } },   -- (1.64 / 1.86: measured contact, see BUILD-LOG)
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { -2, 0, 3 }, { 0, 0, 4 }, { 0, 0, 5 } }, { { -4, 0, 5 }, { 0, 0, 7 }, { 0, 0, 8 } },
		{ { -6, 0, 7 }, { 0, 0, 9 }, { 0, 0, 12 } }, { { 1, 0, 8 }, { 0, 0, 10 }, { 0, 0, 10 } }, { { -5, 0, 4 }, { 0, 0, 5 }, { 0, 0, 7 } },
		{ { -8, 0, 2 }, { 0, 0, 4 }, { 0, 0, 5 } }, { { 3, 0, 5 }, { 0, 0, 6 }, { 0, 0, 7 } }, { { 1, 0, 2 }, { 0, 0, 3 }, { 0, 0, 3 } },
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	}),
	events = {
		{ t = 0, fn = function(ctx) ctx.sound(GSND.gurgle, ctx.base.Position, 0.6, 0.7) end },                       -- (low wet gurgle)
		{ t = 0.25, fn = function(ctx) return ctx.soundRamp(GSND.wiggle, ctx.base.Position, 0.5, 0.7, 0.8, 0.9, 0.7) end },   -- (rubber stretch)
		{ t = 0.74, fn = function(ctx)
			ctx.sound(GSND.bubbles, ctx.base.Position, 0.35, 0.8)
			local o = ctx.base.Position
			return gooWedge(ctx, Vector3.new(o.X, 0, o.Z), Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z).Unit, 0.74, 1.64)
		end },
		{ t = 0.85, fn = function(ctx) droplets(ctx, ctx.bonePos("TentFL3"), 2, 3); droplets(ctx, ctx.bonePos("TentFR3"), 2, 3) end },
		{ t = 1.16, fn = function(ctx) ctx.sound(GSND.goo, ctx.base.Position, 0.9, 0.8) end },                       -- (suction / strain)
		{ t = 1.44, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.9, 1.4, 0.7) end },
		-- IMPACT: both tips crush the ground; a loud wet slap over a short pitched-down thump, splash, rings (no shake)
		{ t = 1.64, fn = function(ctx)
			local pts = {}
			for _, n in { "TentFL3", "TentFR3" } do local p = ctx.bonePos(n); table.insert(pts, Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)) end
			local c = (pts[1] + pts[2]) / 2
			ctx.sound(GSND.slap, c, 2.6, 0.75)
			ctx.sound(GSND.thump, c, 1.4, 0.7)
			ctx.sound(GSND.splash, c, 0.9, 1.1)
			droplets(ctx, pts[1], 4, 7); droplets(ctx, pts[2], 4, 7)
			-- non-damaging goo ripples spreading from each tip, gone by 2.15
			local rings = {}
			local mg = memoGround(ctx)
			for i in pts do rings[i] = gooRing(mg, (i == 1) and G_CYAN or G_MINT, 16) end
			return { step = function(_, t)
				local e = t - 1.64
				if e > 0.51 then return false end
				for i, rg in rings do rg.set(pts[i], 1 + 6 * smooth(e / 0.5), 0.3 + 0.7 * smooth(e / 0.5)) end
				return true
			end, stop = function() for _, rg in rings do rg.destroy() end end }
		end },
		{ t = 1.86, fn = function(ctx) ctx.sound(GSND.splash, ctx.base.Position, 0.5, 0.75) end },                   -- (thick slosh)
		{ t = 2.25, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.7, 0.8) end },                    -- (wobbly rebound)
		{ t = 2.30, fn = function(ctx) droplets(ctx, ctx.bonePos("TentFL2"), 2, 3); droplets(ctx, ctx.bonePos("TentFR2"), 2, 3) end },
		{ t = 2.90, fn = function(ctx) ctx.sound(GSND.goo, ctx.base.Position, 0.5, 1.1) end },                       -- (soft squelch settle)
	},
}

-- ===================== B. GOO BOMB (trap) =====================
local function bombKeys(k)
	return titanKeys({
		{ 0.00, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
		{ 0.40, "O", { -0.08, 0, -0.12, 5, 0, 0 }, { 6, 0, 0 }, { 4, 0, 0, 0.95 }, -5 },
		{ 1.25, "S", { -0.14, 0, -0.18, 9, 0, 0 }, { 10, 0, 0 }, { 9, 0, 0, 1.35 }, -9 },
		{ 1.85, "O", { 0.02, 0, -0.12, 11, 0, 0 }, { 13, 0, 0 }, { 11, 0, 0, 1.55 }, -13 },
		{ 2.32, "S", { 0.06, 0, 0.10, 5, 0, 0 }, { 6, 0, 0 }, { 3, 0, 0, 1.35 }, -8 },
		{ 2.55, "I", { -0.08, 0, 0.35 + 0.30 * k, -5, 0, 0 }, { -9, 0, 0 }, { -12, 0, 0, 0.60 }, 4 },
		{ 2.60, "O", { -0.06, 0, 0.25 + 0.20 * k, -3, 0, 0 }, { -7, 0, 0 }, { -7, 0, 0, 0.55 }, 3 },
		{ 2.85, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 3, 0, 3 }, { 2, 0, 3 }, { 0, 0, 2 } }, { { 6, 0, 5 }, { 4, 0, 6 }, { -3, 0, 4 } },
		{ { 8, 0, 7 }, { 6, 0, 8 }, { -5, 0, 6 } }, { { 4, 0, 4 }, { 3, 0, 5 }, { -2, 0, 3 } }, { { 8, 0, -2 }, { -25, 0, -3 }, { 4, 0, -2 } },
		{ { 1, 0, -2 }, { -22, 0, -1 }, { 3, 0, -1 } }, { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },   -- (2.55 / 2.60: measured at k = 1)
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, 3 }, { 0, 0, 4 }, { 0, 0, 4 } }, { { -2, 0, 5 }, { 0, 0, 7 }, { 0, 0, 8 } },
		{ { -3, 0, 7 }, { 0, 0, 10 }, { 0, 0, 12 } }, { { -1, 0, 5 }, { 0, 0, 7 }, { 0, 0, 9 } }, { { 2, 0, -2 }, { 0, 0, -4 }, { 0, 0, -5 } },
		{ { 1, 0, -2 }, { 0, 0, -3 }, { 0, 0, -4 } }, { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	})
end
-- the mouth (fixed cavity): ~(0, 8, -6.5) in the model, turned toward the target with the aim
local function mouthAt(ctx)
	local top = ctx.bonePos("Top")
	local fwd = ctx.aim and Vector3.new(ctx.aim.X - ctx.base.Position.X, 0, ctx.aim.Z - ctx.base.Position.Z).Unit or Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z).Unit
	return top + fwd * 6.7 + Vector3.new(0, 2.07, 0)
end
A.Bomb = {
	boneKeys = true, dur = 5.9, lock = 2.6, aims = true,
	keys = bombKeys(1),
	keysFor = function(k) return bombKeys(k) end,
	-- (aimed: root 10, body 8, top 12 degrees of turn at a full 30-degree target, built up 0.40-1.85, held through the spit)
	extra = function(t, p, ctx)
		if not (ctx and ctx.aimTheta) then return end
		local s = (ctx.aimTheta / 30) * smooth((t - 0.40) / 1.45)
		p.root[6] += 10 * s
		p.bones.Body[2] += 8 * s; p.bones.Top[2] += 12 * s
	end,
	events = {
		{ t = 0.40, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.6, 0.85); bubbles(ctx, ctx.bonePos("Top"), 3) end },   -- (bubbling inhale)
		{ t = 1.25, fn = function(ctx) ctx.sound(GSND.gurgle, ctx.base.Position, 0.8, 0.8); bubbles(ctx, ctx.bonePos("Top"), 3) end },
		{ t = 1.85, fn = function(ctx)                                                                                     -- (the mouth bulge, popping at 2.55)
			return ctx.soundRamp(GSND.wiggle, ctx.base.Position, 0.4, 0.8, 0.9, 1.1, 0.6)
		end },
		{ t = 1.85, fn = function(ctx)
			local b, m = gooBlob(ctx, G_CYAN, Enum.Material.Neon)
			return { step = function(_, t)
				if t > 2.6 then return false end
				local g = smooth((t - 1.85) / 0.47) + 0.12 * sin(t * 30) * smooth((t - 2.2) / 0.1)
				local d = 0.6 + 2.6 * g
				m.Scale = Vector3.new(d, d * 0.9, d)
				b.CFrame = CFrame.new(mouthAt(ctx))
				b.Transparency = (t > 2.55) and 1 or 0.15
				return true
			end, stop = function() b:Destroy() end }
		end },
		-- the landing circle: radius 5 on the target, fixed at the cast
		{ t = 2.40, fn = function(ctx)
			local a = ctx.aim or ahead(ctx, 26, 0)
			ctx.bombHit = Vector3.new(a.X, ctx.ground(a.X, a.Z), a.Z)
			ctx.sound(GSND.bubbles, ctx.bombHit, 0.3, 1.3)
			return gooCircle(ctx, ctx.bombHit, 5, 2.40, 3.40)
		end },
		-- the goo ball: spat at 2.55, an arc 5 + 4k high, 0.85 s, 1.25 turns, stretched along its path; splats into a
		-- sticky radius-5 puddle (3.40-5.55, gone by 5.90)
		{ world = true, t = 2.55, fn = function(ctx)
			local k = ctx.aimK or 1
			local from = mouthAt(ctx)
			local hit = ctx.bombHit or ahead(ctx, 26, 0)
			local dia = 3.6 + 0.8 * k
			local H = 5 + 4 * k
			ctx.sound(GSND.pop, from, 1.0, 0.8)
			ctx.sound(SND.whoosh, from, 0.6, 1.2, 0.7)
			droplets(ctx, from, 4, 5)
			local ball, bm = gooBlob(ctx, G_CYAN, Enum.Material.SmoothPlastic)
			local core, cm = gooBlob(ctx, G_VIOLET, Enum.Material.Neon)
			local pud, pm = gooBlob(ctx, G_CYAN, Enum.Material.SmoothPlastic)
			local pin, pim = gooBlob(ctx, G_VIOLET, Enum.Material.SmoothPlastic)
			local ring = gooRing(memoGround(ctx), G_MINT, 20)
			-- (the puddle's lumpy rim: five squashed blobs around the edge, so it reads as spilled goo, not a coaster)
			local lumps = {}
			for i = 1, 5 do
				local b, m = gooBlob(ctx, G_CYAN, Enum.Material.SmoothPlastic)
				local a = i / 5 * 2 * pi + 0.4
				lumps[i] = { b = b, m = m, off = Vector3.new(cos(a), 0, sin(a)) * (3.25 + (i % 2) * 0.35), s = 1.6 + (i % 3) * 0.4 }   -- (inside the radius-5 zone: audit r1)
			end
			local landed = false
			return { step = function(_, t)
				if t > 5.9 then return false end
				if t < 3.40 then
					local u = clamp01((t - 2.55) / 0.85)
					local p = from:Lerp(hit + Vector3.new(0, dia * 0.5, 0), u) + Vector3.new(0, 4 * H * u * (1 - u), 0)   -- (touches the ground at 3.40)
					local v = (hit - from) + Vector3.new(0, 4 * H * (1 - 2 * u), 0)
					local cf = CFrame.lookAt(p, p + v) * CFrame.Angles(0, 0, u * 2.5 * pi)
					local st = 1 + 0.18 * math.sin(u * pi)
					bm.Scale = Vector3.new(dia / st, dia / st, dia * st)
					ball.CFrame, ball.Transparency, ball.Reflectance = cf, 0.35, 0.15
					cm.Scale = bm.Scale * 0.55; core.CFrame, core.Transparency = cf, 0.2
				else
					if not landed then
						landed = true
						ball.Transparency, core.Transparency = 1, 1
						ctx.sound(GSND.slap, hit, 2.0, 0.85); ctx.sound(GSND.splash, hit, 0.7, 1.2)
						droplets(ctx, hit, 8, 7); bubbles(ctx, hit, 4)
					end
					local e = t - 3.40
					local spread = smooth(e / 0.15)                            -- (flattens into the puddle in 0.15 s)
					local fade = smooth((t - 5.55) / 0.35)
					local wob = 1 + 0.03 * sin(t * 6)
					pm.Scale = Vector3.new(9.7 * spread * wob, 0.4 + 2.5 * (1 - spread), 9.7 * spread / wob)   -- (never wider than the r = 5 slow zone)
					pud.CFrame = CFrame.new(hit + Vector3.new(0, 0.05, 0))
					pud.Transparency, pud.Reflectance = 0.25 + 0.75 * fade, 0.12
					pim.Scale = Vector3.new(5 * spread, 0.3, 3.8 * spread)          -- (the violet core off-centre, slowly turning)
					pin.CFrame = CFrame.new(hit + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, t * 0.4, 0) * CFrame.new(0.9, 0, -0.4)
					pin.Transparency = 0.45 + 0.55 * fade
					for i, l in lumps do
						local w = 1 + 0.06 * sin(t * 5 + i)
						l.m.Scale = Vector3.new(l.s * spread * w, 0.7 * spread, l.s * 0.8 * spread / w)
						l.b.CFrame = CFrame.new(hit + l.off * spread + Vector3.new(0, 0.1, 0))
						l.b.Transparency, l.b.Reflectance = 0.25 + 0.75 * fade, 0.12
					end
					if e < 0.3 then ring.set(hit, 1 + 4.2 * smooth(e / 0.18), 0.2 + 0.8 * smooth(e / 0.3)) else ring.hide() end   -- (mint splash ring; not a 2nd hit)
				end
				return true
			end, stop = function() ball:Destroy(); core:Destroy(); pud:Destroy(); pin:Destroy(); ring.destroy(); for _, l in lumps do l.b:Destroy() end end }
		end },
		{ world = true, t = 3.55, fn = function(ctx) if ctx.bombHit then ctx.sound(GSND.bubbles, ctx.bombHit, 0.5, 1.2); bubbles(ctx, ctx.bombHit, 2) end end },
		{ world = true, t = 5.55, fn = function(ctx) if ctx.bombHit then ctx.sound(GSND.gurgle, ctx.bombHit, 0.3, 1.3) end end },
		{ world = true, t = 5.85, fn = function(ctx) ctx.bombHit = nil end },
	},
}

-- ===================== C. GOO TSUNAMI (overwhelm, its ORDER) =====================
-- The lane runs 6-30 studs from its centre (24 long in front of its 6-stud body), 12 wide. The fast leading surge
-- crosses it 3.04-3.20 (it is fully engulfed at the hit), a taller crest rolls on 3.20-4.30, ripples fade by 5.30.
A.Wave = {
	boneKeys = true, dur = 5.3, lock = 3.2,
	keys = titanKeys({
		{ 0.00, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
		{ 0.45, "O", { -0.12, 0, -0.10, 5, 0, 0 }, { 7, 0, 0 }, { 6, 0, 0, 0.90 }, -5 },
		{ 1.10, "S", { 0.20, 0, -0.16, 10, 0, 0 }, { 12, 0, 0 }, { 9, 0, 0, 1.35 }, -9 },
		{ 1.70, "O", { 0.42, 0, -0.22, 14, 0, 0 }, { 17, 0, 0 }, { 12, 0, 0, 1.70 }, -12 },
		{ 2.10, "S", { 0.45, 0, -0.24, 15, 0, 0 }, { 19, 0, 0 }, { 14, 0, 0, 1.90 }, -14 },
		{ 2.65, "I", { 0.22, 0, 0.08, 5, 0, 0 }, { 6, 0, 0 }, { 4, 0, 0, 1.40 }, -5 },
		{ 3.00, "I", { -0.06, 0, 0.45, -6, 0, 0 }, { -10, 0, 0 }, { -12, 0, 0, 0.50 }, 3 },
		{ 3.20, "I", { -0.42, 0, 0.80, -10, 0, 0 }, { -17, 0, 0 }, { -18, 0, 0, -0.40 }, 8 },
		{ 3.45, "O", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 5, 1, 3 }, { 5, 0, 5 }, { -3, 0, 4 } }, { { 14, 2, 8 }, { 12, 0, 10 }, { -8, 0, 8 } },
		{ { 23, 4, 12 }, { 20, 0, 16 }, { -14, 0, 11 } }, { { 28, 5, 15 }, { 24, 0, 19 }, { -17, 0, 13 } }, { { 12, 4, 12 }, { 9, 0, 15 }, { -8, 0, 10 } },
		{ { 8, 2, 4 }, { -18, 0, 5 }, { -4, 0, 3 } }, { { 34, 1, -4 }, { -40, 0, -6 }, { 5, 0, -8 } }, { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },   -- (3.00 / 3.20: measured)
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 0, 0, 5 }, { 0, 0, 8 }, { 0, 0, 8 } }, { { -2, 0, 10 }, { 0, 0, 14 }, { 0, 0, 15 } },
		{ { -5, 0, 15 }, { 0, 0, 21 }, { 0, 0, 24 } }, { { -6, 0, 18 }, { 0, 0, 24 }, { 0, 0, 27 } }, { { -2, 0, 16 }, { 0, 0, 21 }, { 0, 0, 23 } },
		{ { 4, 0, 8 }, { 0, 0, 12 }, { 0, 0, 14 } }, { { -8, 0, -2 }, { 0, 0, -6 }, { 0, 0, -9 } }, { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	}),
	events = {
		{ t = 0, fn = function(ctx) return ctx.soundRamp(SND.lava, ctx.base.Position, 0.3, 0.9, 0.7, 0.9, 2.0) end },   -- (deep liquid rumble)
		{ t = 0.45, fn = function(ctx) return ctx.soundRamp(GSND.wiggle, ctx.base.Position, 0.4, 0.8, 0.8, 1.0, 1.0) end },  -- (rising wet stretch)
		{ t = 1.10, fn = function(ctx) ctx.sound(GSND.gurgle, ctx.base.Position, 0.9, 0.75); ctx.sound(GSND.bubbles, ctx.base.Position, 0.6, 0.7) end },
		{ t = 1.70, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.9, 0.6) end },                     -- (large wobbling swell)
		{ world = true, t = 2.10, fn = function(ctx)
			ctx.sound(GSND.bubbles, ctx.base.Position, 0.35, 0.6)
			local o = ctx.base.Position
			local face = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z).Unit
			ctx.waveO, ctx.waveF = Vector3.new(o.X, 0, o.Z), face
			-- (the power graph's lane, design/power/sim.mjs: from the Titan's centre, length 24 + its 6-stud body radius = 0..30)
			return gooLane(ctx, ctx.waveO, face, 0, 30, 6, 2.10, 3.20)
		end },
		{ world = true, t = 2.65, fn = function(ctx) ctx.sound(GSND.goo, ctx.base.Position, 1.0, 0.7); droplets(ctx, ahead(ctx, 6, 0) + Vector3.new(0, 2, 0), 6, 5) end },  -- (suction release)
		-- the wave: a fast low surge to the end of the lane by 3.20, then a taller crest rolling on, then ripples
		{ world = true, t = 3.04, fn = function(ctx)
			local O, F = ctx.waveO, ctx.waveF
			if not (O and F) then return end
			local S = Vector3.new(-F.Z, 0, F.X)
			local crest, sheet, foam = {}, nil, {}
			for i = 1, 4 do local b, m = gooBlob(ctx, (i % 2 == 0) and G_CYAN or C3(80, 210, 255)); crest[i] = { b = b, m = m, s = -4.3 + (i - 1) * 2.87 } end
			local sb, sm = gooBlob(ctx, C3(70, 190, 255)); sheet = { b = sb, m = sm }
			local vb, vm = gooBlob(ctx, G_VIOLET); local violet = { b = vb, m = vm }
			for i = 1, 3 do foam[i] = part(ctx, { Material = Enum.Material.Neon, Color = G_MINT, Transparency = 1, Size = Vector3.new(11, 0.12, 0.4) }) end
			-- (audit r1: a curling lip over the crest, three lobes tipped 50 deg forward with a violet underside, so it reads
			-- as a breaking wave and not a rolling blob; cosmetic only, inside the lane at the hit)
			local lip = {}
			for i = 1, 3 do
				local b, m = gooBlob(ctx, C3(160, 250, 255)); local ub, um = gooBlob(ctx, G_VIOLET)   -- (lighter than the crest: it reads on top)
				lip[i] = { b = b, m = m, ub = ub, um = um, s = (i - 2) * 3.7 }
			end
			local rush = ctx.soundRamp(GSND.waves, O + F * 18, 1.4, 1.0, 1.0, 1.0, 1.8)
			return { step = function(_, t)
				if t > 5.3 then return false end
				rush:step(t)
				local front, h
				if t < 3.20 then front, h = 6 + 24 * smooth((t - 3.04) / 0.16), 2.5 + 2 * smooth((t - 3.04) / 0.16)
				elseif t < 4.30 then front, h = 30 + 3 * smooth((t - 3.20) / 1.1), 4.5 - 3.3 * smooth((t - 3.20) / 1.1)
				else front, h = 33, 1.2 * (1 - smooth((t - 4.3) / 1.0)) end
				local fade = smooth((t - 4.3) / 1.0)
				for i, c in crest do                                   -- (the rounded crest, four overlapping lobes across 11.5)
					local p = O + F * (front - 1.5) + S * c.s
					local g = ctx.ground(p.X, p.Z)
					local wob = 1 + 0.08 * sin(t * 9 + i)
					c.m.Scale = Vector3.new(3.4, math.max(0.2, h * 1.6 * wob), 3.0)
					c.b.CFrame = CFrame.new(p.X, g + h * 0.2, p.Z) * CFrame.Angles(0, math.atan2(-F.X, -F.Z), 0) * CFrame.Angles(rad(-25), 0, 0)
					c.b.Transparency = 0.1 + 0.9 * fade
				end
				local lipFade = (t < 3.10) and 1 or smooth((t - 3.6) / 0.7)        -- (grows on the surge, gone with the crest by 4.30)
				local yaw = CFrame.Angles(0, math.atan2(-F.X, -F.Z), 0)
				for i, l in lip do
					-- (measured: at 0.65 x the height the lip sat inside the crest; on its top edge it overhangs; its tip stays inside the lane)
					local p = O + F * (front - 1.1) + S * l.s
					local g = ctx.ground(p.X, p.Z)
					local wob = 1 + 0.06 * sin(t * 8 + i * 2)
					l.m.Scale = Vector3.new(3.7, 1.1 * wob, 2.2)
					l.b.CFrame = CFrame.new(p.X, g + 0.92 * h, p.Z) * yaw * CFrame.Angles(rad(-50), 0, 0)
					l.b.Transparency = 0.1 + 0.9 * lipFade
					l.um.Scale = Vector3.new(3.3, 0.5, 1.5)
					l.ub.CFrame = l.b.CFrame * CFrame.new(0, -0.35, 0.1)
					l.ub.Transparency = 0.3 + 0.7 * lipFade
				end
				local back = (t < 3.20) and 6 or 6 + 18 * smooth((t - 3.20) / 1.4)   -- (the sheet drains toward the end)
				local mid = O + F * ((front + back) / 2)
				local len = math.max(0.5, front - back)
				sheet.m.Scale = Vector3.new(11.5, 1.2 * (1 - fade) + 0.2, len)
				sheet.b.CFrame = CFrame.new(mid.X, ctx.ground(mid.X, mid.Z) + 0.15, mid.Z) * CFrame.Angles(0, math.atan2(-F.X, -F.Z), 0)
				sheet.b.Transparency = 0.25 + 0.75 * fade
				violet.m.Scale = Vector3.new(6, 0.6, len * 0.6)
				violet.b.CFrame = sheet.b.CFrame + Vector3.new(0, 0.1, 0)
				violet.b.Transparency = 0.5 + 0.5 * fade
				for i, f in ipairs(foam) do                              -- (mint foam lines riding the crest)
					local p = O + F * (front - 2.5 - i * 1.2)
					f.CFrame = CFrame.new(p.X, ctx.ground(p.X, p.Z) + 0.4 + h * 0.2, p.Z) * CFrame.Angles(0, math.atan2(-F.X, -F.Z), 0)
					f.Transparency = (t > 3.1) and (0.35 + 0.65 * fade) or 1
				end
				return true
			end, stop = function() rush:stop(); for _, c in crest do c.b:Destroy() end; for _, l in lip do l.b:Destroy(); l.ub:Destroy() end; sheet.b:Destroy(); violet.b:Destroy(); for _, f in foam do f:Destroy() end end }
		end },
		{ world = true, t = 3.20, fn = function(ctx)
			local c = (ctx.waveO or ctx.base.Position) + (ctx.waveF or ctx.base.LookVector) * 18
			c = Vector3.new(c.X, ctx.ground(c.X, c.Z), c.Z)
			ctx.sound(GSND.splash, c, 1.6, 0.85); ctx.sound(GSND.thump, c, 1.2, 0.6)
			droplets(ctx, c, 8, 9); bubbles(ctx, c, 6)
		end },
		{ world = true, t = 3.65, fn = function(ctx)
			local c = (ctx.waveO or ctx.base.Position) + (ctx.waveF or ctx.base.LookVector) * 24
			return ctx.soundRamp(GSND.crash, Vector3.new(c.X, ctx.ground(c.X, c.Z), c.Z), 0.6, 0.3, 1.0, 1.0, 1.2)
		end },
		{ world = true, t = 3.70, fn = function(ctx) local c = (ctx.waveO or ctx.base.Position) + (ctx.waveF or ctx.base.LookVector) * 26; droplets(ctx, Vector3.new(c.X, ctx.ground(c.X, c.Z), c.Z), 4, 4) end },
		{ world = true, t = 5.25, fn = function(ctx) ctx.waveO, ctx.waveF = nil, nil end },
	},
}

-- ===================== HURT (0.52 s, additive) =====================
-- A giant liquid-filled balloon: a dent, a small sideways give, a rebound. Keys for a push toward +X (the animator
-- mirrors them for the other side); the lid only half-flinches (the eye stays readable).
A.THurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,   -- (keys push toward +X: a hit on the -X side)
	keys = titanKeys({
		{ 0.00, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0 }, 0 },
		{ 0.05, "O", { -0.05, 0.06, -0.04, 1, -2, 1 }, { -1, 1, -2 }, { -2, 1, -3, -0.06 }, 5 },
		{ 0.13, "I", { -0.14, 0.14, -0.09, 3, -4, 3 }, { -3, 2, -5 }, { -4, 3, -7, -0.16 }, 13 },
		{ 0.24, "S", { -0.08, 0.08, -0.04, -1, 2, -1 }, { 2, -1, 2 }, { 3, -1, 4, -0.06 }, 7 },
		{ 0.40, "S", { 0, 0.02, 0, 0, -1, 0 }, { -1, 0, -1 }, { -1, 0, -1, 0.02 }, 0 },
		{ 0.52, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0 }, 0 },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
		{ { -3, 1, 2 }, { -2, 0, 2 }, { 2, 0, 2 }, { 1, -1, -4 }, { 2, 0, -3 }, { 2, 0, -3 } },
		{ { -8, 2, -3 }, { -6, 0, -4 }, { 4, 0, -4 }, { 4, -2, -8 }, { 5, 0, -7 }, { -3, 0, -6 } },
		{ { 3, 1, 3 }, { 4, 0, 4 }, { -2, 0, 3 }, { -3, -1, -5 }, { -2, 0, -4 }, { 3, 0, -4 } },
		{ { -1, 0, 1 }, { -1, 0, 1 }, { 0, 0, 1 }, { 1, 0, -1 }, { 1, 0, -1 }, { 0, 0, -1 } },
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
		{ { -2, 0, 2 }, { 0, 0, 3 }, { 0, 0, 3 }, { 1, 0, -4 }, { 0, 0, -4 }, { 0, 0, -4 } },
		{ { -5, 0, -4 }, { 0, 0, -6 }, { 0, 0, -7 }, { 4, 0, -9 }, { 0, 0, -11 }, { 0, 0, -12 } },
		{ { 3, 0, 4 }, { 0, 0, 5 }, { 0, 0, 6 }, { -2, 0, -5 }, { 0, 0, -6 }, { 0, 0, -7 } },
		{ { -1, 0, 1 }, { 0, 0, 2 }, { 0, 0, 2 }, { 1, 0, -2 }, { 0, 0, -2 }, { 0, 0, -2 } },
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } },
	}, { literal = true, absOy = true }),
	extra = function(t, p) if t > 0.13 and t < 0.21 then p.glowMul = 0.88 end end,
	events = {
		{ t = 0, fn = function(ctx)
			ctx.sound(GSND.slap, ctx.hurtAt or ctx.base.Position, 0.6, 1.35)                   -- (a short, soft wet knock)
			droplets(ctx, ctx.hurtAt or ctx.base.Position, 3, 4); bubbles(ctx, ctx.hurtAt or ctx.base.Position, 2)
		end },
		{ t = 0.13, fn = function(ctx) ctx.sound(GSND.goo, ctx.hurtAt or ctx.base.Position, 0.35, 1.3) end },          -- (rubber compression)
		{ t = 0.24, fn = function(ctx) ctx.sound(GSND.wobble, ctx.hurtAt or ctx.base.Position, 0.45, 1.2) end },       -- (wobbly rebound)
	},
}

-- ===================== DEFEAT (3.8 s, kid-safe) =====================
-- Wobbles (two unequal sways), sags with the eye closing, then MELTS: a goo cap grows under it and the body fades into
-- it by 2.10; the puddle spreads (12.5 x 10.5 at 2.25) and shrinks away by 3.80; 16 cyan motes leave in four groups
-- of four (2.20 / 2.45 / 2.70 / 2.95) and streak ~45 studs toward home.
A.TDefeat = {
	boneKeys = true, dur = 3.8,
	keys = titanKeys({
		{ 0.00, "S", { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0, 0.75 }, 0 },
		{ 0.16, "O", { -0.10, 0.12, -0.08, -3, -2, 2 }, { -2, 2, -3 }, { -3, 3, -4, 0.65 }, 8 },
		{ 0.48, "O", { -0.25, -0.24, -0.12, 5, 5, -3 }, { 6, -2, 8 }, { 7, -4, 10, 0.92 }, 0 },
		{ 0.80, "S", { -0.13, 0.18, 0.05, -2, -4, 4 }, { -4, 3, -7 }, { -5, 3, -8, 0.58 }, 18 },
		{ 1.10, "I", { -0.42, -0.22, 0.12, 7, 4, -3 }, { 8, -1, 6 }, { 11, -2, 8, 0.15 }, 33 },
		{ 1.42, "I", { -0.72, 0.10, 0.25, 10, -3, 1 }, { 11, 0, -6 }, { 12, 1, -7, -0.50 }, 54 },
		{ 1.70, "O", { -0.92, -0.09, 0.32, 3, 2, 0 }, { -9, 0, 4 }, { -11, 0, 6, -1.05 }, 60 },
		{ 2.05, "S", { -1.02, 0, 0.20, 0, 0, 0 }, { -4, 0, 0 }, { -6, 0, 0, -1.75 }, 60 },
		{ 3.80, "S", { -1.02, 0, 0.20, 0, 0, 0 }, { -4, 0, 0 }, { -6, 0, 0, -1.75 }, 60 },
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { 5, 2, 2 }, { 2, 0, 3 }, { -4, 0, 2 } }, { { -4, 4, -2 }, { 7, 0, 9 }, { -8, 0, 8 } },
		{ { 8, -2, 8 }, { -4, 0, 4 }, { 6, 0, 4 } }, { { -12, 2, -4 }, { -5, 0, -8 }, { 9, 0, -7 } }, { { -19, 1, -8 }, { -15, 0, -12 }, { 12, 0, -9 } },
		{ { 10, 0, -12 }, { -40, 0, -16 }, { 15, 0, -12 } }, { { 8, 0, -15 }, { -41, 0, -14 }, { 18, 0, -10 } }, { { 8, 0, -15 }, { -41, 0, -14 }, { 18, 0, -10 } },   -- (1.70+: draped flat, measured)
	}, {
		{ { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }, { { -2, 0, 5 }, { 0, 0, 7 }, { 0, 0, 6 } }, { { 5, 0, 10 }, { 0, 0, 15 }, { 0, 0, 17 } },
		{ { -5, 0, 6 }, { 0, 0, 8 }, { 0, 0, 10 } }, { { -7, 0, -6 }, { 0, 0, -10 }, { 0, 0, -14 } }, { { -10, 0, 10 }, { 0, 0, -17 }, { 0, 0, -20 } },
		{ { -12, 0, -16 }, { 0, 0, -22 }, { 0, 0, -25 } }, { { -15, 0, -19 }, { 0, 0, -25 }, { 0, 0, -28 } }, { { -15, 0, -19 }, { 0, 0, -25 }, { 0, 0, -28 } },
	}),
	-- its cyan glow drains as it melts
	extra = function(t, p) p.glowMul = 1 - smooth((t - 0.8) / 1.3) end,
	events = {
		{ t = 0, fn = function(ctx)
			-- (MOVE TEST repeats a finished defeat: the body starts visible again)
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then d.LocalTransparencyModifier = 0 end end
			ctx.sound(GSND.gurgle, ctx.base.Position, 0.8, 0.85)                                                          -- (a low surprised gurgle)
		end },
		{ t = 0.48, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.9, 0.7) end },
		{ t = 0.80, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.6, 0.6); droplets(ctx, ctx.bonePos("Top"), 5, 3) end },  -- (falling liquid tone)
		{ t = 1.42, fn = function(ctx) ctx.sound(GSND.slap, ctx.base.Position, 1.6, 0.7); ctx.sound(GSND.thump, ctx.base.Position, 0.6, 0.6) end },  -- (soft heavy collapse)
		-- the MELT: a goo cap grows from under the body and becomes the puddle; the body fades into it 1.86-2.10
		{ t = 1.86, fn = function(ctx)
			local o = ctx.base.Position
			local g = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			local cap, cm = gooBlob(ctx, G_CYAN, Enum.Material.SmoothPlastic)
			local inner, im = gooBlob(ctx, G_VIOLET, Enum.Material.SmoothPlastic)
			local hidden, was, done = {}, {}, false
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); was[d] = d.LocalTransparencyModifier end end
			-- six small goo blobs flung out of the melt (scripted, no physics)
			local blobs = {}
			for i = 1, 6 do
				local b, bm = gooBlob(ctx, (i % 2 == 0) and G_CYAN or G_MINT, Enum.Material.SmoothPlastic)
				if not claimFrag(b) then break end
				local a = i / 6 * 2 * pi + 0.3
				blobs[i] = { b = b, m = bm, v = Vector3.new(cos(a) * (5 + i % 3), 7 + (i % 2) * 3, sin(a) * (5 + i % 3)) }
			end
			-- footprint by time, from the spec (X radius x Z radius): 1.86 10.5x8.5, 2.10 11.5x9.5, 2.25 12.5x10.5 (25 wide:
			-- the whole 21-stud Titan pooled), 3.10 7.5x6.0, 3.55 2.5x2.0, 3.80 gone
			local KT = { { 1.86, 10.5, 8.5, 3.5 }, { 2.10, 11.5, 9.5, 0.6 }, { 2.25, 12.5, 10.5, 0.4 }, { 3.10, 7.5, 6.0, 0.3 }, { 3.55, 2.5, 2.0, 0.2 }, { 3.80, 0, 0, 0.05 } }
			local function foot(t)
				for i = 1, #KT - 1 do
					local a, b = KT[i], KT[i + 1]
					if t <= b[1] then local u = smooth((t - a[1]) / (b[1] - a[1])); return a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u end
				end
				return 0, 0, 0
			end
			return { step = function(_, t)
				if t > 3.8 then done = true; return false end
				local gone = smooth((t - 1.86) / 0.24)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = gone end end
				local rx, rz, h = foot(t)
				cm.Scale = Vector3.new(rx * 2 + 0.01, h * 2 + 0.01, rz * 2 + 0.01)
				cap.CFrame = CFrame.new(g + Vector3.new(0, h * 0.4, 0)) * CFrame.Angles(0, math.atan2(-ctx.base.LookVector.X, -ctx.base.LookVector.Z), 0)
				cap.Transparency = 0.15 + 0.85 * smooth((t - 3.1) / 0.7)
				im.Scale = cm.Scale * Vector3.new(0.55, 0.9, 0.55)
				inner.CFrame = cap.CFrame + Vector3.new(0, 0.05, 0)
				inner.Transparency = 0.35 + 0.65 * smooth((t - 3.0) / 0.6)
				for _, bl in blobs do
					local e = t - 1.9
					if e < 0 then bl.b.Transparency = 1 else
						local p = g + Vector3.new(0, 3, 0) + bl.v * e + Vector3.new(0, -28 * e * e / 2, 0)
						local gy = ctx.ground(p.X, p.Z) + 0.3
						local landed = p.Y < gy
						if landed then p = Vector3.new(p.X, gy, p.Z) end
						bl.m.Scale = landed and Vector3.new(1.6, 0.35, 1.6) or Vector3.new(1, 1.2, 1)
						bl.b.CFrame = CFrame.new(p)
						bl.b.Transparency = smooth((t - 2.9) / 0.4)
					end
				end
				return true
			end, stop = function()
				cap:Destroy(); inner:Destroy()
				for _, bl in blobs do bl.b:Destroy() end
				if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end   -- (cancelled: put it back)
			end }
		end },
		{ t = 2.10, fn = function(ctx) ctx.sound(GSND.splash, ctx.base.Position, 0.9, 0.85); droplets(ctx, ctx.base.Position, 7, 6) end },   -- (a large, gentle goo splat)
		-- the 16 matter escape: four groups of four cyan motes spiral up, then streak toward home (no lights, no emitters)
		{ t = 2.20, fn = function(ctx)
			ctx.sound(SND.glass, ctx.base.Position, 0.25, 1.6, 0.65)                                                    -- (a bright little chime)
			local o = ctx.base.Position
			local home = ctx.home or (o - ctx.base.LookVector * 100)
			local toHome = Vector3.new(home.X - o.X, 0, home.Z - o.Z).Unit
			local side = Vector3.new(-toHome.Z, 0, toHome.X)
			local motes = {}
			for i = 1, 16 do
				local gI = (i - 1) // 4
				local a = i * 2.39996
				local r0 = 0.5 + (i % 4) * 0.9
				local sx, sz = o.X + cos(a) * r0, o.Z + sin(a) * r0
				local start = Vector3.new(sx, ctx.ground(sx, sz) + 0.6, sz)
				local m = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = (i % 3 == 0) and G_MINT or G_CYAN,
					Transparency = 1, Size = Vector3.one * (0.42 + (i % 3) * 0.08), CFrame = CFrame.new(start) })
				motes[i] = { m = m, born = 2.20 + gI * 0.25, a = a, start = start, rise = 1 + (i % 4), curve = ((i % 2 == 0) and 1 or -1) * (2 + (i % 5)), up = 1 + (i % 3) }
			end
			return { step = function(_, t)
				if t > 3.8 then return false end
				for _, k in motes do
					local e = t - k.born
					if e < 0 then k.m.Transparency = 1; continue end
					local top = k.start + Vector3.new(cos(k.a + 1.5) * 0.8, k.rise, sin(k.a + 1.5) * 0.8)
					local p
					if e < 0.3 then                                        -- (a short spiral up)
						local u = 1 - (1 - e / 0.3) ^ 2
						local sp = k.a + u * 1.5
						p = k.start:Lerp(top, u) + Vector3.new(cos(sp), 0, sin(sp)) * 0.8 * (1 - u)
					else
						local u = clamp01((e - 0.3) / 0.5)
						p = top + toHome * 45 * u * u + side * k.curve * sin(u * pi) + Vector3.new(0, k.up * sin(u * pi), 0)
					end
					k.m.CFrame = CFrame.new(p)
					k.m.Transparency = math.max(1 - clamp01(e / 0.1), smooth((e - 0.65) / 0.15)) * 0.9 + 0.05
				end
				return true
			end, stop = function() for _, k in motes do k.m:Destroy() end end }
		end },
		{ t = 2.20, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.5, 0.7) end },                 -- (one whoosh per group, at its birth)
		{ t = 2.45, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.6, 0.7) end },
		{ t = 2.70, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.7, 0.7) end },
		{ t = 2.95, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.8, 0.7) end },
		{ t = 3.10, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.4, 1.1) end },                    -- (a quiet bubbling fade)
		{ t = 3.75, fn = function(ctx) ctx.sound(GSND.pop, ctx.base.Position, 0.35, 1.3) end },                       -- (a soft final pop)
	},
}

A.FOR = A.FOR or {}
A.FOR.SquishF4v5 = { Slam = A.TSlam, Bomb = A.Bomb, Wave = A.Wave, Defeat = A.TDefeat, Hurt = A.THurt }

-- ============================================================================================================
-- ===================== BATCH 3a: the SQUISH TWIN (spec design/14-TWIN-BATCH3-SPEC-chatgpt-raw.md) ================
-- Built to match its reference sheets (design/concepts/twin/attacks/: J1 DOUBLE SLAP, J2 STICKY FLOOR, J3 BOING SLAM,
-- J4 HURT + DEFEAT, K EFFECTS). Effects are real goo meshes (GooMesh: crown, puddle, ring, drop, lump), never spheres.
-- Rig: Root -> Base (its puddle) -> Body (lower lobe) -> Top (upper lobe, eye, horns) -> Lid; Tend<L R><1-3> from Body.
-- L = its left = -X. A left tendril DROPS with +rz and swings FORWARD with +rx; the right chain mirrors (rx, -ry, -rz, -ox).
-- (ChatGPT's tables flipped the tendril rz sign against this rig: its "strike" raised the tendrils away from its own
-- ground contacts. Built to its stated intent + contact points, measured in Play.)
-- ============================================================================================================
do
local TAU = 2 * pi
local GooMesh = require(script.Parent:WaitForChild("GooMesh"))
local function gm(ctx, kind, seed, size, cf, extra) return GooMesh.make(kind, seed, size, cf, ctx.holder, extra) end
-- a mesh droplet flung on a short ballistic arc (cell 5): spawns, flies `life` s, flattens into a landed splat
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
				d.CFrame = CFrame.lookAt(p, p + v) * CFrame.Angles(pi / 2, 0, 0)   -- (round end leads, the tail trails)
				d.Transparency = 0
			end
		end
		if landed then                                               -- (a flat little splat where it landed, then gone)
			local u = clamp01((e - landT) / 0.24)
			if u >= 1 then return false end
			d.Size = Vector3.new(size * 1.5, size * 0.35 * (1 - u) + 0.02, size * 1.4)
			d.CFrame = CFrame.new(landed + Vector3.new(0, d.Size.Y / 2, 0))
			d.Transparency = u
		end
		return true
	end, stop = function() d:Destroy() end }
end
-- a goo mesh that plays scale / opacity keys: keys = { { t, sx, sy, sz, opacity }, ... } on a base size; `place` = the
-- ground point under it (the mesh is centred, so it is lifted by half its height and stays sat on the ground)
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

-- the Twin's keys: rows { t, ease, R (lift, side, fwd, pitch, roll, yaw), Body (rx, ry, rz, ox, oy, oz), Top (same), L (lid),
-- T1, T2, T3 (left tendril segments: { rx, ry, rz, ox, oy, oz }) } -> per-bone keys (right chain mirrored)
local function twinKeys(rows)
	local keys = {}
	for i, r in rows do
		local b = { Body = r.B or { 0, 0, 0 }, Top = r.T or { 0, 0, 0 }, Base = r.P or { 0, 0, 0 } }
		local L = r.L or 0
		b.Lid = { (L >= 0) and (LID_FULL * L / 60) or (-L * 0.5) }
		for seg = 1, 3 do
			local v = (r.tend and r.tend[seg]) or { 0, 0, 0 }
			b["TendL" .. seg] = { v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0, v[5] or 0, v[6] or 0 }
			b["TendR" .. seg] = { v[1] or 0, -(v[2] or 0), -(v[3] or 0), -(v[4] or 0), v[5] or 0, v[6] or 0 }
		end
		for k, v in r.extra or {} do b[k] = v end
		local R = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { R[1] or 0, R[2] or 0, R[3] or 0, R[4] or 0, R[5] or 0, R[6] or 0 }, bones = b }
	end
	return keys
end
-- (tendril shorthands: left segment rotations rx (forward), rz (+ = down))
local function T3(a, b, c) return { { a[1], 0, a[2] }, { b[1], 0, b[2] }, { c[1], 0, c[2] } } end

-- ===================== A. DOUBLE SLAP (passive, every 1.0 s; hit 0.39) =====================
-- wind-up 0-0.22: both tendrils coil UP and back, the body squashes and leans back; 0.33-0.39 both whip out and DOWN at
-- once, stretched long and thin onto two ground points left and right; recoil with a wobble; free 0.56; FX gone 0.72
-- (contact points, model space. Measured in Play: the spec's +-2.05 landed just past its own puddle and read as a tap;
-- +-3.3 gives the reference's wide V, the tendrils stretched long and thin)
local SLAP_PT = { L = Vector3.new(-3.3, 0, -0.6), R = Vector3.new(3.3, 0, -0.6) }
A.TSlap2 = {
	boneKeys = true, dur = 1.0, cycle = 1.0, lock = 0.56,
	keys = twinKeys({
		{ 0.00, "smooth" },
		{ 0.12, "out", R = { 0, 0, 0, 5 }, B = { 2, 0, 0, 0, -0.10 }, T = { 5, 0, 0 }, tend = T3({ -10, -20 }, { -12, -28 }, { -8, -22 }) },
		{ 0.22, "in", R = { 0, 0, 0, 8 }, B = { 4, 0, 0, 0, -0.20 }, T = { 6, 0, 0, 0, -0.14 }, L = 6, tend = T3({ -16, -38 }, { -20, -48 }, { -12, -36 }) },
		{ 0.33, "in", R = { 0, 0, 0, -3 }, B = { -2, 0, 0, 0, 0.08 }, T = { -3, 0, 0, 0, 0.12 }, tend = T3({ 8, 4 }, { 10, 18 }, { 8, 20 }) },
		{ 0.39, "in", R = { 0, 0, 0, -7 }, B = { -4, 0, 0, 0, 0.30 }, T = { -6, 0, 0, 0, 0.30 }, L = -6, tend = T3({ 14, 22 }, { 12, 34 }, { 10, 30 }) },
		{ 0.48, "out", B = { -1, 0, 3, 0, 0.06 }, T = { 0, 0, 3 }, tend = T3({ 6, 6 }, { 5, 10 }, { 4, 8 }) },
		{ 0.63, "out", B = { 1, 0, -3, 0, -0.09 }, T = { 0, 0, -3 }, tend = T3({ -4, -8 }, { -5, -10 }, { -4, -8 }) },
		{ 0.82, "smooth", B = { 0, 0, 0, 0, 0.03 }, tend = T3({ 2, 3 }, { 2, 4 }, { 2, 3 }) },
		{ 1.00, "smooth" },
	}),
	-- both tips stretched onto their ground points (the reference strike: "stretched long and thin"), in 0.30-0.37,
	-- held to 0.43, released by 0.56; at most 2.6 studs of stretch (outer two segments: the shoulder bone drags the body)
	reach = {
		{ chain = { "TendL2", "TendL3" }, t0 = 0.30, t1 = 0.37, t2 = 0.43, t3 = 0.56, max = 2.6,
			target = function(ctx) local p = ctx.base * SLAP_PT.L; return Vector3.new(p.X, ctx.ground(p.X, p.Z) + 0.25, p.Z) end },
		{ chain = { "TendR2", "TendR3" }, t0 = 0.30, t1 = 0.37, t2 = 0.43, t3 = 0.56, max = 2.6,
			target = function(ctx) local p = ctx.base * SLAP_PT.R; return Vector3.new(p.X, ctx.ground(p.X, p.Z) + 0.25, p.Z) end },
	},
	events = {
		{ t = 0.17, fn = function(ctx) ctx.sound(GSND.wiggle, ctx.base.Position, 0.45, 1.6) end },          -- (rubbery tension)
		-- 0.39: the two slaps land together: a splat crown under each tip + one droplet each
		{ t = 0.39, fn = function(ctx)
			ctx.sound(GSND.slap, ctx.base.Position, 0.85, 1.25)                                                -- (one composite wet smack)
			local fx = {}
			for _, k in { "L", "R" } do
				local p = ctx.base * SLAP_PT[k]
				local g = Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
				local c = gooKeyed(ctx, "crown", (k == "L") and 11 or 12, Vector3.new(2.2, 0.9, 2.0), CFrame.new(g) * CFrame.Angles(0, (k == "L") and 0.4 or 2.1, 0), {
					{ 0.39, 0.40, 0.25, 0.40, 0 }, { 0.42, 1.0, 1.0, 1.0, 1 }, { 0.51, 1.15, 0.48, 1.15, 1 }, { 0.72, 1.20, 0.08, 1.20, 0 } }, 6)
				if c then table.insert(fx, c) end
				local out = (g - ctx.base.Position) * Vector3.new(1, 0, 1)
				out = out.Magnitude > 0.1 and out.Unit or ctx.base.RightVector
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.4, 0), out * 3 + Vector3.new(0, 6, 0), 0.3, 0.32, 0.40)
				if dr then table.insert(fx, dr) end
			end
			return { step = function(_, t) local alive = false; for _, f in fx do if f:step(t) then alive = true end end; return alive end,
				stop = function() for _, f in fx do f:stop() end end }
		end },
	},
}

-- ===================== B. STICKY FLOOR (auto; warn 0.5, hit 0.5, free 0.85, FX end 3.2) =====================
-- it squashes and hugs itself, its puddle bulges, then surges out in a wide rolling rim to radius 5 by the hit; the pool
-- holds (strands + bubbles) to 3.0 and pulls back in by 3.2
A.Sticky = {
	boneKeys = true, dur = 3.2, lock = 0.85,
	keys = twinKeys({
		{ 0.00, "smooth" },
		{ 0.16, "in", R = { 0, 0, 0, 5 }, B = { 0, 0, 0, 0, -0.18 }, T = { 0, 0, 0, 0, -0.16 }, L = 8, tend = T3({ 6, 16 }, { 8, 26 }, { 6, 22 }) },
		{ 0.28, "in", R = { 0, 0, 0, 9 }, B = { 0, 0, 0, 0, -0.31 }, T = { 0, 0, 0, 0, -0.33 }, L = 14, tend = T3({ 10, 28 }, { 14, 40 }, { 10, 34 }) },
		{ 0.43, "in", R = { 0, 0, 0, 9 }, B = { 0, 0, 0, 0, -0.39 }, T = { 0, 0, 0, 0, -0.43 }, P = { 0, 0, 0, 0, -0.04 }, L = 18, tend = T3({ 14, 36 }, { 18, 48 }, { 14, 40 }) },
		{ 0.50, "in", R = { 0, 0, 0, -5 }, B = { 0, 0, 0, 0, -0.27 }, T = { 0, 0, 0, 0, -0.26 }, tend = T3({ -6, -30 }, { -8, -38 }, { -6, -28 }) },
		{ 0.68, "out", B = { 0, 0, 0, 0, 0.12 }, T = { 0, 0, 0, 0, 0.09 }, tend = T3({ -4, -40 }, { -4, -42 }, { -3, -24 }) },
		{ 0.85, "out", B = { 0, 0, 0, 0, -0.07 }, T = { 0, 0, 0, 0, -0.05 }, tend = T3({ -2, -26 }, { -2, -24 }, { -1, -14 }) },
		{ 1.12, "smooth", tend = T3({ 0, -18 }, { 0, -16 }, { 0, -10 }) },                 -- (tendrils spread, like the sheet)
		{ 3.00, "smooth", tend = T3({ 0, -18 }, { 0, -16 }, { 0, -10 }) },
		{ 3.20, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			local o = ctx.base.Position
			ctx.stickyAt = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			return gooCircle(ctx, ctx.stickyAt, 5, 0, 0.5, { grow = true })
		end },
		{ t = 0.25, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.5, 0.75) end },          -- (low bubbling compression)
		{ t = 0.32, fn = function(ctx)
			ctx.sound(GSND.goo, ctx.base.Position, 0.75, 0.7)                                                 -- (thick rolling surge)
			local g = ctx.stickyAt or ctx.base.Position
			local fx = {}
			-- the pool (cell 2): 10 wide, a rolling raised rim; 1.25 radius at 0.32 -> 5 by 0.50, held, back by 3.20
			local pool = gooKeyed(ctx, "pool", 1, Vector3.new(10, 0.34, 10),   -- (audit r1: the authored 11-lobe pool)
				 CFrame.new(g + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, ctx.base.Position.X % 6.28, 0), {
				{ 0.32, 0.125, 0.5, 0.125, 1 }, { 0.43, 0.70, 1.15, 0.70, 1 }, { 0.50, 1.0, 1.0, 1.0, 1 }, { 3.00, 1.0, 1.0, 1.0, 1 }, { 3.20, 0.65, 0.40, 0.65, 0 } })
			if pool then pool.part.Reflectance = 0.1; table.insert(fx, pool) end
			-- the surge ring racing out with the rim (cell 4), gone once the pool is full
			local ring = gooKeyed(ctx, "ring", 22, Vector3.new(10, 0.5, 10), CFrame.new(g + Vector3.new(0, 0.05, 0)), {
				{ 0.32, 0.15, 1.2, 0.15, 1 }, { 0.50, 1.0, 1.0, 1.0, 1 }, { 0.70, 1.04, 0.5, 1.04, 0 } })
			if ring then table.insert(fx, ring) end
			-- sticky strands (four tall pulled peaks: upside-down drops) and six bubbles (small lumps) across the pool
			for i = 1, 4 do
				local a = i * 1.7 + 0.4
				local p = g + Vector3.new(cos(a) * (1.8 + i * 0.6), 0, sin(a) * (1.8 + i * 0.6))
				local h = 1.2 + 0.12 * i                                   -- (1.32-1.68 tall, audit r2)
				local s = gooKeyed(ctx, "drop", 0, Vector3.new(0.38, h, 0.38), CFrame.new(p.X, ctx.ground(p.X, p.Z), p.Z), {
					{ 0.40, 1, 0.1, 1, 0 }, { 0.60, 1, 1, 1, 1 }, { 3.00, 1, 1, 1, 1 }, { 3.20, 1, 0.05, 1, 0 } })
				if s then table.insert(fx, s) end
			end
			for i = 1, 6 do
				local a = i * 2.39 + 1
				local rr = 1.5 + (i % 3) * 1.1
				local p = g + Vector3.new(cos(a) * rr, 0, sin(a) * rr)
				local sz = 0.55 + (i % 3) * 0.12                            -- (0.55-0.79 wide, audit r2)
				local b = gooKeyed(ctx, "lump", 30 + i, Vector3.new(sz, sz * 0.7, sz), CFrame.new(p.X, ctx.ground(p.X, p.Z), p.Z), {
					{ 0.55, 0.2, 0.2, 0.2, 0 }, { 0.75, 1, 1, 1, 0.75 }, { 3.00, 1, 1, 1, 0.75 }, { 3.15, 0.3, 0.3, 0.3, 0 } })
				if b then table.insert(fx, b) end
			end
			return { step = function(_, t)
				local alive = false
				for _, f in fx do if f:step(t) then alive = true end end
				-- (a slow heavy undulation of the held pool: +-0.07 on a 0.9 s cycle)
				if pool and t > 0.65 and t < 3.0 then
					local y = 0.34 * (1 + 0.18 * sin(t * TAU / 0.9))
					pool.part.Size = Vector3.new(10, y, 10)
					pool.part.CFrame = CFrame.new(g + Vector3.new(0, 0.02 + y / 2, 0)) * pool.part.CFrame.Rotation   -- (bottom stays on the ground)
				end
				return alive
			end, stop = function() for _, f in fx do f:stop() end end }
		end },
		{ t = 3.00, fn = function(ctx) ctx.sound(GSND.goo, ctx.base.Position, 0.35, 1.2) end },
	},
}

-- ===================== C. BOING SLAM (ORDER; warn 0.8, land 0.80, free 1.25, FX end 1.85) =====================
-- locked landing point (aimed, up to 14 away): deep squash, a tall thin launch (its puddle left behind as a splash), a
-- flattened forward-tipped apex with tendrils wide, then a flat belly-flop into a big splash crown + a shock ring to r5
local BOING_KEYS = {
	{ 0.00, "smooth" },
	{ 0.12, "in", R = { 0, 0, 0, 7 }, B = { 12, 0, 0, 0, -0.22 }, T = { 6, 0, 0, 0, -0.22 }, L = 18, tend = T3({ -19, -43 }, { -27, -50 }, { -16, -26 }) },
	{ 0.20, "in", R = { 0, 0, 0, 11 }, B = { 18, 0, 0, 0, -0.46 }, T = { 7, 0, 0, 0, -0.49 }, L = 26, tend = T3({ -19, -43 }, { -27, -50 }, { -16, -26 }) },
	{ 0.22, "in", R = { 0, 0, 0, 12 }, B = { 15, 0, 0, 0, -0.48 }, T = { 5, 0, 0, 0, -0.46 }, L = 20, tend = T3({ -30, -55 }, { -30, -58 }, { -18, -30 }) },
	{ 0.30, "out", R = { 2.6, 0, 1.7, 14 }, B = { 9, 0, 0, 0, 0.42 }, T = { 7, 0, 0, 0, 0.47 }, L = -6, tend = T3({ -39, -57 }, { -32, -63 }, { -22, -37 }) },
	{ 0.40, "smooth", R = { 6.1, 0, 4.4, 0 }, B = { -12, 0, 0, 0, 0.23 }, T = { 8, 0, 0, 0, 0.20 }, tend = T3({ -10, -60 }, { -8, -66 }, { -4, -40 }) },
	{ 0.52, "smooth", R = { 8.0, 0, 7.0, -24 }, B = { -33, 0, 0, 0, -0.16 }, T = { 18, 0, 0, 0, -0.12 }, L = -4, tend = T3({ 18, -66 }, { 11, -72 }, { 10, -44 }) },
	{ 0.66, "in", R = { 5.8, 0, 10.5, -51 }, B = { -29, 0, 0, 0, -0.21 }, T = { 17, 0, 0, 0, -0.12 }, tend = T3({ 31, -48 }, { 25, -57 }, { 19, -35 }) },
	{ 0.76, "in", R = { 1.45, 0, 13.2, -62 }, B = { -19, 0, 0, 0, -0.26 }, T = { 31, 0, 0, 0, -0.18 }, L = 10, tend = T3({ 31, -20 }, { 25, -20 }, { 19, -10 }) },
	{ 0.80, "in", R = { 0.45, 0, 14, -67 }, B = { -17, 0, 0, 0, -0.42 }, T = { 37, 0, 0, 0, -0.24 }, L = 24, tend = T3({ 35, 10 }, { 28, 6 }, { 22, 4 }) },   -- (lift 0.45: measured, the belly sat 0.35 into the ground)
	{ 0.91, "out", R = { 0.35, 0, 14, -23 }, B = { 7, 0, 0, 0, -0.37 }, T = { 6, 0, 0, 0, -0.27 }, L = 10, tend = T3({ -9, -26 }, { -15, -32 }, { -12, -18 }) },
	{ 1.08, "out", R = { 0, 0, 14, 7 }, B = { 8, 0, 0, 0, -0.13 }, T = { 1, 0, 0, 0, -0.10 }, tend = T3({ 4, 8 }, { 6, 12 }, { 4, 7 }) },
	{ 1.25, "smooth", R = { 0, 0, 14, 0 } },
	{ 1.85, "smooth", R = { 0, 0, 14, 0 } },
}
A.Boing = {
	boneKeys = true, dur = 1.85, lock = 1.25, testLock = 1.85, aims = true, testAims = "TEST_AIMS_SHORT",   -- (testLock: MOVE TEST units hold the landing spot)
	keys = twinKeys(BOING_KEYS),
	-- (aimed: the jump goes to the locked landing point; the keys' 14-stud forward travel is rescaled to the real
	-- distance and turned toward it; a short hop gets a lower arc)
	extra = function(t, p, ctx)
		-- (audit r1: ONE landing vector, cached at the cast (event 0), drives the travel, the turn, the circle and the splash)
		local v = ctx and ctx.boingVec or Vector3.new(0, 0, -14)
		local d = Vector2.new(v.X, v.Z).Magnitude
		local f = p.root[3] / 14                                    -- (0 -> 1 along the jump)
		local dir = d > 0.1 and Vector2.new(v.X, v.Z).Unit or Vector2.new(0, -1)
		p.root[2] = dir.X * d * f                                   -- (side)
		p.root[3] = -dir.Y * d * f                                  -- (fwd: +fwd = -Z)
		if t < 0.78 then p.root[1] *= math.clamp(d / 10, 0.4, 1) end   -- (a short hop flies lower; the landing clearance never scales)
		p.root[6] += math.deg(math.atan2(-dir.X, -dir.Y)) * smooth(t / 0.2)   -- (it turns toward the landing point)
	end,
	events = {
		-- the landing circle, fixed at the cast
		{ t = 0, fn = function(ctx)
			local a = ctx.aim or ahead(ctx, 14, 0)
			local v = ctx.base:PointToObjectSpace(a) * Vector3.new(1, 0, 1)
			if v.Magnitude > 14 then v = v.Unit * 14 end
			if v.Magnitude < 0.05 then v = Vector3.zero end
			ctx.boingVec = v                                              -- (model space, frozen for the whole jump)
			local w = ctx.base * v
			ctx.boingAt = Vector3.new(w.X, ctx.ground(w.X, w.Z), w.Z)
			return gooCircle(ctx, ctx.boingAt, 5, 0, 0.8, { grow = true })
		end },
		{ t = 0.14, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.55, 1.3) end },          -- (spring tension)
		-- launch: its puddle splashes up where it stood (a crown 1.7x the slap splat) and a ground puddle fades there
		{ t = 0.22, fn = function(ctx)
			ctx.sound(GSND.pop, ctx.base.Position, 0.85, 1.1)
			local o = ctx.base.Position
			local g = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			local fx = {}
			local c = gooKeyed(ctx, "crown", 41, Vector3.new(2.8, 1.1, 2.5), CFrame.new(g), {
				{ 0.22, 0.5, 0.3, 0.5, 0 }, { 0.26, 1.0, 1.0, 1.0, 1 }, { 0.40, 1.1, 0.5, 1.1, 1 }, { 0.67, 1.15, 0.08, 1.15, 0 } }, 7)
			if c then table.insert(fx, c) end
			local pd = gooKeyed(ctx, "puddle", 42, Vector3.new(4.2, 0.18, 4.0), CFrame.new(g + Vector3.new(0, 0.02, 0)), {
				{ 0.22, 1, 1, 1, 1 }, { 0.60, 1.1, 0.6, 1.1, 0.8 }, { 0.95, 1.15, 0.2, 1.15, 0 } })
			if pd then table.insert(fx, pd) end
			for i = 1, 3 do
				local a = i * 2.1
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.5, 0), Vector3.new(cos(a) * 2, 9 + i, sin(a) * 2), 0.32, 0.5, 0.23)
				if dr then table.insert(fx, dr) end
			end
			return { step = function(_, t) local alive = false; for _, f in fx do if f:step(t) then alive = true end end; return alive end,
				stop = function() for _, f in fx do f:stop() end end }
		end },
		-- its shadow on the landing point (a dark flat puddle, not a danger mark): 2.3 x 1.6 at the apex -> 3.5 x 2.7 at touchdown
		{ t = 0.30, fn = function(ctx)
			local g = ctx.boingAt
			if not g then return end
			local sh = gm(ctx, "puddle", 43, Vector3.new(2.3, 0.04, 1.6), CFrame.new(g + Vector3.new(0, 0.05, 0)))
			if not sh then return end
			for _, d in sh:GetChildren() do d:Destroy() end
			sh.Color, sh.Material = Color3.fromRGB(20, 22, 30), Enum.Material.SmoothPlastic
			return { step = function(_, t)
				if t >= 0.80 then return false end
				local u = smooth((t - 0.30) / 0.5)
				local b = ctx.bonePos("Body")                                -- (straight under the Twin)
				sh.CFrame = CFrame.new(b.X, ctx.ground(b.X, b.Z) + 0.05, b.Z)
				sh.Size = Vector3.new(2.3 + 1.2 * u, 0.04, 1.6 + 1.1 * u)
				sh.Transparency = 0.75 - 0.3 * u
				return true
			end, stop = function() sh:Destroy() end }
		end },
		{ t = 0.70, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.45, 1.5, 0.7) end },         -- (descending whoosh)
		-- (audit r1: the apex silhouette: the rig's puddle can't leave its Root, so a FLIGHT body (twin_dent_flight.py: the
		-- Twin posed with tendrils spread, puddle removed, 1.45 x wide, 0.65 x tall) replaces the rig 0.36-0.72, riding the
		-- Body bone; 0.05 s crossfades)
		{ t = 0.20, fn = function(ctx)
			local fl = gm(ctx, "twinFlight", 1, Vector3.new(3.44, 2.58, 3.80), CFrame.new())
			if not fl then return end
			fl.Transparency = 1
			local parts, was = {}, {}                                    -- (every rendered part of the rig, saved)
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(parts, d); was[d] = d.LocalTransparencyModifier end end
			local b = ctx.m:FindFirstChild("Body", true)
			return { step = function(_, t)
				if t > 0.78 then return false end
				local on = math.min(smooth((t - 0.22) / 0.04), 1 - smooth((t - 0.67) / 0.05))
				local flat = smooth((t - 0.36) / 0.05)                         -- (0 = the tall launch shape, 1 = the flat apex)
				fl.Size = Vector3.new(3.44, 2.58, 3.80) * Vector3.new(0.62 + 0.38 * flat, 1.6 - 0.6 * flat, 0.62 + 0.38 * flat)
				local cf = (b and b:IsA("Bone")) and b.TransformedWorldCFrame or ctx.base
				fl.CFrame = cf * CFrame.new(0, 1.2 + 0.6 * (1 - flat), 0)
				fl.Transparency = 1 - on
				for _, d in parts do if d.Parent then d.LocalTransparencyModifier = math.max(was[d], on) end end
				return true
			end, stop = function() fl:Destroy(); for _, d in parts do if d.Parent then d.LocalTransparencyModifier = was[d] end end end }
		end },
		-- 0.80 BELLY-FLOP: the big crown (cell 3) + the shock ring to radius 5 by 0.98 (cell 4) + droplets thrown high
		{ t = 0.80, fn = function(ctx)
			local g = ctx.boingAt or ctx.base.Position
			ctx.sound(GSND.slap, g, 1.0, 0.8); ctx.sound(GSND.splash, g, 0.8, 1.05)
			local fx = {}
			local c = gooKeyed(ctx, "crown", 44, Vector3.new(7.8, 1.9, 7.8), CFrame.new(g) * CFrame.Angles(0, 0.7, 0), {
				{ 0.80, 0.35, 0.30, 0.35, 0.6 }, { 0.85, 0.85, 1.10, 0.85, 1 }, { 0.94, 1.0, 1.0, 1.0, 1 }, { 1.08, 1.10, 0.25, 1.10, 1 }, { 1.22, 1.12, 0.05, 1.12, 0 } }, 11)
			if c then table.insert(fx, c) end
			local r = gooKeyed(ctx, "ring", 45, Vector3.new(10, 0.28 * 2, 10), CFrame.new(g + Vector3.new(0, 0.03, 0)), {
				{ 0.80, 0.20, 1.0, 0.20, 1 }, { 0.98, 1.0, 0.75, 1.0, 1 }, { 1.15, 1.0, 0.35, 1.0, 0.45 }, { 1.50, 1.0, 0.2, 1.0, 0 } })
			if r then table.insert(fx, r) end
			for i = 1, 4 do
				local a = i * 1.57 + 0.4
				local dr = gooDrop(ctx, g + Vector3.new(cos(a) * 1.5, 0.8, sin(a) * 1.5), Vector3.new(cos(a) * 4, 10 + i * 1.5, sin(a) * 4), 0.42, 0.55, 0.81)
				if dr then table.insert(fx, dr) end
			end
			droplets(ctx, g + Vector3.new(0, 0.6, 0), 4, 7)
			return { step = function(_, t) local alive = false; for _, f in fx do if f:step(t) then alive = true end end; return alive end,
				stop = function() for _, f in fx do f:stop() end end }
		end },
		{ t = 1.80, fn = function(ctx) ctx.boingAt, ctx.boingVec = nil, nil end },
	},
}

-- ===================== HURT (0.52, additive; keys for a hit on its LEFT (-X) side, pushing it toward +X) =====================
-- (no dent bone on this rig yet: the dent reads as the lobes leaning away + squashing; ChatGPT wants DentL/R bones:
-- a rig change, logged for James)
A.TwinHurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,
	keys = twinKeys({
		{ 0.00, "smooth" },
		-- (audit r1: DentL, a new bone on its left side, pushes a real local dent in: 0.43 / 0.50 deep, a 0.08 overshoot out)
		{ 0.07, "out", R = { 0, 0.18 }, B = { -2, 0, -12, 0.12, -0.06 }, T = { -5, 0, -9, 0, -0.05 }, L = 29, tend = T3({ 0, -14 }, { 0, -10 }, { 0, -6 }), extra = { DentL = { 0, 0, 0, 0.43, 0, 0 } } },
		{ 0.14, "out", R = { 0, 0.25 }, B = { -2, 0, -16, 0.15, -0.10 }, T = { -4, 0, -12, 0, -0.08 }, L = 33, tend = T3({ 0, -18 }, { 0, -14 }, { 0, -8 }), extra = { DentL = { 0, 0, 0, 0.50, 0, 0 } } },
		{ 0.26, "out", R = { 0, -0.08 }, B = { 1, 0, 10, -0.05, 0.04 }, T = { 2, 0, 8 }, L = 13, tend = T3({ 0, 10 }, { 0, 8 }, { 0, 5 }), extra = { DentL = { 0, 0, 0, -0.08, 0, 0 } } },
		{ 0.37, "smooth", R = { 0, 0.04 }, B = { 0, 0, -6 }, T = { 0, 0, -4 }, L = 3, extra = { DentL = { 0, 0, 0, 0.03, 0, 0 } } },
		{ 0.52, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			ctx.sound(GSND.goo, ctx.hurtAt or ctx.base.Position, 0.55, 1.4)                                    -- (soft squelch)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local at = ctx.bonePos((out:Dot(ctx.base.RightVector) > 0) and "DentR" or "DentL")   -- (from the dent itself)
			local fx = {}
			for i = 1, 3 do
				local dr = gooDrop(ctx, at, out * (3 + i) + Vector3.new(0, 4 + i, (i - 2) * 1.5), 0.22, 0.35, 0.07)
				if dr then table.insert(fx, dr) end
			end
			return { step = function(_, t) local alive = false; for _, f in fx do if f:step(t) then alive = true end end; return alive end,
				stop = function() for _, f in fx do f:stop() end end }
		end },
		{ t = 0.20, fn = function(ctx) ctx.sound(GSND.wobble, ctx.hurtAt or ctx.base.Position, 0.4, 1.4) end },      -- (rubber recoil)
	},
}

-- ===================== DEFEAT (3.80, terminal): dazed wobble, slump into its puddle, a melt mound, a flat puddle, 2 motes ==========
A.TwinDefeat = {
	boneKeys = true, dur = 3.8,
	keys = twinKeys({
		{ 0.00, "smooth" },
		{ 0.45, "out", B = { 0, 0, 8, 0, -0.12 }, T = { 0, 0, -5 }, L = 25, tend = T3({ 0, 15 }, { 0, 15 }, { 0, 12 }) },
		{ 0.85, "smooth", B = { 0, 0, -12, 0, -0.27 }, T = { 15, 0, 0 }, L = 38, tend = T3({ 0, 35 }, { 0, 30 }, { 0, 25 }) },
		{ 1.30, "in", B = { 0, 0, 0, 0, -0.48 }, T = { 0, 0, 8, 0, -0.58 }, L = 52, tend = T3({ 6, 55 }, { 8, 45 }, { 6, 35 }) },
		{ 1.75, "in", B = { 0, 0, 0, 0, -0.67 }, T = { 18, 0, 0, 0, -0.93 }, L = 60, tend = T3({ 10, 70 }, { 12, 55 }, { 10, 45 }) },
		{ 2.10, "out", B = { 0, 0, 0, 0, -0.77 }, T = { 18, 0, 0, 0, -1.20 }, L = 60, tend = T3({ 10, 75 }, { 12, 60 }, { 10, 50 }) },
		{ 3.80, "smooth", B = { 0, 0, 0, 0, -0.77 }, T = { 18, 0, 0, 0, -1.20 }, L = 60, tend = T3({ 10, 75 }, { 12, 60 }, { 10, 50 }) },
	}),
	extra = function(t, p) p.glowMul = 1 - smooth((t - 2.0) / 0.9) end,
	events = {
		{ t = 0, fn = function(ctx)
			-- (a new MOVE TEST repeat: show the body again; each part's own value is kept for a cancelled defeat)
			ctx.defeatWas = {}
			local replay = ctx.m:GetAttribute("MoveTest")
			for _, d in ctx.m:GetDescendants() do
				if d:IsA("BasePart") and d.Name ~= "Hitbox" then
					if replay then d.LocalTransparencyModifier = 0 end          -- (MOVE TEST repeats: show it again)
					ctx.defeatWas[d] = d.LocalTransparencyModifier
				end
			end
		end },
		{ t = 0.45, fn = function(ctx) ctx.sound(GSND.gurgle, ctx.base.Position, 0.65, 0.85) end },          -- (descending jelly gurgle)
		{ t = 1.30, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.4, 0.7) end },
		-- the melt: the defeat puddle spreads (1.95-2.75), a soft mound covers the sinking body (2.05-3.45), the body fades
		-- out 2.5-3.05 and stays hidden (terminal); a cancelled defeat gives each part its own earlier value back
		{ t = 1.95, fn = function(ctx)
			local o = ctx.base.Position
			local g = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			local fx = {}
			local pd = gooKeyed(ctx, "puddle", 51, Vector3.new(4.4, 0.16, 4.1), CFrame.new(g + Vector3.new(0, 0.02, 0)), {
				{ 1.95, 0.65, 1, 0.65, 1 }, { 2.75, 1, 1, 1, 1 }, { 3.20, 1, 1, 1, 1 }, { 3.80, 1.05, 0.5, 1.05, 0 } })
			if pd then table.insert(fx, pd) end
			local md = gooKeyed(ctx, "lump", 52, Vector3.new(3.4, 1.15, 3.1), CFrame.new(g), {
				{ 2.05, 0.5, 0.3, 0.5, 0 }, { 2.50, 1, 1, 1, 1 }, { 3.05, 1.05, 0.35, 1.05, 1 }, { 3.45, 1.1, 0.1, 1.1, 0 } })
			if md then table.insert(fx, md) end
			local hidden, was, done = {}, ctx.defeatWas or {}, false
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); if was[d] == nil then was[d] = d.LocalTransparencyModifier end end end
			return { step = function(_, t)
				if t >= 3.05 then done = true end                           -- (fully faded: terminal, never restored)
				if t > 3.8 then return false end
				local gone = smooth((t - 2.5) / 0.55)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = gone end end
				for _, f in fx do f:step(t) end
				return true
			end, stop = function()
				for _, f in fx do f:stop() end
				if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end
			end }
		end },
		-- exactly TWO matter motes (it is 2 matter): bright cores with a halo, 0.75 apart, rise 1.2 then arc toward home
		{ t = 3.05, fn = function(ctx)
			ctx.sound(SND.glass, ctx.base.Position, 0.35, 1.7, 0.65)
			local o = ctx.base.Position
			local home = ctx.home or (o - ctx.base.LookVector * 100)
			local toHome = Vector3.new(home.X - o.X, 0, home.Z - o.Z)
			local lk = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z)
			toHome = (toHome.Magnitude > 0.05) and toHome.Unit or ((lk.Magnitude > 0.05) and -lk.Unit or Vector3.xAxis)
			local side = Vector3.new(-toHome.Z, 0, toHome.X)
			local motes = {}
			for i = 1, 2 do
				local s = (i == 1) and -1 or 1
				local start = o + side * 0.375 * s
				start = Vector3.new(start.X, ctx.ground(start.X, start.Z) + 0.3, start.Z)
				local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = G_CYAN, Transparency = 1, Size = Vector3.one * 0.28, CFrame = CFrame.new(start) })
				local halo = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = G_MINT, Transparency = 1, Size = Vector3.one * 0.6, CFrame = CFrame.new(start) })
				motes[i] = { core = core, halo = halo, start = start, s = s }
			end
			return { step = function(_, t)
				if t > 3.8 then return false end
				local e = t - 3.05
				for _, k in motes do
					local p
					if e < 0.15 then p = k.start + Vector3.new(0, 1.2 * smooth(e / 0.15), 0)
					else
						local u = clamp01((e - 0.15) / 0.45)
						p = k.start + Vector3.new(0, 1.2 + sin(u * pi) * 0.8, 0) + toHome * 30 * u * u + side * k.s * sin(u * pi)
					end
					k.core.CFrame, k.halo.CFrame = CFrame.new(p), CFrame.new(p)
					local f = smooth((e - 0.5) / 0.1)
					k.core.Transparency = math.max(1 - clamp01(e / 0.08), f) * 0.95
					k.halo.Transparency = 0.7 + 0.3 * math.max(1 - clamp01(e / 0.08), f)
				end
				return true
			end, stop = function() for _, k in motes do k.core:Destroy(); k.halo:Destroy() end end }
		end },
	},
}

A.FOR = A.FOR or {}
A.FOR.SquishF2v5 = { Slap = A.TSlap2, Sticky = A.Sticky, Boing = A.Boing, Defeat = A.TwinDefeat, Hurt = A.TwinHurt }
end

-- ============================================================================================================
-- ===================== BATCH 3b: the SQUISH BRUTE (spec design/15-BRUTE-BATCH3-SPEC-chatgpt-raw.md) ================
-- Built to match its reference sheets (design/concepts/brute/attacks/: J1 KNUCKLE POUND, J2 STRETCH GRAB, J3 CHEST
-- THUMP, J4 HURT + DEFEAT, K EFFECTS). A goo gorilla on 4 planted limbs (the arms are its front legs: Leg/Shin/Foot FL FR
-- = shoulder / forearm / fist). Its fists leave the ground through TARGET mode (atk.limbs): the 4-leg IK bends each arm
-- to a point; the STRETCH GRAB's arm goes past its reach by sliding the forearm + fist bones (atk.reach).
-- ============================================================================================================
do
local TAU = 2 * pi
local GooMesh = require(script.Parent:WaitForChild("GooMesh"))
local function gm(ctx, kind, seed, size, cf, extra) return GooMesh.make(kind, seed, size, cf, ctx.holder, extra) end
-- (shared with the Twin's block: a keyed goo mesh sat on its ground point, a flung mesh droplet)
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
local function group(list) return { step = function(_, t) local alive = false; for _, f in list do if f:step(t) then alive = true end end; return alive end,
	stop = function() for _, f in list do f:stop() end end } end

-- key rows: { t, ease, R = { lift, side, fwd, pitch, roll, yaw }, Hips / Chest / Head = { rx, ry, rz, ox, oy, oz }, L = lid }
local function bruteKeys(rows)
	local keys = {}
	for i, r in rows do
		local L = r.L or 0
		local b = { Hips = r.Hips or { 0, 0, 0 }, Chest = r.Chest or { 0, 0, 0 }, Head = r.Head or { 0, 0, 0 }, Lid = { (L >= 0) and (LID_FULL * L / 60) or (-L * 0.5) } }
		for k, v in r.extra or {} do b[k] = v end
		local R = r.R or {}
		keys[i] = { t = r[1], ease = r[2], root = { R[1] or 0, R[2] or 0, R[3] or 0, R[4] or 0, R[5] or 0, R[6] or 0 }, bones = b }
	end
	return keys
end
-- a limb's target track: rows { t, w, x, y, z } (model space; y above the ground under the point) -> world point + weight
local function limbTrack(rows)
	return function(tt, ctx)
		if tt <= rows[1][1] then return nil end
		local a, b = rows[#rows], rows[#rows]
		for i = 1, #rows - 1 do if tt >= rows[i][1] and tt <= rows[i + 1][1] then a, b = rows[i], rows[i + 1]; break end end
		local u = smooth((tt - a[1]) / math.max(1e-3, b[1] - a[1]))
		local w = a[2] + (b[2] - a[2]) * u
		if w <= 0 then return nil end
		local lp = Vector3.new(a[3] + (b[3] - a[3]) * u, 0, a[5] + (b[5] - a[5]) * u)
		local y = a[4] + (b[4] - a[4]) * u
		local p = ctx.base * lp
		return { p = Vector3.new(p.X, ctx.ground(p.X, p.Z) + y, p.Z), w = w }
	end
end
local function limbs(tracks)
	return function(tt, ctx)
		local out = {}
		for side, fn in tracks do local r = fn(tt, ctx); if r then out[side] = r end end
		return out
	end
end

-- ===================== A. KNUCKLE POUND (passive, every 1.25 s; hit 0.60) =====================
-- it rears up off its knuckles, both fists high over its head, drives them down together as one hammer onto the ground
-- 2.25 in front; the arms squash on impact, stay planted while the body rocks back; free 1.02
local POUND_HIT = { L = Vector3.new(-1.05, 0, -2.25), R = Vector3.new(1.05, 0, -2.25) }
A.Pound = {
	boneKeys = true, dur = 1.25, cycle = 1.25, lock = 1.02,
	keys = bruteKeys({
		{ 0.00, "smooth" },
		{ 0.18, "out", R = { 0, 0, -0.08, 3 }, Hips = { 8, 0, 0, 0, -0.08 }, Chest = { 15, 0, 0, 0, 0.12 }, Head = { -7, 0, 0 } },
		{ 0.42, "out", R = { 0.05, 0, -0.12, 4 }, Hips = { 11, 0, 0, 0, -0.10 }, Chest = { 23, 0, 0, 0, 0.22 }, Head = { -12, 0, 0 } },
		-- (measured: the spec's root -12 + hips -11 + chest -27 compose to ~50 deg and crumpled it face-down onto its fists;
		-- about half, and the head lifts to keep looking at its target)
		{ 0.54, "in", R = { 0, 0, 0.28, -4 }, Hips = { -3, 0, 0, 0, -0.12 }, Chest = { -8, 0, 0, 0, -0.12 }, Head = { 12, 0, 0 }, L = 8 },
		{ 0.60, "in", R = { -0.08, 0, 0.45, -6 }, Hips = { -5, 0, 0, 0, -0.22 }, Chest = { -12, 0, 0, 0, -0.26 }, Head = { 16, 0, 0 }, L = 16 },
		{ 0.78, "out", R = { -0.04, 0, 0.32, -4 }, Hips = { -3, 0, 0, 0, -0.14 }, Chest = { -9, 0, 0, 0, -0.15 }, Head = { 10, 0, 0 }, L = 8 },
		{ 1.02, "smooth", R = { 0, 0, 0.10, -2 }, Hips = { -2, 0, 0, 0, -0.04 }, Chest = { -5, 0, 0, 0, -0.04 }, Head = { 2, 0, 0 } },
		{ 1.25, "smooth" },
	}),
	limbs = limbs({
		FL = limbTrack({ { 0.10, 0, -1.35, 5.95, 0.10 }, { 0.30, 1, -1.35, 5.95, 0.10 }, { 0.54, 1, -1.35, 5.95, 0.10 }, { 0.60, 1, -1.05, 0.14, -2.25 }, { 0.82, 1, -1.05, 0.14, -2.25 }, { 1.10, 0, -1.05, 0.14, -2.25 } }),
		FR = limbTrack({ { 0.10, 0, 1.35, 5.95, 0.10 }, { 0.30, 1, 1.35, 5.95, 0.10 }, { 0.54, 1, 1.35, 5.95, 0.10 }, { 0.60, 1, 1.05, 0.14, -2.25 }, { 0.82, 1, 1.05, 0.14, -2.25 }, { 1.10, 0, 1.05, 0.14, -2.25 } }),
	}),
	events = {
		{ t = 0.18, fn = function(ctx) ctx.sound(GSND.wiggle, ctx.base.Position, 0.4, 1.1) end },            -- (heavy goo stretch)
		{ t = 0.54, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.4, 1.7, 0.7) end },
		{ t = 0.60, fn = function(ctx)
			local p = ctx.base * Vector3.new(0, 0, -3.6)                                      -- (r2: out in front of the fists; at -2.85 the fists hid it)
			local g = Vector3.new(p.X, ctx.ground(p.X, p.Z), p.Z)
			ctx.sound(GSND.slap, g, 1.0, 0.95); ctx.sound(GSND.thump, g, 0.6, 0.9)
			local fx = {}
			-- one fused splash crown over both fists (cell 1), a flat goo ring spreading out, three droplets
			local c = gooKeyed(ctx, "crown", 61, Vector3.new(6.0, 2.6, 4.5), CFrame.new(g) * CFrame.Angles(0, 0.3, 0), {
				{ 0.60, 0.45, 0.3, 0.45, 0.8 }, { 0.64, 1.0, 1.0, 1.0, 1 }, { 0.78, 1.1, 0.6, 1.1, 1 }, { 1.12, 1.15, 0.06, 1.15, 0 } }, 11)
			if c then table.insert(fx, c) end
			local ap = ctx.base * Vector3.new(0, 0, -2.9)                                     -- (the apron, <= 0.35 high)
			local apron = gooKeyed(ctx, "puddle", 63, Vector3.new(3.2, 0.35, 2.2), CFrame.new(ap.X, ctx.ground(ap.X, ap.Z), ap.Z) * ctx.base.Rotation, {
				{ 0.60, 0.5, 0.6, 0.5, 1 }, { 0.66, 1, 1, 1, 1 }, { 0.90, 1.05, 0.6, 1.05, 1 }, { 1.12, 1.08, 0.3, 1.08, 0 } })
			if apron then table.insert(fx, apron) end
			local rp = ctx.base * Vector3.new(0, 0, -2.45)
			local r = gooKeyed(ctx, "ring", 62, Vector3.new(6.5, 0.12, 5.5), CFrame.new(rp.X, ctx.ground(rp.X, rp.Z) + 0.02, rp.Z), {
				{ 0.60, 0.3, 1, 0.3, 1 }, { 0.80, 1.0, 0.7, 1.0, 0.9 }, { 1.05, 1.08, 0.3, 1.08, 0 } })
			if r then table.insert(fx, r) end
			for i = 1, 3 do
				local a = i * 2.1 + 0.5
				local dr = gooDrop(ctx, g + Vector3.new(cos(a), 0.6, sin(a)), Vector3.new(cos(a) * 4, 8 + i, sin(a) * 4), 0.34, 0.45, 0.61)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
	},
}

-- ===================== B. STRETCH GRAB (auto; warn 0.5, catch 0.76, slam 1.30, free 1.65, FX end 1.98) =====================
-- the left fist stays planted; the right arm winds back, then shoots out as a long thin goo rope to the target (up to 14),
-- the sticky hand catches it (0.76), the rope snaps back thick, and the fist slams it down in front, pinned under goo
-- (fist-touch heights: the spec's wind-up and carry points were fist-bone heights, 1.45 higher)
local GRAB_WIND, GRAB_BACK, GRAB_SLAM = Vector3.new(3.35, 1.70, 0.45), Vector3.new(1.25, 0.75, -1.30), Vector3.new(0.85, 0.13, -2.20)
local function grabCatch(ctx)                                    -- (the catch point: the aim frozen at the cast, 1.2 up, <= 14 away)
	if ctx.grabAt then return ctx.grabAt end
	local a = ctx.aim or ahead(ctx, 12, 0)
	local o = ctx.base.Position
	local v = Vector3.new(a.X - o.X, 0, a.Z - o.Z)
	if v.Magnitude < 0.05 then v = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z) * 12 end
	if v.Magnitude > 14 then v = v.Unit * 14 end
	local p = o + v
	return Vector3.new(p.X, ctx.ground(p.X, p.Z) + 1.2, p.Z)
end
A.Grab = {
	boneKeys = true, dur = 2.0, lock = 1.65, aims = true, testAims = "TEST_AIMS_SHORT",
	keys = bruteKeys({
		{ 0.00, "smooth" },
		{ 0.25, "smooth", R = { 0, 0, -0.12, 2, -3 }, Hips = { 3, 0, 0 }, Chest = { 7, 12, -6 }, Head = { -4, -8, 0 } },
		{ 0.50, "smooth", R = { 0, 0, -0.08, -3, 2 }, Hips = { -2, 0, 0 }, Chest = { -8, 15, 5 }, Head = { 4, -10, 0 }, L = 5 },
		{ 0.76, "in", R = { 0, 0, 0.22, -8, 3 }, Hips = { -5, 0, 0 }, Chest = { -14, 10, 5 }, Head = { 7, -6, 0 }, L = 8 },
		{ 1.00, "out", R = { 0, 0, 0.08, 5, -5 }, Hips = { 6, 0, 0 }, Chest = { 14, -12, -8 }, Head = { -8, 6, 0 } },
		{ 1.12, "out", R = { 0, 0, 0.12, 3, -2 }, Hips = { 3, 0, 0 }, Chest = { 7, -5, -4 }, Head = { -3, 3, 0 } },
		{ 1.30, "out", R = { 0, 0, 0.35, -10, 4 }, Hips = { -9, 0, 0 }, Chest = { -24, 4, 7 }, Head = { 10, -2, 0 }, L = 16 },
		{ 1.55, "smooth", R = { 0, 0, 0.20, -5, 2 }, Hips = { -4, 0, 0 }, Chest = { -13, 2, 3 }, Head = { 6, 0, 0 }, L = 5 },
		{ 1.80, "smooth", R = { 0, 0, 0.03, -1, 0 }, Hips = { -1, 0, 0 }, Chest = { -3, 0, 0 }, Head = { 1, 0, 0 } },
		{ 2.00, "smooth" },
	}),
	-- the right fist: wind-up, then (0.50-1.12) TUCKED to the shoulder while the rope does the reaching, out of the
	-- shoulder to the carry point, slam, hold, planted again by 1.80
	limbs = function(tt, ctx)
		local function at(lp) local p = ctx.base * Vector3.new(lp.X, 0, lp.Z); return Vector3.new(p.X, ctx.ground(p.X, p.Z) + lp.Y, p.Z) end
		local p, w
		if tt < 0.25 then return {}
		elseif tt < 0.50 then p, w = at(GRAB_WIND), smooth((tt - 0.25) / 0.2)
		elseif tt < 1.12 then p, w = at(GRAB_WIND), 1
		elseif tt < 1.30 then p, w = at(GRAB_WIND):Lerp(at(GRAB_SLAM), EASE["in"](clamp01((tt - 1.12) / 0.18))), 1
		elseif tt < 1.65 then p, w = at(GRAB_SLAM), 1
		elseif tt < 1.80 then p, w = at(GRAB_SLAM), 1 - smooth((tt - 1.65) / 0.15)
		else return {} end
		return { FR = { p = p, w = w } }
	end,
	-- (audit r1: bones can't thin the skinned arm, so while the ROPE is out the thick forearm + fist fold INTO the shoulder
	-- (the bones slide to it, the skin collapses with them): the rope + open palm replace the arm 0.50-1.12)
	reach = {
		{ chain = { "ShinFR", "FootFR" }, t0 = 0.46, t1 = 0.52, t2 = 1.06, t3 = 1.14, max = 4, target = function(ctx) return ctx.bonePos("LegFR") end },
	},
	events = {
		-- the warning: a narrow goo lane from the Brute to the target (0.9 wide, <= 14 long), until the launch (0.50)
		{ t = 0, fn = function(ctx)
			ctx.grabAt = nil
			ctx.grabAt = grabCatch(ctx)                                   -- (frozen: the lane, the rope and the catch agree)
			local o = ctx.base.Position
			local c = ctx.grabAt
			local v = Vector3.new(c.X - o.X, 0, c.Z - o.Z)
			if v.Magnitude < 0.05 then v = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z) end
			return gooLane(ctx, Vector3.new(o.X, 0, o.Z), v.Unit, 0, v.Magnitude, 0.45, 0, 0.50)
		end },
		{ t = 0.25, fn = function(ctx) ctx.sound(GSND.wiggle, ctx.base.Position, 0.5, 0.9) end },          -- (rubber stretch)
		{ t = 0.50, fn = function(ctx) ctx.sound(SND.whoosh, ctx.base.Position, 0.5, 1.6, 0.7) end },
		-- 0.50-1.12 THE ROPE (cell 2): a glossy tapered tube from the shoulder (0.9 wide) to the open sticky palm
		-- (1.6 x 1.4 x 1.0): out 0.50-0.76 (ease-out), caught 0.76-0.83, then it snaps back on an S-curve with two trailing
		-- strands 0.76-1.12, carrying the goo-wrapped catch (MOVE TEST stand-in) to the shoulder
		{ t = 0.50, fn = function(ctx)
			local rope = gm(ctx, "rope", 1, Vector3.new(0.9, 1, 0.9), CFrame.new())
			local ropeS = gm(ctx, "ropeS", 1, Vector3.new(1.2, 1, 0.5), CFrame.new())
			local palm = gm(ctx, "palm", 1, Vector3.new(1.6, 1.4, 1.0), CFrame.new())
			local blob = gm(ctx, "lump", 71, Vector3.new(1.3, 1.0, 1.3), CFrame.new())
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = C3(70, 64, 92), Size = Vector3.one * 0.8, Transparency = 1 })
			local strands = {}
			for i = 1, 2 do strands[i] = gm(ctx, "rope", 1, Vector3.new(0.12, 1, 0.12), CFrame.new()) end
			local all = { rope, ropeS, palm, blob, strands[1], strands[2] }
			for _, p in all do if p then p.Transparency = 1 end end
			local function along(m, a, b, width)                            -- (lay a +Y mesh from a to b)
				if not m then return end
				local d = b - a
				if d.Magnitude < 0.05 then m.Transparency = 1; return end
				m.Size = Vector3.new(width, d.Magnitude, width)
				m.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + d) * CFrame.Angles(-pi / 2, 0, 0)
				m.Transparency = 0
			end
			return { step = function(_, t)
				if t > 1.14 then return false end
				local sh = ctx.bonePos("LegFR")
				local c = grabCatch(ctx)
				local hand
				if t < 0.76 then hand = sh:Lerp(c, EASE.out(clamp01((t - 0.50) / 0.26)))
				elseif t < 0.83 then hand = c
				else hand = c:Lerp(sh, smooth((t - 0.83) / 0.27)) end
				local dir = (hand - sh)
				local caught = t >= 0.76
				if t < 0.83 then
					along(rope, sh, hand, 0.9)
					if ropeS then ropeS.Transparency = 1 end
				else                                                       -- (the recoil: an S-curved rope, two strands trailing)
					if rope then rope.Transparency = 1 end
					if ropeS and dir.Magnitude > 0.3 then
						ropeS.Size = Vector3.new(math.min(1.6, dir.Magnitude * 0.25), dir.Magnitude, 0.45)
						ropeS.CFrame = CFrame.lookAt((sh + hand) / 2, (sh + hand) / 2 + dir) * CFrame.Angles(-pi / 2, 0, 0)
						ropeS.Transparency = 0
					elseif ropeS then ropeS.Transparency = 1 end
					local mag = dir.Magnitude
					local unit = (mag > 0.05) and (dir / mag) or ctx.base.LookVector
					for i, st in strands do
						local off = ctx.base.RightVector * ((i == 1) and 0.35 or -0.35) + Vector3.new(0, -0.2 * i, 0)
						if mag > 0.05 then along(st, hand + off * 0.3, hand + off - unit * math.min(2.5, mag * 0.4), 0.12)
						elseif st then st.Transparency = 1 end
					end
				end
				if palm then                                               -- (the open palm faces the target; it closes round the catch)
					local look = (dir.Magnitude > 0.05) and dir.Unit or ctx.base.LookVector
					palm.CFrame = CFrame.lookAt(hand, hand + look)
					palm.Size = caught and Vector3.new(1.2, 1.1, 1.0) or Vector3.new(1.6, 1.4, 1.0)
					palm.Transparency = (dir.Magnitude > 0.4) and 0 or 1
				end
				if caught then
					if blob then blob.CFrame = CFrame.new(hand + Vector3.new(0, -0.1, 0)) * CFrame.Angles(0, t * 3, 0); blob.Transparency = 0.25 end
					core.CFrame = CFrame.new(hand); core.Transparency = 0
				end
				return true
			end, stop = function() for _, p in all do if p then p:Destroy() end end; core:Destroy() end }
		end },
		{ t = 0.76, fn = function(ctx) ctx.sound(GSND.goo, grabCatch(ctx), 0.8, 1.0) end },                -- (the sticky catch)
		{ t = 1.00, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.5, 1.1) end },          -- (the rope snaps back)
		-- 1.12-1.30 the fist comes back out of the shoulder carrying the catch down to the slam point
		{ t = 1.12, fn = function(ctx)
			local blob = gm(ctx, "lump", 71, Vector3.new(1.3, 1.0, 1.3), CFrame.new())
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = C3(70, 64, 92), Size = Vector3.one * 0.8 })
			return { step = function(_, t)
				if t > 1.30 then return false end
				local f = ctx.bonePos("FootFR") + Vector3.new(0, -0.6, 0)
				if blob then blob.CFrame = CFrame.new(f) * CFrame.Angles(0, t * 3, 0); blob.Transparency = 0.25 end
				core.CFrame = CFrame.new(f)
				return true
			end, stop = function() if blob then blob:Destroy() end; core:Destroy() end }
		end },
		-- 1.30 the slam: crown + droplets, and the GOO PIN (cell 3: a lumpy blob with six strands to the ground) made HERE,
		-- anchored at the actual contact, holding the catch to 1.80, gone 1.98
		{ t = 1.30, fn = function(ctx)
			local s = ctx.base * Vector3.new(0.85, 0, -2.2)
			local g = Vector3.new(s.X, ctx.ground(s.X, s.Z), s.Z)
			ctx.sound(GSND.slap, g, 1.0, 0.9); ctx.sound(GSND.thump, g, 0.5, 1.0)
			local fx = {}
			local c = gooKeyed(ctx, "crown", 73, Vector3.new(3.0, 1.4, 2.8), CFrame.new(g), {
				{ 1.30, 0.4, 0.3, 0.4, 0.8 }, { 1.34, 1.0, 1.0, 1.0, 1 }, { 1.48, 1.1, 0.5, 1.1, 1 }, { 1.75, 1.15, 0.06, 1.15, 0 } }, 7)
			if c then table.insert(fx, c) end
			local pin = gooKeyed(ctx, "pin", 72, Vector3.new(2.6, 1.3, 2.4), CFrame.new(g), {
				{ 1.30, 0.4, 0.3, 0.4, 0.8 }, { 1.36, 1.0, 1.0, 1.0, 1 }, { 1.80, 1.0, 0.9, 1.0, 1 }, { 1.98, 1.1, 0.2, 1.1, 0 } })
			if pin then table.insert(fx, pin) end
			local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = C3(70, 64, 92), Size = Vector3.one * 0.8, CFrame = CFrame.new(g + Vector3.new(0, 0.45, 0)) })
			table.insert(fx, { step = function(_, t) core.Transparency = (t > 1.85) and 1 or 0; return t < 1.98 end, stop = function() core:Destroy() end })
			for i = 1, 3 do
				local a = i * 2.1
				local dr = gooDrop(ctx, g + Vector3.new(0, 0.6, 0), Vector3.new(cos(a) * 3.5, 7 + i, sin(a) * 3.5), 0.3, 0.45, 1.31)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
	},
}

-- (audit r2) the GOO SHIELD MANAGER: one jelly shell per unit model, owned here (not by the casting Brute's effects).
-- A cast sets expiry = max(old, new). Each shell grows in 0.28 s (6 % overshoot, a jelly wobble), follows its unit,
-- fades over the last 0.18 s of its expiry, and goes when its unit does. The Brute's own shell has 5 drips.
local SHIELDS = {}
local shieldLoop
-- (AI TEST, 29 Oct, attack-commit build audit r1) the server's shield can END EARLY (used up). The shells of one cast are
-- keyed "casterAiId:attackId" (ctx.atkId, set by the AI animator; nil in the MOVE TEST = unkeyed, as before). A.endShield
-- ends a unit's shell only if that cast still owns it (a newer cast took it over = left alone), and tombstones the
-- pair so a shell that cast hasn't drawn yet never appears
local SHIELD_ENDED = {}
local function gooShieldOn(ctx, m, expiry, big)
	local key = ctx.atkId and (tostring(ctx.m:GetAttribute("AiId")) .. ":" .. tostring(ctx.atkId)) or nil
	if key and SHIELD_ENDED[key] and SHIELD_ENDED[key][m] then return end
	local e = SHIELDS[m]
	if e and e.part.Parent then
		if key and expiry >= e.expiry then e.src = key end   -- (the cast whose expiry wins owns the shell)
		e.expiry = math.max(e.expiry, expiry)
		if big and not e.big then                                -- (audit r3: its own Thump promotes an ally shell)
			e.big, e.from, e.promoted = true, { e.w, e.h, e.d }, workspace:GetServerTimeNow()
			e.w, e.h, e.d = 9.5, 8, 9
			local folder = e.part.Parent
			for i = #e.drips + 1, 5 do e.drips[i] = GooMesh.make("drop", 0, Vector3.new(0.35, 0.5, 0.35), CFrame.new(), folder) end
		end
		return
	end
	local _, bb = m:GetBoundingBox()
	local w, h, d = big and 9.5 or bb.X + 0.7, big and 8 or bb.Y + 0.7, big and 9 or bb.Z + 0.7
	local folder = workspace:FindFirstChild("GooShields") or Instance.new("Folder", workspace)
	folder.Name = "GooShields"
	local s = GooMesh.make("shield", 1, Vector3.new(w, h, d), CFrame.new(), folder)
	if not s then return end
	s.Transparency = 1
	local drips = {}
	for i = 1, (big and 5 or 3) do drips[i] = GooMesh.make("drop", 0, Vector3.new(0.35, 0.5, 0.35), CFrame.new(), folder) end
	SHIELDS[m] = { part = s, drips = drips, born = workspace:GetServerTimeNow(), expiry = expiry, w = w, h = h, d = d, big = big, ground = ctx.ground, src = key }
	if shieldLoop then return end
	shieldLoop = game:GetService("RunService").Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for model, e in SHIELDS do
			local gone = not model.Parent or now > e.expiry
			if gone then
				e.part:Destroy(); for _, dr in e.drips do if dr then dr:Destroy() end end
				SHIELDS[model] = nil
				continue
			end
			local t = now - e.born
			local grow = (t < 0.28) and smooth(t / 0.28) * 1.06 or (1.06 - 0.06 * smooth((t - 0.28) / 0.25))
			local wob = 1 + 0.025 * sin(now * 7) + ((t < 0.8) and 0.05 * sin(t * 25) * (1 - smooth(t / 0.8)) or 0)
			local w, h, d = e.w, e.h, e.d
			if e.promoted then                                      -- (the 0.15 s grow from the ally size to the full size)
				local k = smooth((now - e.promoted) / 0.15)
				w, h, d = e.from[1] + (w - e.from[1]) * k, e.from[2] + (h - e.from[2]) * k, e.from[3] + (d - e.from[3]) * k
			end
			local sz = Vector3.new(w * grow * wob, h * grow / wob, d * grow * wob)
			local o = model:GetPivot()
			local g = e.ground(o.X, o.Z)
			e.part.Size = sz
			e.part.CFrame = CFrame.new(o.X, g + sz.Y / 2, o.Z) * o.Rotation
			local fade = smooth((now - (e.expiry - 0.18)) / 0.18)
			e.part.Transparency = 0.55 + 0.45 * fade + ((t < 0.06) and 0.45 * (1 - smooth(t / 0.06)) or 0)
			for i, dr in e.drips do
				if dr then
					local a = i / #e.drips * 2 * pi + 0.5
					local p = o * Vector3.new(cos(a) * sz.X * 0.48, 0, sin(a) * sz.Z * 0.48)
					dr.CFrame = CFrame.new(p.X, g + 0.45 + 0.15 * sin(now * 2 + i), p.Z) * CFrame.Angles(pi, 0, 0)
					dr.Transparency = (t < 0.2) and 1 or (0.35 + 0.65 * fade)
				end
			end
		end
		if next(SHIELDS) == nil then shieldLoop:Disconnect(); shieldLoop = nil end
	end)
end
-- the server says unit m's shield from cast `key` is gone: fade that cast's shell out now (0.18 s), if it still owns it
function A.endShield(m, key)
	SHIELD_ENDED[key] = SHIELD_ENDED[key] or {}
	SHIELD_ENDED[key][m] = true
	local e = SHIELDS[m]
	if e and e.src == key then e.expiry = math.min(e.expiry, workspace:GetServerTimeNow() + 0.18) end
end

-- (cell 5) a ripple patch on the Brute's chest: a curved ring mesh facing out of its chest, riding the Chest bone for
-- 0.18 s, 2.7 x 2.5 x 0.18, spreading as it fades
local function bruteRipple(ctx, t0)
	local m = gm(ctx, "ripple", 1, Vector3.new(1.4, 0.18, 1.3), CFrame.new())
	if not m then return nil end
	m.Transparency = 1
	return { step = function(_, t)
		local e = (t - t0) / 0.18
		if e > 1 then return false end
		local c = ctx.bonePos("Chest")
		local f = ctx.base.LookVector
		local u = smooth(e)
		m.Size = Vector3.new(1.4 + 1.3 * u, 0.18, 1.3 + 1.2 * u)
		m.CFrame = CFrame.lookAt(c + f * 1.9 + Vector3.new(0, 0.5, 0), c + f * 4) * CFrame.Angles(-pi / 2, 0, 0)
		m.Transparency = 0.15 + 0.85 * u
		return true
	end, stop = function() m:Destroy() end }
end

-- ===================== C. CHEST THUMP (ORDER; wind-up 0.80, buff 0.80, free 1.40, shield to 6.80, FX end 6.98) =====================
-- it rises onto its hind legs, the chest swells, right fist thumps (0.73), left fist thumps (0.80: the buff); the violet
-- core flares, a thick jelly shield grows round it; it drops back to its knuckles, its fists charged (faster) to 4.80
A.Thump = {
	boneKeys = true, dur = 6.98, lock = 1.40,
	keys = bruteKeys({
		{ 0.00, "smooth" },
		{ 0.25, "out", R = { 0.05, 0, 0, 3 }, Hips = { 8, 0, 0, 0, -0.08 }, Chest = { 17, 0, 0, 0, 0.20 }, Head = { -8, 0, 0 } },
		{ 0.55, "out", R = { 0.08, 0, 0, 4 }, Hips = { 11, 0, 0, 0, -0.14 }, Chest = { 25, 0, 0, 0, 0.28 }, Head = { -13, 0, 0 } },
		{ 0.73, "in", R = { 0.04, 0, 0, 2 }, Hips = { 8, 0, 0, 0, -0.12 }, Chest = { 16, 0, 0, 0, 0.15 }, Head = { -7, 0, 0 }, L = 12 },
		{ 0.80, "in", R = { -0.04, 0, 0, -4 }, Hips = { 4, 0, 0, 0, -0.12 }, Chest = { 7, 0, 0, 0, 0.05 }, Head = { 2, 0, 0 }, L = 24 },
		{ 0.95, "out", R = { 0.02, 0, 0, 2 }, Hips = { 7, 0, 0, 0, -0.10 }, Chest = { 13, 0, 0, 0, 0.12 }, Head = { -5, 0, 0 } },
		{ 1.20, "smooth", R = { 0, 0, 0, -3 }, Hips = { -3, 0, 0, 0, -0.05 }, Chest = { -8, 0, 0, 0, -0.04 }, Head = { 4, 0, 0 } },
		{ 1.40, "smooth" },
		{ 6.98, "smooth" },
	}),
	-- fists: drawn back beside the chest, right fist onto the chest at 0.73, left at 0.80, back down by 1.40
	limbs = limbs({
		FR = limbTrack({ { 0.12, 0, 2.4, 2.25, 0.5 }, { 0.40, 1, 2.4, 2.25, 0.5 }, { 0.55, 1, 2.3, 2.35, 0.3 }, { 0.73, 1, 0.6, 2.15, -1.5 }, { 0.80, 1, 1.9, 2.15, -0.6 }, { 1.00, 1, 2.2, 1.55, -0.8 }, { 1.40, 0, 2.6, 0.2, -1.4 } }),
		FL = limbTrack({ { 0.12, 0, -2.4, 2.25, 0.5 }, { 0.40, 1, -2.4, 2.25, 0.5 }, { 0.73, 1, -2.3, 2.35, 0.2 }, { 0.80, 1, -0.6, 2.15, -1.5 }, { 0.92, 1, -1.9, 2.15, -0.6 }, { 1.10, 1, -2.2, 1.55, -0.8 }, { 1.40, 0, -2.6, 0.2, -1.4 } }),
	}),
	-- (the violet core flares on the second thump; its whole goo glows brighter while the fists are charged, 1.40-4.80)
	extra = function(t, p)
		local flare = (t > 0.78 and t < 1.15) and (1 - smooth((t - 0.80) / 0.35)) or 0
		local pumped = (t > 1.2 and t < 4.8) and (0.35 * smooth((t - 1.2) / 0.3) * (1 - smooth((t - 4.6) / 0.2))) or 0
		p.glowMul = 1 + 0.9 * flare + pumped
	end,
	events = {
		{ t = 0.25, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.4, 0.8) end },          -- (chest swelling)
		-- the two thumps: a RIPPLE patch (cell 5) riding the curved chest surface for 0.18 s, a deep wet drum
		{ t = 0.73, fn = function(ctx)
			ctx.sound(GSND.slap, ctx.base.Position, 0.7, 0.7)
			return bruteRipple(ctx, 0.73)
		end },
		{ t = 0.80, fn = function(ctx)
			ctx.sound(GSND.slap, ctx.base.Position, 1.0, 0.62); ctx.sound(GSND.thump, ctx.base.Position, 0.6, 0.8)
			local fx = {}
			local rp = bruteRipple(ctx, 0.80)
			if rp then table.insert(fx, rp) end
			-- the GOO SHIELD (cell 4) on the Brute and on every unit within 8 (audit r2: a SHIELD MANAGER keyed by model owns
			-- the shells: one per unit; a second Thump only pushes its expiry out (max of both); shells live on their own,
			-- outside the caster's effects, and fade over the last 0.18 s of their real expiry)
			local now = workspace:GetServerTimeNow()
			gooShieldOn(ctx, ctx.m, now + 6.0, true)
			local units = ctx.m.Parent
			-- (AI TEST, 29 Oct: friends only, as the server shields; it shelled ENEMY units in reach too. Units with no Team
			-- attribute (the MOVE TEST) keep the old rule)
			local myTeam = ctx.m:GetAttribute("Team")
			for _, u in (units and units:GetChildren() or {}) do
				local theirs = u:GetAttribute("Team")
				local friend = myTeam == nil or theirs == nil or (myTeam == theirs and myTeam ~= "ALL")
				if u ~= ctx.m and u:IsA("Model") and friend and (u:GetPivot().Position - ctx.base.Position).Magnitude <= 8 then
					gooShieldOn(ctx, u, now + 6.0, false)
				end
			end
			for i = 1, 3 do
				local a = i * 2.1 + 1
				local g = ctx.base.Position
				local dr = gooDrop(ctx, Vector3.new(g.X + cos(a) * 3.5, ctx.ground(g.X, g.Z) + 4, g.Z + sin(a) * 3.5), Vector3.new(cos(a) * 2, 4, sin(a) * 2), 0.3, 0.5, 1.0)
				if dr then table.insert(fx, dr) end
			end
			-- PUMPED FISTS (cell 6, audit r2): a goo overlay hugging each fist (the goo skin with its cracks, glowing much
			-- brighter, a little bigger than the fist) + two short glow streaks trailing it; full by 1.08, fading 4.80-5.00
			for _, b in { "FootFL", "FootFR" } do
				local gl = gm(ctx, "lump", 84, Vector3.new(2.2, 2.0, 2.1), CFrame.new())
				if gl then
					local streaks = { gm(ctx, "rope", 1, Vector3.new(0.18, 1.1, 0.18), CFrame.new()), gm(ctx, "rope", 1, Vector3.new(0.14, 1.4, 0.14), CFrame.new()) }
					local bone = ctx.m:FindFirstChild(b, true)
					local sa = gl:FindFirstChildOfClass("SurfaceAppearance")
					if sa then sa.EmissiveStrength = 6 end
					local last
					table.insert(fx, { step = function(_, t)
						if t > 5.0 then return false end
						local p = ctx.bonePos(b) + Vector3.new(0, -0.62, 0)
						local fade = math.max(1 - smooth((t - 0.80) / 0.28), smooth((t - 4.80) / 0.2))
						local rot = (bone and bone:IsA("Bone")) and bone.TransformedWorldCFrame.Rotation or ctx.base.Rotation
						gl.CFrame = CFrame.new(p) * rot                                       -- (turns with the fist)
						gl.Transparency = 0.30 + 0.70 * fade                                   -- (audit r3: 0.45 -> 0.30)
						local v = last and (p - last) or Vector3.zero
						last = p
						local back = (v.Magnitude > 0.01) and -v.Unit or ctx.base.LookVector * -1
						for i, st in streaks do
							if st then
								local off = ctx.base.RightVector * ((i == 1) and 0.35 or -0.3) + Vector3.new(0, (i == 1) and 0.3 or -0.2, 0)
								local a0, a1 = p + off, p + off + back * (0.8 + 0.3 * i)
								st.CFrame = CFrame.lookAt((a0 + a1) / 2, (a0 + a1) / 2 + (a1 - a0)) * CFrame.Angles(-pi / 2, 0, 0)
								st.Transparency = 0.5 + 0.5 * fade
							end
						end
						return true
					end, stop = function() gl:Destroy(); for _, st in streaks do if st then st:Destroy() end end end })
				end
			end
			return group(fx)
		end },
		{ t = 0.90, fn = function(ctx) ctx.sound(GSND.wobble, ctx.base.Position, 0.6, 0.75) end },          -- (the shield wobbling up)
		{ t = 6.80, fn = function(ctx) ctx.sound(GSND.bubbles, ctx.base.Position, 0.35, 1.2) end },         -- (the shield dissolving)
	},
}

-- ===================== HURT (0.52, additive; keys for a hit on its LEFT shoulder (-X), pushing it toward +X) =====================
-- the shoulder dents in (LegFL slides in + down), droplets burst out of it, the weight shifts onto the right fist, it
-- springs back with a snarl (the lid half-shuts)
A.BruteHurt = {
	boneKeys = true, dur = 0.52, additive = true, pushX = true,
	keys = bruteKeys({
		{ 0.00, "smooth" },
		{ 0.10, "out", R = { 0, 0.20, 0, 0, 5 }, Chest = { 0, 0, 9, 0.12 }, Head = { -5, 6, 0 }, L = 34, extra = { LegFL = { 0, 0, 0, 0.28, -0.15 } } },
		{ 0.22, "out", R = { 0, 0.28, 0, 0, 8 }, Chest = { 0, 0, 12, 0.18 }, Head = { -8, 9, 0 }, L = 42, extra = { LegFL = { 0, 0, 0, 0.34, -0.18 } } },
		{ 0.35, "smooth", R = { 0, -0.06, 0, 0, -3 }, Chest = { 0, 0, -5, -0.08 }, Head = { 4, -4, 0 }, L = 15, extra = { LegFL = { 0, 0, 0, -0.10, 0.05 } } },
		{ 0.52, "smooth" },
	}),
	events = {
		{ t = 0, fn = function(ctx)
			ctx.sound(GSND.slap, ctx.hurtAt or ctx.base.Position, 0.6, 1.2)
			local out = ctx.hurtOut or -ctx.base.RightVector
			local at = ctx.bonePos((out:Dot(ctx.base.RightVector) > 0) and "LegFR" or "LegFL")   -- (the shoulder on the hit side)
			local fx = {}
			for i = 1, 3 do
				local dr = gooDrop(ctx, at, out * (3 + i) + Vector3.new(0, 5 + i, (i - 2) * 1.5), 0.3, 0.4, 0.12)
				if dr then table.insert(fx, dr) end
			end
			return group(fx)
		end },
		{ t = 0.22, fn = function(ctx) ctx.sound(GSND.wobble, ctx.hurtAt or ctx.base.Position, 0.45, 1.0) end },
	},
}

-- ===================== DEFEAT (3.80, terminal): dazed sway, arms buckle, it falls forward, melts to a puddle, 4 motes ==========
A.BruteDefeat = {
	boneKeys = true, dur = 3.8,
	keys = bruteKeys({
		{ 0.00, "smooth" },
		{ 0.35, "out", R = { -0.05, 0, 0.05, 0, 6 }, Hips = { -4, 0, 0, 0, -0.12 }, Chest = { -8, 0, 0, 0, -0.18 }, Head = { 5, 0, 0, 0, -0.05 }, L = 30 },
		{ 0.70, "smooth", R = { -0.10, 0, 0.18, 0, -5 }, Hips = { -10, 0, 0, 0, -0.25 }, Chest = { -20, 0, 0, 0, -0.50 }, Head = { 12, 0, 0, 0, -0.22 }, L = 45 },
		{ 1.15, "in", R = { -0.15, 0, 0.32, 0, 3 }, Hips = { -18, 0, 0, 0, -0.48 }, Chest = { -32, 0, 0, 0, -0.95 }, Head = { 18, 0, 0, 0, -0.55 }, L = 60 },
		{ 1.65, "out", R = { -0.18, 0, 0.35, 0, 0 }, Hips = { -20, 0, 0, 0, -0.65 }, Chest = { -35, 0, 0, 0, -1.30 }, Head = { 20, 0, 0, 0, -0.75 }, L = 60 },
		{ 3.80, "smooth", R = { -0.18, 0, 0.35, 0, 0 }, Hips = { -20, 0, 0, 0, -0.65 }, Chest = { -35, 0, 0, 0, -1.30 }, Head = { 20, 0, 0, 0, -0.75 }, L = 60 },
	}),
	-- the arms give way: the fists slide out sideways as the chest comes down
	limbs = limbs({
		FL = limbTrack({ { 0.35, 0, -2.65, 0.1, -1.45 }, { 0.70, 1, -2.9, 0.1, -1.6 }, { 1.65, 1, -3.4, 0.1, -1.9 }, { 3.80, 1, -3.4, 0.1, -1.9 } }),
		FR = limbTrack({ { 0.35, 0, 2.65, 0.1, -1.45 }, { 0.55, 1, 2.8, 0.1, -1.5 }, { 1.65, 1, 3.4, 0.1, -1.9 }, { 3.80, 1, 3.4, 0.1, -1.9 } }),
	}),
	extra = function(t, p) p.glowMul = 1 - smooth((t - 1.6) / 1.2) end,
	events = {
		{ t = 0, fn = function(ctx)
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then d.LocalTransparencyModifier = 0 end end
			ctx.sound(GSND.gurgle, ctx.base.Position, 0.7, 0.75)
		end },
		{ t = 1.15, fn = function(ctx) ctx.sound(GSND.slap, ctx.base.Position, 0.8, 0.7); ctx.sound(GSND.thump, ctx.base.Position, 0.4, 0.8) end },  -- (it hits the ground)
		-- the melt (audit r1: from 1.30): a sprawling puddle spreads, the Brute's own MOUND (three drooping fin remnants)
		-- takes over from the body 1.30-1.85, then sinks nearly flat by 2.85; the body stays hidden (terminal)
		{ t = 1.30, fn = function(ctx)
			local o = ctx.base * Vector3.new(0, 0, -0.6)
			local g = Vector3.new(o.X, ctx.ground(o.X, o.Z), o.Z)
			local fx = {}
			local pd = gooKeyed(ctx, "puddle", 91, Vector3.new(8.5, 0.24, 7.5), CFrame.new(g + Vector3.new(0, 0.02, 0)), {
				{ 1.30, 0.5, 1, 0.5, 1 }, { 2.85, 1, 1, 1, 1 }, { 3.55, 1, 1, 1, 1 }, { 3.80, 1.04, 0.5, 1.04, 0 } })
			if pd then table.insert(fx, pd) end
			local md = gooKeyed(ctx, "mound", 1, Vector3.new(6.0, 3.0, 5.2), CFrame.new(g) * CFrame.Angles(0, math.atan2(-ctx.base.LookVector.X, -ctx.base.LookVector.Z), 0), {
				{ 1.30, 0.75, 0.6, 0.75, 0 }, { 1.85, 1, 1, 1, 1 }, { 2.85, 1.1, 0.4, 1.1, 1 }, { 3.40, 1.15, 0.1, 1.15, 0 } })
			if md then table.insert(fx, md) end
			local hidden, was, done = {}, {}, false
			for _, d in ctx.m:GetDescendants() do if d:IsA("BasePart") and d.Name ~= "Hitbox" then table.insert(hidden, d); was[d] = d.LocalTransparencyModifier end end
			table.insert(fx, { step = function(_, t)
				if t >= 1.85 then done = true end                           -- (fully faded: terminal, never restored)
				if t > 3.8 then return false end
				local gone = smooth((t - 1.40) / 0.45)
				for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = gone end end
				return true
			end, stop = function() if not done then for _, d in hidden do if d.Parent then d.LocalTransparencyModifier = was[d] end end end end })
			return group(fx)
		end },
		{ t = 2.30, fn = function(ctx) ctx.sound(GSND.splash, ctx.base.Position, 0.6, 0.8) end },
		-- FOUR matter motes (it is 4 matter): rise from the puddle 2.65, then arc toward home, gone by 3.55
		{ t = 2.65, fn = function(ctx)
			ctx.sound(SND.glass, ctx.base.Position, 0.35, 1.6, 0.65)
			local o = ctx.base.Position
			local home = ctx.home or (o - ctx.base.LookVector * 100)
			local toHome = Vector3.new(home.X - o.X, 0, home.Z - o.Z)
			local lk = Vector3.new(ctx.base.LookVector.X, 0, ctx.base.LookVector.Z)
			toHome = (toHome.Magnitude > 0.05) and toHome.Unit or ((lk.Magnitude > 0.05) and -lk.Unit or Vector3.xAxis)
			local side = Vector3.new(-toHome.Z, 0, toHome.X)
			local motes = {}
			for i = 1, 4 do
				local s = (i - 2.5) * 0.8
				local start = o + side * s
				start = Vector3.new(start.X, ctx.ground(start.X, start.Z) + 0.4, start.Z)
				local core = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = G_CYAN, Transparency = 1, Size = Vector3.one * 0.3, CFrame = CFrame.new(start) })
				local halo = part(ctx, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = G_MINT, Transparency = 1, Size = Vector3.one * 0.65, CFrame = CFrame.new(start) })
				motes[i] = { core = core, halo = halo, start = start, s = (i % 2 == 0) and 1 or -1, born = 2.65 + (i - 1) * 0.08 }
			end
			return { step = function(_, t)
				if t > 3.8 then return false end
				for _, k in motes do
					local e = t - k.born
					if e < 0 then k.core.Transparency, k.halo.Transparency = 1, 1; continue end
					local p
					if e < 0.2 then p = k.start + Vector3.new(0, 1.4 * smooth(e / 0.2), 0)
					else
						local u = clamp01((e - 0.2) / 0.5)
						p = k.start + Vector3.new(0, 1.4 + sin(u * pi) * 0.9, 0) + toHome * 30 * u * u + side * k.s * sin(u * pi)
					end
					k.core.CFrame, k.halo.CFrame = CFrame.new(p), CFrame.new(p)
					local f = smooth((e - 0.62) / 0.12)
					k.core.Transparency = math.max(1 - clamp01(e / 0.08), f) * 0.95
					k.halo.Transparency = 0.7 + 0.3 * math.max(1 - clamp01(e / 0.08), f)
				end
				return true
			end, stop = function() for _, k in motes do k.core:Destroy(); k.halo:Destroy() end end }
		end },
	},
}

A.FOR = A.FOR or {}
A.FOR.SquishF3v5 = { Pound = A.Pound, Grab = A.Grab, Thump = A.Thump, Defeat = A.BruteDefeat, Hurt = A.BruteHurt }
end

-- each form's own moves (the MOVE TEST names them; the Colossus's are also A.Slam / A.Sun / A.Boulder / A.Defeat)
A.FOR = A.FOR or {}
A.FOR.CrunchF4 = { Slam = A.Slam, Sun = A.Sun, Boulder = A.Boulder, Defeat = A.Defeat, Hurt = A.Hurt }

-- ===================== BATCH 4: the SQUISH DRIP lives in its own module, AttacksDrip (a script source is capped at
-- 200 000 characters; this one was 177 707 before the Drip). It gets A and the shared helpers it uses.
-- (batches 5-7, the magma forms, reuse the Colossus's rock effects: shared through E)
local E = { smooth = smooth, clamp01 = clamp01, LID_FULL = LID_FULL, GSND = GSND, SND = SND,
	G_RIM = G_RIM, G_FILL = G_FILL, G_CYAN = G_CYAN, part = part, pulse = pulse, ahead = ahead,
	dust = dust, sparks = sparks, cracks = cracks, emitterAt = emitterAt, frag = frag, claimFrag = claimFrag, takeParticles = takeParticles,
	onGround = onGround, strip = strip, edge = edge, setT = setT, AMBER = AMBER, MAGMA = MAGMA, BASALT = BASALT,
	W_AMBER = W_AMBER, W_MAGMA = W_MAGMA, W_WHITE = W_WHITE, W_UNDER = W_UNDER, SMOKE = SMOKE, SPARK = SPARK, curve = curve, EASE = EASE,
	gooWedge = gooWedge, gooCircle = gooCircle, gooLane = gooLane, droplets = droplets, bubbles = bubbles }
require(script.Parent:WaitForChild("AttacksDrip"))(A, E)
local crunch = script.Parent:FindFirstChild("AttacksCrunch")
if crunch then require(crunch)(A, E) end
-- (29 Oct night: the Titan REDO lives in AttacksTitan and takes over A.FOR.SquishF4v5; batch 2's stays above as the fallback)
local titan = script.Parent:FindFirstChild("AttacksTitan")
if titan then require(titan)(A, E) end

-- (every timeline's events in time order: audit r2 hygiene, the Boulder's were out of order)
for _, atk in { A.Slam, A.Sun, A.Boulder, A.Hurt, A.Defeat, A.TSlam, A.Bomb, A.Wave, A.THurt, A.TDefeat, A.TSlap2, A.Sticky, A.Boing, A.TwinHurt, A.TwinDefeat, A.Pound, A.Grab, A.Thump, A.BruteHurt, A.BruteDefeat } do table.sort(atk.events, function(x, y) return x.t < y.t end) end

return A
