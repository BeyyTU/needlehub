-- BEYY_RS_INVENTORY_V1
-- Read-only client ReplicatedStorage inventory; no FireServer or require.
-- F6 = start, F7 = cancel/partial export. Data stays in executor files.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local CS=game:GetService("CollectionService")
local player=Players.LocalPlayer
local playerGui=player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then warn("[Beyy RS] Run after joining the game.") return end
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if type(env.BeyyRSDumpDestroy)=="function" then pcall(env.BeyyRSDumpDestroy) end
local alive,running,cancel,sourceEnabled=true,false,false,false
local runId=0
local lastSummary=nil
local listeners={}
local maxChunk=300
local function value(v,depth,seen)
    local ty=typeof(v)
    depth=depth or 0
    if ty=="nil" then return nil end
    if ty=="number" then return (v==v and math.abs(v)<math.huge) and v or tostring(v) end
    if ty=="string" then return #v<16000 and v or (v:sub(1,16000).." [truncated]") end
    if ty=="boolean" then return v end
    if ty=="Instance" then
        local ok,s=pcall(function()return v:GetFullName()end)
        return ok and s or tostring(v)
    end
    if ty=="table" then
        if depth>=3 then return "<nested>" end
        seen=seen or {}
        if seen[v] then return "<cyclic>" end
        seen[v]=true
        local out,n={},0
        for k,item in pairs(v) do
            n+=1
            if n>130 then out.__truncated=true break end
            local name=tostring(k):sub(1,90)
            local low=name:lower()
            if low:find("token",1,true) or low:find("password",1,true)
                or low:find("secret",1,true) or low:find("webhook",1,true)
                or low:find("cookie",1,true) or low:find("api_key",1,true) then
                out[name]="<redacted>"
            else out[name]=value(item,depth+1,seen) end
        end
        seen[v]=nil
        return out
    end
    return tostring(v):sub(1,300)
end
local function prop(obj,k)
    local ok,v=pcall(function()return obj[k]end)
    if ok then return value(v) end
end
local function pathOf(obj)
    local ok,p=pcall(function()return obj:GetFullName()end)
    return ok and p or obj.Name
