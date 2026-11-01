-- Alien Fusion: the AI TESTING GROUND (AlienFusion-AI-Testing.rbxl only; James, 28 Oct: "spawn in a colossus, make it
-- hostile to everything, then spawn in a titan ... AI on, AI off ... as the animations get built I can just keep
-- plugging and playing"; 29 Oct: "all animations are done ... plug in all ai modules like the rest now").
-- The server owns each AI unit's brain, position, HP and every hit; every client draws it (AlienAnimator's "ai" mode).
-- BRAIN = the child module Brain (design/ai/brain.mjs ported: utility targets, shared 24-sector surround slots, evade
-- behind a protector, Pincer guard posts, Ram speed build-up, ORCA crowd steering). COMBAT = this script: each form's
-- PASSIVE / AUTO / ORDER from design/power/kits.mjs, every hit landing on its animation's own mark (the batch specs).
-- PLUG AND PLAY: a form joins the menu as soon as it has an entry in KITS (its animation names = Attacks.FOR[form]).
--
-- TO CLIENTS (AlienFusion.AIState, 10 Hz, one message): (states, events). states = { { id, server time, x, z, facing,
-- speed } }; events = { { id, "atk", name, t0, aimX, aimZ, targetId, slot } | { id, "hurt", t, side } }. A unit that
-- an attack carries (a charge, a leap) JUMPS at one moment: two samples 1 ms apart, so the playback switches at once.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local forms = game:GetService("ServerStorage"):WaitForChild("Aliens"):WaitForChild("Forms")
local Brain = require(script:WaitForChild("Brain"))

local AF = RS:WaitForChild("AlienFusion")
local remote = AF:FindFirstChild("AITest") or Instance.new("RemoteEvent")
remote.Name = "AITest"; remote.Parent = AF
local stateRemote = AF:FindFirstChild("AIState") or Instance.new("RemoteEvent")
stateRemote.Name = "AIState"; stateRemote.Parent = AF
local units = workspace:FindFirstChild("Units") or Instance.new("Folder")
units.Name = "Units"; units.Parent = workspace

-- ===== the chassis (kits.mjs FORMS) + the power graph's guard rails (kits.mjs RULES) =====
-- turnDeg: the giants' 60 deg/s is the kit's; the rest are ours (fast enough that the steering, not the turn, leads)
local CHASSIS = {
	[1] = { hp = 100, speed = 22, r = 1.0, reach = 0.8, matter = 1, turnDeg = 540 },
	[2] = { hp = 235, speed = 19, r = 1.6, reach = 1.2, matter = 2, turnDeg = 360 },
	[3] = { hp = 560, speed = 16, r = 3.0, reach = 1.8, matter = 4, turnDeg = 240 },
	[4] = { hp = 2400, speed = 8, r = 6.0, reach = 3.0, matter = 16, turnDeg = 60 },
}
local RULES = { stunMax = 0.6, stunImmunity = 3.0, slowCap = 0.3, shieldCap = 0.2, f4SlowFactor = 0.5, shove = 8 }
local SURROUND = { [4] = 1.75, [3] = 2 }       -- 6+ little ones on a big one: GOOED / CRACKED

-- ===== ATTACK COMMIT (29 Oct, James: "AI has to commit and finish an attack before doing another"; ChatGPT design audit
-- r1 UNSOUND -> r2 SOUND WITH CHANGES, design\aitest-fixes\commit-*.md) =====
-- BODY[kit][anim] = when that attack's own body animation has finished (its pose keys back at rest, read from the attack
-- modules: Attacks / AttacksCrunch / AttacksDrip). No new attack may START before it (beginning in playAnim, checked by
-- canStart). The unit may still WALK after its lock. Repeating passives commit for their cycle. RELEASE[kit][anim] =
-- when a thrown attack leaves the body: from then its hit belongs to the projectile (a cancel / defeat before it drops
-- the hit; after it the hit still lands)
local BODY = {
	CrunchF4 = { Slam = 3.40, Boulder = 4.70, Sun = 6.20 },
	SquishF4v5 = { Slam = 3.40, Bomb = 2.85, Wave = 3.45 },
	SquishF3v5 = { Pound = 1.25, Grab = 2.00, Thump = 1.40 },
	CrunchF3v5 = { Gore = 1.25, Stamp = 1.16, Charge = 2.60 },
	SquishF2v5 = { Slap = 1.00, Sticky = 3.20, Boing = 1.85 },
	CrunchF2v5 = { Snap = 1.00, Block = 3.55, Sweep = 1.18 },
	SquishF1v5 = { Cling = 3.32, Boing = 0.95, Squash = 0.95, Bombs = 3.07 },
	CrunchF1v5 = { Chip = 4.74, Curl = 1.11, Roll = 1.85 },
}
local RELEASE = { CrunchF4 = { Boulder = 2.55, Sun = 3.20 }, SquishF4v5 = { Bomb = 2.55, Wave = 2.10 } }   -- (Sun: its impact makes the burning spot a world hazard)
local probeRun        -- (test hooks: the remote handler, set at the bottom; "arm" fires one at an exact attack time)
-- the only moves allowed to cut the unit's own current move short (a reaction, never a new attack choice)
local INTERRUPTS = { Cling = { Boing = true, Squash = true }, Chip = { Curl = true } }

-- ===== the kits: slot A = passive, B = auto, C = ORDER (numbers: kits.mjs; times: the batch specs / attack modules) =====
-- every `anim` is a key of Attacks.FOR[form]; `hitAt` = seconds from the animation's start; `lock` = busy until
local KITS = {
	CrunchF4 = { label = "COLOSSUS", race = "CRUNCH", form = 4, defeatDur = 3.8,
		passive = { kind = "slam", anim = "Slam", every = 4, hitAt = 1.64, lock = 3.4, radius = 10, arc = 120, hit = 400, splash = 0.25, cap = 2, mult = { [3] = 2.5 }, stun = 0.3 },
		auto = { kind = "lob", anim = "Boulder", cd = 12, hitAt = 3.4, lock = 2.6, farOnly = 6, range = 30, coneDeg = 30, radius = 4, hit = 160, cap = 3 },
		order = { kind = "beam", anim = "Sun", cd = 28, hitAt = 3.2, lock = 3.2, range = 30, radius = 8, hit = 300, side = 50, cap = 4, mult = { [3] = 2.5 }, burn = 8, burnDur = 2 } },
	SquishF4v5 = { label = "TITAN", race = "SQUISH", form = 4, defeatDur = 3.8,
		passive = { kind = "slam", anim = "Slam", every = 4, hitAt = 1.64, lock = 3.4, radius = 10, arc = 120, hit = 400, splash = 0.25, cap = 2, mult = { [3] = 2.5 } },
		auto = { kind = "lob", anim = "Bomb", cd = 12, hitAt = 3.4, lock = 2.6, farOnly = 6, range = 30, coneDeg = 30, radius = 5, hit = 160, cap = 3, slow = 0.25, slowDur = 2.5 },
		order = { kind = "lane", anim = "Wave", cd = 28, hitAt = 3.2, lock = 3.2, length = 24, width = 12, hit = 300, side = 60, cap = 4, mult = { [3] = 2.5 }, slow = 0.25, slowDur = 2 } },
	SquishF3v5 = { label = "BRUTE", race = "SQUISH", form = 3, defeatDur = 3.8,
		passive = { kind = "melee", anim = "Pound", every = 1.25, hitAt = 0.60, lock = 1.02, hit = 55, mult = { [2] = 1.5 } },
		auto = { kind = "pull", anim = "Grab", cd = 8, catchAt = 0.76, hitAt = 1.30, lock = 1.65, range = 14, hit = 30, root = 0.5, prefer = { 2, 1, 3 } },
		order = { kind = "shieldBuff", anim = "Thump", cd = 26, hitAt = 0.80, lock = 1.40, engage = 10, selfShield = 70, allyShield = 30, allyRadius = 8, shieldDur = 6, haste = 0.2, hasteDur = 4 } },
	CrunchF3v5 = { label = "RAM", race = "CRUNCH", form = 3, defeatDur = 3.65,
		passive = { kind = "melee", anim = "Gore", every = 1.25, hitAt = 0.55, lock = 1.05, hit = 55, mult = { [2] = 1.5 } },
		auto = { kind = "stunRing", anim = "Stamp", cd = 9, hitAt = 0.68, lock = 1.16, radius = 5, hit = 30, stun = 0.5, cap = 2, forms = { [2] = true, [3] = true } },
		order = { kind = "charge", anim = "Charge", cd = 24, lock = 2.5, dur = 2.6, maxRun = 18, minGap = 4, seek = 26, width = 4, hit = 90, side = 20, cap = 3, mult = { [2] = 1.5 }, knock = 4, prefer = { 2, 3 } } },
	SquishF2v5 = { label = "TWIN", race = "SQUISH", form = 2, defeatDur = 3.8,
		passive = { kind = "cleave", anim = "Slap", every = 1.0, hitAt = 0.39, lock = 0.56, hit = 20 },
		auto = { kind = "zoneSlow", anim = "Sticky", cd = 9, hitAt = 0.5, lock = 0.85, radius = 5, slow = 0.25, dur = 2.5, trigger = 3 },
		order = { kind = "leapSlam", anim = "Boing", cd = 22, hitAt = 0.80, lock = 1.85, dur = 1.85, range = 14, radius = 5, hit = 20, cap = 3, stunF1 = 0.4, trigger = 2 } },
	CrunchF2v5 = { label = "PINCER", race = "CRUNCH", form = 2, defeatDur = 3.6,
		passive = { kind = "cleave", anim = "Snap", every = 1.0, hitAt = 0.38, lock = 0.58, hit = 20 },
		auto = { kind = "block", anim = "Block", cd = 10, upAt = 0.23, lock = 3.55, dr = 0.3, dur = 3, trigger = 2 },
		order = { kind = "sweep", anim = "Sweep", cd = 22, hitAt = 0.72, lock = 1.08, length = 7, width = 6, hit = 20, cap = 3, knock = 2, trigger = 2 } },
	SquishF1v5 = { label = "DRIP", race = "SQUISH", form = 1, defeatDur = 3.7,
		-- CLING: hop on, stick, 5 bites from 0.82 every 0.50, then again (it rides the target: the server keeps it there)
		passive = { kind = "cling", anim = "Cling", dur = 3.32, bites = { 0.82, 1.32, 1.82, 2.32, 2.82 }, hit = 6, ride = true },
		auto = { kind = "dodge", anim = "Boing", fail = "Squash", cd = 10, leap = 10, dur = 0.95, dr = 0.5 },
		order = { kind = "leapOnto", anim = "Bombs", cd = 24, dur = 3.07, range = 12, bonusAt = 1.31, bonus = 15, bites = { 1.81, 2.31, 2.81 }, hit = 6, perTarget = 10 } },
	CrunchF1v5 = { label = "PEBBLE", race = "CRUNCH", form = 1, defeatDur = 3.2,
		-- CHIP: skitter to its spot at the big one's foot, then 4 cycles of 0.96 from 0.50: horn jab +0.40, bite +0.65
		passive = { kind = "cling", anim = "Chip", dur = 4.74, bites = { 0.90, 1.15, 1.86, 2.11, 2.82, 3.07, 3.78, 4.03 }, hit = 6 },
		auto = { kind = "curl", anim = "Curl", cd = 12, hitIn = 0.55, dur = 1.11, dr = 0.7, hold = 1.2 },
		order = { kind = "rush", anim = "Roll", cd = 24, dur = 1.85, hitAt = 1.23, range = 16, minGap = 2, dr = 0.3, bonus = 20 } },
}
local BIG = { [3] = true, [4] = true }

