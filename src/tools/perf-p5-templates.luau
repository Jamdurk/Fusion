-- Perf P5 (29 Oct): the alien templates in ServerStorage.Aliens.Forms are moved every frame, so keep them out of the
-- physics engine. Visible mesh: no collide / touch / query. Hitbox: no collide / touch / query / shadow (nothing queries
-- it: checked every script 29 Oct; the Drip's own ray turns its target mesh's CanQuery on locally). Shadows off on the
-- small forms (F1 / F2); F3 / F4 keep them (they read better grounded).
-- The meshes KEEP their collision shape (ChatGPT build audit r1: the Drip's surface rays hit the mesh, a Box would put
-- a clinging Drip on an invisible box): PreciseConvexDecomposition on CrunchF4, CrunchF3v5, SquishF3v5, SquishF4v5,
-- Default on the rest (as authored).
-- Before (29 Oct): Hitbox collide + query on everywhere, + touch + shadow on the v5s; SquishF1v5 / F2v5 mesh collide /
-- query / touch on. Run in Edit (command bar / MCP).
local forms = game:GetService("ServerStorage").Aliens.Forms
local PRECISE = { CrunchF4 = true, CrunchF3v5 = true, SquishF3v5 = true, SquishF4v5 = true }
local n = 0
for _, m in forms:GetChildren() do
	local small = m.Name:match("F[12]") ~= nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			if d.Name == "Hitbox" then
				d.CastShadow = false
			else
				if d:IsA("MeshPart") then
					d.CollisionFidelity = PRECISE[m.Name] and Enum.CollisionFidelity.PreciseConvexDecomposition or Enum.CollisionFidelity.Default
				end
				d.CastShadow = not small
			end
			n += 1
		end
	end
end
return "P5 applied to " .. n .. " parts"
