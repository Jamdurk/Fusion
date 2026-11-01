-- Alien Fusion hub: GREYBOX the 1,500 x 1,050 moon (30 Oct 2026; ChatGPT map-size audit option C, approved by James;
-- design\map-review\map-size-audit.md). Run in Edit, in three calls:
--   STAGE 1 (before the terrain): copy the crater + scar terrain (paint included) into ServerStorage.
--   (then run build-terrain-hub.luau: writes terrain_grid_hub.json)
--   STAGE 2: paste the crater terrain back; archive the old arena (Map.Structures + rocks outside the hub core) to
--            ServerStorage.ArchiveArenaV1; re-seat the hub rocks; streaming settings.
--   STAGE 3: greybox markers: 8 plot outlines + signs, a beacon + sign at each biome entrance (workspace.Hub.Greybox).
-- Coordinates: N ("north") = Roblox -Z. Zones (X, N) from hub_terrain.py.
local STAGE = ... or 1
local T = workspace.Terrain
local SS = game.ServerStorage
local CRATER = Region3int16.new(Vector3int16.new(-40, -10, -40), Vector3int16.new(39, 11, 39))   -- voxel cells (4 studs): +-160 x, -40..48 y, +-160 z

if STAGE == 1 then
	local old = SS:FindFirstChild("CraterTerrainBackup"); if old then old:Destroy() end
	local tr = T:CopyRegion(CRATER); tr.Name = "CraterTerrainBackup"; tr.Parent = SS
	return "copied crater terrain " .. tostring(tr.SizeInCells)
end

if STAGE == 2 then
	local tr = SS:FindFirstChild("CraterTerrainBackup")
	assert(tr, "no CraterTerrainBackup: run stage 1 before the terrain")
	T:PasteRegion(tr, CRATER.Min, true)
	local arch = SS:FindFirstChild("ArchiveArenaV1") or Instance.new("Folder"); arch.Name = "ArchiveArenaV1"; arch.Parent = SS
	local map = workspace:FindFirstChild("Map")
	local moved, kept = 0, 0
	if map then
		local st = map:FindFirstChild("Structures"); if st then st.Parent = arch; moved += 1 end
		local rocks = map:FindFirstChild("Rocks")
		if rocks then
			local ar = arch:FindFirstChild("Rocks") or Instance.new("Folder"); ar.Name = "Rocks"; ar.Parent = arch
			local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
			for _, r in rocks:GetChildren() do
				local p = r:IsA("Model") and r:GetPivot().Position or r.Position
				local inCore = math.abs(p.X) < 315 and math.abs(p.Z) < 250
				local onPlot = math.abs(math.abs(p.X) - 230) < 55 and (math.abs(math.abs(p.Z) - 55) < 60 or math.abs(math.abs(p.Z) - 165) < 60)
				if inCore and not onPlot then
					local hit = workspace:Raycast(Vector3.new(p.X, 120, p.Z), Vector3.new(0, -260, 0), rp)
					if hit then
						local dy = hit.Position.Y - p.Y
						if math.abs(dy) > 0.5 then
							if r:IsA("Model") then r:PivotTo(r:GetPivot() + Vector3.new(0, dy, 0)) else r.CFrame = r.CFrame + Vector3.new(0, dy, 0) end
						end
					end
					kept += 1
				else
					r.Parent = ar; moved += 1
				end
			end
		end
	end
	local ok = pcall(function()
		workspace.StreamingMinRadius = 64
		workspace.StreamingTargetRadius = 384
		workspace.StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic
	end)
	pcall(function() workspace.ModelStreamingBehavior = Enum.ModelStreamingBehavior.Improved end)
	return string.format("crater pasted; archived %d, kept %d hub rocks; streaming set %s", moved, kept, tostring(ok))
end

-- STAGE 3: greybox markers
local hub = workspace:FindFirstChild("Hub") or Instance.new("Folder"); hub.Name = "Hub"; hub.Parent = workspace
local gb = hub:FindFirstChild("Greybox"); if gb then gb:Destroy() end
gb = Instance.new("Folder"); gb.Name = "Greybox"; gb.Parent = hub
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y or 0
end
local function part(name, size, cf, color, mat, parent)
	local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.CastShadow = false; p.Parent = parent; return p
end
local function sign(parent, text, color, studsOffset)
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(260, 46); bb.StudsOffset = Vector3.new(0, studsOffset or 6, 0)
	bb.AlwaysOnTop = false; bb.MaxDistance = 900; bb.LightInfluence = 0; bb.Parent = parent
	local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 0.25
	l.BackgroundColor3 = Color3.fromRGB(16, 16, 22); l.TextColor3 = color; l.TextScaled = true; l.Font = Enum.Font.GothamBold
	l.Text = text; l.Parent = bb
end
-- the 8 plots: 85 x 95 white outlines on the pad + a sign
local i = 0
for _, sx in { -1, 1 } do
	for _, n in { 190, 65, -65, -190 } do
		i += 1
		local x, z = sx * 230, -n
		local y = ground(x, z) + 0.15
		local m = Instance.new("Model"); m.Name = "Plot" .. i; m.Parent = gb
		local W, D, t = 85, 95, 1.2
		part("N", Vector3.new(W, 0.3, t), CFrame.new(x, y, z - D / 2), Color3.fromRGB(235, 235, 240), Enum.Material.Neon, m)
		part("S", Vector3.new(W, 0.3, t), CFrame.new(x, y, z + D / 2), Color3.fromRGB(235, 235, 240), Enum.Material.Neon, m)
		part("W", Vector3.new(t, 0.3, D), CFrame.new(x - W / 2, y, z), Color3.fromRGB(235, 235, 240), Enum.Material.Neon, m)
		part("E", Vector3.new(t, 0.3, D), CFrame.new(x + W / 2, y, z), Color3.fromRGB(235, 235, 240), Enum.Material.Neon, m)
		local post = part("Sign", Vector3.new(1, 8, 1), CFrame.new(x - sx * 30, y + 4, z), Color3.fromRGB(200, 200, 210), nil, m)
		sign(post, "PLOT " .. i, Color3.fromRGB(240, 240, 245), 6)
	end
end
-- biome entrances: a coloured beacon + sign where the path from the hub enters each zone
local BIOMES = {
	{ "MOONWOOD FOREST", 0, 285, Color3.fromRGB(176, 150, 255) },
	{ "GOO MARSH", -380, 10, Color3.fromRGB(70, 225, 235) },
	{ "CRYSTAL CANYON", 380, 10, Color3.fromRGB(255, 170, 60) },
	{ "LANDER RUINS", 0, -305, Color3.fromRGB(225, 220, 205) },
}
for _, b in BIOMES do
	local x, z = b[2], -b[3]
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = b[1]:gsub(" ", ""); m.Parent = gb
	local beacon = part("Beacon", Vector3.new(3, 26, 3), CFrame.new(x, y + 13, z), b[4], Enum.Material.Neon, m)
	sign(beacon, b[1], b[4], 16)
end
-- walk-time check at 22 studs/s (straight line, plot centre -> each entrance)
local lines = {}
for _, p in { { "PLOT 1 (-230, N 190)", -230, 190 }, { "PLOT 8 (230, N -190)", 230, -190 } } do
	local s = {}
	for _, b in BIOMES do table.insert(s, string.format("%s %.0fs", b[1]:match("^%a+"), math.sqrt((p[2] - b[2]) ^ 2 + (p[3] - b[3]) ^ 2) / 22)) end
	table.insert(lines, p[1] .. ": " .. table.concat(s, ", "))
end
return "greybox placed; walk times @22: " .. table.concat(lines, " | ")
