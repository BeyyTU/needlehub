-- BeyyHub Chapter 5 Passive Place Inventory v1
-- PlaceId 85675194070288. Read-only: records replicated objects and attributes.
-- F6: rescan; F7: stop; F8: copy summary. Auto rescans +45s and +120s.
local PLACE=85675194070288
if game.PlaceId~=PLACE then
    warn("[CH5 INVENTORY] Run inside Chapter 5 (85675194070288). Actual: "..game.PlaceId)
    return
end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local WS=game:GetService("Workspace")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local env=(type(getgenv)=="function" and getgenv()) or _G
if type(env.__BEYY_CH5_INVENTORY_STOP)=="function" then
    pcall(env.__BEYY_CH5_INVENTORY_STOP)
end
local alive=true
local started=os.clock()
local dir="BeyyHub/Chapter5_Inventory_"..os.date("!%Y%m%d_%H%M%S")
local canWrite=type(writefile)=="function"
local folder=false
if canWrite and type(makefolder)=="function" then
    pcall(function()
        if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
        if type(isfolder)~="function" or not isfolder(dir) then makefolder(dir) end
        folder=true
    end)
end
if not folder then dir="BeyyHub_CH5_Inventory_"..tostring(os.time()).."_" end
local function save(name,body)
    if not canWrite then return false end
    local path=(folder and dir.."/" or dir)..name
    local ok,err=pcall(writefile,path,body)
    if not ok then warn("[CH5 INVENTORY] Save error: "..tostring(err)) end
    return ok
end
local function pathOf(obj)
    local ok,path=pcall(function()return obj:GetFullName()end)
    return ok and path or tostring(obj)
end
local bossWords={"boss","monster","enemy","golem","guardian","health","phase","combat",
    "hitbox","damage","weakpoint","weak_point","hurtbox","attack","weapon","projectile"}
local puzzleWords={"puzzle","minigame","lever","switch","button","door","gate","lock",
    "key","paper","poster","code","sequence","rune","wire","circuit","color",
    "picture","tile","gem","laser","align","vent","crystal","objective",
    "generator","artifact","clue","note","terminal","quest","pickup"}
local function matches(str,words)
    str=str:lower()
    for _,word in ipairs(words) do if str:find(word,1,true) then return true end end
    return false
end
local function val(v)
    local kind=typeof(v)
    if kind=="string" then
        return #v>1400 and v:sub(1,1400).."...(trimmed)" or v
    elseif kind=="number" or kind=="boolean" then
        return v
    elseif kind=="Instance" then
        return pathOf(v)
    elseif kind=="table" then
        local result={}
        local n=0
        for k,x in pairs(v) do
            n+=1
            if n>60 then result["_extra"]="truncated";break end
            result[tostring(k)]=tostring(x)
        end
        return result
    else
        return tostring(v)
    end
end
local function property(row,obj,key)
    local ok,x=pcall(function()return obj[key]end)
    if ok then row[key]=val(x) end
end
local function record(obj)
    local path=pathOf(obj)
    local row={path=path,class=obj.ClassName,name=obj.Name}
    local ok,attrs=pcall(function()return obj:GetAttributes()end)
    if ok and next(attrs) then row.attributes=val(attrs) end
    if obj:IsA("BasePart") then
        for _,key in ipairs({"Position","Size","Orientation","Anchored",
            "Transparency","CanCollide","CanTouch","CanQuery"}) do property(row,obj,key) end
    elseif obj:IsA("Model") then
        local yes,pivot=pcall(function()return obj:GetPivot()end)
        if yes then row.PivotPosition=tostring(pivot.Position) end
        property(row,obj,"PrimaryPart")
    end
    if obj:IsA("ValueBase") then property(row,obj,"Value") end
    if obj:IsA("Humanoid") then
        property(row,obj,"Health");property(row,obj,"MaxHealth")
        property(row,obj,"WalkSpeed")
    end
    if obj:IsA("ProximityPrompt") then
        for _,key in ipairs({"ActionText","ObjectText","HoldDuration",
            "MaxActivationDistance","RequiresLineOfSight","Enabled"}) do property(row,obj,key) end
    elseif obj:IsA("ClickDetector") then property(row,obj,"MaxActivationDistance") end
    if obj:IsA("ScreenGui") then property(row,obj,"Enabled") end
    if obj:IsA("GuiObject") then
        property(row,obj,"Visible");property(row,obj,"AbsolutePosition")
        property(row,obj,"AbsoluteSize")
    end
    if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
        property(row,obj,"Text")
    end
    if obj:IsA("Animation") then property(row,obj,"AnimationId") end
    if obj:IsA("Sound") then property(row,obj,"SoundId") end
    return row
end
local function classify(obj,path)
    local boss=matches(path,bossWords)
    local puzzle=matches(path,puzzleWords)
    local remote=obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
    local interact=obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")
        or obj:IsA("TouchTransmitter")
    local gui=obj:IsA("GuiButton") or obj:IsA("ScreenGui")
    local state=obj:IsA("ValueBase") or obj:IsA("Humanoid")
    return {boss=boss,puzzle=puzzle,remote=remote,interact=interact,gui=gui,
        state=state,important=boss or puzzle or remote or interact or gui}
