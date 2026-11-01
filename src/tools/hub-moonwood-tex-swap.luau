-- Alien Fusion hub: swap the TEXTURED Moonwood kit into the forest (30 Oct 2026; James: the trees look "very Robloxy";
-- reference design\concepts\hub\C4-moonwood-materials-chatgpt.png; ChatGPT texture audit r1 fixes in
-- design\map-review\moonwood-tex\). Kit from hub_moonwood.py + hub_moonwood_tex.py -> roblox-ready\hub-moonwood-tex.glb
-- -> 3D Importer -> model "Scene" in workspace (pivot = scene origin). Per tree: Bark + Canopy (baked SurfaceAppearance),
-- Pods (pale husks + stems) + PodGlow (Neon drops), all from the GLB. GLB pieces need no importer yaw: C = position - pivot.
-- 1) files the Scene's pieces into ServerStorage.HubKit.Moonwood (attribute NoYaw); the flat OBJ pieces go to
--    HubKit.MoonwoodFlat (rollback). The importer gives every SurfaceAppearance a pure WHITE MetalnessMap (= full metal,
--    renders dark); it is cleared here.
-- 2) rebuilds every placed tree from its Bark (the bark mesh and its C never change): s = bark size / kit bark size,
--    base = bark CFrame * (YAW if it is a flat OBJ piece) * CFrame.new(-C * s); every mw piece is then re-spawned.
local store = game.ServerStorage.HubKit
local K = store.Moonwood
local flat = store:FindFirstChild("MoonwoodFlat") or Instance.new("Folder"); flat.Name = "MoonwoodFlat"; flat.Parent = store
local YAW = CFrame.Angles(0, math.pi, 0)
local scene = workspace:FindFirstChild("Scene")
if scene then
	local pv = scene:GetPivot().Position
	for _, p in scene:GetDescendants() do
		if p:IsA("MeshPart") then
			local old = K:FindFirstChild(p.Name)
			if old and not old:GetAttribute("NoYaw") then
				local prev = flat:FindFirstChild(p.Name); if prev then prev:Destroy() end
				old.Parent = flat
			elseif old then
				old:Destroy()
			end
			p:SetAttribute("C", p.Position - pv); p:SetAttribute("NoYaw", true)
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then sa.MetalnessMap = "" end
			p.Anchored = true
			p.Parent = K
		end
	end
	scene:Destroy()
end

local LOOK = {   -- material, colour, collide (SurfaceAppearance pieces keep white: the maps carry the colour)
	Bark = { Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), true },
	Canopy = { Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), false },
	Pods = { Enum.Material.SmoothPlastic, Color3.fromRGB(230, 218, 242), false },   -- pale lilac husk (audit r1 fix 4, r2 fix 3)
	PodGlow = { Enum.Material.Neon, Color3.fromRGB(124, 86, 232), false },          -- dimmer violet core (audit r2 fix 3)
}
local function spawn(kind, part, base, s, parent)
	local src = K[kind .. part]
	local p = src:Clone()
	local look = LOOK[part]
	p.Material, p.Color = look[1], look[2]
	p.Anchored, p.CanTouch, p.CastShadow = true, false, look[1] ~= Enum.Material.Neon
	p.CanCollide, p.CanQuery = look[3], look[3]
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	p.Size = p.Size * s
	p.CFrame = base * CFrame.new(src:GetAttribute("C") * s)
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if part == "Canopy" and sa then
		-- audit r2 fix 1: per-tree variation, smooth across the forest (a tint can only darken): brightness 0.92..1,
		-- hue about +-6 RGB toward blue-violet or pink-lilac
		local q = p.Position
		local v = math.clamp(math.noise(q.X / 45, q.Z / 45, 2.7) + 0.5, 0, 1)
		local h = math.clamp(math.noise(q.X / 30, q.Z / 30, 8.1) + 0.5, 0, 1)
		local b = 0.92 + 0.08 * v
		sa.Color = Color3.new(b * (1 - 0.05 * h), b * (1 - 0.05 * (1 - h)), b)
	end
	p.Parent = parent
end

local rebuilt = 0
local models = {}
for _, b in workspace.Hub.MoonwoodForest:GetDescendants() do
	local kind = b:IsA("MeshPart") and b.Name:match("^(mw%a-)Bark$")
	if kind and K:FindFirstChild(kind .. "Bark") then table.insert(models, { b, kind }) end
end
for _, e in models do
	local bark, kind = e[1], e[2]
	local kb = K[kind .. "Bark"]
	local s = bark.Size.Y / kb.Size.Y
	local base = bark.CFrame * (bark:GetAttribute("NoYaw") and CFrame.identity or YAW) * CFrame.new(-kb:GetAttribute("C") * s)
	local m = bark.Parent
	for _, c in m:GetChildren() do
		if c:IsA("MeshPart") and c.Name:match("^" .. kind .. "%u") then c:Destroy() end
	end
	for _, part in { "Bark", "Canopy", "Pods", "PodGlow" } do spawn(kind, part, base, s, m) end
	rebuilt += 1
end
print("MWTEX rebuilt", rebuilt, "trees")
return rebuilt
