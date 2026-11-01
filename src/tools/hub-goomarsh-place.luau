-- Alien Fusion hub: lay out the GOO MARSH (west biome, X -830..-490, Z -330..330, north = -Z), 30 Oct 2026.
-- Kit: ServerStorage.HubKit.GooMarsh (hub-goomarsh-kit.luau). References: design\concepts\hub\D (look), D2b (sizes),
-- D3 (materials), D4 (layout: pools chained by trickles, dark rock clumps round every pool, sprouts + blobs packed round
-- the giants, crystals + goo drapes at the cliff feet, sandy routes between). Start: Astra's placement draft (pool dips,
-- nests, routes) with the ChatGPT spec audit r1 fixes: landmark deeper (X -575), 2 big pools + films + drapes, budgets.
-- Everything is raycast-seated on the terrain; pools get the terrain under them levelled (backup first:
-- ServerStorage.MarshTerrainBackup). Output: workspace.Hub.GooMarsh. Re-runnable (clears its folder first).
local K = game.ServerStorage.HubKit.GooMarsh
local hub = workspace.Hub
local old = hub:FindFirstChild("GooMarsh"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "GooMarsh"
local T = workspace.Terrain
local rng = Random.new(3011)

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rp)
	return h and h.Position.Y or 0, h and h.Material or Enum.Material.Ground
end

-- ------------------------------------------------------------ layout anchors (Roblox x, z)
local ROUTES = {   -- 18 wide walking routes (kept clear of everything but goo films / trickles)
	{ { -490, 0 }, { -540, 0 } },
	{ { -540, -290 }, { -540, 290 } },
	{ { -540, 0 }, { -600, -15 }, { -630, -35 } },        -- nest 1
	{ { -540, 120 }, { -610, 135 }, { -660, 140 } },      -- nest 2
	{ { -540, -200 }, { -620, -215 }, { -695, -262 } },   -- nest 3
}
local POOLS = {    -- {kit, x, z, scale}: the 6 terrain dips (Astra / measured) + 2 big pools (audit fix 2) + 1 extra dip
	{ "gmPoolA", -595, -112, 1.0 }, { "gmPoolA", -688, -108, 1.5 }, { "gmPoolB", -768, -188, 1.0 },
	{ "gmPoolB", -628, -262, 0.9 }, { "gmPoolB", -702, 48, 1.7 }, { "gmPoolA", -590, 190, 1.1 },
	{ "gmPoolA", -762, 240, 0.95 }, { "gmPoolB", -622, 75, 1.0 },
}
local LINKS = { { 1, 2 }, { 2, 3 }, { 1, 4 }, { 5, 8 }, { 5, 7 }, { 8, 6 }, { 2, 5 } }   -- goo trickles between pools
local GIANTS = { { -578, -62, 1.15 },   -- (Studio r1: landmark +15 %, the obvious west-biome landmark from the plots)
	 { -772, -60, 0.92 }, { -770, 140, 1.05 } }   -- landmark first
local NESTS = { { -650, -35 }, { -680, 140 }, { -715, -262 } }                  -- all face +X (the routes)

-- ------------------------------------------------------------ occupancy
local occ = {}     -- {x, z, r}
local function distSeg(px, pz, a, b)
	local ax, az, bx, bz = a[1], a[2], b[1], b[2]
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((px - ax - t * dx) ^ 2 + (pz - az - t * dz) ^ 2)
end
local function onRoute(x, z, r)
	for _, rt in ROUTES do
		for i = 1, #rt - 1 do if distSeg(x, z, rt[i], rt[i + 1]) < 9 + r then return true end end
	end
	return false
end
local function poolR(p) return 24 * p[4] end
local function free(x, z, r, allowRoute)
	if x < -826 or x > -492 or z < -330 or z > 330 then return false end
	if not allowRoute and onRoute(x, z, r) then return false end
	for _, o in occ do if (x - o[1]) ^ 2 + (z - o[2]) ^ 2 < (r + o[3]) ^ 2 then return false end end
	return true
end
local function claim(x, z, r) table.insert(occ, { x, z, r }) end