end
local logs={}
local function log(category,text)
    logs[#logs+1]=string.format("+%.2fs [%s] %s",os.clock()-started,category,tostring(text))
    if #logs>2000 then table.remove(logs,1) end
end
local activeScan=false
local snapshots=0
local latestSummary="No scan yet"
local connections={}
local function scan()
    if activeScan or not alive then return end
    activeScan=true
    snapshots+=1
    local id=string.format("%02d",snapshots)
    local count,important,part=0,0,1
    local classes={}
    local totals={boss=0,puzzle=0,remote=0,interact=0,gui=0}
    local candidates,chunk={},{}
    local function flush()
        if #chunk==0 then return end
        local ok,json=pcall(function()return Http:JSONEncode(chunk)end)
        if ok then save("snapshot_"..id.."_objects_"..string.format("%03d",part)..".json",json) end
        chunk={}
        part+=1
    end
    local skip={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then skip[p.Character]=true end
    end
    local roots={WS,RS,game:GetService("ReplicatedFirst"),
        game:GetService("Lighting"),game:GetService("SoundService"),
        game:GetService("StarterGui"),game:GetService("StarterPack"),
        game:GetService("StarterPlayer")}
    for _,root in ipairs({player:FindFirstChildOfClass("PlayerGui"),
        player:FindFirstChildOfClass("Backpack"),
        player:FindFirstChildOfClass("PlayerScripts")}) do
        if root then roots[#roots+1]=root end
    end
    local visited={}
    for _,root in ipairs(roots) do
        local ok,items=pcall(function()return root:GetDescendants()end)
        if ok then
            table.insert(items,1,root)
            for i,obj in ipairs(items) do
                if not alive then break end
                if skip[obj] or (obj.Parent and skip[obj.Parent]) then
                    skip[obj]=true
                elseif not visited[obj] then
                    visited[obj]=true
                    local yes,row=pcall(record,obj)
                    if yes then
                        count+=1
                        classes[row.class]=(classes[row.class] or 0)+1
                        local cat=classify(obj,row.path)
                        if cat.important then
                            important+=1
                            for name in pairs(totals) do
                                if cat[name] then totals[name]+=1 end
                            end
                            if #candidates<5000 then candidates[#candidates+1]=row end
                        end
                        chunk[#chunk+1]=row
                        if #chunk>=250 then flush() end
                    else
                        log("ERROR","Reading "..pathOf(obj).." failed: "..tostring(row))
                    end
                end
                if i%200==0 then task.wait() end
            end
        end
    end
    flush()
    local ok,json=pcall(function()return Http:JSONEncode(candidates)end)
    if ok then save("snapshot_"..id.."_puzzles_bosses_remotes_prompts.json",json) end
    local lines={
        "CHAPTER 5 PASSIVE INVENTORY v1",
        "PlaceId="..tostring(PLACE).." JobId="..tostring(game.JobId),
        "Snapshot="..id.." Objects="..count.." Important="..important,
        "Boss-related="..totals.boss.." Puzzle-related="..totals.puzzle,
        "Remotes="..totals.remote.." Interactions="..totals.interact.." GUI="..totals.gui,
        "Output="..dir,
        "Note: Only client-replicated instances are accessible. Server-only scripts and hidden boss behavior are not included.",
        "-- CANDIDATE OBJECTS --"
    }
    for i=1,math.min(#candidates,500) do
        local r=candidates[i]
        lines[#lines+1]=r.class.." "..r.path
    end
    lines[#lines+1]="-- CLASS COUNTS --"
    local ordered={}
    for name,n in pairs(classes) do ordered[#ordered+1]={name=name,n=n} end
    table.sort(ordered,function(a,b)return a.n>b.n end)
    for _,entry in ipairs(ordered) do
        lines[#lines+1]=entry.name.." "..entry.n
    end
    latestSummary=table.concat(lines,"\n")
    save("summary_latest.txt",latestSummary)
    save("events_latest.txt",table.concat(logs,"\n"))
    print("[CH5 INVENTORY] Snapshot "..id.." complete: "..count..
        " objects, "..important.." candidates, "..totals.remote.." remotes. Saved "..dir)
    if not canWrite then
        warn("[CH5 INVENTORY] Executor has no writefile; F8 copies summary only.")
    end
    activeScan=false
end
local function stop()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    save("events_latest.txt",table.concat(logs,"\n"))
    save("summary_latest.txt",latestSummary)
    env.__BEYY_CH5_INVENTORY_STOP=nil
    print("[CH5 INVENTORY] Stopped. Files: "..dir)
end
env.__BEYY_CH5_INVENTORY_STOP=stop
local keyConnection=UIS.InputBegan:Connect(function(input,used)
    if used then return end
    if input.KeyCode==Enum.KeyCode.F6 then
        task.spawn(scan)
    elseif input.KeyCode==Enum.KeyCode.F7 then
        stop()
    elseif input.KeyCode==Enum.KeyCode.F8 then
        if type(setclipboard)=="function" then
            pcall(setclipboard,latestSummary)
            print("[CH5 INVENTORY] Summary copied.")
        else print(latestSummary) end
    end
end)
connections[#connections+1]=keyConnection
for _,root in ipairs({WS,RS}) do
    connections[#connections+1]=root.DescendantAdded:Connect(function(obj)
        if not alive then return end
        local path=pathOf(obj)
        local cat=classify(obj,path)
        if cat.important then
            log(cat.boss and "BOSS" or cat.puzzle and "PUZZLE" or "SPAWN",path)
        end
    end)
end
print("[CH5 INVENTORY] Read-only Chapter 5 inventory active.")
print("[CH5 INVENTORY] F6 rescan | F7 stop | F8 copy summary | output "..dir)
task.spawn(scan)
task.delay(45,function()if alive then task.spawn(scan)end end)
task.delay(120,function()if alive then task.spawn(scan)end end)
