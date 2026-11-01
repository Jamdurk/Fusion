-- Alien Fusion: CRATER THRONE stage C pieces (31 Oct 2026; ref design\concepts\hub\R5-throne-stageC-chatgpt.png, R3, R4;
-- spec design\conquest-lanes\core\THRONE-SPEC.md). All hidden at rest; the client ReactorMotion controller shows them:
--   Crown     a 5-point light-line crown ~14 wide above the broken ring (HELD: owner colour, turns slowly)
--   Banners   5 owner banners on the rim tops (45 / 90 / 135 / 270 / 315 deg; not the E/W breaches or the 225 notch)
--   Stumps    per pylon: a short broken crystal stump + 3 shards + a little smoke (State "destroyed")
--   Flash     per spawn pocket: a light column + a flare ring (attribute SpawnAt = server time, plays 0.5 s)
--   Meteor    one cosmetic meteor: rock, streak trail, impact flash, dust ring, burst emitter (outer rim only)
-- Re-runnable: rebuilds workspace.Hub.Conquest.Throne.Pieces.StageC.
local GM = game.ServerStorage.HubKit.GooMarsh
local CC = game.ServerStorage.HubKit.CrystalCanyon
local T = workspace.Terrain
local P = workspace.Hub.Conquest.Throne.Pieces
local old = P:FindFirstChild("StageC"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "StageC"

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z) local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp); return h and h.Position.Y or 0 end
local function dir(deg) local a = math.rad(deg); return Vector3.new(math.cos(a), 0, -math.sin(a)) end
local function part(name, size, cf, color, mat, parent, shape)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.Neon; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Transparency = 1; if shape then p.Shape = shape end; p.Parent = parent; return p
end
local BLUE = Color3.fromRGB(70, 140, 255)

-- ---------- crown hologram (above the ring + upper orb: orb top y ~83) ----------
local crown = Instance.new("Model"); crown.Name = "Crown"; crown.Parent = root
local C0 = Vector3.new(0, 98, 0)
local R, BAND, SPIKE = 10, 3.6, 8                       -- radius, band height, spike height (r1 look: 14 wide read tiny from the plots)
for i = 0, 19 do                                         -- two band rings (top + bottom), 20 segments each
	local a0, a1 = i / 20 * math.pi * 2, (i + 1) / 20 * math.pi * 2
	for _, y in { 0, BAND } do
		local p0 = C0 + Vector3.new(math.cos(a0) * R, y, math.sin(a0) * R)
		local p1 = C0 + Vector3.new(math.cos(a1) * R, y, math.sin(a1) * R)
		part("Band", Vector3.new(0.8, 0.8, (p1 - p0).Magnitude + 0.2), CFrame.lookAt((p0 + p1) / 2, p1), BLUE, nil, crown)
	end
end
for k = 0, 4 do                                          -- 5 spikes: each two slanted bars meeting at a tip + a gem
	local a = k / 5 * math.pi * 2
	local tip = C0 + Vector3.new(math.cos(a) * R, BAND + SPIKE, math.sin(a) * R)
	for _, s in { -1, 1 } do
		local b = a + s * math.pi / 5 * 0.55
		local foot = C0 + Vector3.new(math.cos(b) * R, BAND, math.sin(b) * R)
		part("Spike", Vector3.new(0.8, 0.8, (tip - foot).Magnitude + 0.2), CFrame.lookAt((tip + foot) / 2, tip), BLUE, nil, crown)
	end
	part("Gem", Vector3.new(2, 2, 2), CFrame.new(tip + Vector3.new(0, 0.6, 0)), BLUE, nil, crown, Enum.PartType.Ball)
