-- Alien Fusion hub: CRYSTAL CANYON effects (31 Oct 2026), built to match ChatGPT's effects sheet E5
-- (design\concepts\hub\E5-crystal-canyon-effects-chatgpt.png + E5-reply.txt numbers): calm + sparse, 25-60 particles
-- visible on a low-end phone, every light shadowless, <= 6 lights per view. Run after hub-crystalcanyon-place.luau.
-- Textures (assets\textures\hub\fx, hub_crystalcanyon_fx.py, uploaded): _G.CC_FX = { star = .., ember = .., dust = .., mote = .. }.
local FX = _G.CC_FX or { star = "rbxassetid://86272351138981", ember = "rbxassetid://101355905306242",
	dust = "rbxassetid://132675998382510", mote = "rbxassetid://105479828086095" }   -- (asset-ids.md)
local M = workspace.Hub.CrystalCanyon
local old = M:FindFirstChild("FX"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "FX"; root.Parent = M
local AMBER, GOLD, HOT, WARM = Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 214, 120), Color3.fromRGB(255, 120, 40), Color3.fromRGB(214, 190, 160)
local n = { lights = 0, emitters = 0 }
local P = _G.CC_FXP or {}   -- tuning overrides (rates, sizes) from the Studio audit

local function holder(name, cf, size)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.CanTouch = false; p.CastShadow = false; p.Transparency = 1; p.Size = size; p.CFrame = cf; p.Parent = root
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.8; e.LightInfluence = 0.1; e.Rotation = NumberRange.new(0, 0); e.RotSpeed = NumberRange.new(0, 0)
	for k, v in props do e[k] = v end
	e.Parent = parent; n.emitters += 1
	return e
end
local function light(parent, color, range, bright)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = bright; l.Shadows = false
	l.Parent = parent; n.lights += 1
end
local function seq(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local function fadeInOut(lo, hi)   -- transparent at birth + death (soft, never pops)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, lo), NumberSequenceKeypoint.new(0.7, hi), NumberSequenceKeypoint.new(1, 1) })
end
local function bump(a, b, c)   -- size: grow in, hold, shrink out
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.3, b), NumberSequenceKeypoint.new(1, c) })
end

-- LANDMARK spire (E5 #4): one warm light pool at the base, a slow golden haze round the upper crystals, star glints
local spire = M.Landmark:FindFirstChild("LandmarkSpire")
if spire then
	local cf, size = spire:GetBoundingBox()
	local baseY = cf.Position.Y - size.Y / 2
	light(holder("SpireGlow", CFrame.new(cf.Position.X, baseY + 8, cf.Position.Z), Vector3.one), Color3.fromHex("FFB45A"), P.spireRange or 42, P.spireBright or 1.0)   -- (spec audit r1 C: lights)
	local tips = holder("SpireHaze", CFrame.new(cf.Position.X, baseY + size.Y * 0.7, cf.Position.Z), Vector3.new(size.X * 0.6, size.Y * 0.45, size.Z * 0.6))
	emitter(tips, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.mote or "", Color = ColorSequence.new(GOLD),
		Size = bump(0, P.hazeSize or 1.6, 0.4), Transparency = fadeInOut(0.55, 0.7), Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), Rate = P.hazeRate or 1.5, LightEmission = 1 })
	local spk = holder("SpireSparkle", CFrame.new(cf.Position.X, baseY + size.Y * 0.5, cf.Position.Z), Vector3.new(size.X * 0.7, size.Y * 0.8, size.Z * 0.7))
	emitter(spk, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.star or "", Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
		Size = bump(0, P.starSize or 1.4, 0), Transparency = seq(0.05, 0.3), Lifetime = NumberRange.new(0.45, 0.7),
		Speed = NumberRange.new(0), Rate = P.starRate or 2.5, LightEmission = 1,
		Rotation = NumberRange.new(0, 45) })
end

