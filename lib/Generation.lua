local Generation = {}

type table = {
	[any]: any
}

--// Libraries
local ParserModule = loadstring(game:HttpGet('https://raw.githubusercontent.com/Awakenchan/Sigma-Spy/refs/heads/main/lib/RobloxParser'))()

--// Parser
function ParserModule:Import(Name: string)
	local Url = `{self.ImportUrl}/{Name}.lua`
	return loadstring(game:HttpGet(Url))()
end
ParserModule:Load()

--// Modules
local Config
local Hook

local ThisScript = script

function Generation:Init(Configuration: table)
    local Modules = Configuration.Modules

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): string
	local Code = "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n\n"

	--// Generate variables code
	Code ..= Module.Parser:MakeVariableCode({
		"Services", "Variables", "Remote"
	})

	return Code
end

function Generation:GetSwaps()
	local Func = self.SwapsCallback
	local Swaps = {}

	local Interface = {}
	function Interface:AddSwap(Object: Instance, Data: table)
		if not Object then return end
		Swaps[Object] = Data
	end

	--// Invoke GetSwaps function
	Func(Interface)

	return Swaps
end

function Generation:PickVariableName()
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser()
	local VariableName = self:PickVariableName()

	--// Swaps
	local Swaps = self:GetSwaps()

	--// Load parser module
	local Module = ParserModule:New({
		VariableBase = VariableName,
		Swaps = Swaps,
		IndexFunc = function(...)
			return Hook:Index(...)
		end,
	})

	return Module
end

type RemoteScript = {
	Remote: Instance,
	IsReceive: boolean?,
	Args: table,
	Method: string
}
function Generation:RemoteScript(Module, Data: RemoteScript): string
	local Remote = Data.Remote
	local IsReceive = Data.IsReceive
	local Args = Data.Args
	local Method = Data.Method

	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	local Variables = Module.Variables
	local Formatter = Module.Formatter
	local Parser = Module.Parser
	
	--// Pre-render variables
	Variables:PrerenderVariables(Args, {"Instance"})

	--// Parse arguments
	local ParsedArgs, ItemsCount = Parser:ParseTableIntoString({
		NoBrackets = true,
		Table = Args
	})

	--// Create remote variable
	local RemoteVariable = Variables:MakeVariable({
		Value = Formatter:Format(Remote, {
			NoVariableCreate = true
		}),
		Comment = IsNilParent and "Remote parent is nil" or ClassName,
		Lookup = Remote,
		Name = Formatter:MakeName(Remote), --ClassName,
		Class = "Remote"
	})

	--// Make code
	local Code = self:GetBase(Module)
	
	--// Firesignal script for client recieves
	if IsReceive then
		local Second = ItemsCount == 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		Code ..= `\n-- This data was received from the server`
		Code ..= `\nfiresignal({Signal}{Second})`
		return Code
	end
	
	--// Remote invoke script
	Code ..= `\n{RemoteVariable}:{Method}({ParsedArgs})`
	return Code
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	local Connections = getconnections(Signal)
	local DataArray = {}

	for _, Connection in next, Connections do
		local Function = Connection.Function
		local Script = rawget(getfenv(Function), "script")

		--// Skip if self
		if Script == ThisScript then continue end

		--// Connection data
		local Data = {
			Function = Function,
			State = Connection.State,
			Script = Script
		}

		table.insert(DataArray, Data)
	end

	return DataArray
end

function Generation:TableScript(Table: table)
	local Module = self:NewParser()

	--// Pre-render variables
	Module.Variables:PrerenderVariables(Table, {"Instance"})

	--// Parse arguments
	local ParsedTable = Module.Parser:ParseTableIntoString({
		Table = Table
	})

	--// Generate script
	local Code = self:GetBase(Module)
	Code ..= `\nreturn {ParsedTable}`

	return Code
end

return Generation
