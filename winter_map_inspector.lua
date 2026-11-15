-- BeyyHub Winter Map Inspector v1.0 — standalone, read-only diagnostics
-- Christmas! PlaceId 87963815262778
-- Immediately copies JSON to clipboard, then refreshes after 30 seconds.
-- F8 = copy current report; F9 = copy final report and stop.
-- Also saves BeyyHub/winter_full_dump.json when writefile is available.
-- Does NOT fire/invoke remotes, change gameplay attributes or hook outgoing calls.

if game.PlaceId ~= 87963815262778 then
    warn("[Winter Inspector] Wrong map: "..tostring(game.PlaceId))
    return
end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local UIS=game:GetService("UserInputService")
local HS=game:GetService("HttpService")
local CS=game:GetService("CollectionService")
local player=Players.LocalPlayer
if not player then return end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.__BEYY_WINTER_INSPECTOR_STOP)=="function" then
    pcall(env.__BEYY_WINTER_INSPECTOR_STOP,false)
end

local alive=true
local started=os.clock()
local connections={}
local remoteSeen=setmetatable({},{__mode="k"})
local remotes={}
local counts={}
local samples={}
local events={}
local transitions={}
local previous={}
local discovered={}
local duplicateNames={}
local scanned={}
local connected=0
local busy=false
local MAX_ROOT=42000
local MAX_TOTAL=95000
local MAX_REMOTES=1200
local MAX_LISTENERS=700
local MAX_EVENTS=260
local MAX_WORLD=450
local function location(v)
    if not v then return "<nil>" end
    local ok,name=pcall(function()return v:GetFullName()end)
    return ok and name or "<removed>"
end
local function serialize(v,depth,visited)
    depth=depth or 0
    local kind=typeof(v)
    if kind=="nil" then return "<nil>" end
    if kind=="Instance" then return {path=location(v),class=v.ClassName} end
    if kind=="number" then
        return (v==v and v~=math.huge and v~=-math.huge) and v or tostring(v)
    end
    if kind=="string" then
        return #v>250 and v:sub(1,250).."...[truncated]" or v
    end
    if kind=="boolean" then return v end
    if kind=="table" then
        if depth>=4 then return "<max depth>" end
        visited=visited or {}
        if visited[v] then return "<cycle>" end
        visited[v]=true
        local out,n={},0
        for k,value in pairs(v) do
            n+=1
            if n>60 then out._truncated=true;break end
            out[tostring(k):sub(1,100)]=serialize(value,depth+1,visited)
        end
        visited[v]=nil
        return out
    end
    return tostring(v)
end
local function attributes(obj,limit)
    if not obj then return {} end
    local ok,data=pcall(function()return obj:GetAttributes()end)
    if not ok or type(data)~="table" then return {} end
    local out,n={},0
    for k,value in pairs(data) do
        n+=1
        if n>(limit or 150) then out._truncated=true;break end
        out[k]=serialize(value)
    end
    return out
end
local function log(kind,info)
    events[#events+1]={
        time=math.floor((os.clock()-started)*100)/100,
        kind=kind,data=info
    }
    if #events>MAX_EVENTS then table.remove(events,1) end
