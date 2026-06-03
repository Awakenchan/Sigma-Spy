type table = {
	[any]: any
}

--// Module
local Files = {
	UseWorkspace = false,
	Folder = "Sigma spy",
	RepoUrl = nil,
	FolderStructure = {
		["Sigma Spy"] = {
			"assets",
		}
	}
}

--// Services
local HttpService: HttpService

local function getRequest()
	local httpLibrary = http
	return request or http_request or (httpLibrary and httpLibrary.request)
end

function Files:Init(Data)
	local FolderStructure = self.FolderStructure
    local Services = Data.Services

    HttpService = Services.HttpService

	--// Check if the folders need to be created
	self:CheckFolders(FolderStructure)
end

function Files:PushConfig(Config: table)
	for Key, Value in next, Config do
		self[Key] = Value
	end
end

function Files:UrlFetch(Url: string): string
	--// Request data
    local Final = {
        Url = Url:gsub(" ", "%%20"),
        Method = 'GET'
    }

	 --// Send HTTP request
    local Request = getRequest()
    local Success, Responce
    if Request then
        Success, Responce = pcall(Request, Final)
    end

    --// Error check
    if not Success or not Responce then
        local HttpSuccess, Body = pcall(function()
            return game:HttpGet(Final.Url)
        end)

        if HttpSuccess then
            return Body
        end

        warn("[!] HTTP request error! Check console (F9)")
        warn("> Url:", Url)
        return ""
    end

    local Body = Responce.Body or Responce.body or ""
    local StatusCode = Responce.StatusCode or Responce.status

	--// Status code check
    if StatusCode == 404 then
        warn("[!] The file requested has moved or been deleted.")
        warn(" >", Url)
        return ""
    end

    return Body, Responce
end

function Files:MakePath(Path: string)
	local Folder = self.Folder
	return `{Folder}/{Path}`
end

function Files:LoadCustomasset(Path: string): string?
	if not getcustomasset then return end
	if not readfile then return end
	if not Path then return end

	--// Check content
	local ReadSuccess, Content = pcall(readfile, Path)
	if not ReadSuccess then return end
	if #Content <= 0 then return end

	--// Load custom AssetId
	local Success, AssetId = pcall(getcustomasset, Path)
	
	if not Success then return end
	if not AssetId or #AssetId <= 0 then return end

	return AssetId
end

function Files:GetFile(Path: string, CustomAsset: boolean?): string?
	local RepoUrl = self.RepoUrl
	local UseWorkspace = self.UseWorkspace

	local LocalPath = self:MakePath(Path)
	local Content = ""

	--// Check if the files should be fetched from the workspace instead
	if UseWorkspace then
		local Success, Result = readfile and pcall(readfile, LocalPath)
		Content = Success and Result or ""
	else
		--// Download with a HTTP request
		Content = self:UrlFetch(`{RepoUrl}/{Path}`)
	end

	--// Custom asset
	if CustomAsset then
		--// Check if the file should be written to
		local Written = self:FileCheck(LocalPath, function()
			return Content
		end)
		if not Written then return end

		return self:LoadCustomasset(LocalPath)
	end

	return Content
end

function Files:GetTemplate(Name: string): string
    return self:GetFile(`templates/{Name}.lua`)
end

function Files:FileCheck(Path: string, Callback)
	if not isfile or not writefile then return false end

	local CheckSuccess, Exists = pcall(isfile, Path)
	if CheckSuccess and Exists then return true end

	--// Create and write the template to the missing file
	local Template = Callback()
	local WriteSuccess = pcall(writefile, Path, Template)
	return WriteSuccess
end

function Files:FolderCheck(Path: string)
	if not isfolder or not makefolder then return false end

	local CheckSuccess, Exists = pcall(isfolder, Path)
	if CheckSuccess and Exists then return true end

	local MakeSuccess = pcall(makefolder, Path)
	return MakeSuccess
end

function Files:CheckPath(Parent: string, Child: string)
	return Parent and `{Parent}/{Child}` or Child
end

function Files:CheckFolders(Structure: table, Path: string?)
	for ParentName, Name in next, Structure do
		--// Check existance of the parent folder
		if typeof(Name) == "table" then
			local NewPath = self:CheckPath(Path, ParentName)
			self:FolderCheck(NewPath)
			self:CheckFolders(Name, NewPath)
			continue
		end

		--// Check existance of child folder
		local FolderPath = self:CheckPath(Path, Name)
		self:FolderCheck(FolderPath)
	end
end

function Files:TemplateCheck(Path: string, TemplateName: string)
	return self:FileCheck(Path, function()
		return self:GetTemplate(TemplateName)
	end)
end

function Files:GetAsset(Name: string, CustomAsset: boolean?): string
    return self:GetFile(`assets/{Name}`, CustomAsset)
end

function Files:GetModule(Name: string, TemplateName: string): string
	local Path = `{Name}.lua`

	--// The file will be declared local if the template argument is provided
	if TemplateName then
		local HasTemplateFile = self:TemplateCheck(Path, TemplateName)

		--// Check if it successfuly loads
		if HasTemplateFile and readfile then
			local ReadSuccess, Content = pcall(readfile, Path)
			local Success = ReadSuccess and loadstring(Content)
			if Success then return Content end
		end

		return self:GetTemplate(TemplateName)
	end

	return self:GetFile(Path)
end

function Files:LoadLibraries(Scripts: table, ...): table
	local Modules = {}
	for Name, Content in next, Scripts do
		--// Base64 format
		local IsBase64 = typeof(Content) == "table" and Content[1] == "base64"
		Content = IsBase64 and Content[2] or Content

		--// Tables
		if typeof(Content) ~= "string" and not IsBase64 then 
			Modules[Name] = Content
			continue 
		end

		--// Decode Base64
		if IsBase64 then
			Content = crypt.base64decode(Content)
			Scripts[Name] = Content
		end

		--// Compile library 
		local Closure, Error = loadstring(Content, Name)
		assert(Closure, `Failed to load {Name}: {Error}`)

		Modules[Name] = Closure(...)
	end
	return Modules
end

function Files:LoadModules(Modules: {}, Data: {})
    for Name, Module in next, Modules do
        local Init = Module.Init
        if not Init then continue end

		--// Invoke :Init function 
        Module:Init(Data)
    end
end

function Files:CreateFont(Name: string, AssetId: string): string?
	if not AssetId then return end
	if not writefile then return end

	--// Custom font Json
	local FileName = `assets/{Name}.json`
	local JsonPath = self:MakePath(FileName)
	local Data = {
		name = Name,
		faces = {
			{
				name = "Regular",
				weight = 400,
				style = "Normal",
				assetId = AssetId
			}
		}
	}

	--// Write Json
	local Json = HttpService:JSONEncode(Data)
	local Success = pcall(writefile, JsonPath, Json)
	if not Success then return end

	return JsonPath
end

function Files:CompileModule(Scripts): string
    local Out = "local Libraries = {"
    for Name, Content in Scripts do
		if typeof(Content) ~= "string" then continue end
        Out ..= `	{Name} = (function()\n{Content}\nend)(),\n`
    end
	Out ..= "}"
    return Out
end

function Files:MakeActorScript(Scripts, ChannelId: number): string
	local ActorCode = Files:CompileModule(Scripts)
	ActorCode ..= [[
	local ExtraData = {
		IsActor = true
	}
	]]
	ActorCode ..= `Libraries.Hook:BeginService(Libraries, ExtraData, {ChannelId})`
	return ActorCode
end

return Files
