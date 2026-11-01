-- BeyyHub / NeedleHub Lobby Arcade diagnostic v1
-- Read-only: observes replicated state, UI, and incoming remote events.
-- Does NOT send remote requests, move the player, or change attributes.
-- F6 = snapshot; F7 = finish/export; F8 = copy current JSON.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local UserInputService=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then return warn("[Lobby Dump] LocalPlayer missing") end

local env=(type(getgenv)=="function" and getgenv()) or _G
if type(env.BeyyLobbyArcadeDumpStop)=="function" then pcall(env.BeyyLobbyArcadeDumpStop) end
local running=true
local connections={}
local started=os.clock()
local report={
    version="LOBBY_ARCADE_READONLY_V1",
    placeId=game.PlaceId,
    startedUnix=os.time(),
    executor="unknown",
    notes="Read-only client dump. FireServer success and incoming signals do not establish server reward acceptance. Outgoing remote arguments and server-only code are not captured.",
    snapshots={},
    events={},
}
pcall(function()
    if type(identifyexecutor)=="function" then report.executor=tostring(identifyexecutor()) end
end)

local function connect(signal,handler)
    local ok,conn=pcall(function() return signal:Connect(handler) end)
    if ok and conn then table.insert(connections,conn) end
end
local function path(inst)
    if not inst then return nil end
    local ok,v=pcall(function()return inst:GetFullName()end)
    return ok and v or tostring(inst)
end
local function clean(v,depth)
    depth=depth or 0
    local kind=typeof(v)
    if kind=="nil" or kind=="boolean" or kind=="number" then return v end
    if kind=="string" then return v:sub(1,300) end
    if kind=="Instance" then return {class=v.ClassName,path=path(v)} end
    if kind=="table" and depth<2 then
        local t,n={},0
        for k,item in pairs(v) do
            n+=1
            if n>30 then t.__truncated=true break end
            t[tostring(k)]=clean(item,depth+1)
        end
        return t
    end
    return tostring(v)
end
local function event(name,data)
    if not running then return end
    local e={time=math.floor((os.clock()-started)*1000)/1000,name=name,data=clean(data)}
    table.insert(report.events,e)
    if #report.events>400 then table.remove(report.events,1) end
    if name=="GemsChanged" or name=="ArcadePlayingChanged" then
        print("[Lobby Dump] "..name.." "..tostring(e.data))
    end
end
local function attrs(obj)
    if not obj then return nil end
    local ok,raw=pcall(function()return obj:GetAttributes()end)
    if not ok then return nil end
    local result={}
    for k,v in pairs(raw) do result[k]=clean(v) end
    return result
end
local function values(parent,limit)
    local data={}
    if not parent then return data end
    local ok,desc=pcall(function()return parent:GetDescendants()end)
    if not ok then return data end
    for i,obj in ipairs(desc) do
        if i>limit then break end
        if obj:IsA("ValueBase") and (obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("BoolValue")) then
            local okValue,value=pcall(function()return obj.Value end)
            if okValue then table.insert(data,{path=path(obj),value=clean(value)}) end
        end
    end
    return data
end
local function remoteList()
    local result={}
    local ok,desc=pcall(function()return ReplicatedStorage:GetDescendants()end)
    if not ok then return result end
    for _,obj in ipairs(desc) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            table.insert(result,{path=path(obj),class=obj.ClassName,attributes=attrs(obj)})
            if #result>=250 then break end
        end
    end
    return result
