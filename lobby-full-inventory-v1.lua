-- BEYY_LOBBY_FULL_INVENTORY_V1
-- Complete client-visible Search for the Needle lobby inventory.
-- Read-only: does not FireServer, InvokeServer, change the game, or require modules.
-- No client dump can reveal server-only handlers or previous server-side rules.
local PLACE_ID=77108422251420
if game.PlaceId~=PLACE_ID then
    warn("[Beyy Lobby Inventory] Wrong place: "..tostring(game.PlaceId))
    return
end
local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then
    warn("[Beyy Lobby Inventory] LocalPlayer unavailable")
    return
end
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end
if type(env.BeyyLobbyFullDumpStop)=="function" then
    pcall(env.BeyyLobbyFullDumpStop)
end
local running=true
local started=os.clock()
local connections={}
local report={
    signature="BEYY_LOBBY_FULL_INVENTORY_V1",
    description="Read-only client-visible lobby inventory and baseline remote comparison.",
    limitations="ServerScriptService, server remote handlers, ModuleScript.Source and remote arguments sent by unrelated scripts are not included. Changed server validation can keep identical remotes.",
    placeId=game.PlaceId,
    placeVersion=game.PlaceVersion,
    startedUnix=os.time(),
    rootLimit=50000,
    pathBudget=28000,
    captures={},
    changes={},
    baseline={
        description="The 68 ReplicatedStorage remote paths and types present in four user captures of lobby placeVersion 2062, November 7 2026",
        placeVersion=2062,
        expectedCount=68,
    },
    errors={},
}
local function safePath(x)
    local ok,v=pcall(function()return x:GetFullName()end)
    return ok and v or tostring(x)
end
local function connect(signal,callback)
    local ok,c=pcall(function()return signal:Connect(callback)end)
    if ok and c then table.insert(connections,c) end
end
local function encodeValue(v)
    local t=typeof(v)
    if t=="nil" or t=="number" or t=="boolean" then return v end
    if t=="string" then return v:sub(1,300) end
    return tostring(v)
end
local function attrs(x)
    local out={}
    local ok,v=pcall(function()return x:GetAttributes()end)
    if not ok then return out end
    for k,raw in pairs(v) do
        local lk=k:lower()
        if not (lk:find("token",1,true) or lk:find("secret",1,true)
            or lk:find("password",1,true) or lk:find("cookie",1,true)
            or lk:find("authorization",1,true)) then
            out[k]=encodeValue(raw)
        end
    end
    return out
end
local function isRemote(x)
    return x:IsA("RemoteEvent") or x:IsA("RemoteFunction")
        or x:IsA("UnreliableRemoteEvent")
end
local function importantRow(x)
    local result={path=safePath(x),class=x.ClassName,name=x.Name,attributes=attrs(x)}
    if x:IsA("ProximityPrompt") then
        result.enabled=x.Enabled
        result.actionText=x.ActionText
        result.objectText=x.ObjectText
        result.maxActivationDistance=x.MaxActivationDistance
        result.holdDuration=x.HoldDuration
        result.requiresLineOfSight=x.RequiresLineOfSight
    elseif x:IsA("ScreenGui") or x:IsA("SurfaceGui") then
        result.enabled=x.Enabled
    elseif x:IsA("GuiObject") then
        result.visible=x.Visible
        if x:IsA("TextLabel") or x:IsA("TextBox") or x:IsA("TextButton") then
            result.text=x.Text:sub(1,240)
        end
    elseif x:IsA("BoolValue") or x:IsA("StringValue")
        or x:IsA("IntValue") or x:IsA("NumberValue") then
        result.value=encodeValue(x.Value)
    end
    return result
end
local function arcadeState()
    local pgui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local screen=pgui and pgui:FindFirstChild("ArcadeScreen")
    local arena=screen and screen:FindFirstChild("Arena")
    local machine=Workspace:FindFirstChild("Arcade Machine")
    local prompt=machine and machine:FindFirstChild("PlayPrompt",true)
    return {
        t=math.floor((os.clock()-started)*1000)/1000,
        arcadePlaying=LocalPlayer:GetAttribute("ArcadePlaying"),
        inputLocked=LocalPlayer:GetAttribute("NeedleInputLocked"),
        spinUsableGems=LocalPlayer:GetAttribute("SpinUsableGems"),
        screenExists=screen~=nil,
        screenEnabled=screen and screen:IsA("ScreenGui") and screen.Enabled or false,
        arenaVisible=arena and arena:IsA("GuiObject") and arena.Visible or false,
        machineArcadePlayers=machine and machine:GetAttribute("ArcadePlayers"),
        promptExists=prompt~=nil,
        promptEnabled=prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled or false,
    }
