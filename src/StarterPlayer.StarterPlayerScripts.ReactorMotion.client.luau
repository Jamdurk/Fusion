-- Alien Fusion: the crater REACTOR comes alive (31 Oct 2026; design\conquest-lanes\core\THRONE-SPEC.md, ChatGPT
-- core-audit-plan-r1 + ref R2). One client controller for every decorative moving part; nothing here collides or is a
-- combat target, so moving them locally is safe. Phase = Workspace:GetServerTimeNow(), so every client shows the same
-- angle. Updates 20 Hz near (< 400 studs), 5 Hz mid (< 900), frozen beyond.
--   ring 0.6 RPM clockwise (keeps its tilt) | halo 1.2 RPM counter-clockwise | upper orb spin 8 deg/s + pulse 3.5 s
--   core spin 12 deg/s + pulse 3 s (+-15 %) | beams breathe every 4 s | floating rocks bob +-0.8 over 5-8 s, turn 2-4 deg/s
-- Rest poses come from each part's RestCF attribute (written in Edit by src\tools\hub-reactor-motion-setup.luau), so a
-- part that streams out and back in still knows where it belongs.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local TAU = math.pi * 2
local RING_PERIOD, HALO_PERIOD = 100, 50
local ORB_SPIN, CORE_SPIN = math.rad(8), math.rad(12)
local ORB_PULSE, CORE_PULSE, BEAM_BREATHE = 3.5, 3.0, 4.0
local CENTRE = Vector3.new(0, 40, 0)
local NEAR, MID = 400, 900

local hub = workspace:WaitForChild("Hub")
local L = hub:WaitForChild("CraterLandmark")

local function rest(p)
	return p:GetAttribute("RestCF")
end

local function wave(t, period, phase)
	return 0.5 + 0.5 * math.sin(TAU * t / period + (phase or 0))
end

local function step(t, spinT)
	spinT = spinT or t                       -- the ring + halo clock (runs slow for 3 s after a core break)
	-- ring: every part turns about the ring's own (tilted) axis
	local ring = L:FindFirstChild("Ring")
	if ring then
		local base = ring:GetAttribute("Base")
		local ringRot = base * CFrame.Angles(0, -TAU * spinT / RING_PERIOD, 0) * base:Inverse()
		local orbRot = base * CFrame.Angles(0, ORB_SPIN * t, 0) * base:Inverse()
		for _, p in ring:GetChildren() do
			local r = p:IsA("BasePart") and rest(p)
			if r then
				if p.Name:find("^crOrb") then p.CFrame = orbRot * r else p.CFrame = ringRot * r end
			end
		end
		local heart = ring:FindFirstChild("crOrbHeart")
		if heart then
			local k = wave(t, ORB_PULSE)
			heart.Transparency = 0.3 * (1 - k)
			local light = ring:FindFirstChild("crOrb") and ring.crOrb:FindFirstChildWhichIsA("PointLight")
			if light then light.Brightness = 1.6 + 0.8 * k end
		end
	end
	-- halo: the other way, twice as fast
	local halo = L:FindFirstChild("Halo")
	if halo then
		local base = halo:GetAttribute("Base")
		local rot = base * CFrame.Angles(0, TAU * spinT / HALO_PERIOD, 0) * base:Inverse()
		for _, p in halo:GetChildren() do
			local r = p:IsA("BasePart") and rest(p)
			if r then p.CFrame = rot * r end
		end
	end
	-- core: spins on the spot (upright axis through its centre) and pulses +-15 %
	local shell = L:FindFirstChild("Shell")
	if shell then
		local core = shell:FindFirstChild("crCore")
		local c = core and rest(core)
		if c then
			local rot = CFrame.new(c.Position) * CFrame.Angles(0, CORE_SPIN * t, 0) * CFrame.new(-c.Position)
			for _, n in { "crCore", "crCoreLattice", "crCoreHeart" } do
				local p = shell:FindFirstChild(n)
				local r = p and rest(p)
				if r then p.CFrame = rot * r end
			end
			local k = wave(t, CORE_PULSE)
			local heart = shell:FindFirstChild("crCoreHeart")
			if heart then heart.Transparency = 0.25 * (1 - k) end
			local light = core:FindFirstChildWhichIsA("PointLight")
			if light then light.Brightness = 1.2 * (0.85 + 0.3 * k) end
		end
	end
	-- floating rocks: slow bob + turn, each on its own clock
	local rocks = L:FindFirstChild("FloatingRocks")
	if rocks then
		for i, p in rocks:GetChildren() do
			local r = p:IsA("BasePart") and rest(p)
			if r then
				local period = 5 + (i * 0.73) % 3
				local spin = math.rad(2 + (i * 0.61) % 2) * (i % 2 == 0 and 1 or -1)
				p.CFrame = CFrame.new(0, 0.8 * math.sin(TAU * t / period + i * 1.7), 0) * r * CFrame.Angles(0, spin * t, 0)
			end
		end
	end
	-- beams: breathe (opacity) every 4 s
	local anchor = L:FindFirstChild("BeamAnchor")
	if anchor then
		local k = wave(t, BEAM_BREATHE)
		local a = 0.15 + 0.3 * (1 - k)
		local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, math.min(0.95, a + 0.25)) })
		for _, b in anchor:GetChildren() do
			if b:IsA("Beam") then b.Transparency = seq end
		end
	end
