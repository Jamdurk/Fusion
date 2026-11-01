-- Alien Fusion hub: place the imported CRATER LANDMARK (hub_crater.py -> roblox-ready\hub-crater.obj -> 3D Importer).
-- Run once in Edit after the import (the model "hub-crater" in workspace). Matches design\concepts\hub\B + B2.
-- The importer turns meshes 180 deg about Y: each piece's authored centre C = (-dx, dy, -dz) from the model pivot and
-- its placement is base * CFrame.new(C) * YAW180 (same rule as the Titan K meshes).
local m = workspace:FindFirstChild("hub-crater")
if not m then return "no hub-crater model" end
local pv = m:GetPivot().Position
local YAW = CFrame.Angles(0, math.pi, 0)
local FLOOR, RINGY = -10.5, 74                      -- crater floor centre (measured); ring centre
local WRECKY = FLOOR + 5                             -- the wreck sits on the mound
-- (r3, 30 Oct: pieces are authored at FINAL scale in hub_crater.py; the ring centre sits at +74 (ChatGPT's 120-stud
-- visibility test); a terrain mound under the wreck (+7, made once with FillBall) stays from v3)
local RING_TILT = CFrame.Angles(math.rad(18), 0, 0)
local HALO_TILT = CFrame.Angles(math.rad(-8), 0, math.rad(10))

local hub = workspace:FindFirstChild("Hub") or Instance.new("Folder")
hub.Name = "Hub"; hub.Parent = workspace
local old = hub:FindFirstChild("CraterLandmark"); if old then old:Destroy() end
local L = Instance.new("Model"); L.Name = "CraterLandmark"; L.Parent = hub
local function sub(name) local f = Instance.new("Model"); f.Name = name; f.Parent = L; return f end
local static, ring, halo, rocks, crystals = sub("Shell"), sub("Ring"), sub("Halo"), sub("FloatingRocks"), sub("Crystals")

local DARK = Color3.fromRGB(74, 76, 88)
local looks = {
	crShellSeams = { Enum.Material.Neon, Color3.fromRGB(40, 170, 225) },
	crRingStrips = { Enum.Material.Neon, Color3.fromRGB(60, 205, 255) },
	crHalo = { Enum.Material.Neon, Color3.fromRGB(90, 220, 255) },
	crOrb = { Enum.Material.Neon, Color3.fromRGB(30, 120, 255) },
	crOrbLattice = { Enum.Material.Neon, Color3.fromRGB(150, 235, 255) },
	crCore = { Enum.Material.Neon, Color3.fromRGB(150, 70, 255) },
	crCoreLattice = { Enum.Material.Neon, Color3.fromRGB(235, 175, 255) },
	crRubble = { Enum.Material.Slate, Color3.fromRGB(62, 62, 68) },
	crFragments = { Enum.Material.Slate, Color3.fromRGB(96, 98, 110) },
}
local parts = {}
for _, p in m:GetDescendants() do
	if p:IsA("MeshPart") then
		local d = p.Position - pv
		parts[p.Name] = { p = p, C = Vector3.new(-d.X, d.Y, -d.Z) }
	end
end
local function setup(p, name)
	local look = looks[name] or { Enum.Material.Slate, name:match("^crShellPlate") and Color3.fromRGB(122, 124, 138) or name:match("^crRing%d") and Color3.fromRGB(64, 66, 78) or DARK }
	p.Material, p.Color = look[1], look[2]
	p.Anchored, p.CanTouch = true, false
	local solid = name:match("^crShellPlate") ~= nil or name == "crRubble" or name == "crFragments"
	p.CanCollide, p.CanQuery = solid, solid
	p.CastShadow = look[1] ~= Enum.Material.Neon
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	for _, ch in p:GetChildren() do ch:Destroy() end
end
for name, e in parts do
	local p = e.p
	setup(p, name)
	p:SetAttribute("C", e.C)
	if name:match("^crShell") or name:match("^crCore") then
		p.CFrame = CFrame.new(0, WRECKY, 0) * CFrame.new(e.C) * YAW; p.Parent = static
	elseif name == "crRubble" or name == "crFragments" then
		p.CFrame = CFrame.new(0, FLOOR, 0) * CFrame.new(e.C) * YAW; p.Parent = static
	elseif name:match("^crRing") or name:match("^crOrb") then
		p.CFrame = CFrame.new(0, RINGY, 0) * RING_TILT * CFrame.new(e.C) * YAW; p.Parent = ring
	elseif name == "crHalo" then
		p.CFrame = CFrame.new(0, RINGY, 0) * HALO_TILT * CFrame.new(e.C) * YAW; p.Parent = halo
	end
