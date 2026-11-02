-- MiningClient (feel r3, 1 Nov 2026): tap / click a deposit = ONE swing, hold = keep swinging (0.45 s each); a far
-- deposit = walk there first. The swing + hit show at once (predicted); the server confirms the HP and pays. Draws the
-- hover outline, TAP TO MINE, the swing pose (any avatar rig), chips + shake, break pop, local depleted looks, HUD.
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local AF = RS:WaitForChild("AlienFusion")
local Cfg = require(AF:WaitForChild("MiningConfig"))
local remotes = AF:WaitForChild("MiningRemotes")
local SwingRE, ResultRE = remotes:WaitForChild("Swing"), remotes:WaitForChild("Result")
local AudioFX = RS:FindFirstChild("PolishKit") and require(RS.PolishKit.AudioFX)

local camera = workspace.CurrentCamera
local FONT_NUM = Enum.Font.FredokaOne
local FONT_TXT = Enum.Font.GothamBlack

local target -- far deposit we are walking to
local depletedUntil = {} -- [node] = os.clock() when it refills (this player only)
local hidden = {} -- [node] = { [part] = original props }

local function sfx(id, at, pitch)
	if AudioFX then AudioFX.play(id, { at = at, pitch = pitch, jitter = true }) end
end

local function nodeFrom(inst)
	while inst and inst ~= workspace do
		if CS:HasTag(inst, Cfg.TAG) then return inst end
		inst = inst.Parent
	end
end

local function surfacePoint(box, p)
	local lp = box.CFrame:PointToObjectSpace(p)
	local h = box.Size / 2
	return box.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z)))
end

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function distTo(node)
	local r = root()
	local box = node and node:FindFirstChild("MineHitbox")
	if not r or not box then return math.huge end
	local sp = surfacePoint(box, r.Position)
	return (Vector3.new(sp.X, r.Position.Y, sp.Z) - r.Position).Magnitude, sp
end

local function isDepleted(node)
	local t = depletedUntil[node]
	return t and os.clock() < t
end

------------------------------------------------------------------ HUD
local gui = Instance.new("ScreenGui")
gui.Name = "MiningHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0); bar.Position = UDim2.new(0.5, 0, 0, 8); bar.Size = UDim2.fromOffset(0, 56)
bar.AutomaticSize = Enum.AutomaticSize.X; bar.BackgroundTransparency = 1; bar.Parent = gui
local list = Instance.new("UIListLayout"); list.FillDirection = Enum.FillDirection.Horizontal; list.Padding = UDim.new(0, 10)
list.VerticalAlignment = Enum.VerticalAlignment.Center; list.Parent = bar

local chips = {}
local function chip(key, label, color)
	local f = Instance.new("TextButton")
	f.AutoButtonColor = false; f.Text = ""; f.Size = UDim2.fromOffset(0, 56); f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = Color3.fromRGB(22, 18, 38); f.BackgroundTransparency = 0.12; f.Parent = bar
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke", f); st.Color = color; st.Thickness = 2; st.Transparency = 0.25
	local pad = Instance.new("UIPadding", f); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 14)
	local row = Instance.new("UIListLayout", f); row.FillDirection = Enum.FillDirection.Horizontal; row.Padding = UDim.new(0, 8)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local gem = Instance.new("Frame", f); gem.Size = UDim2.fromOffset(30, 30); gem.BackgroundColor3 = color; gem.Rotation = 45
	Instance.new("UICorner", gem).CornerRadius = UDim.new(0, 6)
	local shine = Instance.new("Frame", gem); shine.Size = UDim2.fromScale(0.4, 0.4); shine.Position = UDim2.fromScale(0.15, 0.15)
	shine.BackgroundColor3 = Color3.new(1, 1, 1); shine.BackgroundTransparency = 0.45
	Instance.new("UICorner", shine).CornerRadius = UDim.new(0, 3)
	local col = Instance.new("Frame", f); col.BackgroundTransparency = 1; col.Size = UDim2.fromOffset(0, 50); col.AutomaticSize = Enum.AutomaticSize.X
	local cl = Instance.new("UIListLayout", col); cl.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = Instance.new("TextLabel", col); name.BackgroundTransparency = 1; name.Font = FONT_TXT; name.TextSize = 14
	name.TextColor3 = color; name.Text = label; name.Size = UDim2.fromOffset(0, 16); name.AutomaticSize = Enum.AutomaticSize.X
	name.TextXAlignment = Enum.TextXAlignment.Left
	local num = Instance.new("TextLabel", col); num.BackgroundTransparency = 1; num.Font = FONT_NUM; num.TextSize = 30
	num.TextColor3 = Color3.new(1, 1, 1); num.Text = "0"; num.Size = UDim2.fromOffset(0, 32); num.AutomaticSize = Enum.AutomaticSize.X
	num.TextXAlignment = Enum.TextXAlignment.Left
	local scale = Instance.new("UIScale", f)
	chips[key] = { frame = f, name = name, num = num, gem = gem, stroke = st, scale = scale }
	return chips[key]
