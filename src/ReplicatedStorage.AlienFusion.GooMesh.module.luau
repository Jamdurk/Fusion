-- Alien Fusion: GOO MESHES for attack effects (batch 3, 28 Oct; James: the Titan's sphere-lobe wave "looks very Robloxy",
-- so every effect is built to match its reference sheet: design/concepts/<creature>/attacks/K-effects-chatgpt.png).
-- Real meshes made in code with EditableMesh (no uploads, tuned live): a rimmed PUDDLE, a splash CROWN, a teardrop DROP,
-- a SHOCK RING, a jelly SHELL (the shield) and a lumpy PIN blob. Each wears the SQUISH aliens' own goo skin (the Twin's
-- SurfaceAppearance, mapped onto a patch of its texture that is pure puddle goo), so effects and bodies are one material.
-- Built once per shape (unit size), then cloned; size them with MeshPart.Size.
local AssetService = game:GetService("AssetService")
local AF = game:GetService("ReplicatedStorage"):WaitForChild("AlienFusion")

local M = {}
local sin, cos, pi = math.sin, math.cos, math.pi
local TAU = 2 * pi

-- (the Twin's texture: a patch of blue-cyan goo with bright cracks, picked from an 8 x 8 sweep of its UV layout in
-- Studio: no eye, teeth, horn or violet core in it)
M.PATCH = { 0.89, 0.985, 0.39, 0.485 }   -- (u0, u1, v0, v1)
local function uvAt(a, b) local P = M.PATCH; return Vector2.new(P[1] + (P[2] - P[1]) * (a % 1), P[3] + (P[4] - P[3]) * (b % 1)) end

