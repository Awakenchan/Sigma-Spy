local Hook = {
	OrignalNamecall = nil,
	OrignalIndex = nil,
}

type table = {
	[any]: any
}

type MetaCallback = (Instance, ...any)->...any

local Process

local function HookMetaMethod(self, Call: string, Callback: MetaCallback): MetaCallback
	local OriginalFunc
	OriginalFunc = hookmetamethod(self, Call, function(...)
		local ReturnValues = Callback(...)
		if ReturnValues then
			local Length = table.maxn(ReturnValues)
			return unpack(ReturnValues, 1, Length)
		end

		return OriginalFunc(...)
	end)
	return OriginalFunc
end

local function Merge(Base: table, New: table)
	for Key, Value in New do
		Base[Key] = Value
	end
end

function Hook:RunOnActors(Code: string, ChannelId: number)
	if not getactors then return end
	for _, Actor in getactors() do
		run_on_actor(Actor, Code, ChannelId)
	end
end

local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
	return Process:ProcessRemote({
		Remote = self,
		Method = Method,
		OriginalFunc = OriginalFunc,
		MetaMethod = MetaMethod,
		TransferType = "Send",
		Args = {...}
	})
end

local function __IndexCallback(OriginalIndex, self, Method: string)
	if typeof(self) ~= "Instance" then return end

	local OriginalFunc = OriginalIndex(self, Method)
	if typeof(OriginalFunc) ~= "function" then return end

	if not Process:RemoteAllowed(self, "Send", Method) then return end

	return {function(self, ...)
		return ProcessRemote(OriginalFunc, "__index", self, Method, ...)
	end}
end

function Hook:HookMeta()
	local On; On = HookMetaMethod(game, "__namecall", function(self, ...)
		if typeof(self) ~= "Instance" then return end
		local Method = getnamecallmethod()
		return ProcessRemote(On, "__namecall", self, Method, ...)
	end)
	local Oi; Oi = HookMetaMethod(game, "__index", function(...)
		return __IndexCallback(Oi, ...)
	end)

	Merge(self, {
		OrignalNamecall = On,
		OrignalIndex = Oi,
	})
end

function Hook:Index(Object, Key: string)
	if typeof(Object) == "Instance" then
		local OrignalIndex = self.OrignalIndex
		if OrignalIndex then
			return OrignalIndex(Object, Key)
		end
	end
	local ok, result = pcall(function()
		return Object[Key]
	end)
	if ok then
		return result
	end
	return nil
end

function Hook:Init(Data)
	local Modules = Data.Modules
	Process = Modules.Process
end

function Hook:PushConfig(Overwrites)
	Merge(self, Overwrites)
end

function Hook:HookClientInvoke(Remote, Method, Callback): ((...any) -> ...any)?
	local PreviousFunction = getcallbackvalue(Remote, Method)
	Remote[Method] = Callback

	return PreviousFunction
end

function Hook:MultiConnect(Remotes)
	for _, Remote in Remotes do
		Hook:ConnectClientRecive(Remote)
	end
end

function Hook:ConnectClientRecive(Remote)
	local Allowed = Process:RemoteAllowed(Remote, "Receive")
	if not Allowed then return end

	local ClassData = Process:GetClassData(Remote)
	if not ClassData then return end

	local IsRemoteFunction = ClassData.IsRemoteFunction
	local Method = ClassData.Receive[1]
	local PreviousFunction = nil

	local function Callback(...)
		return Process:ProcessRemote({
			Remote = Remote,
			Method = Method,
			OriginalFunc = PreviousFunction,
			IsReceive = true,
			MetaMethod = "Connect",
			Args = {...}
		})
	end

	if not IsRemoteFunction then
		Remote[Method]:Connect(Callback)
	else
		pcall(function()
			self:HookClientInvoke(Remote, Method, Callback)
		end)
	end
end

function Hook:BeginService(Libraries, ExtraData, ChannelId: number)
	local ReturnSpoofs = Libraries.ReturnSpoofs
	local ProcessLib = Libraries.Process
	local Communication = Libraries.Communication

	local InitData = {
		Modules = {
			ReturnSpoofs = ReturnSpoofs,
			Communication = Communication,
			Process = ProcessLib,
			Hook = self
		}
	}

	local Channel = Communication:GetChannel(ChannelId)
	Communication:Init(InitData)
	Communication:SetChannel(Channel)
	Communication:AddConnection(function(Type: string, Id: string, RemoteData)
		if Type ~= "RemoteData" then return end
		ProcessLib:SetRemoteData(Id, RemoteData)
	end)

	ProcessLib:Init(InitData)
	ProcessLib:SetChannelId(ChannelId)
	ProcessLib:SetExtraData(ExtraData)

	self:Init(InitData)
	self:HookMeta()
end

return Hook