end
local function snapshot(label)
    local arcade=ReplicatedStorage:FindFirstChild("Arcade")
    local classes=ReplicatedStorage:FindFirstChild("ClassSystem")
    local machine=Workspace:FindFirstChild("Arcade Machine")
    local prompt=machine and machine:FindFirstChild("PlayPrompt",true)
    local screen=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    screen=screen and screen:FindFirstChild("ArcadeScreen")
    local stats=LocalPlayer:FindFirstChild("leaderstats")
    local s={
        label=label,
        t=math.floor((os.clock()-started)*1000)/1000,
        playerAttributes=attrs(LocalPlayer),
        stats=values(stats,100),
        playerValues={},
        arcade={
            folder=path(arcade), folderAttributes=attrs(arcade),
            report=path(arcade and arcade:FindFirstChild("ArcadeReport")),
            session=path(arcade and arcade:FindFirstChild("ArcadeSession")),
            machine=path(machine), prompt=path(prompt),
            promptEnabled=prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled or nil,
            promptDistance=prompt and prompt:IsA("ProximityPrompt") and prompt.MaxActivationDistance or nil,
            screen=path(screen),
            screenEnabled=screen and screen:IsA("ScreenGui") and screen.Enabled or nil,
            playerArcadePlaying=LocalPlayer:GetAttribute("ArcadePlaying")
        },
        classRoll=path(classes and classes:FindFirstChild("RollClass")),
    }
    for _,obj in ipairs(LocalPlayer:GetChildren()) do
        if obj:IsA("ValueBase") then
            table.insert(s.playerValues,{path=path(obj),value=clean(obj.Value)})
        elseif obj:IsA("Folder") and obj~=stats and (obj.Name:lower():find("data") or obj.Name:lower():find("stat") or obj.Name:lower():find("currency")) then
            for _,child in ipairs(values(obj,80)) do table.insert(s.playerValues,child) end
        end
    end
    if #report.snapshots==0 then
        s.remotes=remoteList()
        s.repStorageTop={}
        for _,obj in ipairs(ReplicatedStorage:GetChildren()) do
            table.insert(s.repStorageTop,obj.Name..":"..obj.ClassName)
        end
    end
    table.insert(report.snapshots,s)
    if #report.snapshots>100 then table.remove(report.snapshots,1) end
    print(string.format("[Lobby Dump] snapshot=%s ArcadePlaying=%s GemsAttr=%s ArcadeScreen=%s",
        label,tostring(s.arcade.playerArcadePlaying),tostring(LocalPlayer:GetAttribute("Gems")),tostring(s.arcade.screenEnabled)))
end
local function json()
    local ok,v=pcall(function()return HttpService:JSONEncode(report)end)
    return ok and v or nil
end
local function export(copyIt)
    snapshot("export")
    local data=json()
    if not data then return warn("[Lobby Dump] JSON encode failed") end
    local saved=false
    if type(writefile)=="function" then
        pcall(function()
            if type(makefolder)=="function" then makefolder("BeyyHub") end
            writefile("BeyyHub/lobby_arcade_diagnostic.json",data)
            saved=true
        end)
    end
    local copied=false
    if copyIt and type(setclipboard)=="function" then
        copied=pcall(function()setclipboard(data)end)
    end
    print(string.format("[Lobby Dump] export bytes=%d saved=%s copied=%s",#data,tostring(saved),tostring(copied)))
    if not saved and not copied then
        print("[Lobby Dump] No file/clipboard API; paste the JSON below (numbered chunks)")
        for i=1,#data,2500 do
            print(string.format("[Lobby Dump JSON %d] %s",i,data:sub(i,i+2499)))
        end
    end
end
local function stop()
    if not running then return end
    export(true)
    running=false
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end) end
    env.BeyyLobbyArcadeDumpStop=nil
    print("[Lobby Dump] stopped")
end
env.BeyyLobbyArcadeDumpStop=stop

connect(LocalPlayer:GetAttributeChangedSignal("Gems"),function()
    event("GemsChanged",LocalPlayer:GetAttribute("Gems"))
end)
connect(LocalPlayer:GetAttributeChangedSignal("ArcadePlaying"),function()
    event("ArcadePlayingChanged",LocalPlayer:GetAttribute("ArcadePlaying"))
    snapshot("ArcadePlayingChange")
end)
connect(LocalPlayer:GetAttributeChangedSignal("NeedleInputLocked"),function()
    event("NeedleInputLockedChanged",LocalPlayer:GetAttribute("NeedleInputLocked"))
end)

local watched={}
local function watchRemotes()
    local folder=ReplicatedStorage:FindFirstChild("Arcade")
    if not folder then return end
    for _,name in ipairs({"ArcadeSession","ArcadeReport"}) do
        local remote=folder:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") and not watched[remote] then
            watched[remote]=true
            connect(remote.OnClientEvent,function(...)
                local args={...}
                event(name.."_OnClientEvent",args)
            end)
            event("RemoteFound",path(remote))
        end
    end
end

connect(UserInputService.InputBegan,function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.F6 then snapshot("F6")
    elseif input.KeyCode==Enum.KeyCode.F7 then stop()
    elseif input.KeyCode==Enum.KeyCode.F8 then export(true) end
end)

snapshot("start")
watchRemotes()
task.spawn(function()
    local nextSnapshot=0
    while running do
        watchRemotes()
        if os.clock()-started>=nextSnapshot then
            snapshot("poll")
            nextSnapshot=os.clock()-started+2
        end
        task.wait(0.25)
        if os.clock()-started>=90 then
            print("[Lobby Dump] automatic 90s export")
            stop()
        end
    end
end)
print("[Lobby Dump] READ-ONLY. F6=snapshot F7=stop/save F8=copy. Auto-export after 90s.")
