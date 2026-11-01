-- Alien Fusion hub: lay out the CRYSTAL CANYON (east biome, X 490..830, Z -330..330, north = -Z), 31 Oct 2026.
-- Kit: ServerStorage.HubKit.CrystalCanyon (hub-crystalcanyon-kit.luau). References: design\concepts\hub\E (look), E2b
-- (sizes), E3 (materials), E4 (mood map) + ChatGPT's corrected coordinates (design\map-review\crystal-canyon\
-- E4-layout-reply.txt): carve link A (south channel -> entrance) and link B (east join = a loop), two nest alcoves,
-- mining bays; spire on the plateau nose; veins in wall bays; columns on the walls; seams flush on the floors.
-- Terrain backup first (ServerStorage.CanyonTerrainBackup; restore = T:PasteRegion(tr, tr:GetAttribute("CornerVoxel"), true)).
-- Everything raycast-seated AFTER the carve + paint passes. Output: workspace.Hub.CrystalCanyon. Re-runnable: the
-- terrain is restored from the backup first, then re-carved.
local K = game.ServerStorage.HubKit.CrystalCanyon
local hub = workspace.Hub
local old = hub:FindFirstChild("CrystalCanyon"); if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "CrystalCanyon"
local T = workspace.Terrain
local rng = Random.new(3110)
local SAND, ROCK = Enum.Material.Sandstone, Enum.Material.Basalt

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rp)
	return h and h.Position.Y or 0, h and h.Material or Enum.Material.Air, h and h.Normal or Vector3.yAxis
end

-- ------------------------------------------------------------ channels + routes (Roblox x, z; measured 31 Oct)
local NORTH = { { 492, -95 }, { 520, -88 }, { 540, -104 }, { 560, -115 }, { 580, -121 }, { 600, -124 }, { 620, -121 },
	{ 640, -116 }, { 660, -106 }, { 680, -93 }, { 700, -78 }, { 720, -62 }, { 740, -46 }, { 760, -32 }, { 780, -21 }, { 800, -14 } }
local SOUTH = { { 492, 100 }, { 512, 100 }, { 545, 100 }, { 580, 101 }, { 600, 117 }, { 620, 134 }, { 640, 145 }, { 660, 154 },
	{ 680, 157 }, { 700, 153 }, { 720, 144 }, { 740, 134 }, { 760, 118 }, { 780, 101 }, { 800, 87 }, { 815, 73 }, { 820, 76 }, { 840, 66 } }
local LINK_A = { { 500, 100 }, { 545, 100 }, { 580, 101 }, { 596, 112 } }
local LINK_B = { { 800, -14 }, { 805, -15 }, { 798, 15 }, { 803, 42 }, { 815, 73 } }
-- (Studio audit r1 fix 2: the north nest sat in a deep pit) nests moved 7-8 studs toward their channel; their bowls now
-- open straight onto the widened floor through a 32-wide approach (no front lip), so 65-75 % of the front shows
local NEST_N, NEST_S, NEST_U = { 645, -152 }, { 685, 189 }, { 750, -235 }
local SPUR_N = { { 641, -114 }, { 645, -136 } }
local SPUR_S = { { 682, 156 }, { 685, 172 } }
local ROUTES = { NORTH, SOUTH, LINK_B, SPUR_N, SPUR_S,
	{ { 500, 280 }, { 600, 280 }, { 640, 250 } },          -- the plateau ramp onto the south plateau
	{ { 640, -335 }, { 640, -290 }, { 700, -260 }, { 735, -245 } },   -- north pass -> upper nest
	{ { 640, 335 }, { 640, 290 }, { 620, 250 } },          -- south pass
	{ { 492, -330 }, { 492, 330 } },                        -- the entrance strip
}

-- ------------------------------------------------------------ geometry helpers
local function distSeg(px, pz, a, b)
	local ax, az, bx, bz = a[1], a[2], b[1], b[2]
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((px - ax - t * dx) ^ 2 + (pz - az - t * dz) ^ 2), t
end
local function onRoute(x, z, r)
	for _, rt in ROUTES do
		for i = 1, #rt - 1 do if distSeg(x, z, rt[i], rt[i + 1]) < 9 + r then return true end end
	end
	return false
end
local function nearestOn(path, x, z)   -- nearest point + direction on a polyline
	local best, bp, bd = 1e9, nil, nil
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local d, t = distSeg(x, z, a, b)
		if d < best then
			best = d; bp = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t }
			local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2); bd = { (b[1] - a[1]) / L, (b[2] - a[2]) / L }
		end
	end
	return bp, bd, best
