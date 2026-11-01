-- Alien Fusion hub: file the textured GOO MARSH kit (30 Oct 2026). Kit = assets\blender\scripts\hub_goomarsh.py +
-- hub_goomarsh_tex.py -> roblox-ready\hub-goomarsh-tex.glb -> 3D Importer -> model "Scene" in workspace (pivot = the
-- scene origin; GLB pieces need no yaw: C = position - pivot, attribute NoYaw).
-- 1) every MeshPart goes to ServerStorage.HubKit.GooMarsh with attribute C;
-- 2) the importer gives every SurfaceAppearance a pure WHITE MetalnessMap (= full metal, renders dark): cleared;
-- 3) the importer's own emissive mask is replaced by OUR baked _emit map of the piece's texture group (EMIT below,
--    uploaded asset ids), EmissiveStrength per group (ChatGPT spec audit r1 fix 6: keep the bright spots restrained).
local EMIT = _G.GM_EMIT or {}       -- group -> "rbxassetid://..." (set before running, from the upload)
local GROUP = {   -- mesh name -> texture group (hub_goomarsh_tex.py GROUPS)
	gmGiantCap = "giantCap", gmGiantGills = "giantGills", gmGiantStalk = "giantStalk",
	gmTrumpetCap = "mush", gmUmbrellaCap = "mush", gmSproutCap = "mush", gmTrumpetGills = "mush", gmUmbrellaGills = "mush",
	gmSproutGills = "mush", gmTrumpetStalk = "mush", gmUmbrellaStalk = "mush", gmSproutStalk = "mush",
	gmBlobA = "goo", gmBlobB = "goo", gmVeinGoo = "goo", gmDrape = "goo", gmNestShell = "nest", gmNestTunnel = "tunnel",
	gmPoolA = "poolA", gmPoolB = "poolB", gmFilmA = "flats", gmFilmB = "flats", gmStreamA = "flats", gmStreamB = "flats",
	gmRockA = "rocks", gmRockB = "rocks", gmRockC = "rocks", gmVeinRock = "rocks", gmVeinCrystal = "rocks",
}
local STRENGTH = { giantCap = 1.6, giantGills = 2.2, giantStalk = 1.0,   -- (Studio r1: stalk glow lift)
	 mush = 1.6, goo = 1.4, nest = 1.4, tunnel = 2.5,
	poolA = 1.5, poolB = 1.5, flats = 1.3, rocks = 1.2 }
local OVERRIDE = {
	mush = { color = { cap = "rbxassetid://133248699791960", stalk = "rbxassetid://122255523052996" }, noNormal = true },
	nest = { color = "rbxassetid://81669633638971" },
	-- (Studio audit r2 blocker) pools: darker deep-teal centre, glow on the rim only (hub_goomarsh_poolfix.py)
	poolA = { color = "rbxassetid://105815469871936", emit = "rbxassetid://113614846570270", strength = 1.8 },
	poolB = { color = "rbxassetid://70718297096388", emit = "rbxassetid://122605761008554", strength = 1.8 },
	flats = { color = "rbxassetid://131510013263262", emit = "rbxassetid://78125153870997", strength = 1.8 },
	tunnel = { strength = 1.8 },
}
local store = game.ServerStorage:FindFirstChild("HubKit") or Instance.new("Folder"); store.Name = "HubKit"; store.Parent = game.ServerStorage
local K = store:FindFirstChild("GooMarsh") or Instance.new("Folder"); K.Name = "GooMarsh"; K.Parent = store
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
		elseif STRENGTH[g] == 0 then
			sa.EmissiveMaskContent = Content.none; sa.EmissiveStrength = 0
		end
	end
	-- (31 Oct) two importer uploads never loaded in Roblox and shaded flat dark grey (mush atlas colour + normal, nest
	-- colour): fresh uploads instead; the small mushrooms run without a normal map (asset-ids.md)
	if sa and OVERRIDE[g] then
		local o = OVERRIDE[g]
		if o.color then sa.ColorMapContent = Content.fromUri(type(o.color) == "table" and (name:find("Stalk") and o.color.stalk or o.color.cap) or o.color) end
		if o.noNormal then sa.NormalMapContent = Content.none end
		if o.emit then sa.EmissiveMaskContent = Content.fromUri(o.emit) end
		if o.strength then sa.EmissiveStrength = o.strength end
	end
	p.Color = Color3.new(1, 1, 1)
	-- (Studio r1) Roblox culls back faces: the open gill blades + tunnel lining render from both sides
	p.DoubleSided = name:find("Gills") ~= nil or name == "gmNestTunnel"
end
return ("filed %d, kit %d pieces, missing: %s"):format(filed, #K:GetChildren(), table.concat(missing, ","))
