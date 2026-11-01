-- Alien Fusion: the CRATER THRONE contained arena (31 Oct 2026; design\conquest-lanes\core\THRONE-SPEC.md, ref
-- design\concepts\hub\R1-throne-layout-chatgpt.png). Coordinates: N = -Z ("north" up in R1), angles from +X toward N.
--   combat ring r 47-72 | 4 spawn pockets 18 x 22 at r 64 on 45 / 135 / 225 / 315 deg | 2 pylon shelves 14 x 14 at
--   N (0, -67) + S (0, +67) | 8 entry ramps 20 wide on the lane angles (22.5 + 45k), r 125 -> shelf at r 70.
-- Run in Edit: loadstring(src)(stage). Stages:
--   "measure": ground ranges under every pocket / shelf / ramp (no changes)
--   "greybox": marker parts in workspace.Hub.Conquest.Throne.Greybox (CanQuery off; no terrain change)
--   "terrain": level the pockets + shelves and cut the 8 ramps (backs the crater region up first, once)
local STAGE = ... or "measure"
local T = workspace.Terrain
local SS = game.ServerStorage

local R_IN, R_OUT = 47, 72
local POCKET_R, POCKET_W, POCKET_D = 60, 18, 22          -- (audit A r1) r 60, 22 along the radius (49-71, inside the terrace), 18 across
local SHELF = 14
local RAMP_W, RAMP_R0, RAMP_R1 = 20, 70, 125
local POCKETS = { 45, 135, 225, 315 }
-- (audit B r1, measured) the wreck bulges south (to r 56): a south pylon left 9 studs to pass; east / west have 49-55
local PYLONS = { { "East", Vector3.new(67, 0, 0) }, { "West", Vector3.new(-67, 0, 0) } }

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y
end
local function dir(deg) local a = math.rad(deg); return Vector3.new(math.cos(a), 0, -math.sin(a)) end
-- a rectangle's frame: centre c, its local -Z toward the crater centre
local function frameAt(c) return CFrame.lookAt(c, Vector3.new(0, c.Y, 0)) end
local function range(cf, w, d, step)
	local lo, hi, sum, n = 1e9, -1e9, 0, 0
	for u = -w / 2, w / 2, step do for v = -d / 2, d / 2, step do
		local p = (cf * CFrame.new(u, 0, v)).Position
		local y = ground(p.X, p.Z)
		if y then lo = math.min(lo, y); hi = math.max(hi, y); sum += y; n += 1 end
	end end
	return lo, hi, n > 0 and sum / n or 0
end

local function sites()
	local s = {}
	for _, deg in POCKETS do
		local c = dir(deg) * POCKET_R
		table.insert(s, { kind = "pocket", name = "Spawn" .. deg, cf = frameAt(c), w = POCKET_W, d = POCKET_D })
	end
	for _, p in PYLONS do table.insert(s, { kind = "shelf", name = "Pylon" .. p[1], cf = frameAt(p[2]), w = SHELF, d = SHELF }) end
	return s
end

if STAGE == "measure" then
	local out = {}
	for _, s in sites() do
		local lo, hi, avg = range(s.cf, s.w, s.d, 2)
		table.insert(out, string.format("%s at %.0f,%.0f: ground %.1f..%.1f (avg %.1f)", s.name, s.cf.X, s.cf.Z, lo, hi, avg))
	end
	for k = 0, 7 do
		local deg = 22.5 + 45 * k
		local prof = {}
		for r = RAMP_R1, RAMP_R0, -5 do local p = dir(deg) * r; table.insert(prof, string.format("%.0f", ground(p.X, p.Z) or -99)) end
		table.insert(out, string.format("Ramp %.1f (r 125 -> 70): %s", deg, table.concat(prof, " ")))
	end
	return table.concat(out, "\n")
end

if STAGE == "greybox" then
	local cq = workspace.Hub:FindFirstChild("Conquest") or Instance.new("Folder"); cq.Name = "Conquest"; cq.Parent = workspace.Hub
	local th = cq:FindFirstChild("Throne") or Instance.new("Folder"); th.Name = "Throne"; th.Parent = cq
	local old = th:FindFirstChild("Greybox"); if old then old:Destroy() end
	local gb = Instance.new("Folder"); gb.Name = "Greybox"; gb.Parent = th
	local function part(name, size, cf, color, parent, trans)
		local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = Enum.Material.Neon
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
		p.Transparency = trans or 0.35; p.Parent = parent; return p
	end
	-- combat ring edge (r 72) + inner edge (r 47) as dashes laid on the ground
	for _, rr in { R_IN, R_OUT } do
		for i = 0, 47 do
			local a = i / 48 * math.pi * 2
			local p = Vector3.new(rr * math.cos(a), 0, -rr * math.sin(a))
			local y = ground(p.X, p.Z) or 0
			part("Ring" .. rr, Vector3.new(0.6, 0.3, rr * math.pi * 2 / 48 * 0.55), CFrame.lookAt(Vector3.new(p.X, y + 0.2, p.Z), Vector3.new(p.X, y + 0.2, p.Z) + Vector3.new(-math.sin(a), 0, -math.cos(a))), Color3.fromRGB(255, 255, 255), gb, 0.2)
		end
	end
	for _, s in sites() do
		local lo, hi, avg = range(s.cf, s.w, s.d, 2)
		local col = s.kind == "pocket" and Color3.fromRGB(255, 120, 90) or Color3.fromRGB(90, 220, 255)
		local m = Instance.new("Model"); m.Name = s.name; m.Parent = gb
		local cf = s.cf + Vector3.new(0, hi + 0.2, 0)
		part("Pad", Vector3.new(s.w, 0.3, s.d), cf, col, m, 0.55)
		if s.kind == "shelf" then part("PylonBlock", Vector3.new(5, 16, 5), cf * CFrame.new(0, 8, 0), Color3.fromRGB(150, 160, 175), m, 0.1) end
		m:SetAttribute("GroundLo", lo); m:SetAttribute("GroundHi", hi)
	end
	for k = 0, 7 do
		local deg = 22.5 + 45 * k
		local m = Instance.new("Model"); m.Name = "Ramp" .. k + 1; m.Parent = gb
		for r = RAMP_R0, RAMP_R1, 5 do
			local p = dir(deg) * r
			local y = ground(p.X, p.Z) or 0
			part("Step", Vector3.new(RAMP_W, 0.3, 1.2), CFrame.lookAt(Vector3.new(p.X, y + 0.2, p.Z), Vector3.new(0, y + 0.2, 0)), Color3.fromRGB(255, 220, 90), m, 0.4)
		end
	end
	return "throne greybox placed"
