-- Polish Kit runtime SERVER BOOTSTRAP (ServerScriptService.PolishKitServer): creates the PKFX RemoteEvent. Server game code
-- then reports confirmed world events:
--   require(ReplicatedStorage.PolishKit.PresentationRouter).broadcast({ type = "Impact", weight = "Boss", position = pos })
require(game:GetService("ReplicatedStorage"):WaitForChild("PolishKit"):WaitForChild("PresentationRouter")).initServer()
