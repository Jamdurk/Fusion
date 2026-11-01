-- Alien Fusion: build the whole Moon arena in the open place (Studio Edit, via the MCP), from the files on disk.
-- Needs kit-serve on 48734 serving the game folder, and ServerStorage.PropKit (the imported Blender props).
-- 1. Terrain from assets/blender/terrain/terrain_grid.json (build-terrain.luau)   2. structures   3. rocks + quartz
-- Every position is written at map scale 1 and multiplied by the grid's "scale" (map_terrain.py's S).
local Http = game:GetService("HttpService")
local function fetch(path)
	local was = Http.HttpEnabled; Http.HttpEnabled = true
	local ok, body = pcall(Http.GetAsync, Http, "http://127.0.0.1:48734/" .. path, true)
	Http.HttpEnabled = was
	assert(ok, "fetch " .. path .. ": " .. tostring(body))
	return body
end
local terrainOk = loadstring(fetch("src/tools/build-terrain.luau"))()
local g = Http:JSONDecode(fetch("assets/blender/terrain/terrain_grid.json"))
local S = g.scale or 1
local CR = g.crater or 42 * S                 -- world crater radius
-- the doubled map streams (forms/rules v1 §4): profile 512 vs 1024 on a phone
workspace.StreamingEnabled = true
pcall(function() workspace.StreamingMinRadius = 64; workspace.StreamingTargetRadius = 512 end)
pcall(function() workspace.ModelStreamingBehavior = Enum.ModelStreamingBehavior.Improved end)
pcall(function() workspace.StreamingIntegrityMode = Enum.StreamingIntegrityMode.PauseOutsideLoadedArea end)
pcall(function() workspace.StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic end)
local K = S >= 2 and 2 or 1                   -- prop count multiplier for the big map (~200 props, not 4x)

local kit = game:GetService("ServerStorage"):WaitForChild("PropKit")
local map = workspace:FindFirstChild("Map") or Instance.new("Folder", workspace); map.Name = "Map"
for _, n in { "Rocks", "Structures" } do local f = map:FindFirstChild(n); if f then f:Destroy() end end
local rocks = Instance.new("Folder", map); rocks.Name = "Rocks"
local st = Instance.new("Folder", map); st.Name = "Structures"

local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = { workspace.Terrain }
local function hit(x, z) return workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params) end
local function ground(x, z) local h = hit(x, z); return h and h.Position.Y or 0 end

-- ---------- structures (each team side x = -1 / +1) -------------------------------------------------------------
local TEAM = { [-1] = Color3.fromRGB(70, 120, 255), [1] = Color3.fromRGB(255, 70, 80) }   -- placeholder team colours
local function place(name, pos, yaw, scale, extra, parent)
	local src = kit[name]
	local base = src:Clone(); base.Size *= scale
	local cf = CFrame.new(pos + Vector3.new(0, base.Size.Y / 2, 0)) * CFrame.Angles(0, yaw or 0, 0)
	local srcBottom = src.CFrame * CFrame.new(0, -src.Size.Y / 2, 0)
	for _, e in extra or {} do
		local rel = srcBottom:ToObjectSpace(kit[e].CFrame)
		local p = kit[e]:Clone(); p.Size *= scale
		p.CFrame = (cf * CFrame.new(0, -base.Size.Y / 2, 0)) * CFrame.new(rel.Position * scale) * rel.Rotation
		p.Parent = parent or st
	end
	base.CFrame = cf; base.Parent = parent or st
	return base
end
for _, side in { -1, 1 } do
	local bx = 150 * S * side
	local team = Instance.new("Folder", st); team.Name = side < 0 and "BaseA" or "BaseB"
	place("MatterCore", Vector3.new(bx + 10 * side, ground(bx + 10 * side, 0) - 0.3, 0), side > 0 and math.pi or 0, 2.4, { "MatterCore_Glow", "MatterCore_Ring" }, team)
	local padX = bx - 34 * side
	place("SpawnPad", Vector3.new(padX, ground(padX, 0) - 0.4, 0), 0, 1.35, nil, team)
	for _, p in team:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "MatterCore_Glow" then p.Color = TEAM[side] end
	end
	team:SetAttribute("Side", side)
end
place("FusionReactor", Vector3.new(0, ground(0, 0) - 0.2, 0), 0, 1.4, { "Reactor_Glow" })
for _, p in st:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
		if p.Name:find("Glow") then
			p.Material = Enum.Material.Neon; p.CanCollide = false; p.CastShadow = false
			if p.Name == "Reactor_Glow" then p.Color = Color3.fromRGB(235, 245, 255) end
			local sa = p:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa:Destroy() end
		elseif p.Name == "MatterCore_Ring" then
			p.CanCollide = false
		end
	end
