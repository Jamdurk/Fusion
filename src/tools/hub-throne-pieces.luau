-- Alien Fusion: CRATER THRONE arena pieces (31 Oct 2026; refs design\concepts\hub\R1 (layout), R3 (states), R4 (pieces);
-- spec design\conquest-lanes\core\THRONE-SPEC.md). Built from the kits so it matches the biomes (James: simple):
--   2 SHIELD PYLONS on the N / S shelves: a Crystal Canyon basalt column (ccColumnA) + the Goo Marsh cyan DNA crystal
--     (gmVeinCrystal) as the emitter, 2 glow strips + a light facing the lanes; an Attachment "Link" on the crystal for the
--     shield link beam; attribute State = neutral / active / destroyed (the ReactorMotion controller shows it)
--   4 SPAWN POCKETS (r 60, 18 x 22): a flat basalt floor slab over the levelled pad (smooth terrain can't get flatter
--     than ~+-0.5), a violet spawn ring (24 short Neon segments: cylinders are discs, not rings) + 4 ticks, canyon
--     boulders as a low lip on the 3 rim-side edges; Attachments "Spawn1..4" for the garrison groups
-- Re-runnable: rebuilds workspace.Hub.Conquest.Throne.Pieces. Greybox markers are hidden (kept).
local CC = game.ServerStorage.HubKit.CrystalCanyon
local GM = game.ServerStorage.HubKit.GooMarsh
local T = workspace.Terrain
local th = workspace.Hub.Conquest.Throne
local old = th:FindFirstChild("Pieces"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "Pieces"
local gb = th:FindFirstChild("Greybox"); if gb then gb.Parent = nil; gb.Name = "Greybox"; gb.Parent = game.ServerStorage:FindFirstChild("ArchiveRingR5") or game.ServerStorage end

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z) local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp); return h and h.Position.Y or 0 end
local function hiGround(cf, w, d)
	local hi = -1e9
	for u = -w / 2, w / 2, 1 do for v = -d / 2, d / 2, 1 do local p = (cf * CFrame.new(u, 0, v)).Position; hi = math.max(hi, ground(p.X, p.Z)) end end
	return hi
end
local function dir(deg) local a = math.rad(deg); return Vector3.new(math.cos(a), 0, -math.sin(a)) end
local function face(c) return CFrame.lookAt(c, Vector3.new(0, c.Y, 0)) end        -- -Z toward the crater centre
local function clone(src, size, cf, parent, name)
	local p = src:Clone(); p.Size = size; p.CFrame = cf; p.Anchored = true; p.Parent = parent
	if name then p.Name = name end
	return p
end
local function neon(name, size, cf, color, parent)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = Enum.Material.Neon
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Parent = parent
	return p
end

