-- Alien Fusion: moves and animates the alien units on this client, and the WALK TEST menu (James, 27 Oct).
-- Units live in workspace.Units. Each carries its path as attributes (CentreX/Z, Radius, Speed, T0 = server time),
-- so every client puts it in the same place from the server clock; the walk itself is procedural (Gaits module):
-- a phase 0-1 driven by distance walked / stride, so the feet keep pace with the ground at any speed.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local AF = RS:WaitForChild("AlienFusion")
local Gaits = require(AF:WaitForChild("Gaits"))
local Attacks = require(AF:WaitForChild("Attacks"))
local units = workspace:WaitForChild("Units")

local rad = math.rad
local tracked = {} -- model -> state
local fxPart, shakeAt -- (made with the footfall effects, further down)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local DBG_NORAY = false                                   -- (perf audit switch DbgNoRay)
local function groundY(x: number, z: number, fallback: number): number
	if DBG_NORAY then return fallback end
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	return hit and hit.Position.Y or fallback
end

-- ===== auras (James, 27 Oct: magma race = volcanic steam, goo race = cosmic; ChatGPT settings + budget) =====
-- every form has one, stronger with each fusion. Emitted from the body-only Hitbox. Built-in Roblox textures, no uploads.
local SPARK, SMOKE = "rbxasset://textures/particles/sparkles_main.dds", "rbxasset://textures/particles/smoke_main.dds"
local NS, NR, CS = NumberSequence.new, NumberRange.new, ColorSequence.new
local C = Color3.fromRGB
local function curve(a, b, c) return NS({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, b), NumberSequenceKeypoint.new(1, c) }) end
-- per form: { rate, lifetime, size peak/curve, speed, spread }
local AURA = {
	squish = {
		{ spark = { 1.5, NR(1.0, 1.5), curve(0, 0.22, 0), NR(0.2, 0.5), 45 } },
		{ spark = { 2.0, NR(1.2, 1.7), curve(0, 0.3, 0), NR(0.2, 0.6), 60 } },
		{ spark = { 3.0, NR(1.3, 2.0), curve(0, 0.45, 0), NR(0.3, 0.7), 70 }, haze = { 1.0, NR(1.6, 2.4), curve(0, 1.4, 0), NR(0.1, 0.3) } },
		{ spark = { 6.0, NR(1.5, 2.4), curve(0, 0.75, 0), NR(0.4, 0.9), 90 }, haze = { 2.5, NR(2.0, 3.0), curve(0, 2.6, 0), NR(0.1, 0.4) } },
	},
	crunch = {
		-- (rates above ChatGPT's 0.6 / 0.8 / 1.8 / 5: in Studio those read as nothing; 30 was a chimney; the cap still holds)
		{ steam = { 3.0, NR(1.0, 1.5), curve(0.5, 1.0, 1.4), NR(0.4, 0.8), 25 } },
		{ steam = { 4.0, NR(1.2, 1.7), curve(0.7, 1.4, 1.9), NR(0.5, 1.0), 30 } },
		{ steam = { 7.0, NR(1.3, 2.0), curve(1.0, 2.2, 3.0), NR(0.6, 1.2), 35 }, ember = { 1.0, NR(0.8, 1.4), curve(0.3, 0.2, 0), NR(1.5, 3.0) } },
		{ steam = { 12.0, NR(1.5, 2.4), curve(1.6, 3.2, 4.2), NR(0.8, 1.5), 40 }, ember = { 3.0, NR(0.9, 1.6), curve(0.45, 0.3, 0), NR(2.0, 4.0) } },
	},
}
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	-- (locked to the body: on a walking unit loose particles were left behind as a faint trail, not an aura)
	e.LockedToPart = true
	for k, v in props do (e :: any)[k] = v end
	e.Parent = parent
	return e
end
local function makeAura(m: Model)
	local race, f = m:GetAttribute("Race"), m:GetAttribute("Form")
	local spec = AURA[race or ""] and AURA[race][f or 0]
	if not spec then return {} end
	-- the emitters live on a client-only box just around the whole creature: on the body-sized Hitbox they spawned
	-- INSIDE the mesh and the body hid them (27 Oct). It moves with the model (PivotTo moves every part in it)
	-- (its top face sits at shoulder height, ~70 % up, so the steam leaves the back and shoulders, not the crest's tips)
	local cf, size = m:GetBoundingBox()
	local box = Instance.new("Part")
	box.Name = "AuraBox"
	box.Size = size * Vector3.new(0.85, 0.7, 0.85)
	box.CFrame = cf * CFrame.new(0, -size.Y * 0.15, 0)
	box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
	box.Transparency = 1
	box.Parent = m
	local list = {}
	local function add(e, rate) table.insert(list, { e = e, rate = rate }) end
	if spec.spark then
		local s = spec.spark
		add(emitter(box, { Texture = SPARK, Rate = s[1], Lifetime = s[2], Size = s[3], Speed = s[4], SpreadAngle = Vector2.new(s[5], s[5]),
			LightEmission = (f == 4) and 0.9 or 0.8, Transparency = curve(1, 0.15, 1), Color = CS(C(120, 240, 255), C(190, 120, 255)),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rotation = NR(0, 360), RotSpeed = NR(-60, 60),
			Drag = 1 }), s[1])
	end
	if spec.haze then
		local h = spec.haze
		add(emitter(box, { Texture = SMOKE, Rate = h[1], Lifetime = h[2], Size = h[3], Speed = h[4], SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.6, Transparency = curve(1, 0.78, 1), Color = CS(C(150, 80, 255), C(60, 170, 255)),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rotation = NR(0, 360), RotSpeed = NR(-15, 15) }), h[1])
	end
	if spec.steam then
		local s = spec.steam
		-- volcanic steam, lit orange by the magma where it leaves the body, cooling to ash grey as it rises (27 Oct, in
		-- Studio: ChatGPT's pale ash grey, fading in from fully clear, didn't show against the pale ground or the black sky)
		add(emitter(box, { Texture = SMOKE, Rate = s[1], Lifetime = s[2], Size = s[3], Speed = s[4], SpreadAngle = Vector2.new(s[5], s[5]),
			LightEmission = 0.3, Transparency = NS({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Color = CS({ ColorSequenceKeypoint.new(0, C(255, 140, 60)), ColorSequenceKeypoint.new(0.35, C(190, 150, 125)), ColorSequenceKeypoint.new(1, C(110, 104, 100)) }),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, EmissionDirection = Enum.NormalId.Top, -- (from the box just outside the body: inside it the body hid them)
			Acceleration = Vector3.new(0, 1.2, 0), Drag = 0.8, Rotation = NR(0, 360), RotSpeed = NR(-20, 20) }), s[1])
	end
	if spec.ember then
		local s = spec.ember
		add(emitter(box, { Texture = SPARK, Rate = s[1], Lifetime = s[2], Size = s[3], Speed = s[4], SpreadAngle = Vector2.new(25, 25),
			LightEmission = 1, Transparency = curve(0, 0.2, 1), Color = CS(C(255, 200, 80), C(255, 70, 10)),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 1.5, 0), Drag = 0.5 }), s[1])
	end
	return list
end

-- the budget (ChatGPT): emitters run only on the nearest units within 80 studs, until ~50 particles/s are in use
local AURA_RANGE, AURA_CAP = 80, 60
task.spawn(function()
	while true do
		task.wait(0.5)
		local cam = workspace.CurrentCamera
		if cam then
			local near = {}
			for m, st in tracked do
				if m.Parent and st.emitters then
					local d = (m:GetPivot().Position - cam.CFrame.Position).Magnitude
					table.insert(near, { st = st, d = d })
				end
			end
			table.sort(near, function(a, b) return a.d < b.d end)
			local used = 0
			for _, e in near do
				local cost = 0
				for _, em in e.st.emitters do cost += em.rate end
				local on = e.d <= AURA_RANGE and used + cost <= AURA_CAP
				if on then used += cost end
				for _, em in e.st.emitters do if em.e.Enabled ~= on then em.e.Enabled = on end end
			end
		end
	end
end)

-- the blink (ChatGPT timing): close 0.055 s, hold 0.025, reopen 0.085; every 2.5-6 s, 10 % double
local LID_ANGLE = -175 -- (the lid is modelled open, tucked 175 deg back behind the eye; this swings it over the top and down over the eye)
local function blinkAmount(st, now)
	if now >= st.nextBlink then
		st.blinkAt = now
		st.nextBlink = now + ((math.random() < 0.1) and (0.165 + 0.12 + math.random() * 0.08) or (2.5 + math.random() * 3.5))
	end
	local t = st.blinkAt and (now - st.blinkAt) or 99
	if t < 0.055 then return t / 0.055 end
	if t < 0.08 then return 1 end
	if t < 0.165 then return 1 - (t - 0.08) / 0.085 end
	return 0
end

local function setup(m: Model)
	local name = m:GetAttribute("FormName") or ""
	-- (a running unit uses its run cycle, a different gait, not the walk sped up; a standing one its idle, if it has one)
	local mode = m:GetAttribute("Mode")
	-- (an ATTACK unit stands in its idle and plays its attack on repeat: the MOVE TEST menu's attack buttons)
	local an = m:GetAttribute("Attack") or ""
	local attack = (mode == "attack") and ((Attacks.FOR[name] and Attacks.FOR[name][an]) or Attacks[an]) or nil
	local gait = (mode == "run" and Gaits[name .. "Run"]) or ((mode == "idle" or attack) and Gaits[name .. "Idle"]) or Gaits[name]
	if not gait then return end
	-- (START: idle until T0, then the walk)
	local idleGait = (mode == "start") and Gaits[name .. "Idle"] or nil
	local pivot = m:GetPivot()
	local bones, n = {}, 0
	for _, b in m:GetDescendants() do
		if b:IsA("Bone") then
			-- the bone's rest frame in model space: a model-space rotation R becomes rest^-1 * R * rest in the bone's own frame
			local rest = pivot:ToObjectSpace(b.WorldCFrame).Rotation
			bones[b.Name] = { b = b, rest = rest, inv = rest:Inverse() }
			n += 1
		end
	end
	-- (streamed in before its bones arrived: try again shortly. The SQUISH units slid unanimated on the first test)
	if n == 0 then task.delay(0.5, function() if m.Parent and not tracked[m] then setup(m) end end); return end
	local st = { gait = gait, idleGait = idleGait, born = workspace:GetServerTimeNow(), bones = bones, frame = math.random(0, 5), y = pivot.Y,
		nextBlink = os.clock() + 1 + math.random() * 4, emitters = makeAura(m) }
	if gait.ik then
		-- planted-foot legs (Colossus v4 pilot): each leg's chain, lengths and rest frames, from the bones at rest.
		-- (v5 Ram: a gait can name its own legs and their phase offsets, ik.legs, e.g. a trot's diagonal pairs; ik.back
		-- = legs whose joint bends BACK, a hind leg's hock; toeZ / heelZ = where the foot pivots, a hoof's are short)
		st.legs = {}
		local ik = gait.ik
		for side, off in ik.legs or { L = 0, R = 0.5 } do
			local t, s, f = bones["Leg" .. side], bones["Shin" .. side], bones["Foot" .. side]
			if not (t and s and f) then st.legs = nil; break end
			local fwd = Vector3.new(0, 0, -1)
			st.legs[side] = { off = off, thigh = t.b, shin = s.b, foot = f.b, plants = {},
				back = ik.back and ik.back[side] or false, toeZ = ik.toeZ or -1.3, heelZ = ik.heelZ or 0.45,
				front = ik.frontBy and ik.frontBy[side] or 0,             -- (v5 Brute: its arms plant nearer than its feet)
				l1 = s.b.CFrame.Position.Magnitude, l2 = f.b.CFrame.Position.Magnitude,
				dirT = s.b.CFrame.Position.Unit, dirS = f.b.CFrame.Position.Unit,
				fwdT = t.rest:Inverse() * fwd, fwdS = s.rest:Inverse() * fwd,
				ankle = pivot:PointToObjectSpace(f.b.WorldPosition), footRest = f.rest }
		end
	end
	do                                                     -- (every form's glow: hurt dips it, defeat puts it out)
		local mp = m.PrimaryPart
		local sa = mp and mp:FindFirstChildOfClass("SurfaceAppearance")
		if sa then st.sa, st.glow = sa, sa.EmissiveStrength end
	end
	st.hurtDef = (Attacks.FOR[name] and Attacks.FOR[name].Hurt) or Attacks.Hurt
	if attack or m:GetAttribute("HurtEvery") or mode == "ai" then
		-- the arms as IK chains too (attacks reach for the ground and the boulder): shoulder (Arm) -> elbow (Hand) -> the
		-- gauntlet's tip. The tip is the hand bone's far end, measured in Blender: 0.35 out, 4.6 down, 0.15 forward
		st.attack = attack
		st.arms = {}
		for side, sx in { L = -1, R = 1 } do
			local ar, hd = bones["Arm" .. side], bones["Hand" .. side]
			if not (ar and hd) then st.arms = nil; break end
			local tip = hd.rest:Inverse() * Vector3.new(0.35 * sx, -4.6, -0.15)       -- (in the hand bone's own frame)
			local fwd = Vector3.new(0, 0, -1)
			st.arms[side] = { arm = ar.b, hand = hd.b, sx = sx, l1 = hd.b.CFrame.Position.Magnitude, l2 = tip.Magnitude,
				dirA = hd.b.CFrame.Position.Unit, dirH = tip.Unit, fwdA = ar.rest:Inverse() * fwd, fwdH = hd.rest:Inverse() * fwd,
				gc = tip * 0.565 }                                                      -- (the gauntlet block's centre)
		end
		local holder = Instance.new("Folder"); holder.Name = "AttackFX"; holder.Parent = workspace
		st.fx = {}
		local ctx = { m = m, holder = holder, FX = AF:FindFirstChild("FX") }
		ctx.ground = function(x, z) return groundY(x, z, st.y) end
		ctx.shake = shakeAt
		ctx.bonePos = function(name)                                                     -- (a bone's world position: knee, crown, gauntlets)
			local e = bones[name]
			return e and e.b.TransformedWorldCFrame.Position or m:GetPivot().Position
		end
		-- its home base (the 16 matter fly back there on DEFEAT); the MOVE TEST arena sits beside the +X base
		ctx.home = Vector3.new(m:GetAttribute("HomeX") or 395, 0, m:GetAttribute("HomeZ") or 0)
		ctx.gauntlet = function(side)
			local a = st.arms and st.arms[side]
			return a and (a.hand.TransformedWorldCFrame * a.gc) or m:GetPivot().Position
		end
		ctx.tip = function(side)                                                         -- (the gauntlet's far end)
			local a = st.arms and st.arms[side]
			return a and (a.hand.TransformedWorldCFrame * (a.gc / 0.565)) or m:GetPivot().Position
		end
		local function sndAt(id, pos, vol, speed)
			local at = Instance.new("Attachment"); at.Parent = fxPart; at.WorldPosition = pos
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id; s.Volume = vol; s.PlaybackSpeed = speed or 1
			s.RollOffMinDistance = 30; s.RollOffMaxDistance = 260; s.Parent = at
			return s, at
		end
		-- (from: seconds to skip; measured with PlaybackLoudness, some library sounds open with silence: the crystal
		-- shatter 0.7 s, the rock tumble 0.3 s, so their hit landed late)
		ctx.sound = function(id, pos, vol, speed, from)
			local s, at = sndAt(id, pos, vol, speed)
			if from then s.TimePosition = from end
			s:Play()
			game:GetService("Debris"):AddItem(at, 8)
		end
		-- a sound whose volume and pitch ramp over `dur` seconds, then fade out in 0.25 s (the sun's rising roar, the burn)
		ctx.soundRamp = function(id, pos, v0, v1, p0, p1, dur)
			local s, at = sndAt(id, pos, v0, p0)
			s:Play()
			local t0
			return { step = function(_, t)
				t0 = t0 or t
				local e = t - t0
				local k = math.clamp(e / dur, 0, 1)
				s.PlaybackSpeed = p0 + (p1 - p0) * k
				s.Volume = (v0 + (v1 - v0) * k) * (1 - math.clamp((e - dur) / 0.25, 0, 1))
				return e < dur + 0.3
			end, stop = function() at:Destroy() end }
		end
		st.ctx = ctx
		st.ctxTemplate = table.clone(ctx)                     -- (attack instances: each new attack gets a fresh copy)
	end
	-- (AI TEST: the server's AITest drives it: it walks / idles by its real motion and plays attacks once; see aiFrame)
	if mode == "ai" then st.ai, st.walkG, st.idleG = true, gait, Gaits[name .. "Idle"] or gait end
	tracked[m] = st
end

-- the pose a gait writes into: per-bone model-space rotation (degrees) + offset (studs), and the whole body's
-- bob / tilt; reset every frame
local function newPose()
	local p = { bones = {}, lift = 0, pitch = 0, roll = 0, yaw = 0, side = 0, fwd = 0, glow = 0 }
	function p.rot(name, rx, ry, rz, ox, oy, oz)
		p.bones[name] = { rx or 0, ry or 0, rz or 0, ox or 0, oy or 0, oz or 0 }
	end
	return p
end

local BONE_WRITES, DBG_NOBONES, DBG_NOPIVOT, DBG_NOGLOW, PROF_EV, PROF_FX = 0, false, false, false, 0, 0              -- (perf audit readouts, see the RenderStepped loop)

-- (perf P1, 29 Oct: units whose EmissiveStrength differs can't be drawn in one batch, so the per-frame breath / pulse /
-- attack glow halved the frame rate: 64 units 55 -> 113 fps without it. The glow now snaps to 3 shared levels per form,
-- out / base / bright, written only when the level changes)
local function setGlow(st, es)
	local lv = (es < st.glow * 0.5) and 0 or (es >= st.glow + 0.25) and 2 or 1
	if lv == st.glowLv or DBG_NOGLOW then return end
	st.glowLv = lv
	st.sa.EmissiveStrength = (lv == 0) and 0 or (lv == 2) and st.glow + 0.6 or st.glow
end
local function apply(st, pose)
	if DBG_NOBONES then return end
	for name, e in st.bones do
		BONE_WRITES += 1
		local v = pose.bones[name]
		-- (the whole body's bob / tilt ride on the Root bone: ChatGPT gait audit, the pivot is the server's)
		if name == "Root" then v = { pose.pitch, pose.yaw, pose.roll, pose.side, pose.lift, -pose.fwd } end
		if v then
			local r = CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
			local inv = e.inv
			e.b.Transform = CFrame.new(inv * Vector3.new(v[4], v[5], v[6])) * (inv * r * e.rest)
		else
			e.b.Transform = CFrame.identity
		end
	end
	-- (29 Oct POSE HANDOFF, audit r2: the walk -> attack / idle switch popped the whole body pose in one frame, so the hips
	-- jumped and the feet hanging off them (0.5-0.65 studs a frame). After a handoff (poseHandoff) every bone eases from its
	-- last rendered pose over 0.18 s; the legs' IK, solved after this, has its own foot handoff)
	local pf = st.poseFrom
	if pf then
		local k = (os.clock() - pf.t) / 0.18
		if k >= 1 then
			st.poseFrom = nil
		else
			local w = k * k * (3 - 2 * k)
			for name, cf in pf.tf do local e = st.bones[name]; if e then e.b.Transform = cf:Lerp(e.b.Transform, w) end end
		end
	end
end

-- start a pose handoff from the bones as last rendered (st.lastTf, latched at the top of each AI frame). ONLY the bones
-- that carry the hips (Root and each leg's parent chain): the jump was the hips moving; heads, horns, arms, tentacles
-- keep their authored timing (audit r3: a whole-body blend would delay an attack's contact pose)
local function poseHandoff(st)
	if not st.lastTf then return end
	if not st.hipChain then
		local set = { Root = true }
		for _, leg in st.legs or {} do
			local b = leg.thigh.Parent
			while b and b:IsA("Bone") do set[b.Name] = true; b = b.Parent end
		end
		st.hipChain = set
	end
	local tf = {}
	for name in st.hipChain do tf[name] = st.lastTf[name] end
	st.poseFrom = { tf = tf, t = os.clock() }
end

-- ===== planted feet (Colossus v4 pilot; ChatGPT spec, design/06-COLOSSUS-V4-ANIMATION-SPEC.md) =====
-- Each foot lands on a foothold fixed on the ground (along the unit's path, `front` studs ahead of the hip at contact),
-- stays there while the body walks over it, rolls up onto its toe, then swings in an arc to the next foothold. Each
-- leg is a 2-bone IK chain (thigh + shin, knee pointing forward) solved onto that ankle target every frame.
local function smoother(t) t = math.clamp(t, 0, 1); return t * t * t * (t * (t * 6 - 15) + 10) end
local function smooth(t) t = math.clamp(t, 0, 1); return t * t * (3 - 2 * t) end
local UP = Vector3.yAxis
-- a rotation taking the rest basis (dir, fwd) to the wanted one, both in the bone's own frame
local function basis(dir: Vector3, fwd: Vector3)
	local x = dir.Unit
	local y = (fwd - x * fwd:Dot(x)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end
local function aim(bone: Bone, w0: CFrame, restDir, restFwd, wantDir: Vector3, wantFwd: Vector3)
	local inv = w0.Rotation:Inverse()
	bone.Transform = basis(inv * wantDir, inv * wantFwd) * basis(restDir, restFwd):Inverse()
end
-- the ankle for a foot on foothold F with pitch (deg): heel strike (+) pivots on the heel, toe-off (-) on the toe
local function place(leg, F: CFrame, pitch: number): Vector3
	local a = leg.ankle
	if pitch == 0 then return F * a end
	local pv = a + Vector3.new(0, 0.05 - a.Y, (pitch < 0) and leg.toeZ or leg.heelZ)
	return F * (pv + CFrame.Angles(math.rad(pitch), 0, 0) * (a - pv))
end

-- footfall feedback (ChatGPT LOCK): dust + a little magma-lit steam at the foot, the glow pulses, nearby cameras shake
fxPart = Instance.new("Part")
fxPart.Name = "FootfallFX"; fxPart.Anchored = true; fxPart.CanCollide = false; fxPart.CanQuery = false; fxPart.CanTouch = false
fxPart.Transparency = 1; fxPart.Size = Vector3.one; fxPart.Parent = workspace
local fxAt = Instance.new("Attachment"); fxAt.Parent = fxPart
local dust = Instance.new("ParticleEmitter")
-- (ChatGPT pilot audit r1: pale dust vanished on the pale ground: darker basalt grey, outward and a little up)
dust.Enabled = false; dust.Texture = SMOKE; dust.Lifetime = NR(0.45, 0.65); dust.Speed = NR(2, 4)
dust.SpreadAngle = Vector2.new(70, 70); dust.EmissionDirection = Enum.NormalId.Top; dust.Acceleration = Vector3.new(0, -2.5, 0)
dust.Drag = 2.5; dust.Size = curve(0.5, 1.8, 2.4); dust.Transparency = curve(0.25, 0.55, 1); dust.Color = CS(C(117, 111, 105))
dust.Rotation = NR(0, 360); dust.RotSpeed = NR(-40, 40); dust.Shape = Enum.ParticleEmitterShape.Disc
dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume; dust.Parent = fxAt
local puff = Instance.new("ParticleEmitter")
puff.Enabled = false; puff.Texture = SMOKE; puff.Lifetime = NR(0.6, 0.9); puff.Speed = NR(1.5, 2.5)
puff.SpreadAngle = Vector2.new(20, 20); puff.EmissionDirection = Enum.NormalId.Top; puff.Acceleration = Vector3.new(0, 1.5, 0)
puff.Size = curve(0.8, 1.8, 2.4); puff.LightEmission = 0.3; puff.Transparency = curve(0.5, 0.45, 1)
puff.Color = CS(C(255, 140, 60), C(150, 140, 130)); puff.Parent = fxAt
local THUD = "rbxassetid://9125404774"   -- Boomy Footsteps, Giant, Thumpy 2 (ProSoundEffects)
local shakeUntil, shakeAmp, shakeReady, shakeDur = 0, 0, 0, 0.18
-- a camera shake from something at `pos`: full `amp` (studs) within r0, fading out by r1; the strongest one wins, and
-- a new one waits 0.35 s after the last (ChatGPT budget: one shake at a time)
shakeAt = function(pos: Vector3, amp: number, dur: number, r0: number, r1: number)
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 999
	local a = amp * math.clamp(1 - (d - r0) / (r1 - r0), 0, 1)
	local t = os.clock()
	if a <= 0 then return end
	if t >= shakeReady or a > shakeAmp * math.max(0, (shakeUntil - t) / shakeDur) then
		shakeUntil, shakeAmp, shakeReady, shakeDur = t + dur, a, t + 0.35, dur
	end
end
local goo                                                    -- (the SQUISH droplets: made below, with the beats)
local function footfall(st, pos: Vector3, now: number)
	st.pulseAt = now
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 999
	if d > 120 then return end
	fxAt.WorldPosition = pos
	local ik = st.gait.ik
	-- (a SQUISH form's footfall (the Brute's fists) splashes goo, not stone dust)
	if ik.goo then goo:Emit(d > 60 and 3 or (ik.dust or 7)) else dust:Emit(d > 60 and 2 or (ik.dust or 7)) end
	-- (a trot lands two hooves at once: one sound for the pair)
	if now - (st.thudAt or -9) < 0.06 then return end
	st.thudAt = now
	-- the STOMP: a giant's boomy footstep (ProSoundEffects, Roblox's free licensed library): hits at once, then a
	-- 2.5 s rumble. (James, 27 Oct: the first pick, a rock drop slowed down, "sounds like a pebble on the floor";
	-- measured, it peaked at a fifth of this one and was over in 0.3 s.) Near full pitch so the mid-range crunch
	-- still reaches a phone speaker
	local at = Instance.new("Attachment")
	at.Parent = fxPart; at.WorldPosition = pos
	local snd = Instance.new("Sound")
	snd.SoundId = ik.thud or THUD; snd.Volume = ik.thudVol or 1.4; snd.PlaybackSpeed = (ik.thudPitch or 0.9) + math.random() * 0.1
	if ik.thudFrom then snd.TimePosition = ik.thudFrom end
	snd.RollOffMinDistance = 25; snd.RollOffMaxDistance = 220; snd.Parent = at
	snd:Play()
	game:GetService("Debris"):AddItem(at, 4)
	if d <= 60 and not ik.goo then puff:Emit(1) end
	-- (shake: 0.10 studs within 35, fading out by 70)
	shakeAt(pos, ik.shake or 0.10, 0.18, 35, 70)
end
-- ===== beats: the footfall / slap of a form WITHOUT planted feet (v5 rebuild, 28 Oct): its gait names the cycle
-- phases (gait.beats); each plays the race's sound and a puff at the unit. Pitch drops with size. (Sounds from
-- Roblox's licensed ProSoundEffects library, measured with PlaybackLoudness)
local BEAT = {
	-- (measured: Body Hit Wet peaks ~1/13 of Boomy Footsteps: vol 2.4 so the Titan's slap carries)
	squish = { id = "rbxassetid://9113520180", vol = 2.4, pitch = { 1.25, 1.1, 0.9, 0.75 } },   -- Body Hit Wet: a heavy wet slap
	crunch = { id = THUD, vol = 1.0, pitch = { 1.5, 1.3, 1.1, 0.95 } },                       -- Boomy Footsteps, Giant
}
goo = Instance.new("ParticleEmitter")
goo.Enabled = false; goo.Texture = SPARK; goo.Lifetime = NR(0.35, 0.6); goo.Speed = NR(4, 8)
goo.SpreadAngle = Vector2.new(65, 65); goo.EmissionDirection = Enum.NormalId.Top; goo.Acceleration = Vector3.new(0, -28, 0)
goo.Size = curve(0.55, 0.45, 0.1); goo.LightEmission = 0.6; goo.Transparency = curve(0, 0.2, 1)
goo.Color = CS(C(120, 235, 255), C(60, 140, 255)); goo.Shape = Enum.ParticleEmitterShape.Disc
goo.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume; goo.Parent = fxAt
local function beatFx(m: Model, base: CFrame)
	local race, f = m:GetAttribute("Race") or "crunch", m:GetAttribute("Form") or 1
	local cam = workspace.CurrentCamera
	local pos = base.Position
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 999
	if d > 120 then return end
	local b = BEAT[race] or BEAT.crunch
	fxAt.WorldPosition = pos
	if race == "squish" then goo:Emit(d > 60 and 3 or 6 + 3 * f) else dust:Emit(d > 60 and 2 or 3 + 2 * f) end
	local at = Instance.new("Attachment")
	at.Parent = fxPart; at.WorldPosition = pos
	local snd = Instance.new("Sound")
	snd.SoundId = b.id; snd.Volume = b.vol * (0.6 + 0.15 * f); snd.PlaybackSpeed = b.pitch[f] * (0.95 + math.random() * 0.1)
	snd.RollOffMinDistance = 20; snd.RollOffMaxDistance = 180; snd.Parent = at
	snd:Play()
	game:GetService("Debris"):AddItem(at, 4)
	if f >= 3 then shakeAt(pos, 0.04 * f, 0.15, 25, 60) end
end

RunService:BindToRenderStep("AlienFootfallShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then return end
	local k = shakeAmp * (left / shakeDur)
	local cam = workspace.CurrentCamera
	cam.CFrame *= CFrame.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, 0)
end)

local FOOT_HANDOFF, FOOT_TELEPORT = 0.18, 2      -- (teleport = a foot gap over twice the leg's own reach)

-- drop every leg's footholds (re-taken on the next solve); each foot steps over from where it RENDERED last frame
-- (renderedP, latched at the top of each AI frame: solveLegs can run 2-3 times a frame, so drawnP may be provisional)
local function resetFeet(st, plantsToo: boolean)
	local m = st.ctx and st.ctx.m
	if m then m:SetAttribute("FeetResets", (m:GetAttribute("FeetResets") or 0) + 1) end   -- (test readout)
	poseHandoff(st)
	for _, leg in st.legs do
		leg.stand = nil
		if plantsToo then table.clear(leg.plants); leg.lastK = nil end
		local p, r = leg.renderedP or leg.drawnP, leg.renderedR or leg.drawnR
		if p then leg.from = { p = p, r = r, t = os.clock() } end
	end
end

-- the legs: s = studs walked; at(u) = the ground frame on the path u studs along (facing along it)
local function solveLegs(st, base: CFrame, s: number, at, standing: boolean, now: number)
	if DBG_NOBONES then return end
	local ik = st.gait.ik
	local fwdv = base.LookVector
	for side, leg in st.legs do
		BONE_WRITES += 3
		local pole = leg.back and -fwdv or fwdv                           -- (the knee forward; a hock back)
		local x = s / ik.stride - leg.off
		local k = math.floor(x)
		local q = x - k
		local function plant(n)
			local f = leg.plants[n]
			if not f then
				f = at((n + leg.off) * ik.stride + ik.front + leg.front)
				leg.plants[n] = f
				leg.plants[n - 3] = nil
			end
			return f
		end
		local ankle, rot
		if standing then
			leg.stand = leg.stand or at(s)
			ankle, rot = place(leg, leg.stand, 0), leg.stand.Rotation * leg.footRest
		elseif q < ik.stance then
			-- planted: heel strike rolling flat, flat, then up onto the toe
			local pitch = 0
			if q < 0.08 then pitch = ik.heel * (1 - smooth(q / 0.08))
			elseif q > ik.stance - 0.14 then pitch = -ik.toe * smooth((q - (ik.stance - 0.14)) / 0.14) end
			local F = plant(k)
			ankle, rot = place(leg, F, pitch), F.Rotation * CFrame.Angles(math.rad(pitch), 0, 0) * leg.footRest
			if leg.lastK and k > leg.lastK then footfall(st, F * Vector3.new(leg.ankle.X, 0, leg.ankle.Z - 0.3), now) end
			leg.lastK = k
		else
			-- swinging: from the toe-off to the next heel strike, in an arc
			local t = (q - ik.stance) / (1 - ik.stance)
			local A, B = plant(k), plant(k + 1)
			-- (leaves fast, brakes into the contact: a pure smootherstep starts at rest, so the trailing foot fell
			-- further behind than the leg reaches while the body kept walking: 0.2 studs over in the test)
			local e = 0.5 * (1 - (1 - t) ^ 2) + 0.5 * smoother(t)
			local pitch = -ik.toe + (ik.toe + ik.heel) * smooth(t)
			ankle = place(leg, A, -ik.toe):Lerp(place(leg, B, ik.heel), e) + UP * ik.lift * math.sin(math.pi * t)
			rot = A.Rotation:Lerp(B.Rotation, e) * CFrame.Angles(math.rad(pitch), 0, 0) * leg.footRest
		end
		-- (batch 3 TARGET mode: an attack pulls this limb's end to a world point, weight w; the IK below bends to it)
		local tg = st.limbTargets and st.limbTargets[side]
		-- (the target is where the fist / foot TOUCHES; its bone rides its rest height above that: 1.45 on the Brute's fists)
		if tg and tg.w > 0 then ankle = ankle:Lerp(tg.p + UP * (tg.raw and 0 or leg.ankle.Y), tg.w) end
		-- (DEFEAT: a kneeling leg's ankle is pulled back and tipped onto the toe, so the knee comes down to the ground)
		local kn = st.kneel and st.kneel.side == side and st.kneel
		if kn and kn.w > 0 then
			local flat = CFrame.lookAt(base.Position, base.Position + Vector3.new(fwdv.X, 0, fwdv.Z)).Rotation
			local p = base * Vector3.new(leg.ankle.X, 0, leg.ankle.Z + kn.back)
			local kAnkle = Vector3.new(p.X, groundY(p.X, p.Z, st.y) + kn.up, p.Z)
			ankle = ankle:Lerp(kAnkle, kn.w)
			rot = rot:Lerp(flat * CFrame.Angles(math.rad(kn.toe), 0, 0) * leg.footRest, kn.w)
		end
		-- (29 Oct HANDOFF: a foothold reset (resetFeet: attack start, a travel starting / ending, walk <-> idle, the legs
		-- changing owner) teleported a foot caught mid-stride to its new spot in one frame, up to 3-4 studs. It now steps
		-- there from where it was RENDERED last frame, in a low arc. Applied last (after attack targets and the kneel) so
		-- nothing re-adds a jump; its length grows with the distance so a foot never moves faster than 15 studs/s at the
		-- smoothstep's peak 1.5 d / T (0.5 a frame at 30 fps, audit r2 + r3: no upper cap, it broke the bound past 3.5 studs).
		-- A gap over FOOT_TELEPORT x the leg's reach is a real teleport of the whole unit (a hop-on, a place()), not a step:
		-- not smoothed (a flat 4 studs snapped real Colossus / Ram steps of 4.3-4.8, measured).
		-- os.clock, so a frozen / clamped attack clock can't stall it)
		local hf = leg.from
		if hf and not hf.T then
			local d = (hf.p - ankle).Magnitude
			if d > FOOT_TELEPORT * (leg.l1 + leg.l2) then leg.from, hf = nil, nil else hf.T = math.max(FOOT_HANDOFF, d / 10) end
		end
		if hf then
			local k = (os.clock() - hf.t) / hf.T
			if k >= 1 then
				leg.from = nil
			else
				local e = smooth(k)
				local lift = math.min(ik.lift or 0.5, (hf.p - ankle).Magnitude * 0.3)
				ankle = hf.p:Lerp(ankle, e) + UP * lift * math.sin(math.pi * k)
				rot = hf.r:Lerp(rot, e)
			end
		end
		-- 2-bone IK, knee forward
		local hipsCF = leg.thigh.Parent:IsA("Bone") and (leg.thigh.Parent :: Bone).TransformedWorldCFrame or base
		local w0t = hipsCF * leg.thigh.CFrame
		local hip = w0t.Position
		local to = ankle - hip
		local reach = leg.l1 + leg.l2 - 0.02
		local over = to.Magnitude - reach
		if over > (st.over or 0) then st.over, st.overQ = over, q end
		local d = math.clamp(to.Magnitude, math.abs(leg.l1 - leg.l2) + 0.05, reach)
		local u = to.Unit
		local w = (pole - u * pole:Dot(u)).Unit
		local c = math.clamp((leg.l1 * leg.l1 + d * d - leg.l2 * leg.l2) / (2 * leg.l1 * d), -1, 1)
		local knee = hip + (u * c + w * math.sqrt(1 - c * c)) * leg.l1
		aim(leg.thigh, w0t, leg.dirT, leg.fwdT, knee - hip, fwdv)
		local w0s = w0t * leg.thigh.Transform * leg.shin.CFrame
		aim(leg.shin, w0s, leg.dirS, leg.fwdS, (hip + u * d) - knee, fwdv)
		local w0f = w0s * leg.shin.Transform * leg.foot.CFrame
		leg.foot.Transform = w0f.Rotation:Inverse() * rot
		leg.drawnP, leg.drawnR = hip + u * d, rot                      -- (the ankle as solved, reach-clamped = what renders)
	end
end

-- ===== attacks (James, 27 Oct: three for the Colossus v4 pilot; the Attacks module holds the timelines + effects) =====
-- an arm reaching its gauntlet's tip for `target` (world): 2-bone IK, the elbow bending back and out, blended over the
-- posed arm by w (ChatGPT: the fists must really meet the ground / the boulder, not just get close by angles)
local function reachArm(a, target: Vector3, base: CFrame, w: number)
	local fkA, fkH = a.arm.Transform, a.hand.Transform
	local w0a = (a.arm.Parent :: Bone).TransformedWorldCFrame * a.arm.CFrame
	local sh = w0a.Position
	local to = target - sh
	local d = math.clamp(to.Magnitude, math.abs(a.l1 - a.l2) + 0.05, a.l1 + a.l2 - 0.02)
	local u = to.Unit
	local pole = (-base.LookVector + base.RightVector * a.sx * 0.6).Unit
	local wv = (pole - u * pole:Dot(u)).Unit
	local c = math.clamp((a.l1 * a.l1 + d * d - a.l2 * a.l2) / (2 * a.l1 * d), -1, 1)
	local elbow = sh + (u * c + wv * math.sqrt(1 - c * c)) * a.l1
	aim(a.arm, w0a, a.dirA, a.fwdA, elbow - sh, base.LookVector)
	local w0h = w0a * a.arm.Transform * a.hand.CFrame
	aim(a.hand, w0h, a.dirH, a.fwdH, (sh + u * d) - elbow, base.LookVector)
	if w < 1 then a.arm.Transform = fkA:Lerp(a.arm.Transform, w); a.hand.Transform = fkH:Lerp(a.hand.Transform, w) end
end

-- an attack pose (Attacks.pose: ChatGPT's tables, + pitch = bending forward) as a gait pose (+ rx = nose UP)
local function attackPose(p)
	local pose = newPose()
	if p.bones then                                  -- (per-bone keys: any rig, e.g. the Titan)
		local rt = p.root
		pose.lift, pose.side, pose.fwd, pose.pitch, pose.roll, pose.yaw = rt[1], rt[2], rt[3], rt[4], rt[5], rt[6]
		for name, v in p.bones do pose.rot(name, v[1], v[2], v[3], v[4], v[5], v[6]) end
		pose.glow, pose.glowMul = p.glow or 0, p.glowMul or 1
		return pose
	end
	pose.lift, pose.side, pose.fwd = p.R[1], p.R[2], p.R[3]
	pose.rot("Hips", -(p.R[4] + p.P[1]), p.yaw[1], 0)          -- (the whole-body pitch pivots at the hips, not the feet)
	pose.rot("Belly", -p.P[2], p.yaw[2], 0)
	pose.rot("Chest", -p.P[3], p.yaw[3], 0)
	pose.rot("Head", -p.P[4], p.yaw[4], 0)
	pose.yaw = p.rootYaw or 0                                    -- (aimed attacks turn the whole body a little: batch-1 spec)
	pose.rot("ArmL", p.arms[1], p.armYaw or 0, p.armsIn); pose.rot("ArmR", p.arms[2], p.armYaw or 0, -p.armsIn)
	pose.rot("HandL", p.hands[1]); pose.rot("HandR", p.hands[2])
	pose.glow, pose.glowMul = p.glow, p.glowMul or 1
	return pose
end

local function stopFx(st)
	for _, f in st.fx do pcall(f.stop, f) end
	table.clear(st.fx)
	local ctx = st.ctx
	ctx.slamAt, ctx.sunAt, ctx.sunTarget, ctx.rockAt, ctx.rockY, ctx.rockHit, ctx.braceAt = nil, nil, nil, nil, nil, nil, nil
	if ctx.marker then ctx.marker:Destroy(); ctx.marker = nil end
end

-- ATTACK INSTANCES (AI TEST, 29 Oct: "attacks always play out"; ChatGPT commit design audit r2, design\aitest-fixes\).
-- A new attack used to stopFx the previous one: the Colossus's sun beam vanished the moment its next move began. Now the
-- previous attack, if its timeline isn't over and it wasn't cancelled, is DETACHED: it keeps its own ctx (a fresh clone
-- of the unit's ctx goes to the new attack, so no attack overwrites another's per-attack state), its own effects and its
-- own event cursor, and plays on its own clock to its end (fires its later events: future spawns, sounds; steps its
-- effects), then cleans up. The body belongs to the current attack only (the server starts the next one only after the
-- previous one's body has finished).
-- CANCELLED ATTACKS (build audit r1): a cancel always ends the attack's BODY part (its pose, its attached effects:
-- everything made before its release time, or all of it if it throws nothing). If its projectile had really been handed
-- over ("gone"), the WORLD part (effects made at / after the release: the flying rock, its impact) plays on to its end.
-- What survives is decided by OWNERSHIP the attack module declares (build audit r2: never by creation time): an effect
-- made by an event tagged `world = true` (f.world), or one that says it becomes the projectile at the release
-- (f.worldAt: the Boulder's rock, ripped at 0.80 and thrown at 2.55; the Sun's summoned sun, world at its 3.20 impact).
local function splitFx(fx, release)
	local keep = {}
	for _, f in fx do
		if release and (f.world or (f.worldAt and f.worldAt <= release)) then table.insert(keep, f) else pcall(f.stop, f) end
	end
	return keep
end
local function detachOrStop(st, rt)
	local old = st.attack
	local cut = st.attackId and st.cancelled and st.cancelled[st.attackId]        -- nil / "cut" / "gone"
	local speed = st.attackSpeed or 1
	local elapsed = st.aiAtkT0 and (rt - st.aiAtkT0) * speed or math.huge
	local live = st.ai and st.ctxTemplate and old and st.lastTT and elapsed < (old.dur or 0)
	if live and (not cut or (cut == "gone" and st.attackRelease)) then
		local fx, worldOnly = st.fx, nil
		if cut then fx, worldOnly = splitFx(st.fx, st.attackRelease), st.attackRelease end
		st.detached = st.detached or {}
		table.insert(st.detached, { atk = old, t0 = st.aiAtkT0, ctx = st.ctx, fx = fx, lastTT = st.lastTT, id = st.attackId,
			speed = speed, worldOnly = worldOnly, release = st.attackRelease })
		st.ctx, st.fx = table.clone(st.ctxTemplate), {}
		if #st.detached > (player:GetAttribute("AiDetachedMax") or 0) then player:SetAttribute("AiDetachedMax", #st.detached) end
	else
		-- (test readout: an attack's effects stopped before its end without a cancel: must stay 0)
		if st.ai and old and not cut and elapsed < (old.dur or 0) - 0.05 then
			player:SetAttribute("AiFxCutEarly", (player:GetAttribute("AiFxCutEarly") or 0) + 1)
		end
		stopFx(st)
	end
end
-- a cancel for a DETACHED attack: its body part stops now; its world part plays on only if it had really been thrown
local function endInstance(st, id, gone)
	if not st.detached then return end
	for i = #st.detached, 1, -1 do
		local inst = st.detached[i]
		if inst.id == id then
			local rel = gone and inst.release
			inst.fx = splitFx(inst.fx, rel or nil)
			if rel then inst.worldOnly = rel else table.remove(st.detached, i) end
		end
	end
end
local function tickDetached(st, rt)
	local list = st.detached
	if not list or #list == 0 then return end
	for i = #list, 1, -1 do
		local inst = list[i]
		local tt = (rt - inst.t0) * (inst.speed or 1)
		for _, ev in inst.atk.events or {} do
			if ev.t > (inst.lastTT or -1) and ev.t <= tt and (not inst.worldOnly or ev.world) then
				local pc0 = os.clock(); local ok, f = pcall(ev.fn, inst.ctx); PROF_EV += os.clock() - pc0
				if ok and f then f.world = ev.world; table.insert(inst.fx, f) elseif not ok then warn("detached attack event", ev.t, f) end
			end
		end
		inst.lastTT = tt
		for j = #inst.fx, 1, -1 do
			local f = inst.fx[j]
			local pc0 = os.clock(); local ok, alive = pcall(f.step, f, tt); PROF_FX += os.clock() - pc0
			if not ok or alive == false then pcall(f.stop, f); table.remove(inst.fx, j) end
		end
		if tt >= (inst.atk.dur or 0) then
			for _, f in inst.fx do pcall(f.stop, f) end
			table.remove(list, i)
		end
	end
end

-- HURT (batch 1): a big hit every HurtEvery s, alternating sides (MOVE TEST). Fires the hurt's effects and returns its
-- time (nil once it's over) and side. The pose is ADDED before the legs are solved, so the planted feet never move.
local function hurtTick(st, base: CFrame, now: number, t0: number)
	local ctx = st.ctx
	if not ctx then return nil, 1 end
	local ht, sg
	if st.ai then
		-- (AI TEST: one hurt per real hit, from the side it came from: the server's "hurt" events, see aiFrame)
		local h = st.aiHurt
		if not h then return nil, 1 end
		ht = now - h.t
		if ht < 0 or ht > st.hurtDef.dur + 1 then return nil, 1 end
		sg = h.side
		if st.lastHurtAt ~= h.t then st.lastHurtAt = h.t; st.lastHT = -1 end
	else
		local every = ctx.m:GetAttribute("HurtEvery")
		if not every or now < t0 then return nil, 1 end
		ht = (now - t0) % every
		sg = (((now - t0) // every) % 2 == 0) and 1 or -1
		if st.lastHT and ht < st.lastHT then st.lastHT = -1 end      -- (a new hit: its t = 0 effects fire too)
	end
	ctx.base = base
	ctx.hurtOut = base.RightVector * sg
	ctx.hurtAt = ctx.bonePos(st.bones.Chest and "Chest" or "Top") + base.RightVector * sg * 2.5
	for _, ev in st.hurtDef.events do
		if ev.t > (st.lastHT or -1) and ev.t <= ht then
			local ok, fx = pcall(ev.fn, ctx)
			if ok and fx then table.insert(st.fx, fx) elseif not ok then warn("hurt event", fx) end
		end
	end
	st.lastHT = ht
	return (ht < st.hurtDef.dur) and ht or nil, sg
end
-- the hurt pose at weight w (1 in a walk / idle, 0.35 during a committed attack: ChatGPT batch-1 spec)
local function addHurt(st, pose, ht, sg, w)
	if not ht then return end
	local hp = Attacks.pose(st.hurtDef, ht)
	if hp.bones then                                 -- (per-bone hurt: added bone by bone, mirrored by side)
		if st.hurtDef.pushX then sg = -sg end           -- (its keys push toward +X; a hit on the +X side mirrors them)
		local rt = hp.root
		pose.lift += rt[1] * w; pose.side += rt[2] * sg * w; pose.fwd += rt[3] * w
		pose.pitch += rt[4] * w; pose.roll += rt[5] * sg * w; pose.yaw += rt[6] * sg * w
		for name, v in hp.bones do
			if sg < 0 then                               -- (asymmetric chains: a hit from the other side swaps left and right)
				local sd = name:match("^Tent%a([LR])%d$")
				if sd then name = name:sub(1, 5) .. ((sd == "L") and "R" or "L") .. name:sub(7) end
				local pre, fb, lr = name:match("^(%a+)([FB])([LR])$")
				if pre and (pre == "Leg" or pre == "Shin" or pre == "Foot") then name = pre .. fb .. ((lr == "L") and "R" or "L") end
				local dsd = name:match("^Dent([LR])$")                -- (the Twin's dent bones)
				if dsd then name = (dsd == "L") and "DentR" or "DentL" end
			end
			local o = pose.bones[name] or { 0, 0, 0, 0, 0, 0 }
			for i = 1, 6 do o[i] += (v[i] or 0) * w * ((i == 2 or i == 3 or i == 4) and sg or 1) end
			pose.bones[name] = o
		end
		pose.glowMul = (pose.glowMul or 1) * (1 - (1 - (hp.glowMul or 1)) * w)
		return
	end
	local function add(name, rx, ry)
		local v = pose.bones[name] or { 0, 0, 0, 0, 0, 0 }
		v[1] += rx * w; v[2] += (ry or 0) * w
		pose.bones[name] = v
	end
	local aL, aR, hL, hR = hp.arms[1], hp.arms[2], hp.hands[1], hp.hands[2]
	if sg < 0 then aL, aR, hL, hR = aR, aL, hR, hL end
	pose.lift += hp.R[1] * w; pose.side += hp.R[2] * sg * w; pose.fwd += hp.R[3] * w
	add("Hips", -(hp.R[4] + hp.P[1]), hp.yaw[1] * sg); add("Belly", -hp.P[2], hp.yaw[2] * sg)
	add("Chest", -hp.P[3], hp.yaw[3] * sg); add("Head", -hp.P[4], hp.yaw[4] * sg)
	add("ArmL", aL); add("ArmR", aR); add("HandL", hL); add("HandR", hR)
	pose.glowMul = (pose.glowMul or 1) * (1 - (1 - hp.glowMul) * w)
end

-- one frame of an ATTACK unit: it stands in its idle; from T0 it plays its attack, then 2.2 s of idle, on repeat
local function runAttack(st, base: CFrame, at, now: number, t0: number)
	local atk = st.attack
	-- (test hook: FreezeTT holds the attack at that moment, for stills; set on the client only)
	local fz = st.ctx.m:GetAttribute("FreezeTT")
	if fz then now = t0 + ((now - t0) // (atk.cycle or atk.dur + 2.2)) * (atk.cycle or atk.dur + 2.2) + fz end
	local ip = newPose()
	st.gait.fn(now - t0, ip)
	local ht, hsg = hurtTick(st, base, now, t0)
	addHurt(st, ip, ht, hsg, 1)
	st.kneel, st.limbTargets = nil, nil
	local tt = now - t0
	local pose = ip
	if tt < 0 then
		apply(st, ip); if st.legs then solveLegs(st, base, 0, at, true, now) end
	else
		local cycle = (now - t0) // (atk.cycle or atk.dur + 2.2)
		tt %= atk.cycle or atk.dur + 2.2
		local ctx = st.ctx
		ctx.base = base
		if not st.lastTT or tt < st.lastTT then
			if st.lastTT then stopFx(st) end
			st.lastTT = -1                    -- (a new repeat: its t = 0 events must fire too)
			-- (MOVE TEST: an aimed attack picks a new target point each repeat, marked by a little post)
			local aim
			if atk.aims and ctx.m:GetAttribute("AimTest") then
				local list = (atk.testAims and Attacks[atk.testAims]) or Attacks.TEST_AIMS
				local d = list[(cycle % #list) + 1]
				local p = base * (CFrame.Angles(0, math.rad(d[2]), 0) * Vector3.new(0, 0, -d[1]))
				aim = Vector3.new(p.X, groundY(p.X, p.Z, st.y), p.Z)
				ctx.marker = Instance.new("Part")
				ctx.marker.Anchored, ctx.marker.CanCollide, ctx.marker.CanQuery = true, false, false
				ctx.marker.Size, ctx.marker.Color, ctx.marker.Material = Vector3.new(0.6, 5, 0.6), Color3.fromRGB(70, 160, 255), Enum.Material.Neon
				ctx.marker.CFrame = CFrame.new(aim + Vector3.new(0, 2.5, 0)); ctx.marker.Parent = ctx.holder
			end
			if not aim and atk.aims and ctx.m:GetAttribute("AiAimX") then   -- (AI TEST: aimed at the server's target point)
				local ax, az = ctx.m:GetAttribute("AiAimX"), ctx.m:GetAttribute("AiAimZ")
				aim = Vector3.new(ax, groundY(ax, az, st.y), az)
			end
			Attacks.setAim(atk, ctx, aim)
		end
		for _, ev in atk.events do
			if ev.t > (st.lastTT or -1) and ev.t <= tt then
				local pc0 = os.clock(); local ok, f = pcall(ev.fn, ctx); PROF_EV += os.clock() - pc0
				if ok and f then f.world = ev.world; table.insert(st.fx, f) elseif not ok then warn("attack event", ev.t, f) end
			end
		end
		st.lastTT = tt
		-- (batch 7 TRAVEL: on starting / leaving a travel the footholds are dropped, so the feet plant along the new line, then
		-- again at the cast spot)
		local trOn = (atk.travel ~= nil) and tt < atk.dur and atk.travel(ctx, tt) ~= nil
		if st.legs and trOn ~= (st.traveling == true) then
			st.traveling = trOn
			resetFeet(st, true)
		end
		-- (gameplay lock, power graph 09: after it the body blends back in 0.25 s while the effects play on)
		local lockT = (atk.testLock and ctx.m:GetAttribute("MoveTest")) and atk.testLock or atk.lock
		local w = (tt < atk.dur) and smooth(tt / 0.2) * (lockT and (1 - smooth((tt - lockT) / 0.25)) or (1 - smooth((tt - (atk.dur - 0.25)) / 0.25))) or 0
		-- (perf P3a, 29 Oct: the idle pose under an attack is only seen while it blends in / out (w < 1); fully blended in,
		-- posing it was a whole extra pass over every bone + a leg solve each frame)
		if w < 1 then apply(st, ip); if st.legs then solveLegs(st, base, 0, at, true, now) end end
		if tt < atk.dur then
			-- (batch 4: PLACE: the whole unit put on a frame the attack returns: the Drip hopping onto a big enemy and stuck to
			-- it, its BOING escape. Bones then pose as usual on top; ctx.base stays the ground spot it started from)
			if atk.place then
				local cf = atk.place(ctx, tt, base)
				if cf then ctx.m:PivotTo(cf) end
			end
			-- blended in over 0.2 s and out over the last 0.25 s, over the idle
			local held
			if w < 1 then held = {}; for name, e in st.bones do held[name] = e.b.Transform end end
			pose = attackPose(Attacks.pose(atk, tt, ctx))
			addHurt(st, pose, ht, hsg, (tt < (((atk.testLock and ctx.m:GetAttribute("MoveTest")) and atk.testLock or atk.lock) or atk.dur)) and 0.35 or 1)
			st.limbTargets = atk.limbs and atk.limbs(tt, ctx) or nil
			if atk.kneel then
				local k = atk.kneel
				st.kneel = { side = k.side, back = k.back, up = k.up, toe = k.toe, w = smooth((tt - k.t0) / (k.t1 - k.t0)) }
			end
			apply(st, pose)
			-- (batch 7 TRAVEL: an attack that carries the whole unit along a line (the Ram's charge) gives its legs that line:
			-- atk.travel(ctx, tt) -> distance along it, at(distance) -> the ground frame there, standing (true while it stands
			-- at the end); the feet gallop / plant along it instead of staying at the cast spot)
			local trS, trAt, trStand, trIk = nil, nil, nil, nil
			if atk.travel then trS, trAt, trStand, trIk = atk.travel(ctx, tt) end
			if st.legs then
				if trS then
					if trStand then for _, leg in st.legs do leg.stand = trAt(trS) end end      -- (standing at the line's end)
					-- (its own leg timing while it travels: an attack unit stands in its IDLE gait, whose feet never swing)
					local g0 = st.gait
					if trIk then st.gait = { ik = trIk, fn = g0.fn } end
					solveLegs(st, ctx.m:GetPivot(), trS, trAt, trStand, now)
					st.gait = g0
				else solveLegs(st, base, 0, at, true, now) end
			end
			-- (batch 2 audit r1: tentacle tips that must touch the ground at the hit: the measured tip height is pulled to the
			-- target by turning the chain's root, at most maxDeg; the FK keys do the rest. Weighted in t0-t1, out t2-t3)
			local c = atk.contact
			if c and tt > c.t0 and tt < c.t3 then
				local w = (tt < c.t1) and smooth((tt - c.t0) / (c.t1 - c.t0)) or (1 - smooth((tt - c.t2) / (c.t3 - c.t2)))
				local over = 0
				for _, ch in c.chains do
					-- (a chain: "TentFL" (its root's rx raises it: the Titan) or { name, axis, sign, perDeg }: the Twin's
					-- tendrils drop with +rz on the left, -rz on the right)
					local cs = (type(ch) == "table") and ch or { name = ch, axis = 1, sign = 1 }
					local tip, v = st.bones[cs.name .. "3"], pose.bones[cs.name .. "1"]
					if tip and v then
						local p = tip.b.TransformedWorldCFrame.Position
						local deg = ((p.Y - groundY(p.X, p.Z, st.y)) - c.target) / (cs.perDeg or c.perDeg)
						over = math.max(over, math.abs(deg) - c.maxDeg)
						v[cs.axis] -= cs.sign * math.clamp(deg, -c.maxDeg, c.maxDeg) * w
					end
				end
				apply(st, pose)
				if fz then ctx.m:SetAttribute("ContactOver", over) end          -- (> 0: the correction saturated)
			elseif c and fz and tt <= c.t0 then
				ctx.m:SetAttribute("ContactOver", 0)                           -- (a fresh slam starts clean)
			end
			-- (batch 5: SETTLE: the whole unit nudged AFTER its attack pose is on (place runs over the idle pose): the Pebble's
			-- horn tip / mandibles pulled onto the surface point; the attack returns the corrected pivot)
			if atk.settle then
				local cf = atk.settle(ctx, tt)
				if cf then ctx.m:PivotTo(cf) end
			end
			-- (batch 6: POST: the attack nudges single bones AFTER the pose is on (the Pincer's claws turned onto their targets'
			-- surfaces, its jaws closed onto the blade); gets the bone table { [name] = { b = Bone } })
			if atk.post then atk.post(ctx, tt, st.bones) end
			-- (batch 3: REACH BY STRETCH: a goo chain's bones slide so its tip lands on a world point (the Twin's two slaps,
			-- the Brute's stretch grab). Each bone takes an equal share of the move; children inherit it, so the tip gets it
			-- all and the goo skin stretches between. Weighted in t0-t1, held, out t2-t3; at most `max` studs)
			for _, rc in atk.reach or {} do
				if tt > rc.t0 and tt < rc.t3 then
					local w = (tt < rc.t1) and smooth((tt - rc.t0) / (rc.t1 - rc.t0)) or (1 - smooth((tt - rc.t2) / (rc.t3 - rc.t2)))
					local target = rc.target(ctx, tt)
					local tipE = st.bones[rc.chain[#rc.chain]]
					if target and tipE and w > 0 then
						local d = (target - tipE.b.TransformedWorldCFrame.Position) * w
						if rc.max and d.Magnitude > rc.max then d = d.Unit * rc.max end
						for _, name in rc.chain do
							local e = st.bones[name]
							if e then
								local pcf = e.b.Parent:IsA("Bone") and (e.b.Parent :: Bone).TransformedWorldCFrame or ctx.m:GetPivot()
								local frame = (pcf * e.b.CFrame).Rotation
								e.b.Transform = CFrame.new(frame:Inverse() * (d / #rc.chain)) * e.b.Transform
							end
						end
						if fz then ctx.m:SetAttribute("Reach" .. rc.chain[#rc.chain], (target - tipE.b.TransformedWorldCFrame.Position).Magnitude) end
					end
				end
			end
			if atk.ik and st.arms then
				local w, tL, tR = atk.ik(tt, ctx)
				if w and w > 0 then
					if tL then reachArm(st.arms.L, tL, base, w) end
					if tR then reachArm(st.arms.R, tR, base, w) end
				end
			end
			if held then for name, e in st.bones do e.b.Transform = held[name]:Lerp(e.b.Transform, w) end end
			if fz and st.arms then                                      -- (test readouts while frozen)
				local tip, knee = ctx.tip("R"), ctx.bonePos("ShinR")
				ctx.m:SetAttribute("DbgTipR", tip.Y - groundY(tip.X, tip.Z, st.y))
				ctx.m:SetAttribute("DbgKneeR", knee.Y - groundY(knee.X, knee.Z, st.y))
				ctx.m:SetAttribute("IKOver", st.over or 0)
			end
		end
		for i = #st.fx, 1, -1 do
			local f = st.fx[i]
			local pc0 = os.clock(); local ok, alive = pcall(f.step, f, tt); PROF_FX += os.clock() - pc0
			if not ok or alive == false then
				if not ok then warn("attack effect", alive) end
				pcall(f.stop, f); table.remove(st.fx, i)
			end
		end
	end
	if st.sa then setGlow(st, st.glow * (pose.glowMul or 1) + pose.glow) end
end

-- ===== AI TEST units (AlienFusion-AI-Testing only) =====
-- The server (ServerScriptService.AITest) sends ONE message 10 times a second: every unit's position sample
-- { id, server time, x, z, facing, speed } and the events since the last one ({ id, "atk", name, t0, aimX, aimZ,
-- targetId, slot } / { id, "hurt", t, side }). Each unit is drawn on its own steady clock 0.35 s behind the newest
-- sample, and its attacks and hurts play on that SAME clock, so a hit, the body it lands on and the jump an attack
-- carries it through all line up. (28 Oct, James: "stuttering": attribute updates arrived 0.05-0.47 s apart and late.)
local aiSamples: { [number]: { any } } = {}
local aiQueue: { [number]: { atks: { any }, hurts: { any } } } = {}
task.spawn(function()
	local ev = AF:WaitForChild("AIState", 30)
	if not ev then return end
	ev.OnClientEvent:Connect(function(list, events)
		for _, s in list or {} do
			local q = aiSamples[s[1]]
			if not q then q = {}; aiSamples[s[1]] = q end
			if #q == 0 or s[2] > q[#q].t then
				table.insert(q, { t = s[2], x = s[3], z = s[4], f = s[5], v = s[6] })
				if #q > 24 then table.remove(q, 1) end
			end
		end
		for _, e in events or {} do
			local q = aiQueue[e[1]]
			if not q then q = { atks = {}, hurts = {}, marks = {} }; aiQueue[e[1]] = q end
			if e[2] == "atk" then table.insert(q.atks, { name = e[3], t0 = e[4], ax = e[5], az = e[6], tgt = e[7], slot = e[8], id = e[9], speed = e[10] or 1, release = e[11] or nil })
			elseif e[2] == "hurt" then table.insert(q.hurts, { t = e[3], side = e[4] })
			-- (attack commit, 29 Oct: a cancel of one attack by id (+ whether its projectile had already left), and the end
			-- of a shield that one attack's aura shows)
			elseif e[2] == "cancel" then table.insert(q.marks, { t = e[4], kind = "cancel", id = e[3], released = e[6] == true })
			elseif e[2] == "shieldEnd" then table.insert(q.marks, { t = e[3], kind = "shieldEnd", key = tostring(e[4]) .. ":" .. tostring(e[5]) }) end
		end
	end)
end)

-- walk or idle by its real speed; footholds laid along its facing (at), so planted feet stay put while it walks
local function aiWalk(st, m: Model, base: CFrame, now: number, stepFx: boolean)
	local y = base.Position.Y
	local moving = (st.aiMoving and st.spd > 0.25) or st.spd > 0.8   -- (hysteresis: no walk / idle flicker as it arrives)
	local g = moving and st.walkG or st.idleG
	st.gait = g
	local ik = g.ik
	local sOff = (moving and ik) and (ik.start or 0) * ik.stride or 0
	local here = st.s + sOff
	local function at(u)
		local p = base * Vector3.new(0, 0, -(u - here))
		local gp = Vector3.new(p.X, groundY(p.X, p.Z, y), p.Z)
		return CFrame.lookAt(gp, gp + base.LookVector)
	end
	local pose = newPose()
	if moving then
		local phase = (here / g.stride) % 1
		g.fn(phase, pose, here)
		if g.beats then
			local lp = st.lastPhase
			if lp then for _, b in g.beats do if (lp < b and phase >= b) or (phase < lp and (b > lp or b <= phase)) then beatFx(m, base) end end end
			st.lastPhase = phase
		end
	else
		g.fn(now - st.born, pose)
	end
	if st.bones.Lid then pose.rot("Lid", LID_ANGLE * blinkAmount(st, os.clock())) end
	local ht, hsg = hurtTick(st, base, now, now); addHurt(st, pose, ht, hsg, 1)
	apply(st, pose)
	if st.legs then
		-- (29 Oct: taking the legs back from an attack, its footholds were the walk's from BEFORE the attack: the feet jumped
		-- there in one frame as the attack ended. Owner changes (attack <-> walk) hand the feet over like any reset)
		if moving ~= st.aiMoving or st.legOwner ~= "walk" then resetFeet(st, true); st.legOwner = "walk" end
		solveLegs(st, base, here, at, not moving, now)
	end
	st.aiMoving = moving
	if st.sa then setGlow(st, st.glow * (pose.glowMul or 1) + pose.glow) end
	if stepFx and st.fx then
		for i = #st.fx, 1, -1 do
			local fx = st.fx[i]
			local pc0 = os.clock(); local ok, alive = pcall(fx.step, fx, now); PROF_FX += os.clock() - pc0
			if not ok or alive == false then pcall(fx.stop, fx); table.remove(st.fx, i) end
		end
	end
	st.gait = st.walkG
	return at
end

local AI_DELAY = 0.35
local function aiFrame(st, m: Model, now: number)
	local id = m:GetAttribute("AiId")
	if not id then return end
	local dt = math.clamp(now - (st.aiLast or now), 0, 0.1); st.aiLast = now
	-- PLAYBACK BUFFER: our own steady clock (server time), AI_DELAY behind the newest sample, nudged gently toward that
	-- target, so the motion stays even however bursty the arrivals are. Starved: coast at its speed (0.3 s at most)
	local S = aiSamples[id]
	if not S or #S == 0 then
		local x0, z0 = m:GetAttribute("AiX"), m:GetAttribute("AiZ")
		if not (x0 and z0) then return end
		S = { { t = now, x = x0, z = z0, f = m:GetAttribute("AiFace") or 0, v = 0 } }   -- (just spawned: its spawn spot)
	end
	local target = S[#S].t - AI_DELAY
	if not st.clk or math.abs(target - st.clk) > 0.8 then st.clk = target
	else st.clk += dt + (target - st.clk) * math.min(1, dt * 1.5) end
	local rt = st.clk
	local nx, nz, nf, sv
	if #S == 1 or rt <= S[1].t then
		nx, nz, nf, sv = S[1].x, S[1].z, S[1].f, S[1].v
	elseif rt >= S[#S].t then
		local a = S[#S]
		local ex = math.min(rt - a.t, 0.3)
		nx, nz, nf, sv = a.x + math.sin(a.f) * a.v * ex, a.z - math.cos(a.f) * a.v * ex, a.f, a.v
	else
		for i = #S - 1, 1, -1 do
			local a, b = S[i], S[i + 1]
			if rt >= a.t then
				local k = (rt - a.t) / math.max(1e-4, b.t - a.t)
				nx, nz = a.x + (b.x - a.x) * k, a.z + (b.z - a.z) * k
				nf = a.f + ((((b.f - a.f) + math.pi) % (2 * math.pi)) - math.pi) * k
				sv = a.v + (b.v - a.v) * k
				break
			end
		end
	end
	if not st.px then st.px, st.pz, st.s, st.spd = nx, nz, 0, 0 end
	local moved = math.sqrt((nx - st.px) ^ 2 + (nz - st.pz) ^ 2)
	st.px, st.pz = nx, nz
	if moved < 3 then st.s += moved end                 -- (a jump an attack carried it through is not a stride)
	-- (a server JUMP (knockback, a charge's landing) moved the body over 1.5 studs this frame: footholds planted at the old
	-- spot would stretch the legs back to it. Hand the feet over to the new spot (audit r4: knockback mid-Gore))
	if moved >= 1.5 and st.legs then resetFeet(st, true) end
	st.spd += ((sv or 0) - st.spd) * math.min(1, dt * 8)
	local y = groundY(nx, nz, st.y); st.y = y
	local here = Vector3.new(nx, y, nz)
	local base = CFrame.lookAt(here, here + Vector3.new(math.sin(nf), 0, -math.cos(nf)))
	if not DBG_NOPIVOT then m:PivotTo(base) end                 -- (perf audit switch DbgNoPivot)
	-- the events due on our clock: the newest attack becomes the current one (its target / slot / aim set on our copy
	-- of the model, where the attack modules read them); hurts in order
	local q = aiQueue[id]
	if q then
		-- cancels, shield ends and new attacks in TIMESTAMP order (build audit r1); on a tie the mark goes first (a cancel
		-- is always sent before the move that replaces it)
		while true do
			local mk, a = q.marks[1], q.atks[1]
			local useMark = mk ~= nil and mk.t <= rt and (a == nil or a.t0 > rt or mk.t <= a.t0)
			if useMark then
				table.remove(q.marks, 1)
				st.cancelled = st.cancelled or {}
				if mk.kind == "cancel" then
					-- (its body always stops; "gone" = its projectile was really thrown: that part plays on)
					st.cancelled[mk.id] = mk.released and "gone" or "cut"
					if st.aiCurId == mk.id then st.aiCur = nil end         -- (the switch below splits / drops its effects)
					endInstance(st, mk.id, mk.released)
				elseif mk.kind == "shieldEnd" and Attacks.endShield then
					Attacks.endShield(m, mk.key)                           -- (that cast's shell on this unit only)
				end
			elseif a ~= nil and a.t0 <= rt then
				table.remove(q.atks, 1)
				-- (by attack id: an older attack never takes the body back from a newer one; one cancelled before it
				-- arrived never starts)
				if a.id and ((st.aiCurId and a.id <= st.aiCurId) or (st.cancelled and st.cancelled[a.id])) then
					player:SetAttribute("AiSkipped", (player:GetAttribute("AiSkipped") or 0) + 1)
					continue
				end
				st.aiCur, st.aiCurId = a, a.id
				m:SetAttribute("AiTgt", a.tgt); m:SetAttribute("Slot", a.slot)
				m:SetAttribute("AiAimX", (a.ax ~= 0 or a.az ~= 0) and a.ax or nil); m:SetAttribute("AiAimZ", (a.ax ~= 0 or a.az ~= 0) and a.az or nil)
			else
				break
			end
		end
		while #q.hurts > 0 and q.hurts[1].t <= rt do st.aiHurt = table.remove(q.hurts, 1) end
	end
	tickDetached(st, rt)
	-- (the feet as last frame rendered them: every foot handoff this frame starts there)
	if st.legs then for _, leg in st.legs do leg.renderedP, leg.renderedR = leg.drawnP, leg.drawnR end end
	st.lastTf = st.lastTf or {}
	for name, e in st.bones do st.lastTf[name] = e.b.Transform end
	local name = m:GetAttribute("FormName") or ""
	local cur = st.aiCur
	local atk = cur and ((Attacks.FOR[name] and Attacks.FOR[name][cur.name]) or Attacks[cur.name]) or nil
	local defeat = cur and cur.name == "Defeat"
	-- (the attack's own clock: a hasted swing (speed > 1) plays faster, so its body ends when the server's commitment does)
	local te = cur and (cur.t0 + (rt - cur.t0) * (cur.speed or 1)) or rt
	if atk and (defeat or te - cur.t0 < atk.dur) then
		if st.attack ~= atk or st.aiAtkT0 ~= cur.t0 then
			if st.attack then detachOrStop(st, rt) end
			st.attack, st.aiAtkT0, st.lastTT, st.attackId, st.attackSpeed = atk, cur.t0, nil, cur.id, cur.speed or 1
			st.attackRelease = cur.release
			st.ctx.atkId = cur.id                               -- (its own id: a Thump's shells are keyed by it)
			if st.legs then resetFeet(st, false) else poseHandoff(st) end
		end
		-- (runAttack plants the feet at at(0) = right under it. 29 Oct: this was -(u - st.s), i.e. the distance it had walked
		-- since it spawned: feet planted that far BEHIND, the legs flicked back and up reaching for them, worse the longer it
		-- had walked (James: Colossus / Ram / Brute "hovering" as attacks start))
		local function at(u)
			local p = base * Vector3.new(0, 0, -u)
			local gp = Vector3.new(p.X, groundY(p.X, p.Z, y), p.Z)
			return CFrame.lookAt(gp, gp + base.LookVector)
		end
		-- (after the body lock the AI may already be walking again: its walk takes over while the effects play on)
		-- (LATCHED per attack, audit r2: a speed hovering at 0.4 flipped the legs' owner every frame, restarting the handoff)
		local tail = st.tailFor == cur or (not defeat and te - cur.t0 > (atk.lock or atk.dur) + 0.25 and st.spd > 0.4)
		if tail then st.tailFor = cur end                   -- (cur = this attack's own event: a new attack never inherits it)
		if st.legs and not tail and st.legOwner ~= "atk" then resetFeet(st, true); st.legOwner = "atk" end
		st.gait = st.idleG
		runAttack(st, base, at, defeat and math.min(te, cur.t0 + atk.dur - 0.02) or te, cur.t0)
		st.gait = st.walkG
		if tail then aiWalk(st, m, base, rt, false) end
		return
	elseif st.attack then
		detachOrStop(st, rt); st.attack = nil
	end
	aiWalk(st, m, base, rt, true)
end

local frameNo = 0
-- (PERF AUDIT readout, 29 Oct, test only: script time of this loop per frame, the AI units' share, bone writes;
-- player attributes DbgNoAnim (skip the AI units' animation) / DbgNoBones (skip every bone write) to measure the
-- engine's side. Published once a second as AnimMs / AnimAiMs / AnimUnits / AnimBoneWrites)
local prof = { t = 0, ai = 0, n = 0, frames = 0, last = os.clock() }
RunService.RenderStepped:Connect(function()
	local pt0 = os.clock()
	frameNo += 1
	local noAnim = player:GetAttribute("DbgNoAnim")
	DBG_NOBONES = player:GetAttribute("DbgNoBones") == true
	DBG_NOPIVOT = player:GetAttribute("DbgNoPivot") == true
	DBG_NOGLOW = player:GetAttribute("DbgNoGlow") == true
	DBG_NORAY = player:GetAttribute("DbgNoRay") == true
	-- (test readout: the shared FX budget in use, for the audit's two-Colossi test)
	if frameNo % 15 == 0 and Attacks.budgetStats then
		local b = Attacks.budgetStats()
		player:SetAttribute("FxParticles", b.particles); player:SetAttribute("FxLights", b.lights); player:SetAttribute("FxFrags", b.frags)
		-- (test readout: live attack effects across AI units, current + detached)
		local n = 0
		for mm, s in tracked do
			if s.ai then
				local k, ids = #(s.fx or {}), {}
				for _, inst in s.detached or {} do k += #inst.fx; table.insert(ids, tostring(inst.id)) end
				n += k
				mm:SetAttribute("AiFx", k); mm:SetAttribute("AiDetIds", table.concat(ids, ","))   -- (per unit, for the probes)
			end
		end
		player:SetAttribute("AiLiveFx", n)
	end
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	for m, st in tracked do
		if not m.Parent then
			if st.fx then stopFx(st); st.ctx.holder:Destroy() end
			tracked[m] = nil; continue
		end
		if st.ai then                                       -- (AI TEST units follow the server, not a test loop)
			local c0 = os.clock()
			if not noAnim then aiFrame(st, m, now) end
			prof.ai += os.clock() - c0; prof.n += 1
			continue
		end
		local cx, cz, r = m:GetAttribute("CentreX"), m:GetAttribute("CentreZ"), m:GetAttribute("Radius")
		local speed, t0 = m:GetAttribute("Speed") or 16, m:GetAttribute("T0") or now
		if not (cx and cz and r) then continue end
		local s = math.max(0, now - t0) * speed * (st.gait.speedScale or 1) -- studs walked
		local a = s / r
		local pos = Vector3.new(cx + math.cos(a) * r, 0, cz + math.sin(a) * r)
		-- (far away: fewer updates; ChatGPT LOD: every frame near, every 2nd to 150 studs, every 6th beyond)
		local dist = cam and (cam.CFrame.Position - pos).Magnitude or 0
		local every = (dist > 150) and 6 or (dist > 80) and 2 or 1
		if (frameNo + st.frame) % every ~= 0 then continue end
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local y = groundY(pos.X, pos.Z, st.y)
		st.y = y
		-- (a planted-foot gait starts mid-stride: ik.start shifts its cycle, not the unit's path)
		local ik = st.gait.ik
		local sOff = ik and (ik.start or 0) * ik.stride or 0
		local phase = ((s + sOff) / st.gait.stride) % 1
		-- a START unit stands in its idle until T0, then walks; the first 0.25 s blend the idle pose into the walk
		-- (ChatGPT pilot audit r1: no hard pose snap)
		local idling = st.idleGait and now < t0
		local blendIdle = st.idleGait and not idling and now < t0 + 0.25
		local pose = newPose()
		if idling then st.idleGait.fn(now - st.born, pose)
		elseif st.gait.idle then st.gait.fn(now - t0, pose)
		else st.gait.fn(phase, pose, s + sOff) end
		if st.bones.Lid then pose.rot("Lid", LID_ANGLE * blinkAmount(st, os.clock())) end
		-- facing: forward (-Z) along the path; a sideways walker (the crab) faces out of the loop and steps along it
		local face = st.gait.sideways and Vector3.new(math.cos(a), 0, math.sin(a)) or tangent
		local base = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + face)
		m:PivotTo(base)
		local function at(u)
			local au = (u - sOff) / r
			local p = Vector3.new(cx + math.cos(au) * r, 0, cz + math.sin(au) * r)
			local g = Vector3.new(p.X, groundY(p.X, p.Z, y), p.Z)
			return CFrame.lookAt(g, g + Vector3.new(-math.sin(au), 0, math.cos(au)))
		end
		if st.attack then runAttack(st, base, at, now, t0); continue end
		-- (a form without planted feet: its gait's beats play its slap / stomp)
		if st.gait.beats and not st.gait.idle and not idling and speed > 0 then
			local lp = st.lastPhase
			if lp then
				for _, b in st.gait.beats do
					if (lp < b and phase >= b) or (phase < lp and (b > lp or b <= phase)) then beatFx(m, base) end
				end
			end
			st.lastPhase = phase
		end
		-- HURT (batch 1, MOVE TEST): an additive layer over the walk
		local ht, hsg = nil, 1
		if st.ctx then ht, hsg = hurtTick(st, base, now, t0); addHurt(st, pose, ht, hsg, 1) end
		local held
		if blendIdle then
			local ip = newPose()
			st.idleGait.fn(now - st.born, ip)
			apply(st, ip)
			if st.legs then solveLegs(st, base, sOff, at, true, now) end   -- (v5 Titan: a START form may have no legs)
			held = {}
			for name, e in st.bones do held[name] = e.b.Transform end
		end
		apply(st, pose)
		if st.legs then solveLegs(st, base, s + sOff, at, idling or st.gait.idle or speed <= 0, now) end
		if held then
			local wgt = smooth((now - t0) / 0.25)
			for name, e in st.bones do e.b.Transform = held[name]:Lerp(e.b.Transform, wgt) end
		end
		if st.legs then
			-- (the worst unreachable foothold so far, studs: > 0 means a planted foot slid; read by the test tools)
			if frameNo % 30 == 0 then m:SetAttribute("IKOver", st.over or 0); m:SetAttribute("IKOverQ", st.overQ or -1) end
			-- the glow: a pulse on each footfall (1.4 -> 2.0 -> 1.4 over 0.3 s) and the idle's breath
			if st.sa then
				local t = now - (st.pulseAt or -9)
				local pulse = (t < 0.08) and t / 0.08 or (t < 0.3) and 1 - (t - 0.08) / 0.22 or 0
				setGlow(st, st.glow * (pose.glowMul or 1) + 0.6 * pulse + pose.glow)
			end
		end
		if st.fx and #st.fx > 0 then                                -- (the hurt chips and sparks)
			for i = #st.fx, 1, -1 do
				local fx = st.fx[i]
				local pc0 = os.clock(); local ok, alive = pcall(fx.step, fx, now); PROF_FX += os.clock() - pc0
				if not ok or alive == false then pcall(fx.stop, fx); table.remove(st.fx, i) end
			end
		end
	end
	prof.t += os.clock() - pt0; prof.frames += 1
	if os.clock() - prof.last >= 1 then
		local f = math.max(prof.frames, 1)
		player:SetAttribute("AnimMs", prof.t / f * 1000); player:SetAttribute("AnimAiMs", prof.ai / f * 1000)
		player:SetAttribute("AnimUnits", prof.n / f); player:SetAttribute("AnimBoneWrites", BONE_WRITES / f)
		player:SetAttribute("AnimFps", f / (os.clock() - prof.last))
		player:SetAttribute("AnimEvMs", PROF_EV / f * 1000); player:SetAttribute("AnimFxMs", PROF_FX / f * 1000)
		prof.t, prof.ai, prof.n, prof.frames, prof.last, BONE_WRITES, PROF_EV, PROF_FX = 0, 0, 0, 0, os.clock(), 0, 0, 0
	end
end)

for _, m in units:GetChildren() do task.defer(setup, m) end
units.ChildAdded:Connect(function(m) task.wait(); if m:IsA("Model") then setup(m) end end)
units.ChildRemoved:Connect(function(m)
	local st = tracked[m]
	if st and st.fx then stopFx(st); st.ctx.holder:Destroy() end
	tracked[m] = nil
end)

-- ===== the MOVE TEST menu (James, 28 Oct: "droppable closable headings", "move around screen", one unit at a time) =====
-- A panel you drag by its title bar, a [-] to fold it to just the title, sections that open / close from their headings
-- (the newest batches open), and ONE AT A TIME: on, every spawn clears the units already out first.
local remote = AF:WaitForChild("WalkTest")
local UIS = game:GetService("UserInputService")
local gui = Instance.new("ScreenGui")
gui.Name = "WalkTestMenu"; gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local INK, MUTED, BAR = Color3.fromRGB(235, 240, 250), Color3.fromRGB(150, 220, 255), Color3.fromRGB(32, 36, 50)
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(220, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Position = UDim2.fromOffset(12, 80)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28); panel.BackgroundTransparency = 0.12
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local outer = Instance.new("UIListLayout", panel); outer.SortOrder = Enum.SortOrder.LayoutOrder

-- the title bar: drag it to move the panel; [-] folds the panel
local title = Instance.new("TextButton")
title.Size = UDim2.new(1, 0, 0, 44); title.LayoutOrder = 0; title.AutoButtonColor = false
title.BackgroundColor3 = BAR; title.Text = "   MOVE TEST"; title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold; title.TextSize = 14; title.TextColor3 = MUTED
title.Parent = panel
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)
local fold = Instance.new("TextButton")
fold.Size = UDim2.fromOffset(44, 40); fold.Position = UDim2.new(1, -48, 0, 2)   -- (thumb-sized: phones open it folded)
fold.BackgroundColor3 = Color3.fromRGB(55, 60, 80); fold.Text = "-"; fold.Font = Enum.Font.GothamBold; fold.TextSize = 16; fold.TextColor3 = INK
fold.Parent = title
Instance.new("UICorner", fold).CornerRadius = UDim.new(0, 5)
do
	local dragging, start, startPos
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, start, startPos = true, i.Position, panel.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			local vs = workspace.CurrentCamera.ViewportSize
			panel.Position = UDim2.fromOffset(math.clamp(startPos.X.Offset + d.X, 0, vs.X - 60), math.clamp(startPos.Y.Offset + d.Y, 0, vs.Y - 40))
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
end

-- the body scrolls when it is taller than the screen
local body = Instance.new("ScrollingFrame")
body.LayoutOrder = 1; body.BackgroundTransparency = 1; body.BorderSizePixel = 0
body.Size = UDim2.new(1, 0, 0, 0); body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new()
body.ScrollBarThickness = 4; body.ScrollingDirection = Enum.ScrollingDirection.Y
body.Parent = panel
local bpad = Instance.new("UIPadding", body)
bpad.PaddingTop, bpad.PaddingBottom, bpad.PaddingLeft, bpad.PaddingRight = UDim.new(0, 6), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 10)
local blist = Instance.new("UIListLayout", body); blist.Padding = UDim.new(0, 5); blist.SortOrder = Enum.SortOrder.LayoutOrder
-- (James's phone test, 29 Oct: "the menus are massive": smaller on a short screen; AbsoluteContentSize is on-screen
-- pixels, after the UIScale, Size is before it)
local mscale = Instance.new("UIScale", panel)
local function fit()                                             -- (as tall as its content, at most 75 % of the screen)
	local vs = workspace.CurrentCamera.ViewportSize
	if vs.Y >= 50 then mscale.Scale = math.clamp(vs.Y / 600, 0.8, 1) end
	local h = blist.AbsoluteContentSize.Y / mscale.Scale + 16
	body.Size = UDim2.new(1, 0, 0, math.min(h, math.max(0, math.min(vs.Y * 0.75, vs.Y - 100) / mscale.Scale - 44)))
end
blist:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
-- (29 Oct: at load the camera's ViewportSize can still be 1 x 1, so the body was sized 0 tall and never grew: the menu
-- "didn't open". Refit when the screen size is known / changes, and on every unfold)
local function watchCam()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	fit()
end
watchCam()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCam)
task.delay(1, fit)
fold.MouseButton1Click:Connect(function()
	body.Visible = not body.Visible
	fold.Text = body.Visible and "-" or "+"
	fit()
end)
-- (a touch screen opens it folded: it covered the left of a phone)
if UIS.TouchEnabled and not UIS.KeyboardEnabled then body.Visible = false; fold.Text = "+" end

local order = 0
local function button(parent, text, color, fn)
	order += 1
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28); b.LayoutOrder = order; b.AutoButtonColor = true
	b.BackgroundColor3 = color; b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.TextColor3 = Color3.new(1, 1, 1); b.Text = text
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(fn)
	return b
end
-- a section: a heading that opens / closes the buttons under it
local function section(name, open)
	order += 1
	local head = Instance.new("TextButton")
	head.Size = UDim2.new(1, 0, 0, 24); head.LayoutOrder = order; head.AutoButtonColor = true
	head.BackgroundColor3 = BAR; head.Font = Enum.Font.GothamBold; head.TextSize = 13; head.TextColor3 = MUTED
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Parent = body
	Instance.new("UICorner", head).CornerRadius = UDim.new(0, 5)
	order += 1
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 0); box.AutomaticSize = Enum.AutomaticSize.Y; box.LayoutOrder = order; box.BackgroundTransparency = 1
	box.Parent = body
	local l = Instance.new("UIListLayout", box); l.Padding = UDim.new(0, 4); l.SortOrder = Enum.SortOrder.LayoutOrder
	box.Visible = open and true or false
	local function show() head.Text = (box.Visible and "  v   " or "  >   ") .. name end
	show()
	head.MouseButton1Click:Connect(function() box.Visible = not box.Visible; show() end)
	return box
end

-- ONE AT A TIME (on by default): a spawn first clears every unit already out
local solo = true
local function send(...)
	if solo then remote:FireServer("stop") end
	remote:FireServer(...)
end
local mode = "walk"
local top = section("SETTINGS", true)
local modeBtn
-- WALK / RUN / IDLE / START: every walk button spawns its form in this mode
modeBtn = button(top, "MODE: WALK", Color3.fromRGB(70, 70, 90), function()
	mode = (mode == "walk") and "run" or (mode == "run") and "idle" or (mode == "idle") and "start" or "walk"
	modeBtn.Text = "MODE: " .. string.upper(mode)
	modeBtn.BackgroundColor3 = (mode == "run") and Color3.fromRGB(170, 60, 160) or (mode == "idle") and Color3.fromRGB(60, 120, 120) or Color3.fromRGB(70, 70, 90)
end)
local soloBtn
soloBtn = button(top, "ONE AT A TIME: ON", Color3.fromRGB(60, 110, 80), function()
	solo = not solo
	soloBtn.Text = "ONE AT A TIME: " .. (solo and "ON" or "OFF")
	soloBtn.BackgroundColor3 = solo and Color3.fromRGB(60, 110, 80) or Color3.fromRGB(80, 80, 90)
end)
button(top, "STOP ALL", Color3.fromRGB(150, 40, 40), function() remote:FireServer("stop") end)
-- SPEED (James, 31 Oct: "a speed toggle that goes up to a very very high speed"): each tap steps the player's walk
-- speed up, past the top it goes back to normal. Client-side WalkSpeed (the client moves its own character); kept
-- through respawns.
local SPEEDS = { 16, 32, 64, 128, 256, 500, 1000 }
local speedI = 1
local speedBtn
local function applySpeed()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = SPEEDS[speedI] end
end
speedBtn = button(top, "SPEED: NORMAL", Color3.fromRGB(70, 70, 90), function()
	speedI = speedI % #SPEEDS + 1
	speedBtn.Text = speedI == 1 and "SPEED: NORMAL" or ("SPEED: " .. SPEEDS[speedI])
	speedBtn.BackgroundColor3 = speedI == 1 and Color3.fromRGB(70, 70, 90)
		or Color3.fromRGB(200, math.floor(160 - 110 * (speedI - 2) / (#SPEEDS - 2)), 40)   -- yellow -> red as it climbs
	applySpeed()
end)
player.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid"); applySpeed() end)

-- PICKAXE (James, 1 Nov: "click any of the pickaxes to use and test"): puts that tier in your hand (MiningService's
-- TestPick, only while MiningConfig.TEST_PICKS is on); the one you hold is marked with a dot
do
	local pickBox = section("PICKAXE", true)
	local TIERS = {
		{ "T1 STARTER", Color3.fromRGB(110, 105, 125) }, { "T2 IRON", Color3.fromRGB(120, 125, 140) },
		{ "T3 LUNAR", Color3.fromRGB(40, 140, 190) }, { "T4 CRYSTAL", Color3.fromRGB(205, 130, 30) },
		{ "T5 COSMIC", Color3.fromRGB(130, 60, 210) },
	}
	local pickBtns = {}
	local function mark()
		local held = player:GetAttribute("PickTier") or 1
		for t, b in pickBtns do b.Text = (t == held and "●  " or "") .. TIERS[t][1] end
	end
	for t, e in TIERS do
		pickBtns[t] = button(pickBox, e[1], e[2], function()
			local r = AF:FindFirstChild("MiningRemotes") and AF.MiningRemotes:FindFirstChild("TestPick")
			if r then r:FireServer(t) end
		end)
	end
	player:GetAttributeChangedSignal("PickTier"):Connect(mark)
	mark()
end

local BLUE, ORANGE, TEAL = Color3.fromRGB(30, 110, 200), Color3.fromRGB(200, 110, 30), Color3.fromRGB(30, 150, 140)
-- the attack batches (newest open); each button stands that form in front of you doing the move on repeat
local function batch(name, form, color, moves, hurtLabel, open)
	local box = section(name, open)
	for _, e in moves do button(box, e[2], color, function() send("attack", form, e[1]) end) end
	button(box, hurtLabel, color, function() send("hurt", form) end)
	return box
end
-- (batch 4: CLING and BOING BOMBS bring a Brute stand-in to stick to; 6 DRIPS = the GOOED test)
-- PHONE TEST: an army on screen at once + a frame-time readout (top centre: top right sat under the AI TEST menu on
-- James's phone, 29 Oct; tap it to hide)
local fpsLabel = Instance.new("TextButton")
fpsLabel.Name = "FpsLabel"                                       -- (the AI TEST menu's SHOW FPS finds it by name)
fpsLabel.Size = UDim2.fromOffset(250, 46); fpsLabel.AnchorPoint = Vector2.new(0.5, 0); fpsLabel.Position = UDim2.new(0.5, 0, 0, 4)
fpsLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 28); fpsLabel.BackgroundTransparency = 0.15; fpsLabel.AutoButtonColor = false
fpsLabel.Font = Enum.Font.GothamBold; fpsLabel.TextSize = 15; fpsLabel.TextColor3 = INK; fpsLabel.Visible = false
fpsLabel.Parent = gui
Instance.new("UICorner", fpsLabel).CornerRadius = UDim.new(0, 8)
fpsLabel.MouseButton1Click:Connect(function() fpsLabel.Visible = false end)
do
	local dts, acc = {}, 0
	RunService.RenderStepped:Connect(function(dt)
		if not fpsLabel.Visible then return end
		table.insert(dts, dt); acc += dt
		if acc < 1 then return end                                   -- (one reading a second: average FPS + the worst frame)
		local worst, sum = 0, 0
		for _, x in dts do sum += x; worst = math.max(worst, x) end
		local fps = #dts / sum
		local n = 0
		local uf = workspace:FindFirstChild("Units")
		for _, u in (uf and uf:GetChildren() or {}) do if u:GetAttribute("Owner") == player.UserId or u:GetAttribute("Mode") == "ai" then n += 1 end end
		fpsLabel.Text = string.format("FPS %d   worst frame %d ms\n%d aliens", math.floor(fps + 0.5), math.floor(worst * 1000 + 0.5), n)
		fpsLabel.TextColor3 = (fps >= 55) and Color3.fromRGB(120, 235, 140) or (fps >= 30) and Color3.fromRGB(250, 210, 90) or Color3.fromRGB(255, 110, 100)
		table.clear(dts); acc = 0
	end)
end
local phone = section("PHONE TEST", true)
for _, n in { 12, 24, 48 } do
	button(phone, n .. " ALIENS FIGHTING", Color3.fromRGB(150, 90, 40), function()
		remote:FireServer("stress", n)
		fpsLabel.Text = "FPS ...\n" .. n .. " aliens"; fpsLabel.TextColor3 = INK; fpsLabel.Visible = true
	end)
end
button(phone, "SHOW / HIDE FPS", Color3.fromRGB(80, 80, 95), function() fpsLabel.Visible = not fpsLabel.Visible end)
-- (batches 5-7: the magma forms)
local ORANGE5 = Color3.fromRGB(200, 100, 30)
local pebbleBox = batch("PEBBLE (BATCH 5)", "CrunchF1v5", ORANGE5,
	{ { "Chip", "CHIP (ON A BRUTE)" }, { "Curl", "CURL UP" }, { "Roll", "ROLL OUT (ON A BRUTE)" }, { "Defeat", "DEFEAT" } }, "HURT (SKITTERING)", true)
for _, t in { { "SquishF4v5", "6 PEBBLES ON A TITAN" }, { "CrunchF3v5", "6 PEBBLES ON A RAM" }, { "CrunchF4", "6 PEBBLES ON A COLOSSUS" } } do
	button(pebbleBox, t[2], ORANGE5, function() remote:FireServer("pebbleon", t[1], "Chip", 6) end)
end
batch("PINCER (BATCH 6)", "CrunchF2v5", ORANGE5,
	{ { "Snap", "SCISSOR SNAP" }, { "Block", "CLAW BLOCK" }, { "Sweep", "SIDE SWEEP" }, { "Defeat", "DEFEAT" } }, "HURT (SCUTTLING)", false)
batch("RAM (BATCH 7)", "CrunchF3v5", ORANGE5,
	{ { "Gore", "HORN GORE" }, { "Stamp", "HOOF STAMP" }, { "Charge", "RAM CHARGE (AIMED)" }, { "Defeat", "DEFEAT" } }, "HURT (TROTTING)", false)
local dripBox = batch("DRIP (BATCH 4)", "SquishF1v5", Color3.fromRGB(35, 150, 230),
	{ { "Cling", "CLING + BITE (ON A BRUTE)" }, { "Boing", "BOING ESCAPE (AIMED)" }, { "Squash", "BOING FAILED (PANCAKE)" }, { "Bombs", "BOING BOMBS (ON A BRUTE)" }, { "Defeat", "DEFEAT" } }, "HURT (HOPPING)", false)
button(dripBox, "6 DRIPS CLING (GOOED)", Color3.fromRGB(35, 150, 230), function() remote:FireServer("swarm", "SquishF1v5", "Cling") end)
-- (6 Drips clinging to each big form in turn: the stick-to-anything check)
for _, t in { { "SquishF4v5", "6 DRIPS ON A TITAN" }, { "CrunchF3v5", "6 DRIPS ON A RAM" }, { "CrunchF4", "6 DRIPS ON A COLOSSUS" } } do
	button(dripBox, t[2], Color3.fromRGB(35, 150, 230), function() remote:FireServer("dripon", t[1], "Cling", 6) end)
end
batch("BRUTE (BATCH 3)", "SquishF3v5", Color3.fromRGB(45, 70, 170),
	{ { "Pound", "KNUCKLE POUND" }, { "Grab", "STRETCH GRAB (AIMED)" }, { "Thump", "CHEST THUMP" }, { "Defeat", "DEFEAT" } }, "HURT (WALKING)", false)
batch("TWIN (BATCH 3)", "SquishF2v5", Color3.fromRGB(40, 110, 200),
	{ { "Slap", "DOUBLE SLAP" }, { "Sticky", "STICKY FLOOR" }, { "Boing", "BOING SLAM (AIMED)" }, { "Defeat", "DEFEAT" } }, "HURT (HOPPING)", false)
batch("TITAN (BATCH 2)", "SquishF4v5", Color3.fromRGB(25, 130, 160),
	{ { "Slam", "TENTACLE SLAM" }, { "Bomb", "GOO BOMB (AIMED)" }, { "Wave", "GOO TSUNAMI" }, { "Defeat", "DEFEAT" } }, "HURT (SLIDING)", false)
-- (batch 1: the sun and the boulder aim at a new blue post each repeat)
batch("COLOSSUS (BATCH 1)", "CrunchF4", Color3.fromRGB(170, 60, 40),
	{ { "Slam", "SMASH THE GROUND" }, { "Sun", "SUN BEAM (AIMED)" }, { "Boulder", "THROW A BOULDER (AIMED)" }, { "Defeat", "DEFEAT" } }, "HURT (WALKING)", false)
-- walking: the v5 rebuilds (28 Oct) and the forms they will replace
local v5 = section("WALK: v5 MODELS", false)
for _, e in { { "SquishF1v5", "1 DRIP v5" }, { "SquishF2v5", "2 TWIN v5" }, { "SquishF3v5", "3 BRUTE v5" }, { "SquishF4v5", "4 TITAN v5" },
	{ "CrunchF1v5", "1 PEBBLE v5" }, { "CrunchF2v5", "2 PINCER v5" }, { "CrunchF3v5", "3 RAM v5" } } do
	button(v5, e[2], TEAL, function() send("walk", e[1], mode) end)
end
local old = section("WALK: OLD MODELS", false)
for _, e in { { "SquishF1", "1 DRIP", BLUE }, { "SquishF2", "2 TWIN", BLUE }, { "SquishF3", "3 BRUTE", BLUE }, { "SquishF4", "4 TITAN", BLUE },
	{ "CrunchF1", "1 PEBBLE", ORANGE }, { "CrunchF2", "2 PINCER", ORANGE }, { "CrunchF3", "3 RAM", ORANGE }, { "CrunchF4", "4 COLOSSUS", ORANGE } } do
	button(old, e[2], e[3], function() send("walk", e[1], mode) end)
end
button(old, "ALL 8", Color3.fromRGB(60, 140, 70), function() remote:FireServer("all", nil, mode) end)
fit()
