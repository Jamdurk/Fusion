-- Alien Fusion: the walk-test spawner behind the command menu (James, 27 Oct: "a command menu in the game where I
-- can trigger each one's walking animation"). A client asks for a form; the server puts a copy from
-- ServerStorage.Aliens.Forms into workspace.Units with its path (a loop in front of that player) as attributes.
-- Every client then moves and animates it the same way from those attributes and the server clock (AlienAnimator).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local forms = game:GetService("ServerStorage"):WaitForChild("Aliens"):WaitForChild("Forms")

local folder = RS:FindFirstChild("AlienFusion") or Instance.new("Folder", RS)
folder.Name = "AlienFusion"
local remote = folder:FindFirstChild("WalkTest") or Instance.new("RemoteEvent", folder)
remote.Name = "WalkTest"
local units = workspace:FindFirstChild("Units") or Instance.new("Folder", workspace)
units.Name = "Units"

-- the test speeds (rules §3: F1 22, F2 19, F3 16, F4 8 studs/s)
local SPEED = { [1] = 22, [2] = 19, [3] = 16, [4] = 8 }   -- (F4 12 -> 8, James 27 Oct: "the bigger forms naturally need to be a bit [slower]")
local ARENA = Vector3.new(260, 0, 180) -- (measured: 4.6 studs of height range over 200 x 120)
local ORDER = { "SquishF1", "SquishF2", "SquishF3", "SquishF4", "CrunchF1", "CrunchF2", "CrunchF3", "CrunchF4" }

local function clear(owner: Player?, name: string?)
	for _, u in units:GetChildren() do
		if (not owner or u:GetAttribute("Owner") == owner.UserId) and (not name or u:GetAttribute("FormName") == name) then u:Destroy() end
	end
end

local RUN_SPEED = 1.6 -- (a run is 1.6x the walk speed, with its own gait: ChatGPT run audit)

local function spawnWalker(plr: Player, name: string, slot: number, slots: number, mode: string, attack: string?, extra: { [string]: any }?)
	local src = forms:FindFirstChild(name)
	if not src then return end
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if not (extra and extra.Keep) then clear(plr, name) end
	local m = src:Clone()
	local f = m:GetAttribute("Form") or 1
	local _, size = m:GetBoundingBox()
	-- (the Colossus walks a wider loop on its own: on a tight one its footholds crowd together on the inside. Not in
	-- "all", where the loops are 50 apart)
	local radius = math.max(8, size.X * 1.2, size.Z * 1.2, (name == "CrunchF4" and slots == 1) and 30 or 0)
	-- the test arena: the flattest open ground on the map (beside the +X base); the player is brought to its edge
	-- to watch. "all": SQUISH on the near row, CRUNCH on the far row, F1 to F4 left to right, loops 50 studs apart
	local row = (slots > 1 and slot > 4) and 1 or 0
	local col = (slots > 1) and ((slot - 1) % 4) - 1.5 or 0
	local centre = ARENA + Vector3.new(col * 50, 0, -row * 55)
	if (root.Position - ARENA).Magnitude > 140 then
		plr.Character:PivotTo(CFrame.lookAt(ARENA + Vector3.new(0, 6, 60), ARENA + Vector3.new(0, 6, -30)))
	end
	-- (streams in whole: without it a client could get the model before its bones and never animate it)
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	m:SetAttribute("Owner", plr.UserId)
	m:SetAttribute("FormName", name)
	m:SetAttribute("MoveTest", true)   -- (a MOVE TEST unit: attacks may hold their end pose (atk.testLock))
	m:SetAttribute("Mode", mode)
	m:SetAttribute("Attack", attack)   -- (set before it's parented: a client sets the unit up the moment it arrives)
	-- (F4 is 8 now: the Colossus's legs (4.07 studs) reach an 11-stud stride at most, so at the old 12 it stepped every
	-- 0.46 s, "a little quick ... not like a giant walking"; at 8 every 0.69 s. James: big forms slower is fine)
	local walk = SPEED[f] or 16
	m:SetAttribute("Speed", (mode == "idle" or mode == "attack") and 0 or walk * ((mode == "run") and RUN_SPEED or 1))
	m:SetAttribute("CentreX", centre.X)
	m:SetAttribute("CentreZ", centre.Z)
	m:SetAttribute("Radius", radius)
	-- (START: stands in its idle for 3 s, then walks)
	m:SetAttribute("T0", workspace:GetServerTimeNow() + ((mode == "start") and 3 or (mode == "attack") and 1 or 0))
	for k, v in extra or {} do if k ~= "Keep" then m:SetAttribute(k, v) end end
	m:PivotTo(CFrame.new(centre + Vector3.new(radius, 0, 0)))
	m.Parent = units
end

local ATTACKS = { Slam = true, Sun = true, Boulder = true, Defeat = true, Bomb = true, Wave = true, Slap = true, Sticky = true, Boing = true, Pound = true, Grab = true, Thump = true, Cling = true, Squash = true, Bombs = true,
	Chip = true, Curl = true, Roll = true, Snap = true, Block = true, Sweep = true, Gore = true, Stamp = true, Charge = true }
local AIMED = { Sun = true, Boulder = true, Bomb = true, Boing = true, Grab = true }   -- (these aim at a new target each repeat)   -- (batch 1: these aim at a new target each repeat)

-- (batch 4, the Drip: CLING and BOING BOMBS need a big enemy to stick to: a Brute stand-in (StandIn) standing still,
-- the Drip(s) 7.5 studs from it; n = 6 rings them round it (the GOOED test), each with its own Slot)
local BIG = { SquishF3v5 = true, SquishF4v5 = true, CrunchF3v5 = true, CrunchF4 = true }   -- (Brute, Titan, Ram, Colossus)
local function dripOnStandIn(plr: Player, mode: string, n: number, target: string?, unit: string?)
	clear(plr)
	unit = (unit == "CrunchF1v5") and "CrunchF1v5" or "SquishF1v5"
	target = (target and BIG[target]) and target or "SquishF3v5"
	spawnWalker(plr, target, 1, 1, "idle", nil, { Keep = true, StandIn = true })
	local b
	for _, u in units:GetChildren() do if u:GetAttribute("StandIn") and u:GetAttribute("Owner") == plr.UserId then b = u end end
	if not b then return end
	local c = Vector3.new(b:GetAttribute("CentreX") + b:GetAttribute("Radius"), 0, b:GetAttribute("CentreZ"))
	local _, bsz = b:GetBoundingBox()
	local ring = math.max(bsz.X, bsz.Z) / 2 + 4                         -- (the Drips start 4 studs outside its body)
	if mode == "Roll" then ring = math.max(bsz.X, bsz.Z) / 2 + 20 end           -- (ROLL OUT: 0.5 s of rolling at 35.2 studs/s to its spot)
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi
		local p = c + Vector3.new(math.cos(a), 0, math.sin(a)) * ring
		spawnWalker(plr, unit, 1, 1, "attack", mode, { Keep = true, Slot = i - 1, CentreX = p.X - 8, CentreZ = p.Z, Radius = 8,
			T0 = workspace:GetServerTimeNow() + 1 + (i - 1) * 0.07 })
	end
end

-- (PHONE TEST: a whole army doing its attacks at once, to read frame time on a phone. n = 12, 24 or 48: per group of 6,
-- 1 Brute (Pound / Thump, the Drips' stand-in), 2 Twins (Slap / Sticky / Boing in turn), 3 Drips clinging to that Brute.
-- 48 is the "weaker phone" stand-in: if a fast phone holds 60 FPS at 48, one about half as fast holds it at 24.
-- Start times are spread over 1 s so the attacks do not all land on the same frame)
local TWIN_MOVES, BRUTE_MOVES = { "Slap", "Sticky", "Boing" }, { "Pound", "Thump" }
local function stressArmy(plr: Player, n: number)
	clear(plr)
	local groups = math.max(1, n // 6)
	local cols = math.ceil(math.sqrt(groups))
	local now = workspace:GetServerTimeNow()
	local k = 0
	local function put(form, attack, p: Vector3, extra)
		k += 1
		local e = { Keep = true, CentreX = p.X - 8, CentreZ = p.Z, Radius = 8, T0 = now + 1 + ((k * 0.37) % 1) }
		for a, v in extra or {} do e[a] = v end
		spawnWalker(plr, form, 1, 1, "attack", attack, e)
	end
	for gi = 0, groups - 1 do
		local c = ARENA + Vector3.new(((gi % cols) - (cols - 1) / 2) * 22, 0, -(gi // cols) * 22)
		put("SquishF3v5", BRUTE_MOVES[gi % 2 + 1], c, { StandIn = true })
		for t = 0, 1 do
			local mv = TWIN_MOVES[(gi * 2 + t) % 3 + 1]
			put("SquishF2v5", mv, c + Vector3.new(-9 + t * 18, 0, 7), (mv == "Boing") and { AimTest = true } or nil)
		end
		for d = 0, 2 do
			local a = d / 3 * 2 * math.pi + 0.4
			put("SquishF1v5", "Cling", c + Vector3.new(math.cos(a), 0, math.sin(a)) * 7.5, { Slot = d })
		end
	end
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if root then plr.Character:PivotTo(CFrame.lookAt(ARENA + Vector3.new(0, 6, 24 + cols * 5), ARENA + Vector3.new(0, 4, -cols * 8))) end
end

-- (batches 6-7: the Pincer / Ram attack with idle stand-in targets placed in front of them, model-space offsets)
local NEAR = {
	Snap = { { "SquishF1v5", -3.2, -1.2 }, { "SquishF1v5", 3.2, -1.2 } },
	Block = { { "SquishF1v5", -3.5, -2.5 }, { "SquishF1v5", 3.5, -2.5 }, { "SquishF1v5", 0, -3.6 } },
	Sweep = { { "SquishF1v5", -3.5, -3.0 }, { "SquishF1v5", 0, -4.2 }, { "SquishF1v5", 3.5, -3.0 } },
	Gore = { { "SquishF2v5", 0, -9.5 } },
	Stamp = { { "SquishF2v5", -2.5, -8.5 }, { "SquishF2v5", 2.5, -8.5 } },
	Charge = { { "SquishF2v5", 0, -20 }, { "SquishF2v5", -3, -21 }, { "SquishF2v5", 3, -21 } },
}
local function attackWithNear(plr: Player, name: string, mode: string)
	clear(plr)
	spawnWalker(plr, name, 1, 1, "attack", mode, { Keep = true, AimTest = (mode == "Charge") or nil })
	local u
	for _, x in units:GetChildren() do if x:GetAttribute("Owner") == plr.UserId and x:GetAttribute("FormName") == name then u = x end end
	if not u then return end
	local cf = u:GetPivot()                                    -- (attack units stand at the loop start facing +Z = along it)
	for i, n in NEAR[mode] or {} do
		-- (the client turns a SIDEWAYS unit (the Pincer) a quarter turn from its server pivot (measured: offsets came out with x
		-- and z swapped): swap them there so n[2] / n[3] are its own right / forward; the Ram faces its path)
		local p = (name == "CrunchF2v5") and cf * Vector3.new(-n[3], 0, n[2]) or cf * Vector3.new(-n[2], 0, -n[3])   -- (the Ram: a half turn, measured)
		spawnWalker(plr, n[1], 1, 1, "idle", nil, { Keep = true, NearTarget = true, Slot = i - 1, CentreX = p.X - 8, CentreZ = p.Z, Radius = 8 })
	end
end

remote.OnServerEvent:Connect(function(plr, cmd, name, mode, extra)
	if cmd == "attack" and (name == "CrunchF2v5" or name == "CrunchF3v5") and NEAR[mode] then attackWithNear(plr, name, mode); return end
	if cmd == "attack" and name == "CrunchF1v5" and (mode == "Chip" or mode == "Roll") then dripOnStandIn(plr, mode, 1, extra, "CrunchF1v5"); return end
	if cmd == "pebbleon" and typeof(name) == "string" and (mode == "Chip" or mode == "Roll") then
		dripOnStandIn(plr, mode, math.clamp(tonumber(extra) or 1, 1, 10), name, "CrunchF1v5")
		return
	end
	-- (batch 4 check: Drips onto ANY big form: "dripon", target form, "Cling" / "Bombs", count 1-10)
	if cmd == "dripon" and typeof(name) == "string" and (mode == "Cling" or mode == "Bombs") then
		dripOnStandIn(plr, mode, math.clamp(tonumber(extra) or 1, 1, 10), name)
		return
	end
	if cmd == "stress" and (name == 12 or name == 24 or name == 48) then stressArmy(plr, name); return end
	if (cmd == "attack" and name == "SquishF1v5" and (mode == "Cling" or mode == "Bombs")) or cmd == "swarm" then
		dripOnStandIn(plr, (mode == "Bombs") and "Bombs" or "Cling", (cmd == "swarm") and 6 or 1)
		return
	end
	if cmd == "attack" and typeof(name) == "string" and ATTACKS[mode] then
		-- (the attack test: the unit stands on its loop's start, facing along it, and attacks on repeat; T0 = 1 s from now)
		for _, u in units:GetChildren() do if u:GetAttribute("StandIn") and u:GetAttribute("Owner") == plr.UserId then u:Destroy() end end   -- (a Drip stand-in left over)
		spawnWalker(plr, name, 1, 1, "attack", mode, AIMED[mode] and { AimTest = true } or nil)
		return
	end
	-- (batch-1 audit tests: HURT landing during an attack; TWO Colossi doing the same attack at once, for the FX budget)
	if cmd == "attackhurt" and typeof(name) == "string" and ATTACKS[mode] then
		spawnWalker(plr, name, 1, 1, "attack", mode, { HurtEvery = 1.6, AimTest = AIMED[mode] or nil })
		return
	end
	if cmd == "attack2" and typeof(name) == "string" and ATTACKS[mode] then
		clear(plr, name)
		for i = 1, 2 do spawnWalker(plr, name, i, 2, "attack", mode, { Keep = true, AimTest = AIMED[mode] or nil }) end
		return
	end
	if cmd == "hurt" and typeof(name) == "string" then
		-- (batch 1: it walks its loop and takes a big hit every 1.6 s, alternating sides)
		spawnWalker(plr, name, 1, 1, "walk", nil, { HurtEvery = 1.6 })
		return
	end
	mode = (mode == "run" or mode == "idle" or mode == "start") and mode or "walk"
	if cmd == "walk" and typeof(name) == "string" then
		spawnWalker(plr, name, 1, 1, mode)
	elseif cmd == "all" then
		clear(plr)
		for i, n in ORDER do spawnWalker(plr, n, i, #ORDER, mode) end
	elseif cmd == "stop" then
		clear(plr, typeof(name) == "string" and name or nil)
	end
end)
Players.PlayerRemoving:Connect(function(plr) clear(plr) end)