-- a mesh builder: grids of vertices joined into quads; normals are smooth (averaged per vertex)
local function newBuilder()
	local B = { pos = {}, uv = {}, tris = {} }
	function B.v(p, uv) table.insert(B.pos, p); table.insert(B.uv, uv); return #B.pos end
	function B.t(a, b, c) table.insert(B.tris, { a, c, b }) end   -- (Roblox's front face winds the other way: measured)
	function B.q(a, b, c, d) B.t(a, b, c); B.t(a, c, d) end
	-- rows of vertices (each a closed loop of n) joined: rows[k][i]
	function B.loft(rows, closed)
		for k = 1, #rows - 1 do
			local r0, r1 = rows[k], rows[k + 1]
			local n = #r0
			for i = 1, (closed and n or n - 1) do
				local j = i % n + 1
				B.q(r0[i], r0[j], r1[j], r1[i])
			end
		end
	end
	function B.build()
		local em = AssetService:CreateEditableMesh({})
		local nrm = table.create(#B.pos, Vector3.zero)
		for _, t in B.tris do
			local a, b, c = B.pos[t[1]], B.pos[t[2]], B.pos[t[3]]
			local n = (b - a):Cross(c - a)
			for _, i in t do nrm[i] += n end
		end
		local vid, uid, nid = {}, {}, {}
		for i, p in B.pos do
			vid[i] = em:AddVertex(p)
			uid[i] = em:AddUV(B.uv[i])
			local n = nrm[i]
			nid[i] = em:AddNormal(n.Magnitude > 1e-6 and n.Unit or Vector3.yAxis)
		end
		for _, t in B.tris do
			local f = em:AddTriangle(vid[t[1]], vid[t[2]], vid[t[3]])
			em:SetFaceUVs(f, { uid[t[1]], uid[t[2]], uid[t[3]] })
			em:SetFaceNormals(f, { nid[t[1]], nid[t[2]], nid[t[3]] })
		end
		-- (thin goo sheets are seen from both sides: a splash wall, a ring, the shield's rim)
		if B.double then
			local back = {}
			for i, n in nrm do back[i] = em:AddNormal(n.Magnitude > 1e-6 and -n.Unit or -Vector3.yAxis) end
			for _, t in B.tris do
				local f = em:AddTriangle(vid[t[1]], vid[t[3]], vid[t[2]])
				em:SetFaceUVs(f, { uid[t[1]], uid[t[3]], uid[t[2]] })
				em:SetFaceNormals(f, { back[t[1]], back[t[3]], back[t[2]] })
			end
		end
		return em
	end
	return B
end

-- a lathe: profile points { r, y } swept round n times; rOf(theta) scales the radius (a wavy outline)
local function lathe(B, prof, n, rOf, cx, cz)
	local rows = {}
	for k, pr in prof do
		local row = {}
		for i = 1, n do
			local a = (i - 1) / n * TAU
			local s = rOf and rOf(a, k / #prof) or 1
			row[i] = B.v(Vector3.new((cx or 0) + cos(a) * pr[1] * s, pr[2], (cz or 0) + sin(a) * pr[1] * s), uvAt((i - 1) / n, k / #prof))
		end
		rows[k] = row
	end
	B.loft(rows, true)
	return rows
end
-- close a lathe's first row to a point (a cap)
local function cap(B, row, p, flip)
	local c = B.v(p, uvAt(0.5, 0.5))
	for i = 1, #row do local j = i % #row + 1; if flip then B.t(c, row[i], row[j]) else B.t(c, row[j], row[i]) end end
end

-- ===== the shapes (unit size: about 2 studs across, 1 tall) =====
local SHAPES = {}

-- PUDDLE (sheet cells 2 STICKY FLOOR / 6 MOTES / the melt): a glossy flat pool, a raised rounded rim, a wavy outline
function SHAPES.puddle(seed)
	local B = newBuilder()
	local function wavy(a) return 1 + 0.07 * sin(5 * a + seed) + 0.05 * sin(9 * a + 2 * seed) + 0.025 * sin(14 * a + 3 * seed) end
	-- (centre to edge: a low dome, a dip, the raised rim, then the rounded lip down to the ground)
	-- (listed from the lip inward: a lathe's faces point up when its profile runs inward or upward)
	local prof = { { 0.99, 0.0 }, { 1.0, 0.07 }, { 0.98, 0.14 }, { 0.92, 0.18 }, { 0.84, 0.16 }, { 0.74, 0.10 }, { 0.55, 0.08 }, { 0.3, 0.09 }, { 0.05, 0.10 } }
	local rows = lathe(B, prof, 36, function(a) return wavy(a) end)
	cap(B, rows[#rows], Vector3.new(0, 0.10, 0), false)
	return B.build()
end

-- CROWN (cells 1 SLAP SPLAT / 3 BELLY-FLOP / Brute 1 POUND SPLASH): a splash crown,
-- each peak ending in a round droplet bulb. Like the sheet: ONE sheet of goo rising from a thick base into uneven
-- points (not separate sticks), flaring out as it rises
function SHAPES.crown(seed, nSpikes)
	local B = newBuilder()
	B.double = true
	nSpikes = nSpikes or 9
	local peaks = {}
	for i = 1, nSpikes do
		peaks[i] = { a = (i - 1 + 0.35 * sin(i * 3.1 + seed)) / nSpikes * TAU, h = 0.55 + 0.45 * (0.5 + 0.5 * sin(i * 2.3 + seed)) }
	end
	-- the sheet's height round the ring: a low wall with sharp peaks (each peak ~1/3 of the gap wide at its base)
	local W = TAU / nSpikes * 0.33
	local function height(a)
		local h = 0.22
		for _, p in peaks do
			local d = math.abs(((a - p.a + pi) % TAU) - pi)
			if d < W then h = math.max(h, 0.22 + (p.h - 0.22) * (1 - d / W) ^ 1.7) end
		end
		return h
	end
	local N, K = 60, 6
	local rows = {}
	for k = 0, K do
		local f = k / K                                            -- (0 at the ground .. 1 at the top edge)
		local row = {}
		for i = 1, N do
			local a = (i - 1) / N * TAU
			local h = height(a)
			local y = f * h
			local r = 0.62 + 0.12 * f + 0.25 * (f * f) * (h - 0.22) / 0.78 -- (flares out; the peaks lean out most)
			r *= 1 + 0.05 * sin(7 * a + seed)
			-- (thick at the base, thinning to the edge: the inner face is a little lower, read as one rolled lip)
			row[i] = B.v(Vector3.new(cos(a) * r, y, sin(a) * r), uvAt((i - 1) / N, f))
		end
		rows[k + 1] = row
	end
	B.loft(rows, true)
	-- a round bulb on each peak (the droplet about to fly off)
	for i, p in peaks do
		local r = (0.62 + 0.12 + 0.25 * (p.h - 0.22) / 0.78) * (1 + 0.05 * sin(7 * p.a + seed))
		local tip = Vector3.new(cos(p.a) * r, p.h + 0.04, sin(p.a) * r)
		local br = 0.06 + 0.035 * (0.5 + 0.5 * sin(i * 4.1 + seed))
		local bulb = {}
		for k = 1, 4 do
			local ph = (k - 1) / 3 * pi
			local row = {}
			for j = 1, 5 do
				local t = (j - 1) / 5 * TAU
				row[j] = B.v(tip + Vector3.new(cos(t) * sin(ph), cos(ph), sin(t) * sin(ph)) * br, uvAt(j / 5, k / 4))
			end
			bulb[k] = row
		end
		B.loft(bulb, true)
	end
	return B.build()
end

-- DROP (cell 5 GOO DROPLETS): a teardrop, round end down, tail up (+Y); orient it along its velocity
function SHAPES.drop()
	local B = newBuilder()
	local prof = {}
	for k = 0, 10 do
		local t = k / 10                                          -- (0 bottom .. 1 tail tip)
		local y = -0.5 + 1.3 * t
		local r = (t < 0.45) and 0.5 * sin(pi * (0.5 * t / 0.45 + 0.0) ) or 0.5 * (1 - (t - 0.45) / 0.55) ^ 1.6 * 0.98
		if k == 0 then r = 0.02 end
		table.insert(prof, { math.max(r, 0.015), y })
	end
	local rows = lathe(B, prof, 12)
	cap(B, rows[1], Vector3.new(0, -0.5, 0), true)
	cap(B, rows[#rows], Vector3.new(0, 0.8, 0), false)
	return B.build()
end

-- RING (cell 4 GOO SHOCK RING): a low rolling goo torus, thicker on its outer side, a wavy outline
function SHAPES.ring(seed)
	local B = newBuilder()
	B.double = true
	local N, S = 32, 6
	local rows = {}
	for i = 1, N do
		local a = (i - 1) / N * TAU
		local R = 1 + 0.04 * sin(6 * a + seed)
		local row = {}
		for j = 1, S do
			local t = (j - 1) / S * TAU
			local rr = 0.12 * (1 + 0.25 * cos(t)) * (1 + 0.15 * sin(9 * a + seed))
			local p = Vector3.new(cos(a) * (R + cos(t) * rr), math.max(0, sin(t) * rr * 0.8 + 0.05), sin(a) * (R + cos(t) * rr))
			row[j] = B.v(p, uvAt(i / N, j / S))
		end
		rows[i] = row
	end
	-- (loft across the ring: each tube cross-section joined to the next)
	for i = 1, N do
		local r0, r1 = rows[i], rows[i % N + 1]
		for j = 1, S do local k = j % S + 1; B.q(r0[j], r1[j], r1[k], r0[k]) end
	end
	return B.build()
end

-- SHELL (Brute cell 4 GOO SHIELD): a jelly dome, a wobbly surface, a thick rounded rim where it meets the ground
function SHAPES.shell(seed)
	local B = newBuilder()
	local prof = {}
	-- (outside surface from the rim up to the top, then a thin inside going back down: a shell, not a solid)
	for k = 0, 7 do local ph = k / 7 * (pi / 2); table.insert(prof, { cos(ph) * 1.0, sin(ph) * 1.0 }) end
	local outer = lathe(B, prof, 28, function(a, f) return 1 + 0.035 * sin(5 * a + seed + f * 3) * (1 - f) + 0.02 * sin(11 * a + seed) end)
	cap(B, outer[#outer], Vector3.new(0, 1.0, 0), false)
	-- the thick base rim: a fat torus round the bottom edge
	local N, S = 28, 6
	local rows = {}
	for i = 1, N do
		local a = (i - 1) / N * TAU
		local row = {}
		for j = 1, S do
			local t = (j - 1) / S * TAU
			local rr = 0.09 * (1 + 0.3 * sin(7 * a + seed))
			row[j] = B.v(Vector3.new(cos(a) * (1 + cos(t) * rr), math.max(0, 0.06 + sin(t) * rr), sin(a) * (1 + cos(t) * rr)), uvAt(i / N, j / S))
		end
		rows[i] = row
	end
	for i = 1, N do
		local r0, r1 = rows[i], rows[i % N + 1]
		for j = 1, S do local k = j % S + 1; B.q(r0[j], r1[j], r1[k], r0[k]) end
	end
	return B.build()
end

-- LUMP (Brute cell 3 GOO PIN): a lumpy glossy blob dome (bubbles on it) on a short skirt
function SHAPES.lump(seed)
	local B = newBuilder()
	local prof = {}
	for k = 0, 7 do local ph = k / 7 * (pi / 2); table.insert(prof, { 0.02 + cos(ph) * 1.0, sin(ph) * 0.8 }) end
	local rows = lathe(B, prof, 24, function(a, f)
		return 1 + 0.12 * sin(4 * a + seed) * sin(f * pi) + 0.08 * sin(7 * a + 2 * seed + f * 4) + 0.05 * sin(13 * a + f * 7)
	end)
	cap(B, rows[#rows], Vector3.new(0, 0.8, 0), false)
	return B.build()
end

-- ===== templates + skin =====
local cache = {}
function M.clearCache() table.clear(cache) end
local skin
local function gooSkin()
	if skin ~= nil then return skin or nil end
	local fx = AF:FindFirstChild("FX")
	local sa = fx and fx:FindFirstChild("GooSkin")
	skin = sa or false
	return sa
end
-- (a FIXED shared set (baked: FX.GooMeshes; batch 3 r1 added pool, shield, rope, ropeS, palm, ripple, mound, pin): the client's EditableMesh memory budget held only ~8 of the first versions;
-- a phone's may be smaller. Seeds fold into 2 variants; a crown is small (<= 8 peaks: 7) or big (11))
local VARIANTS = { puddle = 2, lump = 2, crown = 1, ring = 1, drop = 1, shell = 1, splat = 2 }   -- (splat: seed 0 -> splat1 flat, 1 -> splat2 rounded)
-- a MeshPart of shape `kind` (variant `seed`), unit size, anchored, no collisions; nil if neither a baked mesh nor
-- EditableMesh is available. A baked MeshPart in FX.GooMeshes named "<kind><variant>" (e.g. "crown11", "puddle2") wins:
-- before release these shapes get baked into real mesh assets (no runtime budget at all) with no code change
function M.template(kind, seed, extra)
	seed = ((seed or 0) % (VARIANTS[kind] or 1)) + 1
	if kind == "crown" then extra = ((extra or 9) <= 6) and 6 or ((extra or 9) <= 8) and 7 or 11 else extra = nil end
	local key = kind .. ":" .. tostring(seed) .. ":" .. tostring(extra or "")
	if cache[key] ~= nil then return cache[key] or nil end
	local fx = AF:FindFirstChild("FX")
	local baked = fx and fx:FindFirstChild("GooMeshes") and fx.GooMeshes:FindFirstChild(kind .. ((kind == "crown") and extra or seed))
	if baked then cache[key] = baked; return baked end
	local ok, mp = pcall(function()
		local em = SHAPES[kind](seed, extra)
		if not em then error("EditableMesh budget full") end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(70, 200, 255)
		local sa = gooSkin()
		if sa then sa:Clone().Parent = part end
		return part
	end)
	if not ok then warn("GooMesh", kind, mp) end
	cache[key] = ok and mp or false
	return ok and mp or nil
end
-- a fresh copy, sized and placed (size = full extent in studs), parented to `parent`
function M.make(kind, seed, size: Vector3, cf: CFrame, parent, extra)
	local t = M.template(kind, seed, extra)
	if not t then return nil end
	local p = t:Clone()
	p.Size, p.CFrame = size, cf
	p.Parent = parent
	return p
end
M.SHAPES = SHAPES
return M