end

-- ---------- rocks + quartz (mirrored about x = 0) ---------------------------------------------------------------
local rng = Random.new(27)
local placed = {}
local function free(x, z, r)
	for _, p in placed do if (Vector2.new(x, z) - p[1]).Magnitude < r + p[2] then return false end end
	return true
end
local function put(name, x, z, scale, yaw, tint)
	local h = hit(x, z); if not h then return end
	local t = kit[name]:Clone(); t.Size *= scale
	t.CollisionFidelity = Enum.CollisionFidelity.Hull
	local up = h.Normal:Lerp(Vector3.yAxis, 0.6).Unit
	local axis = Vector3.yAxis:Cross(up)
	local tilt = axis.Magnitude > 1e-3 and CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(up:Dot(Vector3.yAxis), -1, 1))) or CFrame.identity
	t.CFrame = CFrame.new(h.Position) * tilt * CFrame.Angles(0, yaw, 0) * CFrame.new(0, t.Size.Y * 0.38, 0)
	if tint then local sa = t:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa.Color = tint end end
	t.Anchored = true; t.Parent = rocks
end
local function pair(name, x, z, scale, yaw, r, tint)
	if not free(x, z, r) then return false end
	table.insert(placed, { Vector2.new(x, z), r }); table.insert(placed, { Vector2.new(-x, z), r })
	put(name, x, z, scale, yaw, tint); put(name, -x, z, scale, -yaw, tint)
	return true
end
local DARK = Color3.fromRGB(120, 116, 112)   -- the south route's identity: darker basalt boulders
-- Boulder Plain (Roblox z > 0)
local n = 0
for _ = 1, 3000 do
	if n >= 26 * K then break end
	local x, z = rng:NextNumber(40, 172) * S, rng:NextNumber(48, 112) * S
	local name = ({ "Boulder1", "Boulder2", "Boulder3", "Boulder4" })[rng:NextInteger(1, 4)]
	if pair(name, x, z, rng:NextNumber(1.0, 1.7), rng:NextNumber(0, 6.28), 10 * S, DARK) then n += 1 end
end
-- Crystal Canyon ridges (Roblox z < 0): spires on the ridges, quartz along the channel
local s = 0
for _ = 1, 3000 do
	if s >= 18 * K then break end
	local xd, zd = rng:NextNumber(56, 138), rng:NextNumber(-114, -44)
	local chan = -(62 + 9 * math.sin(xd / 26))
	if math.abs(zd - chan) > 13 then
		if pair(({ "Spire1", "Spire2", "Spire3" })[rng:NextInteger(1, 3)], xd * S, zd * S, rng:NextNumber(1.1, 1.8), rng:NextNumber(0, 6.28), 8 * S) then s += 1 end
	end
end
local q = 0
for _ = 1, 600 do
	if q >= 12 * K then break end
	local xd = rng:NextNumber(55, 140)
	local chan = -(62 + 9 * math.sin(xd / 26))
	local zd = chan + (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(8, 11)
	if pair(({ "QuartzA", "QuartzB", "QuartzC" })[rng:NextInteger(1, 3)], xd * S, zd * S, rng:NextNumber(1.0, 1.9), rng:NextNumber(0, 6.28), 6 * S) then q += 1 end
end
-- quartz marking the crater rim either side of the breaches
for _, a in { 0.55, 2.6, 3.7, 5.75 } do
	local rr = CR + 5
	put("QuartzC", rr * math.cos(a), rr * math.sin(a), 1.6, a)
end
-- a few small boulders elsewhere (out of bases, crater and lanes)
local k = 0
for _ = 1, 600 do
	if k >= 10 * K then break end
	local xd, zd = rng:NextNumber(55, 125), rng:NextNumber(-35, 40)
	if Vector2.new(xd, zd).Magnitude > CR / S + 22 and Vector2.new(xd - 150, zd).Magnitude > 50 and math.abs(zd) > 16 then
		if pair(({ "Boulder1", "Boulder2" })[rng:NextInteger(1, 2)], xd * S, zd * S, rng:NextNumber(0.9, 1.3), rng:NextNumber(0, 6.28), 10 * S) then k += 1 end
	end
end
return string.format("%s | scale %.2f | structures %d | rocks %d", terrainOk, S, #st:GetDescendants(), #rocks:GetChildren())
