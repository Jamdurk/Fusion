-- Alien Fusion mining setup (Studio Edit, 1 Nov 2026). Re-runnable: rebuilds everything it owns.
-- Look matches design\concepts\mining\mining-refs-chatgpt.png (chunky lilac rock clusters, goo puddle in a rock ring,
-- crystal clusters on a rock base, 5 picks with a hex collar). Numbers live in MiningConfig.
--   * tags the 8 Goo Marsh veins, 8 Crystal Canyon veins, 8 Moonwood pods (4 cyan / 4 amber) + MineHitbox each
--   * plot 1 mining corner (back-right, clear of the Launch Pad): 3 small + 1 big Moon Rock + the starter Goo pocket,
--     plus 2 empty Dense Rock sockets for the later pad
--   * 12 cluster sockets per biome near the veins + 6 small clusters each (the server rotates them every 4 min)
--   * ReplicatedStorage.AlienFusion.Pickaxes T1..T5
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local TAG = "MineNode"
local hub = workspace.Hub
local out = {}
local rng = Random.new(1101)

local LILAC = Color3.fromRGB(150, 142, 176)
local LILAC_DARK = Color3.fromRGB(78, 68, 102)
local GOO = Color3.fromRGB(70, 235, 225)
local AMBER = Color3.fromRGB(255, 170, 50)
local VIOLET = Color3.fromRGB(122, 60, 255)

local function anchorDeco(p)
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
end

local function hitbox(model, pad)
	local old = model:FindFirstChild("MineHitbox")
	if old then old:Destroy() end
	local cf, size = model:GetBoundingBox()
	local b = Instance.new("Part")
	b.Name = "MineHitbox"; b.Transparency = 1; b.Anchored = true; b.CanCollide = false; b.CanTouch = false; b.CanQuery = true
	b.CastShadow = false; b.Size = size + Vector3.one * (pad or 0.4); b.CFrame = cf; b.Parent = model
	return b
end

local function tagNode(model, nodeType)
	model:SetAttribute("NodeType", nodeType)
	CS:AddTag(model, TAG)
	hitbox(model)
end

local function ground(pos, onlyTerrain)
	local rp = RaycastParams.new()
	if onlyTerrain then rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { workspace.Terrain } end
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 120, pos.Z), Vector3.new(0, -400, 0), rp)
	return hit
end

------------------------------------------------------------------ the placed landmarks
for _, v in hub.GooMarsh.Veins:GetChildren() do tagNode(v, "GooVein") end
for _, v in hub.CrystalCanyon.Veins:GetChildren() do
	if v.Name:match("^AmberVein") then tagNode(v, "CrystalVein") end
end
for i, pod in hub.MoonwoodForest.DNAPods:GetChildren() do
	local goo = i % 2 == 1
	local col = goo and GOO or AMBER
	for _, p in pod:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "mwPodClusterGlow" then p.Color = col:Lerp(Color3.new(1, 1, 1), 0.35) end
		if p:IsA("BasePart") and p.Name == "mwPodClusterCore" then p.Color = col end
		if p:IsA("SurfaceAppearance") and p.Parent.Name == "mwPodClusterGlow" then p.Color = col:Lerp(Color3.new(1, 1, 1), 0.3) end
	end
	tagNode(pod, goo and "GooPod" or "CrystalPod")
end
table.insert(out, "landmarks tagged")

------------------------------------------------------------------ rock nodes (PlainRock meshes: main boulder + pebbles)
local rockSrc = {}
for _, r in hub.PlainDetail:GetChildren() do if r.Name == "PlainRock" then table.insert(rockSrc, r) end end