end
local function nearestChannel(x, z)
	local p1, d1, b1 = nearestOn(NORTH, x, z); local p2, d2, b2 = nearestOn(SOUTH, x, z); local p3, d3, b3 = nearestOn(LINK_B, x, z)
	if b1 <= b2 and b1 <= b3 then return p1, d1, b1 elseif b2 <= b3 then return p2, d2, b2 end
	return p3, d3, b3
end
local function yawFacing(dx, dz) return math.atan2(-dx, -dz) end   -- local -Z (the kit front) -> (dx, dz)
local function face(x, z, tx, tz) local dx, dz = tx - x, tz - z; local L = math.sqrt(dx * dx + dz * dz); return yawFacing(dx / L, dz / L) end

-- ------------------------------------------------------------ terrain: backup / restore, carve, paint
local store = game.ServerStorage
local LO, HI = Vector3int16.new(120, -10, -90), Vector3int16.new(215, 25, 90)   -- voxels: X 480..864, Y -40..104, Z -360..364
local bk = store:FindFirstChild("CanyonTerrainBackup")
if not bk then
	bk = T:CopyRegion(Region3int16.new(LO, HI)); bk.Name = "CanyonTerrainBackup"
	bk:SetAttribute("CornerVoxel", Vector3.new(LO.X, LO.Y, LO.Z)); bk.Parent = store
else
	T:PasteRegion(bk, LO, true)                            -- re-run: start from the untouched canyon
end
task.wait()
local function floorY(x, z)   -- the channel floor near a point (lowest ground within 14)
	local lo = 1e9
	for _, o in { { 0, 0 }, { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 }, { 12, 0 }, { -12, 0 }, { 0, 12 }, { 0, -12 } } do lo = math.min(lo, (ground(x + o[1], z + o[2]))) end
	return lo
end
local function carvePath(path, W, fy0, fy1)
	-- stepped walls (3 tiers ~ a 45-60 deg slope) + a sand floor; fy eases from fy0 to fy1 along the path
	local total, segs = 0, {}
	for i = 1, #path - 1 do local a, b = path[i], path[i + 1]; local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2); table.insert(segs, L); total += L end
	local s = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]; local L = segs[i]
		local dx, dz = (b[1] - a[1]) / L, (b[2] - a[2]) / L
		local yaw = math.atan2(-dz, dx)
		for d = 0, L, 2 do
			local x, z = a[1] + dx * d, a[2] + dz * d
			local f = (s + d) / total; local fy = fy0 + (fy1 - fy0) * (f * f * (3 - 2 * f))
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
			T:FillBlock(cf + Vector3.new(0, fy + 45, 0), Vector3.new(4, 90, W), Enum.Material.Air)
			T:FillBlock(cf + Vector3.new(0, fy + 8 + 45, 0), Vector3.new(4, 90, W + 10), Enum.Material.Air)
			T:FillBlock(cf + Vector3.new(0, fy + 16 + 45, 0), Vector3.new(4, 90, W + 22), Enum.Material.Air)
			T:FillBlock(cf + Vector3.new(0, fy - 4, 0), Vector3.new(4, 8, W), SAND)
		end
		s += L
		task.wait()
	end
end
local function carveBowl(x, z, R, fy)
	T:FillCylinder(CFrame.new(x, fy + 40, z), 80, R, Enum.Material.Air)
	T:FillCylinder(CFrame.new(x, fy + 8 + 40, z), 80, R + 5, Enum.Material.Air)
	T:FillCylinder(CFrame.new(x, fy + 16 + 40, z), 80, R + 11, Enum.Material.Air)
	T:FillCylinder(CFrame.new(x, fy - 4, z), 8, R, SAND)
