-- Alien Fusion hub: the crater IMPACT SCAR round the wreck (reference design\concepts\hub\K-impact-scar-chatgpt.png;
-- ChatGPT crater audit r2 fix 2). Run in Edit after hub-crater-place.luau.
--   1. terrain: the burnt zone (~56 across, a little longer along the impact line) painted MoonBasalt (dark), with a
--      splattered noisy edge, plus 7 long dark ejecta streaks reaching past it;
--   2. radial cracks: thin dark strips laid on the ground, 3 of them with a faint cyan / violet glow inside;
--   3. two big detached hull plates lying at an angle in the scar, scattered dark debris;
--   4. the wreck looks crashed, not installed: two dominant petals offset 3-5 studs, one lower petal buried 5 more.
local T = workspace.Terrain
local L = workspace.Hub.CraterLandmark
local R = Random.new(11)
local RES = 4
local IMPACT = math.rad(20)                         -- the impact line (radians from +x); the scar stretches along it
local function scarDist(x, z)                       -- elliptical distance, 1.0 = the scar edge
	local c, s = math.cos(-IMPACT), math.sin(-IMPACT)
	local u, v = x * c - z * s, x * s + z * c
	return math.sqrt((u / 31) ^ 2 + (v / 25) ^ 2)
end
local streaks = {}
for i = 1, 7 do streaks[i] = { a = (i - 1) / 7 * math.pi * 2 + R:NextNumber(-0.25, 0.25), len = R:NextNumber(46, 66), w = R:NextNumber(3.5, 6) } end

-- 1. terrain paint (only the solid surface voxels change material; the shape stays)
local region = Region3.new(Vector3.new(-72, -28, -72), Vector3.new(72, 24, 72)):ExpandToGrid(RES)
local mats, occ = T:ReadVoxels(region, RES)
local size = mats.Size
local lo = region.CFrame.Position - region.Size / 2
local painted = 0
for xi = 1, size.X do
	for zi = 1, size.Z do
		local x = lo.X + (xi - 0.5) * RES
		local z = lo.Z + (zi - 0.5) * RES
		local d = scarDist(x, z) + math.noise(x / 9, z / 9, 0.37) * 0.32 + math.noise(x / 3.5, z / 3.5, 4.1) * 0.12
		local burn = d < 1
		if not burn then
			local r, a = math.sqrt(x * x + z * z), math.atan2(z, x)
			for _, s in streaks do
				local da = math.abs((a - s.a + math.pi) % (2 * math.pi) - math.pi)
				local half = (s.w * (1 - r / s.len)) / math.max(r, 1)       -- tapers to a point
				if r < s.len and da < half and math.noise(x / 5, z / 5, 9.2) > -0.25 then burn = true; break end
			end
		end
		if burn then
			for yi = 1, size.Y do
				if occ[xi][yi][zi] > 0 and mats[xi][yi][zi] ~= Enum.Material.Air then
					mats[xi][yi][zi] = Enum.Material.Basalt; painted += 1
				end
			end
		end
	end
end
T:WriteVoxels(region, RES, mats, occ)

-- ground helper (terrain only)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), rp)
	return h and h.Position or Vector3.new(x, -10.5, z), h and h.Normal or Vector3.yAxis
end

local scar = L:FindFirstChild("Scar"); if scar then scar:Destroy() end
scar = Instance.new("Model"); scar.Name = "Scar"; scar.Parent = L
local function strip(p0, p1, w, color, mat, sink)
	local mid = (p0 + p1) / 2
	local len = (p1 - p0).Magnitude
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Color = mat, color
	p.Size = Vector3.new(w, 0.3, len + w * 0.6)
	p.CFrame = CFrame.lookAt(mid - Vector3.new(0, sink, 0), p1 - Vector3.new(0, sink, 0))
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = scar
	return p
end

