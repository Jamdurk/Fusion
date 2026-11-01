-- Alien Fusion: the Moon look on every client (Lighting Kit `void` + the "lunarday" overlay).
-- Roblox only renders its own stars at night, so the black star sky is a Blender skybox (Lighting.PK_Sky textures,
-- set at build time) and the light is a hard daytime sun. Values from the 27 Oct map audit (ChatGPT: lower the
-- ground highlights a touch, lift the shadows, keep the sky black).
local RS = game:GetService("ReplicatedStorage")
local Looks = require(RS:WaitForChild("PolishKit"):WaitForChild("Looks"))
local C = Color3.fromRGB
Looks.apply("void")
Looks.push("lunarday", { set = {
	lighting = { ClockTime = 15.2, GeographicLatitude = 20, Brightness = 2.4, ExposureCompensation = -0.4,
		OutdoorAmbient = C(72, 76, 90), Ambient = C(16, 18, 24), ShadowSoftness = 0.04, ColorShift_Top = C(255, 244, 228),
		EnvironmentDiffuseScale = 0.12, EnvironmentSpecularScale = 0.6 },
	sky = { SunAngularSize = 7, StarCount = 0 },
	cc = { Contrast = 0.12, Saturation = -0.03, TintColor = C(255, 253, 250) },
} }, 10)
