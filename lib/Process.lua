--!nolint DeprecatedApi

type table = {
    [any]: any
}

type RemoteData = {
	Remote: Instance,
    NoBacktrace: boolean?,
	IsReceive: boolean?,
	Args: table,
    Id: string,
	Method: string,
    TransferType: string,
	ValueReplacements: table,
    ReturnValues: table,
    OriginalFunc: (Instance, ...any) -> ...any
}

--// Module
local Process = {
    --// Remote classes
    RemoteClassData = {
        ["RemoteEvent"] = {
            Send = {
                "FireServer",
                "fireServer",
            },
            Receive = {
                "OnClientEvent",
            }
        },
        ["RemoteFunction"] = {
            IsRemoteFunction = true,
            Send = {
                "InvokeServer",
                "invokeServer",
            },
            Receive = {
                "OnClientInvoke",
            }
        },
        ["UnreliableRemoteEvent"] = {
            Send = {
                "FireServer",
                "fireServer",
            },
            Receive = {
                "OnClientEvent",
            }
        },
        ["BindableEvent"] = {
            NoReciveHook = true,
            Send = {
                "Fire",
            },
            Receive = {
                "Event",
            }
        },
        ["BindableFunction"] = {
            IsRemoteFunction = true,
            NoReciveHook = true,
            Send = {
                "Invoke",
            },
            Receive = {
                "OnInvoke",
            }
        }
    },
    RemoteOptions = {},
    LoopingRemotes = {},
    ConfigOverwrites = {
        [{"sirhurt", "potassium", "wave"}] = {
            ForceUseCustomComm = true
        }
    }
}

--// Modules
local Hook
local Communication
local ReturnSpoofs
local Ui
local Config

--// Services
local HttpService: HttpService

--// Communication channel
local Channel
local WrappedChannel = false

local SigmaENV = getfenv(1)

type Event = RemoteEvent | RemoteFunction | UnreliableRemoteEvent | BindableEvent | BindableFunction
local InstanceCreatedRemotes: typeof(setmetatable({} :: {[Event]: true}, {__mode = "k"})) = setmetatable({}, {
    __mode = "k"
})

function Process:Merge(Base: table, New: table)
    if not New then return end
	for Key, Value in next, New do
		Base[Key] = Value
	end
end
local function GetHook()
	return (oth and oth.hook) or hookfunction
end

function Process:Init(Data)
    local Modules = Data.Modules
    local Services = Data.Services

    --// Services
    HttpService = Services.HttpService

    --// Modules
    Config = Modules.Config
    Ui = Modules.Ui
    Hook = Modules.Hook
    Communication = Modules.Communication
    ReturnSpoofs = Modules.ReturnSpoofs
    local method = GetHook()

    local OldInstancenew; OldInstancenew = method(getrenv().Instance.new, newcclosure(function(...)
        local Inst = OldInstancenew(...)
        if typeof(Inst) == "Instance" and Process.RemoteClassData[Inst.ClassName] then
            InstanceCreatedRemotes[Inst :: Event] = true
        end
        return Inst
    end))
end

--// Communication
function Process:SetChannel(NewChannel: BindableEvent, IsWrapped: boolean)
    Channel = NewChannel
    WrappedChannel = IsWrapped
end

function Process:GetConfigOverwrites(Name: string)
    local ConfigOverwrites = self.ConfigOverwrites

    for List, Overwrites in next, ConfigOverwrites do
        if not table.find(List, Name) then continue end
        return Overwrites
    end
    return
end

function Process:CheckConfig(Config: table)
    local Name = identifyexecutor():lower()

    --// Force configuration overwrites for specific executors
    local Overwrites = self:GetConfigOverwrites(Name)
    if not Overwrites then return end

    self:Merge(Config, Overwrites)
end

function Process:CleanCError(Error: string): string
    Error = Error:gsub(":%d+: ", "")
    Error = Error:gsub(", got %a+", "")
    Error = Error:gsub("invalid argument", "missing argument")
    return Error
end

function Process:CountMatches(String: string, Match: string): number
	local Count = 0
	for _ in String:gmatch(Match) do
		Count +=1 
	end

	return Count
end

function Process:CheckValue(Value, Ignore: table?, Cache: table?)
    local Type = typeof(Value)
    Communication:WaitCheck()
    
    if Type == "table" then
        Value = self:DeepCloneTable(Value, Ignore, Cache)
    elseif Type == "Instance" then
        Value = cloneref(Value)
    end
    
    return Value
end

function Process:DeepCloneTable(Table, Ignore: table?, Visited: table?): table
    if typeof(Table) ~= "table" then return Table end
    local Cache = Visited or {}

    --// Check for cached
    if Cache[Table] then
        return Cache[Table]
    end

    local New = {}
    Cache[Table] = New

    for Key, Value in next, Table do
        --// Check if the value is ignored
        if Ignore and table.find(Ignore, Value) then continue end
        
        Key = self:CheckValue(Key, Ignore, Cache)
        New[Key] = self:CheckValue(Value, Ignore, Cache)
    end

    --// Master clear
    if not Visited then
        table.clear(Cache)
    end
    
    return New