end
-- (spec audit r1 fix 2) widen the existing channels: 28 wide floor, 32 at bends, each point at its own (smoothed) floor
local function carveChannel(path, W)
	local pts = {}
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2); local dx, dz = (b[1] - a[1]) / L, (b[2] - a[2]) / L
		local turn = 0
		if path[i + 2] then local c = path[i + 2]; local L2 = math.sqrt((c[1] - b[1]) ^ 2 + (c[2] - b[2]) ^ 2); turn = math.acos(math.clamp(dx * (c[1] - b[1]) / L2 + dz * (c[2] - b[2]) / L2, -1, 1)) end
		for d = 0, L - 0.01, 2 do
			table.insert(pts, { x = a[1] + dx * d, z = a[2] + dz * d, yaw = math.atan2(-dz, dx), w = W + (turn > math.rad(22) and d > L - 14 and 4 or 0) })
		end
	end
	for _, p in pts do p.fy = floorY(p.x, p.z) end
	for i, p in pts do   -- smooth the floor along the path (5-point mean) so the widened floor has no steps
		local s, n = 0, 0
		for j = math.max(1, i - 2), math.min(#pts, i + 2) do s += pts[j].fy; n += 1 end
		p.sfy = s / n
	end
	for k, p in pts do
		local cf = CFrame.new(p.x, 0, p.z) * CFrame.Angles(0, p.yaw, 0)
		T:FillBlock(cf + Vector3.new(0, p.sfy + 45, 0), Vector3.new(4, 90, p.w), Enum.Material.Air)
		T:FillBlock(cf + Vector3.new(0, p.sfy + 8 + 45, 0), Vector3.new(4, 90, p.w + 10), Enum.Material.Air)
		T:FillBlock(cf + Vector3.new(0, p.sfy + 16 + 45, 0), Vector3.new(4, 90, p.w + 22), Enum.Material.Air)
		T:FillBlock(cf + Vector3.new(0, p.sfy - 4, 0), Vector3.new(4, 8, p.w), SAND)
		if k % 20 == 0 then task.wait() end
	end
end
carveChannel(NORTH, 28)
carveChannel(SOUTH, 28)
-- (fix 1) a level foundation for the landmark on the plateau nose (30 x 28): the median plateau height, bumps cut off
local SPIRE_X, SPIRE_Z = 580, -10
local hs = {}
for k = 0, 11 do local a = k / 12 * math.pi * 2; table.insert(hs, (ground(SPIRE_X + math.cos(a) * 13, SPIRE_Z + math.sin(a) * 13))) end
table.insert(hs, (ground(SPIRE_X, SPIRE_Z))); table.sort(hs)
local SPIRE_Y = hs[7]
local SPIRE_S = _G.CC_SPIRE_SCALE or 1.5   -- (Studio audit r1 fix 1: 1.1 read as another cluster from the plots; ~80 tall)
T:FillCylinder(CFrame.new(SPIRE_X, SPIRE_Y + 15, SPIRE_Z), 30, 14.5 * SPIRE_S, Enum.Material.Air)
T:FillCylinder(CFrame.new(SPIRE_X, SPIRE_Y - 5, SPIRE_Z), 10, 14.5 * SPIRE_S, ROCK)
local fyA0, fyA1 = (ground(495, 100)), floorY(596, 112)
carvePath(LINK_A, 24, fyA0, fyA1)
local fyB0, fyB1 = floorY(800, -14), floorY(818, 76)
carvePath(LINK_B, 24, fyB0, fyB1)
local fyN = floorY(640, -116); carveBowl(NEST_N[1], NEST_N[2], 24, fyN); carvePath(SPUR_N, 32, fyN, fyN)
local fyS = floorY(680, 157); carveBowl(NEST_S[1], NEST_S[2], 24, fyS); carvePath(SPUR_S, 32, fyS, fyS)
local VEINS = { -- {x, z, floor bay?}
	{ 552, -84, true }, { 625, -95, true }, { 739, -10, true }, { 611, 106, true }, { 721, 108, true }, { 795, 124, true },
	{ 640, -272, false }, { 718, 245, false } }
for _, v in VEINS do
	if v[3] then
		local p = nearestChannel(v[1], v[2]); local fy = floorY(p[1], p[2])
		carveBowl(v[1], v[2], 8, fy); carvePath({ p, { v[1], v[2] } }, 14, fy, fy)
	end
end
task.wait()
-- paint (zone only, a noisy west edge): channel Sand / Ground -> Sandstone ("CanyonFloor"), plateau Rock -> Basalt
local MS = game:GetService("MaterialService")
local reg = MS:FindFirstChild("MoonRegolith")
if reg and not MS:FindFirstChild("CanyonFloor") then
	local v = reg:Clone(); v.Name = "CanyonFloor"; v.BaseMaterial = SAND; v.Parent = MS
end
pcall(function() MS:SetBaseMaterialOverride(SAND, "CanyonFloor") end)
T:SetMaterialColor(SAND, _G.CC_SAND or Color3.fromRGB(206, 196, 184))   -- E3 #6 warm GREY (Studio r0: 196,182,162 read orange-tan beside the plain)
local painted = 0
for x0 = 480, 860, 64 do
	local r3 = Region3.new(Vector3.new(x0, -40, -360), Vector3.new(math.min(x0 + 64, 864), 104, 364))
	local mats, occs = T:ReadVoxels(r3, 4)
	for xi = 1, mats.Size.X do
		local x = x0 + (xi - 0.5) * 4
		for zi = 1, mats.Size.Z do
			local z = -360 + (zi - 0.5) * 4
			local edge = 500 + 14 * math.noise(z / 37, 2.7) + 6 * math.noise(z / 11, 7.1)
			-- (Studio r0: a hard straight paint line) a 40-stud dithered blend band: the chance of canyon floor rises across it
			local blend = math.clamp((x - edge) / 40, 0, 1)
			local dither = 0.5 + 0.5 * math.noise(x / 7.3, z / 7.3, 1.9)
			-- (Studio r1: white regolith blotches left on the entrance walls) the dither only applies to the flat floor
			-- (y < 10); anything higher inside the edge is always canyon (walls, plateau, the pass tops)
			if x > edge - 6 and math.abs(z) < 345 + 10 * math.noise(x / 29, 3.3) then
				for yi = 1, mats.Size.Y do
					local y = -40 + (yi - 0.5) * 4
					local m = mats[xi][yi][zi]
					if (m == Enum.Material.Sand or m == Enum.Material.Ground) and not (y < 10 and blend <= dither) then mats[xi][yi][zi] = SAND; painted += 1
					elseif m == Enum.Material.Rock then mats[xi][yi][zi] = ROCK; painted += 1 end
				end
			end
		end
	end
	T:WriteVoxels(r3, 4, mats, occs)
	task.wait()
end

-- ------------------------------------------------------------ occupancy + spawning
local occ = {}
local function free(x, z, r, allowRoute)
	if x < 494 or x > 845 or z < -335 or z > 335 then return false end
	if not allowRoute and onRoute(x, z, r) then return false end
	for _, o in occ do if (x - o[1]) ^ 2 + (z - o[2]) ^ 2 < (r + o[3]) ^ 2 then return false end end
	return true
end
local function claim(x, z, r) table.insert(occ, { x, z, r }) end
local LOOK = {   -- name fragment -> collide, castShadow
	Crystal = { false, false }, Rock = { true, true }, Column = { true, true }, Boulder = { true, true }, Gravel = { false, false },
	Tunnel = { false, false }, Seam = { false, false }, Arch = { true, true },
}
local function look(name)
	if name:find("Crystal") then return LOOK.Crystal end
	for k, v in LOOK do if name:find(k) then return v end end
	return { false, true }
end
local stats = { tris = 0, parts = 0 }
local TRIS = { ccSpire = 6328, ccClusterL = 1475, ccClusterS = 774, ccShards = 654, ccColumnA = 1200, ccColumnB = 956,
	ccBoulderA = 320, ccBoulderB = 480, ccBoulderC = 699, ccVein = 1392, ccNest = 4781, ccSeamA = 1100, ccSeamB = 1100, ccArch = 2852 }
local SET = {
	ccSpire = { "ccSpireRock", "ccSpireCrystal" }, ccClusterL = { "ccClusterLRock", "ccClusterLCrystal" },
	ccClusterS = { "ccClusterSRock", "ccClusterSCrystal" }, ccShards = { "ccShardsCrystal", "ccShardsGravel" },
	ccVein = { "ccVeinRock", "ccVeinCrystal" }, ccNest = { "ccNestRock", "ccNestTunnel", "ccNestCrystal" },
	ccArch = { "ccArch", "ccArchCrystal" },
}
local function seatY(x, z, r)   -- a contact height from 9 samples under the footprint (spec audit r1 fix 1): a quarter of
	-- the way from the lowest to the median = shallow burial on slopes, no floating corners
	local hs = { (ground(x, z)) }
	for k = 0, 7 do local a = k / 8 * math.pi * 2; table.insert(hs, (ground(x + math.cos(a) * r, z + math.sin(a) * r))) end
	table.sort(hs)
	return hs[1] + 0.1 * (hs[5] - hs[1])   -- (Studio r0: 0.25 left small crystals hovering on steep walls)
end
local function put(kind, x, z, yaw, s, parent, sink, yOverride, seatR)
	local sv = typeof(s) == "Vector3" and s or Vector3.new(s, s, s)
	local gy = yOverride or ((seatR and seatY(x, z, seatR) or (ground(x, z))) - (sink or 0.3))
	local base = CFrame.new(x, gy, z) * CFrame.Angles(0, yaw, 0)
	local m = Instance.new("Model"); m.Name = kind
	for _, n in SET[kind] or { kind } do
		local src = K:FindFirstChild(n)
		if src then
			local p = src:Clone(); local lk = look(n)
			p.Anchored, p.CanTouch = true, false
			p.CanCollide, p.CanQuery, p.CastShadow = lk[1], lk[1], lk[2]
			p.Size = p.Size * sv
			p.CFrame = base * CFrame.new(src:GetAttribute("C") * sv)
			p.Parent = m; stats.parts += 1
		end
	end
	m.WorldPivot = base
	pcall(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
	m:SetAttribute("Biome", "CrystalCanyon")
	m.Parent = parent
	stats.tris += TRIS[kind] or 0
	return m
end
local function folder(name) local f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f end
local F = { landmark = folder("Landmark"), nests = folder("Nests"), veins = folder("Veins"), arch = folder("Arch"),
	columns = folder("Columns"), seams = folder("Seams"), crystals = folder("Crystals"), rocks = folder("Rocks") }
local count = {}
local function add(k, n) count[k] = (count[k] or 0) + (n or 1) end

-- ------------------------------------------------------------ landmark, nests, arch, veins
put("ccSpire", SPIRE_X, SPIRE_Z, yawFacing(-1, 0), SPIRE_S, F.landmark, 0, SPIRE_Y - 3.0).Name = "LandmarkSpire"   -- (Blender r2 note 3: base buried 3)
claim(580, -10, 17 * SPIRE_S)
-- (E6 #1) the spire grows out of stacked basalt COLUMNS: low column outcrops banked against its rock base
for k, c in { { 16, 200, 0.55 }, { 15, 300, 0.7 }, { 17, 40, 0.5 }, { 14, 120, 0.6 } } do
	local a = math.rad(c[2]); local x, z = 580 + math.cos(a) * c[1] * SPIRE_S / 1.1, -10 + math.sin(a) * c[1] * SPIRE_S / 1.1
	put(k % 2 == 0 and "ccColumnA" or "ccColumnB", x, z, face(x, z, 580, -10) + math.pi, c[3], F.landmark, 1.2, nil, 6)
end
put("ccNest", NEST_N[1], NEST_N[2], face(NEST_N[1], NEST_N[2], SPUR_N[1][1], SPUR_N[1][2]), 1, F.nests, 0.2).Name = "NestNorth"
put("ccNest", NEST_S[1], NEST_S[2], face(NEST_S[1], NEST_S[2], SPUR_S[1][1], SPUR_S[1][2]), 1, F.nests, 0.2).Name = "NestSouth"
put("ccNest", NEST_U[1], NEST_U[2], face(NEST_U[1], NEST_U[2], 700, -260), 1, F.nests, 0.6, nil, 12).Name = "NestUpper"
for _, n in { NEST_N, NEST_S, NEST_U } do claim(n[1], n[2], 20) end
do   -- the arch spans the north channel at (705, -77): its length (local X) across the channel
	local p, d = nearestOn(NORTH, 705, -77)
	local px, pz = -d[2], d[1]
	local fy = floorY(p[1], p[2])
	-- (spec audit r1 fix 1) seat from BOTH banks: the deck (kit top ~14.5 x 1.7 = 24.6) meets the lower bank top, the
	-- piers stay on the floor, headroom (opening 9.2 x 1.7 = 15.6) >= 12 over the walking floor
	local h1 = ground(p[1] + px * 31, p[2] + pz * 31); local h2 = ground(p[1] - px * 31, p[2] - pz * 31)
	local by = math.clamp(math.min(h1, h2) - 24.1, fy - 1.5, fy + 2)
	local S = Vector3.new(1.35, 1.7, 1.2)
	local m = put("ccArch", p[1], p[2], math.atan2(-pz, px), S, F.arch, 0, by)
	m.Name = "ArchBridge"; claim(p[1] + px * 26, p[2] + pz * 26, 8); claim(p[1] - px * 26, p[2] - pz * 26, 8)
	m:SetAttribute("Headroom", by + 15.6 - fy); m:SetAttribute("BankH1", h1); m:SetAttribute("BankH2", h2)
	-- simple invisible collision (fix D): deck slab + two piers; the detailed mesh does not collide
	for _, part in m:GetChildren() do if part:IsA("BasePart") then part.CanCollide = false end end
	local base = m:GetPivot()
	for _, c in { { Vector3.new(0, 24.0, 0), Vector3.new(58, 1.2, 10) }, { Vector3.new(23.5, 7.5, 0), Vector3.new(11, 15, 11) },
		{ Vector3.new(-23.5, 7.5, 0), Vector3.new(11, 15, 11) } } do
		local cp = Instance.new("Part"); cp.Name = "ArchCollision"; cp.Anchored = true; cp.Transparency = 1; cp.CastShadow = false
		cp.CanQuery = false; cp.CanTouch = false; cp.Size = c[2]; cp.CFrame = base * CFrame.new(c[1]); cp.Parent = m
	end
end
for i, v in VEINS do
	local yaw
	if v[3] then local p = nearestChannel(v[1], v[2]); yaw = face(v[1], v[2], p[1], p[2]) else yaw = rng:NextNumber(0, math.pi * 2) end
	local vm = put("ccVein", v[1], v[2], yaw, rng:NextNumber(1.0, 1.15), F.veins, 0.4, nil, 3); vm.Name = "AmberVein" .. i
	for _, part in vm:GetChildren() do part.CanQuery = true end   -- (fix D) mining raycasts must hit the vein crystals
	vm:SetAttribute("Resource", "CrunchDNA")
	claim(v[1], v[2], 6); add("ccVein")
end

-- ------------------------------------------------------------ column outcrops on the walls (E4 C1-C10) + extras
local COLS = { { 556, -150 }, { 615, -159 }, { 672, -128 }, { 743, -91 }, { 802, -55 }, { 598, 160 }, { 635, 186 },
	{ 728, 189 }, { 770, 69 }, { 822, 115 } }
for i, c in COLS do
	local p = nearestChannel(c[1], c[2])
	local kind = i % 3 == 0 and "ccColumnB" or "ccColumnA"
	-- (Blender r2 note 2) repeated outcrops turned 20-60 deg off the channel, scale +-15 %, buried 1.5-3 into the wall
	put(kind, c[1], c[2], face(c[1], c[2], p[1], p[2]) + (i % 2 == 0 and 1 or -1) * rng:NextNumber(0.35, 1.05), rng:NextNumber(0.85, 1.15), F.columns, rng:NextNumber(1.5, 3), nil, 6)
	claim(c[1], c[2], 8); add(kind)
end

-- ------------------------------------------------------------ magma seam plates M1-M12 (flush, tilted to the ground)
local SEAMS = { { 535, -98 }, { 580, -120 }, { 625, -121 }, { 665, -101 }, { 715, -66 }, { 790, -16 }, { 586, 108 }, { 630, 142 },
	{ 675, 155 }, { 725, 144 }, { 780, 103 }, { 827, 70 } }
local seamList = {}
for i, s in SEAMS do
	local p, d = nearestChannel(s[1], s[2])
	-- (Studio r0: after the widening some E4 points sat on the wall slope) snap onto the channel floor, a little off-centre
	local o = rng:NextNumber(-5, 5); s = { p[1] - d[2] * o, p[2] + d[1] * o }
	local yaw = math.atan2(-d[2], d[1]) + rng:NextNumber(-0.45, 0.45) + (i % 4 == 0 and math.pi / 2 * 0.6 or 0)
	-- (Studio audit r1 fix 3) fit a plane: ends along local X (pitch) + sides along local Z (roll), centre = the mean of
	-- the 5 samples, buried 0.5; where the ground bends (centre far off the plane) use the short plate
	local ax, az = math.cos(yaw), -math.sin(yaw)       -- local X in world (x, z)
	local zx, zz = math.sin(yaw), math.cos(yaw)        -- local Z in world
	local bend = false
	local L, W = 10, 3
	local function fit()
		local hx1, hx2 = ground(s[1] - ax * L, s[2] - az * L), ground(s[1] + ax * L, s[2] + az * L)
		local hz1, hz2 = ground(s[1] - zx * W, s[2] - zz * W), ground(s[1] + zx * W, s[2] + zz * W)
		local hc = ground(s[1], s[2])
		return hx1, hx2, hz1, hz2, hc
	end
	local hx1, hx2, hz1, hz2, hc = fit()
	if math.abs(hc - (hx1 + hx2) / 2) > 0.6 or i % 3 == 0 then bend = true; L, W = 7, 2.5; hx1, hx2, hz1, hz2, hc = fit() end
	local y = (hx1 + hx2 + hz1 + hz2 + hc) / 5
	local m = put(bend and "ccSeamB" or "ccSeamA", s[1], s[2], yaw, 1, F.seams, 0, y - 0.3)   -- (Studio r2: -0.5 hid the glow under the sand)
	m:PivotTo(m:GetPivot() * CFrame.Angles(-math.atan2(hz2 - hz1, 2 * W), 0, math.atan2(hx2 - hx1, 2 * L)))   -- (+X-rotation lowers +Z)
	table.insert(seamList, m); add("ccSeam")
end
-- (fix 4) a few narrow magma fractures on prominent channel-wall faces: seam plates laid against the wall slope
for _, wpt in { { 600, -124, 1 }, { 700, -78, -1 }, { 760, -32, 1 }, { 640, 145, -1 }, { 740, 134, 1 }, { 560, -115, -1 } } do
	local p, d = nearestChannel(wpt[1], wpt[2])
	local nx, nz = -d[2] * wpt[3], d[1] * wpt[3]
	local y0 = ground(p[1], p[2]); local fx, fz
	for dd = 6, 40, 1 do if ground(p[1] + nx * dd, p[2] + nz * dd) > y0 + 6 then fx, fz = p[1] + nx * dd, p[2] + nz * dd; break end end
	if fx then
		local gy = ground(fx, fz); local up = ground(fx + nx * 3, fz + nz * 3); local dn = ground(fx - nx * 3, fz - nz * 3)
		local slope = math.atan2(up - dn, 6)
		-- plate length along the channel, its local +Z toward the wall, tipped up to the wall slope
		local yaw = math.atan2(-d[2], d[1]) + rng:NextNumber(-0.3, 0.3)
		local m = put("ccSeamB", fx, fz, yaw, Vector3.new(1, 1, 1.1), F.seams, 0, gy - 0.75)
		local zSide = (math.sin(yaw) * nx + math.cos(yaw) * nz) >= 0 and 1 or -1
		m:PivotTo(m:GetPivot() * CFrame.Angles(-zSide * slope, 0, 0)); m.Name = "WallSeam"; add("wallSeam")
	end
end

-- ------------------------------------------------------------ crystal cluster groups G1-G12 (E4)
local function scatter(kind, cx, cz, r0, r1, n, sMin, sMax, rad, parent, sink, minY, maxY)
	local placed = 0
	for _ = 1, 40 * n do
		if placed >= n then break end
		local a = rng:NextNumber(0, math.pi * 2); local r = rng:NextNumber(r0, r1)
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local s = rng:NextNumber(sMin, sMax)
		local gy = ground(x, z)
		if free(x, z, rad * s) and (not minY or gy >= minY) and (not maxY or gy <= maxY) then
			put(kind, x, z, rng:NextNumber(0, math.pi * 2), s, parent, sink, nil, rad * s * 0.6)
			claim(x, z, rad * s); placed += 1
		end
	end
	add(kind, placed); return placed
end
local GROUPS = { { 565, -254, "L" }, { 705, -292, "M" }, { 795, -250, "S" }, { 810, -138, "L" }, { 650, 10, "L" }, { 730, 24, "M" },
	{ 570, 204, "M" }, { 615, 254, "L" }, { 772, 259, "M" }, { 781, 174, "S" }, { 585, -211, "S" }, { 684, -187, "M" } }
for _, g in GROUPS do
	local G = Instance.new("Folder"); G.Name = "Group"; G.Parent = F.crystals
	if g[3] == "L" then
		scatter("ccClusterL", g[1], g[2], 0, 12, 3, 0.9, 1.35, 6.5, G, 0.5)
		scatter("ccClusterS", g[1], g[2], 6, 18, 3, 0.9, 1.4, 3, G, 0.3)
		scatter("ccBoulderC", g[1], g[2], 8, 20, 1, 0.8, 1.2, 5, G, 0.6)
	elseif g[3] == "M" then
		scatter("ccClusterL", g[1], g[2], 0, 10, 2, 0.8, 1.1, 6.5, G, 0.5)
		scatter("ccClusterS", g[1], g[2], 4, 16, 3, 0.9, 1.4, 3, G, 0.3)
		scatter("ccBoulderB", g[1], g[2], 6, 16, 2, 0.8, 1.3, 3.5, G, 0.5)
	else
		scatter("ccClusterS", g[1], g[2], 0, 10, 4, 0.9, 1.5, 3, G, 0.3)
		scatter("ccShards", g[1], g[2], 2, 12, 2, 0.9, 1.3, 4, G, 0.15)
	end
	task.wait()
end
-- the spire's foot: a ring of clusters + shards so it reads as the heart of the canyon
scatter("ccClusterL", 580, -10, 15 * SPIRE_S, 21 * SPIRE_S, 3, 0.9, 1.25, 6.5, F.landmark, 0.5)
scatter("ccClusterS", 580, -10, 14 * SPIRE_S, 23 * SPIRE_S, 5, 0.9, 1.4, 3, F.landmark, 0.3)
scatter("ccShards", 580, -10, 13 * SPIRE_S, 23 * SPIRE_S, 4, 1.0, 1.4, 4, F.landmark, 0.15)
scatter("ccBoulderA", 580, -10, 12 * SPIRE_S, 19 * SPIRE_S, 6, 0.8, 1.5, 2, F.landmark, 0.4)   -- (Blender r2 note 3) detached basalt fragments
-- round the nests + veins (frame the mouths, keep the approach clear)
for _, n in { NEST_N, NEST_S, NEST_U } do
	scatter("ccClusterS", n[1], n[2], 20, 27, 3, 0.9, 1.3, 3, F.nests, 0.3)
	scatter("ccBoulderB", n[1], n[2], 20, 28, 2, 0.8, 1.3, 3.5, F.nests, 0.5)
end
for _, v in VEINS do scatter("ccShards", v[1], v[2], 6, 10, 1, 0.8, 1.1, 4, F.veins, 0.15) end

-- ------------------------------------------------------------ channel dressing: wall feet + rims, both sides
local function wallWalk(x, z, nx, nz)   -- from a channel point, walk out until the ground rises 5 (foot) / 16 (rim)
	local y0 = ground(x, z); local foot, rim
	for d = 4, 46, 2 do
		local gy = ground(x + nx * d, z + nz * d)
		if not foot and gy > y0 + 5 then foot = d end
		if not rim and gy > y0 + 16 then rim = d; break end
	end
	return foot, rim, y0
end
for _, path in { NORTH, SOUTH, LINK_B, LINK_A } do
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2); local dx, dz = (b[1] - a[1]) / L, (b[2] - a[2]) / L
		for d = 0, L - 1, 12 do
			local x, z = a[1] + dx * d, a[2] + dz * d
			if x < 505 then continue end
			for _, sgn in { -1, 1 } do
				local nx, nz = -dz * sgn, dx * sgn
				local foot, rim = wallWalk(x, z, nx, nz)
				-- (Studio audit r1 fix 4: too uniform) a slow noise along the walls: INFESTED stretches (dense crystals on
				-- the foot + rim) and BARE stretches (rock only), like E
				local dens = math.noise((x + nx * 20) / 55, (z + nz * 20) / 55, 5.5)
				local infested, bare = dens > 0.08, dens < -0.12
				if foot then
					local fx, fz = x + nx * (foot + 1), z + nz * (foot + 1)
					local pick = rng:NextNumber()
					if infested then pick = pick * 0.45 elseif bare then pick = 0.2 + pick * 0.52 end
					if pick < 0.2 then
						if free(fx, fz, 3) then put("ccClusterS", fx, fz, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.5), F.crystals, 0.4, nil, 2); claim(fx, fz, 3); add("ccClusterS") end
					elseif pick < 0.5 then
						if free(fx, fz, 3.5) then put("ccBoulderB", fx, fz, rng:NextNumber(0, 6.28), rng:NextNumber(0.8, 1.4), F.rocks, 0.6, nil, 2.5); claim(fx, fz, 3.5); add("ccBoulderB") end
					elseif pick < 0.72 then
						if free(fx, fz, 2) then put("ccBoulderA", fx, fz, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.6), F.rocks, 0.4, nil, 1.5); claim(fx, fz, 2); add("ccBoulderA") end
					else
						if free(fx, fz, 4) then put("ccShards", fx, fz, rng:NextNumber(0, 6.28), rng:NextNumber(0.9, 1.3), F.crystals, 0.15); claim(fx, fz, 4); add("ccShards") end
					end
				end
				local rimP = infested and 0.95 or (bare and 0.0 or 0.3)
				if rim and rng:NextNumber() < rimP then   -- crystals crowning the rim, leaning over the channel
					for k = 1, infested and 2 or 1 do
						local off = (k - 1) * 7
						local rx, rz = x + nx * (rim + 4 + off) + dx * rng:NextNumber(-4, 4), z + nz * (rim + 4 + off) + dz * rng:NextNumber(-4, 4)
						local kind = rng:NextNumber() < (infested and 0.6 or 0.4) and "ccClusterL" or "ccClusterS"
						local rad = kind == "ccClusterL" and 6.5 or 3
						if free(rx, rz, rad) then
							put(kind, rx, rz, yawFacing(-nx, -nz), rng:NextNumber(0.9, 1.35), F.crystals, 0.5, nil, rad * 0.5); claim(rx, rz, rad); add(kind)
						end
					end
				end
			end
		end
		task.wait()
	end