end
-- Historical client-visible ReplicatedStorage remotes; not server behavior.
local baseline={
    ["Arcade.ArcadeReport"]="RemoteEvent",
    ["Arcade.ArcadeSession"]="RemoteEvent",
    ["ClanSystem.ClanEvent"]="RemoteEvent",
    ["ClanSystem.ClanRequest"]="RemoteFunction",
    ["ClanSystem.OpenClanChest"]="RemoteFunction",
    ["ClassSystem.RollClass"]="RemoteFunction",
    ["ClassSystem.SelectClassSlot"]="RemoteFunction",
    ["ClassSystem.SelectLimitedClass"]="RemoteFunction",
    ["ClassSystem.WatchLuckAd"]="RemoteEvent",
    ["CodeSystem.RedeemCode"]="RemoteFunction",
    ["CommunityHarvestState.Milestone"]="RemoteEvent",
    ["Events.AdminEvents.AdminBan"]="RemoteFunction",
    ["Events.AdminEvents.AdminCheck"]="RemoteFunction",
    ["Events.AdminEvents.AdminCommunityHarvest"]="RemoteFunction",
    ["Events.AdminEvents.AdminEventControl"]="RemoteEvent",
    ["Events.AdminEvents.AdminPlayerData"]="RemoteFunction",
    ["Events.AdminEvents.AdminSendGlobalMessage"]="RemoteEvent",
    ["Events.AdminEvents.AdminTestDiscord"]="RemoteEvent",
    ["Events.GlobalEvents.GlobalMessageEvent"]="RemoteEvent",
    ["Events.GlobalEvents.HalloweenThunder"]="RemoteEvent",
    ["GamepassShop.GetGiftRecipients"]="RemoteFunction",
    ["GamepassShop.RequestGift"]="RemoteFunction",
    ["GardenSystem.Garden"]="RemoteFunction",
    ["GardenSystem.ViewGarden"]="RemoteFunction",
    ["HayIndexReward"]="RemoteFunction",
    ["MasterySystem.Request"]="RemoteFunction",
    ["MerchantSystem.Merchant"]="RemoteFunction",
    ["Packages.DataServiceTyped.Networker._remotes.DataService.RemoteEvent"]="RemoteEvent",
    ["Packages.DataServiceTyped.Networker._remotes.DataService.RemoteFunction"]="RemoteFunction",
    ["PetSystem.EquipPet"]="RemoteFunction",
    ["PetSystem.PetMenu"]="RemoteFunction",
    ["SettingsSystem.ChangeSetting"]="RemoteEvent",
    ["SkinSystem.EquipSkin"]="RemoteFunction",
    ["SoundManager.Remotes.PlaySound"]="RemoteEvent",
    ["SoundManager.Remotes.PlaySoundAtPosition"]="RemoteEvent",
    ["TitleSystem.EquipTitle"]="RemoteEvent",
}
for _,name in ipairs({
    "AnimationService","DailyRewards","EffectService","GroupReward",
    "InformationService","LoadingUIService","MonetizationService",
    "PartyService","PlayerStats","ScreenEffectService","ShopUI",
    "SoundService","StatBoard","TimeBoard","UpdateReward","WeeklyRewards",
}) do
    local prefix="Packages.Networker._remotes."..name.."."
    baseline[prefix.."RemoteEvent"]="RemoteEvent"
    baseline[prefix.."RemoteFunction"]="RemoteFunction"
