-- Alien Fusion hub: GOO MARSH effects (30 Oct 2026), built to match ChatGPT's effects sheet D5
-- (design\concepts\hub\D5-goo-marsh-effects-chatgpt.png) inside the spec audit r1 budget (fix 5): calm + sparse,
-- 25-60 particles visible on a low-end phone, drips 1-3/s on the giants only, pool bubbles 1-2/s on a few pools,
-- spores ~1/s, every light shadowless. Run after hub-goomarsh-place.luau. Textures (assets\textures\hub\fx, uploaded):
-- _G.GM_FX = { dot = "rbxassetid://..", ring = .., drop = .., bubble = .. }.
local FX = _G.GM_FX or {}
local M = workspace.Hub.GooMarsh
local old = M:FindFirstChild("FX"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "FX"; root.Parent = M
local CYAN, LILAC, PALE = Color3.fromRGB(120, 236, 255), Color3.fromRGB(196, 150, 255), Color3.fromRGB(214, 250, 255)
local n = { lights = 0, emitters = 0 }

local function holder(name, cf, size)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false
	p.CanTouch = false; p.CastShadow = false; p.Transparency = 1; p.Size = size; p.CFrame = cf; p.Parent = root
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.7; e.LightInfluence = 0.2; e.Rotation = NumberRange.new(0, 0); e.RotSpeed = NumberRange.new(0, 0)
	for k, v in props do e[k] = v end
	e.Parent = parent; n.emitters += 1
	return e
end
local function light(parent, color, range, bright)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = bright; l.Shadows = false
	l.Parent = parent; n.lights += 1
end
local function seq(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local FLAT = Enum.ParticleOrientation.VelocityPerpendicular   -- rings lie flat on the ground / goo surface

-- giants: soft lilac light pool under the gills (D5 #4), drips forming at the rim, falling, ring splash (D5 #1)
for _, g in M.Giants:GetChildren() do
	local cap, gills = g:FindFirstChild("gmGiantCap"), g:FindFirstChild("gmGiantGills")
	if not (cap and gills) then continue end
	local s = cap.Size.X / 41.0
	local c = gills.Position
	local under = holder("GillGlow", CFrame.new(c.X, c.Y - 3 * s, c.Z), Vector3.new(1, 1, 1))
	light(under, Color3.fromRGB(184, 132, 255), 24 * s, 1.3)   -- (Studio r1: tight ranges)
	local stalk = g:FindFirstChild("gmGiantStalk")
	local groundY = stalk.Position.Y - stalk.Size.Y / 2 + 0.9 * s
	local rimY = c.Y - 3.5 * s
	local rim = holder("DripRim", CFrame.new(c.X, rimY, c.Z), Vector3.new(34 * s, 0.2, 34 * s))
	emitter(rim, { Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Texture = FX.drop or "", Color = ColorSequence.new(CYAN), Size = seq(0.55 * s, 0.4 * s), Transparency = seq(0.1, 0.25),
		Lifetime = NumberRange.new(math.sqrt(2 * (rimY - groundY) / 45)), Speed = NumberRange.new(0), Acceleration = Vector3.new(0, -45, 0),
		Rate = 2, EmissionDirection = Enum.NormalId.Bottom })
	local splash = holder("DripSplash", CFrame.new(c.X, groundY + 0.4, c.Z), Vector3.new(34 * s, 0.2, 34 * s))
	emitter(splash, { Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Texture = FX.ring or "", Color = ColorSequence.new(CYAN), Orientation = FLAT, EmissionDirection = Enum.NormalId.Top,
		Size = seq(0.2, 2.2), Transparency = seq(0.25, 1), Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0.01), Rate = 2 })
	-- slow drifting spores round each giant (D5 #3): cyan + lilac specks, very sparse
	local cloud = holder("Spores", CFrame.new(c.X, groundY + 14, c.Z), Vector3.new(60, 22, 60))
	emitter(cloud, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.dot or "",
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(0.5, LILAC), ColorSequenceKeypoint.new(1, CYAN) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(0.3, 0.9), SpreadAngle = Vector2.new(180, 180), Rate = 1, Drag = 0.2,
		LightEmission = 1 })
end

-- pools: bubbles rising + popping into soft rings (D5 #2), on the 4 pools nearest the routes only
for _, name in { "Pool1", "Pool2", "Pool5", "Pool8" } do
	local p = M.Pools:FindFirstChild(name)
	if not p then continue end
	local cf, size = p:GetBoundingBox()
	local top = cf.Position.Y + size.Y / 2 - 0.45
	local area = holder(name .. "Bubbles", CFrame.new(cf.Position.X, top, cf.Position.Z), Vector3.new(size.X * 0.55, 0.2, size.Z * 0.55))
	emitter(area, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.bubble or "", Color = ColorSequence.new(PALE),
		Size = seq(0.35, 0.8), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(0.5, 0.9), EmissionDirection = Enum.NormalId.Top, Rate = 1.5 })
	emitter(area, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.ring or "", Color = ColorSequence.new(CYAN),
		Orientation = FLAT, EmissionDirection = Enum.NormalId.Top, Size = seq(0.3, 2.6), Transparency = seq(0.3, 1),
		Lifetime = NumberRange.new(0.9), Speed = NumberRange.new(0.01), Rate = 1.2 })
end

-- drapes: a little splash of bubbles + rings where the cascade lands (D5 #5)
for _, d in M.Drapes:GetChildren() do
	local cf, size = d:GetBoundingBox()
	local foot = holder("CascadeFoot", CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 0.6, cf.Position.Z), Vector3.new(6, 0.2, 6))
	emitter(foot, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.bubble or "", Color = ColorSequence.new(PALE),
		Size = seq(0.3, 0.6), Transparency = seq(0.2, 1), Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, -12, 0), EmissionDirection = Enum.NormalId.Top, Rate = 2 })
	emitter(foot, { Shape = Enum.ParticleEmitterShape.Box, Texture = FX.ring or "", Color = ColorSequence.new(CYAN),
		Orientation = FLAT, EmissionDirection = Enum.NormalId.Top, Size = seq(0.5, 3), Transparency = seq(0.3, 1),
		Lifetime = NumberRange.new(0.8), Speed = NumberRange.new(0.01), Rate = 1 })
end

-- nests: a lilac glow deep in the tunnel + faint motes drifting out of the mouth (D5 #6)
for _, nest in M.Nests:GetChildren() do
	local tun = nest:FindFirstChild("gmNestTunnel")
	if not tun then continue end
	local fwd = Vector3.xAxis                                   -- every nest is placed facing +X (its route)
	local at = tun.Position - fwd * 3
	local deep = holder("TunnelGlow", CFrame.lookAt(at, at + fwd), Vector3.new(3, 3, 3))   -- Front = out of the mouth
	light(deep, Color3.fromRGB(176, 110, 255), 12, 2)
	emitter(deep, { Shape = Enum.ParticleEmitterShape.Sphere, Texture = FX.dot or "", Color = ColorSequence.new(LILAC),
		Size = seq(0.3, 0.15), Transparency = seq(0.2, 1), Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(1.2, 2),
		SpreadAngle = Vector2.new(25, 25), Rate = 1, LightEmission = 1, EmissionDirection = Enum.NormalId.Front })
end
return ("FX: %d lights, %d emitters"):format(n.lights, n.emitters)
