--[[
	⣿⣿⣿⣿⣿⣿SIGMA SPY⣿⣿⣿⣿⣿⣿
	⣿⣿⣯⡉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁
	⠉⠻⣿⣿⣦⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
	⠀⠀⠈⠻⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
	⠀⠀⠀⠀⠀⠙⢿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀
	⠀⠀⠀⠀⠀⠀⠀⣉⣿⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀
	⠀⠀⠀⠀⠀⣠⣾⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀
	⠀⠀⢀⣴⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
	⣀⣴⣿⣿⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
	⣿⣿⣟⣁⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡀
	⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇

    Written by @depso
    MIT License
    
    https://github.com/depthso
]]

--// File handling configuration 
local FilesConfig = {
	UseWorkspace = false,
	RepoUrl = "https://github.com/Awakenchan/Sigma-Spy/tree/main" -- "http://127.0.0.1:3000"
}

--// Service handlers
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		local Service = game:GetService(Name)
		return cloneref(Service)
	end,
})

--// Services
local Players: Players = Services.Players

--// Fetch Files module code
local FilesScript
if FilesConfig.UseWorkspace then
	FilesScript = readfile(`{FilesConfig.Folder}/lib/Files.lua`)
else
	FilesScript = game:HttpGet(`{FilesConfig.RepoUrl}/lib/Files.lua`)
end

--// Load files module
local Files = loadstring(FilesScript)()
Files:PushConfig(FilesConfig)
Files:Init({
	Services = Services
})

--// Modules
local Scripts = {
	--// User configurations
	Config = Files:GetModule("Sigma Spy/Config", "Config"),
	ReturnSpoofs = Files:GetModule("Sigma Spy/Return spoofs", "Return Spoofs"),

	--// Libraries
	Process = Files:GetModule("lib/Process"),
	Hook = Files:GetModule("lib/Hook"),
	Flags = Files:GetModule("lib/Flags"),
	Ui = Files:GetModule("lib/Ui"),
	Generation = Files:GetModule("lib/Generation"),
	Communication = Files:GetModule("lib/Communication")
}

--// Dependencies
local Modules = Files:LoadLibraries(Scripts)
local Process = Modules.Process
local Hook = Modules.Hook
local Config = Modules.Config
local Ui = Modules.Ui
local Generation = Modules.Generation
local Communication = Modules.Communication

--// Unpack config
local BlackListedServices = Config.BlackListedServices

--// Use custom font (optional)
local FontContent = Files:GetAsset("ProggyClean.ttf", true)
local FontJsonFile = Files:CreateFont("ProggyClean", FontContent)
Ui:SetFont(FontJsonFile, FontContent)

--// Actor code
local ActorCode = Files:CompileModule(Scripts)
ActorCode ..= [=[
	local ExtraData = {
		IsActor = true
	}
	print("ChannelId", ...)
	Libraries.Hook:BeginService(Libraries, ExtraData, ...)
]=]

--// Load modules
Files:LoadModules(Modules, {
	Modules = Modules,
	Services = Services
})

--// ReGui Create window
local Window = Ui:CreateWindow()

--// Check if Sigma spy is supported
local Supported = Process:CheckIsSupported()
if not Supported then 
	Window:Close()
	return
end

--// Generation swaps
local LocalPlayer = Players.LocalPlayer
Generation:SetSwapsCallback(function(self)
	self:AddSwap(LocalPlayer, {
		String = "LocalPlayer",
	})
	self:AddSwap(LocalPlayer.Character, {
		String = "Character",
		NextParent = LocalPlayer
	})
end)

--// Beta alert modal
Ui:ShowModal({
	"<b>Attention!</b>",
	"Sigma Spy is in BETA, please expect issues\n",
	"Report any issues to the Github page (depthso/Sigma-Spy)\n",
	"Many thanks!"
})

--// Create window content
Ui:CreateWindowContent(Window)

--// Create communication channel
local ChannelId = Communication:CreateChannel()
Communication:AddCommCallback("QueueLog", function(...)
	Ui:QueueLog(...)
end)

--// Begin hook
Hook:BeginService(Modules, nil, ChannelId) -- Run on self
Hook:RunOnActors(ActorCode, ChannelId) -- Run on actors

--// Remote added
game.DescendantAdded:Connect(function(Remote) -- TODO
	Hook:ConnectClientRecive(Remote)
end)

--// Collect missing remotes
Hook:MultiConnect(getnilinstances())

--// Search for remotes
for _, Service in next, game:GetChildren() do
	if table.find(BlackListedServices, Service.ClassName) then continue end
	Hook:MultiConnect(Service:GetDescendants())
end

--// Begin the Log queue service
Ui:BeginLogService()