end
ring:SetAttribute("Base", CFrame.new(0, RINGY, 0) * RING_TILT)
halo:SetAttribute("Base", CFrame.new(0, RINGY, 0) * HALO_TILT)

-- floating rocks (6) and DNA crystals (9), copies of the shared meshes (one MeshId each: Roblox instances them)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z) local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp); return h and h.Position.Y or FLOOR end
local R = Random.new(7)
for i = 1, 6 do
	local src = parts["crRock" .. ((i - 1) % 3 + 1)].p
	local r = src:Clone(); setup(r, "rock"); r.CanCollide, r.CanQuery = false, false
	local a = (i - 1) / 6 * math.pi * 2 + R:NextNumber(-0.3, 0.3)
	local rad = R:NextNumber(30, 46)
	r.CFrame = CFrame.new(math.cos(a) * rad, FLOOR + R:NextNumber(46, 70), math.sin(a) * rad) * CFrame.Angles(R:NextNumber(0, 6), R:NextNumber(0, 6), 0)
	r:SetAttribute("Home", r.CFrame); r:SetAttribute("Phase", R:NextNumber(0, 6.28)); r:SetAttribute("Period", R:NextNumber(5, 8))
	r.Parent = rocks
end
local crys = parts.crCrystal.p
for i = 1, 9 do
	local c = crys:Clone(); setup(c, "crystal"); c.CanCollide, c.CanQuery = true, true
	local amber = i % 2 == 0
	c.Material = Enum.Material.Neon
	c.Color = amber and Color3.fromRGB(235, 125, 25) or Color3.fromRGB(25, 165, 235)
	local a = (i - 1) / 9 * math.pi * 2 + R:NextNumber(-0.2, 0.2)
	local rad = R:NextNumber(38, 52)
	local x, z = math.cos(a) * rad, math.sin(a) * rad
	local s = R:NextNumber(1.0, 1.6)
	c.Size = c.Size * s
	c.CFrame = CFrame.new(x, gy(x, z) + c.Size.Y * 0.36, z) * CFrame.Angles(0, R:NextNumber(0, 6.28), 0) * YAW
	c:SetAttribute("DNA", amber and "Crunch" or "Squish")
	c.Parent = crystals
end
for _, n in { "crRock1", "crRock2", "crRock3", "crCrystal" } do parts[n].p:Destroy() end

-- three violet energy beams from the shell up to the ring (Roblox Beams: camera-facing quads, cheap)
local anchor = Instance.new("Part"); anchor.Name = "BeamAnchor"; anchor.Anchored = true; anchor.CanCollide = false
anchor.CanQuery, anchor.CanTouch, anchor.Transparency, anchor.Size = false, false, 1, Vector3.new(1, 1, 1)
anchor.CFrame = CFrame.new(0, FLOOR, 0); anchor.Parent = L
for i = 1, 3 do
	local a = (i - 1) / 3 * math.pi * 2 + 0.5
	local a0 = Instance.new("Attachment"); a0.Parent = anchor; a0.WorldPosition = Vector3.new(-8 + math.cos(a) * 7, WRECKY + 28, math.sin(a) * 7)
	local a1 = Instance.new("Attachment"); a1.Parent = anchor; a1.WorldPosition = (CFrame.new(0, RINGY, 0) * RING_TILT * CFrame.new(math.cos(a) * 22, -3, math.sin(a) * 22)).Position
	local b = Instance.new("Beam"); b.Name = "EnergyBeam" .. i
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 200, 255))
	b.LightEmission, b.LightInfluence, b.Brightness = 1, 0, 3
	b.Width0, b.Width1, b.FaceCamera, b.Segments = 3.0, 2.2, true, 1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.7) })
	b.Parent = anchor
end
-- two lights only (budget: 4-6 in a busy view), no shadows
local function light(part, color, range)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = 2; l.Shadows = false; l.Parent = part
end
light(parts.crCore.p, Color3.fromRGB(170, 90, 255), 40)
light(parts.crOrb.p, Color3.fromRGB(80, 190, 255), 52)

-- the old reactor goes to storage (not deleted)
local store = game.ServerStorage:FindFirstChild("_HubOld") or Instance.new("Folder"); store.Name = "_HubOld"; store.Parent = game.ServerStorage
for _, n in { "FusionReactor", "Reactor_Glow" } do local o = workspace.Map.Structures:FindFirstChild(n); if o then o.Parent = store end end
m:Destroy()
local count, tris = 0, 0
for _, p in L:GetDescendants() do if p:IsA("MeshPart") then count += 1 end end
return "placed " .. count .. " mesh parts"