-- large crystal clusters near the routes: a rare star glint each (E5 #3), max ~12 emitters
local glints = 0
for _, m in M:GetDescendants() do
	if glints >= (P.maxGlints or 12) then break end
	if m:IsA("Model") and m.Name == "ccClusterL" then
		local cf, size = m:GetBoundingBox()
		local box = holder("ClusterGlint", cf, size * 0.8)
		emitter(box, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.star or "", Color = ColorSequence.new(Color3.fromRGB(255, 236, 190)),
			Size = bump(0, P.glintSize or 0.8, 0), Transparency = seq(0.1, 0.35), Lifetime = NumberRange.new(0.4, 0.6),
			Speed = NumberRange.new(0), Rate = P.glintRate or 0.6, LightEmission = 1 })
		glints += 1
	end
end

local seamLights = 0   -- (Studio r1: the wall fractures pushed the canyon to 7 lights; hard cap 2 seam lights)
-- magma seams (E5 #1 / #2): a few embers rising out of half the seams, a small warm glow on 3 of them
for i, s in M.Seams:GetChildren() do
	local cf, size = s:GetBoundingBox()
	if i % 2 == 1 then
		local area = holder("SeamEmbers", CFrame.new(cf.Position.X, cf.Position.Y + 0.4, cf.Position.Z) * cf.Rotation, Vector3.new(size.X * 0.7, 0.2, 1.5))
		emitter(area, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.ember or "", Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 160)), ColorSequenceKeypoint.new(0.5, HOT), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 50, 20)) }),
			Size = seq(P.emberSize or 0.35, 0.1), Transparency = fadeInOut(0.05, 0.3), Lifetime = NumberRange.new(1.8, 2.8),
			Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0.6, 0.4, 0),
			EmissionDirection = Enum.NormalId.Top, Rate = P.emberRate or 1.5, LightEmission = 1, Drag = 0.4 })
	end
	if i % 6 == 1 and s.Name ~= "WallSeam" and seamLights < 2 then seamLights += 1; light(holder("SeamGlow", cf + Vector3.new(0, 2, 0), Vector3.one), Color3.fromHex("FF8A2E"), P.seamRange or 12, P.seamBright or 0.7) end   -- 2 seam lights in all
end

-- nests (E5 #5): orange heat light deep in the tunnel + slow motes drifting out of the mouth
for _, nest in M.Nests:GetChildren() do
	local tun = nest:IsA("Model") and nest:FindFirstChild("ccNestTunnel")
	if not tun then continue end
	local piv = nest:GetPivot()
	local fwd = piv.LookVector                               -- the kit front (the mouth) is local -Z = LookVector
	local at = tun.Position - fwd * 2
	local deep = holder("TunnelGlow", CFrame.lookAt(at, at + fwd), Vector3.new(3, 3, 3))   -- Front = out of the mouth
	light(deep, Color3.fromHex("FF9A42"), P.tunnelRange or 12, P.tunnelBright or 0.8)
	emitter(deep, { Shape = Enum.ParticleEmitterShape.Sphere, Texture = FX.mote or "", Color = ColorSequence.new(GOLD),
		Size = seq(0.35, 0.12), Transparency = fadeInOut(0.15, 0.4), Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(1.2, 2),
		SpreadAngle = Vector2.new(25, 25), Rate = P.moteRate or 1, LightEmission = 1, EmissionDirection = Enum.NormalId.Front })
end

-- warm dust drifting low along the channels (E5 #6): a few long boxes on the floors, very faint
local DUST = P.dust or { { 560, -115, 0.3 }, { 650, -110, -0.5 }, { 740, -46, -0.7 }, { 600, 117, 0.7 }, { 690, 156, 0 }, { 790, 95, -0.6 } }
for _, d in DUST do
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { workspace.Terrain }
	local h = workspace:Raycast(Vector3.new(d[1], 200, d[2]), Vector3.new(0, -400, 0), rp)
	local y = h and h.Position.Y or 3
	local box = holder("FloorDust", CFrame.new(d[1], y + 1.5, d[2]) * CFrame.Angles(0, d[3], 0), Vector3.new(36, 2, 14))
	emitter(box, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.dust or "", Color = ColorSequence.new(WARM),
		Size = bump(2, P.dustSize or 5, 6), Transparency = fadeInOut(P.dustAlpha or 0.82, 0.88), Lifetime = NumberRange.new(5, 7),
		Speed = NumberRange.new(1.5, 2.5), EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(10, 5),
		Rate = P.dustRate or 0.6, LightEmission = 0, LightInfluence = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8) })
end
return ("FX: %d lights, %d emitters"):format(n.lights, n.emitters)
