-- Alien Fusion tycoon, slice 1 (1 Nov 2026): plot 1 only, session-only (no saving yet).
-- Buy pads (stand on one: Drill 20 Rock -> Incubator 30 Rock), the drill pays the plot owner 8 Rock/min, the incubator's
-- two chambers hatch eggs (12 DNA, 12 s; SQUISH = Goo DNA -> Drip, CRUNCH = Crystal DNA -> Pebble) with a REPEAT each.
-- The server rolls the look, spawns the alien (celebrates at the incubator, then walks the army ring round the Launch
-- Pad) and tells the owner's client to show the hatch card. Numbers: TycoonConfig. Models: tools\tycoon-setup.luau.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local AF = RS:WaitForChild("AlienFusion")
local Cfg = require(AF:WaitForChild("TycoonConfig"))
local kit = SS:WaitForChild("TycoonKit")
local forms = SS:WaitForChild("Aliens"):WaitForChild("Forms")
local plot = workspace:WaitForChild("Hub"):WaitForChild("Greybox"):WaitForChild("Plot" .. Cfg.PLOT)
local P = plot:GetPivot()

local remotes = AF:FindFirstChild("TycoonRemotes")
if not remotes then remotes = Instance.new("Folder"); remotes.Name = "TycoonRemotes"; remotes.Parent = AF end
local function remote(name)
	local r = remotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes end
	return r
end
local NotifyRE, HatchRE, DrillPayRE = remote("Notify"), remote("Hatch"), remote("DrillPay")

-- the hatch card shows the alien in a ViewportFrame, so the client needs a copy of each egg's form
local cardForms = AF:FindFirstChild("TycoonForms") or Instance.new("Folder")
cardForms.Name = "TycoonForms"; cardForms.Parent = AF
for _, e in Cfg.Eggs do
	if not cardForms:FindFirstChild(e.form) and forms:FindFirstChild(e.form) then forms[e.form]:Clone().Parent = cardForms end
end

local units = workspace:FindFirstChild("Units")
if not units then units = Instance.new("Folder"); units.Name = "Units"; units.Parent = workspace end
local folder = plot:FindFirstChild("Tycoon")
if folder then folder:Destroy() end
folder = Instance.new("Folder"); folder.Name = "Tycoon"; folder.Parent = plot

local NEON = Color3.fromRGB(120, 255, 70)
local LOCKED = Color3.fromRGB(90, 92, 104)
local rng = Random.new()

------------------------------------------------------------------ plot geometry
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { plot, units }
local function plotPos(v: Vector2): Vector3
	local w = P:PointToWorldSpace(Vector3.new(v.X, 0, v.Y))
	local skip = { plot, units }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(skip, p.Character) end end
	rayParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(w + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), rayParams)
	return Vector3.new(w.X, hit and hit.Position.Y or (P.Y - 3.25), w.Z)
end
-- a machine stands on its centre and faces its pad (its front = -Z)
local function machineCF(def)
	local c, t = plotPos(def.centre), plotPos(def.pad)
	return CFrame.lookAt(c, Vector3.new(t.X, c.Y, t.Z))
end

------------------------------------------------------------------ session state
local owner: Player? = nil
local bought = {}
local pads = {}
local serial = 0
local joinT = {}

local function notify(player, text) NotifyRE:FireClient(player, text) end
local function track(player, event) -- (onboarding funnel, plan: first rock, drill, incubator, first hatch)
	print(("[AF onboarding] %s %s at %ds"):format(player.Name, event, math.floor(os.clock() - (joinT[player] or os.clock()))))
end

local function burst(pos: Vector3, color: Color3, n: number)
	local a = Instance.new("Part")
	a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false; a.Transparency = 1
	a.Size = Vector3.one; a.Position = pos; a.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color); pe.LightEmission = 1; pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(10, 22); pe.SpreadAngle = Vector2.new(180, 180); pe.Rate = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Acceleration = Vector3.new(0, -30, 0); pe.Parent = a
	pe:Emit(n)
	task.delay(1.5, function() a:Destroy() end)
end

------------------------------------------------------------------ pads
local function hexPart(parent, name, width, height, cf, color, mat)
	-- three boxes at 0 / 60 / 120 degrees make a flat-sided hexagon `width` across
	for i = 0, 2 do
		local p = Instance.new("Part")
		p.Name = name; p.Size = Vector3.new(width / math.sqrt(3), height, width); p.CFrame = cf * CFrame.Angles(0, math.rad(i * 60), 0)
		p.Color = color; p.Material = mat; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth; p.Parent = parent
	end
end

local function ghostOf(name, cf, color, transparency)
	local g = kit[name]:Clone()
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.ForceField; d.Color = color; d.Transparency = transparency
			d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	for _, t in CS:GetTags(g) do CS:RemoveTag(g, t) end
	for _, d in g:GetDescendants() do for _, t in CS:GetTags(d) do CS:RemoveTag(d, t) end end
	g.Name = "Ghost"; g:PivotTo(cf)
	return g