-- ---------- shield pylons ----------
local CYAN = Color3.fromHex("56DDF2")
for _, py in { { "East", Vector3.new(67, 0, 0) }, { "West", Vector3.new(-67, 0, 0) } } do   -- (audit B r1: moved from N / S, see hub-throne-arena)
	local m = Instance.new("Model"); m.Name = "Pylon" .. py[1]; m.Parent = root
	local f = face(py[2])
	local gy = hiGround(f, 12, 12)
	local at = CFrame.new(py[2].X, gy, py[2].Z) * (f - f.Position)
	-- the shelf slab (flat 14 x 14 under the pylon)
	local slab = Instance.new("Part"); slab.Name = "Shelf"; slab.Size = Vector3.new(14, 1.2, 14); slab.CFrame = at * CFrame.new(0, 0.1, 0)
	slab.Material = Enum.Material.Slate; slab.Color = Color3.fromHex("7A7C86"); slab.Anchored = true; slab.Parent = m
	-- the basalt body: a canyon column cluster squeezed to ~6.5 x 12 x 6
	local base = clone(CC.ccColumnA, CC.ccColumnA.Size * Vector3.new(0.42, 0.5, 0.45), at * CFrame.new(0, 0.7 + CC.ccColumnA.Size.Y * 0.25, 0), m, "Body")
	local top = base.Position.Y + base.Size.Y / 2
	-- the emitter crystal (cyan DNA crystal) on top
	local cr = clone(GM.gmVeinCrystal, GM.gmVeinCrystal.Size * 0.95, CFrame.new(at.X, top + GM.gmVeinCrystal.Size.Y * 0.475 - 0.8, at.Z) * (f - f.Position), m, "Crystal")
	local link = Instance.new("Attachment"); link.Name = "Link"; link.Parent = cr
	-- (r1 look) the vein crystal read pale white here and the canyon column glows amber: tint both toward R4's cyan
	for _, sa in cr:GetChildren() do if sa:IsA("SurfaceAppearance") then sa.Color = Color3.fromRGB(120, 225, 255) end end
	for _, sa in base:GetChildren() do if sa:IsA("SurfaceAppearance") then pcall(function() sa.EmissiveTint = CYAN end) end end
	-- the shield link (off until the throne is attacked): pylon crystal -> the core
	local coreAtt = workspace.Hub.CraterLandmark.Shell.crCore:FindFirstChild("ShieldLink")
	if not coreAtt then coreAtt = Instance.new("Attachment"); coreAtt.Name = "ShieldLink"; coreAtt.Parent = workspace.Hub.CraterLandmark.Shell.crCore end
	local beam = Instance.new("Beam"); beam.Name = "ShieldLink"; beam.Attachment0 = link; beam.Attachment1 = coreAtt
	beam.Texture = "rbxassetid://80886891608954"; beam.TextureMode = Enum.TextureMode.Wrap; beam.TextureLength = 10; beam.TextureSpeed = 1.2
	beam.Color = ColorSequence.new(CYAN); beam.LightEmission = 1; beam.Width0, beam.Width1 = 1.6, 1.0; beam.FaceCamera = true
	beam.CurveSize0 = 18; beam.Segments = 24; beam.Enabled = false; beam.Parent = cr
	-- 2 glow strips on the lane-facing side (+Z of this frame faces outward = toward the lanes)
	for s = -1, 1, 2 do
		neon("Strip", Vector3.new(0.35, base.Size.Y * 0.62, 0.35), at * CFrame.new(s * 1.3, 0.7 + base.Size.Y * 0.45, base.Size.Z / 2 - 0.4), Color3.fromRGB(70, 74, 86), m):SetAttribute("RestColor", Color3.fromRGB(70, 74, 86))   -- the colour the client returns them to
	end
	local light = Instance.new("PointLight"); light.Name = "Glow"; light.Color = CYAN; light.Range = 14; light.Brightness = 0; light.Shadows = false; light.Parent = cr
	m:SetAttribute("State", "neutral"); m:SetAttribute("MaxHP", 400)
	-- the combat target: an invisible column, the only queryable pylon part
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.CanQuery = false; d.CanTouch = false end end
	local hb = Instance.new("Part"); hb.Name = "PylonHitbox"; hb.Shape = Enum.PartType.Cylinder; hb.Size = Vector3.new(top + 4 - gy, 8, 8)
	hb.CFrame = CFrame.new(at.X, gy + (top + 4 - gy) / 2, at.Z) * CFrame.Angles(0, 0, math.rad(90)); hb.Transparency = 1
	hb.Anchored = true; hb.CanCollide = false; hb.CanTouch = false; hb.CanQuery = true; hb.Parent = m
end

