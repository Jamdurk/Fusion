-- MiningService: server-owned mining (feel r3, 1 Nov 2026). Every tap / click is ONE swing (holding repeats it on the
-- client); the client plays the swing at once and sends Swing(node, seq). The server checks the swing rate, reach,
-- line of sight and plot owner, applies the damage, and answers with the true HP (or why it was refused). It owns HP,
-- per-player depletion and rewards. Numbers: ReplicatedStorage.AlienFusion.MiningConfig (design\economy\).
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local AF = RS:WaitForChild("AlienFusion")
local Cfg = require(AF:WaitForChild("MiningConfig"))

local remotes = AF:FindFirstChild("MiningRemotes")
if not remotes then
	remotes = Instance.new("Folder"); remotes.Name = "MiningRemotes"; remotes.Parent = AF
end
local function remote(name)
	local r = remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes end
	return r
end
for _, old in { "Start", "Stop" } do -- (r2's tap-once remotes)
	local r = remotes:FindFirstChild(old)
	if r then r:Destroy() end
end
local SwingRE, ResultRE = remote("Swing"), remote("Result")

-- MOVE TEST menu's PICKAXE buttons: any tier into your hand while testing (MiningConfig.TEST_PICKS; off at launch, when
-- the tycoon pads sell them)
remote("TestPick").OnServerEvent:Connect(function(player, tier)
	if Cfg.TEST_PICKS and typeof(tier) == "number" and Cfg.Picks[tier] then player:SetAttribute("PickTier", tier) end
end)

