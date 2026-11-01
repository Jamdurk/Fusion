-- Alien Fusion: write the HUB moon heightfield (1,500 x 1,050 playable; hub_terrain.py -> terrain_grid_hub.json) into
-- Roblox Terrain (Studio Edit, via the MCP). Same mapping as build-terrain.luau: grid x = Roblox X, grid z (= north) lands
-- at Roblox Z = -z; heights in studs; voxels are 4 studs. Needs kit-serve on 48736 serving the game folder.
local Http = game:GetService("HttpService")
local was = Http.HttpEnabled
Http.HttpEnabled = true
local ok, body = pcall(Http.GetAsync, Http, "http://127.0.0.1:48736/assets/blender/terrain/terrain_grid_hub.json", true)
Http.HttpEnabled = was
assert(ok, "fetch failed: " .. tostring(body))
local g = Http:JSONDecode(body)

local MAT = { s = Enum.Material.Sand, g = Enum.Material.Ground, r = Enum.Material.Rock, b = Enum.Material.Basalt }
local terrain = workspace.Terrain
local C = g.cell
local baseY = g.baseY
local topY = 0
for _, row in g.h do for _, v in row do topY = math.max(topY, v) end end
local ny = math.ceil((topY - baseY) / C) + 1

terrain:Clear()
local STRIP = 16
local function snap(v) return math.floor(v / C + 0.5) * C end
for x0 = 1, g.nx, STRIP do
	local x1 = math.min(g.nx, x0 + STRIP - 1)
	local sx = x1 - x0 + 1
	local mats, occ = {}, {}
	for i = 1, sx do
		mats[i], occ[i] = {}, {}
		for y = 1, ny do
			mats[i][y], occ[i][y] = {}, {}
		end
	end
	for i = 1, sx do
		local xi = x0 + i - 1
		for zi = 1, g.nz do
			local row = g.nz - zi + 1
			local h = g.h[row][xi]
			local m = MAT[string.sub(g.m[row], xi, xi)] or Enum.Material.Sand
			for y = 1, ny do
				local yBottom = baseY + (y - 1) * C
				local o = math.clamp((h - yBottom) / C, 0, 1)
				occ[i][y][zi] = o
				mats[i][y][zi] = if o > 0 then m else Enum.Material.Air
			end
		end
	end
	-- the hub grid origin (-630) is off the 4-stud voxel grid: snap the corner (a <= 2-stud shift); ExpandToGrid would
	-- otherwise add a cell and WriteVoxels rejects the array
	local minX = snap(g.originX + (x0 - 1) * C)
	local minZ = snap(-(g.originZ + (g.nz - 1) * C))
	local minY = snap(baseY)
	local region = Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(minX + sx * C, minY + ny * C, minZ + g.nz * C))
	terrain:WriteVoxels(region, C, mats, occ)
	task.wait()
end
return string.format("hub terrain ok: %d x %d cells, %d voxels high, top %.1f", g.nx, g.nz, ny, topY)
