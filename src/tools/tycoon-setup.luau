-- Alien Fusion tycoon setup (Studio Edit, 1 Nov 2026). Re-runnable: rebuilds ServerStorage.TycoonKit.
-- Look matches design\concepts\tycoon\tycoon-slice1-refs.png: dark metal frame + green neon strips + hazard stripes,
-- spinning drill bit, hopper of lilac Moon Rock; incubator = plinth with two glass domes (SQUISH cyan goo, CRUNCH amber
-- crystals), a timer ring + REPEAT light under each, pipes to a centre tower. Colours: the locked DNA colours (Goo cyan,
-- Crystal amber), not the sheet's green / cyan. Models: pivot = bottom centre, front = -Z.
-- TycoonService places them on the plot; pads + ghosts are made at run time.
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local METAL = Color3.fromRGB(58, 60, 72)
local METAL_DARK = Color3.fromRGB(34, 35, 44)
local NEON = Color3.fromRGB(120, 255, 70)
local HAZARD = Color3.fromRGB(255, 196, 30)
local LILAC = Color3.fromRGB(150, 142, 176)
local GOO = Color3.fromRGB(70, 235, 225)
local AMBER = Color3.fromRGB(255, 170, 50)

local old = SS:FindFirstChild("TycoonKit")
if old then old:Destroy() end
local kit = Instance.new("Folder"); kit.Name = "TycoonKit"

local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function solid(p) p.CanCollide = true; p.CanQuery = true; return p end
local function neon(parent, name, size, cf, color) return part(parent, name, size, cf, color or NEON, Enum.Material.Neon) end
-- yellow / black stripes along X, centred on cf
local function hazard(parent, length, cf, h, d)
	local n = math.floor(length)
	for i = 0, n - 1 do
		part(parent, "Hazard", Vector3.new(length / n, h, d), cf * CFrame.new(-length / 2 + (i + 0.5) * length / n, 0, 0),
			(i % 2 == 0) and HAZARD or Color3.fromRGB(25, 25, 25))
	end
end
local function label(p, face, text, color, size)
	local g = Instance.new("SurfaceGui"); g.Face = face; g.LightInfluence = 0; g.PixelsPerStud = 40
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.Parent = p
	local t = Instance.new("TextLabel"); t.Name = "Text"; t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.Text = text; t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4; t.Parent = g
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0.08, 0); pad.PaddingRight = UDim.new(0.08, 0)
	pad.PaddingTop = UDim.new(0.1, 0); pad.PaddingBottom = UDim.new(0.1, 0); pad.Parent = t
	return g
end
local function rock(parent, cf, s)
	local p = part(parent, "Rock", Vector3.new(s, s * 0.8, s * 0.9), cf * CFrame.Angles(math.rad(s * 37 % 40), math.rad(s * 91 % 90), 0),
		LILAC, Enum.Material.Slate)
	return p
end