-- ------------------------------------------------------------ spawning
local LOOK = {   -- suffix -> collide, castShadow
	Stalk = { true, true }, Cap = { false, true }, Gills = { false, false }, Blob = { false, true }, Rock = { true, true },
	Crystal = { false, false }, VeinGoo = { false, false }, Shell = { true, true }, Tunnel = { false, false },
	Pool = { false, false }, Film = { false, false }, Stream = { false, false }, Drape = { false, false },
}
local function look(name)
	for k, v in LOOK do if name:find(k) then return v end end
	return { false, true }
end
local stats = { tris = 0, parts = 0 }
local TRIS = { gmGiant = 7552, gmTrumpet = 1753, gmUmbrella = 1268, gmSprout = 454, gmBlobA = 963, gmBlobB = 672,
	gmNest = 3859, gmPoolA = 2016, gmPoolB = 2016, gmFilmA = 728, gmFilmB = 624, gmStreamA = 924, gmStreamB = 924,
	gmRockA = 430, gmRockB = 535, gmRockC = 633, gmVein = 1624, gmDrape = 1268 }
local function spawn(kind, pieces, x, z, yaw, s, parent, sink, yOverride)
	-- s = number (uniform) or Vector3 (per axis); pieces = kit mesh names; base seated on the ground at (x, z)
	local sv = typeof(s) == "Vector3" and s or Vector3.new(s, s, s)
	local gy = yOverride or (ground(x, z) - (sink or 0.3))
	local base = CFrame.new(x, gy, z) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model"); m.Name = kind
	for _, n in pieces do
		local src = K:FindFirstChild(n)
		if src then
			local p = src:Clone()
			local lk = look(n)
			p.Anchored, p.CanTouch = true, false
			p.CanCollide, p.CanQuery, p.CastShadow = lk[1], lk[1], lk[2]
			p.RenderFidelity = Enum.RenderFidelity.Automatic
			p.Size = p.Size * sv
			p.CFrame = base * CFrame.new(src:GetAttribute("C") * sv)
			p.Parent = m
			stats.parts += 1
		end
	end
	m.WorldPivot = base                                   -- (pivot = the seated base, so PivotTo tilts round the foot)
	pcall(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
	m:SetAttribute("Biome", "GooMarsh")
	m.Parent = parent
	stats.tris += math.floor((TRIS[kind] or 0) * (sv.X * sv.Z > 0 and 1 or 1))
	return m
end
local SET = {
	gmGiant = { "gmGiantStalk", "gmGiantCap", "gmGiantGills" },
	gmTrumpet = { "gmTrumpetStalk", "gmTrumpetCap", "gmTrumpetGills" },
	gmUmbrella = { "gmUmbrellaStalk", "gmUmbrellaCap", "gmUmbrellaGills" },
	gmSprout = { "gmSproutStalk", "gmSproutCap", "gmSproutGills" },
	gmNest = { "gmNestShell", "gmNestTunnel" }, gmVein = { "gmVeinRock", "gmVeinCrystal", "gmVeinGoo" },
}
local function put(kind, x, z, yaw, s, parent, sink, y)
	return spawn(kind, SET[kind] or { kind }, x, z, yaw, s, parent, sink, y)
end
local function folder(name)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f
end
local F = { pools = folder("Pools"), streams = folder("Streams"), giants = folder("Giants"), nests = folder("Nests"),
	groves = folder("Groves"), rocks = folder("Rocks"), veins = folder("Veins"), drapes = folder("Drapes") }

-- ------------------------------------------------------------ terrain backup, then pools (levelled into their dips)
local store = game.ServerStorage
if not store:FindFirstChild("MarshTerrainBackup") then
	-- voxel units (4 studs); restore = T:PasteRegion(tr, tr:GetAttribute("CornerVoxel"), true)
	local lo, hi = Vector3int16.new(-215, -10, -90), Vector3int16.new(-115, 20, 90)
	local tr = T:CopyRegion(Region3int16.new(lo, hi)); tr.Name = "MarshTerrainBackup"
	tr:SetAttribute("CornerVoxel", Vector3.new(lo.X, lo.Y, lo.Z)); tr.Parent = store
end
for i, p in POOLS do
	local R = poolR(p)
	local hs = {}
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		table.insert(hs, (ground(p[2] + math.cos(a) * R * 0.95, p[3] + math.sin(a) * R * 0.95)))
	end
	table.sort(hs)
	local rimY = hs[9]                                     -- lower third of the rim: the goo sits in the dip
	local _, mat = ground(p[2], p[3])
	-- (FillCylinder's height runs along the CFrame's Y axis)
	T:FillCylinder(CFrame.new(p[2], rimY + 5.4, p[3]), 12, R * 0.82, Enum.Material.Air)       -- nothing pokes through
	T:FillCylinder(CFrame.new(p[2], rimY - 4.1, p[3]), 6, R * 0.96, mat == Enum.Material.Air and Enum.Material.Ground or mat)
	-- (Studio r1: smooth terrain rounds to 4-stud voxels, so the levelled ground came out ~0.35 ABOVE the goo and buried
	-- it. Seat the pool from the REAL surface after carving: its sheet (local +0.30) sits 0.15 over the highest point)
	local top = -1e9
	for k = 0, 35 do
		local a = k / 36 * math.pi * 2
		for _, f in { 0, 0.3, 0.55, 0.75 } do top = math.max(top, (ground(p[2] + math.cos(a) * R * f, p[3] + math.sin(a) * R * f))) end
	end
	p.y = top + 0.15 - 0.30
	put(p[1], p[2], p[3], rng:NextNumber(0, math.pi * 2), Vector3.new(p[4], 1, p[4]), F.pools, 0, p.y).Name = "Pool" .. i
	claim(p[2], p[3], R + 2)
	task.wait()
end

-- ------------------------------------------------------------ trickles between pools (stream pieces chained rim to rim)
for li, l in LINKS do
	local a, b = POOLS[l[1]], POOLS[l[2]]
	local dx, dz = b[2] - a[2], b[3] - a[3]
	local d = math.sqrt(dx * dx + dz * dz); local ux, uz = dx / d, dz / d
	local s0, s1 = poolR(a) * 0.9, d - poolR(b) * 0.9
	local L = s1 - s0
	if L > 4 then
		local n = math.max(1, math.ceil(L / 21))
		local seg = L / n
		for k = 1, n do
			local t = s0 + seg * (k - 0.5)
			local wob = (k % 2 == 0 and 1 or -1) * rng:NextNumber(1, 3)
			local x, z = a[2] + ux * t - uz * wob, a[3] + uz * t + ux * wob
			local yaw = math.atan2(-uz, ux) + (k % 2 == 0 and math.pi or 0)
			local sx = seg / 22
			-- (Studio r1: flat slabs floated on slopes) follow the ground along the piece: pitch from its two ends
			local h1 = ground(x - ux * seg * 0.5, z - uz * seg * 0.5); local h2 = ground(x + ux * seg * 0.5, z + uz * seg * 0.5)
			local hm = math.max((ground(x, z)), (h1 + h2) / 2)
			local m = put(k % 2 == 0 and "gmStreamB" or "gmStreamA", x, z, yaw, Vector3.new(sx, 1, rng:NextNumber(0.9, 1.15)), F.streams, 0, hm - 0.12)
			local pitch = math.atan2(h2 - h1, seg) * (k % 2 == 0 and -1 or 1)
			m:PivotTo(m:GetPivot() * CFrame.Angles(0, 0, pitch))
			m.Name = ("Trickle%d_%d"):format(li, k)
		end
	end
end

-- ------------------------------------------------------------ giants (landmark first) + their groves
for gi, g in GIANTS do
	local yaw = rng:NextNumber(0, math.pi * 2)
	put("gmGiant", g[1], g[2], yaw, g[3], F.giants, 0.8).Name = gi == 1 and "LandmarkGiant" or "Giant" .. gi
	claim(g[1], g[2], 13 * g[3])
end
for _, n in NESTS do
	put("gmNest", n[1], n[2], -math.pi / 2, 1, F.nests, 0.4).Name = "Nest"
	-- (Studio r1: ground the nests) a goo apron spilling out of the mouth (+X) and a film behind
	put("gmFilmA", n[1] + 15, n[2], math.pi / 2, Vector3.new(0.75, 1, 0.9), F.nests, 0.12)
	put("gmFilmB", n[1] - 12, n[2] + 4, 0.3, Vector3.new(0.9, 1, 1.0), F.nests, 0.12)
	claim(n[1], n[2], 21)   -- (geo r6 nest: 36 x 29)
end

local function scatter(kind, cx, cz, r0, r1, count, sMin, sMax, rad, parent, sink, tries)
	local placed = 0
	for _ = 1, (tries or 30) * count do
		if placed >= count then break end
		local a = rng:NextNumber(0, math.pi * 2); local r = rng:NextNumber(r0, r1)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local s = rng:NextNumber(sMin, sMax)
		if free(x, z, rad * s) then
			put(kind, x, z, rng:NextNumber(0, math.pi * 2), s, parent, sink)
			claim(x, z, rad * s); placed += 1
		end
	end
	return placed
end
local count = {}
local function add(k, n) count[k] = (count[k] or 0) + n end
for _, n in NESTS do   -- (Studio r1) offshoot blobs round the base, rocks + sprouts framing the mouth (not on the route)
	local G = Instance.new("Folder"); G.Name = "NestDressing"; G.Parent = F.nests
	add("gmBlobB", scatter("gmBlobB", n[1], n[2], 18, 24, 3, 0.7, 1.1, 3.2, G, 0.25))
	for _, side in { -1, 1 } do
		add("gmRockA", scatter("gmRockA", n[1] + 16, n[2] + side * 16, 0, 4, 1, 0.9, 1.4, 2.0, G, 0.4))
		add("gmSprout", scatter("gmSprout", n[1] + 13, n[2] + side * 19, 0, 5, 1, 0.9, 1.3, 1.6, G, 0.3))
	end
end
for _, g in GIANTS do   -- D4: each giant ringed by sprouts, blobs, a few rocks, an umbrella or two
	local G = Instance.new("Folder"); G.Name = "GiantGrove"; G.Parent = F.groves
	add("gmSprout", scatter("gmSprout", g[1], g[2], 9, 22, 6, 0.8, 1.4, 1.6, G, 0.3))   -- (r1 dry run: 301k tris -> trimmed)
	add("gmBlobB", scatter("gmBlobB", g[1], g[2], 8, 18, 2, 0.8, 1.2, 3.2, G, 0.25))
	add("gmBlobA", scatter("gmBlobA", g[1], g[2], 10, 20, 2, 0.8, 1.1, 4.2, G, 0.25))
	add("gmRockA", scatter("gmRockA", g[1], g[2], 10, 22, 2, 0.9, 1.5, 2.0, G, 0.4))
	add("gmUmbrella", scatter("gmUmbrella", g[1], g[2], 18, 30, 2, 0.85, 1.15, 6.5, G, 0.3))
	add("gmTrumpet", scatter("gmTrumpet", g[1], g[2], 16, 28, 1, 0.9, 1.2, 5.5, G, 0.3))
end

-- ------------------------------------------------------------ wall groves (west, north, south cliff feet)
local function wallFoot(x, z, dx, dz)   -- walk toward the wall until the ground rises 5 over the start; step back 4
	local y0 = ground(x, z)
	for d = 0, 140, 3 do
		if ground(x + dx * d, z + dz * d) > y0 + 5 then return x + dx * (d - 4), z + dz * (d - 4) end
	end
	return x + dx * 140, z + dz * 140
end
local WALL = {}
for z = -270, 270, 54 do local x, zz = wallFoot(-760, z, -1, 0); table.insert(WALL, { x, zz, 1, 0 }) end   -- west (+X out)
for x = -770, -590, 60 do local xx, z = wallFoot(x, -240, 0, -1); table.insert(WALL, { xx, z, 0, 1 }) end   -- north
for x = -770, -590, 60 do local xx, z = wallFoot(x, 250, 0, 1); table.insert(WALL, { xx, z, 0, -1 }) end    -- south
for wi, w in WALL do
	local G = Instance.new("Folder"); G.Name = "WallGrove"; G.Parent = F.groves
	local cx, cz = w[1] + w[3] * 10, w[2] + w[4] * 10
	add("gmTrumpet", scatter("gmTrumpet", cx, cz, 0, 14, wi % 3 == 0 and 2 or 1, 0.85, 1.25, 5.5, G, 0.3))
	add("gmUmbrella", scatter("gmUmbrella", cx, cz, 4, 18, 1, 0.8, 1.2, 6.5, G, 0.3))
	add("gmSprout", scatter("gmSprout", cx, cz, 0, 16, 2, 0.8, 1.5, 1.6, G, 0.3))
	add("gmRockB", scatter("gmRockB", w[1], w[2], 0, 10, 2, 0.8, 1.4, 3.4, G, 0.5))
	add("gmBlobB", scatter("gmBlobB", cx, cz, 2, 16, 1, 0.8, 1.2, 3.2, G, 0.25))
	task.wait()
end

-- ------------------------------------------------------------ pool rims: dark rock clumps + blobs (D4)
for _, p in POOLS do
	local R = poolR(p)
	add("gmRockC", scatter("gmRockC", p[2], p[3], R + 2, R + 9, 1, 0.8, 1.2, 4.2, F.rocks, 0.5))
	add("gmRockB", scatter("gmRockB", p[2], p[3], R + 1, R + 8, 1, 0.7, 1.2, 3.4, F.rocks, 0.5))
	add("gmRockA", scatter("gmRockA", p[2], p[3], R, R + 7, 3, 0.8, 1.6, 2.0, F.rocks, 0.4))
	add("gmBlobA", scatter("gmBlobA", p[2], p[3], R + 1, R + 6, 1, 0.7, 1.0, 4.2, F.rocks, 0.25))
	add("gmBlobB", scatter("gmBlobB", p[2], p[3], R, R + 6, 1, 0.7, 1.1, 3.2, F.rocks, 0.25))
	add("gmSprout", scatter("gmSprout", p[2], p[3], R + 2, R + 10, 1, 0.8, 1.2, 1.6, F.rocks, 0.3))
end

-- ------------------------------------------------------------ DNA crystal veins + goo drapes at the cliff feet
local VEINS = { { -760, -250, -1, 0 }, { -760, -125, -1, 0 }, { -760, 25, -1, 0 }, { -760, 195, -1, 0 },
	{ -700, -240, 0, -1 }, { -600, -240, 0, -1 }, { -650, 250, 0, 1 }, { -565, 250, 0, 1 } }
for _, v in VEINS do
	local x, z = wallFoot(v[1], v[2], v[3], v[4])
	for _ = 1, 12 do
		if free(x, z, 5) then break end
		x, z = x - v[3] * 3 + rng:NextNumber(-4, 4), z - v[4] * 3 + rng:NextNumber(-4, 4)
	end
	local yaw = math.atan2(v[3], v[4])                    -- crystals lean out of the wall
	put("gmVein", x, z, yaw, rng:NextNumber(0.95, 1.2), F.veins, 0.5); claim(x, z, 5); add("gmVein", 1)
end
local DRAPES = { { -760, -200, -1, 0 }, { -760, -35, -1, 0 }, { -760, 100, -1, 0 }, { -760, 262, -1, 0 }, { -660, -240, 0, -1 } }
for _, d in DRAPES do
	local x, z = wallFoot(d[1], d[2], d[3], d[4])
	-- (Studio r1: the drape stood free) a horizontal ray 3 studs up finds the cliff face; the drape foot goes 1 stud off it
	local gy = ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x - d[3] * 20, gy + 3, z - d[4] * 20), Vector3.new(d[3] * 80, 0, d[4] * 80), rp)
	if hit then x, z = hit.Position.X - d[3] * 1, hit.Position.Z - d[4] * 1 else x, z = x + d[3] * 3, z + d[4] * 3 end
	-- local +Z (Blender +Y) runs into the wall: yaw maps +Z onto the wall direction
	local yaw = math.atan2(d[3], d[4])
	put("gmDrape", x, z, yaw, rng:NextNumber(1.1, 1.5), F.drapes, 0.3); add("gmDrape", 1)
