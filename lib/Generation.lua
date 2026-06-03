type table = {
	[any]: any
}

type RemoteData = {
	Remote: Instance,
	IsReceive: boolean?,
	MetaMethod: string,
	Args: table,
	Method: string,
    TransferType: string,
	ValueReplacements: table,
	NoVariables: boolean?
}

--// Module
local Generation = {
	DumpBaseName = "SigmaSpy-Dump %s.lua", -- "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n"
	Header = "-- Generated with Sigma Spy BOI @awaken was here",
	ScriptTemplates = {
		["Remote"] = {
			{"%RemoteCall%"}
		},
		["Spam"] = {
			{"while wait() do"},
			{"%RemoteCall%", 2},
			{"end"}
		},
		["Repeat"] = {
			{"for Index = 1, 10 do"},
			{"%RemoteCall%", 2},
			{"end"}
		},
		["Block"] = {
			["__index"] = {
				{"local Old; Old = hookfunction(%Signal%, function(self, ...)"},
				{"if self == %Remote% then", 2},
				{"return", 3},
				{"end", 2},
				{"return Old(self, ...)", 2},
				{"end)"}
			},
			["__namecall"] = {
				{"local Old; Old = hookmetamethod(game, \"__namecall\", function(self, ...)"},
				{"local Method = getnamecallmethod()", 2},
				{"if self == %Remote% and Method == \"%Method%\" then", 2},
				{"return", 3},
				{"end", 2},
				{"return Old(self, ...)", 2},
				{"end)"}
			},
			["Connect"] = {
				{"for _, Connection in getconnections(%Signal%) do"},
				{"Connection:Disable()", 2},
				{"end"}
			}
		}
	}
}

--// Modules
local Config
local Hook
local ParserModule = loadstring(game:HttpGet('https://raw.githubusercontent.com/Awakenchan/Sigma-Spy/refs/heads/main/lib/RobloxParser'))()

local Flags
local ThisScript = script

local function Merge(Base: table, New: table?)
	if not New then return end
	for Key, Value in next, New do
		Base[Key] = Value
	end
end

function Generation:Init(Data: table)
    local Modules = Data.Modules
	local Configuration = Modules.Configuration

	--// Modules
	Config = Modules.Config
	Hook = Modules.Hook
	Flags = Modules.Flags
	
	--// Import parser
	local ParserUrl = Configuration.ParserUrl
	self:LoadParser(ParserUrl)
end

function Generation:MakePrintable(String: string): string
	local Formatter = ParserModule.Modules.Formatter
	return Formatter:MakePrintable(String)
end

function Generation:TimeStampFile(FilePath: string): string
	local TimeStamp = os.date("%Y-%m-%d_%H-%M-%S")
	local Formatted = FilePath:format(TimeStamp)
	return Formatted
end

function Generation:WriteDump(Content: string): string
	local DumpBaseName = self.DumpBaseName
	local FilePath = self:TimeStampFile(DumpBaseName)

	--// Write to file
	if not writefile then return FilePath end

	pcall(writefile, FilePath, Content)

	return FilePath
end

function Generation:LoadParser(ModuleUrl: string)
	ParserModule = loadstring(game:HttpGet(ModuleUrl), "Parser")()
end

function Generation:MakeValueSwapsTable(): table
	local Formatter = ParserModule.Modules.Formatter
	return Formatter:MakeReplacements()
end

function Generation:SetSwapsCallback(Callback: (Interface: table) -> ())
	self.SwapsCallback = Callback
end

function Generation:GetBase(Module): (string, boolean)
	local NoComments = Flags:GetFlagValue("NoComments")
	local Header = self.Header

	local Code = NoComments and "" or Header

	--// Generate variables code
	local Variables = Module.Parser:MakeVariableCode({
		"Services", "Remote", "Variables"
	}, NoComments)

	local NoVariables = Variables == ""
	Code ..= Variables

	return Code, NoVariables
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