end
local function registerRemote(remote,root)
    if remoteSeen[remote] then return end
    remoteSeen[remote]=true
    if #remotes>=MAX_REMOTES then return end
    local name=location(remote)
    remotes[#remotes+1]={
        path=name,class=remote.ClassName,root=root,
        attributes=attributes(remote,45)
    }
    if (remote:IsA("RemoteEvent") or remote.ClassName=="UnreliableRemoteEvent")
        and connected<MAX_LISTENERS then
        local ok,conn=pcall(function()
            return remote.OnClientEvent:Connect(function(...)
                if not alive then return end
                local data=table.pack(...)
                counts[name]=(counts[name] or 0)+1
                local item=samples[name]
                if not item then item={};samples[name]=item end
                if #item<5 then
                    local args={}
                    for i=1,math.min(data.n,12) do
                        args[i]=serialize(data[i])
                    end
                    item[#item+1]={
                        time=math.floor((os.clock()-started)*100)/100,
                        count=data.n,args=args
                    }
                end
                if counts[name]<=3 then
                    log("remote.in",{path=name,
                        first=serialize(data[1]),second=serialize(data[2])})
                end
            end)
        end)
        if ok and conn then
            connected+=1
            connections[#connections+1]=conn
        end
    end
end
local keywords={
    "winter","yeti","boss","snow","ice","icicle","frost",
    "arena","lobby","spawn","portal","teleport","tnt",
    "pitchfork","vacuum","needle","haystack","gem",
    "shop","reward","coin","egg","tool","skip","pickup"
}
local function significant(name)
    local s=name:lower()
    for _,word in ipairs(keywords) do
        if s:find(word,1,true) then return true end
    end
    return false
end
local function worldObject(obj)
    if #discovered>=MAX_WORLD or not significant(obj.Name) then return end
    local key=obj.ClassName..":"..obj.Name
    duplicateNames[key]=(duplicateNames[key] or 0)+1
    if duplicateNames[key]>8 then return end
    local item={
        path=location(obj),class=obj.ClassName,
        attributes=attributes(obj,45),
    }
    if obj:IsA("BasePart") then
        item.position=serialize(obj.Position)
        item.size=serialize(obj.Size)
        item.canCollide=obj.CanCollide
    elseif obj:IsA("Model") then
        local ok,p=pcall(function()return obj:GetPivot().Position end)
        if ok then item.position=serialize(p)end
    end
    discovered[#discovered+1]=item
end
local function scan()
    discovered={}
    duplicateNames={}
    scanned={}
    local all=0
    local roots={
        {"ReplicatedStorage",RS},{"Workspace",WS},
        {"PlayerGui",player:FindFirstChildOfClass("PlayerGui")},
        {"Character",player.Character},
        {"Backpack",player:FindFirstChildOfClass("Backpack")},
        {"PlayerScripts",player:FindFirstChild("PlayerScripts")},
        {"StarterGui",game:GetService("StarterGui")},
        {"StarterPack",game:GetService("StarterPack")},
        {"Lighting",game:GetService("Lighting")}
    }
    for _,pair in ipairs(roots) do
        if not alive then return end
        local label,root=pair[1],pair[2]
        if root then
            local queue={root}
            local first,last,done=1,1,0
            while first<=last and done<MAX_ROOT and all<MAX_TOTAL and alive do
                local node=queue[first]
                queue[first]=nil
                first+=1;done+=1;all+=1
                if node:IsA("RemoteEvent") or node:IsA("RemoteFunction")
                    or node.ClassName=="UnreliableRemoteEvent" then
                    registerRemote(node,label)
                end
                if label=="Workspace" or label=="ReplicatedStorage" then
                    worldObject(node)
                end
                local ok,kids=pcall(function()return node:GetChildren()end)
                if ok and kids then
                    for _,child in ipairs(kids) do
                        last+=1
                        queue[last]=child
                    end
                end
                if done%650==0 then task.wait() end
            end
            scanned[label]={checked=done,truncated=first<=last}
        end
    end
end
local function detailModel(obj,maxElements)
    if not obj then return nil end
    local result={
        path=location(obj),class=obj.ClassName,
        attributes=attributes(obj,180),parts={},rig={},others={}
    }
    local ok,pivot=pcall(function()return obj:GetPivot()end)
    if ok then result.pivot=serialize(pivot)end
    local descendants=obj:GetDescendants()
    for i,node in ipairs(descendants) do
        if i>(maxElements or 400) then result.truncated=true;break end
        if node:IsA("BasePart") and #result.parts<145 then
            result.parts[#result.parts+1]={
                name=node.Name,path=location(node),
                position=serialize(node.Position),
                cframe=serialize(node.CFrame),size=serialize(node.Size),
                attributes=attributes(node,45)
            }
        elseif (node:IsA("Bone") or node:IsA("Attachment")
            or node:IsA("Motor6D")) and #result.rig<115 then
            result.rig[#result.rig+1]={
                path=location(node),class=node.ClassName,
                attributes=attributes(node,30)
            }
        elseif #result.others<75 then
            result.others[#result.others+1]={
                path=location(node),class=node.ClassName
            }
        end
    end
    return result
end
local function locate(parts)
    local obj=RS
    for _,part in ipairs(parts) do
        obj=obj and obj:FindFirstChild(part)
        if not obj then return nil end
    end
    return obj
end
local cfgCache=nil
local function configDump()
    if cfgCache then return cfgCache end
    cfgCache={}
    for _,parts in ipairs({
        {"WinterBoss","Config"},{"NeedleHaystack","Config"},
        {"Shared","Configs","GameConfig"},{"Shared","Configs","UpgradeConfig"}
    }) do
        local name="ReplicatedStorage."..table.concat(parts,".")
        local obj=locate(parts)
        local entry={path=name,status="not replicated"}
        if obj and obj:IsA("ModuleScript") then
            entry.attributes=attributes(obj,55)
            -- Only these known replicated config modules are required.
            local ok,result=pcall(require,obj)
            entry.status=ok and "loaded" or "require error"
            entry.values=ok and serialize(result) or tostring(result):sub(1,250)
        end
        cfgCache[#cfgCache+1]=entry
    end
    return cfgCache
end
local function playerDump()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local data={
        attributes=attributes(player,320),
        rootPosition=root and serialize(root.Position) or nil,
        humanoid=hum and {
            health=hum.Health,walkSpeed=hum.WalkSpeed,
            jumpPower=hum.JumpPower,state=tostring(hum:GetState()),
            platformStand=hum.PlatformStand
        } or nil,
        tools={},leaderstats={}
    }
    local stats=player:FindFirstChild("leaderstats")
    if stats then
        for _,v in ipairs(stats:GetChildren()) do
            if v:IsA("ValueBase") then
                data.leaderstats[v.Name]=serialize(v.Value)
            end
        end
    end
    for _,holder in ipairs({
        char,player:FindFirstChildOfClass("Backpack")
    }) do
        if holder then
            for _,tool in ipairs(holder:GetChildren()) do
                if tool:IsA("Tool") then
                    data.tools[#data.tools+1]={
                        path=location(tool),attributes=attributes(tool,90),
                        requiresHandle=tool.RequiresHandle
                    }
                end
            end
        end
    end
    return data
end
local function guiDump()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local out={screens={},buttons={},labels={}}
    if not pg then return out end
    for _,obj in ipairs(pg:GetChildren()) do
        if obj:IsA("ScreenGui") then
            out.screens[#out.screens+1]={
                path=location(obj),enabled=obj.Enabled,
                attributes=attributes(obj,40)
            }
        end
    end
    for i,obj in ipairs(pg:GetDescendants()) do
        if i>7200 then out.truncated=true;break end
        if obj:IsDescendantOf(pg) and
            not location(obj):lower():find("beyynativehub",1,true) and
            not location(obj):lower():find("chat",1,true) then
            if obj:IsA("GuiButton") and #out.buttons<260 then
                local visible=true
                local current=obj
                while current and current~=pg do
                    if current:IsA("GuiObject") and not current.Visible
                        or current:IsA("ScreenGui") and not current.Enabled then
                        visible=false;break
                    end
                    current=current.Parent
                end
                out.buttons[#out.buttons+1]={
                    path=location(obj),
                    text=obj:IsA("TextButton") and serialize(obj.Text) or nil,
                    visible=visible,
                    position=serialize(obj.AbsolutePosition),
                    size=serialize(obj.AbsoluteSize),
                    attributes=attributes(obj,24)
                }
            elseif obj:IsA("TextLabel") and #out.labels<190 then
                local text=(obj.Name.." "..obj.Text):lower()
                if significant(text) or text:find("weak",1,true)
                    or text:find("victory",1,true) then
                    out.labels[#out.labels+1]={
                        path=location(obj),text=serialize(obj.Text),
                        visible=obj.Visible
                    }
                end
            end
        end
        if i%850==0 then task.wait() end
    end
    return out
end
local function tagDump()
    local out={}
    local ok,tags=pcall(function()return CS:GetAllTags()end)
    if not ok or type(tags)~="table" then return out end
    for i,tag in ipairs(tags) do
        if i>130 then break end
        local good,nodes=pcall(function()return CS:GetTagged(tag)end)
        if good and nodes then
            local a={}
            for j,obj in ipairs(nodes) do
                if j>6 then break end
                a[#a+1]=location(obj)
            end
            out[#out+1]={tag=tag,count=#nodes,samples=a}
        end
    end
    return out
end
local watched={
    player={"InWinterBoss","CutsceneActive","NeedleInputLocked",
        "IntroCutsceneFinished","NeedleOwned","NeedleRoundComplete",
        "BossHeld","BossRagdolled","BossGrabbed","VacuumState",
        "VacuumHeat","VacuumActive","VacuumOverheated","VacuumOwned",
        "PitchforkOwned","PitchforkReach","PitchforkCooldown",
        "TntOwned","TntCooldown","HayHeld","HayCapacity"},
    boss={"BossState","BossPhase","BossHealth","BossMaxHealth",
        "BossShielded","BossWeakPoint","BossWeakPointDizzy",
        "BossDizzy","BossStagger","BossVulnerable","BossHidden"}
}
local function trackStates()
    local objects={player=player,boss=WS:FindFirstChild("YetiKing")}
    for group,keys in pairs(watched) do
        local obj=objects[group]
        if obj then
            for _,key in ipairs(keys) do
                local id=group.."."..key
                local current=tostring(obj:GetAttribute(key))
                if previous[id]~=nil and previous[id]~=current then
                    transitions[#transitions+1]={
                        t=math.floor((os.clock()-started)*100)/100,
                        attribute=id,previous=previous[id],value=current
                    }
                    if #transitions>350 then table.remove(transitions,1) end
                end
                previous[id]=current
            end
        end
    end
end
local function fullReport(stage)
    local winter=RS:FindFirstChild("WinterBoss")
    local template=winter and winter:FindFirstChild("Yeti")
    local incomingKinds=0
    for _ in pairs(counts) do incomingKinds+=1 end
    return {
        marker="BEYY_WINTER_FULL_INSPECTOR_V1",stage=stage,
        utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        elapsed=math.floor((os.clock()-started)*100)/100,
        placeId=game.PlaceId,gameId=game.GameId,
        scope="Client-visible replicated content",
        limitations={
            "All listed remotes are client-visible only.",
            "Outgoing payloads and server validation cannot be inspected without intercepting requests.",
            "No remote was fired or invoked by this inspector.",
            "Only known replicated Config modules are required.",
            "No incoming event during the window does not imply the remote is unused."
        },
        counts={remotes=#remotes,subscribed=connected,
            incomingTypes=incomingKinds,scanned=scanned},
        player=playerDump(),
        liveBoss=detailModel(WS:FindFirstChild("YetiKing"),520),
        bossTemplate=detailModel(template,550),
        winterFolder=winter and {path=location(winter),
            attributes=attributes(winter,140)} or nil,
        workspaceObjects=discovered,
        gui=guiDump(),collectionTags=tagDump(),
        configs=configDump(),
        remotes=remotes,
        incomingCounts=counts,incomingSamples=samples,
        incomingEventLog=events,stateTransitions=transitions,
    }
end
local function copy(stage)
    if busy or not alive then return end
    busy=true
    local ok,report=pcall(fullReport,stage)
    if not ok then
        warn("[Winter Inspector] Report failed: "..tostring(report))
        busy=false;return
    end
    local success,json=pcall(function()return HS:JSONEncode(report)end)
    if not success then
        warn("[Winter Inspector] JSON encode failed: "..tostring(json))
        busy=false;return
    end
    if #json>1600000 then
        report.incomingEventLog={}
        report.workspaceObjects={}
        report.gui.labels={}
        report.collectionTags={}
        report.compacted=true
        local again,s=pcall(function()return HS:JSONEncode(report)end)
        if again then json=s end
    end
    env.__BEYY_WINTER_LAST_DUMP=json
    local clipboard=type(setclipboard)=="function" and setclipboard
        or (type(toclipboard)=="function" and toclipboard or nil)
    local copied=clipboard and pcall(clipboard,json) or false
    local saved=false
    if type(writefile)=="function" then
        pcall(function()
            if type(makefolder)=="function" and
                (type(isfolder)~="function" or not isfolder("BeyyHub")) then
                makefolder("BeyyHub")
            end
            writefile("BeyyHub/winter_full_dump.json",json)
            saved=true
        end)
    end
    print(("[Winter Inspector] %s | %d bytes | %d remotes | %d incoming types | clipboard=%s | file=%s")
        :format(stage,#json,#remotes,report.counts.incomingTypes,
            tostring(copied),tostring(saved)))
    if not copied then
        warn("[Winter Inspector] Clipboard unavailable; use BeyyHub/winter_full_dump.json if file=true")
    end
    busy=false
end
local function stop(final)
    if not alive then return end
    if final~=false then copy("manual F9 final") end
    alive=false
    for _,c in ipairs(connections) do
        pcall(function()c:Disconnect()end)
    end
    table.clear(connections)
    if env.__BEYY_WINTER_INSPECTOR_STOP==stop then
        env.__BEYY_WINTER_INSPECTOR_STOP=nil
    end
    print("[Winter Inspector] Stopped; all passive listeners disconnected.")
end
env.__BEYY_WINTER_INSPECTOR_STOP=stop
connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
    if processed or input.UserInputType~=Enum.UserInputType.Keyboard then return end
    if input.KeyCode==Enum.KeyCode.F8 then
        task.spawn(function()copy("manual F8")end)
    elseif input.KeyCode==Enum.KeyCode.F9 then
        task.spawn(function()stop(true)end)
    end
end)
task.spawn(function()
    print("[Winter Inspector] Collecting Winter objects and remotes...")
    scan()
    if not alive then return end
    trackStates()
    copy("initial")
    local endAt=os.clock()+30
    while alive and os.clock()<endAt do
        task.wait(0.25)
        trackStates()
    end
    if not alive then return end
    scan()
    if not alive then return end
    trackStates()
    copy("automatic final after 30s")
    stop(false)
end)