-- the menu lists these (a client can't see ServerStorage): one StringValue per form, value = its label
local list = AF:FindFirstChild("AITestForms") or Instance.new("Folder")
list.Name = "AITestForms"; list.Parent = AF
list:ClearAllChildren()
for name, k in KITS do
	if forms:FindFirstChild(name) then
		local v = Instance.new("StringValue"); v.Name = name; v.Value = k.label; v:SetAttribute("Form", k.form); v.Parent = list
	else
		warn("[AITest] no template for", name)
	end
end

local DT, SEND = 0.05, 0.1        -- brain + motion at a fixed 20 Hz (the sim's canonical rate), positions to clients 10 Hz
local SEP = 0.9                   -- bodies may overlap 10 % (the sim's separation rule)
local live: { [Model]: any } = {}
local serial = 0
local function clock() return workspace:GetServerTimeNow() end

local function flatDist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end
local function gapOf(a, b) return flatDist(a, b) - a.r - b.r end
local function wrap(a) a = (a + math.pi) % (2 * math.pi); return a - math.pi end
-- facing angle f: forward = (sin f, 0, -cos f) (matches the client: CFrame.lookAt along that vector)
local function forward(f) return math.sin(f), -math.cos(f) end
local function bearing(u, x, z) return math.atan2(x - u.x, -(z - u.z)) end
local function hostile(a, b) return a ~= b and not b.dead and (a.team == "ALL" or b.team == "ALL" or a.team ~= b.team) end
local function friendly(a, b) return a ~= b and not b.dead and not hostile(a, b) end

local brainCtx = { units = {}, now = clock, DT = DT, hostile = hostile }
local brain = Brain.new(brainCtx)

-- ===== the message to clients =====
local events, extras = {}, {}
local function event(e) table.insert(events, e) end
-- an attack carried it somewhere: switch at this moment (two samples 1 ms apart), not a slide over the next 0.1 s
local function jump(u, nx, nz)
	local t = clock()
	table.insert(extras, { u.id, t - 0.001, u.x, u.z, u.face, 0 })
	u.x, u.z, u.v = nx, nz, 0
	if u.brain then u.brain.vx, u.brain.vz = 0, 0 end
	table.insert(extras, { u.id, t, u.x, u.z, u.face, 0 })
end

-- ===== HP bar (server-built, follows the model's primary part on every client) =====
local function makeBar(m: Model, u)
	local pp = m.PrimaryPart
	if not pp then return end
	local g = Instance.new("BillboardGui")
	g.Name = "AIBar"; g.StudsOffsetWorldSpace = Vector3.new(0, ({ 3.5, 5, 8, 16 })[u.form], 0)
	g.Size = (u.form >= 3) and UDim2.fromOffset(150, 34) or UDim2.fromOffset(90, 26)
	g.AlwaysOnTop = true; g.MaxDistance = (u.form >= 3) and 400 or 160; g.Adornee = pp
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 16); name.BackgroundTransparency = 1; name.Font = Enum.Font.GothamBold; name.TextSize = (u.form >= 3) and 13 or 10
	name.TextColor3 = Color3.new(1, 1, 1); name.TextStrokeTransparency = 0.4; name.Name = "Title"; name.Parent = g
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 18); back.Size = UDim2.new(1, 0, 0, (u.form >= 3) and 10 or 6); back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0; back.Name = "Back"; back.Parent = g
	local fill = Instance.new("Frame")
	fill.Name = "Fill"; fill.Size = UDim2.fromScale(1, 1); fill.BorderSizePixel = 0; fill.Parent = back
	local sh = Instance.new("Frame")                                   -- (a shield: white over the bar)
	sh.Name = "Shield"; sh.Size = UDim2.fromScale(0, 1); sh.BackgroundColor3 = Color3.new(1, 1, 1); sh.BackgroundTransparency = 0.3
	sh.BorderSizePixel = 0; sh.Parent = back
	g.Parent = pp
	u.bar = g
end
local function refreshBar(u)
	if not u.m.Parent then return end
	u.m:SetAttribute("Hp", math.floor(u.hp + 0.5)); u.m:SetAttribute("MaxHp", u.maxHp)   -- (the menu reads these)
	u.m:SetAttribute("Team", u.team); u.m:SetAttribute("AiOn", u.ai)
	if not u.bar then return end
	local col = (u.team == "A") and Color3.fromRGB(80, 170, 255) or (u.team == "B") and Color3.fromRGB(255, 150, 60) or Color3.fromRGB(240, 70, 70)
	local back = u.bar:FindFirstChild("Back")
	local title, fill, sh = u.bar:FindFirstChild("Title"), back and back:FindFirstChild("Fill"), back and back:FindFirstChild("Shield")
	if not (title and fill and sh) then return end
	title.Text = (u.form >= 3) and string.format("%s  [%s]  %s", u.label, u.team, u.ai and "AI" or "idle") or string.format("%s %s", u.team, u.ai and "" or "idle")
	title.TextColor3 = col
	fill.Size = UDim2.fromScale(math.clamp(u.hp / u.maxHp, 0, 1), 1)
	fill.BackgroundColor3 = col
	sh.Size = UDim2.fromScale(math.clamp(u.shield / u.maxHp, 0, 1), 1)
end
-- (the bar moves when the hit is SEEN: the clients draw 0.35 s behind the server)
local function barLater(u) task.delay(0.35, refreshBar, u) end

-- ===== effects on a unit =====
local function activeDr(u, t)
	local dr = 0
	for i = #u.drs, 1, -1 do
		local d = u.drs[i]
		if t > d.to then table.remove(u.drs, i) elseif t >= d.from then dr = math.max(dr, d.dr) end
	end
	return dr
end
local function slowK(u, t)
	local s = 0
	for i = #u.slows, 1, -1 do
		local d = u.slows[i]
		if t > d.to then table.remove(u.slows, i) else s = math.max(s, d.k) end
	end
	s = math.min(s, RULES.slowCap)
	if u.form == 4 then s *= RULES.f4SlowFactor end
	return 1 - s
end
local function slow(u, k, dur) if not u.dead then table.insert(u.slows, { k = k, to = clock() + dur }) end end
local function stun(u, dur)
	local t = clock()
	if u.dead or u.form == 4 or t < u.stunImmuneUntil then return end
	u.stunUntil = math.max(u.stunUntil, t + math.min(dur, RULES.stunMax)); u.stunImmuneUntil = u.stunUntil + RULES.stunImmunity
end
-- src = { caster id, caster's attack id } (a Brute's Thump): the shell the client draws belongs to that cast
local function shield(u, amount, dur, src)
	u.shield = math.max(u.shield, math.min(amount, u.maxHp * RULES.shieldCap)); u.shieldUntil = clock() + dur
	if src then u.shieldSrc = src end                      -- (a newer cast takes the shell over)
	barLater(u)
end
-- u's shield is gone (used up / timed out): the client ends the shell of the cast that made it, matched by that cast
-- (caster + attack id), so a late end never removes a newer cast's shell and a shell already ended is never drawn
local function shieldEnded(u, t)
	local s = u.shieldSrc
	if s then event({ u.id, "shieldEnd", t, s[1], s[2] }); u.shieldSrc = nil end
end
-- a shove (knock / pull): at most RULES.shove studs per victim per 3 s, giants never
local function shove(u, dx, dz)
	if u.dead or u.form == 4 then return end
	local t = clock()
	if t > u.shoveT then u.shoveT, u.shoved = t + 3, 0 end
	local L = math.sqrt(dx * dx + dz * dz)
	local k = math.min(L, RULES.shove - u.shoved)
	if k <= 0.05 or L < 1e-3 then return end
	u.shoved += k
	jump(u, u.x + dx / L * k, u.z + dz / L * k)
end

-- ===== actions =====
-- test readouts (workspace attributes): illegal overlaps, stale hits blocked, order outcomes
local function bump(name, by) workspace:SetAttribute(name, (workspace:GetAttribute(name) or 0) + (by or 1)) end

-- THE one place an attack begins (every start path ends here): a new attack id, its body commitment, the event (with the
-- id, so the client can tell attacks apart and a late cancel only touches its own). `scale` = a haste cadence (< 1)
local function playAnim(u, anim, ax, az, tgt, slot, scale)
	local t = clock()
	-- (build audit r1: ENFORCED, not just counted: an ordinary start before the current body has finished is refused
	-- here, with no new id and no event. Every start function also checks `gate` first, before it touches any state;
	-- authorised interrupts end the commitment first (interrupt), Defeat always plays)
	if anim ~= "Defeat" and t < (u.commitUntil or 0) then bump("AITestIllegalOverlaps"); return nil end
	u.atkId = (u.atkId or 0) + 1
	u.curAnim = anim
	local body = (BODY[u.name] and BODY[u.name][anim]) or 0
	u.commitUntil = (anim == "Defeat") and math.huge or t + body * (scale or 1)
	u.lastAtk = { anim = anim, t0 = t }
	-- (the playback speed: a hasted swing is drawn that much faster, so its body ends when its commitment does)
	-- (+ its release time, if it throws something: the client tells its flying part from its body part by it)
	event({ u.id, "atk", anim, t, ax or 0, az or 0, tgt and tgt.id or 0, slot or 0, u.atkId, 1 / (scale or 1),
		RELEASE[u.name] and RELEASE[u.name][anim] or false })
	local arm = u.armed                                    -- (test hook "arm": a probe at an exact time into this attack)
	if arm and probeRun and (not arm.anim or arm.anim == anim) then
		u.armed = nil
		task.delay(arm.offset or 0, probeRun, nil, arm.cmd, u.id, arm.mode, nil)
	end
	return t
end
-- the first line of every attack start, before it changes anything: may this unit begin a new attack now?
local function gate(u)
	if clock() < (u.commitUntil or 0) then bump("AITestIllegalOverlaps"); return false end
	return true
end
-- may this unit start a new attack now? (alive, AI on, not stunned, not busy, its last attack's body finished)
local function canStart(u, now)
	return not u.dead and u.ai and now >= u.stunUntil and now >= u.busyUntil and now >= (u.commitUntil or 0)
end
local function release(u)                         -- (stop riding / holding: back to the brain)
	if u.on and u.on.riders then u.on.riders[u] = nil end
	u.on, u.pinned, u.slotNo, u.rideA, u.rideC = nil, false, nil, nil, nil
end
local function cancel(u)                          -- (drop the current attack: its pending hits die with it)
	for i = #u.pending, 1, -1 do if not u.pending[i].released then table.remove(u.pending, i) end end
	release(u); u.busyUntil = 0
end
-- an AUTHORISED interrupt (a dodge out of its own Cling / Chip, the anti-cling shake-off, defeat): the current attack's
-- unreleased hits are dropped, the client is told (by attack id) to stop that attack's attached effects, and the body
-- commitment ends so the reaction may start
local function interrupt(u, reason)
	if u.atkId then
		-- (gone = this attack's projectile has ACTUALLY been handed over (the hand-over action ran), not "it's past the
		-- time": the client then keeps only the flying part; the body part always stops)
		event({ u.id, "cancel", u.atkId, clock(), reason, u.releasedAtk == u.atkId })
	end
	cancel(u)
	u.commitUntil = 0
end
-- a pending action of u at time `at`. Unreleased ones belong to the attack that scheduled them (atkId): if that attack is
-- no longer u's current one they are stale and never run. Returns the record (setting .released hands a thrown attack's
-- hit to its projectile)
local function later(u, at, fn, released)
	local p = { at = at, fn = fn, released = released, atkId = u.atkId }
	table.insert(u.pending, p)
	return p
end

local function die(u)
	if u.dead then return end
	interrupt(u, "defeat")                                   -- (its released projectiles keep flying: they still land)
	-- (its riders let go now: no bites queued on a dead carrier, no dead `on` kept; each stays where it was, which the ride
	-- step kept on the body. Audit r3)
	for r in u.riders do if r.on == u then interrupt(r, "carrier") end end
	table.clear(u.riders)
	u.dead, u.ai = true, false
	if u.brain then brain.clearTarget(u) end
	playAnim(u, "Defeat")
	refreshBar(u)
	task.delay(u.kit.defeatDur + 1.9, function() if u.m.Parent then u.m:Destroy() end end)
end

-- anti-cling service record of rider r on carrier u (see antiCling in step). The counters belong to the CURRENT carrier:
-- a rider on a new carrier, or back after > 2 s off it, starts clean (audit r4). svcAllow = its never-served allowance,
-- fixed when its clock starts: max(30, (riders on u / slam cap, rounded up) x cycle + 2 cycles): a 32-Drip swarm waits
-- its turn under the cap without being shaken off, and a newcomer never extends an older rider's deadline

local function svcFor(r, u, now)
	if r.svc ~= u or now - (r.svcSeen or -1e9) > 2 then
		local p, n = u.kit.passive, 0
		for o in u.riders do if not o.dead and o.on == u then n += 1 end end
		local every = p.every or 4
		r.svc, r.svcSince, r.svcHit, r.svcMiss = u, now, nil, 0
		r.svcAllow = math.max(30, math.ceil(math.max(n, 1) / (p.cap or 1)) * every + 2 * every)
	end
	r.svcSeen = now
end

local function damage(src, u, amount)
	if u.dead or amount <= 0 then return end
	local t = clock()
	amount *= 1 - activeDr(u, t)
	if u.shield > 0 and t <= u.shieldUntil then
		local a = math.min(u.shield, amount); u.shield -= a; amount -= a
		if u.shield <= 0 then shieldEnded(u, t) end
	end
	if workspace:GetAttribute("AITestNoDmgId") == u.id then amount = 0 end   -- (test hook: an unhittable unit, every hit 0)
	u.hp -= amount
	-- (anti-cling watchdog: hurt by the carrier it rides = served. Only damage actually DEALT, after DR / shield (audit r3))
	if amount > 0 and u.on == src then svcFor(u, src, t); u.svcHit, u.svcMiss = t, 0 end
	-- the hurt plays from the side the hit came from (+1 = from its right); a swarm's nibbles don't restart it every bite
	if amount >= 0.04 * u.maxHp or t - u.lastHurtT > 0.9 then
		u.lastHurtT = t
		local fx, fz = forward(u.face)
		local side = ((src.x - u.x) * -fz + (src.z - u.z) * fx) >= 0 and 1 or -1
		event({ u.id, "hurt", t, side })
	end
	if u.hp <= 0 then u.hp = 0; task.delay(0.35, die, u) end   -- (it falls when the killing blow is seen)
	barLater(u)
end

-- shapes (sim.mjs inShape): a target counts if its centre is inside the shape grown by half its body radius
local function inReach(u, e, radius) return flatDist(u, e) <= radius + u.r + e.r * 0.5 end
local function inArc(u, e, radius, arcDeg)
	if not inReach(u, e, radius) then return false end
	return flatDist(u, e) < e.r or math.abs(wrap(bearing(u, e.x, e.z) - u.face)) <= math.rad(arcDeg / 2)
end
-- a giant's slam: its 120-deg wedge, plus anything riding ITS body within the same reach (the slam shakes the whole body;
-- a rider drawn on its back can't be faced by turning, it turns with it. Still capped, still Boing-dodgeable)
local function ridesOn(e, u) return e.on == u and e.rideA ~= nil end      -- (riding the body; a Pebble chipping a foot isn't)
-- anti-cling: its carrier picked this rider for a hit and dealt it nothing (shield, DR, an unhittable test unit) = a miss
local function tried(u, e, hp0)
	if not ridesOn(e, u) then return end
	svcFor(e, u, clock())
	if e.hp >= hp0 then e.svcMiss = (e.svcMiss or 0) + 1 end
end
local function slamHits(u, s, e) return inArc(u, e, s.radius, s.arc) or (ridesOn(e, u) and inReach(u, e, s.radius)) end
local function inCircle(cx, cz, radius, e) return math.sqrt((e.x - cx) ^ 2 + (e.z - cz) ^ 2) < radius + e.r * 0.5 end
local function laneCoords(ox, oz, face, e)
	local fx, fz = forward(face)
	local dx, dz = e.x - ox, e.z - oz
	return dx * fx + dz * fz, -dx * fz + dz * fx              -- along, across (+ = its right)
end
local function inLane(ox, oz, face, len, width, e)
	local along, across = laneCoords(ox, oz, face, e)
	return along > -1 and along < len + e.r * 0.5 and math.abs(across) < width / 2 + e.r * 0.5
end
local function enemiesWhere(u, test)
	local out = {}
	for _, e in live do if hostile(u, e) and test(e) then table.insert(out, e) end end
	return out
end
local function nearestFirst(cx, cz, arr)
	table.sort(arr, function(a, b) return ((a.x - cx) ^ 2 + (a.z - cz) ^ 2) < ((b.x - cx) ^ 2 + (b.z - cz) ^ 2) end)
	return arr
end
local function preferred(u, pool, prefer)          -- (the kit's prefer list, then the nearest)
	local rank = {}
	for i, f in prefer or {} do rank[f] = i end
	table.sort(pool, function(a, b)
		local ra, rb = rank[a.form] or 9, rank[b.form] or 9
		if ra ~= rb then return ra < rb end
		return flatDist(u, a) < flatDist(u, b)
	end)
	return pool[1]
end

-- ===== DANGER: a giant's slam / Order is coming; the little ones that can, react (BOING / CURL UP) =====
-- shape = { kind = "arc" | "circle" | "lane", ... }; hitAt = when it lands (server time)
local function escapeFrom(e, shape)
	local m = e.r * 0.5 + 0.6
	if shape.kind == "arc" then
		local s = shape.src
		local d = math.max(0.01, flatDist(s, e))
		return (e.x - s.x) / d, (e.z - s.z) / d, shape.radius + s.r + m - d
	elseif shape.kind == "circle" then
		local dx, dz = e.x - shape.x, e.z - shape.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 0.01 then dx, dz, d = 1, 0, 1 end
		return dx / d, dz / d, shape.radius + m - d
	else
		local _, across = laneCoords(shape.x, shape.z, shape.face, e)
		local fx, fz = forward(shape.face)
		local sg = (across >= 0) and 1 or -1
		return -fz * sg, fx * sg, shape.width / 2 + m - math.abs(across)
	end
end
-- may e start reaction `anim` now? Free: yes (whatever is left of an old attack is dropped). Mid-attack: only the
-- authorised cut-shorts (INTERRUPTS: a Drip's Boing / Squash out of its own Cling, a Pebble's Curl out of its Chip).
-- A refused reaction gives its cooldown back
local function mayReact(e, anim)
	if e.dead then return false end
	local now = clock()
	if now < (e.commitUntil or 0) then
		if not (INTERRUPTS[e.curAnim] and INTERRUPTS[e.curAnim][anim]) then e.autoReadyAt = now; return false end
		interrupt(e, "dodge")
	else
		cancel(e)
	end
	return true
end
local function warnDanger(src, shape, hitAt, inShape)
	for _, e in live do
		if not (hostile(src, e) and e.ai and e.form == 1 and inShape(e)) then continue end
		local a = e.kit.auto
		if not a or clock() < e.autoReadyAt or clock() < e.stunUntil then continue end
		e.autoReadyAt = clock() + a.cd
		local react = clock() + 0.15 + math.random() * 0.3        -- (its notice beat: LC Thumper reacts after 0.2 s)
		if a.kind == "dodge" then
			-- BOING: spring to the nearest edge of the danger, up to 10 studs; can't get clear = SQUASHED flat (half damage)
			local dx, dz, need = escapeFrom(e, shape)
			if need <= a.leap and react + a.dur < hitAt then
				local tx, tz = e.x + dx * math.max(need, 1), e.z + dz * math.max(need, 1)
				later(e, react, function()
					if not mayReact(e, a.anim) then return end
					e.busyUntil, e.pinned = clock() + a.dur, true
					playAnim(e, a.anim, tx, tz)
					later(e, clock() + a.dur, function() e.pinned = false; jump(e, tx, tz) end)
				end, true)
			else
				local t0 = math.max(react, hitAt - 0.1)
				later(e, t0, function()
					if not mayReact(e, a.fail) then return end
					e.busyUntil, e.pinned = clock() + a.dur, true
					table.insert(e.drs, { from = clock(), to = clock() + 0.5, dr = a.dr })
					playAnim(e, a.fail)
					later(e, clock() + a.dur, function() e.pinned = false end)
				end, true)
			end
		elseif a.kind == "curl" then
			-- CURL UP: tuck so the shell takes the hit (its curl lands 0.55 in), stays put
			local t0 = math.max(react, hitAt - a.hitIn)
			later(e, t0, function()
				if not mayReact(e, a.anim) then return end
				e.busyUntil, e.pinned = clock() + a.dur, true
				table.insert(e.drs, { from = clock(), to = clock() + a.hold, dr = a.dr })
				playAnim(e, a.anim)
				later(e, clock() + a.dur, function() e.pinned = false end)
			end, true)
		end
	end
end

-- ===== the giants (batch 1 + 2) =====
local function startSlam(u, s, now)
	if not gate(u) then return end
	u.busyUntil = now + s.lock; u.nextPassive = now + s.every
	playAnim(u, s.anim)
	local test = function(e) return slamHits(u, s, e) end
	warnDanger(u, { kind = "arc", src = u, radius = s.radius }, now + s.hitAt, test)
	later(u, now + s.hitAt, function()
		local k = workspace:GetAttribute("AITestSlamMiss") and 0 or 1   -- (test hook: every slam deals nothing)
		-- (its own riders first, the longest-unserved first (audit r3: the cap of 2 must not keep skipping one), then the
		-- rest nearest first, as before)
		local hit = nearestFirst(u.x, u.z, enemiesWhere(u, test))
		local function waited(e) return ridesOn(e, u) and -math.max(e.svcSince or now, e.svcHit or -1e9) or 1 end
		table.sort(hit, function(a, b)
			local ra, rb = ridesOn(a, u), ridesOn(b, u)
			if ra ~= rb then return ra end
			if ra then return waited(a) > waited(b) end
			return flatDist(u, a) < flatDist(u, b)
		end)
		for i = 1, math.min(#hit, s.cap) do
			local e = hit[i]
			local hp0 = e.hp
			damage(u, e, k * s.hit * ((i == 1) and 1 or s.splash) * (s.mult[e.form] or 1))
			tried(u, e, hp0)
			if s.stun then stun(e, s.stun) end
		end
	end)
end
-- anti-cling last resort (the watchdog in step): rider r Boings off u, as its own dodge, to the first CLEAR spot just past
-- u's body (straight out from where it rides, then 45-deg steps either side; no body of another unit there). It lets go
-- in every case: nowhere clear = it drops where it is (the separation pass then pushes it out). It can't cling to u again
-- for 1 s after landing (audit r3: no instant re-cling loop; scoped to this carrier only)
local function shakeOff(u, r, now)
	u.m:SetAttribute("ShakeOffs", (u.m:GetAttribute("ShakeOffs") or 0) + 1)   -- (test readout)
	local L = flatDist(u, r)
	local ang = (L < 0.25) and (u.face + math.pi) or bearing(u, r.x, r.z)      -- (at the pivot: off its back)
	local d = u.r + r.r + 1.5
	local tx, tz
	for i = 0, 7 do
		local fx, fz = forward(ang + ((i % 2 == 1) and 1 or -1) * math.ceil(i / 2) * math.pi / 4)
		local cx, cz = u.x + fx * d, u.z + fz * d
		local clear = true
		for _, o in live do
			if o ~= r and o ~= u and not o.dead and not o.on and math.sqrt((o.x - cx) ^ 2 + (o.z - cz) ^ 2) < o.r + r.r then clear = false; break end
		end
		if clear then tx, tz = cx, cz; break end
	end
	local a = r.kit.auto
	local dur = (a and a.kind == "dodge") and a.dur or 0.95
	interrupt(r, "shake")                                    -- (drops its bites and lets go: release)
	r.noClingOn, r.noClingUntil = u, now + dur + 1.0
	r.svc, r.svcMiss = nil, 0                                -- (a fresh clock if it comes back)
	if not tx then return end
	r.busyUntil, r.pinned = now + dur, true
	playAnim(r, (a and a.kind == "dodge") and a.anim or "Boing", tx, tz)
	later(r, now + dur, function() r.pinned = false; jump(r, tx, tz) end)
end
-- a thrown attack's hit: owned by the cast (dropped by a cancel / defeat) until its RELEASE time, then by the projectile
-- (it lands even if the thrower falls). The hand-over is itself a cast action, so a cancel before it drops both
local function handOver(u, anim, hitP, now)
	local rel = RELEASE[u.name] and RELEASE[u.name][anim]
	local id = u.atkId
	if rel then later(u, now + rel, function() hitP.released = true; u.releasedAtk = id end) end
end
local function startLob(u, a, target, now)
	if not gate(u) then return end
	u.busyUntil = now + a.lock; u.autoReadyAt = now + a.cd
	local ax, az = target.x, target.z                     -- (it lands where the target was: dodgeable, like the sim)
	playAnim(u, a.anim, ax, az, target)
	local hitP = later(u, now + a.hitAt, function()
		local hit = nearestFirst(ax, az, enemiesWhere(u, function(e) return inCircle(ax, az, a.radius, e) end))
		for i = 1, math.min(#hit, a.cap) do
			damage({ x = ax, z = az }, hit[i], a.hit)
			if a.slow then slow(hit[i], a.slow, a.slowDur) end
		end
	end)
	handOver(u, a.anim, hitP, now)
end

-- ===== passives =====
local function riders(e, side)                       -- little ones of `side` stuck on e right now
	local n = 0
	for r in e.riders do if not r.dead and r.on == e and not hostile(side, r) then n += 1 end end
	return n
end
local function freeSlotOn(e)
	local used = {}
	for r in e.riders do if r.slotNo then used[r.slotNo] = true end end
	for i = 0, 15 do if not used[i] then return i end end
	return 0
end
-- a little one's bite: x1.75 / x2 on a giant / Brute with 6+ of its side on it
local function bite(u, e, hit)
	if e.dead or u.on ~= e then return end
	local k = (BIG[e.form] and riders(e, u) >= 6) and (SURROUND[e.form] or 1) or 1
	damage(u, e, hit * k)
end
local function startCling(u, p, e, now)
	if not gate(u) then return end
	u.busyUntil = now + p.dur; u.pinned, u.on = true, e
	u.slotNo = freeSlotOn(e); e.riders[u] = true
	if p.ride then
		-- (29 Oct, audit r2: the offset is in the carrier's frame (along / across its facing) so it turns WITH it, as the
		-- client draws a Drip stuck to the body. A world offset let a turning giant slide round under its riders)
		local fx, fz = forward(e.face)
		local dx, dz = u.x - e.x, u.z - e.z
		u.rideA, u.rideC = dx * fx + dz * fz, -dx * fz + dz * fx
	end
	u.face = bearing(u, e.x, e.z)
	playAnim(u, p.anim, e.x, e.z, e, u.slotNo)
	for _, bt in p.bites do
		later(u, now + bt, function()
			-- (the target walked off a little one that only stands at its foot: the bites stop)
			if not p.ride and gapOf(u, e) > u.reach + 1.5 then return end
			bite(u, e, p.hit)
		end)
	end
	later(u, now + p.dur, function() release(u) end)
end
local function startMelee(u, p, e, now)
	if not gate(u) then return end
	local cad = (now < u.hasteUntil) and 1 / (1 + u.haste) or 1
	cad /= slowK(u, now)
	u.busyUntil = now + p.lock * cad; u.nextPassive = now + p.every * cad
	-- (not toward its own rider: it rides the body, so turning swings it round too; the hit is by contact distance)
	if not ridesOn(e, u) then u.face = bearing(u, e.x, e.z) end
	playAnim(u, p.anim, e.x, e.z, e, nil, cad)              -- (haste: its next swing may start that much sooner)
	later(u, now + p.hitAt * cad, function()
		if e.dead or gapOf(u, e) > u.reach + 1.0 then return end
		local hp0 = e.hp
		if p.kind == "melee" then
			damage(u, e, p.hit * (p.mult and p.mult[e.form] or 1))
			tried(u, e, hp0)
		else
			-- cleave: both tendrils / claws at once; the second hits a little one beside it (F1 only)
			damage(u, e, p.hit)
			tried(u, e, hp0)
			local second = nil
			for _, o in live do
				if o ~= e and hostile(u, o) and o.form == 1 and gapOf(u, o) <= u.reach + 1.5 then second = o; break end
			end
			if second then damage(u, second, p.hit) end
		end
	end)
end

-- ===== autos (it uses them by itself) =====
local function tryAuto(u, e, now)
	if not gate(u) then return false end
	local a = u.kit.auto
	if not a or now < u.autoReadyAt then return false end
	if a.kind == "lob" then
		local gap = gapOf(u, e)
		local ang = math.abs(wrap(bearing(u, e.x, e.z) - u.face))
		if gap > a.farOnly and gap <= a.range and ang <= math.rad(a.coneDeg) then
			if #enemiesWhere(u, function(o) return gapOf(u, o) < a.farOnly end) == 0 then startLob(u, a, e, now); return true end
		end
	elseif a.kind == "zoneSlow" then
		local near = enemiesWhere(u, function(o) return inCircle(u.x, u.z, a.radius, o) end)
		if #near >= a.trigger then
			u.busyUntil, u.autoReadyAt = now + a.lock, now + a.cd
			playAnim(u, a.anim)
			later(u, now + a.hitAt, function()
				for _, o in enemiesWhere(u, function(o) return inCircle(u.x, u.z, a.radius, o) end) do slow(o, a.slow, a.dur) end
			end)
			return true
		end
	elseif a.kind == "pull" then
		-- STRETCH GRAB: a runner out of reach (never a giant), the kit's prefer order
		local pool = enemiesWhere(u, function(o) local g = gapOf(u, o); return o.form ~= 4 and g > u.reach + 1 and g <= a.range end)
		local v = preferred(u, pool, a.prefer)
		if v then
			u.busyUntil, u.autoReadyAt = now + a.lock, now + a.cd
			u.face = bearing(u, v.x, v.z)
			playAnim(u, a.anim, v.x, v.z, v)
			later(u, now + a.catchAt, function() if not v.dead and gapOf(u, v) <= a.range + 2 then stun(v, a.root) end end)
			later(u, now + a.hitAt, function()
				if v.dead or gapOf(u, v) > a.range + 2 then return end
				damage(u, v, a.hit)
				local fx, fz = forward(u.face)
				local want = u.r + v.r + 0.5               -- (yanked in to just in front of it)
				shove(v, u.x + fx * want - v.x, u.z + fz * want - v.z)
			end)
			return true
		end
	elseif a.kind == "block" then
		local near = enemiesWhere(u, function(o) return (o.form == 1 or o.form == 2) and gapOf(u, o) <= u.reach + 2 end)
		if #near >= a.trigger then
			u.busyUntil, u.autoReadyAt = now + a.lock, now + a.cd
			table.insert(u.drs, { from = now + a.upAt, to = now + a.upAt + a.dur, dr = a.dr })
			playAnim(u, a.anim)
			return true
		end
	elseif a.kind == "stunRing" then
		local test = function(o) return a.forms[o.form] and inCircle(u.x, u.z, a.radius + u.r, o) end
		if #enemiesWhere(u, test) >= 1 then
			u.busyUntil, u.autoReadyAt = now + a.lock, now + a.cd
			playAnim(u, a.anim)
			later(u, now + a.hitAt, function()
				local hit = nearestFirst(u.x, u.z, enemiesWhere(u, test))
				for i = 1, math.min(#hit, a.cap) do damage(u, hit[i], a.hit); stun(hit[i], a.stun) end
			end)
			return true
		end
	end
	return false
end

-- ===== ORDERS: one per form per side, shared cooldown; it fires when it would land for 30 % of the form's units, and
-- then every unit of the form that can does it, in a ripple (TELLS.orderWave 0.06-0.3 s) =====
local groupCd: { [string]: number } = {}
local function groupKey(u) return (u.team == "ALL") and ("ALL" .. u.id) or (u.team .. ":" .. u.name) end
-- can this unit do its Order right now? returns a function that starts it, or nil. ifFree: would it, once its current
-- attack is over (the order queue's issue check; the execution check is the full one)
local function orderFor(u, now, ifFree)
	local o = u.kit.order
	local e = u.brain and u.brain.target
	if not o or u.dead or not u.ai then return nil end
	if not ifFree and not canStart(u, now) then return nil end
	if o.kind == "beam" then
		if not e then return nil end
		local gap = gapOf(u, e)
		if gap > o.range or math.abs(wrap(bearing(u, e.x, e.z) - u.face)) > math.pi / 2 then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			u.busyUntil = t + o.lock
			local ax, az = e.x, e.z
			playAnim(u, o.anim, ax, az, e)
			local test = function(x) return inCircle(ax, az, o.radius, x) end
			warnDanger(u, { kind = "circle", x = ax, z = az, radius = o.radius }, t + o.hitAt, test)
			local hitP = later(u, t + o.hitAt, function()
				local hit = nearestFirst(ax, az, enemiesWhere(u, test))
				for i = 1, math.min(#hit, o.cap) do
					local x = hit[i]
					damage({ x = ax, z = az }, x, (i == 1) and o.hit * (o.mult[x.form] or 1) or o.side)
				end
				-- the burn: 8/s for 2 s on whoever stands in it; a WORLD hazard from the impact on (its ticks run on their own,
				-- whatever happens to the Colossus)
				for k = 1, o.burnDur * 4 do
					task.delay(k * 0.25, function()
						local inBurn = enemiesWhere(u, test)
						for i = 1, math.min(#inBurn, o.cap) do damage({ x = ax, z = az }, inBurn[i], o.burn * 0.25) end
					end)
				end
			end)
			-- (the beam is the cast until the impact: cut before 3.20 = no hit and no burn; from the impact (RELEASE 3.20) the
			-- burning spot is the world's, and the client keeps its beam / burn effects if the Colossus falls)
			handOver(u, o.anim, hitP, t)
		end
	elseif o.kind == "lane" then
		if not e or not inLane(u.x, u.z, u.face, o.length + u.r, o.width, e) then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			u.busyUntil = t + o.lock
			local ox, oz, of = u.x, u.z, u.face          -- (the wave rolls down the lane it faced when it reared up)
			playAnim(u, o.anim)
			local test = function(x) return inLane(ox, oz, of, o.length + u.r, o.width, x) end
			warnDanger(u, { kind = "lane", x = ox, z = oz, face = of, width = o.width }, t + o.hitAt, test)
			local hitP
			hitP = later(u, t + o.hitAt, function()
				local hit = nearestFirst(ox, oz, enemiesWhere(u, test))
				for i = 1, math.min(#hit, o.cap) do
					local x = hit[i]
					damage({ x = ox, z = oz }, x, (i == 1) and o.hit * (o.mult[x.form] or 1) or o.side)
					slow(x, o.slow, o.slowDur)
				end
			end)
			handOver(u, o.anim, hitP, t)                  -- (the wall leaves its body at 2.10: from then it rolls on)
		end
	elseif o.kind == "shieldBuff" then
		if #enemiesWhere(u, function(x) return gapOf(u, x) <= o.engage end) == 0 then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			u.busyUntil = t + o.lock
			playAnim(u, o.anim)
			later(u, t + o.hitAt, function()
				local src = { u.id, u.atkId }                  -- (the shells belong to this Thump: shieldEnded says so)
				shield(u, o.selfShield, o.shieldDur, src)
				u.haste, u.hasteUntil = o.haste, clock() + o.hasteDur
				for _, f in live do if friendly(u, f) and flatDist(u, f) <= o.allyRadius + u.r + f.r then shield(f, o.allyShield, o.shieldDur, src) end end
			end)
		end
	elseif o.kind == "leapSlam" then
		-- BOING SLAM: land on the thickest crowd in range (2+ enemies under the 5-stud splat)
		local best, bn = nil, 0
		for _, x in enemiesWhere(u, function(x) return gapOf(u, x) <= o.range end) do
			local n = #enemiesWhere(u, function(y) return inCircle(x.x, x.z, o.radius, y) end)
			if n > bn then best, bn = x, n end
		end
		if not best or bn < o.trigger then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			local ax, az = best.x, best.z
			u.busyUntil, u.pinned = t + o.dur, true
			u.face = bearing(u, ax, az)
			playAnim(u, o.anim, ax, az, best)
			later(u, t + o.hitAt, function()
				local hit = nearestFirst(ax, az, enemiesWhere(u, function(y) return inCircle(ax, az, o.radius, y) end))
				for i = 1, math.min(#hit, o.cap) do
					damage({ x = ax, z = az }, hit[i], o.hit)
					if hit[i].form == 1 then stun(hit[i], o.stunF1) end
				end
			end)
			later(u, t + o.dur, function() u.pinned = false; jump(u, ax, az) end)
		end
	elseif o.kind == "sweep" then
		local test = function(x) return (x.form == 1 or x.form == 2) and inLane(u.x, u.z, u.face, o.length + u.r, o.width, x) end
		if #enemiesWhere(u, test) < o.trigger then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			u.busyUntil = t + o.lock
			playAnim(u, o.anim)
			later(u, t + o.hitAt, function()
				local fx, fz = forward(u.face)
				local hit = nearestFirst(u.x, u.z, enemiesWhere(u, test))
				for i = 1, math.min(#hit, o.cap) do
					damage(u, hit[i], o.hit)
					shove(hit[i], -fz * o.knock, fx * o.knock)   -- (batted aside: the claws swing toward its right)
				end
			end)
		end
	elseif o.kind == "charge" then
		-- RAM CHARGE: a Pack (or a Brute) 4-26 studs off, roughly ahead; runs at 24 studs/s to 0.35 short of its face
		local pool = enemiesWhere(u, function(x)
			local g = gapOf(u, x)
			return x.form ~= 4 and g >= o.minGap and g <= o.seek and math.abs(wrap(bearing(u, x.x, x.z) - u.face)) < math.rad(60)
		end)
		local v = preferred(u, pool, o.prefer)
		if not v then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			local dx, dz = v.x - u.x, v.z - u.z
			local L = math.max(0.01, math.sqrt(dx * dx + dz * dz))
			dx, dz = dx / L, dz / L
			local d = math.clamp(L - v.r - 5.75, 0, o.maxRun)         -- (its horn hooks ride 5.4 ahead of the pivot)
			local tHit = 0.85 + ((d < 1.44) and math.sqrt(d * 0.01) or 0.12 + (d - 1.44) / 24)
			u.busyUntil, u.pinned = t + o.dur, true
			u.face = math.atan2(dx, -dz)
			playAnim(u, o.anim, v.x, v.z, v)
			local ox, oz, of = u.x, u.z, u.face
			later(u, t + tHit, function()
				local test = function(x) return inLane(ox, oz, of, d + u.r + 6, o.width, x) end
				local hit = nearestFirst(ox, oz, enemiesWhere(u, test))
				for i = 1, math.min(#hit, o.cap) do
					local x = hit[i]
					damage(u, x, (i == 1) and o.hit * (o.mult[x.form] or 1) or o.side)
					shove(x, dx * o.knock, dz * o.knock)
				end
			end)
			later(u, t + o.dur, function() u.pinned = false; jump(u, ox + dx * (d + 0.6), oz + dz * (d + 0.6)) end)
		end
	elseif o.kind == "leapOnto" then
		-- BOING BOMBS: spring onto the nearest big enemy within 12 (at most 10 Drips on one), splat (+15), bite
		local best, bd = nil, o.range
		for _, x in live do
			if hostile(u, x) and BIG[x.form] and gapOf(u, x) <= bd and riders(x, u) < o.perTarget then best, bd = x, gapOf(u, x) end
		end
		if not best then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			local e2 = best
			if e2.dead then return end
			cancel(u)
			u.busyUntil, u.pinned, u.on = t + o.dur, true, e2
			u.slotNo = freeSlotOn(e2); e2.riders[u] = true
			u.face = bearing(u, e2.x, e2.z)
			playAnim(u, o.anim, e2.x, e2.z, e2, u.slotNo)
			later(u, t + o.bonusAt, function() bite(u, e2, o.bonus) end)
			for _, bt in o.bites do later(u, t + bt, function() bite(u, e2, o.hit) end) end
			later(u, t + o.dur, function()
				release(u)
				if not e2.dead then                        -- (it comes off at the flank it landed on)
					local d = math.max(0.01, flatDist(u, e2))
					jump(u, e2.x + (u.x - e2.x) / d * (e2.r + u.r * 0.9), e2.z + (u.z - e2.z) / d * (e2.r + u.r * 0.9))
				end
			end)
		end
	elseif o.kind == "rush" then
		-- ROLL OUT: roll at the nearest big enemy 2-16 off (hard to hurt while rolling), BIG JAB on arrival
		local best, bd = nil, o.range
		for _, x in live do
			local g = hostile(u, x) and BIG[x.form] and gapOf(u, x)
			if g and g >= o.minGap and g <= bd then best, bd = x, g end
		end
		if not best then return nil end
		return function(t)
			if not gate(u) then return end                    -- (attack commit: refused before it changes anything)
			local e2 = best
			cancel(u)
			u.busyUntil, u.pinned = t + o.dur, true
			u.slotNo = freeSlotOn(e2)
			u.face = bearing(u, e2.x, e2.z)
			table.insert(u.drs, { from = t, to = t + o.hitAt, dr = o.dr })
			playAnim(u, o.anim, e2.x, e2.z, e2, u.slotNo)
			later(u, t + o.hitAt, function() if not e2.dead then damage(u, e2, o.bonus) end end)
			later(u, t + o.dur, function()
				u.pinned, u.slotNo = false, nil
				if not e2.dead then
					local d = math.max(0.01, flatDist(u, e2))
					jump(u, e2.x + (u.x - e2.x) / d * (e2.r + u.r * 0.9), e2.z + (u.z - e2.z) / d * (e2.r + u.r * 0.9))
				end
			end)
		end
	end
	return nil
end
-- ORDER QUEUE (commit audit r2: the old start fired 0.06-0.30 s after the check WITHOUT re-checking, so it could land on
-- top of a swing that began in between). An issued Order is now a RESERVATION on each unit that could do it once free:
-- { issue, issuedAt, notBefore (the ripple), expires (7 s: covers the Sun's 6.2 s commitment), target }. Every step,
-- before the passive / auto (runOrder): it starts as soon as the unit is free and the SAME order still holds (an order
-- aimed at the brain's target needs that same target); while it waits out the ripple or the unit's current attack the
-- unit does nothing else; while it is merely invalid (out of range, facing away) the unit fights on as normal. Each
-- reservation ends exactly once: executed / expired / invalid / superseded. The group cooldown is reserved at the issue;
-- if nobody of that issue casts, it is given back (re-issue in 1 s), and only that issue's own reservation
local issueSerial, groupIssue = 0, {}
local function resolveOrder(u, why, now)
	local po = u.pendingOrder
	if not po then return end
	u.pendingOrder = nil
	bump("AITestOrders_" .. why)
	local w = now - po.issuedAt
	if why == "executed" and w > (workspace:GetAttribute("AITestOrderWaitMax") or 0) then workspace:SetAttribute("AITestOrderWaitMax", w) end
	local is = po.issue
	is.open -= 1
	if why == "executed" then is.cast += 1 end
	if is.open == 0 and is.cast == 0 and groupIssue[is.group] == is then groupCd[is.group] = now + 1 end
end
local function tryOrders(now)
	local groups = {}
	for _, u in live do
		if u.ai and not u.dead and u.kit.order then
			local k = groupKey(u)
			groups[k] = groups[k] or {}
			table.insert(groups[k], u)
		end
	end
	for k, g in groups do
		if not groupCd[k] then groupCd[k] = now + 3 + math.random() * 6 end   -- (power graph: the first Order 3-9 s in)
		if now < groupCd[k] then continue end
		local ready = {}
		for _, u in g do if orderFor(u, now, true) then table.insert(ready, u) end end
		if #ready > 0 and #ready >= math.ceil(#g * 0.3) then          -- (the Order glow rule: 30 % of the form's units)
			groupCd[k] = now + g[1].kit.order.cd
			issueSerial += 1
			local is = { id = issueSerial, group = k, open = #ready, cast = 0 }
			groupIssue[k] = is
			for _, u in ready do
				if u.pendingOrder then resolveOrder(u, "superseded", now) end
				u.pendingOrder = { issue = is, issuedAt = now, notBefore = now + 0.06 + math.random() * 0.24, expires = now + 7,
					target = u.brain and u.brain.target }
			end
		end
	end
end
-- this step's reserved Order: "done" (it started), "hold" (waiting its turn: nothing else starts), nil (fight on)
local function runOrder(u, now)
	local po = u.pendingOrder
	if not po then return nil end
	if u.dead or not u.ai then resolveOrder(u, "invalid", now); return nil end
	if now > po.expires then resolveOrder(u, "expired", now); return nil end
	if po.target and po.target.dead then resolveOrder(u, "invalid", now); return nil end
	if now < po.notBefore or not canStart(u, now) then return "hold" end
	local kind = u.kit.order.kind
	if (kind == "beam" or kind == "lane") and u.brain.target ~= po.target then return nil end
	local start = orderFor(u, now)
	if not start then return nil end
	start(now)
	resolveOrder(u, "executed", now)
	return "done"
end

-- ===== one fixed step (20 Hz): brains, then actions, then everyone moves at once =====
local function step(now)
	local arr = {}
	for _, u in live do if not u.dead then table.insert(arr, u) end end
	-- the brain's inputs: who is on whom (attackers = little ones in reach of it), damage heading for each unit
	local incoming = {}
	for _, u in arr do u.brain.attackers = 0 end
	for _, u in arr do
		local e = u.brain and u.brain.target
		if e and not e.dead and gapOf(u, e) <= u.reach + 1 then
			if e.brain then e.brain.attackers += 1 end
			incoming[e] = (incoming[e] or 0) + ({ 12, 20, 44, 100 })[u.form] * 1.5
		end
	end
	brainCtx.units = arr
	for _, u in arr do
		u.brainOn = u.ai and now >= u.stunUntil
		if u.brainOn then
			local foes, friends = {}, {}
			for _, o in arr do
				if hostile(u, o) then table.insert(foes, o) elseif o ~= u then table.insert(friends, o) end
			end
			brain.tick(u, foes, friends, incoming)
		end
	end
	tryOrders(now)
	-- actions: a reserved Order first, then auto (situational), then the passive when in reach; nothing starts before the
	-- unit's last attack has finished its body (canStart)
	for _, u in arr do
		if runOrder(u, now) then continue end
		if not u.brainOn or not canStart(u, now) then continue end
		local e = u.brain.target
		if not e then continue end
		if tryAuto(u, e, now) then continue end
		local p = u.kit.passive
		if now < u.nextPassive then continue end
		if p.kind == "slam" then
			if slamHits(u, p, e) then startSlam(u, p, now) end
		elseif p.kind == "cling" then
			if gapOf(u, e) <= u.reach + 0.6 and not (u.noClingOn == e and now < u.noClingUntil) then startCling(u, p, e, now) end
		elseif gapOf(u, e) <= u.reach + 0.3 then
			startMelee(u, p, e, now)
		end
	end
	-- plan from the same snapshot, then integrate
	-- ANTI-CLING (29 Oct, James: a Colossus "stopped and walked around" while the last Drips kept biting it: its target
	-- rode ON it, and walking to a unit that moves with you never arrives). ANY carrier whose target rides its body stands:
	-- no chase, no turn (the rider turns with it). Every carrier can hit its own rider: a giant's slam shakes its whole
	-- body (slamHits); melee / cleave / chip hit by contact distance, not by facing. WATCHDOG PER RIDER: a rider is shaken
	-- off (shakeOff) when its carrier has PICKED it for a hit and dealt it nothing twice in a row (svcMiss, tried()), or,
	-- as a backstop, when it has gone its svcAllow (>= 30 s, scaled to the riders queued under the cap: svcFor) on the
	-- body without real damage from it. A swarm waiting its turn under the slam's cap of 2 is not "missed" (riders are
	-- picked longest-unserved first), so this is no hidden anti-swarm move. Re-clings to the same carrier within 2 s keep
	-- the rider's clock. ChatGPT audits r1-r4 (design\aitest-fixes\): r1 held any unit with no way out; r2's timer reset on
	-- every slam start and target switch; r3's was shared by the whole rider set (one unhittable rider starved) and
	-- counted 0-damage hits; a flat 9 s per rider shook healthy 12-Drip swarms off (measured: 3 per fight); r4: a flat
	-- 30 s would expel half of a 32-Drip swarm still waiting its turn.
	local function antiCling(u, now)
		if not u.brainOn then u.anti = nil; return false end
		local riding = false
		for r in u.riders do
			if r.dead or not ridesOn(r, u) or not hostile(u, r) then continue end
			riding = true
			svcFor(r, u, now)
			local starved = (r.svcMiss or 0) >= 2 or now - math.max(r.svcSince, r.svcHit or -1e9) > r.svcAllow
			if starved and now >= u.busyUntil then shakeOff(u, r, now) end
		end
		u.anti = riding or nil
		local tg = u.brain and u.brain.target
		return riding and tg ~= nil and not tg.dead and ridesOn(tg, u)
	end
	local moving = {}
	for _, u in arr do
		local hold = antiCling(u, now)
		if u.brainOn and now >= u.busyUntil and not u.pinned and not hold then
			brain.plan(u, u.speed * slowK(u, now), false)
			table.insert(moving, u)
		elseif u.brain then
			brain.hold(u)
		end
	end
	for _, u in moving do
		brain.integrate(u)
		u.v = math.sqrt(u.brain.vx ^ 2 + u.brain.vz ^ 2)
	end
	for _, u in arr do
		if not table.find(moving, u) then u.v = 0 end
		-- facing: along the walk while walking, else toward its target (giants turn at 60 deg/s)
		local want
		if u.v > 0.5 and u.brain and u.brain.walkDir then want = u.brain.walkDir
		elseif u.brainOn and now >= u.busyUntil and u.brain.target and not ridesOn(u.brain.target, u) then
			want = bearing(u, u.brain.target.x, u.brain.target.z)            -- (not toward its own rider: it turns with it)
		end
		if want then
			local turn = math.rad(u.turnDeg) * DT
			u.face = wrap(u.face + math.clamp(wrap(want - u.face), -turn, turn))
		end
		-- a Drip riding its target goes where it goes
		if u.on and u.rideA and not u.on.dead then
			local fx, fz = forward(u.on.face)
			u.x, u.z = u.on.x + u.rideA * fx - u.rideC * fz, u.on.z + u.rideA * fz + u.rideC * fx
		end
	end
	-- the hard separation pass (the sim's): bodies overlap at most 10 %; the heavier one gives way less; held ones not at all
	for i = 1, #arr do for j = i + 1, #arr do
		local a, b = arr[i], arr[j]
		if (a.on and a.on == b) or (b.on and b.on == a) or (a.on and b.on) then continue end
		local dx, dz = b.x - a.x, b.z - a.z
		local L = math.sqrt(dx * dx + dz * dz)
		local need = (a.r + b.r) * SEP
		if L < need then
			if L < 1e-3 then dx, dz, L = 1, 0, 1 end
			local wa = a.pinned and 0 or (b.pinned and 1 or b.matter / (a.matter + b.matter))
			local wb = b.pinned and 0 or (a.pinned and 1 or a.matter / (a.matter + b.matter))
			local push = need - L
			a.x -= dx / L * push * wa; a.z -= dz / L * push * wa; b.x += dx / L * push * wb; b.z += dz / L * push * wb
		end
	end end
	for _, u in arr do if u.shield > 0 and now > u.shieldUntil then u.shield = 0; shieldEnded(u, now); refreshBar(u) end end
end

local acc, sendAcc = 0, 0
local simN, simSum, simMax = 0, 0, 0
RunService.Heartbeat:Connect(function(dt)
	local now = clock()
	for _, u in live do
		for i = #u.pending, 1, -1 do
			local p = u.pending[i]
			if p and now >= p.at then
				table.remove(u.pending, i)
				if not p.released and p.atkId ~= u.atkId then
					bump("AITestStaleBlocked")                -- (a hit of an attack that is no longer this unit's: never lands)
				elseif not u.dead or p.released then
					local ok, err = pcall(p.fn); if not ok then warn("[AITest] action", err) end
				end
			end
		end
	end
	acc = math.min(acc + dt, DT * 4)                 -- (a long frame: catch up at most 4 steps)
	while acc >= DT do
		acc -= DT
		local s0 = os.clock()
		local ok, err = pcall(step, clock())
		if not ok then warn("[AITest] step", err) end
		-- (perf audit readout: the slowest 20 Hz step in the last second, in ms)
		simMax = math.max(simMax, (os.clock() - s0) * 1000); simN += 1; simSum += (os.clock() - s0) * 1000
		if simN >= 20 then workspace:SetAttribute("SimStepMs", simSum / simN); workspace:SetAttribute("SimStepMaxMs", simMax); simN, simSum, simMax = 0, 0, 0 end
	end
	sendAcc += dt
	if sendAcc >= SEND then
		sendAcc = 0
		local stamp, packet = clock(), extras
		extras = {}
		for m, u in live do
			if not m.Parent then live[m] = nil; continue end
			table.insert(packet, { u.id, stamp, u.x, u.z, u.face, u.v })
		end
		local ev = events
		events = {}
		if #packet > 0 or #ev > 0 then stateRemote:FireAllClients(packet, ev) end
	end
end)

-- ===== the menu's commands =====
local function find(id) for _, u in live do if u.id == id then return u end end end

local function spawnAI(plr: Player, name: string, team: string, count: number)
	local kit, src = KITS[name], forms:FindFirstChild(name)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not (kit and src and root) then return end
	local c = CHASSIS[kit.form]
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Magnitude > 0.1 and Vector3.new(look.X, 0, look.Z).Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local centre = root.Position + flat * (25 + c.r * 3)
	for n = 1, count do
		-- (a group in a loose block; spawned again without turning: step sideways until the spot is clear)
		local col, rowN = (n - 1) % 4, (n - 1) // 4
		local pos = centre + right * (col - 1.5) * c.r * 3 * ((count > 1) and 1 or 0) + flat * rowN * c.r * 3
		for s = 1, 8 do
			local taken = false
			for _, o in live do if not o.dead and math.sqrt((o.x - pos.X) ^ 2 + (o.z - pos.Z) ^ 2) < o.r + c.r + 1 then taken = true; break end end
			if not taken then break end
			pos += right * (c.r * 2 + 2) * ((s % 2 == 1) and s or -s)
		end
		serial += 1
		local m = src:Clone()
		m.Name = kit.label .. " " .. serial
		pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
		local u = { id = serial, m = m, kit = kit, name = name, label = kit.label .. " " .. serial, form = kit.form, fk = "F" .. kit.form,
			race = kit.race, matter = c.matter, x = pos.X, z = pos.Z, face = 0, v = 0, r = c.r, reach = c.reach, speed = c.speed,
			turnDeg = c.turnDeg, hp = c.hp, maxHp = c.hp, team = team, ai = false, dead = false, busyUntil = 0, nextPassive = 0,
			autoReadyAt = clock() + 2, stunUntil = 0, stunImmuneUntil = 0, drs = {}, slows = {}, shield = 0, shieldUntil = 0,
			haste = 0, hasteUntil = 0, shoveT = 0, shoved = 0, lastHurtT = -9, pending = {}, riders = {}, pinned = false }
		u.face = bearing(u, root.Position.X, root.Position.Z)   -- (faces you when it lands)
		brain.init(u)                                          -- (u.brain = the brain's state; u.ai = AI on / off)
		m:SetAttribute("Owner", plr.UserId); m:SetAttribute("FormName", name); m:SetAttribute("Mode", "ai")
		m:SetAttribute("AiId", serial); m:SetAttribute("AiX", u.x); m:SetAttribute("AiZ", u.z); m:SetAttribute("AiFace", u.face)
		m:PivotTo(CFrame.new(pos))
		m.Parent = units
		live[m] = u
		makeBar(m, u); refreshBar(u)
	end
end

local handler
-- (test hooks force / dodge / ghost / preshield accept an exact SERVER time `at` (c): the command is held until then,
-- so a probe lands at a precise moment of an attack whatever the client's lag)
remote.OnServerEvent:Connect(function(plr, cmd, a, b, c)
	if (cmd == "force" or cmd == "dodge" or cmd == "ghost" or cmd == "preshield") and typeof(c) == "number" and c > clock() then
		task.delay(c - clock(), handler, plr, cmd, a, b, nil)
		return
	end
	handler(plr, cmd, a, b, c)
end)
handler = function(plr, cmd, a, b, c)
	if cmd == "spawn" and typeof(a) == "string" and (b == "A" or b == "B" or b == "ALL") then
		spawnAI(plr, a, b, math.clamp(math.floor(tonumber(c) or 1), 1, 12))
	elseif cmd == "team" and typeof(a) == "number" then
		local u = find(a)
		if u and not u.dead then u.team = (u.team == "A") and "B" or (u.team == "B") and "ALL" or "A"; brain.clearTarget(u); refreshBar(u) end
	elseif cmd == "ai" and typeof(a) == "number" then
		local u = find(a)
		if u and not u.dead then u.ai = not u.ai; refreshBar(u) end
	elseif cmd == "allai" and typeof(a) == "boolean" then
		for _, u in live do if not u.dead then u.ai = a; refreshBar(u) end end
	elseif cmd == "heal" then
		for _, u in live do if not u.dead then u.hp = u.maxHp; refreshBar(u) end end
	elseif cmd == "remove" and typeof(a) == "number" then
		local u = find(a)
		if u then u.dead = true; release(u); u.m:Destroy(); live[u.m] = nil end
	-- TEST HOOKS for the commit audit's forced probes (AI test place only):
	--   force <id> ["bypass"]: start its passive now (normal = must be refused mid-attack; bypass = drop its commitment
	--     WITHOUT a cancel first, so the old attack's unreleased hits are left behind and must be blocked as stale)
	--   dodge <id>: its Boing reaction now (allowed only out of its own Cling)
	--   ghost <id>: send a cancel for its NEXT attack id first, then force that attack (the client must never play it)
	--   preshield <id>: send the end of the shield its NEXT Thump will make, then force that Thump (no shell may appear)
	elseif cmd == "force" and typeof(a) == "number" then
		local u = find(a)
		if u and not u.dead then
			if b == "bypass" then u.commitUntil, u.busyUntil = 0, 0 end
			local p, e = u.kit.passive, u.brain and u.brain.target
			if p.kind == "slam" then startSlam(u, p, clock())
			elseif e and (p.kind == "melee" or p.kind == "cleave") then startMelee(u, p, e, clock()) end
		end
	elseif cmd == "dodge" and typeof(a) == "number" then
		local e = find(a)
		if e and mayReact(e, "Boing") then
			local tx, tz = e.x + 3, e.z
			e.busyUntil, e.pinned = clock() + 0.95, true
			playAnim(e, "Boing", tx, tz)
			later(e, clock() + 0.95, function() e.pinned = false; jump(e, tx, tz) end)
		end
	elseif cmd == "ghost" and typeof(a) == "number" then
		local u = find(a)
		if u and not u.dead then
			event({ u.id, "cancel", (u.atkId or 0) + 1, clock(), "test", false })
			u.commitUntil, u.busyUntil = 0, 0
			local p, e = u.kit.passive, u.brain and u.brain.target
			if p.kind == "slam" then startSlam(u, p, clock()) elseif e then startMelee(u, p, e, clock()) end
		end
	elseif cmd == "preshield" and typeof(a) == "number" then
		local u = find(a)
		if u and not u.dead and u.kit.order and u.kit.order.kind == "shieldBuff" then
			event({ u.id, "shieldEnd", clock(), u.id, (u.atkId or 0) + 1 })
			u.commitUntil, u.busyUntil = 0, 0
			local start = orderFor(u, clock())
			if start then start(clock()) end
		end
	elseif cmd == "arm" and typeof(a) == "number" and typeof(b) == "table" then   -- (test hook: { cmd, anim, offset, mode })
		local u = find(a)
		if u then u.armed = { cmd = b.cmd, anim = b.anim, offset = tonumber(b.offset) or 0, mode = b.mode } end
	elseif cmd == "kill" and typeof(a) == "number" then                    -- (test hook: defeat a unit now / at server time b)
		local u = find(a)
		local function go() if u and not u.dead then u.hp = 0; die(u) end end
		if typeof(b) == "number" and b > clock() then task.delay(b - clock(), go) else go() end
	elseif cmd == "flag" and typeof(a) == "string" and a:sub(1, 6) == "AITest" then   -- (test hooks: AITestSlamMiss, AITestNoDmgId)
		workspace:SetAttribute(a, b)
	elseif cmd == "clear" then
		for m, u in live do u.dead = true; m:Destroy() end
		table.clear(live); table.clear(groupCd)
	end
end
probeRun = handler