end

-- ------------------------------------------------------------ open-floor fill: blobs, sprouts, a few mushrooms, films
local function fill(kind, n, rad, sMin, sMax, parent, sink)
	local c = 0
	for _ = 1, n * 40 do
		if c >= n then break end
		local x, z = rng:NextNumber(-815, -555), rng:NextNumber(-300, 300)
		local s = rng:NextNumber(sMin, sMax)
		if free(x, z, rad * s) then put(kind, x, z, rng:NextNumber(0, math.pi * 2), s, parent, sink); claim(x, z, rad * s); c += 1 end
	end
	add(kind, c)
end
local OPEN = folder("Floor")
fill("gmUmbrella", 4, 6.5, 0.8, 1.15, OPEN, 0.3)
fill("gmTrumpet", 4, 5.5, 0.85, 1.2, OPEN, 0.3)
fill("gmBlobA", 6, 4.2, 0.7, 1.1, OPEN, 0.25)
fill("gmBlobB", 6, 3.2, 0.7, 1.2, OPEN, 0.25)
fill("gmSprout", 4, 1.6, 0.8, 1.4, OPEN, 0.3)
fill("gmRockB", 3, 3.4, 0.8, 1.4, OPEN, 0.5)
-- (Studio r1: the middle felt underdressed) mid-ground punctuation between the entrance and the deeper pools
local function fillMid(kind, n, rad, sMin, sMax, sink)
	local c = 0
	for _ = 1, n * 60 do
		if c >= n then break end
		local x, z = rng:NextNumber(-705, -560), rng:NextNumber(-230, 230)
		local s = rng:NextNumber(sMin, sMax)
		if free(x, z, rad * s) then put(kind, x, z, rng:NextNumber(0, math.pi * 2), s, OPEN, sink); claim(x, z, rad * s); c += 1 end
	end
	add(kind, c)
