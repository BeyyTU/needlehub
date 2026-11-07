-- BeyyHub / Search for the Needle COMPLETE ARCADE AUDIT v3
-- Based on repository lobby-arcade-diagnostic.lua, with richer UI snapshots.
-- Read-only: observes replicated state, UI, and incoming remote events.
-- Does NOT send remote requests, move the player, or change attributes.
-- F6 = snapshot; F7 = finish/export; F8 = copy current JSON.
local EXPECTED_PLACE_ID=77108422251420
if game.PlaceId~=EXPECTED_PLACE_ID then
    warn("[Lobby Dump] Wrong place. Search for the Needle lobby required; current PlaceId="..tostring(game.PlaceId))
    return
end
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
    version="NEEDLE_LOBBY_ARCADE_FULL_AUDIT_V3",
    placeVersion=game.PlaceVersion,
    jobId=tostring(game.JobId),
    placeId=game.PlaceId,
    startedUnix=os.time(),
    executor="unknown",
    notes="Read-only client dump. FireServer success and incoming signals do not establish server reward acceptance. Outgoing remote arguments and server-only code are not captured.",
    snapshots={},
    events={},
    quickSamples={},
    structureChanges={},
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
    if #report.events>1000 then table.remove(report.events,1) end
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
local function hierarchy(root,limit)
    if not root then return {missing=true} end
    local entries={}
    local descendants=root:GetDescendants()
    for _,obj in ipairs(descendants) do
        if #entries>=limit then break end
        local item={path=path(obj),class=obj.ClassName,attributes=attrs(obj)}
        if obj:IsA("ScreenGui") then
            item.Enabled=obj.Enabled
        elseif obj:IsA("GuiObject") then
            item.Visible=obj.Visible
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                item.Text=obj.Text:sub(1,250)
            end
        elseif obj:IsA("ProximityPrompt") then
            item.Enabled=obj.Enabled
            item.HoldDuration=obj.HoldDuration
            item.MaxActivationDistance=obj.MaxActivationDistance
            item.ActionText=obj.ActionText
            item.ObjectText=obj.ObjectText
        elseif obj:IsA("ValueBase") then
            item.Value=clean(obj.Value)
        end
        if obj:IsA("BasePart") then
            item.Position=tostring(obj.Position)
            item.Size=tostring(obj.Size)
            item.Anchored=obj.Anchored
            item.CanCollide=obj.CanCollide
            item.Transparency=obj.Transparency
        elseif obj:IsA("GuiObject") then
            item.AbsolutePosition=tostring(obj.AbsolutePosition)
            item.AbsoluteSize=tostring(obj.AbsoluteSize)
            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                item.Image=obj.Image
            end
        elseif obj:IsA("ProximityPrompt") then
            item.RequiresLineOfSight=obj.RequiresLineOfSight
            item.KeyboardKeyCode=tostring(obj.KeyboardKeyCode)
        end
        table.insert(entries,item)
    end
    return {root=path(root),entries=entries,truncated=(#descendants>limit)}
end
local function quickState()
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local gui=pg and pg:FindFirstChild("ArcadeScreen")
    local arena=gui and gui:FindFirstChild("Arena")
    local hud=arena and arena:FindFirstChild("HUD")
    local overlay=arena and arena:FindFirstChild("Overlay")
    local dim=overlay and overlay:FindFirstChild("Dim")
    local panel=dim and dim:FindFirstChild("Panel")
    local texts={}
    if hud then
        for _,name in ipairs({"Score","Wave","Health"}) do
            local frame=hud:FindFirstChild(name)
            if frame then
                local list={}
                for _,obj in ipairs(frame:GetDescendants()) do
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        table.insert(list,obj.Text:sub(1,180))
                    end
                end
                texts[name]=list
            end
        end
    end
    local leave=panel and panel:FindFirstChild("LEAVE")
    if leave and leave:IsA("TextButton") then texts.Leave=leave.Text end
    return {
        t=math.floor((os.clock()-started)*1000)/1000,
        arcadePlaying=LocalPlayer:GetAttribute("ArcadePlaying"),
        inputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),
        gems=LocalPlayer:GetAttribute("SpinUsableGems"),
        guiEnabled=gui and gui:IsA("ScreenGui") and gui.Enabled or false,
        arenaVisible=arena and arena:IsA("GuiObject") and arena.Visible or false,
        paused=dim and dim:IsA("GuiObject") and dim.Visible or false,
        texts=texts
    }
end
local function relatedObjects()
    local out={}
    for _,entry in ipairs({
        {root=Workspace,limit=15000,label="Workspace"},
        {root=ReplicatedStorage,limit=15000,label="ReplicatedStorage"},
        {root=LocalPlayer:FindFirstChildOfClass("PlayerGui"),limit=6000,label="PlayerGui"},
        {root=LocalPlayer:FindFirstChild("PlayerScripts"),limit=4000,label="PlayerScripts"},
        {root=game:GetService("StarterGui"),limit=4000,label="StarterGui"},
    }) do
        local matches={}
        if entry.root then
            local ok,desc=pcall(function()return entry.root:GetDescendants()end)
            if ok then
                for i,obj in ipairs(desc) do
                    if i>entry.limit then break end
                    local name=obj.Name:lower()
                    if name:find("arcade",1,true) or name:find("blaster",1,true)
                        or name:find("ufo",1,true) or name:find("gem",1,true) then
                        table.insert(matches,{path=path(obj),class=obj.ClassName,attributes=attrs(obj)})
                        if #matches>=200 then break end
                    end
                end
            end
        end
        out[entry.label]=matches
    end
    return out
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
        playerAttributes={
            ArcadePlaying=LocalPlayer:GetAttribute("ArcadePlaying"),
            NeedleInputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),
            SpinUsableGems=LocalPlayer:GetAttribute("SpinUsableGems"),
            GemMultiplier=LocalPlayer:GetAttribute("GemMultiplier"),
            UpgradeGemValue=LocalPlayer:GetAttribute("UpgradeGemValue")
        },
        arcadeHud=quickState(),
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
        visibleGems=LocalPlayer:GetAttribute("SpinUsableGems"),
        hasGemAttribute=LocalPlayer:GetAttribute("Gems")~=nil,
    }
    for _,obj in ipairs(LocalPlayer:GetChildren()) do
        if obj:IsA("ValueBase") then
            table.insert(s.playerValues,{path=path(obj),value=clean(obj.Value)})
        elseif obj:IsA("Folder") and obj~=stats and (obj.Name:lower():find("data") or obj.Name:lower():find("stat") or obj.Name:lower():find("currency")) then
            for _,child in ipairs(values(obj,80)) do table.insert(s.playerValues,child) end
        end
    end
    if #report.snapshots==0 or label=="F6" or label=="export"
        or label=="ArcadePlayingChange" or label=="ArcadeScreenChange" then
        s.machineHierarchy=hierarchy(machine,160)
        s.arcadeHierarchy=hierarchy(arcade,100)
        s.screenHierarchy=hierarchy(screen,160)
    end
    if #report.snapshots==0 then
        s.relatedObjects=relatedObjects()
        s.remotes=remoteList()
        s.repStorageTop={}
        for _,obj in ipairs(ReplicatedStorage:GetChildren()) do
            table.insert(s.repStorageTop,obj.Name..":"..obj.ClassName)
        end
    end
    table.insert(report.snapshots,s)
    if #report.snapshots>100 then table.remove(report.snapshots,1) end
    print(string.format("[Lobby Dump] snapshot=%s ArcadePlaying=%s SpinUsableGems=%s ArcadeScreen=%s",
        label,tostring(s.arcade.playerArcadePlaying),tostring(LocalPlayer:GetAttribute("SpinUsableGems")),tostring(s.arcade.screenEnabled)))