local hpOf = {} -- [player][node] = { hp, t }
local depleted = {} -- [player][node] = os.clock() when it refills
local due = {} -- [player] = os.clock() the next swing is due (switching deposits can't skip it)
local lastHit = {} -- [player] = { node, t } (cluster rotation waits for a deposit being mined)
local reqLog = {} -- [player] = { n, windowStart }

local function nodeInfo(node)
	if typeof(node) ~= "Instance" or not CS:HasTag(node, Cfg.TAG) or not node:IsDescendantOf(workspace) then return end
	local def = Cfg.Nodes[node:GetAttribute("NodeType")]
	local box = node:FindFirstChild("MineHitbox")
	if not def or not box then return end
	return def, box
end

-- distance from a point to the deposit's hitbox SURFACE (veins are 10-20 studs wide, so never the centre)
local function surfaceDistance(box, p)
	local lp = box.CFrame:PointToObjectSpace(p)
	local h = box.Size / 2
	local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
	local wp = box.CFrame:PointToWorldSpace(c)
	return (wp - p).Magnitude, wp
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true -- only solid parts + terrain can block a swing

-- plot deposits (attribute Plot = n) belong to that plot's owner (Plot<n> attribute OwnerUserId); an unclaimed plot is
-- open to anyone until plots get owners
local function plotAllows(player, node)
	local n = node:GetAttribute("Plot")
	if not n then return true end
	local plot = workspace.Hub:FindFirstChild("Greybox") and workspace.Hub.Greybox:FindFirstChild("Plot" .. n)
	local owner = plot and plot:GetAttribute("OwnerUserId")
	return owner == nil or owner == player.UserId
end

-- alive, in range of the surface, and a clear line from the chest to the deposit. Cliffs and terrain walls block; the
-- ground at a rock's foot doesn't, because it passes if ANY of three aim points (nearest surface point, centre, top) is
-- clear. Returns nil or the refusal reason the client shows.
local function refusal(player, node, box)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then return "dead" end
	if not plotAllows(player, node) then return "notyours" end
	local d, wp = surfaceDistance(box, root.Position)
	if d > Cfg.RANGE + Cfg.RANGE_SLACK then return "far" end
	if d < 0.5 then return nil end -- standing against / inside its hitbox
	rayParams.FilterDescendantsInstances = { char, node }
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	for _, aim in { wp, box.Position, box.Position + Vector3.new(0, box.Size.Y * 0.4, 0) } do
		local hit = workspace:Raycast(eye, aim - eye, rayParams)
		if not hit or (hit.Position - aim).Magnitude < 0.75 then return nil end
	end
	return "blocked"
end

local function rateOk(player)
	local now = os.clock()
	local r = reqLog[player]
	if not r or now - r.windowStart > 1 then r = { n = 0, windowStart = now }; reqLog[player] = r end
	r.n += 1
	return r.n <= Cfg.MAX_REQUESTS_PER_SEC
end

local function award(player, def)
	for res, amt in def.reward do
		player:SetAttribute(res, (player:GetAttribute(res) or 0) + amt)
	end
end

SwingRE.OnServerEvent:Connect(function(player, node, seq)
	if not rateOk(player) then
		-- The client has already counted this swing as pending. Always answer,
		-- even when throttled, so its predicted HP can be reconciled.
		ResultRE:FireClient(player, "refused", node, "rate", seq)
		return
	end
	local def, box = nodeInfo(node)
	if not def then return end
	local now = os.clock()
	-- the swing clock: a swing may arrive SWING_SLACK early (jitter), but `due` always moves on a full interval from
	-- where it was, so the long-run rate can't beat 1 per SWING_INTERVAL however fast the taps come
	local d = due[player] or 0
	if now < d - Cfg.SWING_SLACK then ResultRE:FireClient(player, "refused", node, "wait", seq) return end
	local dep = depleted[player] and depleted[player][node]
	if dep and now < dep then ResultRE:FireClient(player, "refused", node, "empty", seq) return end
	local why = refusal(player, node, box)
	if why then ResultRE:FireClient(player, "refused", node, why, seq) return end
	due[player] = math.max(d, now - Cfg.SWING_SLACK) + Cfg.SWING_INTERVAL
	lastHit[player] = { node = node, t = now }
	-- everyone else nearby sees this player swing (the swinger already did, locally)
	for _, other in Players:GetPlayers() do
		if other ~= player then SwingRE:FireClient(other, player, node) end
	end
	local tier = Cfg.Picks[player:GetAttribute("PickTier") or 1] or Cfg.Picks[1]
	hpOf[player] = hpOf[player] or {}
	local rec = hpOf[player][node]
	if not rec or now - rec.t > Cfg.HP_FORGET then rec = { hp = def.hp }; hpOf[player][node] = rec end
	rec.hp -= tier.damage
	rec.t = now
	if rec.hp > 0 then
		ResultRE:FireClient(player, "hit", node, rec.hp, def.hp, seq)
		return
	end
	-- break: deplete + pay in the same step, so two swings can never pay one deposit twice
	hpOf[player][node] = nil
	depleted[player] = depleted[player] or {}
	depleted[player][node] = now + def.respawn
	award(player, def)
	ResultRE:FireClient(player, "break", node, def.reward, def.respawn, seq)
end)

-- small clusters hop between their biome's sockets (folder <Biome>.ClusterSockets, clusters carry attribute ClusterOf).
-- The cluster Model IS the stable id, so a player's refill timer moves with it. One hit in the last 3 s waits.
local function rotateClusters()
	local byBiome = {}
	for _, node in CS:GetTagged(Cfg.TAG) do
		local biome = node:GetAttribute("ClusterOf")
		if biome and node:IsDescendantOf(workspace) then
			byBiome[biome] = byBiome[biome] or {}
			table.insert(byBiome[biome], node)
		end
	end
	local busy = {}
	local now = os.clock()
	for _, h in lastHit do
		if now - h.t < 3 then busy[h.node] = true end
	end
	for biome, nodes in byBiome do
		local folder = workspace.Hub:FindFirstChild(biome)
		local sockets = folder and folder:FindFirstChild("ClusterSockets")
		if sockets then
			local free = {}
			for _, s in sockets:GetChildren() do free[s] = true end
			for _, n in nodes do
				if busy[n] then
					local s = sockets:FindFirstChild(n:GetAttribute("Socket") or "")
					if s then free[s] = nil end
				end
			end
			local pool = {}
			for s in free do table.insert(pool, s) end
			for _, n in nodes do
				if not busy[n] and #pool > 0 then
					local s = table.remove(pool, math.random(#pool))
					n:PivotTo(s.CFrame)
					n:SetAttribute("Socket", s.Name)
				end
			end
		end
	end
end
task.spawn(function()
	while true do
		task.wait(Cfg.CLUSTER_ROTATE)
		rotateClusters()
	end
end)

-- the pick is always in hand (no hotbar on phone): the current tier's model welded to the right hand (R15 RightHand, or
-- the bottom of an R6 Right Arm), so it fits any avatar
local function giveDefaults(player)
	for res in Cfg.Resources do
		if player:GetAttribute(res) == nil then player:SetAttribute(res, 0) end
	end
	if player:GetAttribute("PickTier") == nil then player:SetAttribute("PickTier", 1) end
end

local function equipPick(player, char)
	char = char or player.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	local hand, handCF
	if hum.RigType == Enum.HumanoidRigType.R6 then
		hand = char:WaitForChild("Right Arm", 5)
		handCF = hand and hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 + 0.15, 0)
	else
		hand = char:WaitForChild("RightHand", 5)
		handCF = hand and hand.CFrame
	end
	if not hand then return end
	local old = char:FindFirstChild("Pickaxe")
	if old then old:Destroy() end
	local tier = player:GetAttribute("PickTier") or 1
	local src = AF:FindFirstChild("Pickaxes") and AF.Pickaxes:FindFirstChild("T" .. tier)
	if not src then return end
	local pick = src:Clone()
	pick.Name = "Pickaxe"
	local handle = pick:FindFirstChild("Handle")
	for _, p in pick:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
		end
	end
	local grip = handle:FindFirstChild("Grip")
	pick:PivotTo(handCF * (grip and grip.CFrame:Inverse() or CFrame.new()))
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand; w.Part1 = handle; w.Parent = handle
	-- every other piece (head, collar, bands) welds to the handle, or it falls off once unanchored (1 Nov: "just a stick")
	for _, p in pick:GetDescendants() do
		if p:IsA("BasePart") and p ~= handle then
			local pw = Instance.new("WeldConstraint")
			pw.Part0 = handle; pw.Part1 = p; pw.Parent = p
		end
	end
	pick.Parent = char
end

local function onPlayer(player)
	giveDefaults(player)
	player.CharacterAdded:Connect(function(char) equipPick(player, char) end)
	player:GetAttributeChangedSignal("PickTier"):Connect(function() equipPick(player) end)
	if player.Character then task.spawn(equipPick, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	hpOf[player], depleted[player], due[player], lastHit[player], reqLog[player] = nil, nil, nil, nil, nil
end)