------------------------------------------------------------------ ROCK DRILL (12 x 12)
do
	local m = Instance.new("Model"); m.Name = "Drill"
	solid(part(m, "Base", Vector3.new(12, 0.8, 12), CFrame.new(0, 0.4, 0), METAL_DARK))
	for _, c in { { -4.6, -4.6 }, { 4.6, -4.6 }, { -4.6, 4.6 }, { 4.6, 4.6 } } do
		solid(part(m, "Leg", Vector3.new(2.2, 8.6, 2.2), CFrame.new(c[1], 4.7, c[2]), METAL))
		part(m, "Foot", Vector3.new(3, 0.8, 3), CFrame.new(c[1], 1.2, c[2]), METAL_DARK)
		-- neon strip on the leg's outer face
		neon(m, "Strip", Vector3.new(0.3, 3.4, 0.9), CFrame.new(c[1] + math.sign(c[1]) * 1.15, 5.2, c[2]))
	end
	for _, z in { -4.6, 4.6 } do
		part(m, "Beam", Vector3.new(11.4, 1.4, 1.8), CFrame.new(0, 9.4, z), METAL)
		hazard(m, 8, CFrame.new(0, 9.4, z - math.sign(z) * 0.95), 0.9, 0.1)
	end
	for _, x in { -4.6, 4.6 } do part(m, "Beam", Vector3.new(1.8, 1.4, 11.4), CFrame.new(x, 9.4, 0), METAL) end
	part(m, "Housing", Vector3.new(5, 2.6, 5), CFrame.new(0, 10.4, 0), METAL)
	neon(m, "HousingLight", Vector3.new(3.6, 0.8, 0.2), CFrame.new(0, 10.7, -2.55))
	part(m, "Motor", Vector3.new(3, 1.6, 3), CFrame.new(0, 12.4, 0), METAL_DARK)
	-- pipe from the housing down the back right leg
	part(m, "Pipe", Vector3.new(0.9, 4, 0.9), CFrame.new(3, 11, 3), NEON, Enum.Material.Neon).Shape = Enum.PartType.Block
	-- the bit: shaft + shrinking discs + spiral fins (spun by TycoonClient round its own Y)
	local bit = Instance.new("Model"); bit.Name = "Bit"; bit.Parent = m
	local up = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder's axis is X)
	part(bit, "Shaft", Vector3.new(4.4, 1.4, 1.4), CFrame.new(0, 7, 0) * up, Color3.fromRGB(150, 155, 170), Enum.Material.Metal,
		Enum.PartType.Cylinder)
	for i, d in { 2.6, 2.1, 1.6, 1.1, 0.6 } do
		part(bit, "Disc", Vector3.new(0.8, d, d), CFrame.new(0, 5 - i * 0.75, 0) * up, Color3.fromRGB(175, 180, 195),
			Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for i = 0, 5 do
		part(bit, "Fin", Vector3.new(2.4, 0.25, 0.5), CFrame.new(0, 4.6 - i * 0.55, 0) * CFrame.Angles(0, math.rad(i * 60), math.rad(-18)),
			Color3.fromRGB(120, 125, 140), Enum.Material.Metal)
	end
	local ring = part(bit, "Ring", Vector3.new(0.25, 4.4, 4.4), CFrame.new(0, 6, 0) * up, NEON, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.55
	bit.PrimaryPart = bit.Shaft
	CS:AddTag(bit, "TycoonSpin")
	-- rubble round the hole
	for i = 0, 7 do
		local a = i * math.pi / 4
		rock(m, CFrame.new(math.cos(a) * 2.4, 1.1, math.sin(a) * 2.4), 0.9 + (i % 3) * 0.35)
	end
	-- hopper on the +X side (outside the 12 x 12 frame's legs, inside its footprint edge) filling with Moon Rock
	local hx = 7.6
	solid(part(m, "Hopper", Vector3.new(3.6, 2.6, 4.4), CFrame.new(hx, 1.3, 1.5), METAL))
	part(m, "HopperLip", Vector3.new(4.2, 0.5, 5), CFrame.new(hx, 2.75, 1.5), METAL_DARK)
	hazard(m, 3.4, CFrame.new(hx, 0.6, 1.5 - 2.25) , 0.8, 0.1)
	for i = 0, 5 do rock(m, CFrame.new(hx - 1.1 + (i % 3) * 1.1, 3.1 + (i // 3) * 0.4, 0.6 + (i % 2) * 1.6), 0.9) end
	local sign = part(m, "HopperSign", Vector3.new(3.2, 1.3, 0.1), CFrame.new(hx, 1.4, 1.5 - 2.25), METAL_DARK)
	label(sign, Enum.NormalId.Front, "MOON ROCK", NEON)
	part(m, "Chute", Vector3.new(3, 0.5, 1.4), CFrame.new(5, 2.9, 1.5) * CFrame.Angles(0, 0, math.rad(-20)), METAL_DARK)
	-- rate board above (the server fills in the text)
	local board = part(m, "RateBoard", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 14.4, 0), METAL)
	board.Transparency = 1
	local bb = Instance.new("BillboardGui"); bb.Name = "Rate"; bb.Size = UDim2.fromOffset(170, 40); bb.MaxDistance = 90
	bb.AlwaysOnTop = false; bb.LightInfluence = 0; bb.Parent = board
	local t = Instance.new("TextLabel"); t.Name = "Text"; t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne; t.TextScaled = true; t.TextColor3 = NEON; t.TextStrokeTransparency = 0.2
	t.Text = "+8 ROCK / MIN"; t.Parent = bb
	m.PrimaryPart = m.Base
	m:PivotTo(CFrame.new())
	m.WorldPivot = CFrame.new()
	m.Parent = kit
end

------------------------------------------------------------------ INCUBATOR (14 x 14)
do
	local m = Instance.new("Model"); m.Name = "Incubator"
	solid(part(m, "Plinth", Vector3.new(14, 2.2, 9), CFrame.new(0, 1.1, 0.5), METAL))
	part(m, "PlinthTop", Vector3.new(13.4, 0.4, 8.4), CFrame.new(0, 2.4, 0.5), METAL_DARK)
	hazard(m, 13, CFrame.new(0, 0.5, -4.05), 0.8, 0.1)
	-- centre tower + egg screen
	solid(part(m, "Tower", Vector3.new(2.4, 9, 2.4), CFrame.new(0, 6.6, 2), METAL))
	local scr = part(m, "Screen", Vector3.new(2, 2, 0.15), CFrame.new(0, 9.6, 0.75), METAL_DARK)
	label(scr, Enum.NormalId.Front, "EGG", NEON)
	neon(m, "TowerLight", Vector3.new(0.5, 2.6, 0.15), CFrame.new(0, 5.4, 0.75))
	for side, info in { Squish = { x = -3.6, color = GOO, name = "SQUISH" }, Crunch = { x = 3.6, color = AMBER, name = "CRUNCH" } } do
		local ch = Instance.new("Model"); ch.Name = side; ch.Parent = m
		local x = info.x
		part(ch, "Pedestal", Vector3.new(1.4, 5.4, 5.4), CFrame.new(x, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), METAL_DARK,
			nil, Enum.PartType.Cylinder)
		neon(ch, "PedestalRing", Vector3.new(0.3, 5.6, 5.6), CFrame.new(x, 3.9, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color).Shape =
			Enum.PartType.Cylinder
		local dome = part(ch, "Dome", Vector3.new(5, 5, 5), CFrame.new(x, 4.2, 0), Color3.fromRGB(200, 240, 255), Enum.Material.Glass,
			Enum.PartType.Ball)
		dome.Transparency = 0.6
		dome.CanQuery = true -- (the HATCH prompt lives here)
		if side == "Squish" then
			local goo = part(ch, "Goo", Vector3.new(0.6, 4.2, 4.2), CFrame.new(x, 4.3, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color,
				Enum.Material.Neon, Enum.PartType.Cylinder)
			goo.Transparency = 0.25
			for i = 0, 3 do
				local b = part(ch, "Bubble", Vector3.one * (0.35 + i * 0.1), CFrame.new(x - 1.2 + i * 0.8, 5.5 + (i % 2) * 1.1, -0.8 + (i % 3) * 0.7),
					info.color, Enum.Material.Neon, Enum.PartType.Ball)
				b.Transparency = 0.35
			end
		else
			for i = 0, 6 do
				local a = i * math.pi * 2 / 7
				part(ch, "Crystal", Vector3.new(0.6, 1.4 + (i % 3) * 0.5, 0.6), CFrame.new(x + math.cos(a) * 1.5, 5 + (i % 3) * 0.2, math.sin(a) * 1.5)
					* CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), info.color, Enum.Material.Glass).Transparency = 0.15
			end
		end
		-- the egg (hidden until a hatch starts; TycoonClient wobbles it)
		local egg = part(ch, "Egg", Vector3.new(2.1, 2.8, 2.1), CFrame.new(x, 5.6, 0), info.color, Enum.Material.Neon, Enum.PartType.Ball)
		egg.Transparency = 1
		local spots = Instance.new("Highlight"); spots.Name = "Glow"; spots.FillColor = info.color; spots.OutlineColor = Color3.new(1, 1, 1)
		spots.FillTransparency = 0.6; spots.Enabled = false; spots.Adornee = egg; spots.Parent = egg
		-- name plate on the plinth front
		local plate = part(ch, "Plate", Vector3.new(4.4, 1.1, 0.15), CFrame.new(x, 1.6, -4.05), METAL_DARK)
		label(plate, Enum.NormalId.Front, info.name, info.color)
		-- timer ring (front face of the plinth, beside the plate) + REPEAT light
		local ring = part(ch, "Timer", Vector3.new(0.2, 2.4, 2.4), CFrame.new(x + (x < 0 and 1.9 or -1.9), 3.4, -3.3)
			* CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0), METAL_DARK, nil, Enum.PartType.Cylinder)
		local rg = label(ring, Enum.NormalId.Right, "HATCH\n12", info.color)
		rg.Name = "Gui"
		neon(ch, "TimerRing", Vector3.new(0.12, 2.7, 2.7), ring.CFrame * CFrame.new(-0.05, 0, 0), info.color).Shape = Enum.PartType.Cylinder
		local rep = part(ch, "Repeat", Vector3.new(1.6, 1.6, 0.4), CFrame.new(x + (x < 0 and -2.3 or 2.3), 3.4, -3.6), METAL_DARK)
		rep.CanQuery = true -- (the REPEAT prompt lives here)
		label(rep, Enum.NormalId.Front, "REPEAT", Color3.new(1, 1, 1))
		neon(ch, "RepeatLight", Vector3.new(1, 0.3, 0.4), CFrame.new(rep.Position.X, 4.35, -3.6), Color3.fromRGB(60, 60, 70))
		-- where a new alien steps out (in front of the plinth)
		local sp = part(ch, "Spawn", Vector3.new(1, 1, 1), CFrame.new(x, 0.5, -6.5), METAL)
		sp.Transparency = 1
		ch:SetAttribute("Egg", side)
		CS:AddTag(ch, "EggChamber")
		-- pipe from the tower to the dome top
		part(m, "Pipe", Vector3.new(math.abs(x) + 0.2, 0.7, 0.7), CFrame.new(x / 2, 9.2, 1.2), info.color, Enum.Material.Neon)
		part(m, "PipeDown", Vector3.new(0.7, 2.4, 0.7), CFrame.new(x, 8, 1.2), METAL)
	end
	-- side goo tank (left) like the sheet
	part(m, "Tank", Vector3.new(4.6, 1.8, 1.8), CFrame.new(-6.4, 4.6, 2.6) * CFrame.Angles(0, 0, math.rad(90)), GOO, Enum.Material.Neon,
		Enum.PartType.Cylinder).Transparency = 0.3
	part(m, "TankCap", Vector3.new(0.5, 2.1, 2.1), CFrame.new(-6.4, 7, 2.6) * CFrame.Angles(0, 0, math.rad(90)), METAL, nil,
		Enum.PartType.Cylinder)
	m.PrimaryPart = m.Plinth
	m.WorldPivot = CFrame.new()
	m.Parent = kit
end

kit.Parent = SS
return "TycoonKit built: " .. #kit.Drill:GetDescendants() .. " + " .. #kit.Incubator:GetDescendants() .. " instances"
