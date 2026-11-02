-- Mining numbers (ChatGPT mining spec r2 + feel r3: tap = one swing, hold = keep swinging, 0.45 s swings, HP x1.5;
-- design\economy\mining-spec-r2.txt + mining-feel-r1.txt, 1 Nov 2026). Starting values: tune from
-- measured Studio runs, not by feel. Better picks break deposits faster; plot upgrades (Dense Rock) raise how much you can
-- mine in a minute. A T5 pick on an unchanged plot stays at the same respawn ceiling.
local C = {}

C.TAG = "MineNode" -- CollectionService tag on every deposit Model (needs a MineHitbox part + NodeType attribute)

C.RANGE = 12 -- studs to the closest point of the deposit's hitbox SURFACE
C.RANGE_SLACK = 2 -- server allowance for lag
C.SWING_INTERVAL = 0.45 -- one swing per tap / click; holding repeats at this rate (every pick)
C.IMPACT_AT = 0.12 -- the pick hits this long into the swing (client shows it at once, the server counts it on arrival)
C.SWING_SLACK = 0.25 -- server lets a swing arrive this early (network jitter) without raising the long-run rate
C.BUFFER = 1 -- taps during a swing: at most one waits for the next
C.DRAG_CANCEL = 24 -- a held finger that moves this many pixels is a camera drag, not mining
C.HP_FORGET = 15 -- a half-mined deposit heals after this long untouched
C.MAX_REQUESTS_PER_SEC = 10
C.WALK_TO_MAX = 90 -- tapping a deposit this close walks you to it
C.HINT_RANGE = 14 -- TAP TO MINE shows on the nearest deposit inside this

C.Resources = {
	Rock = { label = "MOON ROCK", color = Color3.fromRGB(196, 190, 214) },
	GooDNA = { label = "GOO DNA", color = Color3.fromRGB(70, 235, 225) },
	CrystalDNA = { label = "CRYSTAL DNA", color = Color3.fromRGB(255, 176, 64) },
}

C.TEST_PICKS = true -- MOVE TEST menu can hand you any pick; TURN OFF before launch

C.Picks = {
	{ name = "Starter Pick", damage = 1 },
	{ name = "Iron Pick", damage = 2 },
	{ name = "Lunar Pick", damage = 3 },
	{ name = "Crystal Pick", damage = 4 },
	{ name = "Cosmic Pick", damage = 6 },
}

-- landmark = the finished vein props: they go dark for you instead of vanishing
C.Nodes = {
	SmallRock = { hp = 8, reward = { Rock = 10 }, respawn = 40 },
	BigRock = { hp = 15, reward = { Rock = 24 }, respawn = 75 },
	DenseRock = { hp = 27, reward = { Rock = 50 }, respawn = 50 }, -- 30 s with the pad upgrade (not built yet)
	GooPocket = { hp = 21, reward = { GooDNA = 2 }, respawn = 45 },
	GooVein = { hp = 42, reward = { GooDNA = 5 }, respawn = 90, landmark = true },
	GooCluster = { hp = 27, reward = { GooDNA = 3 }, respawn = 60 },
	CrystalVein = { hp = 42, reward = { CrystalDNA = 5 }, respawn = 90, landmark = true },
	CrystalCluster = { hp = 27, reward = { CrystalDNA = 3 }, respawn = 60 },
	-- 8 placed pods (spec said 6 at 85 s): 110 s keeps the same ~13 DNA/min ceiling
	GooPod = { hp = 21, reward = { GooDNA = 3 }, respawn = 110, landmark = true },
	CrystalPod = { hp = 21, reward = { CrystalDNA = 3 }, respawn = 110, landmark = true },
}

C.CLUSTER_ROTATE = 240 -- small clusters hop to 6 of their biome's 12 sockets every 4 min (shared spots, own timers)
C.CLUSTERS_ACTIVE = 6

return C