end
local function json()
    local ok,v=pcall(function()return HttpService:JSONEncode(report)end)
    return ok and v or nil
end
local function export(copyIt)
    snapshot("export")
    local data=json()
    if not data then return warn("[Lobby Dump] JSON encode failed") end

    -- Cache the report in the executor environment so the UI can copy it
    -- even when the executor writes files to an unexpected sandbox folder.
    env.BeyyLobbyArcadeDumpLastJSON=data

    local folderPath="BeyyHub/lobby_arcade_full_audit_v3.json"
    local rootPath="lobby_arcade_full_audit_v3.json"
    local folderSaved=false
    local rootSaved=false
    if type(writefile)=="function" then
        if type(makefolder)=="function" then
            local exists=false
            if type(isfolder)=="function" then
                local ok,result=pcall(isfolder,"BeyyHub")
                exists=ok and result==true
            end
            if not exists then pcall(makefolder,"BeyyHub") end
        end

        local function verifiedWrite(filePath)
            local ok,err=pcall(writefile,filePath,data)
            if not ok then
                warn("[Lobby Dump] writefile("..filePath..") failed: "..tostring(err))
                return false
            end
            if type(readfile)=="function" then
                local readOk,readBack=pcall(readfile,filePath)
                if not readOk or readBack~=data then
                    warn("[Lobby Dump] Could not verify report at "..filePath)
                    return false
                end
            end
            return true
        end
        folderSaved=verifiedWrite(folderPath)
        rootSaved=verifiedWrite(rootPath)
    end
    local copied=false
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if copyIt and clip then copied=pcall(clip,data) end

    print(string.format("[Lobby Dump] export bytes=%d folderSaved=%s rootSaved=%s copied=%s",
        #data,tostring(folderSaved),tostring(rootSaved),tostring(copied)))
    if folderSaved then print("[Lobby Dump] Saved in executor's file system: "..folderPath) end
    if rootSaved then print("[Lobby Dump] Saved in executor's file system: "..rootPath) end
    print("[Lobby Dump] Executor file locations may not match the Windows workspace folder.")
    if copied then
        print("[Lobby Dump] Full JSON copied. Paste directly into Notepad and save as .json.")
    elseif not folderSaved and not rootSaved then
        print("[Lobby Dump] No verified file or clipboard output; paste JSON chunks from the console.")
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
    if env.BeyyLobbyArcadeAuditEvent==auditCallback then env.BeyyLobbyArcadeAuditEvent=nil end
    if _G.BeyyLobbyArcadeAuditEvent==auditCallback then _G.BeyyLobbyArcadeAuditEvent=nil end
    print("[Lobby Dump] stopped")
end
env.BeyyLobbyArcadeDumpStop=stop

connect(LocalPlayer:GetAttributeChangedSignal("Gems"),function()
    event("GemsChanged",LocalPlayer:GetAttribute("Gems"))
end)
connect(LocalPlayer:GetAttributeChangedSignal("SpinUsableGems"),function()
    event("SpinUsableGemsChanged",LocalPlayer:GetAttribute("SpinUsableGems"))
    snapshot("SpinUsableGemsChange")
end)
connect(LocalPlayer:GetAttributeChangedSignal("ArcadePlaying"),function()
    event("ArcadePlayingChanged",LocalPlayer:GetAttribute("ArcadePlaying"))
    snapshot("ArcadePlayingChange")
end)
connect(LocalPlayer:GetAttributeChangedSignal("NeedleInputLocked"),function()
    event("NeedleInputLockedChanged",LocalPlayer:GetAttribute("NeedleInputLocked"))
end)

-- Captures only calls reported by BeyyHub's own arcade routine.
-- This does not intercept other scripts' remote calls.
local auditCallback=function(stage,details)
    event("Farm_"..tostring(stage),details)
end
env.BeyyLobbyArcadeAuditEvent=auditCallback
_G.BeyyLobbyArcadeAuditEvent=auditCallback
local watched={}
local watchedScreens={}
local function watchScreen()
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local screen=pg and pg:FindFirstChild("ArcadeScreen")
    if screen and screen:IsA("ScreenGui") and not watchedScreens[screen] then
        watchedScreens[screen]=true
        connect(screen:GetPropertyChangedSignal("Enabled"),function()
            event("ArcadeScreenEnabled",screen.Enabled)
            snapshot("ArcadeScreenChange")
        end)
    end
end
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
watchScreen()
-- Track UI/score/health/reward text changes while the game is active.
task.spawn(function()
    local signature
    while running do
        local state=quickState()
        local ok,nextSignature=pcall(function()
            return HttpService:JSONEncode({state.arcadePlaying,state.inputLocked,
                state.gems,state.guiEnabled,state.arenaVisible,state.paused,state.texts})
        end)
        if ok and signature~=nextSignature then
            signature=nextSignature
            table.insert(report.quickSamples,state)
            if #report.quickSamples>450 then table.remove(report.quickSamples,1) end
        end
        task.wait(0.2)
    end
end)
for _,root in ipairs({
    Workspace:FindFirstChild("Arcade Machine"),
    ReplicatedStorage:FindFirstChild("Arcade"),
    LocalPlayer:FindFirstChildOfClass("PlayerGui")
}) do
    if root then
        connect(root.DescendantAdded,function(obj)
            if root:IsDescendantOf(game) then
                local name=obj.Name:lower()
                if root.Name~="PlayerGui" or name:find("arcade",1,true) then
                    event("ObjectAdded",{path=path(obj),class=obj.ClassName})
                end
            end
        end)
        connect(root.DescendantRemoving,function(obj)
            if root.Name~="PlayerGui" or obj.Name:lower():find("arcade",1,true) then
                event("ObjectRemoved",{path=path(obj),class=obj.ClassName})
            end
        end)
    end
end
task.spawn(function()
    local nextSnapshot=0
    while running do
        watchRemotes()
        watchScreen()
        if os.clock()-started>=nextSnapshot then
            snapshot("poll")
            nextSnapshot=os.clock()-started+2
        end
        task.wait(0.25)
        if os.clock()-started120 then
            print("[Lobby Dump] automatic 120s export")
            stop()
        end
    end
end)
print("[Lobby Dump] READ-ONLY. F6=snapshot F7=stop/save F8=copy. Auto-export after 120s.")

-- END OF COMPLETE SCRIPT: NEEDLE_LOBBY_ARCADE_FULL_AUDIT_V3
