-- Alien Fusion hub: file the textured CRYSTAL CANYON kit (31 Oct 2026). Kit = assets\blender\scripts\hub_crystalcanyon.py +
-- hub_crystalcanyon_tex.py -> roblox-ready\hub-crystalcanyon-tex.glb -> 3D Importer -> model "Scene" in workspace (pivot =
-- the scene origin; GLB pieces need no yaw: C = position - pivot, attribute NoYaw). Same steps as hub-goomarsh-kit.luau:
-- 1) every MeshPart goes to ServerStorage.HubKit.CrystalCanyon with attribute C;
-- 2) the importer's pure WHITE MetalnessMap (= full metal, renders dark) is cleared;
-- 3) the importer's own emissive mask is replaced by OUR baked _emit map of the piece's texture group (EMIT below,
--    uploaded asset ids), EmissiveStrength per group (E3 reply: spires ~1.4, magma ~1.7, rock seams lower).
local EMIT = _G.CC_EMIT or {       -- group -> uploaded _emit mask, bake r5 (crystal-canyon asset-ids.md)
	spireCrystal = "rbxassetid://136346899509854", spireRock = "rbxassetid://81529775612283", crystals = "rbxassetid://71327138440626",
	basalt = "rbxassetid://77117615972416", columns = "rbxassetid://129988194897041", nest = "rbxassetid://127290935175312",
	tunnel = "rbxassetid://108089044717970", arch = "rbxassetid://99986067045381", seam = "rbxassetid://77630882236376",
}
local GROUP = {   -- mesh name -> texture group (hub_crystalcanyon_tex.py GROUPS)
	ccSpireCrystal = "spireCrystal", ccSpireRock = "spireRock",
	ccClusterLCrystal = "crystals", ccClusterSCrystal = "crystals", ccShardsCrystal = "crystals", ccVeinCrystal = "crystals",
	ccNestCrystal = "crystals", ccArchCrystal = "crystals",
	ccClusterLRock = "basalt", ccClusterSRock = "basalt", ccShardsGravel = "basalt", ccBoulderA = "basalt",
	ccBoulderB = "basalt", ccBoulderC = "basalt", ccVeinRock = "basalt",
	ccColumnA = "columns", ccColumnB = "columns", ccNestRock = "nest", ccNestTunnel = "tunnel", ccArch = "arch",
	ccSeamA = "seam", ccSeamB = "seam",
}
local STRENGTH = _G.CC_STRENGTH or { spireCrystal = 1.4, spireRock = 1.5, crystals = 1.4, basalt = 1.5, columns = 1.4,
	nest = 1.5, tunnel = 1.5, arch = 1.4, seam = 2.4 }   -- (Studio r1 fix 2: tunnel -25 %)
-- (Studio r1, LESSONS 24) the moon light (Brightness 2.4, lilac outdoor ambient) washes albedo out: rocks read white-lilac,
-- crystals lemon yellow. SurfaceAppearance.Color tints the maps: basalt down to mid grey, crystals toward amber.
local TINT = _G.CC_TINT or { spireCrystal = Color3.new(1, 0.68, 0.48), crystals = Color3.new(1, 0.68, 0.48),   -- (Studio r1 fix 5: -8 % green)
	spireRock = Color3.new(0.7, 0.7, 0.72), basalt = Color3.new(0.7, 0.7, 0.72), columns = Color3.new(0.7, 0.7, 0.72),
	nest = Color3.new(0.7, 0.7, 0.72), arch = Color3.new(0.7, 0.7, 0.72), seam = Color3.new(0.6, 0.59, 0.6) }   -- (Studio r2: 0.78 read as pale slabs on the basalt walls)
local OVERRIDE = _G.CC_OVERRIDE or {}   -- group -> { color = id, normal = id | false, emit = id, strength = n } (dead uploads)
local store = game.ServerStorage:FindFirstChild("HubKit") or Instance.new("Folder"); store.Name = "HubKit"; store.Parent = game.ServerStorage
local K = store:FindFirstChild("CrystalCanyon") or Instance.new("Folder"); K.Name = "CrystalCanyon"; K.Parent = store
local scene = workspace:FindFirstChild("Scene")
local filed = 0
if scene then
	local pv = scene:GetPivot().Position
	for _, p in scene:GetDescendants() do
		if p:IsA("MeshPart") and GROUP[p.Name] then
			local old = K:FindFirstChild(p.Name); if old then old:Destroy() end
			p:SetAttribute("C", p.Position - pv); p:SetAttribute("NoYaw", true); p:SetAttribute("Group", GROUP[p.Name])
			p.Anchored = true
			p.Parent = K
			filed += 1
		end
	end
	scene:Destroy()
end
local missing = {}
for name, g in GROUP do
	local p = K:FindFirstChild(name)
	if not p then table.insert(missing, name); continue end
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		sa.MetalnessMap = ""
		if EMIT[g] then
			sa.EmissiveMaskContent = Content.fromUri(EMIT[g])
			sa.EmissiveStrength = STRENGTH[g] or 1
		end
		local o = OVERRIDE[g]
		if o then
			if o.color then sa.ColorMapContent = Content.fromUri(o.color) end
			if o.normal == false then sa.NormalMapContent = Content.none elseif o.normal then sa.NormalMapContent = Content.fromUri(o.normal) end
			if o.emit then sa.EmissiveMaskContent = Content.fromUri(o.emit) end
			if o.strength then sa.EmissiveStrength = o.strength end
		end
	end
	p.Color = Color3.new(1, 1, 1)
	if sa then sa.Color = TINT[g] or Color3.new(1, 1, 1) end
	p.DoubleSided = name == "ccNestTunnel"   -- (Roblox culls back faces: the lining is seen from inside)
end
return ("filed %d, kit %d pieces, missing: %s"):format(filed, #K:GetChildren(), table.concat(missing, ","))