local function rockPiece(parent, size, cf, color)
	local r = rockSrc[rng:NextInteger(1, #rockSrc)]:Clone()
	for _, c in r:GetChildren() do c:Destroy() end
	r.Name = "Rock"; r.Size = size; r.CFrame = cf; r.Color = color; r.Material = Enum.Material.Slate
	anchorDeco(r); r.CanCollide = true
	r.Parent = parent
	return r
end

-- a deposit model: pivot = ground centre, main rock + ring of pebbles
local function makeRock(name, base, mainSize, color, pebbles)
	local m = Instance.new("Model"); m.Name = name
	local main = rockPiece(m, mainSize, base * CFrame.new(0, mainSize.Y * 0.42, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), color)
	-- ref: a chunky CLUSTER, so the first two around the main rock are half its size, the rest small
	for i = 1, pebbles do
		local a = (i / pebbles) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local big = i <= 2
		local rr = mainSize.X * (big and 0.48 or 0.62) + rng:NextNumber(0, 0.5)
		local s = mainSize * (big and rng:NextNumber(0.48, 0.6) or rng:NextNumber(0.26, 0.36))
		local p = rockPiece(m, s, base * CFrame.new(math.cos(a) * rr, s.Y * 0.35, math.sin(a) * rr) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), color)
		p.CanCollide = false
	end
	m.PrimaryPart = main
	m.WorldPivot = base
	return m
end

local function makeGooPocket(base)
	local m = Instance.new("Model"); m.Name = "GooPocket"
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2
		local s = Vector3.new(2.2, 1.8, 2.0) * rng:NextNumber(0.8, 1.25)
		rockPiece(m, s, base * CFrame.new(math.cos(a) * 3.6, s.Y * 0.35, math.sin(a) * 3.6) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), LILAC)
	end
	local goo = Instance.new("Part")
	goo.Name = "Goo"; goo.Shape = Enum.PartType.Cylinder; goo.Size = Vector3.new(0.7, 7.2, 7.2)
	goo.CFrame = base * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90))
	goo.Color = GOO; goo.Material = Enum.Material.Neon; goo.Transparency = 0.15
	anchorDeco(goo); goo.Parent = m
	local blob = Instance.new("Part")
	blob.Name = "GooBlob"; blob.Shape = Enum.PartType.Ball; blob.Size = Vector3.new(3.2, 3.2, 3.2)
	blob.CFrame = base * CFrame.new(0.4, 0.45, -0.3); blob.Color = GOO:Lerp(Color3.new(1, 1, 1), 0.25)
	blob.Material = Enum.Material.SmoothPlastic; anchorDeco(blob); blob.Parent = m
	local light = Instance.new("PointLight"); light.Color = GOO; light.Range = 9; light.Brightness = 1.2; light.Parent = goo
	m.WorldPivot = base
	return m
end

------------------------------------------------------------------ plot 1 mining corner
local plot = hub.Greybox.Plot1
local old = plot:FindFirstChild("Mining")
if old then old:Destroy() end
local mining = Instance.new("Folder"); mining.Name = "Mining"; mining.Parent = plot
local P = plot:GetPivot()
-- local x = width (-47.5..47.5), z = depth (front/crater = -42.5); Launch Pad (0,-35), sign (-41,36): corner = back-right
local SOCKETS = {
	{ "S1", 20, 22, "SmallRock" }, { "S2", 31, 19, "SmallRock" }, { "S3", 40, 28, "SmallRock" },
	{ "B1", 25, 33, "BigRock" }, { "G1", 38, 37, "GooPocket" },
	{ "D1", 12, 35, "DenseRock" }, { "D2", 41, 10, "DenseRock" },
}
for _, s in SOCKETS do
	local w = P:PointToWorldSpace(Vector3.new(s[2], 0, s[3]))
	local hit = ground(w, true)
	local base = CFrame.new(w.X, hit.Position.Y - 0.3, w.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local sock = Instance.new("Part")
	sock.Name = "Socket" .. s[1]; sock.Size = Vector3.new(1, 0.2, 1); sock.CFrame = base; sock.Transparency = 1
	anchorDeco(sock); sock:SetAttribute("For", s[4]); sock.Parent = mining
	local node
	if s[4] == "SmallRock" then node = makeRock("SmallRock", base, Vector3.new(4.2, 3.6, 3.8), LILAC, 5)
	elseif s[4] == "BigRock" then node = makeRock("BigRock", base, Vector3.new(7.4, 6.2, 6.6), LILAC, 7)
	elseif s[4] == "GooPocket" then node = makeGooPocket(base) end
	if node then
		if s[4] == "SmallRock" then node.Name = "SmallRock" .. s[1]:sub(2) end -- unique names: client and server must agree
		node.Parent = mining
		tagNode(node, s[4])
		node:SetAttribute("Plot", 1)
	end
end
table.insert(out, "plot 1 corner built")

------------------------------------------------------------------ small clusters + 12 sockets per biome
local function makeCluster(kind, base)
	local m
	if kind == "GooCluster" then
		m = hub.GooMarsh.Veins:FindFirstChildWhichIsA("Model"):Clone()
		m:ScaleTo(0.55)
	else
		m = Instance.new("Model")
		local v = hub.CrystalCanyon.Veins.AmberVein1:Clone()
		v:ScaleTo(0.5)
		for _, c in v:GetChildren() do c.Parent = m end
		v:Destroy()
	end
	for _, d in m:GetDescendants() do
		if d.Name == "MineHitbox" then d:Destroy() elseif d:IsA("BasePart") then anchorDeco(d) end
	end
	for k in m:GetAttributes() do m:SetAttribute(k, nil) end
	CS:RemoveTag(m, TAG)
	m.Name = kind
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z)
	m:PivotTo(base)
	return m