function Generation:PickVariableName(): string
	local Names = Config.VariableNames
	return Names[math.random(1, #Names)]
end

function Generation:NewParser(Extra: table?)
	local VariableName = self:PickVariableName()
	local Swaps = self:GetSwaps()

	local Configuration = {
		VariableBase = VariableName,
		Swaps = Swaps,
		IndexFunc = function(...)
			return Hook:Index(...)
		end,
	}

	--// Merge extra configuration
	Merge(Configuration, Extra)

	--// Create new parser instance
	return ParserModule:New(Configuration)
end

function Generation:Indent(IndentString: string, Line: string)
	return `{IndentString}{Line}`
end

type CallInfo = {
	Arguments: table,
	Indent: number,
	RemoteVariable: string,
	Module: table
}
function Generation:CallRemoteScript(Data, Info: CallInfo): string
	local IsReceive = Data.IsReceive
	local Method = Data.Method
	local Args = Data.Args

	local RemoteVariable = Info.RemoteVariable
	local Indent = Info.Indent or 0
	local Module = Info.Module

	local Variables = Module.Variables
	local Parser = Module.Parser
	local NoVariables = Data.NoVariables

	local IndentString = self:MakeIndent(Indent)

	--// Parse arguments
	local ParsedArgs, ItemsCount, IsArray = Parser:ParseTableIntoString({
		NoBrackets = true,
		NoVariables = NoVariables,
		Table = Args,
		Indent = Indent
	})

	--// Create table variable if not an array
	if not IsArray or NoVariables then
		ParsedArgs = Variables:MakeVariable({
			Value = ("{%s}"):format(ParsedArgs),
			Comment = not IsArray and "Arguments aren't ordered" or nil,
			Name = "RemoteArgs",
			Class = "Remote"
		})
	end

	--// Wrap in a unpack if the table is a dict
	if ItemsCount > 0 and not IsArray then
		ParsedArgs = `unpack({ParsedArgs}, 1, table.maxn({ParsedArgs}))`
	end

	--// Firesignal script for client recieves
	if IsReceive then
		local Second = ItemsCount <= 0 and "" or `, {ParsedArgs}`
		local Signal = `{RemoteVariable}.{Method}`

		local Code = `-- This data was received from the server`
		ParsedArgs = self:Indent(IndentString, Code)
		Code ..= `\n{IndentString}firesignal({Signal}{Second})`
		
		return Code
	end
	
	--// Remote invoke script
	return `{RemoteVariable}:{Method}({ParsedArgs})`
end

--// Variables: %VariableName%
function Generation:ApplyVariables(String: string, Variables: table, ...): string
	for Variable, Value in Variables do
		--// Invoke value function
		if typeof(Value) == "function" then
			Value = Value(...)
		end

		String = String:gsub(`%%{Variable}%%`, function()
			return Value
		end)
	end
	return String
end

function Generation:MakeIndent(Indent: number)
	return string.rep("	", Indent)
end

type ScriptData = {
	Variables: table,
	MetaMethod: string
}
function Generation:MakeCallCode(ScriptType: string, Data: ScriptData): string
	local ScriptTemplates = self.ScriptTemplates
	local Template = ScriptTemplates[ScriptType]

	assert(Template, `{ScriptType} is not a valid script type!`)

	local Variables = Data.Variables
	local MetaMethod = Data.MetaMethod
	local MetaMethods = {"__index", "__namecall", "Connect"}

	local function Compile(Template: table): string
		local Out = ""

		for Key, Value in next, Template do
			--// MetaMethod check
			local IsMetaTypeOnly = table.find(MetaMethods, Key)
			if IsMetaTypeOnly then
				if Key == MetaMethod then
					local Line = Compile(Value)
					Out ..= Line
				end
				continue
			end

			--// Information
			local Content, Indent = Value[1], Value[2] or 0
			Indent = math.clamp(Indent-1, 0, 9999)

			--// Make line
			local Line = self:ApplyVariables(Content, Variables, Indent)
			local IndentString = self:MakeIndent(Indent)

			--// Append to code
			Out ..= `{IndentString}{Line}\n`
		end

		return Out
	end
	
	return Compile(Template)
end

function Generation:RemoteScript(Module, Data: RemoteData, ScriptType: string): string
	--// Unpack data
	local Remote = Data.Remote
	local Args = Data.Args
	local Method = Data.Method
	local MetaMethod = Data.MetaMethod

	--// Remote info
	local ClassName = Hook:Index(Remote, "ClassName")
	local IsNilParent = Hook:Index(Remote, "Parent") == nil
	
	local Variables = Module.Variables
	local Formatter = Module.Formatter
	
	--// Pre-render variables
	Variables:PrerenderVariables(Args, {"Instance"})

	--// Create remote variable
	local RemoteVariable = Variables:MakeVariable({
		Value = Formatter:Format(Remote, {
			NoVariables = true
		}),
		Comment = `{ClassName} {IsNilParent and "| Remote parent is nil" or ""}`,
		Name = Formatter:MakeName(Remote),
		Lookup = Remote,
		Class = "Remote"
	})

	--// Generate call script
	local CallCode = self:MakeCallCode(ScriptType, {
		Variables = {
			["RemoteCall"] = function(Indent: number)
				return self:CallRemoteScript(Data, {
					RemoteVariable = RemoteVariable,
					Indent = Indent,
					Module = Module
				})
			end,
			["Remote"] = RemoteVariable,
			["Method"] = Method,
			["Signal"] = `{RemoteVariable}.{Method}`
		},
		MetaMethod = MetaMethod
	})
	
	--// Make code
	local Code = self:GetBase(Module)
	return `{Code}\n{CallCode}`
end

function Generation:ConnectionsTable(Signal: RBXScriptSignal): table
	if not getconnections then return {} end

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

function Generation:TableScript(Module, Table: table): string
	--// Pre-render variables
	Module.Variables:PrerenderVariables(Table, {"Instance"})

	--// Parse arguments
	local ParsedTable = Module.Parser:ParseTableIntoString({
		Table = Table
	})

	--// Generate script
	local Code, NoVariables = self:GetBase(Module)
	local Seperator = NoVariables and "" or "\n"
	Code ..= `{Seperator}return {ParsedTable}`

	return Code
end

function Generation:MakeTypesTable(Table: table): table
	local Types = {}

	for Key, Value in next, Table do
		local Type = typeof(Value)
		if Type == "table" then
			Type = self:MakeTypesTable(Value)
		end

		Types[Key] = Type
	end

	return Types
end

function Generation:ConnectionInfo(Remote: Instance, ClassData: table): table?
	local ReceiveMethods = ClassData.Receive
	if not ReceiveMethods then return end

	local Connections = {}
	for _, Method: string in next, ReceiveMethods do
		pcall(function() -- TODO: GETCALLBACKVALUE
			local Signal = Hook:Index(Remote, Method)
			Connections[Method] = self:ConnectionsTable(Signal)
		end)
	end

	return Connections
end

function Generation:AdvancedInfo(Module, Data: table): string
	--// Unpack remote data
	local Function = Data.CallingFunction
	local ClassData = Data.ClassData
	local Remote = Data.Remote
	local Args = Data.Args
	
	--// Advanced info table base
	local FunctionInfo = {
		["Caller"] = {
			["SourceScript"] = Data.SourceScript,
			["CallingScript"] = Data.CallingScript,
			["CallingFunction"] = Function
		},
		["Remote"] = {
			["Remote"] = Remote,
			["RemoteID"] = Data.Id,
			["Method"] = Data.Method,
			["Connections"] = self:ConnectionInfo(Remote, ClassData)
		},
		["Arguments"] = {
			["Length"] = #Args,
			["Types"] = self:MakeTypesTable(Args),
		},
		["MetaMethod"] = Data.MetaMethod,
		["IsActor"] = Data.IsActor,
	}

	--// Some closures may not be lua
	if Function and islclosure(Function) then
		FunctionInfo["UpValues"] = debug.getupvalues(Function)
		FunctionInfo["Constants"] = debug.getconstants(Function)
	end

	--// Generate script
	return self:TableScript(Module, FunctionInfo)
end

function Generation:DumpLogs(Logs: table): string
	local BaseData
	local Parsed = {
		Remote = nil,
		Calls = {}
	}

	--// Create new parser instance
	local Module = Generation:NewParser()

	for _, Data in Logs do
		local Calls = Parsed.Calls
		local Table = {
			Args = Data.Args,
			Timestamp = Data.Timestamp,
			ReturnValues = Data.ReturnValues,
			Method = Data.Method,
			MetaMethod = Data.MetaMethod,
			CallingScript = Data.CallingScript,
		}

		--// Append
		table.insert(Calls, Table)

		--// Set BaseData
		if not BaseData then
			BaseData = Data
		end
	end

	--// Basedata merge
	Parsed.Remote = BaseData.Remote

	--// Compile and save
	local Output = self:TableScript(Module, Parsed)
	local FilePath = self:WriteDump(Output)
	
	return FilePath
end

return Generation
