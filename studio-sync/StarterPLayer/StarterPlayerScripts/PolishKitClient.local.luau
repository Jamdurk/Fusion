-- Polish Kit runtime CLIENT BOOTSTRAP (StarterPlayerScripts.PolishKitClient). Starts listening for server-broadcast FX
-- events and warms the approved sounds so the first play isn't late. Game code then uses
--   require(ReplicatedStorage.PolishKit.PresentationRouter).present({ type = "UI", action = "press", gui = btn })
local RS = game:GetService("ReplicatedStorage")
local PK = RS:WaitForChild("PolishKit")
require(PK:WaitForChild("PresentationRouter")).initClient()
task.spawn(function() require(PK:WaitForChild("AudioFX")).preload() end)
-- Looks v2: the client owns Lighting. start() applies server-published looks (Looks.apply on the server) + tagged PK_LightZone parts
require(PK:WaitForChild("Looks")).start()
