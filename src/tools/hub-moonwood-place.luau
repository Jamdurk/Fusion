-- Alien Fusion hub: lay out the MOONWOOD FOREST in the north (references design\concepts\hub\C, C2, C3; kit from
-- hub_moonwood.py -> roblox-ready\hub-moonwood.obj -> 3D Importer -> model "hub-moonwood" in workspace).
-- The north is a low valley (x ~ -140..170, floor y ~0) between two raised plateaus (y ~25). Following C3:
-- groves of mixed trees with clear open areas, one winding main path from the hub, 3 small clearings with a violet DNA
-- pod cluster each, one big central clearing with a giant ELDER tree, moss patches, trees thinning onto the plateaus.
-- The band z > -235 stays empty (the hub plots go there). Budget (ChatGPT pack audit): forest 25-35k tris in a typical
-- view; ~80 trees x ~1.2k tris total, identical MeshIds (instanced), RenderFidelity Automatic, no lights, no particles.
local kit = workspace:FindFirstChild("hub-moonwood")
local store = game.ServerStorage:FindFirstChild("HubKit") or Instance.new("Folder"); store.Name = "HubKit"; store.Parent = game.ServerStorage
local K = store:FindFirstChild("Moonwood")
if kit then
	-- file the kit (once): each piece keeps its authored centre C (importer yaw rule: C = (-dx, dy, -dz))
	if K then K:Destroy() end
	K = Instance.new("Folder"); K.Name = "Moonwood"; K.Parent = store
	local pv = kit:GetPivot().Position
	for _, p in kit:GetDescendants() do
		if p:IsA("MeshPart") then
			local d = p.Position - pv
			p:SetAttribute("C", Vector3.new(-d.X, d.Y, -d.Z))
			for _, ch in p:GetChildren() do ch:Destroy() end
			p.Parent = K
		end
	end
	kit:Destroy()
end
assert(K, "no Moonwood kit")

local YAW = CFrame.Angles(0, math.pi, 0)
local LOOK = {
	Bark = { Enum.Material.SmoothPlastic, Color3.fromRGB(250, 244, 240), true },   -- (r3: warm pearl, warmer than the canopies)
	Canopy = { Enum.Material.SmoothPlastic, Color3.fromRGB(186, 180, 236), false },   -- (r3: more silver-lilac)
	-- (30 Oct textures, hub-moonwood-tex-swap.luau: Bark + Canopy carry baked SurfaceAppearances and stay white;
	-- Pods = pale husks + stems, PodGlow = the Neon drops)
	Pods = { Enum.Material.SmoothPlastic, Color3.fromRGB(226, 214, 248), false },
	PodGlow = { Enum.Material.Neon, Color3.fromRGB(150, 110, 255), false },
	Cups = { Enum.Material.SmoothPlastic, Color3.fromRGB(236, 232, 244), true },
	Glow = { Enum.Material.SmoothPlastic, Color3.fromRGB(178, 150, 255), true },   -- (r3: opaque lilac crystals, not a neon blob)
	Core = { Enum.Material.Neon, Color3.fromRGB(150, 110, 255), false },
	Moss = { Enum.Material.SmoothPlastic, Color3.fromRGB(78, 98, 140), false },
}
local function lookFor(name)
	for k, v in LOOK do if name:sub(-#k) == k then return v end end
	return { Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), false }
end
local function spawnPiece(src, base, s, parent)
	local p = src:Clone()
	local look = lookFor(src.Name)
	p.Material, p.Color = look[1], look[2]
	if p:FindFirstChildOfClass("SurfaceAppearance") then p.Color = Color3.new(1, 1, 1) end
	p.Anchored, p.CanTouch, p.CastShadow = true, false, look[1] ~= Enum.Material.Neon
	p.CanCollide, p.CanQuery = look[3], look[3]
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	p.Size = p.Size * s
	p.CFrame = base * CFrame.new(p:GetAttribute("C") * s) * (p:GetAttribute("NoYaw") and CFrame.identity or YAW)   -- GLB pieces: no yaw
	p.Parent = parent
	return p
