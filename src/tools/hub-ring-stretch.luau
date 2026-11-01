-- Alien Fusion hub r5: STRETCH the moon for the CONQUEST LANES ring (31 Oct 2026; James: "Move bases too";
-- design\CONQUEST-LANES-HANDOFF.md). The biomes move out as the SAME ground (hub_terrain.py r5 evaluates each biome at
-- shifted coordinates): Moonwood N +100 (Roblox Z -100), Lander Ruins S -100 (Z +100), Goo Marsh X -52, Crystal Canyon
-- X +52. Shifts are whole voxels (4 studs), so every hand edit (canyon channels + bowls, marsh pools + paint, forest
-- paths, crater scar + mound) is carried over voxel for voxel.
-- Needs serve2.mjs on the game folder at 127.0.0.1:8767 (r4 + r5 grids). Run in Edit, one stage per call:
--   STAGE 1 "delta": for each edit box, read the live terrain (C) and rebuild in memory what the r4 grid wrote (B);
--            every voxel where C differs from B is a hand edit -> _G.RingDelta (at its NEW, shifted position).
--   STAGE 2 "pure": write the pure r5 grid, then re-take MarshTerrainBackup / CanyonTerrainBackup (the place scripts'
--            restore point) at their shifted corners.
--   STAGE 3 "final": write the r5 grid again WITH the hand edits folded in (one write per strip, no read-back round trip).
--   STAGE 4 "props": move the biome folders by their shift.
local STAGE = ...
local Http = game:GetService("HttpService")
local T = workspace.Terrain
local SS = game.ServerStorage
local URL = "http://127.0.0.1:8767/assets/blender/terrain/"
local C = 4

local function fetch(name)
	local was = Http.HttpEnabled
	Http.HttpEnabled = true
	local ok, body = pcall(Http.GetAsync, Http, URL .. name, true)
	Http.HttpEnabled = was
	assert(ok, "fetch failed: " .. tostring(body))
	return Http:JSONDecode(body)
end

local MAT = { s = Enum.Material.Sand, g = Enum.Material.Ground, r = Enum.Material.Rock, b = Enum.Material.Basalt }

-- the build's voxel for grid g at world voxel (vx, vy, vz): exactly what build-terrain-hub.luau writes
local function gridTop(g)
	local top = 0
	for _, row in g.h do for _, v in row do top = math.max(top, v) end end
	return math.ceil((top - g.baseY) / C) + 1
end
local function gridVoxel(g, vx, vy, vz)
	local xi = (vx * C - g.originX) / C + 1
	local zi = (vz * C - (-(g.originZ + (g.nz - 1) * C))) / C + 1
	if xi < 1 or xi > g.nx or zi < 1 or zi > g.nz then return Enum.Material.Air, 0 end
	local row = g.nz - zi + 1
	local h = g.h[row][xi]
	local o = math.clamp((h - (vy * C)) / C, 0, 1)
	if o <= 0 then return Enum.Material.Air, 0 end
	return MAT[string.sub(g.m[row], xi, xi)] or Enum.Material.Sand, o
end

-- edit boxes in WORLD VOXELS (min inclusive, max inclusive) + their shift in voxels
local BOXES = {
	{ name = "core", lo = Vector3int16.new(-40, -10, -40), hi = Vector3int16.new(39, 21, 39), dx = 0, dz = 0 },     -- crater, mound, scar
	{ name = "forest", lo = Vector3int16.new(-130, -10, -185), hi = Vector3int16.new(129, 21, -95), dx = 0, dz = -25 }, -- Z -740..-380
	{ name = "marsh", lo = Vector3int16.new(-215, -10, -90), hi = Vector3int16.new(-115, 20, 90), dx = -13, dz = 0 },  -- = MarshTerrainBackup
	{ name = "canyon", lo = Vector3int16.new(120, -10, -90), hi = Vector3int16.new(215, 25, 90), dx = 13, dz = 0 },    -- = CanyonTerrainBackup
}
local TOL = 0.03

