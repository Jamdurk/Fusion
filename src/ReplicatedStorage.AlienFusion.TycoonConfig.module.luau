-- Alien Fusion tycoon numbers (slice 1, 1 Nov 2026). Plan: design\25-TYCOON-PLAN.md (ChatGPT TYCOON SPEC r2 GO).
-- Looks: design\concepts\tycoon\tycoon-slice1-refs.png. Positions are plot-local (x -47.5..47.5, z -42.5 front .. 42.5
-- back; walkway x -7..7 kept clear). Session-only: nothing is saved yet (slice 2).
local C = {}

C.PLOT = 1
C.STARTER_GOO = 12 -- one starter Squish egg, given once per session

-- buy order: the Drill is the green NEXT pad from the start; the Incubator pad is locked until the Drill is bought
C.Machines = {
	Drill = { label = "ROCK DRILL", price = 20, centre = Vector2.new(25, -4), pad = Vector2.new(14, -4), order = 1 },
	Incubator = { label = "INCUBATOR", price = 30, centre = Vector2.new(-25, -8), pad = Vector2.new(-12, -8), order = 2,
		needs = "Drill" },
}
C.DRILL_PER_MIN = 8 -- +1 Moon Rock every 7.5 s to the plot owner

-- one incubator, two chambers, each with its own REPEAT (keeps hatching while you're out mining)
C.Eggs = {
	Squish = { res = "GooDNA", cost = 12, time = 12, form = "SquishF1v5", race = "squish", alien = "DRIP",
		color = Color3.fromRGB(70, 235, 225), resLabel = "GOO DNA" },
	Crunch = { res = "CrystalDNA", cost = 12, time = 12, form = "CrunchF1v5", race = "crunch", alien = "PEBBLE",
		color = Color3.fromRGB(255, 176, 64), resLabel = "CRYSTAL DNA" },
}

-- rolled LOOK (design 21: rarity = looks only, never stats). Your first hatch is always Glowing.
C.FIRST_LOOK = "Glowing"
C.Looks = {
	{ name = "Normal", chance = 89.38 },
	{ name = "Glowing", chance = 8, fill = nil, glow = true },
	{ name = "Crystal", chance = 2, fill = Color3.fromRGB(190, 240, 255), rare = true },
	{ name = "Shadow", chance = 0.5, fill = Color3.fromRGB(20, 12, 34), rare = true },
	{ name = "Rainbow", chance = 0.1, fill = Color3.fromRGB(255, 80, 200), rare = true, rainbow = true },
	{ name = "Cosmic", chance = 0.02, fill = Color3.fromRGB(120, 60, 255), rare = true },
}

C.CELEBRATE_TIME = 3 -- the new alien stands + celebrates at the incubator, then joins the army ring
C.ARMY_RING = { centre = Vector2.new(0, -35), radius = 7.5, speed = 5, slots = 8 } -- walks round the Launch Pad
C.CARD_TIME = 2.5

return C