end

function Process:Unpack(Table: table)
    if not Table then return Table end
	local Length = table.maxn(Table)
	return unpack(Table, 1, Length)
end

function Process:PushConfig(Overwrites)
    self:Merge(self, Overwrites)
end

function Process:FuncExists(Name: string)
	return SigmaENV[Name]
end

function Process:CheckExecutor(): boolean
    local Blacklisted = {
        "xeno",
        "solara",
        "jjsploit"
    }

    local Name = identifyexecutor():lower()
    local IsBlacklisted = table.find(Blacklisted, Name)

    --// Some executors have broken functionality
    if IsBlacklisted then
        Ui:ShowUnsupportedExecutor(Name)
        return false
    end

    return true
end

function Process:CheckFunctions(): boolean
    local CoreFunctions = {
        "hookmetamethod",
        "hookfunction",
        "getrawmetatable",
        "setreadonly"
    }

    --// Check if the functions exist in the ENV
    for _, Name in CoreFunctions do
        local Func = self:FuncExists(Name)
        if Func then continue end

        --// Function missing!
        Ui:ShowUnsupported(Name)
        return false
    end

    return true
end

function Process:CheckIsSupported(): boolean
    --// Check if the executor is blacklisted
    local ExecutorSupported = self:CheckExecutor()
    if not ExecutorSupported then
        return false
    end

    --// Check if the core functions exist
    local FunctionsSupported = self:CheckFunctions()
    if not FunctionsSupported then
        return false
    end

    return true
end

function Process:GetClassData(Remote: Instance): table?
    local RemoteClassData = self.RemoteClassData
    local ClassName = Hook:Index(Remote, "ClassName")

    return RemoteClassData[ClassName]
end

function Process:IsProtectedRemote(Remote: Instance): boolean
    local IsDebug = Remote == Communication.DebugIdRemote
    local IsChannel = Remote == (WrappedChannel and Channel.Channel or Channel)

    return IsDebug or IsChannel
end

function Process:RemoteAllowed(Remote: Event, TransferType: string, Method: string?): boolean?
    if typeof(Remote) ~= 'Instance' or InstanceCreatedRemotes[Remote] then return end
    
    --// Check if the Remote is protected
    if self:IsProtectedRemote(Remote) then return end

    --// Fetch class table
	local ClassData = self:GetClassData(Remote)
	if not ClassData then return end

    --// Check if the transfer type has data
	local Allowed = ClassData[TransferType]
	if not Allowed then return end

    --// Check if the method is allowed
	if Method then
		return table.find(Allowed, Method) ~= nil
	end

	return true
end

function Process:SetExtraData(Data: table)
    if not Data then return end
    self.ExtraData = Data
end

function Process:GetRemoteSpoof(Remote: Instance, Method: string, ...): table?
    local Spoof = ReturnSpoofs[Remote]

    if not Spoof then return end
    if Spoof.Method ~= Method then return end

    local ReturnValues = Spoof.Return

    --// Call the ReturnValues function type
    if typeof(ReturnValues) == "function" then
        ReturnValues = ReturnValues(...)
    end

	return ReturnValues
end

function Process:SetNewReturnSpoofs(NewReturnSpoofs: table)
    ReturnSpoofs = NewReturnSpoofs
end

function Process:FindCallingLClosure(Offset: number)
    local Getfenv = Hook:GetOriginalFunc(getfenv)
    Offset += 1

    while true do
        Offset += 1

        --// Check if the stack level is valid
        local IsValid = debug.info(Offset, "l") ~= -1
        if not IsValid then continue end

        --// Check if the function is valid
        local Function = debug.info(Offset, "f")
        if not Function then return end
        if Getfenv(Function) == SigmaENV then continue end

        return Function
    end
end

function Process:Decompile(Script: LocalScript | ModuleScript): string
    local KonstantAPI = "http://api.plusgiant5.com/konstant/decompile"
    local ForceKonstant = Config.ForceKonstantDecompiler

    --// Use built-in decompiler if the executor supports it
    if decompile and not ForceKonstant then 
        return decompile(Script)
    end

    --// getscriptbytecode
    local Success, Bytecode = pcall(getscriptbytecode, Script)
    if not Success then
        local Error = `--Failed to get script bytecode, error:\n`
        Error ..= `\n--[[\n{Bytecode}\n]]`
        return Error, true
    end
    
    --// Send POST request to the API
    local Responce = request({
        Url = KonstantAPI,
        Body = Bytecode,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "text/plain"
        },
    })

    --// Error check
    if Responce.StatusCode ~= 200 then
        local Error = `--[KONSTANT] Error occured while requesting the API, error:\n`
        Error ..= `\n--[[\n{Responce.Body}\n]]`
        return Error, true
    end

    return Responce.Body
end