end

local tryBuy -- (forward)
local function makePad(name)
	local def = Cfg.Machines[name]
	local locked = def.needs ~= nil and not bought[def.needs]
	local m = Instance.new("Model"); m.Name = name .. "Pad"
	local base = plotPos(def.pad)
	local cf = CFrame.new(base) * P.Rotation
	hexPart(m, "Base", 6.4, 0.6, cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(40, 42, 52), Enum.Material.SmoothPlastic)
	hexPart(m, "Top", 5.2, 0.25, cf * CFrame.new(0, 0.65, 0), locked and LOCKED or NEON, locked and Enum.Material.SmoothPlastic or Enum.Material.Neon)
	local hit = Instance.new("Part")
	hit.Name = "Hit"; hit.Size = Vector3.new(5.2, 4, 5.2); hit.CFrame = cf * CFrame.new(0, 2, 0); hit.Transparency = 1
	hit.Anchored = true; hit.CanCollide = false; hit.CanQuery = false; hit.CanTouch = true; hit.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"; bb.Size = UDim2.fromOffset(200, 74); bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0); bb.MaxDistance = 140
	bb.LightInfluence = 0; bb.Adornee = hit; bb.Parent = m
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1); frame.BackgroundColor3 = Color3.fromRGB(16, 18, 26); frame.BackgroundTransparency = 0.1
	frame.Parent = bb
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = locked and LOCKED or NEON; stroke.Parent = frame
	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1; top.Size = UDim2.new(1, 0, 0.4, 0); top.Font = Enum.Font.GothamBlack; top.TextScaled = true
	top.TextColor3 = locked and Color3.fromRGB(170, 170, 185) or Color3.new(1, 1, 1)
	top.Text = locked and ("LOCKED: BUY THE " .. Cfg.Machines[def.needs].label .. " FIRST") or ("BUY " .. def.label)
	top.Parent = frame
	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1; price.Position = UDim2.fromScale(0, 0.38); price.Size = UDim2.fromScale(1, 0.62)
	price.Font = Enum.Font.FredokaOne; price.TextScaled = true; price.TextColor3 = locked and LOCKED or NEON
	price.Text = def.price .. " ROCK"; price.Parent = frame
	for _, l in { top, price } do
		local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
		pad.PaddingTop = UDim.new(0, 4); pad.Parent = l
	end
	ghostOf(name, machineCF(def), locked and LOCKED or NEON, locked and 0.9 or 0.8).Parent = m
	m.Parent = folder
	local busy = {}
	hit.Touched:Connect(function(other)
		local plr = Players:GetPlayerFromCharacter(other.Parent)
		if not plr or busy[plr] or other.Name ~= "HumanoidRootPart" then return end
		busy[plr] = true
		tryBuy(plr, name)
		task.delay(1.5, function() busy[plr] = nil end)
	end)
	pads[name] = m
end

local function refreshPads()
	for name in Cfg.Machines do
		if pads[name] then pads[name]:Destroy(); pads[name] = nil end
		if not bought[name] then makePad(name) end
	end
end

------------------------------------------------------------------ aliens
local function rollLook(player)
	if not player:GetAttribute("HatchedOnce") then
		player:SetAttribute("HatchedOnce", true)
		return Cfg.FIRST_LOOK
	end
	local r, acc = rng:NextNumber(0, 100), 0
	for _, L in Cfg.Looks do
		acc += L.chance
		if r < acc then return L.name end
	end
	return "Normal"
end
local function lookDef(name) for _, L in Cfg.Looks do if L.name == name then return L end end return Cfg.Looks[1] end

local function applyLook(m: Model, look: string, e)
	local L = lookDef(look)
	if L.name == "Normal" then return end
	local h = Instance.new("Highlight")
	h.Name = "Look"; h.FillColor = L.fill or e.color; h.FillTransparency = L.fill and 0.3 or 0.6
	h.OutlineColor = L.glow and e.color or Color3.new(1, 1, 1); h.OutlineTransparency = 0.2; h.Parent = m
	if L.glow or L.rare then
		local light = Instance.new("PointLight"); light.Color = L.fill or e.color; light.Brightness = 2; light.Range = 10
		light.Parent = m.PrimaryPart
	end
	if L.rainbow then CS:AddTag(h, "RainbowLook") end
end

