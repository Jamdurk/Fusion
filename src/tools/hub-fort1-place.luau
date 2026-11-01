-- Alien Fusion hub: CONQUEST LANES Fort 1 "THE HATCHLING NEST" on lane 1 (31 Oct 2026; design\conquest-lanes\FORT1-SPEC.md,
-- refs design\concepts\hub\L1, L4 (ortho + sizes), L4b (materials + hex)). James: heaps of refs + SIMPLE.
-- Built from the GOO MARSH kit (ServerStorage.HubKit.GooMarsh: real baked goo / rock textures) so the fort matches the
-- marsh: nest shell + tunnel, a goo CORE (goo orb in a ring of rock claws on a rock plinth), 6 EGG SACS, a goo PUDDLE,
-- the wild RAG pole; CONQUERED adds the player BANNER + a tiny DRILL (ServerStorage.FortKit, AI-generated pieces).
-- Re-runnable (rebuilds workspace.Hub.Conquest.Lane1.Fort1). Run in Edit: loadstring(src)(state) with state
-- "wild" (default) or "conquered" (only switches the looks; the spawn points + attributes stay).
local STATE = ... or "wild"
local KIT = game.ServerStorage.HubKit.GooMarsh
local FK = game.ServerStorage:FindFirstChild("FortKit")
local T = workspace.Terrain

local LANE = 1
local ANG = math.rad(22.5 + 45 * (LANE - 1))
local R = 240
local OUT = Vector3.new(math.cos(ANG), 0, -math.sin(ANG))          -- outward along the lane (toward the plot / attacker)
local C0 = Vector3.new(R * math.cos(ANG), 0, -R * math.sin(ANG))

local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { T }
local function ground(p)
	local hit = workspace:Raycast(Vector3.new(p.X, 200, p.Z), Vector3.new(0, -400, 0), rp)
	return hit and hit.Position.Y or 0
end
-- the fort frame: origin on the pad centre, -Z = outward (the nest mouth + core face the attacker), +X = to the right
local gy = ground(C0)
local F = CFrame.lookAt(Vector3.new(C0.X, gy, C0.Z), Vector3.new(C0.X, gy, C0.Z) + OUT)

local hub = workspace.Hub
local cq = hub:FindFirstChild("Conquest") or Instance.new("Folder"); cq.Name = "Conquest"; cq.Parent = hub
local lane = cq:FindFirstChild("Lane1") or Instance.new("Folder"); lane.Name = "Lane1"; lane.Parent = cq
local old = lane:FindFirstChild("Fort1"); if old then old:Destroy() end
local fort = Instance.new("Model"); fort.Name = "Fort1"
local wild = Instance.new("Folder"); wild.Name = "Wild"; wild.Parent = fort
local tame = Instance.new("Folder"); tame.Name = "Conquered"; tame.Parent = fort
local shared = Instance.new("Folder"); shared.Name = "Shared"; shared.Parent = fort

-- place a kit piece: lx, lz in the fort frame, yaw (deg) on top of the frame, scale, sink into the ground
local function put(src, parent, lx, lz, yaw, scale, sink, name)
	local p = src:Clone()
	if name then p.Name = name end
	if typeof(scale) == "number" then scale = Vector3.new(scale, scale, scale) end
	local cf, size
	if p:IsA("Model") then
		p:ScaleTo(scale.X)
		cf, size = p:GetBoundingBox()
	else
		p.Size = p.Size * scale
		cf, size = p.CFrame, p.Size
	end
	local w = F * CFrame.new(lx, 0, lz)
	local g = ground(w.Position)
	local target = CFrame.new(w.Position.X, g + size.Y / 2 - (sink or 0), w.Position.Z) * (F - F.Position) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	if p:IsA("Model") then p:PivotTo(target * (cf:Inverse() * p:GetPivot())) else p.CFrame = target end
	p.Parent = parent
	for _, d in (p:IsA("Model") and p:GetDescendants() or { p }) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	return p
end

-- ---------- the nest (shared: both looks), its mouth facing the attacker ----------
local nest = put(KIT.gmNestShell, shared, 0, 6, 0, 1, 1.0, "NestShell")
put(KIT.gmNestTunnel, shared, 0, -1.5, 0, 1, 1.0, "NestTunnel")