if STAGE == "delta" then
	local g4 = fetch("terrain_grid_hub.r4.json")
	local delta = {}           -- key "vx,vy,vz" (new position) -> { mat, occ }
	local report = {}
	for _, b in BOXES do
		local n, outY = 0, 0
		for x0 = b.lo.X, b.hi.X, 16 do
			local x1 = math.min(b.hi.X, x0 + 15)
			local reg = Region3.new(Vector3.new(x0 * C, b.lo.Y * C, b.lo.Z * C), Vector3.new((x1 + 1) * C, (b.hi.Y + 1) * C, (b.hi.Z + 1) * C))
			local mats, occs = T:ReadVoxels(reg, C)
			for i = 1, #mats do
				local vx = x0 + i - 1
				for j = 1, #mats[i] do
					local vy = b.lo.Y + j - 1
					for k = 1, #mats[i][j] do
						local vz = b.lo.Z + k - 1
						local cm, co = mats[i][j][k], occs[i][j][k]
						if vy < g4.baseY / C then
							-- the build never writes below baseY: anything solid down there would be an edit we can't carry
							if co > TOL then outY += 1 end
						else
							local bm, bo = gridVoxel(g4, vx, vy, vz)
							local differs = math.abs(co - bo) > TOL or (cm ~= bm and math.max(co, bo) > TOL)
							-- core: only the crater bowl + rim, mound and scar (r < 118) are hand work; past that the box holds
							-- the old arena ground the crater was pasted from in r4, which must give way to the r5 lanes + pads
							local keep = b.name ~= "core" or math.sqrt(((vx + 0.5) * C) ^ 2 + ((vz + 0.5) * C) ^ 2) < 118
							if differs and keep then
								delta[string.format("%d,%d,%d", vx + b.dx, vy, vz + b.dz)] = { cm, co }
								n += 1
							end
						end
					end
				end
			end
			task.wait()
		end
		table.insert(report, string.format("%s %d edits (%d below baseY)", b.name, n, outY))
	end
	_G.RingDelta = delta
	return table.concat(report, " | ")
end

local function build(g, delta)
	local ny = gridTop(g)
	if delta then
		for key in delta do
			local vy = tonumber(string.match(key, "^[-%d]+,([-%d]+),"))
			ny = math.max(ny, vy - g.baseY / C + 1)
		end
	end
	local minVY = g.baseY / C
	local nz = g.nz
	local minVZ = -(g.originZ + (nz - 1) * C) / C
	local minVX0 = g.originX / C
	local used = 0
	T:Clear()
	for x0 = 1, g.nx, 16 do
		local x1 = math.min(g.nx, x0 + 15)
		local sx = x1 - x0 + 1
		local mats, occ = {}, {}
		for i = 1, sx do
			mats[i], occ[i] = {}, {}
			local vx = minVX0 + x0 + i - 2
			for y = 1, ny do
				mats[i][y], occ[i][y] = {}, {}
				local vy = minVY + y - 1
				for zi = 1, nz do
					local vz = minVZ + zi - 1
					local d = delta and delta[string.format("%d,%d,%d", vx, vy, vz)]
					if d then
						mats[i][y][zi], occ[i][y][zi] = d[1], d[2]
						used += 1
					else
						mats[i][y][zi], occ[i][y][zi] = gridVoxel(g, vx, vy, vz)
					end
				end
			end
		end
		local vx0 = minVX0 + x0 - 1
		local region = Region3.new(Vector3.new(vx0 * C, minVY * C, minVZ * C), Vector3.new((vx0 + sx) * C, (minVY + ny) * C, (minVZ + nz) * C))
		T:WriteVoxels(region, C, mats, occ)
		task.wait()
	end
	return used, ny
end

