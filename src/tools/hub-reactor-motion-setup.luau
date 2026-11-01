-- Alien Fusion: write the reactor's rest poses (RestCF attribute) for the client ReactorMotion controller and install
-- the controller (31 Oct 2026). Run in Edit: loadstring(setupSrc)(controllerSource). Re-runnable: a part that already
-- has RestCF keeps it (so re-running after the controller moved things in Play can't bake a moved pose).
local controllerSource = ...
local L = workspace.Hub.CraterLandmark
local n = 0
local function mark(p)
	if p:IsA("BasePart") and not p:GetAttribute("RestCF") then p:SetAttribute("RestCF", p.CFrame); n += 1 end
end
for _, m in { L.Ring, L.Halo, L.FloatingRocks } do for _, p in m:GetChildren() do mark(p) end end
for _, nm in { "crCore", "crCoreLattice", "crCoreHeart" } do mark(L.Shell[nm]) end
-- the colours the owner tint returns to (only written once: a re-run never captures a tinted colour). Values = the
-- landmark as built (30 Oct), restored by hand 31 Oct after a preview baked a test colour in.
local REST = { crCore = { 96, 40, 170 }, crCoreHeart = { 255, 120, 240 }, crCoreLattice = { 255, 150, 255 }, crShellSeams = { 40, 170, 225 },
	crOrb = { 30, 110, 210 }, crOrbHeart = { 120, 220, 255 }, crOrbLattice = { 170, 240, 255 }, crRingStrips = { 60, 205, 255 }, crHalo = { 55, 150, 180 } }
for _, m in { L.Shell, L.Ring, L.Halo } do
	for _, p in m:GetChildren() do
		local c = REST[p.Name]
		if c and p:IsA("BasePart") and not p:GetAttribute("RestColor") then p:SetAttribute("RestColor", Color3.fromRGB(c[1], c[2], c[3])) end
	end
end
-- the 3 beams: a band texture (assets\textures\reactor-beam-flow.png, uploaded as below) flowing core -> ring, violet at
-- the core fading to cyan at the ring, a little wider (ChatGPT r1: "the beams are thin"); the controller breathes them
for _, b in L.BeamAnchor:GetChildren() do
	if b:IsA("Beam") then
		local up = b.Attachment1.WorldPosition.Y > b.Attachment0.WorldPosition.Y
		b.Texture = "rbxassetid://80886891608954"
		b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 16
		b.TextureSpeed = up and 0.45 or -0.45                     -- + scrolls Attachment0 -> Attachment1
		local c0, c1 = Color3.fromHex("B86BFF"), Color3.fromHex("56DDF2")
		if not up then c0, c1 = c1, c0 end
		b.Color = ColorSequence.new(c0, c1); b.LightEmission = 1; b.Width0, b.Width1 = 3.6, 2.6; b.FaceCamera = true
	end
end
local sps = game.StarterPlayer.StarterPlayerScripts
local s = sps:FindFirstChild("ReactorMotion") or Instance.new("LocalScript")
s.Name = "ReactorMotion"
if controllerSource then s.Source = controllerSource end
s.Parent = sps
return string.format("RestCF written on %d parts; ReactorMotion installed (%d chars)", n, #s.Source)