end

-- ---------- throne STATES (refs R3 / R4): read from workspace.Hub.Conquest.Throne attributes ----------
--   State "wild" | "attacked" | "shieldDown" | "held"; each pylon's own State "neutral" | "active" | "destroyed";
--   OwnerColor (held); BreakAt = server time of the core break (3 s shockwave + a slowed ring)
local CYAN, RED = Color3.fromHex("56DDF2"), Color3.fromRGB(255, 70, 90)
local DEAD = Color3.fromRGB(46, 48, 56)
local seen = {}                                   -- part -> original colour (to restore / tint)
local function tint(p, c)
	-- the true colour lives in the RestColor attribute (written in Edit by hub-reactor-motion-setup.luau); remembering the
	-- first colour seen baked a test owner colour in for good once (31 Oct)
	if not seen[p] then seen[p] = p:GetAttribute("RestColor") or p.Color end
	p.Color = c or seen[p]
end
local lastBurst = -1                              -- the meteor cycle whose dust burst already fired
local landN, landY = -1, 2
local terrainOnly = RaycastParams.new(); terrainOnly.FilterType = Enum.RaycastFilterType.Include; terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function states(t)
	local cq = hub:FindFirstChild("Conquest")
	local th = cq and cq:FindFirstChild("Throne")
	local pieces = th and th:FindFirstChild("Pieces")
	if not pieces then return t end
	local state = th:GetAttribute("State") or "wild"
	local owner = th:GetAttribute("OwnerColor")
	local fight = state == "attacked" or state == "shieldDown"
	-- pylons: dark at rest, cyan + linked while active (1.6 s pulse), a dead stump once destroyed
	local live = 0
	for _, name in { "PylonEast", "PylonWest" } do
		local py = pieces:FindFirstChild(name)
		if py then
			local ps = py:GetAttribute("State") or "neutral"
			if fight and ps == "neutral" then ps = "active" end
			if not fight then ps = "neutral" end
			local k = wave(t, 1.6)
			for _, s in py:GetChildren() do
				if s.Name == "Strip" then tint(s, ps == "active" and CYAN:Lerp(Color3.new(1, 1, 1), 0.25 * k) or (ps == "destroyed" and DEAD or nil)) end
			end
			local cr = py:FindFirstChild("Crystal")
			if cr then
				cr.Transparency = ps == "destroyed" and 1 or 0               -- (stage C) the broken stump shows instead
				local g = cr:FindFirstChild("Glow"); if g then g.Brightness = ps == "active" and (1.5 + k) or 0 end
				local b = cr:FindFirstChild("ShieldLink"); if b then b.Enabled = ps == "active" and state == "attacked" end
			end
			if ps == "active" then live += 1 end
			-- (stage C, ref R5) destroyed: a short broken crystal stump, 3 shards on the shelf, faint smoke, a darker column
			local sc = pieces:FindFirstChild("StageC")
			local stump = sc and sc:FindFirstChild("Stump" .. name:sub(6))
			if stump then
				local dead = ps == "destroyed"
				for _, p in stump:GetChildren() do
					if p:IsA("BasePart") then p.Transparency = dead and 0 or 1 end
				end
				local sm = stump:FindFirstChild("Stump") and stump.Stump:FindFirstChild("Smoke")
				if sm then sm.Enabled = dead end
				local body = py:FindFirstChild("Body")
				if body then
					for _, sa in body:GetChildren() do
						if sa:IsA("SurfaceAppearance") then
							if not seen[sa] then seen[sa] = sa.Color end
							sa.Color = dead and Color3.fromRGB(95, 95, 105) or seen[sa]
						end
					end
				end
			end
		end
	end
	-- the shield bubble: up while attacked (flickers once only one pylon holds it), folds in 1.5 s once both are down
	local fx = pieces:FindFirstChild("CoreFX")
	if fx then
		local bubble = fx:FindFirstChild("ShieldBubble")
		if bubble then
			if state == "attacked" then
				local flick = live < 2 and (math.sin(t * 23) > 0.6 and 0.55 or 0) or 0
				bubble.Transparency = flick
				bubble.Color = Color3.fromRGB(150, 245, 255)            -- (audit B r1) +35 % hex contrast
				bubble.Size = Vector3.new(15, 15, 15)
			elseif state == "shieldDown" then
				local since = t - (th:GetAttribute("ShieldDownAt") or t)
				local f = math.clamp(since / 1.5, 0, 1)
				bubble.Size = Vector3.new(15, 15, 15) * (1 - 0.8 * f)
				bubble.Transparency = 0.15 + 0.85 * f
			else
				bubble.Transparency = 1
			end
			local hl = bubble:FindFirstChild("ShieldOutline")
			if hl then hl.OutlineTransparency = bubble.Transparency < 0.9 and 0.15 + bubble.Transparency * 0.5 or 1 end
		end
		local marker = fx:FindFirstChild("TargetMarker")
		if marker then
			local on = state == "shieldDown"
			for i, s in marker:GetChildren() do
				s.Transparency = on and (0.1 + 0.5 * wave(t * 2 + i / 32, 1)) or 1
			end
		end
		-- core break: a ring rolls out across the floor for 3 s
		local w = fx:FindFirstChild("Shockwave")
		local at = th:GetAttribute("BreakAt")
		if w then
			local since = at and (t - at) or 99
			if since >= 0 and since < 3 then
				local r = 10 + 120 * (since / 3)
				w.Size = Vector3.new(0.4, r, r); w.Transparency = 0.1 + 0.9 * (since / 3)
			else
				w.Transparency = 1
			end
		end
	end
	-- held: the reactor's light strips, halo and beams take the owner's colour
	local col = state == "held" and owner or nil
	local ring = L:FindFirstChild("Ring")
	if ring and ring:FindFirstChild("crRingStrips") then tint(ring.crRingStrips, col) end
	local halo = L:FindFirstChild("Halo")
	if halo and halo:FindFirstChild("crHalo") then tint(halo.crHalo, col) end
	local shell = L:FindFirstChild("Shell")
	if shell and shell:FindFirstChild("crShellSeams") then tint(shell.crShellSeams, col) end
	local anchor = L:FindFirstChild("BeamAnchor")
	if anchor then
		for _, b in anchor:GetChildren() do
			if b:IsA("Beam") then
				if col then b.Color = ColorSequence.new(col)
				else b.Color = ColorSequence.new(Color3.fromHex("B86BFF"), Color3.fromHex("56DDF2")) end
			end
		end
	end
	-- (stage C, ref R5) held: the lower core + upper orb take the owner colour too
	for _, pair in { { shell, { "crCore", "crCoreHeart", "crCoreLattice" } }, { ring, { "crOrb", "crOrbHeart", "crOrbLattice" } } } do
		if pair[1] then
			for _, n in pair[2] do
				local p = pair[1]:FindFirstChild(n)
				if p then tint(p, col and (n:find("Heart") and col:Lerp(Color3.new(1, 1, 1), 0.35) or col) or nil) end
			end
		end
	end
	local sc = pieces:FindFirstChild("StageC")
	if sc then
		-- crown hologram: owner colour, turns 10 deg/s about its centre, gentle 2.5 s shimmer
		local crown = sc:FindFirstChild("Crown")
		if crown then
			local c0 = crown:GetAttribute("Centre")
			local rot = CFrame.new(c0) * CFrame.Angles(0, math.rad(10) * t, 0) * CFrame.new(-c0)
			local k = wave(t, 2.5)
			for _, p in crown:GetChildren() do
				local r = rest(p)
				if r then p.CFrame = rot * r end
				if col then
					p.Color = p.Name == "Gem" and col:Lerp(Color3.new(1, 1, 1), 0.3 * k) or col:Lerp(Color3.new(0, 0, 0), 0.18)   -- full owner colour, a touch deeper (Neon blooms orange toward gold)
					p.Transparency = p.Name == "Glow" and 0.55 or 0.05
				else
					p.Transparency = 1
				end
			end
		end
		-- owner banners on the rim
		local banners = sc:FindFirstChild("Banners")
		if banners then
			for _, m in banners:GetChildren() do
				for _, p in m:GetChildren() do
					if p:IsA("BasePart") then
						p.Transparency = col and 0 or 1
						if col and (p.Name == "Cloth" or p.Name == "Light") then p.Color = col end
					end
				end
			end
		end
		-- spawn flash (0.5 s from the pocket's SpawnAt): the ring flares, a light column rises, then dims
		for _, m in sc:GetChildren() do
			local pk = m:GetAttribute("Pocket") and pieces:FindFirstChild(m:GetAttribute("Pocket"))
			if pk then
				local since = t - (pk:GetAttribute("SpawnAt") or -99)
				local on = since >= 0 and since < 0.6
				local f = math.clamp(since / 0.5, 0, 1)
				local col2, fl = m:FindFirstChild("Column"), m:FindFirstChild("Flare")
				if col2 then
					local fy = col2:GetAttribute("BaseY") or (col2.Position.Y - col2.Size.X / 2)
					col2:SetAttribute("BaseY", fy)
					local h = 2 + 16 * math.min(1, f * 1.6)
					local d = 7 - 4 * f                                  -- (audit C r1) 7 -> 3 wide
					col2.Size = Vector3.new(h, d, d)
					col2.CFrame = CFrame.new(col2.Position.X, fy + h / 2, col2.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
					col2.Transparency = on and (0.35 + 0.65 * f) or 1
				end
				if fl then fl.Transparency = on and (0.05 + 0.9 * f) or 1 end
			end
		end
		-- meteor (cosmetic): one every 105 s, only while nobody is fighting; lands on the OUTER rim (r 100-115)
		local met = sc:FindFirstChild("Meteor")
		if met then
			local CYCLE = 105
			local n = math.floor(t / CYCLE)
			local s = t - n * CYCLE                                  -- 0 .. 105 s into this cycle
			local rock, flash, dust = met:FindFirstChild("Rock"), met:FindFirstChild("Flash"), met:FindFirstChild("Dust")
			local burst = flash and flash:FindFirstChild("Burst")
			local h = (n * 7919) % 360                               -- the same spot on every client
			local lr = 100 + (n * 37) % 15
			local lx, lz = math.cos(math.rad(h)) * lr, -math.sin(math.rad(h)) * lr
			if landN ~= n then                                       -- the real ground there, once per meteor
				landN = n
				local hit = workspace:Raycast(Vector3.new(lx, 200, lz), Vector3.new(0, -400, 0), terrainOnly)
				landY = hit and hit.Position.Y or 2
			end
			local land = Vector3.new(lx, landY, lz)
			local from = land + Vector3.new(math.cos(math.rad(h + 60)) * 220, 260, -math.sin(math.rad(h + 60)) * 220)
			local quiet = not fight
			if rock then
				local streak = rock:FindFirstChild("Streak")
				if quiet and s < 1.2 then
					local p = from:Lerp(land, s / 1.2)
					rock.CFrame = CFrame.lookAt(p, land); rock.Transparency = 0
					if streak then
						streak.Enabled = true
						local tail = streak.Attachment1
						if tail then tail.WorldPosition = from:Lerp(land, math.max(0, s / 1.2 - 0.25)) end
					end
				else
					rock.Transparency = 1; if streak then streak.Enabled = false end
				end
			end
			if flash then
				local f = (s - 1.2) / 0.18                               -- (audit C r1) a bright 0.18 s pop
				flash.CFrame = CFrame.new(land + Vector3.new(0, 3, 0)); flash.Transparency = (quiet and f >= 0 and f < 1) and (f * f) or 1
				flash.Size = Vector3.new(4, 4, 4) * (1 + 3 * math.clamp(f, 0, 1))   -- a fast bright pop, lifted off the ground
				if burst and quiet and f >= 0 and f < 0.15 and lastBurst ~= n then
					lastBurst = n; burst:Emit(16)
					local puffs = flash:FindFirstChild("Puffs"); if puffs then puffs:Emit(10) end
				end
			end
			if dust then
				local f = (s - 1.2) / 2.2
				local r = 6 + 34 * math.clamp(f, 0, 1)
				local on = quiet and f >= 0 and f < 1
				for i, seg in dust:GetChildren() do
					if on then
						local a = i / 24 * math.pi * 2
						local px, pz = land.X + math.cos(a) * r / 2, land.Z + math.sin(a) * r / 2
						local hit = workspace:Raycast(Vector3.new(px, land.Y + 40, pz), Vector3.new(0, -80, 0), terrainOnly)   -- 24 rays x 2.2 s, then idle
						local gy = hit and hit.Position.Y or land.Y
						seg.Size = Vector3.new(0.6, 0.35, math.max(1.2, r * math.pi / 24 * 0.7))
						seg.CFrame = CFrame.lookAt(Vector3.new(px, gy + 0.3, pz), Vector3.new(px, gy + 0.3, pz) + Vector3.new(-math.sin(a), 0, math.cos(a)))
						seg.Transparency = 0.15 + 0.85 * f                -- fully gone at 2.2 s
					else
						seg.Transparency = 1
					end
				end
			end
		end
	end
	-- break: beams cut out for 3 s and the ring + halo run at 25 % (returns their clock: it falls 2.25 s behind for good,
	-- the same on every client, so there is no snap when the 3 s end)
	local at = th:GetAttribute("BreakAt")
	local since = at and (t - at) or -1
	if anchor then for _, b in anchor:GetChildren() do if b:IsA("Beam") then b.Enabled = not (since >= 0 and since < 3) end end end
	return t - 0.75 * math.clamp(since, 0, 3)
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local d = (cam.CFrame.Position - CENTRE).Magnitude
	if d > MID then return end
	acc += dt
	local interval = d < NEAR and 1 / 20 or 1 / 5
	if acc < interval then return end
	acc = 0
	local t = workspace:GetServerTimeNow()
	step(t, states(t))
end)
