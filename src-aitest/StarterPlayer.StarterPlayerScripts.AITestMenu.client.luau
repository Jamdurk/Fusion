-- Alien Fusion: the AI TEST menu (AlienFusion-AI-Testing.rbxl only). Right side of the screen; the MOVE TEST menu stays
-- on the left. Spawn any form the server's AITest has a kit for (it appears here by itself), pick the team it spawns on,
-- then per unit: change its team (A -> B -> ALL = hostile to everyone), switch its AI on / off, remove it.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local AF = RS:WaitForChild("AlienFusion")
local remote = AF:WaitForChild("AITest")
local formsList = AF:WaitForChild("AITestForms")
local units = workspace:WaitForChild("Units")

local gui = Instance.new("ScreenGui")
gui.Name = "AITestMenu"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local outerPanel = Instance.new("Frame")
outerPanel.Size = UDim2.fromOffset(260, 0); outerPanel.AutomaticSize = Enum.AutomaticSize.Y
outerPanel.AnchorPoint = Vector2.new(1, 0); outerPanel.Position = UDim2.new(1, -12, 0, 60)
outerPanel.BackgroundColor3 = Color3.fromRGB(18, 20, 28); outerPanel.BackgroundTransparency = 0.15; outerPanel.Parent = gui
Instance.new("UICorner", outerPanel).CornerRadius = UDim.new(0, 8)
Instance.new("UIListLayout", outerPanel).SortOrder = Enum.SortOrder.LayoutOrder
-- (James's phone test, 29 Oct: "the menus are massive, I can't minimise the AI one, I can't scroll it": it was ~800 tall on
-- a ~390-tall screen. Now: a title bar with [-] to fold it, ONE scrolling body capped to the screen, smaller on phones)
local scale = Instance.new("UIScale", outerPanel)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 44); title.LayoutOrder = 0; title.BackgroundColor3 = Color3.fromRGB(32, 36, 50)
title.Font = Enum.Font.GothamBold; title.TextSize = 14; title.TextColor3 = Color3.fromRGB(150, 220, 255)
title.Text = "   AI TEST"; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = outerPanel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)
local fold = Instance.new("TextButton")
fold.Size = UDim2.fromOffset(44, 40); fold.Position = UDim2.new(1, -48, 0, 2)   -- (a thumb-sized target, also at 0.8 scale)
fold.BackgroundColor3 = Color3.fromRGB(55, 60, 80); fold.Text = "-"; fold.Font = Enum.Font.GothamBold; fold.TextSize = 18
fold.TextColor3 = Color3.new(1, 1, 1); fold.Parent = title
Instance.new("UICorner", fold).CornerRadius = UDim.new(0, 5)
local panel = Instance.new("ScrollingFrame")
panel.LayoutOrder = 1; panel.BackgroundTransparency = 1; panel.BorderSizePixel = 0
panel.Size = UDim2.new(1, 0, 0, 0); panel.CanvasSize = UDim2.new(); panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollBarThickness = 6; panel.ScrollingDirection = Enum.ScrollingDirection.Y; panel.Parent = outerPanel
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 12)
local layout = Instance.new("UIListLayout", panel)
layout.Padding = UDim.new(0, 5); layout.SortOrder = Enum.SortOrder.LayoutOrder
local function fit()                       -- (as tall as its content, at most the screen below the panel's top)
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1000, 800)
	if vs.Y < 50 then return end           -- (at load the viewport can still be 1 x 1)
	scale.Scale = math.clamp(vs.Y / 600, 0.8, 1)
	-- (AbsoluteContentSize is on-screen pixels, after the UIScale; Size is before it)
	local contentH = layout.AbsoluteContentSize.Y / scale.Scale + 16
	local availableH = math.max(0, (vs.Y - 80) / scale.Scale - 44)
	panel.Size = UDim2.new(1, 0, 0, math.min(contentH, availableH))
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
local function watchCam()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	fit()
end
watchCam()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCam)
task.delay(1, fit)
fold.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	fold.Text = panel.Visible and "-" or "+"
end)

