-- Alien Fusion: write the Blender-sculpted Moon heightfield into Roblox Terrain (Studio Edit, via the MCP).
-- Needs kit-serve on 48734 serving the game folder. Grid: assets/blender/terrain/terrain_grid.json (map_terrain.py).
-- Mapping (same as the GLB route, Blender (x, y, z) -> Roblox (-x, z, y)): the grid's x is mirror-symmetric so
-- Roblox X = x; grid z (= -Blender y) lands at Roblox Z = -z. Heights in studs; voxels are 4 studs.
local Http = game:GetService("HttpService")
local was = Http.HttpEnabled
Http.HttpEnabled = true
local ok, body = pcall(Http.GetAsync, Http, "http://127.0.0.1:48734/assets/blender/terrain/terrain_grid.json", true)
Http.HttpEnabled = was
assert(ok, "fetch failed: " .. tostring(body))
local g = Http:JSONDecode(body)

local MAT = { s = Enum.Material.Sand, g = Enum.Material.Ground, r = Enum.Material.Rock, b = Enum.Material.Basalt }
local terrain = workspace.Terrain
local C = g.cell                     -- 4
local baseY = g.baseY                -- bottom of the ground
local topY = 0
for _, row in g.h do for _, v in row do topY = math.max(topY, v) end end
local ny = math.ceil((topY - baseY) / C) + 1

terrain:Clear()
-- write in x strips of 16 columns so Studio never stalls
local STRIP = 16
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
			-- Roblox Z = -grid z: write the rows reversed so voxel index k runs south -> north in Roblox
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
	local minX = g.originX + (x0 - 1) * C
	local minZ = -(g.originZ + (g.nz - 1) * C)
	local region = Region3.new(
		Vector3.new(minX, baseY, minZ),
		Vector3.new(minX + sx * C, baseY + ny * C, minZ + g.nz * C)
	):ExpandToGrid(C)
	terrain:WriteVoxels(region, C, mats, occ)
	task.wait()
end
return string.format("terrain ok: %d x %d cells, %d voxels high, top %.1f", g.nx, g.nz, ny, topY)