end
local function spawnTree(kind, pos, rot, s, parent, name)
	local m = Instance.new("Model"); m.Name = name or kind
	local base = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	for _, part in { "Bark", "Canopy", "Pods", "PodGlow" } do
		if not K:FindFirstChild(kind .. part) then continue end              -- the flat OBJ kit has no PodGlow
		local pc = spawnPiece(K[kind .. part], base, s, m)
		if part == "Canopy" and not pc:FindFirstChildOfClass("SurfaceAppearance") then
			local v = (math.noise(pos.X / 40, pos.Z / 40, 5.5) + 0.5)           -- 0..1, smooth across the forest
			pc.Color = Color3.fromRGB(176, 170, 232):Lerp(Color3.fromRGB(204, 196, 240), math.clamp(v, 0, 1))
		end
	end
	pcall(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
	m.Parent = parent
	return m
end

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rp)
	if not h then return nil end
	return h.Position, h.Normal
end

local hub = workspace:FindFirstChild("Hub") or Instance.new("Folder"); hub.Name = "Hub"; hub.Parent = workspace
local old = hub:FindFirstChild("MoonwoodForest"); if old then old:Destroy() end
local F = Instance.new("Folder"); F.Name = "MoonwoodForest"; F.Parent = hub
local trees = Instance.new("Folder"); trees.Name = "Trees"; trees.Parent = F
local deco = Instance.new("Folder"); deco.Name = "Ground"; deco.Parent = F
local dna = Instance.new("Folder"); dna.Name = "DNAPods"; dna.Parent = F

-- layout features (C3)
-- (r4, 30 Oct: the hub moon grew to ~1,660 x 1,400 and the forest moved against the north wall: X -480..480,
-- N 420..700 (Roblox Z -700..-420), James: biomes against the walls with open ground between them and the bases)
local PATH = { Vector2.new(0, -405), Vector2.new(-24, -452), Vector2.new(-12, -505), Vector2.new(-34, -560), Vector2.new(-28, -620), Vector2.new(-8, -684) }
local PATH_HALF = 7
local ELDER = { c = Vector2.new(44, -548), r = 32 }                     -- (r3: +25 %)
local CLEARINGS = { { c = Vector2.new(-270, -520), r = 20 }, { c = Vector2.new(280, -505), r = 20 }, { c = Vector2.new(-160, -645), r = 20 }, { c = Vector2.new(210, -650), r = 20 } }
local function distSeg(p, a, b)
	local ab = b - a; local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
local function pathDist(p)
	local d = math.huge
	for i = 1, #PATH - 1 do d = math.min(d, distSeg(p, PATH[i], PATH[i + 1])) end
	return d
end
local function blocked(p, extra)
	if p.Y > -425 then return true end                                    -- the open plain (r4)
	if pathDist(p) < PATH_HALF + extra + 5 then return true end           -- (r3: trees back 5 more from the path)
	if (p - ELDER.c).Magnitude < ELDER.r + extra then return true end
	for _, c in CLEARINGS do if (p - c.c).Magnitude < c.r + extra then return true end end
	return false
end