end

if STAGE == "terrain" then
	-- one read -> reshape -> write over the crater box (|x|, |z| <= 132, y -40..44). Only columns in the combat ring
	-- (r 40-80) or a ramp corridor change; every other column is written back as read. Surface material is kept (scar
	-- paint), new solid below a raised surface takes the column's top material, a cut keeps what's below.
	local C = 4
	local LO = Vector3int16.new(-33, -10, -33)
	local HI = Vector3int16.new(32, 10, 32)
	local bk = SS:FindFirstChild("ThroneTerrainBackup")
	if not bk then
		bk = T:CopyRegion(Region3int16.new(LO, HI)); bk.Name = "ThroneTerrainBackup"
		bk:SetAttribute("CornerVoxel", Vector3.new(LO.X, LO.Y, LO.Z)); bk.Parent = SS
	else
		T:PasteRegion(bk, LO, true)                                     -- re-run: start from the untouched crater
	end
	local function smooth(e0, e1, v) local t = math.clamp((v - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t) end
	local FLOOR = -2
	-- pads sit ON a voxel boundary (full top voxel, air above): a half-filled top voxel renders with ~1.6-stud bumps, a
	-- full one ~0.9 (measured 31 Oct); so the pads are low platforms at the boundary y 0 (the rough terrace is y -2)
	local PAD_Y = 0
	local reg = Region3.new(Vector3.new(LO.X * C, LO.Y * C, LO.Z * C), Vector3.new((HI.X + 1) * C, (HI.Y + 1) * C, (HI.Z + 1) * C))
	local mats, occ = T:ReadVoxels(reg, C)
	local nx, ny, nz = #mats, #mats[1], #mats[1][1]
	local changed, cut, raised = 0, 0, 0
	for i = 1, nx do
		for k = 1, nz do
			local x, z = (LO.X + i - 0.5) * C, (LO.Z + k - 0.5) * C
			local r = math.sqrt(x * x + z * z)
			-- current surface + its top material
			local h, top = nil, Enum.Material.Ground
			for j = ny, 1, -1 do
				if occ[i][j][k] > 0 then h = (LO.Y + j - 1) * C + occ[i][j][k] * C; top = mats[i][j][k]; break end
			end
			if h then
				local target = h
				-- the combat ring: flat terrace r 47-72, eased in from r 40 and out to r 80
				local wRing = smooth(40, 47, r) * (1 - smooth(75, 83, r))   -- (audit B r1) flat to r 75 for Titan room
				local tRing = FLOOR + 0.35 * math.noise(x / 11, z / 11, 3.3)
				target = target * (1 - wRing) + tRing * wRing
				-- (audit A r1) the 4 spawn pockets + 2 pylon shelves: exactly flat at FLOOR, 4-stud soft edge
				for _, s in sites() do
					local lp = s.cf:PointToObjectSpace(Vector3.new(x, s.cf.Y, z))
					local wPad = (1 - smooth(s.w / 2, s.w / 2 + 4, math.abs(lp.X))) * (1 - smooth(s.d / 2, s.d / 2 + 4, math.abs(lp.Z)))
					if wPad > 0 then target = target * (1 - wPad) + PAD_Y * wPad end
				end
				-- ramps: corridors on the lane angles, 20 clear + 11 soft each side, r 72 -> 122, only ever cut
				local a = math.atan2(-z, x)
				for kk = 0, 7 do
					local la = math.rad(22.5 + 45 * kk)
					local da = math.atan2(math.sin(a - la), math.cos(a - la))
					if math.abs(da) < math.rad(30) then
						local along, across = r * math.cos(da), math.abs(r * math.sin(da))
						local wSide = 1 - smooth(RAMP_W / 2, RAMP_W / 2 + 11, across)
						local wEnd = smooth(68, 74, along) * (1 - smooth(118, 126, along))
						local w = wSide * wEnd
						if w > 0 then
							local outer = 3                                                -- the plain at the lane end
							local tRamp = FLOOR + (outer - FLOOR) * smooth(72, 122, along)
							if tRamp < target then target = target * (1 - w) + tRamp * w end
						end
					end
				end
				if math.abs(target - h) > 0.05 then
					changed += 1
					if target < h then cut += 1 else raised += 1 end
					for j = 1, ny do
						local yb = (LO.Y + j - 1) * C
						local o = math.clamp((target - yb) / C, 0, 1)
						if o <= 0 then
							mats[i][j][k] = Enum.Material.Air
						elseif mats[i][j][k] == Enum.Material.Air or target - yb < C then
							mats[i][j][k] = top
						end
						occ[i][j][k] = o
					end
				end
			end
		end
	end
	T:WriteVoxels(reg, C, mats, occ)
	return string.format("arena terrain: %d columns reshaped (%d cut, %d raised); backup ServerStorage.ThroneTerrainBackup", changed, cut, raised)
end

error("stage: measure / greybox / terrain")