local order = 0
local function label(text, parent)
	order += 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 20); l.BackgroundTransparency = 1; l.LayoutOrder = order
	l.Font = Enum.Font.GothamBold; l.TextSize = 14; l.TextColor3 = Color3.fromRGB(150, 220, 255); l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent or panel
	return l
end
local function button(text, color, fn, parent, size)
	order += 1
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.new(1, 0, 0, 30); b.LayoutOrder = order; b.AutoButtonColor = true
	b.BackgroundColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.TextColor3 = Color3.new(1, 1, 1); b.Text = text
	b.Parent = parent or panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
	return b
end
local TEAM_COL = { A = Color3.fromRGB(40, 110, 200), B = Color3.fromRGB(200, 110, 30), ALL = Color3.fromRGB(180, 40, 40) }
local TEAM_TXT = { A = "TEAM A", B = "TEAM B", ALL = "HOSTILE TO ALL" }

-- the team the NEXT spawn joins
local spawnTeam = "A"
local teamBtn
teamBtn = button("SPAWN ON: TEAM A", TEAM_COL.A, function()
	spawnTeam = (spawnTeam == "A") and "B" or (spawnTeam == "B") and "ALL" or "A"
	teamBtn.Text = "SPAWN ON: " .. TEAM_TXT[spawnTeam]; teamBtn.BackgroundColor3 = TEAM_COL[spawnTeam]
end)
-- your own walk speed, to get round the map quicker (16 = normal; kept when you respawn)
local SPEEDS = { 16, 40, 80, 150 }
local speedI = 1
local function applySpeed()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = SPEEDS[speedI] end
end
local speedBtn
speedBtn = button("MY SPEED: 16", Color3.fromRGB(120, 80, 30), function()
	speedI = speedI % #SPEEDS + 1
	speedBtn.Text = "MY SPEED: " .. SPEEDS[speedI]
	applySpeed()
end)
player.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid", 10); applySpeed() end)
-- how many each SPAWN press makes (a swarm needs 6+ on a big one to GOO / CRACK it)
local COUNTS = { 1, 3, 6, 12 }
local countI = 1
local countBtn
countBtn = button("HOW MANY: 1", Color3.fromRGB(70, 70, 120), function()
	countI = countI % #COUNTS + 1
	countBtn.Text = "HOW MANY: " .. COUNTS[countI]
end)
-- one SPAWN button per form the server can drive (new forms appear as their kits are added)
local spawnBox = Instance.new("Frame")
spawnBox.Size = UDim2.new(1, 0, 0, 0); spawnBox.AutomaticSize = Enum.AutomaticSize.Y; spawnBox.BackgroundTransparency = 1
order += 1; spawnBox.LayoutOrder = order; spawnBox.Parent = panel
Instance.new("UIListLayout", spawnBox).Padding = UDim.new(0, 5)
local function rebuildSpawns()
	for _, c in spawnBox:GetChildren() do if c:IsA("TextButton") then c:Destroy() end end
	local names = formsList:GetChildren()
	-- (biggest first: giants, then F3, F2, F1)
	table.sort(names, function(a, b)
		local fa, fb = a:GetAttribute("Form") or 0, b:GetAttribute("Form") or 0
		if fa ~= fb then return fa > fb end
		return a.Value < b.Value
	end)
	for _, v in names do
		button("SPAWN " .. v.Value, Color3.fromRGB(30, 140, 90), function() remote:FireServer("spawn", v.Name, spawnTeam, COUNTS[countI]) end, spawnBox)
	end
end
rebuildSpawns()
formsList.ChildAdded:Connect(rebuildSpawns); formsList.ChildRemoved:Connect(rebuildSpawns)