-- a unit the AlienAnimator plays: Mode idle + Speed 0 stands still; no Mode = walks the circle (Centre, Radius, Speed, T0)
local function makeUnit(e, look, player, centre: Vector3, mode, radius, speed, t0)
	local m = forms[e.form]:Clone()
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	m:SetAttribute("FormName", e.form); m:SetAttribute("Race", e.race); m:SetAttribute("Form", 1)
	if mode then m:SetAttribute("Mode", mode) end
	m:SetAttribute("CentreX", centre.X); m:SetAttribute("CentreZ", centre.Z); m:SetAttribute("Radius", radius)
	m:SetAttribute("Speed", speed); m:SetAttribute("T0", t0)
	m:SetAttribute("Owner", player.UserId); m:SetAttribute("Look", look)
	applyLook(m, look, e)
	m:PivotTo(CFrame.new(centre + Vector3.new(radius, 0, 0)))
	m.Parent = units
	return m
end

local function addToArmy(player, e, look)
	serial += 1
	local army = player:FindFirstChild("Army")
	if not army then army = Instance.new("Folder"); army.Name = "Army"; army.Parent = player end
	local v = Instance.new("StringValue")
	v.Name = tostring(serial); v.Value = e.alien; v:SetAttribute("Look", look); v:SetAttribute("Form", e.form); v.Parent = army
	player:SetAttribute("ArmySize", #army:GetChildren())
	return #army:GetChildren()
end

local function hatchAlien(player, ch, e)
	local look = rollLook(player)
	local n = addToArmy(player, e, look)
	local spawn = ch.Spawn.Position
	local now = workspace:GetServerTimeNow()
	local m = makeUnit(e, look, player, spawn, "idle", 0.01, 0, now)
	m.Name = e.alien .. " " .. serial
	burst(spawn + Vector3.new(0, 2, 0), e.color, lookDef(look).rare and 70 or 35)
	HatchRE:FireClient(player, { alien = e.alien, look = look, rare = lookDef(look).rare == true, form = e.form, unit = m })
	if n == 1 then track(player, "first hatch") end
	-- celebrate at the incubator, then join the ring round the Launch Pad (the animator picks a unit's gait once, so it
	-- re-enters as a walker); slots spread round the ring by army number
	task.delay(Cfg.CELEBRATE_TIME, function()
		if not m.Parent or owner ~= player then return end
		m:Destroy()
		local R = Cfg.ARMY_RING
		local k = (n - 1) % R.slots
		local t1 = workspace:GetServerTimeNow() - (k * 2 * math.pi * R.radius / R.slots) / R.speed
		local w = makeUnit(e, look, player, plotPos(R.centre), nil, R.radius, R.speed, t1)
		w.Name = e.alien .. " " .. serial
	end)
end

------------------------------------------------------------------ incubator chambers
local function chamberParts(ch) return ch:FindFirstChild("Dome"), ch:FindFirstChild("Repeat") end

local startHatch -- (forward)
local function tryRepeat(ch)
	if ch.Parent and ch:GetAttribute("Repeat") and ch:GetAttribute("State") == "idle" and owner then startHatch(ch, owner, true) end
end

function startHatch(ch, player, auto)
	local e = Cfg.Eggs[ch:GetAttribute("Egg")]
	if ch:GetAttribute("State") ~= "idle" then return end
	local have = player:GetAttribute(e.res) or 0
	if have < e.cost then
		if not auto then notify(player, ("NEED %d %s (YOU HAVE %d)"):format(e.cost, e.resLabel, have)) end
		return
	end
	player:SetAttribute(e.res, have - e.cost)
	ch:SetAttribute("State", "hatching")
	ch:SetAttribute("EndsAt", workspace:GetServerTimeNow() + e.time)
	local dome = chamberParts(ch)
	local hp = dome and dome:FindFirstChild("HatchPrompt")
	if hp then hp.Enabled = false end
	task.delay(e.time, function()
		if not ch.Parent or owner ~= player then return end
		ch:SetAttribute("State", "idle")
		if hp then hp.Enabled = true end
		hatchAlien(player, ch, e)
		tryRepeat(ch)
	end)
end

local function setupIncubator(machine)
	for _, ch in machine:GetChildren() do
		local side = ch:GetAttribute("Egg")
		local e = side and Cfg.Eggs[side]
		if not e then continue end
		ch:SetAttribute("State", "idle"); ch:SetAttribute("EndsAt", 0); ch:SetAttribute("Repeat", false)
		ch:SetAttribute("Cost", e.cost); ch:SetAttribute("ResLabel", e.resLabel); ch:SetAttribute("Time", e.time)
		local dome, rep = chamberParts(ch)
		local hp = Instance.new("ProximityPrompt")
		hp.Name = "HatchPrompt"; hp.ActionText = "HATCH EGG"; hp.ObjectText = ("%s EGG - %d %s"):format(side:upper(), e.cost, e.resLabel)
		hp.KeyboardKeyCode = Enum.KeyCode.E; hp.MaxActivationDistance = 14; hp.RequiresLineOfSight = false; hp.HoldDuration = 0
		hp.Parent = dome
		hp.Triggered:Connect(function(plr) if plr == owner then startHatch(ch, plr) end end)
		local rp = Instance.new("ProximityPrompt")
		rp.Name = "RepeatPrompt"; rp.ActionText = "REPEAT: OFF"; rp.ObjectText = side:upper() .. " EGGS"
		rp.KeyboardKeyCode = Enum.KeyCode.R; rp.MaxActivationDistance = 14; rp.RequiresLineOfSight = false; rp.HoldDuration = 0
		rp.Parent = rep
		rp.Triggered:Connect(function(plr)
			if plr ~= owner then return end
			local on = not ch:GetAttribute("Repeat")
			ch:SetAttribute("Repeat", on)
			rp.ActionText = on and "REPEAT: ON" or "REPEAT: OFF"
			local light = ch:FindFirstChild("RepeatLight")
			if light then light.Color = on and NEON or Color3.fromRGB(60, 60, 70) end
			notify(plr, on and ("%s EGGS REPEAT ON: HATCHES WHENEVER YOU HAVE %d %s"):format(side:upper(), e.cost, e.resLabel)
				or (side:upper() .. " EGGS REPEAT OFF"))
			tryRepeat(ch)
		end)
	end
end

------------------------------------------------------------------ buying
local function build(name)
	local def = Cfg.Machines[name]
	local m = kit[name]:Clone()
	local cf = machineCF(def)
	m:PivotTo(cf)
	m:ScaleTo(0.25)
	m.Parent = folder
	for i = 1, 10 do m:ScaleTo(0.25 + 0.075 * i); task.wait(0.03) end
	burst(cf.Position + Vector3.new(0, 4, 0), NEON, 60)
	if name == "Drill" then
		m.RateBoard.Rate.Text.Text = ("+%d ROCK / MIN"):format(Cfg.DRILL_PER_MIN)
		task.spawn(function()
			while m.Parent do
				task.wait(60 / Cfg.DRILL_PER_MIN)
				if not m.Parent or not owner then break end
				owner:SetAttribute("Rock", (owner:GetAttribute("Rock") or 0) + 1)
				DrillPayRE:FireClient(owner, m)
			end
		end)
	elseif name == "Incubator" then
		setupIncubator(m)
	end
	return m
end

function tryBuy(player, name)
	local def = Cfg.Machines[name]
	if bought[name] then return end
	if player ~= owner then notify(player, "THIS IS NOT YOUR BASE"); return end
	if def.needs and not bought[def.needs] then notify(player, "BUY THE " .. Cfg.Machines[def.needs].label .. " FIRST"); return end
	local rock = player:GetAttribute("Rock") or 0
	if rock < def.price then notify(player, ("NEED %d ROCK (YOU HAVE %d) - MINE THE ROCKS ON YOUR BASE"):format(def.price, rock)); return end
	player:SetAttribute("Rock", rock - def.price)
	bought[name] = true
	track(player, name .. " bought")
	refreshPads()
	build(name)
	notify(player, def.label .. " BUILT!")
end

------------------------------------------------------------------ owner (session-only)
local function resetPlot()
	for _, c in folder:GetChildren() do c:Destroy() end
	for _, u in units:GetChildren() do if u:GetAttribute("Owner") and owner and u:GetAttribute("Owner") == owner.UserId then u:Destroy() end end
	bought, pads = {}, {}
	owner = nil
	plot:SetAttribute("OwnerUserId", nil)
end

local function claim(player)
	owner = player
	plot:SetAttribute("OwnerUserId", player.UserId)
	refreshPads()
	notify(player, "THIS IS YOUR MOON BASE! MINE ROCK, THEN STAND ON THE GREEN PAD")
end

local function onPlayer(player)
	joinT[player] = os.clock()
	if not player:GetAttribute("StarterGoo") then
		player:SetAttribute("StarterGoo", true)
		player:SetAttribute("GooDNA", (player:GetAttribute("GooDNA") or 0) + Cfg.STARTER_GOO)
	end
	local firstRock
	firstRock = player:GetAttributeChangedSignal("Rock"):Connect(function()
		if (player:GetAttribute("Rock") or 0) > 0 then track(player, "first rock"); firstRock:Disconnect() end
	end)
	-- REPEAT chambers start again as soon as you have the DNA (mined while away)
	for _, e in Cfg.Eggs do
		player:GetAttributeChangedSignal(e.res):Connect(function()
			if player ~= owner then return end
			for _, ch in CS:GetTagged("EggChamber") do if ch:IsDescendantOf(folder) then tryRepeat(ch) end end
		end)
	end
	if not owner then claim(player) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	joinT[player] = nil
	if player ~= owner then return end
	resetPlot()
	for _, p in Players:GetPlayers() do
		if p ~= player then claim(p); break end
	end
end)