end

local function biomeClusters(biomeName, veinFolder, veinPattern, kind)
	local biome = hub[biomeName]
	for _, n in { "ClusterSockets", "Clusters" } do
		local f = biome:FindFirstChild(n)
		if f then f:Destroy() end
	end
	local sockets = Instance.new("Folder"); sockets.Name = "ClusterSockets"; sockets.Parent = biome
	local clusters = Instance.new("Folder"); clusters.Name = "Clusters"; clusters.Parent = biome
	local veins = {}
	for _, v in veinFolder:GetChildren() do if v.Name:match(veinPattern) then table.insert(veins, v) end end
	-- 12 sockets: every vein gets one, the first 4 get a second, 13-19 studs out on open, flat-ish terrain
	local made = 0
	for round = 1, 2 do
		for i, v in veins do
			if made >= 12 or (round == 2 and i > 4) then continue end
			local c = v:GetPivot().Position
			for try = 1, 24 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(13, 19)
				local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				local hit = ground(p, false)
				if hit and hit.Instance == workspace.Terrain and hit.Normal.Y > 0.8 and hit.Material ~= Enum.Material.Water then
					local ok = true
					for _, s in sockets:GetChildren() do if (s.Position - hit.Position).Magnitude < 10 then ok = false end end
					if ok then
						made += 1
						local s = Instance.new("Part")
						s.Name = "Socket" .. made; s.Size = Vector3.new(1, 0.2, 1); s.Transparency = 1; anchorDeco(s)
						s.CFrame = CFrame.new(hit.Position - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
						s.Parent = sockets
						break
					end
				end
			end
		end
	end
	local list = sockets:GetChildren()
	for i = 1, math.min(6, #list) do
		local s = list[i]
		local m = makeCluster(kind, s.CFrame)
		m.Name = kind .. i
		m:SetAttribute("ClusterOf", biomeName)
		m:SetAttribute("Socket", s.Name)
		m.Parent = clusters
		tagNode(m, kind)
	end
	table.insert(out, biomeName .. ": " .. #list .. " sockets, " .. #clusters:GetChildren() .. " clusters")
end
biomeClusters("GooMarsh", hub.GooMarsh.Veins, "^gmVein", "GooCluster")
biomeClusters("CrystalCanyon", hub.CrystalCanyon.Veins, "^AmberVein", "CrystalCluster")

------------------------------------------------------------------ pickaxes T1..T5 (handle along +Y, arms along +-Z)
local AF = RS.AlienFusion
local oldP = AF:FindFirstChild("Pickaxes")
if oldP then oldP:Destroy() end
local picks = Instance.new("Folder"); picks.Name = "Pickaxes"; picks.Parent = AF

local TIERS = {
	{ head = Color3.fromRGB(150, 145, 165), headMat = Enum.Material.Slate, collar = Color3.fromRGB(120, 116, 132), handle = Color3.fromRGB(128, 78, 42), bands = false, edge = nil, len = 3.4, arm = 1.0 },
	{ head = Color3.fromRGB(185, 185, 198), headMat = Enum.Material.Metal, collar = Color3.fromRGB(140, 140, 155), handle = Color3.fromRGB(120, 70, 38), bands = Color3.fromRGB(175, 175, 188), edge = nil, len = 3.6, arm = 1.15 },
	{ head = Color3.fromRGB(165, 165, 190), headMat = Enum.Material.Metal, collar = Color3.fromRGB(95, 100, 135), handle = Color3.fromRGB(70, 60, 110), bands = Color3.fromRGB(60, 70, 140), edge = Color3.fromRGB(90, 230, 255), len = 3.7, arm = 1.2, emblem = Color3.fromRGB(90, 230, 255) },
	{ head = AMBER, headMat = Enum.Material.SmoothPlastic, collar = Color3.fromRGB(150, 120, 90), handle = Color3.fromRGB(115, 68, 36), bands = Color3.fromRGB(150, 145, 160), edge = Color3.fromRGB(255, 200, 80), len = 3.8, arm = 1.25, emblem = AMBER },
	{ head = Color3.fromRGB(150, 135, 200), headMat = Enum.Material.Metal, collar = Color3.fromRGB(70, 60, 100), handle = Color3.fromRGB(50, 40, 75), bands = VIOLET, edge = Color3.fromRGB(190, 90, 255), len = 3.9, arm = 1.3, emblem = Color3.fromRGB(200, 120, 255), sparks = true },
}

local function part(model, name, shape, size, cf, color, mat)
	local p = (shape == "Wedge") and Instance.new("WedgePart") or Instance.new("Part")
	if shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
	p.Parent = model
	return p
end

for t, d in TIERS do
	local m = Instance.new("Model"); m.Name = "T" .. t
	local L = d.len
	local handle = part(m, "Handle", "Block", Vector3.new(0.36, L, 0.36), CFrame.new(), d.handle, Enum.Material.Wood)
	local top = L / 2
	-- collar (hex-ish: two crossed blocks) at the top
	part(m, "Collar", "Block", Vector3.new(0.8, 0.9, 0.8), CFrame.new(0, top, 0), d.collar, Enum.Material.Metal)
	part(m, "Collar2", "Block", Vector3.new(0.8, 0.9, 0.8), CFrame.new(0, top, 0) * CFrame.Angles(0, math.rad(45), 0), d.collar, Enum.Material.Metal)
	if d.emblem then
		local e = part(m, "Emblem", "Cylinder", Vector3.new(0.08, 0.38, 0.38), CFrame.new(0.45, top, 0), d.emblem, Enum.Material.Neon)
		local e2 = e:Clone(); e2.CFrame = CFrame.new(-0.45, top, 0); e2.Parent = m
	end
	-- the two arms: out along +-Z, drooping toward the handle, tapering to a point
	for _, side in { 1, -1 } do
		local segs = { { 0.55, 0.78, 0.56, -10 }, { 0.5, 0.62, 0.5, -28 }, { 0.42, 0.48, 0.42, -48 } }
		local pos = Vector3.new(0, top + 0.08, 0.3 * side)
		local ang = 0
		for i, s in segs do
			ang = s[4]
			local len = s[1] * d.arm * 0.85
			local rot = CFrame.Angles(math.rad(-ang) * side, 0, 0)
			local cf = CFrame.new(pos) * rot * CFrame.new(0, 0, len / 2 * side)
			local seg = part(m, "Head", "Block", Vector3.new(s[3], s[2], len), cf, d.head, d.headMat)
			if d.headMat == Enum.Material.Glass then seg.Transparency = 0.1 end
			if d.edge then
				part(m, "Edge", "Block", Vector3.new(s[3] * 0.7, 0.1, len * 0.95), cf * CFrame.new(0, -s[2] / 2 - 0.02, 0), d.edge, Enum.Material.Neon)
			end
			pos = (cf * CFrame.new(0, 0, len / 2 * side)).Position
		end
		-- tip wedge
		local tipCf = CFrame.new(pos) * CFrame.Angles(math.rad(-62) * side, 0, 0) * CFrame.new(0, 0, 0.22 * side)
		local tip = part(m, "Tip", "Wedge", Vector3.new(0.34, 0.34, 0.45), tipCf * (side == 1 and CFrame.Angles(0, math.rad(180), 0) or CFrame.new()), d.head, d.headMat)
		if d.edge then tip.Color = d.edge; tip.Material = Enum.Material.Neon end
	end
	-- pommel + bands
	part(m, "Pommel", "Block", Vector3.new(0.46, 0.34, 0.46), CFrame.new(0, -top - 0.1, 0), d.bands or d.handle, d.bands and Enum.Material.Metal or Enum.Material.Wood)
	if d.bands then
		part(m, "Band", "Cylinder", Vector3.new(0.22, 0.42, 0.42), CFrame.new(0, -top + 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), d.bands, Enum.Material.Metal)
		part(m, "Band2", "Cylinder", Vector3.new(0.22, 0.42, 0.42), CFrame.new(0, -top + 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), d.bands, Enum.Material.Metal)
	end
	if t >= 3 then
		local l = Instance.new("PointLight"); l.Color = d.edge; l.Range = 5; l.Brightness = 0.8; l.Parent = handle
	end
	if d.sparks then
		local a = Instance.new("Attachment"); a.Position = Vector3.new(0, top, 0); a.Parent = handle
		local pe = Instance.new("ParticleEmitter"); pe.Color = ColorSequence.new(Color3.fromRGB(200, 120, 255)); pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }); pe.Rate = 10
		pe.Lifetime = NumberRange.new(0.4, 0.8); pe.Speed = NumberRange.new(0.5, 1.5); pe.SpreadAngle = Vector2.new(180, 180); pe.Parent = a
	end
	-- grip on the handle's lower third; its look (-Z) runs up the handle, its up (+Y) along the arms
	local grip = Instance.new("Attachment"); grip.Name = "Grip"
	grip.CFrame = CFrame.fromMatrix(Vector3.new(0, -top + 0.8, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
	grip.Parent = handle
	m.PrimaryPart = handle
	m.Parent = picks
end
table.insert(out, "pickaxes T1-T5 built")
return table.concat(out, "\n")