local row = Instance.new("Frame")
row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundTransparency = 1; order += 1; row.LayoutOrder = order; row.Parent = panel
local rl = Instance.new("UIListLayout", row); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0, 5)
button("ALL AI ON", Color3.fromRGB(40, 150, 60), function() remote:FireServer("allai", true) end, row, UDim2.new(0.5, -3, 1, 0))
button("ALL AI OFF", Color3.fromRGB(90, 90, 100), function() remote:FireServer("allai", false) end, row, UDim2.new(0.5, -3, 1, 0))
local row2 = row:Clone(); for _, c in row2:GetChildren() do if c:IsA("TextButton") then c:Destroy() end end
order += 1; row2.LayoutOrder = order; row2.Parent = panel
button("HEAL ALL", Color3.fromRGB(40, 120, 140), function() remote:FireServer("heal") end, row2, UDim2.new(0.5, -3, 1, 0))
button("CLEAR AI", Color3.fromRGB(150, 40, 40), function() remote:FireServer("clear") end, row2, UDim2.new(0.5, -3, 1, 0))
-- (the animator's frame-rate readout, top centre; James's phone test: he couldn't find / see it)
button("SHOW / HIDE FPS", Color3.fromRGB(80, 80, 95), function()
	local wt = player.PlayerGui:FindFirstChild("WalkTestMenu")
	local f = wt and wt:FindFirstChild("FpsLabel")
	if f then f.Visible = not f.Visible end
end)

label("UNITS")
-- (the whole menu scrolls, so the rows just stack: a scroll inside a scroll fought touch on the phone)
local listBox = Instance.new("Frame")
listBox.Size = UDim2.new(1, 0, 0, 0); listBox.AutomaticSize = Enum.AutomaticSize.Y; listBox.BackgroundTransparency = 1
order += 1; listBox.LayoutOrder = order; listBox.Parent = panel
local ll = Instance.new("UIListLayout", listBox); ll.Padding = UDim.new(0, 4); ll.SortOrder = Enum.SortOrder.LayoutOrder

-- one row per AI unit: name + HP, its team (tap to change), AI on / off, remove
local rows = {}
local function rowFor(m: Model)
	local id = m:GetAttribute("AiId")
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -8, 0, 50); r.BackgroundColor3 = Color3.fromRGB(32, 34, 44); r.LayoutOrder = id or 0; r.Parent = listBox
	Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -8, 0, 18); name.Position = UDim2.fromOffset(6, 2); name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold; name.TextSize = 12; name.TextColor3 = Color3.new(1, 1, 1); name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = r
	local function small(text, x, w, color, fn)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(w, -4, 0, 24); b.Position = UDim2.new(x, 2, 0, 22); b.BackgroundColor3 = color
		b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.TextColor3 = Color3.new(1, 1, 1); b.Text = text; b.Parent = r
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
		b.MouseButton1Click:Connect(fn)
		return b
	end
	local teamB = small("", 0, 0.42, TEAM_COL.A, function() remote:FireServer("team", id) end)
	local aiB = small("", 0.42, 0.38, Color3.fromRGB(90, 90, 100), function() remote:FireServer("ai", id) end)
	small("X", 0.8, 0.2, Color3.fromRGB(150, 40, 40), function() remote:FireServer("remove", id) end)
	local function refresh()
		local team, on = m:GetAttribute("Team") or "A", m:GetAttribute("AiOn")
		local hp, max = m:GetAttribute("Hp") or 0, m:GetAttribute("MaxHp") or 1
		name.Text = string.format("%s   %d / %d HP", m.Name, hp, max)
		teamB.Text = TEAM_TXT[team] or team; teamB.BackgroundColor3 = TEAM_COL[team] or TEAM_COL.A
		aiB.Text = on and "AI ON" or "AI OFF"; aiB.BackgroundColor3 = on and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(90, 90, 100)
	end
	refresh()
	local conns = {}
	for _, a in { "Team", "AiOn", "Hp" } do table.insert(conns, m:GetAttributeChangedSignal(a):Connect(refresh)) end
	rows[m] = { frame = r, conns = conns }
end
local function track(m)
	if m:IsA("Model") and m:GetAttribute("Mode") == "ai" and not rows[m] then rowFor(m) end
end
local function untrack(m)
	local r = rows[m]
	if r then for _, c in r.conns do c:Disconnect() end; r.frame:Destroy(); rows[m] = nil end
end
for _, m in units:GetChildren() do track(m) end
units.ChildAdded:Connect(function(m) task.wait(); track(m) end)
units.ChildRemoved:Connect(untrack)