end
local baselineCount=0
for _ in pairs(baseline) do baselineCount+=1 end
report.baseline.embeddedCount=baselineCount
local function diffRemotes(remotes)
    local observed={}
    local otherLocations={}
    for _,r in ipairs(remotes) do
        local prefix="ReplicatedStorage."
        if r.path:sub(1,#prefix)==prefix then
            observed[r.path:sub(#prefix+1)]=r.class
        else
            table.insert(otherLocations,r)
        end
    end
    local diff={added={},removed={},changedType={},otherLocations=otherLocations,
        currentReplicatedStorageCount=0,baselineCount=baselineCount}
    for p,cls in pairs(observed) do
        diff.currentReplicatedStorageCount+=1
        if not baseline[p] then
            table.insert(diff.added,{path="ReplicatedStorage."..p,class=cls})
        elseif baseline[p]~=cls then
            table.insert(diff.changedType,{path="ReplicatedStorage."..p,old=baseline[p],new=cls})
        end
    end
    for p,cls in pairs(baseline) do
        if not observed[p] then table.insert(diff.removed,{path="ReplicatedStorage."..p,class=cls}) end
    end
    local byPath=function(a,b)return a.path<b.path end
    table.sort(diff.added,byPath)
    table.sort(diff.removed,byPath)
    table.sort(diff.changedType,byPath)
    table.sort(diff.otherLocations,byPath)
    return diff
end
local function roots()
    local rootsToScan={
        {name="ReplicatedStorage",root=ReplicatedStorage},
        {name="Workspace",root=Workspace},
        {name="ReplicatedFirst",root=game:GetService("ReplicatedFirst")},
        {name="StarterGui",root=game:GetService("StarterGui")},
        {name="StarterPlayer",root=game:GetService("StarterPlayer")},
        {name="StarterPack",root=game:GetService("StarterPack")},
        {name="Lighting",root=game:GetService("Lighting")},
        {name="SoundService",root=game:GetService("SoundService")},
        {name="Teams",root=game:GetService("Teams")},
        {name="TextChatService",root=game:GetService("TextChatService")},
        {name="LocalPlayer.PlayerGui",root=LocalPlayer:FindFirstChildOfClass("PlayerGui")},
        {name="LocalPlayer.PlayerScripts",root=LocalPlayer:FindFirstChild("PlayerScripts")},
        {name="LocalPlayer.Backpack",root=LocalPlayer:FindFirstChildOfClass("Backpack")},
    }
    return rootsToScan
end
local function inventory()
    local result={
        roots={},remotes={},scripts={},bindables={},prompts={},
        arcadeRelated={},paths={},arcadeRoots={},
        remoteDiff={},state=arcadeState(),scanned=0,
        pathTruncated=false,
    }
    local pathBudget=report.pathBudget
    for _,entry in ipairs(roots()) do
        if not running then break end
        local info={root=entry.name,count=0,classCounts={},truncated=false}
        table.insert(result.roots,info)
        if entry.root then
            local ok,desc=pcall(function()return entry.root:GetDescendants()end)
            if ok then
                info.totalDescendants=#desc
                for i,obj in ipairs(desc) do
                    if i>report.rootLimit then info.truncated=true break end
                    info.count+=1
                    result.scanned+=1
                    info.classCounts[obj.ClassName]=(info.classCounts[obj.ClassName] or 0)+1
                    if pathBudget>0 then
                        table.insert(result.paths,safePath(obj))
                        pathBudget-=1
                    else
                        result.pathTruncated=true
                    end
                    local name=obj.Name:lower()
                    local interesting=name:find("arcade",1,true)
                        or name:find("blaster",1,true)
                        or name:find("gem",1,true)
                    if isRemote(obj) then
                        table.insert(result.remotes,importantRow(obj))
                    elseif obj:IsA("ModuleScript") or obj:IsA("LocalScript") or obj:IsA("Script") then
                        if #result.scripts<6000 then
                            table.insert(result.scripts,importantRow(obj))
                        end
                    elseif obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                        if #result.bindables<2000 then
                            table.insert(result.bindables,importantRow(obj))
                        end
                    elseif obj:IsA("ProximityPrompt") then
                        if #result.prompts<3000 then
                            table.insert(result.prompts,importantRow(obj))
                        end
                    end
                    if interesting and #result.arcadeRelated<3000 then
                        table.insert(result.arcadeRelated,importantRow(obj))
                    end
                    if i%1500==0 then task.wait() end
                end
            else
                info.error="Unable to list descendants"
                table.insert(report.errors,entry.name.." scan failed")
            end
        else
            info.error="Not replicated or not loaded"
        end
    end
    local cmp=function(a,b)return a.path<b.path end
    table.sort(result.remotes,cmp)
    table.sort(result.scripts,cmp)
    table.sort(result.prompts,cmp)
    table.sort(result.bindables,cmp)
    table.sort(result.arcadeRelated,cmp)
    table.sort(result.paths)
    result.remoteDiff=diffRemotes(result.remotes)
    -- Expanded arcade-specific GUI/object trees with their public properties.
    for _,entry in ipairs({
        {name="ReplicatedStorage.Arcade",instance=ReplicatedStorage:FindFirstChild("Arcade")},
        {name="Workspace.Arcade Machine",instance=Workspace:FindFirstChild("Arcade Machine")},
        {name="PlayerGui.ArcadeScreen",instance=LocalPlayer:FindFirstChildOfClass("PlayerGui")
            and LocalPlayer:FindFirstChildOfClass("PlayerGui"):FindFirstChild("ArcadeScreen")},
    }) do
        local items={}
        if entry.instance then
            table.insert(items,importantRow(entry.instance))
            local ok,desc=pcall(function()return entry.instance:GetDescendants()end)
            if ok then
                for i,obj in ipairs(desc) do
                    if i>1500 then break end
                    table.insert(items,importantRow(obj))
                end
            end
        end
        result.arcadeRoots[entry.name]=items
    end
    return result
end
local function addCapture(label)
    if not running and label~="stop" then return end
    print("[Beyy Lobby Inventory] Scanning "..label.." (client-visible only)...")
    local ok,snapshot=pcall(inventory)
    if not ok then
        table.insert(report.errors,"Capture "..label..": "..tostring(snapshot))
        warn("[Beyy Lobby Inventory] Scan failed: "..tostring(snapshot))
        return
    end
    table.insert(report.captures,{
        label=label,t=math.floor((os.clock()-started)*1000)/1000,
        data=snapshot,
    })
    local d=snapshot.remoteDiff
    print(string.format("[Beyy Lobby Inventory] %s objects=%d remote=%d RS=%d added=%d removed=%d typeChanged=%d elsewhere=%d pathsTruncated=%s",
        label,snapshot.scanned,#snapshot.remotes,d.currentReplicatedStorageCount,
        #d.added,#d.removed,#d.changedType,#d.otherLocations,
        tostring(snapshot.pathTruncated)))
    for _,x in ipairs(d.added) do print("[Beyy Lobby Inventory] Added "..x.path) end
    for _,x in ipairs(d.removed) do print("[Beyy Lobby Inventory] Missing "..x.path) end
    for _,x in ipairs(d.changedType) do
        print("[Beyy Lobby Inventory] Type changed "..x.path.." "..x.old.." -> "..x.new)
    end
end
local function save()
    local ok,encoded=pcall(function()return HttpService:JSONEncode(report)end)
    if not ok then return warn("[Beyy Lobby Inventory] JSON encode error: "..tostring(encoded)) end
    env.BeyyLobbyFullDumpLastJSON=encoded
    local outputs={"BeyyHub/lobby_full_inventory_v1.json","lobby_full_inventory_v1.json"}
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end)
    end
    local written={}
    for _,file in ipairs(outputs) do
        if type(writefile)=="function" then
            local didWrite,err=pcall(writefile,file,encoded)
            if didWrite and type(readfile)=="function" then
                local verified,content=pcall(readfile,file)
                if not verified or content~=encoded then didWrite=false end
            end
            table.insert(written,{path=file,verified=didWrite})
            if not didWrite then warn("[Beyy Lobby Inventory] Save failed "..file..": "..tostring(err)) end
        end
    end
    local clip=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    local copied=false
    if clip then copied=pcall(clip,encoded) end
    print(string.format("[Beyy Lobby Inventory] Exported %d bytes; clipboard=%s; captures=%d",
        #encoded,tostring(copied),#report.captures))
    for _,x in ipairs(written) do
        print("[Beyy Lobby Inventory] "..x.path.." verified="..tostring(x.verified))
    end
    if not copied and #written==0 then
        warn("[Beyy Lobby Inventory] Neither file API nor clipboard API is available.")
    end
end
local function stop()
    if not running then return end
    addCapture("stop")
    running=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    env.BeyyLobbyFullDumpStop=nil
    save()
    print("[Beyy Lobby Inventory] Stopped")
end
env.BeyyLobbyFullDumpStop=stop
connect(LocalPlayer:GetAttributeChangedSignal("ArcadePlaying"),function()
    if running then
        table.insert(report.changes,{t=os.clock()-started,event="ArcadePlaying",value=encodeValue(LocalPlayer:GetAttribute("ArcadePlaying"))})
    end
end)
connect(LocalPlayer:GetAttributeChangedSignal("SpinUsableGems"),function()
    if running then
        table.insert(report.changes,{t=os.clock()-started,event="SpinUsableGems",value=LocalPlayer:GetAttribute("SpinUsableGems")})
    end
end)
for _,entry in ipairs(roots()) do
    if entry.root then
        connect(entry.root.DescendantAdded,function(obj)
            if running and isRemote(obj) then
                table.insert(report.changes,{t=os.clock()-started,event="RemoteAdded",object=importantRow(obj)})
            end
        end)
        connect(entry.root.DescendantRemoving,function(obj)
            if running and isRemote(obj) then
                table.insert(report.changes,{t=os.clock()-started,event="RemoteRemoving",path=safePath(obj),class=obj.ClassName})
            end
        end)
    end
end
addCapture("start")
print("[Beyy Lobby Inventory] Ready. Click Entire Lobby Dump again to stop and export.")
task.delay(120,function()
    if running then
        print("[Beyy Lobby Inventory] Automatic export after 120 seconds")
        stop()
    end
end)
-- END BEYY_LOBBY_FULL_INVENTORY_V1