end

local R = Cfg.Resources
chip("Rock", R.Rock.label, R.Rock.color)
local dnaChip = chip("DNA", R.GooDNA.label, R.GooDNA.color)
local dnaShown = "GooDNA" -- phone HUD: ONE DNA counter (the family you're growing); tap to swap

local function fmt(n)
	if n >= 10000 then return string.format("%.1fK", n / 1000) end
	return tostring(math.floor(n))
end

local function bump(c)
	c.scale.Scale = 1.18
	Tween:Create(c.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function refresh()
	chips.Rock.num.Text = fmt(player:GetAttribute("Rock") or 0)
	local r = R[dnaShown]
	dnaChip.name.Text = r.label; dnaChip.name.TextColor3 = r.color; dnaChip.gem.BackgroundColor3 = r.color; dnaChip.stroke.Color = r.color
	dnaChip.num.Text = fmt(player:GetAttribute(dnaShown) or 0)
end
dnaChip.frame.Activated:Connect(function()
	dnaShown = dnaShown == "GooDNA" and "CrystalDNA" or "GooDNA"
	refresh(); bump(dnaChip)
end)
for res in R do
	player:GetAttributeChangedSignal(res):Connect(function()
		if res ~= "Rock" and res ~= dnaShown then dnaShown = res end -- show the family you just mined
		refresh()
		bump(res == "Rock" and chips.Rock or dnaChip)
	end)
end
refresh()

------------------------------------------------------------------ world hints (hover outline, TAP TO MINE, HP bar)
local hl = Instance.new("Highlight")
hl.FillTransparency = 1; hl.OutlineColor = Color3.new(1, 1, 1); hl.OutlineTransparency = 0.2
hl.DepthMode = Enum.HighlightDepthMode.Occluded; hl.Enabled = false; hl.Parent = gui

local hint = Instance.new("BillboardGui")
hint.Size = UDim2.fromOffset(150, 34); hint.AlwaysOnTop = true; hint.LightInfluence = 0; hint.Enabled = false; hint.Parent = gui
local hintBg = Instance.new("TextLabel", hint)
hintBg.Size = UDim2.fromScale(1, 1); hintBg.BackgroundColor3 = Color3.fromRGB(22, 18, 38); hintBg.BackgroundTransparency = 0.15
hintBg.Font = FONT_TXT; hintBg.TextSize = 15; hintBg.TextColor3 = Color3.new(1, 1, 1)
hintBg.Text = UIS.TouchEnabled and not UIS.MouseEnabled and "TAP TO MINE" or "CLICK TO MINE"
Instance.new("UICorner", hintBg).CornerRadius = UDim.new(1, 0)

local hpGui = Instance.new("BillboardGui")
hpGui.Size = UDim2.fromOffset(120, 16); hpGui.AlwaysOnTop = true; hpGui.LightInfluence = 0; hpGui.Enabled = false; hpGui.Parent = gui
local hpBack = Instance.new("Frame", hpGui)
hpBack.Size = UDim2.fromScale(1, 1); hpBack.BackgroundColor3 = Color3.fromRGB(22, 18, 38); hpBack.BackgroundTransparency = 0.1
Instance.new("UICorner", hpBack).CornerRadius = UDim.new(1, 0)
local hpFill = Instance.new("Frame", hpBack)
hpFill.Size = UDim2.fromScale(1, 1); hpFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)
local hpStroke = Instance.new("UIStroke", hpBack); hpStroke.Thickness = 2; hpStroke.Color = Color3.fromRGB(22, 18, 38)

local function topOf(node, up)
	local box = node:FindFirstChild("MineHitbox")
	return box, Vector3.new(0, box.Size.Y / 2 + (up or 1.5), 0)
end

local function nodeColor(node)
	local def = Cfg.Nodes[node:GetAttribute("NodeType")]
	for res in def.reward do return R[res].color end
	return Color3.new(1, 1, 1)
end

------------------------------------------------------------------ deposit looks (local to this player)
local function setDepletedLook(node, on)
	local def = Cfg.Nodes[node:GetAttribute("NodeType")]
	if on then
		hidden[node] = hidden[node] or {}
		for _, p in node:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "MineHitbox" and not hidden[node][p] then
				hidden[node][p] = { T = p.Transparency, C = p.Color, M = p.Material, S = p.Size, CC = p.CanCollide }
				if def.landmark then
					-- big veins stay as landmarks: they go dark until they refill
					Tween:Create(p, TweenInfo.new(0.6), { Color = p.Color:Lerp(Color3.new(0.08, 0.07, 0.1), 0.75) }):Play()
					if p.Material == Enum.Material.Neon then p.Material = Enum.Material.SmoothPlastic end
				else
					Tween:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = p.Size * 0.2, Transparency = 1 }):Play()
					p.CanCollide = false -- a rock you can't see must not block you
				end
			elseif p:IsA("Light") or p:IsA("ParticleEmitter") then
				hidden[node][p] = { E = p.Enabled }; p.Enabled = false
			end
		end
	else
		local saved = hidden[node]
		if not saved then return end
		hidden[node] = nil
		for p, o in saved do
			if p.Parent then
				if o.E ~= nil then p.Enabled = o.E
				elseif def.landmark then p.Material = o.M; Tween:Create(p, TweenInfo.new(0.8), { Color = o.C }):Play()
				else
					p.CanCollide = o.CC
					Tween:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = o.S, Transparency = o.T }):Play()
				end
			end
		end
		local box = node:FindFirstChild("MineHitbox")
		if box then sfx("sfx_ui_press_primary_01", box.Position, 0.8) end
	end