-- 1. the ELDER tree: the wide tree x2.4, in its clearing
local R = Random.new(31)
do
	local g = ground(ELDER.c.X, ELDER.c.Y)
	local e = spawnTree("mwElder", g - Vector3.new(0, 0.6, 0), math.rad(-25), 2.4, F, "ElderMoonwood")
	-- a ring of pod clusters round its roots (the forest's richest DNA spot)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		local gp = ground(ELDER.c.X + math.cos(a) * 19, ELDER.c.Y + math.sin(a) * 19)
		if gp then
			local cl = Instance.new("Model"); cl.Name = "DNAPodCluster"
			local base = CFrame.new(gp) * CFrame.Angles(0, a, 0)
			spawnPiece(K.mwPodClusterCups, base, 3.9, cl); spawnPiece(K.mwPodClusterGlow, base, 3.9, cl); spawnPiece(K.mwPodClusterCore, base, 3.9, cl)
			cl:SetAttribute("DNA", "Moonwood"); cl.Parent = dna
		end
	end
end
-- 2. the 3 small clearings: one big pod cluster each
for _, c in CLEARINGS do
	local gp = ground(c.c.X, c.c.Y)
	local cl = Instance.new("Model"); cl.Name = "DNAPodCluster"
	local base = CFrame.new(gp) * CFrame.Angles(0, R:NextNumber(0, 6.28), 0)
	spawnPiece(K.mwPodClusterCups, base, 4.25, cl); spawnPiece(K.mwPodClusterGlow, base, 4.25, cl); spawnPiece(K.mwPodClusterCore, base, 4.25, cl)
	cl:SetAttribute("DNA", "Moonwood"); cl.Parent = dna
end

-- 3. trees: jittered grid, groves by noise, open areas left open, sparse on the plateaus
local placed = {}
local KINDS = { mwTall = 6, mwWide = 13, mwLow = 9 }                      -- footprint radius at scale 1
local count = { mwTall = 0, mwWide = 0, mwLow = 0 }
local CELL = 23                                                           -- (r4: 960 x 280 forest, ~180 trees; 17 gave 335 = ~800k tris)
for gx = -465, 465, CELL do
	for gz = -692, -428, CELL do
		local x, z = gx + R:NextNumber(-5, 5), gz + R:NextNumber(-5, 5)
		local p2 = Vector2.new(x, z)
		local g, n = ground(x, z)
		if g and n.Y > 0.86 and not blocked(p2, 4) then
			local grove = math.noise(x / 70, z / 70, 1.7)                 -- -0.5..0.5: groves vs open meadows
			local plateau = g.Y > 12
			-- (r3: clumps + open meadows, not a continuous strip)
			local want = plateau and 0.42 or (grove > 0.06 and 0.97 or (grove > -0.04 and 0.3 or 0.0))
			if R:NextNumber() < want then
				local kind
				local roll = R:NextNumber()
				local edge = pathDist(p2) < 22 or grove < 0.1                       -- path bends, grove edges, ridge shoulders: low trees
				if plateau then kind = roll < 0.65 and "mwLow" or "mwTall"
				elseif edge then kind = roll < 0.6 and "mwLow" or (roll < 0.8 and "mwWide" or "mwTall")
				else kind = roll < 0.72 and "mwTall" or (roll < 0.88 and "mwWide" or "mwLow") end
				local s = R:NextNumber(0.95, 1.3)
				local rad = KINDS[kind] * s
				local ok = true
				for _, q in placed do if (q.p - p2).Magnitude < (q.r + rad) * 0.62 then ok = false; break end end   -- (canopies may overlap a little: a grove)
				if ok then
					spawnTree(kind, g - Vector3.new(0, 0.5, 0), R:NextNumber(0, 6.28), s, trees)
					table.insert(placed, { p = p2, r = rad }); count[kind] += 1
				end
			end
		end
	end
end
-- 4. moss patches (blue-grey), more under groves
local moss = 0
for i = 1, 150 do
	local x, z = R:NextNumber(-460, 460), R:NextNumber(-692, -428)
	local g, n = ground(x, z)
	if g and n.Y > 0.85 and pathDist(Vector2.new(x, z)) > PATH_HALF + 1 then
		local s = R:NextNumber(1.2, 2.6)
		spawnPiece(K.mwMoss, CFrame.new(g - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, R:NextNumber(0, 6.28), 0), s, deco)
		moss += 1
	end
end
-- 4b. grey boulders in the open meadows (r3): the crater's rock meshes, big
local rockSrc = workspace.Hub.CraterLandmark.FloatingRocks:GetChildren()
local boulders = 0
for i = 1, 120 do
	if boulders >= 40 then break end
	local x, z = R:NextNumber(-460, 460), R:NextNumber(-692, -428)
	local p2 = Vector2.new(x, z)
	local g, n = ground(x, z)
	if g and n.Y > 0.8 and math.noise(x / 70, z / 70, 1.7) < 0.0 and not blocked(p2, 2) then
		local b = rockSrc[(i % #rockSrc) + 1]:Clone(); b.Name = "Boulder"
		for _, at in { "Home", "Phase", "Period" } do b:SetAttribute(at, nil) end
		b.Size = b.Size * R:NextNumber(2.2, 4.2); b.Color = Color3.fromRGB(112, 110, 120); b.CanCollide, b.CanQuery = true, true
		b.CFrame = CFrame.new(g + Vector3.new(0, b.Size.Y * 0.2, 0)) * CFrame.Angles(R:NextNumber(0, 6), R:NextNumber(0, 6), R:NextNumber(0, 6))
		b.Parent = deco; boulders += 1
	end
end
-- 4c. (r3) ground detail where the eye goes: path edges + clearing rims (path centre kept clean), 1-2 spores per clearing
local edgeMoss, edgeRocks, spores = 0, 0, 0
for i = 1, #PATH - 1 do
	local a, b = PATH[i], PATH[i + 1]
	local dir = (b - a).Unit; local side = Vector2.new(-dir.Y, dir.X)
	local n = math.floor((b - a).Magnitude / 9)
	for s = 1, n do
		local q = a:Lerp(b, s / (n + 1)) + side * ((s % 2 == 0) and 1 or -1) * R:NextNumber(PATH_HALF + 1.5, PATH_HALF + 4)
		local g = ground(q.X, q.Y)
		if g and q.Y < -425 then
			if R:NextNumber() < 0.65 then
				spawnPiece(K.mwMoss, CFrame.new(g - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, R:NextNumber(0, 6.28), 0), R:NextNumber(0.9, 1.6), deco); edgeMoss += 1
			else
				local bb = rockSrc[(s % #rockSrc) + 1]:Clone(); bb.Name = "EdgeRock"
				for _, at in { "Home", "Phase", "Period" } do bb:SetAttribute(at, nil) end
				bb.Size = bb.Size * R:NextNumber(0.9, 1.6); bb.Color = Color3.fromRGB(118, 116, 126)
				bb.CFrame = CFrame.new(g + Vector3.new(0, bb.Size.Y * 0.2, 0)) * CFrame.Angles(R:NextNumber(0, 6), R:NextNumber(0, 6), 0)
				bb.Parent = deco; edgeRocks += 1
			end
		end
	end
end
local rims = { { c = ELDER.c, r = ELDER.r } }
for _, c in CLEARINGS do table.insert(rims, c) end
for _, c in rims do
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + R:NextNumber(-0.25, 0.25)
		local q = c.c + Vector2.new(math.cos(a), math.sin(a)) * (c.r - R:NextNumber(1, 3))
		local g = ground(q.X, q.Y)
		if g then spawnPiece(K.mwMoss, CFrame.new(g - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, a, 0), R:NextNumber(1.1, 1.9), deco); edgeMoss += 1 end
	end
	for k = 1, 2 do                                                       -- 1-2 floating spore accents per clearing
		local a = R:NextNumber(0, 6.28); local q = c.c + Vector2.new(math.cos(a), math.sin(a)) * c.r * 0.45
		local g = ground(q.X, q.Y)
		if g then
			local sp = spawnPiece(K.mwSpore, CFrame.new(g + Vector3.new(0, R:NextNumber(5, 9), 0)), R:NextNumber(1.4, 2.0), deco)
			sp.Material, sp.Color, sp.CanCollide, sp.CanQuery = Enum.Material.Neon, Color3.fromRGB(170, 140, 255), false, false
			sp:SetAttribute("Spore", true); spores += 1
		end
	end
end
-- 5. the path: paint the terrain under it a lighter dusty material (MoonRegolith) so it reads as a trail
local T = workspace.Terrain
for i = 1, #PATH - 1 do
	local a, b = PATH[i], PATH[i + 1]
	local steps = math.ceil((b - a).Magnitude / 6)
	for s = 0, steps do
		local p = a:Lerp(b, s / steps)
		local g = ground(p.X, p.Y)
		if g then T:ReplaceMaterial(Region3.new(g - Vector3.new(PATH_HALF, 4, PATH_HALF), g + Vector3.new(PATH_HALF, 2, PATH_HALF)):ExpandToGrid(4), 4, Enum.Material.Ground, Enum.Material.Sand) end
	end
end
-- store the layout features for later systems (mining, nests)
F:SetAttribute("PathPoints", #PATH); F:SetAttribute("Elder", Vector3.new(ELDER.c.X, 0, ELDER.c.Y))
local tris = count.mwTall * 1332 + count.mwWide * 1701 + count.mwLow * 1332
return string.format("trees: tall %d, wide %d, low %d (+ elder); moss %d+%d; boulders %d+%d; spores %d; pods %d; ~%dk tris", count.mwTall, count.mwWide, count.mwLow, moss, edgeMoss, boulders, edgeRocks, spores, #dna:GetChildren(), math.floor(tris / 1000))