end
fillMid("gmRockB", 5, 3.4, 0.8, 1.3, 0.5); fillMid("gmRockA", 4, 2.0, 1.0, 1.6, 0.4)
fillMid("gmSprout", 6, 1.6, 0.9, 1.4, 0.3); fillMid("gmBlobB", 4, 3.2, 0.8, 1.2, 0.25)
fillMid("gmUmbrella", 2, 6.5, 0.8, 1.0, 0.3); fillMid("gmTrumpet", 2, 5.5, 0.8, 1.0, 0.3)
-- goo films (audit fix 2: 10-14 patches 20-40 long): beside the trickles + pools, may run up to a route edge
local films = 0
for _ = 1, 400 do
	if films >= 12 then break end
	local p = POOLS[rng:NextInteger(1, #POOLS)]
	local a = rng:NextNumber(0, math.pi * 2); local r = poolR(p) + rng:NextNumber(4, 18)
	local x, z = p[2] + math.cos(a) * r, p[3] + math.sin(a) * r
	local s = rng:NextNumber(0.8, 1.25)
	if free(x, z, 9 * s) then
		-- (Studio r1) tilt the film to the ground: slopes from 4 samples 10 studs out
		local hx1, hx2 = ground(x - 10, z), ground(x + 10, z); local hz1, hz2 = ground(x, z - 10), ground(x, z + 10)
		local hc = math.max((ground(x, z)), (hx1 + hx2 + hz1 + hz2) / 4)
		local m = put(films % 2 == 0 and "gmFilmA" or "gmFilmB", x, z, a + math.pi / 2 + rng:NextNumber(-0.4, 0.4), Vector3.new(s, 1, s), F.streams, 0, hc - 0.08)
		local tilt = CFrame.Angles(-math.atan2(hz2 - hz1, 20), 0, math.atan2(hx2 - hx1, 20))   -- (+Z / +X ends rise with the ground)
		m:PivotTo(CFrame.new(m:GetPivot().Position) * tilt * m:GetPivot().Rotation)
		claim(x, z, 9 * s); films += 1
	end
end
add("gmFilm", films)

-- ------------------------------------------------------------ darker damp floor in patches (Studio r1 fix: "the single
-- best match-to-D fix"). "MarshDust" = the MoonCraterDust textures on Mud, tinted cool charcoal; painted where goo
-- gathers (pool banks, under the giants, round the nests, below the drapes, along the trickles) with noise-broken
-- edges; walking routes stay lighter. Only Ground voxels change (the cliffs are Rock).
local MS = game:GetService("MaterialService")
local dust = MS:FindFirstChild("MoonCraterDust")
if dust and not MS:FindFirstChild("MarshDust") then
	local v = dust:Clone(); v.Name = "MarshDust"; v.BaseMaterial = Enum.Material.Mud; v.Parent = MS
end
pcall(function() MS:SetBaseMaterialOverride(Enum.Material.Mud, "MarshDust") end)
T:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(150, 147, 166))   -- (r2: 96,94,110 read as black mud)
local spots = {}
for _, p in POOLS do table.insert(spots, { p[2], p[3], poolR(p) + 10, 10 }) end
for _, g in GIANTS do table.insert(spots, { g[1], g[2], 26 * g[3], 10 }) end
for _, n in NESTS do table.insert(spots, { n[1], n[2], 25, 9 }) end
for _, d in F.drapes:GetChildren() do local p = d:GetPivot().Position; table.insert(spots, { p.X, p.Z, 14, 8 }) end
local reg = Region3.new(Vector3.new(-860, -20, -360), Vector3.new(-460, 40, 360))
local mats, occs = T:ReadVoxels(reg, 4)
local painted = 0
for xi = 1, mats.Size.X do
	local x = -860 + (xi - 0.5) * 4
	for zi = 1, mats.Size.Z do
		local z = -360 + (zi - 0.5) * 4
		local score = 0
		for _, sp in spots do
			local d = math.sqrt((x - sp[1]) ^ 2 + (z - sp[2]) ^ 2)
			score = math.max(score, math.clamp(1 - (d - sp[3]) / sp[4], 0, 1))
		end
		for _, l in LINKS do
			local a, b = POOLS[l[1]], POOLS[l[2]]
			score = math.max(score, math.clamp(1 - (distSeg(x, z, { a[2], a[3] }, { b[2], b[3] }) - 6) / 6, 0, 1))
		end
		if onRoute(x, z, -2) then score *= 0.35 end
		score += 0.45 * math.noise(x / 23, z / 23, 4.2)
		if score > 0.5 then
			for yi = 1, mats.Size.Y do
				if mats[xi][yi][zi] == Enum.Material.Ground then mats[xi][yi][zi] = Enum.Material.Mud; painted += 1 end
			end
		end
	end
end
T:WriteVoxels(reg, 4, mats, occs)
count.paintedVoxels = painted
-- (r2) the ReadVoxels/WriteVoxels round trip lifts the ground ~0.2: re-seat every pool AFTER painting, sheet 0.3 over
-- the highest point inside it
for i, p in POOLS do
	local R = poolR(p); local top = -1e9
	for k = 0, 35 do
		local a = k / 36 * math.pi * 2
		for _, f in { 0, 0.3, 0.55, 0.75 } do top = math.max(top, (ground(p[2] + math.cos(a) * R * f, p[3] + math.sin(a) * R * f))) end
	end
	local m = F.pools["Pool" .. i]; local pv = m:GetPivot()
	m:PivotTo(pv + Vector3.new(0, top - pv.Position.Y, 0))
end

root.Parent = hub
local out = {}
for k, v in count do table.insert(out, k .. "=" .. v) end
table.sort(out)
return ("parts %d, approx tris %d | %s"):format(stats.parts, stats.tris, table.concat(out, " "))