end

------------------------------------------------------------------ effects
local function chipsAt(pos, color, n, speed)
	for i = 1, n do
		local c = Instance.new("Part")
		c.Size = Vector3.one * (0.35 + math.random() * 0.45); c.Color = color; c.Material = Enum.Material.Slate
		c.CanCollide = false; c.CanQuery = false; c.CanTouch = false; c.CastShadow = false
		c.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		c.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), math.random(12, 22), math.random(-10, 10)).Unit * speed
			+ Vector3.new(0, speed * 0.6, 0)
		c.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
		c.Parent = workspace
		Tween:Create(c, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.05 }):Play()
		Debris:AddItem(c, 0.75)
	end
end

local function flashAt(pos, color, size)
	local f = Instance.new("Part")
	f.Shape = Enum.PartType.Ball; f.Material = Enum.Material.Neon; f.Color = color
	f.Anchored = true; f.CanCollide = false; f.CanQuery = false; f.CanTouch = false; f.CastShadow = false
	f.Size = Vector3.one * size * 0.4; f.CFrame = CFrame.new(pos); f.Transparency = 0.1; f.Parent = workspace
	Tween:Create(f, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(f, 0.2)
end

local shaking = {}
local function shake(node, amp)
	if shaking[node] then return end
	shaking[node] = true
	local base = node:GetPivot()
	task.spawn(function()
		for i = 1, 6 do
			local a = amp * (1 - i / 7)
			node:PivotTo(base * CFrame.new(math.random(-10, 10) / 10 * a, 0, math.random(-10, 10) / 10 * a))
			task.wait(0.025)
		end
		node:PivotTo(base)
		shaking[node] = nil
	end)
end

local function popText(pos, text, color, big)
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromOffset(240, 50); b.StudsOffsetWorldSpace = Vector3.new(0, 1, 0); b.AlwaysOnTop = true; b.LightInfluence = 0
	local a = Instance.new("Attachment"); a.WorldPosition = pos; a.Parent = workspace.Terrain
	b.Adornee = a; b.Parent = gui
	local t = Instance.new("TextLabel", b)
	t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Font = FONT_NUM; t.TextSize = big and 30 or 22
	t.TextColor3 = color; t.Text = text
	local s = Instance.new("UIStroke", t); s.Thickness = 3; s.Color = Color3.fromRGB(22, 18, 38)
	local sc = Instance.new("UIScale", t); sc.Scale = 0.4
	Tween:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Tween:Create(b, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	task.delay(0.8, function()
		Tween:Create(t, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		Tween:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(a, 1.4); Debris:AddItem(b, 1.4)
end

------------------------------------------------------------------ the swing pose (any avatar: classic Motor6D or the newer
-- AnimationConstraint joints, R15 or R6). The pose is laid on top of whatever the Animator played this frame, in the
-- parent part's axes (X right, Y up, -Z forward), so it reads the same on every rig.
local swings = {} -- [character] = os.clock() the swing started
local jointState = {} -- [joint] = { written, base }

local function jointsOf(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if hum.RigType == Enum.HumanoidRigType.R6 then
		local torso = char:FindFirstChild("Torso")
		return torso and torso:FindFirstChild("Right Shoulder"), nil
	end
	local ua, ut = char:FindFirstChild("RightUpperArm"), char:FindFirstChild("UpperTorso")
	return ua and ua:FindFirstChild("RightShoulder"), ut and ut:FindFirstChild("Waist")
end

local function frame0(j)
	if j:IsA("Motor6D") then return j.C0 end
	if j:IsA("AnimationConstraint") and j.Attachment0 then return j.Attachment0.CFrame end
end

local function ease(a) return a * a * (3 - 2 * a) end

-- degrees at time t into a swing: arm raise (forward), waist twist, waist lean
local function poseAt(t)
	if t < 0.06 then -- wind-up: pick goes back over the shoulder, body turns away
		local a = ease(t / 0.06)
		return 140 * a, -12 * a, 5 * a
	elseif t < Cfg.IMPACT_AT then -- strike: fast down into the deposit, body turns in and leans forward
		local a = (t - 0.06) / (Cfg.IMPACT_AT - 0.06)
		a = a * a
		return 140 - 160 * a, -12 + 27 * a, 5 - 17 * a
	elseif t < Cfg.SWING_INTERVAL then -- recover to idle
		local a = ease((t - Cfg.IMPACT_AT) / (Cfg.SWING_INTERVAL - Cfg.IMPACT_AT))
		return -20 * (1 - a), 15 * (1 - a), -12 * (1 - a)
	end
end

local function apply(j, rot)
	local f0 = j and frame0(j)
	if not f0 then return end
	local st = jointState[j]
	local cur = j.Transform
	-- the Animator rewrites Transform each frame it animates the joint; if it didn't, ours is still there: start from
	-- the last clean base so the pose never stacks
	local base = (st and cur == st.written) and st.base or cur
	local r0 = f0.Rotation
	local new = (r0:Inverse() * rot * r0) * base
	j.Transform = new
	jointState[j] = { written = new, base = base }
end

local function release(j)
	local st = j and jointState[j]
	if not st then return end
	if j.Transform == st.written then j.Transform = st.base end
	jointState[j] = nil
end

Run.Stepped:Connect(function() -- (after the Animator, before physics + render)
	local now = os.clock()
	for char, t0 in swings do
		local shoulder, waist = jointsOf(char)
		local arm, twist, lean = poseAt(now - t0)
		if not char.Parent or not arm then
			release(shoulder); release(waist)
			swings[char] = nil
		else
			apply(shoulder, CFrame.Angles(math.rad(arm), 0, math.rad(-6)))
			apply(waist, CFrame.Angles(math.rad(lean), math.rad(twist), 0))
		end
	end
end)

-- one swing on a character: the pose, a whoosh, and at the impact the hit effects on the deposit
local function swingFX(who, node)
	local char = who.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	local me = root()
	if not r or not me or (r.Position - me.Position).Magnitude > 120 then return end
	swings[char] = os.clock()
	sfx("sfx_combat_whoosh_light_01", r.Position, 1.5)
	task.delay(Cfg.IMPACT_AT, function()
		local box = node and node.Parent and node:FindFirstChild("MineHitbox")
		if not box then return end
		local sp = surfacePoint(box, r.Position + Vector3.new(0, 1.5, 0))
		chipsAt(sp, nodeColor(node):Lerp(Color3.fromRGB(150, 145, 160), 0.5), who == player and 3 or 2, 18)
		flashAt(sp, Color3.fromRGB(255, 248, 220), 2.2)
		if who == player then
			shake(node, 0.35)
			sfx("sfx_combat_hit_light_01", sp, 0.75 + math.random() * 0.1)
		end
	end)
end

-- other players' swings (the server tells everyone but the swinger)
SwingRE.OnClientEvent:Connect(function(who, node)
	if who ~= player then swingFX(who, node) end
end)

------------------------------------------------------------------ HP bar: predicted at the impact, corrected by the server
local known = {} -- [node] = { hp, max, t } last HP the server confirmed
local pending = {} -- [node] = swings sent, not answered yet

local function dmg() return (Cfg.Picks[player:GetAttribute("PickTier") or 1] or Cfg.Picks[1]).damage end

local predictedBreak = {} -- [node] = true: we showed the break before the server's answer arrived

local function predictedHp(node)
	local def = Cfg.Nodes[node:GetAttribute("NodeType")]
	local k = known[node]
	if k and os.clock() - k.t > Cfg.HP_FORGET then known[node] = nil; k = nil end
	return (k and k.hp or def.hp) - dmg() * (pending[node] or 0), def.hp
end

local function showBar(node)
	local hp, max = predictedHp(node)
	local box, off = topOf(node)
	hpGui.Adornee = box; hpGui.StudsOffsetWorldSpace = off; hpGui.Enabled = true
	hpFill.BackgroundColor3 = nodeColor(node)
	Tween:Create(hpFill, TweenInfo.new(0.08), { Size = UDim2.fromScale(math.clamp(hp / max, 0.04, 1), 1) }):Play()
end

-- Reward text/sound must ONLY play after the server confirms a break. A predicted
-- break can be refused, so showing "+10 ROCK" before confirmation is misleading.
local function confirmedRewardFX(node, reward)
	local box = node:FindFirstChild("MineHitbox")
	local pos = box and box.Position or node:GetPivot().Position
	local y = 0
	for res, amt in reward do
		popText(pos + Vector3.new(0, (box and box.Size.Y / 2 or 2) + y, 0), "+" .. amt .. " " .. R[res].label, R[res].color, true)
		y += 2.5
	end
	sfx("sfx_reward_coin_pickup_01", nil, 1)
end

-- Break visuals are predicted for responsiveness, and can be rolled back.
-- Rewards are deliberately NOT shown here until the server confirms the break.
local function breakFX(node, respawn)
	hpGui.Enabled = false
	local box = node:FindFirstChild("MineHitbox")
	local pos = box and box.Position or node:GetPivot().Position
	local color = nodeColor(node)
	chipsAt(pos + Vector3.new(0, 1, 0), color, 9, 30)
	flashAt(pos, color, 7)
	sfx("sfx_combat_hit_heavy_01", pos, 0.9)
	local untilT = os.clock() + respawn
	depletedUntil[node] = untilT
	setDepletedLook(node, true)
	task.delay(respawn, function()
		if depletedUntil[node] == untilT then
			depletedUntil[node] = nil
			setDepletedLook(node, false)
		end
	end)
end

-- the server didn't break it after all (a swing was refused on the way): bring it back and show the true HP
local function undoBreak(node)
	predictedBreak[node] = nil
	depletedUntil[node] = nil
	setDepletedLook(node, false)
	showBar(node)
end

local REFUSED = { far = "TOO FAR", blocked = "BLOCKED", notyours = "NOT YOUR PLOT" }

ResultRE.OnClientEvent:Connect(function(kind, node, a, b)
	if not node then return end
	pending[node] = math.max(0, (pending[node] or 0) - 1)
	if kind == "hit" then
		known[node] = { hp = a, t = os.clock() }
		if predictedBreak[node] then
			if (pending[node] or 0) == 0 then undoBreak(node) end
		else
			showBar(node)
		end
	elseif kind == "break" then
		known[node], pending[node] = nil, nil
		if predictedBreak[node] then
			predictedBreak[node] = nil -- visual already played; now the reward is actually confirmed
			confirmedRewardFX(node, a)
			local untilT = os.clock() + b
			depletedUntil[node] = untilT
			task.delay(b, function()
				if depletedUntil[node] == untilT then
					depletedUntil[node] = nil
					setDepletedLook(node, false)
				end
			end)
		else
			breakFX(node, b)
			confirmedRewardFX(node, a)
		end
	elseif kind == "refused" then
		-- Rate-limited swings now receive this acknowledgement instead of disappearing.
		-- Their pending damage was removed above; if a predicted break was shown,
		-- undo it when there are no other outstanding swings for this node.
		if predictedBreak[node] and (pending[node] or 0) == 0 then undoBreak(node)
		elseif not isDepleted(node) and hpGui.Adornee and hpGui.Adornee.Parent == node then showBar(node) end -- quietly put the bar back
		-- say why only when the player can do something about it
		local box = node:FindFirstChild("MineHitbox")
		if REFUSED[a] and box then popText(box.Position + Vector3.new(0, box.Size.Y / 2, 0), REFUSED[a], Color3.fromRGB(255, 150, 140), false) end
	end
end)

------------------------------------------------------------------ input: tap / click = one swing, hold = keep swinging
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

-- screen point -> deposit (viewport = GetMouseLocation coords; otherwise InputObject coords, below the top bar)
local function pick(pos, viewport)
	local ray = viewport and camera:ViewportPointToRay(pos.X, pos.Y) or camera:ScreenPointToRay(pos.X, pos.Y)
	rp.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
	if not hit then return end
	local node = nodeFrom(hit.Instance)
	if node then return node end
	-- forgiving fingers: a tap that lands just beside a deposit still counts (nearest within 5 studs of the hit)
	local best, bd = nil, 5
	for _, n in CS:GetTagged(Cfg.TAG) do
		local box = n:FindFirstChild("MineHitbox")
		if box and n:IsDescendantOf(workspace) then
			local d = (surfacePoint(box, hit.Position) - hit.Position).Magnitude
			if d < bd then best, bd = n, d end
		end
	end
	return best
end

local holding -- { kind = "mouse" | input object, node, start }
local buffered, bufferedNode = 0, nil
local nextSwingAt = 0
local seq = 0
local lastSwing = 0

local function inRange(node)
	return node and node.Parent and not isDepleted(node) and distTo(node) <= Cfg.RANGE - 0.5
end

local function doSwing(node)
	local now = os.clock()
	seq += 1
	nextSwingAt = now + Cfg.SWING_INTERVAL
	lastSwing = now
	local r, hum = root()
	if r and hum and hum.MoveDirection.Magnitude < 0.1 then -- face the deposit (own character only; it replicates)
		local box = node:FindFirstChild("MineHitbox")
		local sp = surfacePoint(box, r.Position)
		local flat = Vector3.new(sp.X, r.Position.Y, sp.Z)
		if (flat - r.Position).Magnitude > 0.5 then r.CFrame = CFrame.lookAt(r.Position, flat) end
	end
	swingFX(player, node)
	pending[node] = (pending[node] or 0) + 1
	SwingRE:FireServer(node, seq)
	task.delay(Cfg.IMPACT_AT, function()
		if not node.Parent or isDepleted(node) then return end
		if predictedHp(node) <= 0 then -- the last hit: break it now, the server confirms + pays
			predictedBreak[node] = true
			local def = Cfg.Nodes[node:GetAttribute("NodeType")]
			breakFX(node, def.respawn)
		else
			showBar(node)
		end
	end)
end

local function refillText(node)
	local box = node:FindFirstChild("MineHitbox")
	local left = math.ceil(depletedUntil[node] - os.clock())
	if box then popText(box.Position + Vector3.new(0, box.Size.Y / 2, 0), "REFILLS IN " .. left .. "s", Color3.fromRGB(200, 195, 215), false) end
	sfx("sfx_ui_error_denied_01")
end

local function press(node, holdKey, pos)
	if not node then return end
	if isDepleted(node) then refillText(node) return end
	local d, sp = distTo(node)
	if d > Cfg.RANGE - 0.5 then -- too far: walk there; the next tap swings
		if d > Cfg.WALK_TO_MAX then return end
		target = node; buffered = 0
		local _, hum = root()
		if hum then hum:MoveTo(sp) end
		return
	end
	target = nil
	holding = { key = holdKey, node = node, start = pos }
	if bufferedNode ~= node then buffered = 0 end
	if os.clock() >= nextSwingAt then
		doSwing(node)
	elseif buffered < Cfg.BUFFER then -- a tap mid-swing waits for the next one (never more than one)
		buffered += 1; bufferedNode = node
	end
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local m = UIS:GetMouseLocation()
		press(pick(m, true), "mouse", m)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local p = Vector2.new(input.Position.X, input.Position.Y)
		press(pick(p, false), input, p)
	end
end)
UIS.InputChanged:Connect(function(input)
	-- a held finger that slides is turning the camera: stop mining
	if holding and holding.key == input and (Vector2.new(input.Position.X, input.Position.Y) - holding.start).Magnitude > Cfg.DRAG_CANCEL then
		holding = nil; buffered = 0
	end
end)
UIS.InputEnded:Connect(function(input)
	if not holding then return end
	if holding.key == input or (holding.key == "mouse" and input.UserInputType == Enum.UserInputType.MouseButton1) then holding = nil end
end)

-- swings from the buffer / a held press; walking to a far deposit; hints
local hintNode
local nextScan = 0
Run.RenderStepped:Connect(function()
	local r, hum = root()
	if not r then return end
	local now = os.clock()
	if now >= nextSwingAt then
		if buffered > 0 then
			buffered -= 1
			if inRange(bufferedNode) then doSwing(bufferedNode) else buffered = 0 end
		elseif holding then
			if inRange(holding.node) then doSwing(holding.node) else holding = nil end
		end
	end
	if target then
		if not target.Parent or isDepleted(target) then target = nil
		else
			local d, sp = distTo(target)
			if d <= Cfg.RANGE - 1 then -- arrived: stop walking, the TAP TO MINE hint takes over
				target = nil
				if hum then hum:MoveTo(r.Position) end
			elseif hum and hum.MoveDirection.Magnitude < 0.05 then
				hum:MoveTo(sp)
			end
		end
	end
	-- hover + hint scans 6 times a second, not every frame (cheap on phones)
	if now < nextScan then return end
	nextScan = now + 0.16
	if hpGui.Enabled and now - lastSwing > 3 then hpGui.Enabled = false end
	if UIS.MouseEnabled then -- PC hover outline
		local n = pick(UIS:GetMouseLocation(), true)
		if n and not isDepleted(n) then hl.Adornee = n; hl.Enabled = true else hl.Enabled = false end
	end
	-- nearest minable deposit in reach gets TAP TO MINE until you start swinging at it
	local best, bd = nil, Cfg.HINT_RANGE
	if now - lastSwing > 1.5 then
		for _, n in CS:GetTagged(Cfg.TAG) do
			if n:IsDescendantOf(workspace) and not isDepleted(n) and n:FindFirstChild("MineHitbox") then
				local d = distTo(n)
				if d < bd then best, bd = n, d end
			end
		end
	end
	if best ~= hintNode then
		hintNode = best
		if best then
			local box, off = topOf(best, 2.5)
			hint.Adornee = box; hint.StudsOffsetWorldSpace = off; hint.Enabled = true
		else
			hint.Enabled = false
		end
	end
end)
