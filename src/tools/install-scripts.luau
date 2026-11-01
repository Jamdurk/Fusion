-- Alien Fusion: install the game's scripts from src\ into the open place (Studio Edit, via the MCP).
-- Needs kit-serve on 48734 serving the game folder. Each file name says where it goes:
--   <Service>.<Folder...>.<Name>.<client|server|module>.luau  ->  LocalScript / Script / ModuleScript
-- An existing script of the same name in the same place is updated in place (its Source replaced).
local Http = game:GetService("HttpService")
local FILES = {
	"StarterPlayer.StarterPlayerScripts.MoonLook.client.luau",
	"ReplicatedStorage.AlienFusion.Gaits.module.luau",
	"ReplicatedStorage.AlienFusion.Attacks.module.luau",
	"StarterPlayer.StarterPlayerScripts.AlienAnimator.client.luau",
	"ServerScriptService.WalkTest.server.luau",
}
local CLASS = { client = "LocalScript", server = "Script", module = "ModuleScript" }
local was = Http.HttpEnabled
Http.HttpEnabled = true
local out = {}
for _, file in FILES do
	local ok, src = pcall(Http.GetAsync, Http, "http://127.0.0.1:48734/src/" .. file, true)
	assert(ok, "fetch " .. file .. ": " .. tostring(src))
	local parts = string.split(file, ".")
	local kind = parts[#parts - 1]
	local name = parts[#parts - 2]
	local parent = game:GetService(parts[1])
	for i = 2, #parts - 3 do
		local f = parent:FindFirstChild(parts[i])
		if not f then f = Instance.new("Folder"); f.Name = parts[i]; f.Parent = parent end
		parent = f
	end
	local s = parent:FindFirstChild(name)
	if s and s.ClassName ~= CLASS[kind] then s:Destroy(); s = nil end
	if not s then s = Instance.new(CLASS[kind]); s.Name = name; s.Parent = parent end
	s.Source = src
	table.insert(out, s:GetFullName() .. " (" .. #src .. ")")
end
Http.HttpEnabled = was
return "installed: " .. table.concat(out, ", ")