-- 2. radial cracks: jagged paths from the wreck's foot outward; 3 of 9 glow (a thin Neon line inside a dark one)
local cracks = 0
for i = 1, 9 do
	local a = (i - 1) / 9 * math.pi * 2 + R:NextNumber(-0.2, 0.2)
	local r = R:NextNumber(14, 18)
	local glow = (i % 3 == 0)
	local gcol = (i % 2 == 0) and Color3.fromRGB(160, 90, 255) or Color3.fromRGB(60, 190, 255)
	local prev = ground(math.cos(a) * r, math.sin(a) * r)
	local steps = R:NextInteger(4, 6)
	for s = 1, steps do
		a += R:NextNumber(-0.18, 0.18); r += R:NextNumber(4, 6.5)
		local nxt = ground(math.cos(a) * r, math.sin(a) * r)
		local w = 1.1 * (1 - s / (steps + 1)) + 0.35
		strip(prev, nxt, w, Color3.fromRGB(22, 22, 28), Enum.Material.Slate, 0.05)
		if glow and s <= steps - 1 then strip(prev, nxt, w * 0.35, gcol, Enum.Material.Neon, -0.04) end
		prev = nxt; cracks += 1
	end
end

-- 3. two detached hull plates (copies of two petals, smaller, lying at 20-35 deg) + scattered dark debris
local shell = L.Shell
local plates = 0
for i, info in { { "crShellPlate2", 0.5, math.rad(200), 30 }, { "crShellPlate4", 0.38, math.rad(330), 27 } } do
	local src = shell:FindFirstChild(info[1])
	if src then
		local c = src:Clone(); c.Name = "DetachedPlate" .. i
		c.Size = c.Size * info[2]
		local pos = ground(math.cos(info[3]) * info[4], math.sin(info[3]) * info[4])
		c.CFrame = CFrame.new(pos + Vector3.new(0, c.Size.Y * 0.18, 0)) * CFrame.Angles(math.rad(R:NextNumber(20, 35)), info[3], math.rad(R:NextNumber(-25, 25)))
		c.Parent = scar; plates += 1
		-- one glowing crack on it
		local g = Instance.new("Part"); g.Name = "PlateCrack"; g.Anchored = true; g.CanCollide = false; g.CanQuery = false; g.CanTouch = false
		g.Material, g.Color, g.CastShadow = Enum.Material.Neon, Color3.fromRGB(40, 170, 225), false
		g.Size = Vector3.new(0.4, 0.4, c.Size.Y * 0.6)
		g.CFrame = c.CFrame * CFrame.new(0, 0, -c.Size.Z * 0.42) * CFrame.Angles(math.rad(90), 0, math.rad(R:NextNumber(-20, 20)))
		g.Parent = scar
	end
end
local rockSrc = L.FloatingRocks:GetChildren()
local debris = 0
for i = 1, 22 do
	local a, r = R:NextNumber(0, math.pi * 2), R:NextNumber(12, 34)
	local src = rockSrc[(i - 1) % #rockSrc + 1]
	local d = src:Clone(); d.Name = "Debris"
	d.Size = d.Size * R:NextNumber(0.35, 0.8); d.Color = Color3.fromRGB(46, 46, 52)
	for _, k in { "Home", "Phase", "Period" } do d:SetAttribute(k, nil) end
	local pos = ground(math.cos(a) * r, math.sin(a) * r)
	d.CFrame = CFrame.new(pos + Vector3.new(0, d.Size.Y * 0.25, 0)) * CFrame.Angles(R:NextNumber(0, 6), R:NextNumber(0, 6), R:NextNumber(0, 6))
	d.Parent = scar; debris += 1
end

-- 4. crashed, not installed: offset two dominant petals, bury one lower petal 5 more
local function nudge(name, dy) local p = shell:FindFirstChild(name); if p then p.CFrame = p.CFrame + Vector3.new(0, dy, 0) end end
nudge("crShellPlate1", 4); nudge("crShellPlate3", -3); nudge("crShellPlate6", -5)

return string.format("painted %d voxels, %d crack segments, %d plates, %d debris", painted, cracks, plates, debris)