-- ---------- spawn pockets ----------
local VIOLET = Color3.fromHex("7A3CFF")   -- (Neon blooms lighter: #B86BFF read pink)
for _, deg in { 45, 135, 225, 315 } do
	local m = Instance.new("Model"); m.Name = "Spawn" .. deg; m.Parent = root
	local f = face(dir(deg) * 60)
	local hi = hiGround(f, 18, 22)
	local at = CFrame.new(f.X, hi, f.Z) * (f - f.Position)
	local floor = Instance.new("Part"); floor.Name = "Floor"; floor.Size = Vector3.new(18, 1.4, 22)
	floor.CFrame = at * CFrame.new(0, 0.05 - 0.7 + 0.25, 0)          -- top 0.25 above the highest ground under it
	floor.Material = Enum.Material.Slate; floor.Color = Color3.fromHex("7A7C86"); floor.Anchored = true; floor.Parent = m   -- mid-grey (LESSONS 15: dark stone reads black)
	local fy = floor.Position.Y + floor.Size.Y / 2
	-- the spawn ring (r 6) + 4 ticks
	local ring = Instance.new("Model"); ring.Name = "SpawnRing"; ring.Parent = m
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local p = at.Position + (at - at.Position) * Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		local seg = neon("Seg", Vector3.new(0.45, 0.12, 1.45), CFrame.lookAt(Vector3.new(p.X, fy + 0.07, p.Z), Vector3.new(p.X, fy + 0.07, p.Z) + (at - at.Position) * Vector3.new(-math.sin(a), 0, math.cos(a))), VIOLET, ring)
		seg.Transparency = 0.15
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local p = at.Position + (at - at.Position) * Vector3.new(math.cos(a) * 7.6, 0, math.sin(a) * 7.6)
		neon("Tick", Vector3.new(0.5, 0.12, 2.0), CFrame.lookAt(Vector3.new(p.X, fy + 0.07, p.Z), Vector3.new(at.X, fy + 0.07, at.Z)), VIOLET, ring).Transparency = 0.15
	end
	-- garrison group spawn points (2 x 2 inside the ring)
	for i, o in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
		local a0 = Instance.new("Attachment"); a0.Name = "Spawn" .. i; a0.Parent = floor
		a0.WorldCFrame = at * CFrame.new(o[1], fy - at.Y + 0.5, o[2])
	end
	-- the lip: canyon boulders along the back (rim side, +Z) and both sides, the crater side left open
	local rocks = { { -7, 11, 0.9 }, { 0, 12, 1.1 }, { 7, 11, 0.8 }, { -10, 5, 0.7 }, { 10, 5, 0.75 } }   -- (audit B r1) the 2 crater-side lip rocks dropped: they pinched the ring
	for i, rk in rocks do
		local src = (i % 2 == 0) and CC.ccBoulderC or CC.ccBoulderB
		local w = at * CFrame.new(rk[1], 0, rk[2])
		local g = ground(w.X, w.Z)
		local b = clone(src, src.Size * rk[3], CFrame.new(w.X, math.max(g, fy - 1) + src.Size.Y * rk[3] * 0.3, w.Z) * CFrame.Angles(0, i * 1.7, 0), m, "Lip" .. i)
	end
	m:SetAttribute("Group", deg)
end

-- ---------- the core's shield bubble + target marker (both hidden until the fight) ----------
local fx = Instance.new("Folder"); fx.Name = "CoreFX"; fx.Parent = root
local core = workspace.Hub.CraterLandmark.Shell.crCore
local bubble = Instance.new("Part"); bubble.Name = "ShieldBubble"; bubble.Shape = Enum.PartType.Ball; bubble.Size = Vector3.new(15, 15, 15)
bubble.CFrame = CFrame.new(core.Position); bubble.Material = Enum.Material.ForceField; bubble.Color = CYAN; bubble.Transparency = 1
bubble.Anchored = true; bubble.CanCollide = false; bubble.CanQuery = false; bubble.CanTouch = false; bubble.CastShadow = false; bubble.Parent = fx
-- (audit B r1) readable shield: a brighter hex skin (the client sets it) + a cyan-violet silhouette outline (Highlight)
local hl = Instance.new("Highlight"); hl.Name = "ShieldOutline"; hl.Adornee = bubble; hl.FillTransparency = 1
hl.OutlineColor = Color3.fromRGB(150, 120, 255); hl.OutlineTransparency = 1; hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Parent = bubble
local marker = Instance.new("Model"); marker.Name = "TargetMarker"; marker.Parent = fx
local gy = ground(core.Position.X, core.Position.Z)
for i = 0, 31 do
	local a = i / 32 * math.pi * 2
	local p = core.Position + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
	local s = neon("Seg", Vector3.new(0.5, 0.15, 1.75), CFrame.lookAt(Vector3.new(p.X, gy + 0.2, p.Z), Vector3.new(p.X, gy + 0.2, p.Z) + Vector3.new(-math.sin(a), 0, math.cos(a))), Color3.fromRGB(255, 70, 90), marker)
	s.Transparency = 1
end
-- the core-break shockwave (a flat ring the client scales out across the crater floor)
local wave = Instance.new("Part"); wave.Name = "Shockwave"; wave.Shape = Enum.PartType.Cylinder; wave.Size = Vector3.new(0.4, 10, 10)
wave.CFrame = CFrame.new(core.Position.X, gy + 0.6, core.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
wave.Material = Enum.Material.ForceField; wave.Color = Color3.fromHex("B86BFF"); wave.Transparency = 1
wave.Anchored = true; wave.CanCollide = false; wave.CanQuery = false; wave.CanTouch = false; wave.CastShadow = false; wave.Parent = fx

-- the throne's state lives on the Throne folder (server-owned later; for now set by hand / the preview commands):
--   State = "wild" | "attacked" | "shieldDown" | "held";  OwnerColor (Color3, when held);  BreakAt (server time of a core break)
th:SetAttribute("State", th:GetAttribute("State") or "wild")
root.Parent = th
return "throne pieces: 2 pylons + 4 spawn pockets + core FX"