end

-- ------------------------------------------------------------ plateau tops: sparse boulders + a few low columns
local function fillPlateau(kind, n, rad, sMin, sMax, parent, sink)
	local c = 0
	for _ = 1, n * 60 do
		if c >= n then break end
		local x, z = rng:NextNumber(540, 830), rng:NextNumber(-320, 320)
		local s = rng:NextNumber(sMin, sMax)
		if (ground(x, z)) > 18 and free(x, z, rad * s) then
			put(kind, x, z, rng:NextNumber(0, 6.28), s, parent, sink, nil, rad * s * 0.6); claim(x, z, rad * s); c += 1
		end
	end
	add(kind, c)
end
fillPlateau("ccBoulderC", 10, 5, 0.8, 1.3, F.rocks, 0.7)
fillPlateau("ccBoulderB", 14, 3.5, 0.8, 1.4, F.rocks, 0.5)
fillPlateau("ccColumnB", 4, 8, 0.7, 1.0, F.columns, 1.0)
fillPlateau("ccShards", 10, 4, 0.9, 1.3, F.crystals, 0.15)

root.Parent = hub
local beacon = hub:FindFirstChild("Greybox") and hub.Greybox:FindFirstChild("CRYSTALCANYON")
if beacon then for _, d in beacon:GetDescendants() do if d:IsA("BasePart") then d.Transparency = 1 elseif d:IsA("GuiObject") or d:IsA("BillboardGui") then pcall(function() d.Enabled = false end) end end end
local out = {}
for k, v in count do table.insert(out, k .. "=" .. v) end
table.sort(out)
return ("parts %d, approx tris %d, painted %d | %s"):format(stats.parts, stats.tris, painted, table.concat(out, " "))