end
part("Glow", Vector3.new(0.4, 2 * R + 6, 2 * R + 6), CFrame.new(C0 + Vector3.new(0, BAND / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), BLUE, Enum.Material.ForceField, crown, Enum.PartType.Cylinder)
crown:SetAttribute("Centre", C0)
for _, p in crown:GetChildren() do p:SetAttribute("RestCF", p.CFrame) end   -- the client turns the crown about C0

-- ---------- owner banners on the rim ----------
local banners = Instance.new("Folder"); banners.Name = "Banners"; banners.Parent = root
for _, deg in { 45, 90, 135, 270, 315 } do
	local best, br = -1e9, 84
	for r = 76, 98, 2 do local p = dir(deg) * r; local y = ground(p.X, p.Z); if y > best then best = y; br = r end end
	local p = dir(deg) * br
	local at = CFrame.lookAt(Vector3.new(p.X, best - 0.6, p.Z), Vector3.new(0, best - 0.6, 0))   -- cloth faces the crater
	local m = Instance.new("Model"); m.Name = "Banner" .. deg; m.Parent = banners
	local base = part("Block", Vector3.new(3, 1.6, 3), at * CFrame.new(0, 0.6, 0), Color3.fromHex("4A4D57"), Enum.Material.Basalt, m)
	part("Pole", Vector3.new(0.45, 11, 0.45), at * CFrame.new(0, 6.5, 0), Color3.fromHex("5B6170"), Enum.Material.Metal, m)
	part("Bar", Vector3.new(4.2, 0.32, 0.32), at * CFrame.new(0, 11.6, -0.35), Color3.fromHex("5B6170"), Enum.Material.Metal, m)
	local cloth = part("Cloth", Vector3.new(3.6, 6.2, 0.12), at * CFrame.new(0, 8.3, -0.4), BLUE, Enum.Material.Fabric, m)
	cloth:SetAttribute("TeamColour", true)
	for s = -1, 1, 2 do
		part("Chevron", Vector3.new(0.75, 2.6, 0.14), cloth.CFrame * CFrame.new(s * 0.8, -0.6, -0.02) * CFrame.Angles(0, 0, math.rad(-s * 42)), Color3.fromHex("DCE8FF"), Enum.Material.Neon, m)
	end
	part("Light", Vector3.new(0.8, 0.8, 0.8), at * CFrame.new(0, 12.4, 0), BLUE, Enum.Material.Neon, m, Enum.PartType.Ball)
end

-- ---------- destroyed-pylon stumps ----------
for _, name in { "PylonEast", "PylonWest" } do
	local py = P:FindFirstChild(name)
	if py then
		local cr = py.Crystal
		local top = py.Body.Position.Y + py.Body.Size.Y / 2
		local m = Instance.new("Model"); m.Name = "Stump" .. name:sub(6); m.Parent = root
		local stump = GM.gmVeinCrystal:Clone(); stump.Name = "Stump"; stump.Size = cr.Size * Vector3.new(0.85, 0.32, 0.85)
		stump.CFrame = CFrame.new(cr.Position.X, top + stump.Size.Y / 2 - 0.3, cr.Position.Z) * CFrame.Angles(0, 0.7, math.rad(9))
		stump.Anchored = true; stump.CanCollide = false; stump.CanQuery = false; stump.Transparency = 1; stump.Parent = m
		for _, sa in stump:GetChildren() do if sa:IsA("SurfaceAppearance") then sa.Color = Color3.fromRGB(70, 90, 110); pcall(function() sa.EmissiveStrength = 0 end) end end   -- a dead crystal: no glow
		local shelf = py:FindFirstChild("Shelf")
		local sy = shelf and (shelf.Position.Y + shelf.Size.Y / 2) or top - 14
		for i = 1, 3 do
			local sh = GM.gmVeinCrystal:Clone(); sh.Name = "Shard"; sh.Size = sh.Size * 0.3   -- (r1 look: canyon shards glowed orange + read as specks)
			sh.CFrame = CFrame.new(cr.Position + Vector3.new(math.cos(i * 2.1) * 4.5, 0, math.sin(i * 2.1) * 4.5)) * CFrame.Angles(0, i * 1.3, math.rad(70))
			sh.CFrame = sh.CFrame - Vector3.new(0, sh.Position.Y - sy - 0.4, 0)
			sh.Anchored = true; sh.CanCollide = false; sh.CanQuery = false; sh.Transparency = 1; sh.Parent = m
			for _, sa in sh:GetChildren() do if sa:IsA("SurfaceAppearance") then sa.Color = Color3.fromRGB(70, 90, 110); pcall(function() sa.EmissiveStrength = 0 end) end end
		end
		local smoke = Instance.new("ParticleEmitter"); smoke.Name = "Smoke"; smoke.Rate = 1.2; smoke.Lifetime = NumberRange.new(2.5, 3.5)
		smoke.Speed = NumberRange.new(1.5, 2.5); smoke.SpreadAngle = Vector2.new(12, 12); smoke.Color = ColorSequence.new(Color3.fromRGB(70, 72, 82))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		smoke.LightEmission = 0; smoke.Enabled = false; smoke.Parent = stump
		m:SetAttribute("For", name)
	end
end

-- ---------- spawn flash per pocket ----------
for _, pk in P:GetChildren() do
	if pk.Name:match("^Spawn%d") then
		local floor = pk:FindFirstChild("Floor")
		if floor then
			local fy = floor.Position.Y + floor.Size.Y / 2
			local m = Instance.new("Model"); m.Name = "Flash" .. pk.Name:sub(6); m.Parent = root
			part("Column", Vector3.new(14, 7, 7), CFrame.new(floor.Position.X, fy + 7, floor.Position.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("9A6BFF"), Enum.Material.Neon, m, Enum.PartType.Cylinder)
			part("Flare", Vector3.new(0.3, 15, 15), CFrame.new(floor.Position.X, fy + 0.2, floor.Position.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("D8C2FF"), Enum.Material.Neon, m, Enum.PartType.Cylinder)
			m:SetAttribute("Pocket", pk.Name)
		end
	end
end

-- ---------- meteor (cosmetic, client-driven) ----------
local met = Instance.new("Model"); met.Name = "Meteor"; met.Parent = root
local rock = CC.ccBoulderC:Clone(); rock.Name = "Rock"; rock.Size = rock.Size * 0.6; rock.Anchored = true; rock.CanCollide = false
rock.CanQuery = false; rock.CanTouch = false; rock.Transparency = 1; rock.CFrame = CFrame.new(0, -500, 0); rock.Parent = met
local a0 = Instance.new("Attachment"); a0.Name = "Head"; a0.Parent = rock
local a1 = Instance.new("Attachment"); a1.Name = "Tail"; a1.Position = Vector3.new(0, 0, 0); a1.Parent = T
local trail = Instance.new("Beam"); trail.Name = "Streak"; trail.Attachment0 = a0; trail.Attachment1 = a1
trail.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255), Color3.fromRGB(70, 170, 255)); trail.LightEmission = 1   -- (R5: cyan-white streak)
trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
trail.Width0, trail.Width1 = 3, 0.4; trail.FaceCamera = true; trail.Enabled = false; trail.Parent = rock
part("Flash", Vector3.new(10, 10, 10), CFrame.new(0, -500, 0), Color3.fromRGB(170, 225, 255), Enum.Material.Neon, met, Enum.PartType.Ball)
-- the dust ring: 24 Neon segments the client spreads out on the ground (a flat disc sank into the slopes and grey
-- dust vanished on the pale ground; R5 ring is cyan)
local dust = Instance.new("Model"); dust.Name = "Dust"; dust.Parent = met
for i = 1, 24 do part("Seg", Vector3.new(0.6, 0.35, 2), CFrame.new(0, -500, 0), Color3.fromHex("A5B5C2"), Enum.Material.SmoothPlastic, dust) end   -- (stage C audit r1: dusty grey-blue, not a cyan target ring)
local burst = Instance.new("ParticleEmitter"); burst.Name = "Burst"; burst.Rate = 0; burst.Lifetime = NumberRange.new(1, 1.8)
burst.Speed = NumberRange.new(10, 22); burst.SpreadAngle = Vector2.new(70, 70); burst.Acceleration = Vector3.new(0, -12, 0)
burst.Color = ColorSequence.new(Color3.fromRGB(190, 180, 165)); burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
burst.Enabled = false; burst.Parent = met.Flash
-- (stage C audit r1) 8-12 soft dust puffs rolling outward along the ground
local puffs = Instance.new("ParticleEmitter"); puffs.Name = "Puffs"; puffs.Rate = 0; puffs.Lifetime = NumberRange.new(0.6, 1.0)
puffs.Speed = NumberRange.new(14, 20); puffs.SpreadAngle = Vector2.new(180, 6); puffs.EmissionDirection = Enum.NormalId.Top
puffs.Shape = Enum.ParticleEmitterShape.Disc; puffs.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
puffs.Color = ColorSequence.new(Color3.fromHex("A5B5C2")); puffs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
puffs.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }); puffs.Drag = 3
puffs.Enabled = false; puffs.Parent = met.Flash

root.Parent = P
return "stage C: crown, 5 banners, 2 stumps, 4 flashes, meteor"