-- ---------- the goo puddle in front of the core (L4: ~14 x 10; 20 % slow later) ----------
local CZ = -15                                                   -- the core stands well clear of the tunnel mouth
local pud = put(KIT.gmPoolB, shared, 0, CZ - 1, 0, Vector3.new(16 / 52, 1, 12 / 44), 2.85, "GooPuddle")   -- (sunk: only the goo sheet shows, no raised lip)

-- ---------- the GOO CORE: plinth of rocks, 4 rock claws, a goo orb ----------
local core = Instance.new("Model"); core.Name = "Core"; core.Parent = shared
for i = 0, 4 do                                                  -- the plinth: 5 basalt rocks in a tight ring
	local a = i / 5 * math.pi * 2
	put(KIT.gmRockC, core, math.cos(a) * 2.2, CZ + math.sin(a) * 2.2, i * 72 + 20, Vector3.new(0.62, 1.55, 0.62), 0.9, "Plinth" .. i)   -- (audit r1: taller ring = the claws; the orb rides 2 higher)
end
local plinthTop = 0
for _, d in core:GetChildren() do plinthTop = math.max(plinthTop, d.Position.Y + d.Size.Y / 2) end
-- the orb: thick translucent goo (L4b #56DDF2, roughness 0.28) round a violet swirl; a goo-kit blob stretched round
-- reads as a cone, so the orb is a ball of Glass (refractive on PC, plain translucent on phones)
local orb = Instance.new("Part"); orb.Name = "Orb"; orb.Shape = Enum.PartType.Ball
orb.Size = Vector3.new(5.4, 5.4, 5.4); orb.Material = Enum.Material.Glass; orb.Color = Color3.fromHex("56DDF2")
orb.Transparency = 0.42; orb.Reflectance = 0.08; orb.CastShadow = false
local oc = (F * CFrame.new(0, 0, CZ)).Position
orb.CFrame = CFrame.new(oc.X, plinthTop + 1.4, oc.Z) * (F - F.Position)   -- cradled by the rock ring (its lower third inside)
orb.Anchored = true; orb.Parent = core
local seep = put(KIT.gmBlobB, core, 0, CZ, 30, Vector3.new(0.75, 0.55, 0.9), -0.2, "OrbSeep")   -- goo spilling over the plinth top
seep.CFrame = CFrame.new(oc.X, plinthTop - 1.0, oc.Z) * (F - F.Position)
for i = 0, -1 do                                                 -- (audit r1: separate claws dropped: the taller plinth ring holds the orb)
	local a = i / 4 * math.pi * 2 + math.pi / 4
	local cl = KIT.gmRockA:Clone(); cl.Name = "Claw" .. i
	cl.Size = cl.Size * Vector3.new(0.45, 0.55, 0.45)          -- (audit r1: claws cut ~half: low grips, the orb stays in sight)
	-- each claw stands on the plinth rim and leans in over the orb (its top just past the orb equator)
	local pos = Vector3.new(oc.X, plinthTop + 1.6, oc.Z) + (F - F.Position) * Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
	cl.CFrame = CFrame.lookAt(pos, Vector3.new(oc.X, plinthTop + 9, oc.Z)) * CFrame.Angles(math.rad(-90), 0, 0)
	cl.Anchored = true; cl.Parent = core
end
local inner = Instance.new("Part"); inner.Name = "OrbSwirl"; inner.Shape = Enum.PartType.Ball; inner.Size = Vector3.new(3.3, 3.3, 3.3)
inner.Material = Enum.Material.Neon; inner.Color = Color3.fromHex("B86BFF"); inner.Transparency = 0    -- (Glass hides see-through parts behind it: keep the swirl opaque)
inner.CFrame = orb.CFrame; inner.Anchored = true; inner.CanCollide = false; inner.CastShadow = false; inner.Parent = core
local light = Instance.new("PointLight"); light.Color = Color3.fromHex("56DDF2"); light.Range = 16; light.Brightness = 1.6
light.Shadows = false; light.Parent = inner
core:SetAttribute("MaxHP", 600)
-- (audit r1) the combat target: an invisible column from the ground to the orb top, reachable by F1 to F3 without
-- climbing; the decorative rocks never catch a hit or a click
for _, d in core:GetDescendants() do if d:IsA("BasePart") then d.CanQuery = false; d.CanTouch = false end end
local hb = Instance.new("Part"); hb.Name = "CoreHitbox"; hb.Shape = Enum.PartType.Cylinder
local hbH = orb.Position.Y + orb.Size.Y / 2 - gy
hb.Size = Vector3.new(hbH, 8, 8); hb.CFrame = CFrame.new(oc.X, gy + hbH / 2, oc.Z) * CFrame.Angles(0, 0, math.rad(90))
hb.Transparency = 1; hb.Anchored = true; hb.CanCollide = false; hb.CanTouch = false; hb.CanQuery = true; hb.CastShadow = false
hb:SetAttribute("CoreOf", "Lane1.Fort1"); hb.Parent = core

-- ---------- 6 EGG SACS on the nest flanks (goo blob membrane, a dark embryo inside) ----------
local eggs = Instance.new("Model"); eggs.Name = "EggSacs"; eggs.Parent = shared
local EGG = { { -17.5, -5, 3.4 }, { -20, -1, 2.8 }, { -18.5, 3.5, 3.1 }, { 17.5, -5, 3.4 }, { 20, -1, 2.8 }, { 18.5, 3.5, 3.1 } }
for i, e in EGG do
	local h = e[3]
	-- the membrane: the egg-shaped FortKit mesh with its flat texture swapped for translucent glass-goo (L4b #82EAF6)
	local m = put(FK.egg:FindFirstChildWhichIsA("MeshPart", true), eggs, e[1], e[2], i * 47, h / 3.5, 0.25, "Egg" .. i)
	for _, s in m:GetChildren() do if s:IsA("SurfaceAppearance") then s:Destroy() end end
	m.TextureID = ""; m.Material = Enum.Material.Glass; m.Color = Color3.fromHex("82EAF6"); m.Transparency = 0.32
	m.Reflectance = 0.06; m.CastShadow = false
	local em = KIT.gmRockC:Clone(); em.Name = "Embryo" .. i                     -- the curled embryo inside (audit r1: less like cartoon eyes)
	em.Size = em.Size * (h / 3.4) * Vector3.new(0.2, 0.36, 0.26)
	em.CFrame = m.CFrame * CFrame.new(0.1 * h, 0.1 * h, 0) * CFrame.Angles(0.9, i * 1.3, 1.1); em.Anchored = true; em.CanCollide = false
	for _, s in em:GetChildren() do if s:IsA("SurfaceAppearance") then s.Color = Color3.fromHex("5A7484") end end
	em.Parent = eggs
	put(KIT.gmBlobB, eggs, e[1], e[2], i * 31, h / 3.4 * 0.42, 0.5, "EggGoo" .. i)   -- goo at its base
end

-- ---------- dressing: a few goo blobs + rocks round the base (kept sparse) ----------
local dress = Instance.new("Folder"); dress.Name = "Dressing"; dress.Parent = shared
for i, d in { { KIT.gmBlobB, -9, -6, 0.6 }, { KIT.gmBlobB, 9.5, -5, 0.55 }, { KIT.gmRockB, -12, -9, 0.7 }, { KIT.gmRockA, 11, -12, 0.8 },
	{ KIT.gmBlobB, -6, 11, 0.7 }, { KIT.gmRockC, 7, 12, 0.6 } } do
	put(d[1], dress, d[2], d[3], i * 61, d[4], 0.3)
end

-- ---------- WILD look: the rag pole ----------
if FK and FK:FindFirstChild("rag") then
	local rag = put(FK.rag, wild, -19, -14, 15, 12 / 8, 0.3, "RagPole")
	-- (audit r1) darken the rag toward L4b #352B4A so it never reads as the blue player banner
	for _, mp in rag:GetDescendants() do
		if mp:IsA("MeshPart") and mp.TextureID ~= "" then
			local sa = Instance.new("SurfaceAppearance"); sa.ColorMap = mp.TextureID; sa.Color = Color3.fromRGB(150, 118, 170); sa.Parent = mp
		end
	end
end

-- ---------- CONQUERED look: banner + drill ----------
if FK and FK:FindFirstChild("drill") then
	put(FK.drill, tame, 14, -13, -25, 1.3, 0.1, "Drill")
end
-- the player banner: metal pole, cross bar, team-colour cloth with a white chevron, a small DNA crystal on top
do
	local b = Instance.new("Model"); b.Name = "Banner"; b.Parent = tame
	local base = F * CFrame.new(-19, 0, -14)
	local g = ground(base.Position)
	local function bp(name, size, cf, color, mat)
		local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat
		p.Anchored = true; p.CanCollide = false; p.Parent = b; return p
	end
	local rot = F - F.Position
	local at = CFrame.new(base.X, g, base.Z) * rot
	local pole = bp("Pole", Vector3.new(0.45, 12, 0.45), at * CFrame.new(0, 6, 0), Color3.fromHex("8F98A3"), Enum.Material.Metal)
	bp("Bar", Vector3.new(4.4, 0.32, 0.32), at * CFrame.new(1.9, 11.2, 0), Color3.fromHex("8F98A3"), Enum.Material.Metal)
	local cloth = bp("Cloth", Vector3.new(3.6, 5.2, 0.12), at * CFrame.new(2.0, 8.4, 0), Color3.fromHex("6BA6FF"), Enum.Material.Fabric)   -- (L4b #3B82F6, a notch brighter: Fabric reads darker under the moon light)
	cloth:SetAttribute("TeamColour", true)
	for s = -1, 1, 2 do                                      -- the white chevron: two strips meeting in a V
		bp("Chevron", Vector3.new(0.75, 2.6, 0.14), cloth.CFrame * CFrame.new(s * 0.8, -0.3, 0) * CFrame.Angles(0, 0, math.rad(-s * 42)), Color3.fromHex("DCE8FF"), Enum.Material.Neon)   -- a V pointing down; self-lit so it reads from the shaded side too (audit r1)
	end
	local tip = KIT.gmVeinCrystal:Clone(); tip.Name = "Tip"; tip.Size = tip.Size * 0.22
	tip.CFrame = at * CFrame.new(0, 12.4, 0); tip.Anchored = true; tip.CanCollide = false; tip.Parent = b
end

-- ---------- gameplay markers (no visuals): 6 wild Drip spawns + the attackers' approach ----------
local marks = Instance.new("Folder"); marks.Name = "Markers"; marks.Parent = fort
for _, a in T:GetChildren() do if a:IsA("Attachment") and a:GetAttribute("Fort") == "Lane1.Fort1" then a:Destroy() end end
for i = 1, 6 do
	local a = (i - 1) / 6 * math.pi * 2
	local a0 = Instance.new("Attachment")
	a0.Name = "WildSpawn" .. i
	local w = F * CFrame.new(math.cos(a) * 9, 0, -4 + math.sin(a) * 5)
	a0.WorldCFrame = CFrame.new(w.X, ground(w.Position) + 1, w.Z)
	a0.Parent = T
	a0:SetAttribute("Fort", "Lane1.Fort1")
	local ov = Instance.new("ObjectValue"); ov.Name = a0.Name; ov.Value = a0; ov.Parent = marks
end
fort:SetAttribute("Lane", LANE)
fort:SetAttribute("State", "wild")
fort:SetAttribute("CoreHP", 600)
fort:SetAttribute("WildDrips", 6)
fort:SetAttribute("ApproachFrom", (F * CFrame.new(0, 0, -30)).Position)
fort.WorldPivot = F
fort.Parent = lane

-- ---------- the two looks: the inactive one waits in ServerStorage.FortLooks (the gameplay stage swaps them) ----------
local looks = game.ServerStorage:FindFirstChild("FortLooks") or Instance.new("Folder"); looks.Name = "FortLooks"; looks.Parent = game.ServerStorage
local prev = looks:FindFirstChild("Lane1.Fort1"); if prev then prev:Destroy() end
local hold = Instance.new("Folder"); hold.Name = "Lane1.Fort1"; hold.Parent = looks
if STATE == "conquered" then
	wild.Parent = hold
	inner.Transparency = 0.6; light.Brightness = 0.5               -- the core dims once tamed
else
	tame.Parent = hold
end
fort:SetAttribute("State", STATE)
return string.format("Fort1 (%s) at %.1f, %.1f, %.1f facing out %.2f, %.2f", STATE, F.X, F.Y, F.Z, OUT.X, OUT.Z)