if STAGE == "pure" then
	local g5 = fetch("terrain_grid_hub.json")
	local _, ny = build(g5, nil)
	local out = {}
	for _, b in BOXES do
		if b.name == "marsh" or b.name == "canyon" then
			local nm = b.name == "marsh" and "MarshTerrainBackup" or "CanyonTerrainBackup"
			local old = SS:FindFirstChild(nm)
			local lo = Vector3int16.new(b.lo.X + b.dx, b.lo.Y, b.lo.Z + b.dz)
			local hi = Vector3int16.new(b.hi.X + b.dx, b.hi.Y, b.hi.Z + b.dz)
			local tr = T:CopyRegion(Region3int16.new(lo, hi))
			tr.Name = nm
			tr:SetAttribute("CornerVoxel", Vector3.new(lo.X, lo.Y, lo.Z))   -- (Vector3int16 can't be an attribute)
			tr:SetAttribute("Note", "r5 ring stretch 31 Oct: pure r5 grid before the carried-over hand edits")
			if old then old:Destroy() end
			tr.Parent = SS
			table.insert(out, nm .. " " .. tostring(lo))
		end
	end
	return "pure r5 written, ny " .. ny .. "; backups " .. table.concat(out, ", ")
end

if STAGE == "final" then
	assert(_G.RingDelta, "run stage delta first")
	local g5 = fetch("terrain_grid_hub.json")
	local n = 0
	for _ in _G.RingDelta do n += 1 end
	local used, ny = build(g5, _G.RingDelta)
	_G.RingFinal = string.format("final r5 written with %d / %d hand edits, ny %d", used, n, ny)
	return _G.RingFinal
end

if STAGE == "blend" then
	-- (after delta, before final) the marsh + canyon paint passes re-wrote their whole box, so every voxel there reads as
	-- an "edit" and the box edge carried the OLD ground into the blend bands (3-7 stud steps at the box edges). Where
	-- the r5 ground differs from r4 at that spot (blend band) and the edit is only paint / round-trip drift (occupancy
	-- within 0.3 of what r4 wrote), take the r5 occupancy and keep the painted material. Real carving stays.
	assert(_G.RingDelta, "run stage delta first")
	local g4, g5 = fetch("terrain_grid_hub.r4.json"), fetch("terrain_grid_hub.json")
	local changed, kept = 0, 0
	for key, d in _G.RingDelta do
		local vx, vy, vz = string.match(key, "^([-%d]+),([-%d]+),([-%d]+)$")
		vx, vy, vz = tonumber(vx), tonumber(vy), tonumber(vz)
		for _, b in BOXES do
			if (b.dx ~= 0 or b.dz ~= 0) and vx >= b.lo.X + b.dx and vx <= b.hi.X + b.dx and vz >= b.lo.Z + b.dz and vz <= b.hi.Z + b.dz then
				local _, bo = gridVoxel(g4, vx - b.dx, vy, vz - b.dz)
				local nm, no = gridVoxel(g5, vx, vy, vz)
				if math.abs(no - bo) > 0.05 and math.abs(d[2] - bo) < 0.3 then
					local mat = if no <= 0 then Enum.Material.Air elseif d[1] == Enum.Material.Air then nm else d[1]
					_G.RingDelta[key] = { mat, no }
					changed += 1
				else
					kept += 1
				end
				break
			end
		end
	end
	return string.format("blend bands: %d paint-only edits moved onto the r5 ground, %d kept", changed, kept)
end

if STAGE == "unblend" then
	-- (only needed once, 31 Oct) the "blend" stage was written against the first r5 grid (r5a), whose biome edges did NOT
	-- match r4. The final r5 grid (hub_terrain_ring.py) copies every biome WITH its edges exactly, so those paint-only
	-- edits go back to what r4 wrote there (their painted material kept).
	assert(_G.RingDelta, "run stage delta first")
	local g4, ga = fetch("terrain_grid_hub.r4.json"), fetch("terrain_grid_hub.r5a.json")
	local undone = 0
	for key, d in _G.RingDelta do
		local vx, vy, vz = string.match(key, "^([-%d]+),([-%d]+),([-%d]+)$")
		vx, vy, vz = tonumber(vx), tonumber(vy), tonumber(vz)
		for _, b in BOXES do
			if (b.dx ~= 0 or b.dz ~= 0) and vx >= b.lo.X + b.dx and vx <= b.hi.X + b.dx and vz >= b.lo.Z + b.dz and vz <= b.hi.Z + b.dz then
				local bm, bo = gridVoxel(g4, vx - b.dx, vy, vz - b.dz)
				local _, ao = gridVoxel(ga, vx, vy, vz)
				if math.abs(ao - bo) > 0.05 and d[2] == ao then
					local mat = if bo <= 0 then Enum.Material.Air elseif d[1] == Enum.Material.Air then bm else d[1]
					_G.RingDelta[key] = { mat, bo }
					undone += 1
				end
				break
			end
		end
	end
	return "unblended " .. undone
end

if STAGE == "reseat2" then
	-- props were seated on the first r5 grid (r5a); move each by the change r5a -> final r5 under it (carved columns skipped)
	assert(_G.RingDelta, "run stage delta first")
	local ga, g5 = fetch("terrain_grid_hub.r5a.json"), fetch("terrain_grid_hub.json")
	local edited = {}
	for key in _G.RingDelta do
		local x, _, z = string.match(key, "^([-%d]+),([-%d]+),([-%d]+)$")
		edited[x .. "," .. z] = true
	end
	local function gh(g, x, n)
		local i = math.floor((x - g.originX) / C + 0.5) + 1
		local j = math.floor((n - g.originZ) / C + 0.5) + 1
		if i < 1 or i > g.nx or j < 1 or j > g.nz then return nil end
		return g.h[j][i]
	end
	local out = {}
	for _, name in { "MoonwoodForest", "GooMarsh", "CrystalCanyon" } do
		local moved, worst = 0, 0
		for _, grp in workspace.Hub[name]:GetChildren() do
			local items = grp:IsA("Folder") and grp:GetChildren() or { grp }
			for _, it in items do
				if it:IsA("Model") or it:IsA("BasePart") then
					local p = it:IsA("Model") and it:GetPivot().Position or it.Position
					if not edited[math.floor(p.X / C) .. "," .. math.floor(p.Z / C)] then
						local a, b = gh(ga, p.X, -p.Z), gh(g5, p.X, -p.Z)
						if a and b and math.abs(b - a) > 0.3 then
							local dy = b - a
							worst = math.max(worst, math.abs(dy))
							if it:IsA("Model") then it:PivotTo(it:GetPivot() + Vector3.new(0, dy, 0)) else it.CFrame = it.CFrame + Vector3.new(0, dy, 0) end
							moved += 1
						end
					end
				end
			end
		end
		table.insert(out, string.format("%s: %d moved (worst %.2f)", name, moved, worst))
	end
	return table.concat(out, " | ")
end

if STAGE == "feather" then
	-- (after final) the carried-over marsh / canyon ground can meet the r5 ground with a 3-6 stud ledge at the box edge
	-- (the canyon's carved approaches reach its hub-side edge). Inside a 20-stud strip along each box edge, each column's
	-- surface eases from the r5 grid height AT the edge to the carried-over height 20 studs in; paint keeps its own
	-- material past a noisy line so no straight edge shows.
	local g5 = fetch("terrain_grid_hub.json")
	local FV = 5                                      -- strip width in voxels (20 studs)
	local out = {}
	for _, b in BOXES do
		if b.name == "marsh" or b.name == "canyon" then
			local x0, x1, z0, z1 = b.lo.X + b.dx, b.hi.X + b.dx, b.lo.Z + b.dz, b.hi.Z + b.dz
			local y0, y1 = g5.baseY / C, b.hi.Y + 4
			local cols, maxd = 0, 0
			-- read the strip in 4 sides (each a thin box)
			local sides = {
				{ x0, x0 + FV - 1, z0, z1 }, { x1 - FV + 1, x1, z0, z1 },
				{ x0 + FV, x1 - FV, z0, z0 + FV - 1 }, { x0 + FV, x1 - FV, z1 - FV + 1, z1 },
			}
			for _, s in sides do
				local reg = Region3.new(Vector3.new(s[1] * C, y0 * C, s[3] * C), Vector3.new((s[2] + 1) * C, (y1 + 1) * C, (s[4] + 1) * C))
				local mats, occs = T:ReadVoxels(reg, C)
				for i = 1, #mats do
					local vx = s[1] + i - 1
					for k = 1, #mats[i][1] do
						local vz = s[3] + k - 1
						local dist = math.min(vx - x0, x1 - vx, vz - z0, z1 - vz)       -- voxels from the box edge
						if dist < FV then
							local w = (dist + 0.5) / FV                                    -- 0 at the edge -> 1 inside
							w = w * w * (3 - 2 * w)
							-- carried-over surface height + its top material
							local he, topMat = y0 * C, Enum.Material.Sand
							for j = #mats[i], 1, -1 do
								if occs[i][j][k] > 0 then he = (y0 + j - 1) * C + occs[i][j][k] * C; topMat = mats[i][j][k]; break end
							end
							local gm, _ = gridVoxel(g5, vx, 0, vz)
							local xi = (vx * C - g5.originX) / C + 1
							local zi = (vz * C - (-(g5.originZ + (g5.nz - 1) * C))) / C + 1
							local h5 = g5.h[g5.nz - zi + 1][xi]
							local target = h5 * (1 - w) + he * w
							maxd = math.max(maxd, math.abs(he - h5))
							local paint = w + 0.35 * math.noise(vx / 3.1, vz / 3.1, 7.7) > 0.5
							local mat = paint and topMat or (gm ~= Enum.Material.Air and gm or Enum.Material.Sand)
							for j = 1, #mats[i] do
								local yb = (y0 + j - 1) * C
								local o = math.clamp((target - yb) / C, 0, 1)
								occs[i][j][k] = o
								if o <= 0 then mats[i][j][k] = Enum.Material.Air
								elseif mats[i][j][k] == Enum.Material.Air or (target - yb) < C * 1.5 then mats[i][j][k] = mat end
							end
							cols += 1
						end
					end
				end
				T:WriteVoxels(reg, C, mats, occs)
				task.wait()
			end
			table.insert(out, string.format("%s: %d edge columns feathered (largest step %.1f)", b.name, cols, maxd))
		end
	end
	return table.concat(out, " | ")
end

if STAGE == "verify" then
	-- read the written terrain back over every shifted edit box: each voxel must be its hand edit or the r5 grid
	assert(_G.RingDelta, "run stage delta first")
	local g5 = fetch("terrain_grid_hub.json")
	local out = {}
	for _, b in BOXES do
		local n, bad, worst, editsSeen = 0, 0, 0, 0
		for x0 = b.lo.X + b.dx, b.hi.X + b.dx, 16 do
			local x1 = math.min(b.hi.X + b.dx, x0 + 15)
			local lo = Vector3.new(x0 * C, (g5.baseY / C) * C, (b.lo.Z + b.dz) * C)
			local reg = Region3.new(lo, Vector3.new((x1 + 1) * C, (b.hi.Y + 1) * C, (b.hi.Z + b.dz + 1) * C))
			local mats, occs = T:ReadVoxels(reg, C)
			for i = 1, #mats do
				local vx = x0 + i - 1
				for j = 1, #mats[i] do
					local vy = g5.baseY / C + j - 1
					for k = 1, #mats[i][j] do
						local vz = b.lo.Z + b.dz + k - 1
						local d = _G.RingDelta[string.format("%d,%d,%d", vx, vy, vz)]
						local em, eo
						if d then em, eo = d[1], d[2]; editsSeen += 1 else em, eo = gridVoxel(g5, vx, vy, vz) end
						local cm, co = mats[i][j][k], occs[i][j][k]
						local diff = math.abs(co - eo)
						if cm ~= em and math.max(co, eo) > TOL then diff = math.max(diff, 1) end
						n += 1
						if diff > TOL then bad += 1 end
						worst = math.max(worst, diff)
					end
				end
			end
			task.wait()
		end
		table.insert(out, string.format("%s: %d voxels, %d off (worst %.3f), %d edits present", b.name, n, bad, worst, editsSeen))
	end
	return table.concat(out, " | ")
end

if STAGE == "reseat" then
	-- after "props": each biome piece keeps its old relation to the ground. Where the ground under it changed (the blend
	-- bands), it moves by exactly that change: r5 grid height here minus the r4 grid height at its old spot. Columns with
	-- a carried-over hand edit are the old ground already (skipped).
	assert(_G.RingDelta, "run stage delta first")
	local g4, g5 = fetch("terrain_grid_hub.r4.json"), fetch("terrain_grid_hub.json")
	local edited = {}
	for key in _G.RingDelta do
		local x, _, z = string.match(key, "^([-%d]+),([-%d]+),([-%d]+)$")
		edited[x .. "," .. z] = true
	end
	local function gh(g, x, n)
		local i = math.floor((x - g.originX) / C + 0.5) + 1
		local j = math.floor((n - g.originZ) / C + 0.5) + 1
		if i < 1 or i > g.nx or j < 1 or j > g.nz then return nil end
		return g.h[j][i]
	end
	local SH = { MoonwoodForest = { 0, 100 }, GooMarsh = { -52, 0 }, CrystalCanyon = { 52, 0 } }    -- (x, N) shift
	local out = {}
	for name, s in SH do
		local moved, skipped, worst = 0, 0, 0
		for _, grp in workspace.Hub[name]:GetChildren() do
			local items = grp:IsA("Folder") and grp:GetChildren() or { grp }
			for _, it in items do
				if it:IsA("Model") or it:IsA("BasePart") then
					local p = it:IsA("Model") and it:GetPivot().Position or it.Position
					if edited[math.floor(p.X / C) .. "," .. math.floor(p.Z / C)] then
						skipped += 1
					else
						local h5, h4 = gh(g5, p.X, -p.Z), gh(g4, p.X - s[1], -p.Z - s[2])
						if h5 and h4 then
							local dy = h5 - h4
							worst = math.max(worst, math.abs(dy))
							if math.abs(dy) > 0.3 then
								if it:IsA("Model") then it:PivotTo(it:GetPivot() + Vector3.new(0, dy, 0)) else it.CFrame = it.CFrame + Vector3.new(0, dy, 0) end
								moved += 1
							end
						end
					end
				end
			end
		end
		table.insert(out, string.format("%s: %d re-seated (worst %.2f), %d on carved ground", name, moved, worst, skipped))
	end
	return table.concat(out, " | ")
end

if STAGE == "props" then
	local hub = workspace.Hub
	local moves = { MoonwoodForest = Vector3.new(0, 0, -100), GooMarsh = Vector3.new(-52, 0, 0), CrystalCanyon = Vector3.new(52, 0, 0) }
	local out = {}
	for name, off in moves do
		local f = hub:FindFirstChild(name)
		assert(f, "missing " .. name)
		assert(not f:GetAttribute("RingShifted"), name .. " already shifted")
		local n = 0
		for _, d in f:GetDescendants() do
			if d:IsA("BasePart") then d.CFrame = d.CFrame + off; n += 1
			elseif d:IsA("Model") and not d.PrimaryPart then d.WorldPivot = d.WorldPivot + off end
		end
		f:SetAttribute("RingShifted", off)
		table.insert(out, name .. " " .. n)
	end
	return "moved " .. table.concat(out, ", ")
end

-- shared by the last stages: the ring (hub_terrain.py r5)
local PLOT_R, PLOT_U, PLOT_V, LANE_W, LANE_R0 = 380, 42.5, 47.5, 20, 125   -- plots 85 along the radius x 95 across (r 380 since 31 Oct pm, was 320)
local function plotAngles()
	local t = {}
	for k = 0, 7 do table.insert(t, math.rad(22.5 + 45 * k)) end
	return t
end
-- world (x, z) -> (along, across) for the plot / lane at angle a (N = -Z)
local function local2(x, z, a)
	local n = -z
	return x * math.cos(a) + n * math.sin(a), -x * math.sin(a) + n * math.cos(a)
end
local rpT = RaycastParams.new(); rpT.FilterType = Enum.RaycastFilterType.Include; rpT.FilterDescendantsInstances = { T }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rpT)
	return hit and hit.Position.Y
end

if STAGE == "tidy" then
	-- plain rocks: archive any that land on a plot (+10) or a lane (+8), re-seat the rest on the new ground
	local arch = SS:FindFirstChild("ArchiveRingR5") or Instance.new("Folder"); arch.Name = "ArchiveRingR5"; arch.Parent = SS
	local archived, seated = {}, 0
	local function check(obj)
		local p = obj:IsA("Model") and obj:GetPivot().Position or obj.Position
		for _, a in plotAngles() do
			local u, v = local2(p.X, p.Z, a)
			if math.abs(u - PLOT_R) < PLOT_U + 10 and math.abs(v) < PLOT_V + 10 then return true end
			if u > LANE_R0 - 8 and u < PLOT_R - PLOT_U + 8 and math.abs(v) < LANE_W / 2 + 8 then return true end
		end
		return false
	end
	for _, f in { workspace.Map.Rocks, workspace.Hub.PlainDetail } do
		for _, r in f:GetChildren() do
			if check(r) then
				table.insert(archived, r.Name); r.Parent = arch
			else
				-- seat by the lowest point of the piece: bottom of its bounding box onto the ground under its centre
				local cf, size = if r:IsA("Model") then r:GetBoundingBox() else r.CFrame, if r:IsA("Model") then select(2, r:GetBoundingBox()) else r.Size
				local gy = ground(cf.Position.X, cf.Position.Z)
				if gy then
					local bottom = cf.Position.Y - size.Y / 2
					local sink = math.min(size.Y * 0.25, 1.5)               -- rocks sit a little into the ground
					local dy = (gy - sink) - bottom
					if math.abs(dy) > 0.6 then
						if r:IsA("Model") then r:PivotTo(r:GetPivot() + Vector3.new(0, dy, 0)) else r.CFrame = r.CFrame + Vector3.new(0, dy, 0) end
						seated += 1
					end
				end
			end
		end
	end
	return string.format("archived %d (%s), re-seated %d", #archived, table.concat(archived, ","), seated)
end

if STAGE == "floatcheck" then
	-- every loose prop in the biomes + crater: compare its bottom with the ground under its centre (report only)
	local out, worst = {}, {}
	for _, name in { "MoonwoodForest", "GooMarsh", "CrystalCanyon", "CraterLandmark" } do
		local f = workspace.Hub:FindFirstChild(name)
		local n, floating, sunk = 0, 0, 0
		for _, m in f:GetChildren() do
			local ok, cf, size = pcall(function()
				if m:IsA("Model") then return m:GetBoundingBox() end
				if m:IsA("BasePart") then return m.CFrame, m.Size end
				error("skip")
			end)
			if ok and size.Y < 120 then
				local gy = ground(cf.Position.X, cf.Position.Z)
				if gy then
					n += 1
					local gap = (cf.Position.Y - size.Y / 2) - gy
					if gap > 1.0 then floating += 1; table.insert(worst, string.format("%s.%s +%.1f @(%.0f,%.0f)", name, m.Name, gap, cf.Position.X, cf.Position.Z)) end
					if gap < -math.max(3, size.Y * 0.6) then sunk += 1; table.insert(worst, string.format("%s.%s %.1f @(%.0f,%.0f)", name, m.Name, gap, cf.Position.X, cf.Position.Z)) end
				end
			end
		end
		table.insert(out, string.format("%s: %d checked, %d floating > 1, %d sunk", name, n, floating, sunk))
	end
	_G.RingFloat = worst
	return table.concat(out, "\n") .. "\n" .. table.concat(worst, "\n", 1, math.min(#worst, 40))
end

if STAGE == "greybox" then
	local gb = workspace.Hub:FindFirstChild("Greybox"); if gb then gb.Parent = nil; gb.Name = "GreyboxR4"; gb.Parent = SS:FindFirstChild("ArchiveRingR5") or SS end
	gb = Instance.new("Folder"); gb.Name = "Greybox"; gb.Parent = workspace.Hub
	local function part(name, size, cf, color, mat, parent)
		local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.CastShadow = false; p.Parent = parent; return p
	end
	local function sign(parent, text, color, up)
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(260, 46); bb.StudsOffset = Vector3.new(0, up or 6, 0)
		bb.MaxDistance = 900; bb.LightInfluence = 0; bb.Parent = parent
		local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 0.25
		l.BackgroundColor3 = Color3.fromRGB(16, 16, 22); l.TextColor3 = color; l.TextScaled = true; l.Font = Enum.Font.GothamBold
		l.Text = text; l.Parent = bb
	end
	local WHITE, PAD = Color3.fromRGB(235, 235, 240), Color3.fromRGB(90, 220, 255)
	for i, a in plotAngles() do
		local cx, cz = PLOT_R * math.cos(a), -PLOT_R * math.sin(a)
		local y = (ground(cx, cz) or 3) + 0.15
		-- the plot frame: +u = outward (away from the crater), turned so its inner edge faces the crater
		local face = CFrame.lookAt(Vector3.new(cx, y, cz), Vector3.new(0, y, 0))      -- -Z of this frame points at the crater
		local m = Instance.new("Model"); m.Name = "Plot" .. i; m.Parent = gb
		local t = 1.2      -- face frame: local X = across (95), local Z = along the radius (85, -Z = crater side)
		part("In", Vector3.new(PLOT_V * 2, 0.3, t), face * CFrame.new(0, 0, -PLOT_U), WHITE, Enum.Material.Neon, m)
		part("Out", Vector3.new(PLOT_V * 2, 0.3, t), face * CFrame.new(0, 0, PLOT_U), WHITE, Enum.Material.Neon, m)
		part("L", Vector3.new(t, 0.3, PLOT_U * 2), face * CFrame.new(-PLOT_V, 0, 0), WHITE, Enum.Material.Neon, m)
		part("R", Vector3.new(t, 0.3, PLOT_U * 2), face * CFrame.new(PLOT_V, 0, 0), WHITE, Enum.Material.Neon, m)
		local post = part("Sign", Vector3.new(1, 8, 1), face * CFrame.new(-PLOT_V + 6, 4, PLOT_U - 6), Color3.fromRGB(200, 200, 210), nil, m)
		sign(post, "PLOT " .. i, WHITE, 6)
		-- LAUNCH PAD marker: a 12 x 12 square in the middle of the crater-facing edge, inside the plot
		local padCF = face * CFrame.new(0, 0, -PLOT_U + 8)
		part("LaunchPad", Vector3.new(12, 0.3, 12), padCF, PAD, Enum.Material.Neon, m).Transparency = 0.55
		local pp = part("LaunchSign", Vector3.new(0.5, 0.5, 0.5), padCF * CFrame.new(0, 3, 0), PAD, nil, m); pp.Transparency = 1
		sign(pp, "LAUNCH PAD", PAD, 3)
		m:SetAttribute("Angle", math.deg(a))
	end
	-- biome entrances (r5: each faces a gap between two plots)
	local BIOMES = {
		{ "MOONWOOD FOREST", 0, 470, Color3.fromRGB(176, 150, 255) },
		{ "GOO MARSH", -490, 10, Color3.fromRGB(70, 225, 235) },
		{ "CRYSTAL CANYON", 490, 10, Color3.fromRGB(255, 170, 60) },
		{ "LANDER RUINS", 0, -470, Color3.fromRGB(225, 220, 205) },
	}
	for _, b in BIOMES do
		local x, z = b[2], -b[3]
		local y = ground(x, z) or 0
		local m = Instance.new("Model"); m.Name = b[1]:gsub(" ", ""); m.Parent = gb
		local beacon = part("Beacon", Vector3.new(3, 26, 3), CFrame.new(x, y + 13, z), b[4], Enum.Material.Neon, m)
		sign(beacon, b[1], b[4], 16)
	end
	return "ring greybox placed (8 plots + launch pads, 4 beacons)"
end

error("STAGE must be delta / pure / final / props / tidy / floatcheck / greybox")
