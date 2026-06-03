type table = {
    [any]: any
}

--// Module
local Module = {
    CommCallbacks = {}
}

local CommWrapper = {}
CommWrapper.__index = CommWrapper

--// Serializer cache
local SerializeCache = setmetatable({}, {__mode = "k"})
local DeserializeCache = setmetatable({}, {__mode = "k"})

--// Services
local CoreGui

--// Modules
local Hook
local Channel
local Config
local Process

function Module:Init(Data)
    local Modules = Data.Modules
    local Services = Data.Services

    Hook = Modules.Hook
    Process = Modules.Process
    Config = Modules.Config or Config
    CoreGui = Services.CoreGui
end

function CommWrapper:Fire(...)
    local Queue = self.Queue
    table.insert(Queue, {...})
end

function CommWrapper:ProcessArguments(Arguments) 
    local Channel = self.Channel
    Channel:Fire(Process:Unpack(Arguments))
end

function CommWrapper:ProcessQueue()
    local Queue = self.Queue

    for Index = 1, #Queue do
        local Arguments = table.remove(Queue)
        pcall(function()
            self:ProcessArguments(Arguments) 
        end)
    end
end

function CommWrapper:BeginQueueService()
    coroutine.wrap(function()
        while wait() do
            self:ProcessQueue()
        end
    end)()
end

function Module:NewCommWrap(Channel: BindableEvent)
    local Base = {
        Queue = setmetatable({}, {__mode = "v"}),
        Channel = Channel,
        Event = Channel.Event
    }

    --// Create new wrapper class
    local Wrapped = setmetatable(Base, CommWrapper)
    Wrapped:BeginQueueService()

    return Wrapped
end

function Module:MakeDebugIdHandler(): BindableFunction
    --// Using BindableFunction as it does not require a thread permission change
    local Remote = Instance.new("BindableFunction")
    function Remote.OnInvoke(Object: Instance): string
        return Object:GetDebugId()
    end

    self.DebugIdRemote = Remote
    self.DebugIdInvoke = Remote.Invoke

    return Remote
end

function Module:GetDebugId(Object: Instance): string
    local Invoke = self.DebugIdInvoke
    local Remote = self.DebugIdRemote
    local success, id = pcall(Invoke, Remote, Object)
    if success and id then
        return id
    end

    local fallbackSuccess, fallbackId = pcall(function()
        return Object:GetDebugId()
    end)
    if fallbackSuccess and fallbackId then
        return fallbackId
    end

	return tostring(Object)
end

function Module:GetHiddenParent(): Instance
    --// Use gethui if it exists
    if gethui then
        local success, parent = pcall(gethui)
        if success and parent then
            return parent
        end
    end

    return CoreGui
end

function Module:CreateCommChannel(): (number, BindableEvent)
    --// Use native if it exists
    local Force = Config.ForceUseCustomComm
    if create_comm_channel and not Force then
        return create_comm_channel()
    end

    local Parent = self:GetHiddenParent()
    local ChannelId = math.random(1, 10000000)

    --// BindableEvent
    local Channel = Instance.new("BindableEvent", Parent)
    Channel.Name = ChannelId

    return ChannelId, Channel
end

function Module:GetCommChannel(ChannelId: number): BindableEvent?
    --// Use native if it exists
    local Force = Config.ForceUseCustomComm
    if get_comm_channel and not Force then
        local Channel = get_comm_channel(ChannelId)
        return Channel, false
    end

    local Parent = self:GetHiddenParent()
    local Channel = Parent:FindFirstChild(ChannelId)
    if not Channel then return end

    --// Wrap the channel (Prevents thread permission errors)
    local Wrapped = self:NewCommWrap(Channel)
    return Wrapped, true
end

function Module:CheckValue(Value, Inbound: boolean?)
     --// No serializing  needed
    if typeof(Value) ~= "table" then 
        return Value 
    end
   
    --// Deserialize
    if Inbound then
        return self:DeserializeTable(Value)
    end

    --// Serialize
    return self:SerializeTable(Value)
end

local Tick = 0
function Module:WaitCheck()
    Tick += 1
    if Tick > 40 then
        Tick = 0 -- I could use modulus here but the interger will be massive
        wait()
    end
end

function Module:MakePacket(Index, Value): table
    self:WaitCheck()
    return {
        Index = self:CheckValue(Index), 
        Value = self:CheckValue(Value)
    }
end

function Module:ReadPacket(Packet: table): (any, any)
    if typeof(Packet) ~= "table" then return Packet end
    
    local Key = self:CheckValue(Packet.Index, true)
    local Value = self:CheckValue(Packet.Value, true)
    self:WaitCheck()

    return Key, Value
end

function Module:SerializeTable(Table: table): table
    --// Check cache for existing
    local Cached = SerializeCache[Table]
    if Cached then return Cached end

    local Serialized = {}
    SerializeCache[Table] = Serialized

    for Index, Value in next, Table do
        local Packet = self:MakePacket(Index, Value)
        table.insert(Serialized, Packet)
    end

    return Serialized
end

function Module:DeserializeTable(Serialized: table): table
    --// Check for cached
    local Cached = DeserializeCache[Serialized]
    if Cached then return Cached end

    local Table = {}
    DeserializeCache[Serialized] = Table
    
    for _, Packet in next, Serialized do
        local Index, Value = self:ReadPacket(Packet)
        if Index == nil then continue end

        Table[Index] = Value
    end

    return Table
end

function Module:SetChannel(NewChannel: number)
    Channel = NewChannel
end

function Module:ConsolePrint(...)
    self:Communicate("Print", ...)
end

function Module:QueueLog(Data)
    spawn(function()
        local SerializedArgs = self:SerializeTable(Data.Args)
        Data.Args = SerializedArgs

        self:Communicate("QueueLog", Data)
    end)
end

function Module:AddCommCallback(Type: string, Callback: (...any) -> ...any)
    local CommCallbacks = self.CommCallbacks
    CommCallbacks[Type] = Callback
end

function Module:GetCommCallback(Type: string): (...any) -> ...any
    local CommCallbacks = self.CommCallbacks
    return CommCallbacks[Type]
end

function Module:ChannelIndex(Channel, Property: string)
    if typeof(Channel) == "Instance" then
        return Hook:Index(Channel, Property)
    end

    --// Some executors return a UserData type
    return Channel[Property]
end

function Module:Communicate(...)
    local Fire = self:ChannelIndex(Channel, "Fire")
    local identity = getthreadidentity()
    setthreadidentity(8)
    Fire(Channel, ...)
    setthreadidentity(identity)
end

function Module:AddConnection(Callback): RBXScriptConnection
    local Event = self:ChannelIndex(Channel, "Event")
    return Event:Connect(Callback)
end

function Module:AddTypeCallback(Type: string, Callback): RBXScriptConnection
    local Event = self:ChannelIndex(Channel, "Event")
    return Event:Connect(function(RecivedType: string, ...)
        if RecivedType ~= Type then return end
        Callback(...)
    end)
end

function Module:AddTypeCallbacks(Types: table)
    for Type: string, Callback in next, Types do
        self:AddTypeCallback(Type, Callback)
    end
end

function Module:CreateChannel(): number
    local ChannelID, Event = self:CreateCommChannel()

    --// Connect GetCommCallback function
    Event.Event:Connect(function(Type: string, ...)
        local Callback = self:GetCommCallback(Type)
        if Callback then
            Callback(...)
        end
    end)

    return ChannelID, Event
end

Module:MakeDebugIdHandler()

return Module