function Process:GetScriptFromFunc(Func: (...any) -> ...any)
    if not Func then return end

    local Success, ENV = pcall(getfenv, Func)
    if not Success then return end
    
    --// Blacklist sigma spy
    if self:IsSigmaSpyENV(ENV) then return end

    return rawget(ENV, "script")
end

function Process:ConnectionIsValid(Connection: table): boolean
    local ValueReplacements = {
		["Script"] = function(Connection: table): Script?
			local Function = Connection.Function
			if not Function then return end

			return self:GetScriptFromFunc(Function)
		end
	}

    --// Check if these properties are valid
    local ToCheck = {
        "Script"
    }
    for _, Property in ToCheck do
        local Replacement = ValueReplacements[Property]
        local Value

        --// Check if there's a function for a property
        if Replacement then
            Value = Replacement(Connection)
        end

        --// Check if the property has a value
        if Value == nil then 
            return false 
        end
    end

    return true
end

function Process:FilterConnections(Signal: RBXScriptSignal): table
    local Processed = {}

    --// Filter each connection
    for _, Connection in getconnections(Signal) do
        if not self:ConnectionIsValid(Connection) then continue end
        table.insert(Processed, Connection)
    end

    return Processed
end

function Process:IsSigmaSpyENV(Env: table): boolean
    return Env == SigmaENV
end

function Process:GetRemoteData(Id: string)
    local RemoteOptions = self.RemoteOptions

    --// Check for existing remote data
	local Existing = RemoteOptions[Id]
	if Existing then return Existing end
	
    --// Base remote data
	local Data = {
		Excluded = false,
		Blocked = false
	}

	RemoteOptions[Id] = Data
	return Data
end

function Process:CallDiscordRPC(Body: table)
    request({
        Url = "http://127.0.0.1:6463/rpc?v=1",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Origin"] = "https://discord.com/"
        },
        Body = HttpService:JSONEncode(Body)
    })
end

function Process:PromptDiscordInvite(InviteCode: string)
    self:CallDiscordRPC({
        cmd = "INVITE_BROWSER",
        nonce = HttpService:GenerateGUID(false),
        args = {
            code = InviteCode
        }
    })
end

local ProcessCallback = newcclosure(function(Data: RemoteData, Remote, ...): table?
    --// Unpack Data
    local OriginalFunc = Data.OriginalFunc
    local Id = Data.Id
    local Method = Data.Method

    --// Check if the Remote is Blocked
    local RemoteData = Process:GetRemoteData(Id)
    if RemoteData.Blocked then return {} end

    --// Check for a spoof
    local Spoof = Process:GetRemoteSpoof(Remote, Method, OriginalFunc, ...)
    if Spoof then return Spoof end

    --// Check if the orignal function was passed
    if not OriginalFunc then return end

    --// Invoke orignal function
    return {
        OriginalFunc(Remote, ...)
    }
end)

function Process:ProcessRemote(Data: RemoteData, Remote, ...): table?
    --// Unpack Data
	local Method = Data.Method
    local TransferType = Data.TransferType
    local IsReceive = Data.IsReceive

	--// Check if the transfertype method is allowed
	if TransferType and not self:RemoteAllowed(Remote, TransferType, Method) then return end

    --// Fetch details
    local Id = Communication:GetDebugId(Remote)
    local ClassData = self:GetClassData(Remote)
    local Timestamp = tick()

    local CallingFunction
    local SourceScript

    --// Add extra data into the log if needed
    local ExtraData = self.ExtraData
    if ExtraData then
        self:Merge(Data, ExtraData)
    end

    --// Get caller information
    if not IsReceive then
        CallingFunction = self:FindCallingLClosure(6)
        SourceScript = CallingFunction and self:GetScriptFromFunc(CallingFunction) or nil
    end

    --// Add to queue
    self:Merge(Data, {
        Remote = cloneref(Remote),
		CallingScript = getcallingscript(),
        CallingFunction = CallingFunction,
        SourceScript = SourceScript,
        Id = Id,
		ClassData = ClassData,
        Timestamp = Timestamp,
        Args = {...}
    })

    --// Invoke the Remote and log return values
    local ReturnValues = ProcessCallback(Data, Remote, ...)
    Data.ReturnValues = ReturnValues

    --// Queue log
    Communication:QueueLog(Data)

    return ReturnValues
end

function Process:SetAllRemoteData(Key: string, Value)
    local RemoteOptions = self.RemoteOptions
	for RemoteID, Data in next, RemoteOptions do
		Data[Key] = Value
	end
end

--// The communication creates a different table address
--// Recived tables will not be the same
function Process:SetRemoteData(Id: string, RemoteData: table)
    local RemoteOptions = self.RemoteOptions
    RemoteOptions[Id] = RemoteData
end

function Process:UpdateRemoteData(Id: string, RemoteData: table)
    Communication:Communicate("RemoteData", Id, RemoteData)
end

function Process:UpdateAllRemoteData(Key: string, Value)
    Communication:Communicate("AllRemoteData", Key, Value)
end

return Process