end
local function inspect(obj)
    local d={name=obj.Name,class=obj.ClassName,path=pathOf(obj)}
    if obj.Parent then d.parent=pathOf(obj.Parent) end
    local ok,attrs=pcall(function()return obj:GetAttributes()end)
    if ok and type(attrs)=="table" and next(attrs) then d.attributes=value(attrs) end
    local tagsOK,tags=pcall(CS.GetTags,CS,obj)
    if tagsOK and type(tags)=="table" and #tags>0 then d.tags=tags end
    local props={}
    local names={}
    if obj:IsA("BasePart") then
        names={"Position","CFrame","Size","Anchored","CanCollide","CanTouch",
            "CanQuery","Transparency","Color","Material","Massless","CollisionGroup"}
        if obj:IsA("MeshPart") then
            names[#names+1]="MeshId";names[#names+1]="TextureID"
        end
    elseif obj:IsA("Model") then names={"PrimaryPart","WorldPivot"}
    elseif obj:IsA("Attachment") then names={"Position","Orientation","WorldPosition"}
    elseif obj:IsA("ValueBase") then names={"Value"}
    elseif obj:IsA("Sound") then names={"SoundId","Volume","PlaybackSpeed","Looped"}
    elseif obj:IsA("Animation") then names={"AnimationId"}
    elseif obj:IsA("ParticleEmitter") then
        names={"Enabled","Rate","Lifetime","Speed","Texture"}
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        names={"Texture","Color3","Transparency"}
    elseif obj:IsA("ProximityPrompt") then
        names={"ActionText","ObjectText","Enabled","MaxActivationDistance","HoldDuration"}
    elseif obj:IsA("GuiObject") then
        names={"Visible","Position","Size","Text","BackgroundTransparency"}
    end
    for _,name in ipairs(names) do
        local v=prop(obj,name)
        if v~=nil then props[name]=v end
    end
    if next(props) then d.properties=props end
    d.remote=obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
    d.module=obj:IsA("ModuleScript")
    d.script=obj:IsA("LocalScript") or obj:IsA("Script")
    return d
end
local function noteworthy(d)
    if d.remote or d.module or d.script or d.attributes or d.tags then return true end
    if d.class:find("Value") then return true end
    local low=d.name:lower()
    for _,term in ipairs({"config","setting","cooldown","yeti","boss","damage",
        "weak","crit","vacuum","pitchfork","tnt","attack","reward","gem","upgrade"}) do
        if low:find(term,1,true) then return true end
    end
    return false
end
local function mkdir(path)
    local prefix=""
    for part in path:gmatch("[^/]+") do
        prefix=prefix=="" and part or (prefix.."/"..part)
        local exists=false
        if type(isfolder)=="function" then
            local ok,result=pcall(isfolder,prefix)
            exists=ok and result==true
        end
        if not exists then pcall(makefolder,prefix) end
    end
end
local function save(path,obj)
    local ok,json=pcall(HS.JSONEncode,HS,obj)
    if not ok then return false,tostring(json) end
    local wrote,why=pcall(writefile,path,json)
    return wrote,wrote and #json or tostring(why)
end
local ui=Instance.new("ScreenGui")
ui.Name="BeyyRSInspector";ui.ResetOnSpawn=false
ui.IgnoreGuiInset=true;ui.DisplayOrder=10000
ui.ZIndexBehavior=Enum.ZIndexBehavior.Global;ui.Parent=playerGui
local frame=Instance.new("Frame")
frame.Name="Panel";frame.Size=UDim2.fromOffset(382,205)
frame.AnchorPoint=Vector2.new(1,1)
frame.Position=UDim2.new(1,-16,1,-24)
frame.BackgroundColor3=Color3.fromRGB(24,29,40)
frame.BorderSizePixel=0;frame.ZIndex=300;frame.Active=true
frame.Parent=ui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=frame
local function label(txt,y,h,size)
    local l=Instance.new("TextLabel");l.Size=UDim2.new(1,-20,0,h)
    l.Position=UDim2.fromOffset(10,y);l.ZIndex=301;l.BackgroundTransparency=1
    l.TextXAlignment=Enum.TextXAlignment.Left;l.TextWrapped=true
    l.TextColor3=Color3.fromRGB(229,236,248);l.Font=Enum.Font.Gotham
    l.TextSize=size;l.Text=txt;l.Parent=frame
    return l
end
label("REPLICATED STORAGE · INVENTORY",8,24,15)
label("F6 = start | F7 = stop. Saves all replicated descendants in JSON chunks.",33,35,12)
local status=label("READY",67,29,13)
local detail=label("Only client-visible objects. Does not modify gameplay.",95,39,11)
local function button(txt,x,y,w,color)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(w,30);b.Position=UDim2.fromOffset(x,y)
    b.ZIndex=302;b.Active=true;b.Selectable=true
    b.BackgroundColor3=color;b.BorderSizePixel=0
    b.TextColor3=Color3.new(1,1,1);b.TextSize=12
    b.Font=Enum.Font.GothamBold;b.Text=txt;b.Parent=frame
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=b
    return b
end
local sourceBtn=button("DECOMPILE SOURCE: OFF",10,138,362,27 and Color3.fromRGB(61,73,94))
local startBtn=button("START FULL DUMP",10,171,174,Color3.fromRGB(31,137,95))
local stopBtn=button("STOP / EXPORT",198,171,174,Color3.fromRGB(159,74,77))
local function show(s,d)
    status.Text=s
    if d then detail.Text=d end
end
local function copySummary()
    if not lastSummary then show("NO EXPORT YET","Start the scan with F6.") return end
    local copy=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    local ok=copy and pcall(copy,lastSummary)
    show(ok and "SUMMARY COPIED" or "NO CLIPBOARD SUPPORT",
        "Upload manifest.json and priority.json for first analysis.")
end
local function runScan(token)
    if type(writefile)~="function" or type(makefolder)~="function" then
        show("FILE API NOT SUPPORTED","Your executor must provide writefile + makefolder.")
        running=false;startBtn.Text="START FULL DUMP";return
    end
    local began=os.clock()
    local folder="BeyyHub/rs_dump_"..os.date("!%Y%m%d_%H%M%S")
    mkdir(folder)
    if sourceEnabled then mkdir(folder.."/sources") end
    local manifest={signature="BEYY_RS_INVENTORY_V1",placeId=game.PlaceId,
        placeVersion=game.PlaceVersion,startedUnix=os.time(),
        root="ReplicatedStorage",sourceEnabled=sourceEnabled,complete=false,
        notes={
            "Client-replicated objects only; server-only code is not visible.",
            "No gameplay remotes are invoked; ModuleScripts are never required.",
            "Property inspection uses a class-specific whitelist; not every engine property is enumerable.",
            "Optional decompile relies on executor support and may reveal sensitive code.",
            "Client changes do not imply server-authoritative game changes."
        },chunks={},classCounts={},rootChildren={},errors={}}
    local stats={objects=0,modules=0,remotes=0,scripts=0,sources=0,
        sourceFailures=0,chunks=0,interestingDropped=0,errors=0}
    local priority={signature="BEYY_RS_PRIORITY_V1",items={},remotes={},modules={}}
    local queue={{obj=RS,depth=0}}
    local chunk={}
    local sourceFn=(type(decompile)=="function" and decompile or nil)
    local function err(reason)
        stats.errors+=1
        if #manifest.errors<100 then
            manifest.errors[#manifest.errors+1]=tostring(reason):sub(1,600)
        end
    end
    local function flush()
        if #chunk==0 then return end
        stats.chunks+=1
        local name=string.format("objects_%04d.json",stats.chunks)
        local ok,size=save(folder.."/"..name,{signature="BEYY_RS_OBJECT_CHUNK_V1",items=chunk})
        if ok then manifest.chunks[#manifest.chunks+1]={file=name,items=#chunk,bytes=size}
        else err("Saving "..name..": "..tostring(size)) end
        chunk={}
    end
    while #queue>0 and alive and running and token==runId and not cancel do
        local node=table.remove(queue)
        local object=node.obj
        local ok,d=pcall(inspect,object)
        if ok and d then
            d.depth=node.depth
            stats.objects+=1
            manifest.classCounts[d.class]=(manifest.classCounts[d.class] or 0)+1
            if node.depth==1 then manifest.rootChildren[#manifest.rootChildren+1]=d.name end
            if d.remote then
                stats.remotes+=1;priority.remotes[#priority.remotes+1]=d
            end
            if d.module then
                stats.modules+=1;priority.modules[#priority.modules+1]=d
            end
            if d.script then stats.scripts+=1 end
            if noteworthy(d) then
                if #priority.items<1500 then priority.items[#priority.items+1]=d
                else stats.interestingDropped+=1 end
            end
            if sourceEnabled and (d.module or d.script) then
                if sourceFn then
                    local decompiled,source=pcall(sourceFn,object)
                    if decompiled and type(source)=="string" and #source>0 then
                        local name=string.format("sources/script_%06d.lua",stats.objects)
                        if pcall(writefile,folder.."/"..name,source) then
                            d.sourceFile=name;d.sourceBytes=#source
                            stats.sources+=1
                        else stats.sourceFailures+=1 end
                    else stats.sourceFailures+=1 end
                else stats.sourceFailures+=1 end
            end
            local childOk,children=pcall(function()return object:GetChildren()end)
            if childOk then
                d.childCount=#children
                for i=#children,1,-1 do
                    queue[#queue+1]={obj=children[i],depth=node.depth+1}
                end
            else err("GetChildren: "..d.path) end
            chunk[#chunk+1]=d
            if #chunk>=maxChunk then flush() end
        else err("Inspect: "..pathOf(object).." / "..tostring(d)) end
        if stats.objects%65==0 then
            show("SCANNING · "..stats.objects.." objects",
                stats.remotes.." remotes · "..stats.modules.." modules · "..stats.chunks.." chunks")
            task.wait()
        end
    end
    flush()
    manifest.complete=alive and running and not cancel and token==runId and #queue==0
    manifest.finishedUnix=os.time()
    manifest.durationSeconds=math.round((os.clock()-began)*100)/100
    manifest.pendingObjects=#queue
    manifest.stats=stats
    priority.stats=stats;priority.complete=manifest.complete
    local pOk,pWhy=save(folder.."/priority.json",priority)
    if not pOk then err("Priority export: "..tostring(pWhy)) end
    local mOk,mWhy=save(folder.."/manifest.json",manifest)
    if not mOk then warn("[Beyy RS] Manifest export failed: "..tostring(mWhy)) end
    lastSummary=string.format(
        "Beyy RS dump / PlaceId %s / Objects %d / Remotes %d / Modules %d / Chunks %d / Complete %s / Folder %s",
        tostring(game.PlaceId),stats.objects,stats.remotes,stats.modules,
        stats.chunks,tostring(manifest.complete),folder)
    env.BeyyRSLastSummary=lastSummary
    env.BeyyRSLastFolder=folder
    running=false;cancel=false
    startBtn.Text="START NEW DUMP";stopBtn.Text="COPY SUMMARY"
    sourceBtn.Text=sourceEnabled and "DECOMPILE SOURCE: ON" or "DECOMPILE SOURCE: OFF"
    show(manifest.complete and "COMPLETE · EXPORTED" or "PARTIAL · EXPORTED",
        stats.objects.." objects · "..stats.remotes.." remotes | "..folder)
    print("[Beyy RS] "..lastSummary)
    print("[Beyy RS] Upload manifest.json and priority.json. Include objects_*.json for the exhaustive tree.")
end
local function start()
    if not alive or running then return end
    runId+=1
    running=true;cancel=false;lastSummary=nil
    startBtn.Text="SCANNING...";stopBtn.Text="STOP / EXPORT"
    show("STARTING","No game-state changes or remote requests.")
    local token=runId
    task.spawn(function()
        local ok,e=xpcall(function()runScan(token)end,debug.traceback)
        if not ok then
            warn("[Beyy RS] Scan error: "..tostring(e))
            running=false;cancel=false
            startBtn.Text="RETRY DUMP";stopBtn.Text="COPY SUMMARY"
            show("ERROR · F9 CONSOLE",tostring(e):sub(1,190))
        end
    end)
end
local function stop()
    if running then cancel=true;show("STOP REQUESTED","Finalizing partial JSON chunks.")
    else copySummary() end
end
local lastPress=-math.huge
local function action(k)
    if not alive then return end
    if os.clock()-lastPress<0.18 then return end
    lastPress=os.clock()
    if k=="start" then start()
    elseif k=="stop" then stop()
    elseif k=="source" and not running then
        sourceEnabled=not sourceEnabled
        sourceBtn.Text=sourceEnabled and "DECOMPILE SOURCE: ON" or "DECOMPILE SOURCE: OFF"
        show("READY",sourceEnabled and "Decompiler exports can be slow; review source files before sharing."
            or "Default: full object metadata, no script decompilation.")
    end
end
local function listen(button,k)
    listeners[#listeners+1]=button.Activated:Connect(function()action(k)end)
    listeners[#listeners+1]=button.MouseButton1Click:Connect(function()action(k)end)
end
listen(startBtn,"start");listen(stopBtn,"stop");listen(sourceBtn,"source")
listeners[#listeners+1]=UIS.InputBegan:Connect(function(input)
    if not alive or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F6 then action("start")
    elseif input.KeyCode==Enum.KeyCode.F7 then action("stop") end
end)
local function destroy()
    if not alive then return end
    cancel=true;alive=false;running=false;runId+=1
    for _,c in ipairs(listeners) do pcall(function()c:Disconnect()end) end
    pcall(function()ui:Destroy()end)
end
env.BeyyRSDumpDestroy=destroy
env.BeyyRSDumpStart=start
env.BeyyRSDumpStop=stop
print("[Beyy RS] Ready. F6 / START FULL DUMP; F7 to stop/export.")
