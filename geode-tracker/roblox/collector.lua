-- BeyyHub Discord tracker v3. Passive observers only; never invokes game remotes.
if not game:IsLoaded() then game.Loaded:Wait() end
assert(game.GameId==10770110947,"Crack the Geode only")
local env=getgenv()
local Http=game:GetService("HttpService")
local config={Url="https://geode-tracker-production.up.railway.app/upload",BoardInterval=30}
if type(readfile)=="function" then pcall(function()
    local saved=Http:JSONDecode(readfile("Geode/tracker_config.json"))
    if type(saved)=="table" then for k,v in pairs(saved) do config[k]=v end end
end) end
if type(env.GeodeTrackerConfig)=="table" then for k,v in pairs(env.GeodeTrackerConfig) do config[k]=v end end
local uploadEnabled=type(config.Url)=="string" and config.Url:match("^https://") and type(config.Key)=="string" and #config.Key>=32
local requestFn=request or http_request or (syn and syn.request)
if uploadEnabled then assert(type(requestFn)=="function","Executor HTTP request is unavailable") end
if env.GeodeTracker and env.GeodeTracker.Stop then env.GeodeTracker.Stop() end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local connections,queue={},{}
local running=true
local tracker={Version=3,Sent=0,Queued=0,LastError="",Captured=0,Boards=0,Running=true,UploadEnabled=not not uploadEnabled}
env.GeodeTracker=tracker
local queuePath="Geode/tracker_pending.json"
local function saveQueue()
    if type(writefile)=="function" then pcall(function()
        if type(makefolder)=="function" then pcall(makefolder,"Geode") end
        writefile(queuePath,Http:JSONEncode(queue))
    end) end
end
if type(readfile)=="function" then pcall(function()
    local saved=Http:JSONDecode(readfile(queuePath))
    if type(saved)=="table" then
        for _,item in ipairs(saved) do
            if #queue<200 and type(item)=="table" and item.gameId==game.GameId then queue[#queue+1]=item end
        end
    end
end) end
local function plain(v,depth)
    depth=depth or 0
    local kind=typeof(v)
    if kind=="string" then return v:sub(1,150) end
    if kind=="boolean" then return v end
    if kind=="number" then if v==v and math.abs(v)<1e100 then return v end;return nil end
    if kind=="Instance" then
        if v:IsA("Player") then return {Name=v.Name,UserId=v.UserId} end
        return v.Name
    end
    if kind=="table" and depth<2 then
        local out,count={},0
        for k,value in pairs(v) do
            if type(k)=="string" and #k<50 and count<20 then out[k]=plain(value,depth+1);count=count+1 end
        end
        return out
    end
end
local function envelope(kind)
    return {version=1,gameId=game.GameId,placeId=game.PlaceId,jobId=game.JobId,
        observedAt=DateTime.now():ToIsoDate(),kind=kind}
end
local function enqueue(d)
    if #queue>=200 then tracker.LastError="Queue full; export pending captures before continuing";return end
    if d.kind=="pet" then table.insert(queue,1,d) else queue[#queue+1]=d end
    tracker.Queued=#queue;saveQueue()
end
local attached=setmetatable({},{__mode="k"})
local petCatalog={}
local function attach(remote)
    if attached[remote] or not remote:IsA("RemoteEvent") then return end
    if remote.Name~="PetEvents" and remote.Name~="PetDrop" then return end
    local parent=remote.Parent
    if not parent or parent.Name~="Remotes" or not parent.Parent or parent.Parent.Name~="MTG" then return end
    attached[remote]=true
    connections[#connections+1]=remote.OnClientEvent:Connect(function(raw)
        if not running or type(raw)~="table" then return end
        local d=envelope("pet");d.category=remote.Name=="PetDrop" and "boss" or "secret";d.fields={}
        for _,field in ipairs({"Name","Pet","User","Odds","Type","Global","Serial"}) do d.fields[field]=plain(raw[field]) end
        if type(raw.Pet)=="string" then d.pet=petCatalog[raw.Pet] end
        tracker.Captured=tracker.Captured+1
        -- Preserve real values for schema confirmation, even if the API rejects them.
        if type(writefile)=="function" then pcall(function()
            if type(makefolder)=="function" then pcall(makefolder,"Geode") end
            writefile("Geode/last_"..d.category.."_event.json",Http:JSONEncode(d))
        end) end
        enqueue(d)
    end)
end
connections[#connections+1]=RS.DescendantAdded:Connect(attach)
for _,item in ipairs(RS:GetDescendants()) do attach(item) end
-- Presentation metadata comes from the same config/portrait helper used by PetsUI.
-- Capture atlas coordinates, not banner backgrounds, glows or player avatars.
task.spawn(function()
    local mtg=RS:FindFirstChild("MTG")
    local cfg=mtg and mtg:FindFirstChild("Config")
    local modules=mtg and mtg:FindFirstChild("Modules")
    local petModule=cfg and cfg:FindFirstChild("Pets")
    if not petModule or not petModule:IsA("ModuleScript") then return end
    local ok,definitions=pcall(require,petModule)
    if not ok or type(definitions)~="table" or type(definitions.ById)~="table" then return end
    local portraitModule=modules and modules:FindFirstChild("PetPortrait")
    local portraits
    if portraitModule and portraitModule:IsA("ModuleScript") then
        local success,value=pcall(require,portraitModule)
        if success and type(value)=="table" then portraits=value end
    end
    local function asset(value)
        if type(value)=="number" and value>0 then return tostring(value) end
        if type(value)~="string" then return nil end
        return value:match("^rbxassetid://(%d+)$") or value:match("^(%d+)$") or value:match("^https?://www%.roblox%.com/asset/%?id=(%d+)$")
    end
    local batch={}
    local sheetSizes={}
    local function sheetSize(assetId)
        if sheetSizes[assetId]~=nil then return sheetSizes[assetId] end
        -- Read original image dimensions when exposed by this client. Never infer atlas size.
        local image=Instance.new("ImageLabel");image.Image="rbxassetid://"..assetId
        local success,size=pcall(function()return image.ContentImageSize end)
        if not success and type(gethiddenproperty)=="function" then success,size=pcall(gethiddenproperty,image,"ContentImageSize") end
        image:Destroy()
        if success and typeof(size)=="Vector2" and size.X>0 and size.Y>0 then sheetSizes[assetId]=size else sheetSizes[assetId]=false end
        return sheetSizes[assetId]
    end
    local function flush()
        if #batch==0 or not running then return end
        local d=envelope("catalog");d.pets=batch;enqueue(d);batch={}
    end
    for id,definition in pairs(definitions.ById) do
        if not running then return end
        if type(id)=="string" and #id<=80 and id:match("^[%w_-]+$") and type(definition)=="table" then
            local metadata={id=id}
            local name=definition.Name or definition.DisplayName
            if type(name)=="string" and #name>0 and #name<=100 then metadata.name=name end
            if portraits and type(portraits.rect)=="function" then
                local success,image,offset,size=pcall(portraits.rect,id)
                local assetId=success and asset(image)
                if assetId then
                    metadata.portrait={assetId=assetId}
                    if typeof(offset)=="Vector2" and typeof(size)=="Vector2" and size.X>0 and size.Y>0 then
                        metadata.portrait.x=math.floor(offset.X);metadata.portrait.y=math.floor(offset.Y)
                        metadata.portrait.width=math.floor(size.X);metadata.portrait.height=math.floor(size.Y)
                        local dimensions=sheetSize(assetId)
                        if dimensions then metadata.portrait.sheetWidth=math.floor(dimensions.X);metadata.portrait.sheetHeight=math.floor(dimensions.Y) end
                    end
                end
            end
            if not metadata.portrait then
                local image=asset(definition.Image) or asset(definition.Portrait) or asset(definition.Thumbnail) or asset(definition.ImageId) or asset(definition.Icon) or asset(definition.ModelId) or asset(definition.Model)
                if image then metadata.portrait={assetId=image} end
            end
            petCatalog[id]=metadata;batch[#batch+1]=metadata
            if #batch>=50 then flush() end
        end
    end
    flush()
    print("[Geode Tracker] Pet names and available portrait metadata captured.")
end)
local function resolve(path,root)
    local node=root or game
    for _,segment in ipairs(path) do node=node and node:FindFirstChild(segment);if not node then return nil end end
    return node
end
local function label(root,path)
    local obj=resolve(path,root)
    if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return obj.Text:gsub("<[^>]->","") end
end
local function integer(value)
    if type(value)~="string" then return nil end
    local stripped=value:gsub(",",""):gsub("%s","")
    if not stripped:match("^%d+$") then return nil end
    local number=tonumber(stripped)
    if number and number<=9007199254740991 then return number end
end
local boardLast={}
local function submitBoard(d)
    local digest=Http:JSONEncode(d.rows)
    local previous=boardLast[d.boardId]
    if previous and previous.digest==digest and os.clock()-previous.at<120 then return end
    boardLast[d.boardId]={digest=digest,at=os.clock()}
    tracker.Boards=tracker.Boards+1
    if type(writefile)=="function" then pcall(function()
        if type(makefolder)=="function" then pcall(makefolder,"Geode") end
        writefile("Geode/last_board_"..d.boardId:gsub("[^%w_-]","_")..".json",Http:JSONEncode(d))
    end) end
    enqueue(d)
end
local nativeBoards={TopMiners="Top Miners",DeepestEndless="Deepest Endless",FastestHard="Fastest Hard",FastestEscapes="Fastest Escapes",TopWins="Top Wins"}
local function nativeBoardSnapshots(root)
    local snapshots={}
    local folder=root
    if not folder then folder=workspace:FindFirstChild("LobbyMap");folder=folder and folder:FindFirstChild("Boards") end
    if not folder then return snapshots end
    for id,title in pairs(nativeBoards) do
        local model=folder:FindFirstChild(id)
        local screen=model and model:FindFirstChild("Screen")
        local gui=screen and screen:FindFirstChild("MTG_Board")
        local board=gui and gui:FindFirstChild("Board")
        local well=board and board:FindFirstChild("Well")
        local container=well and well:FindFirstChild("Rows")
        if container then
            local rows,valid={},true
            for _,row in ipairs(container:GetChildren()) do
                if row.Name:match("^Row%d+$") and row:IsA("GuiObject") and row.Visible then
                    -- Direct labels are the three columns; Badge labels are nested and excluded.
                    -- Instance names repeat, so identify columns by their actual visual positions.
                    local columns={}
                    for _,v in ipairs(row:GetChildren()) do
                        if v:IsA("TextLabel") or v:IsA("TextButton") then columns[#columns+1]=v end
                    end
                    table.sort(columns,function(a,b)
                        local ax,bx=a.AbsolutePosition.X,b.AbsolutePosition.X
                        if ax==bx then return a.Position.X.Scale+a.Position.X.Offset/10000 < b.Position.X.Scale+b.Position.X.Offset/10000 end
                        return ax<bx
                    end)
                    if #columns~=3 then valid=false;break end
                    local rank=integer(columns[1].Text:gsub("#",""))
                    local name=columns[2].Text:gsub("<[^>]->","")
                    local score=columns[3].Text:gsub("<[^>]->","")
                    if not rank or rank<1 or #name==0 or #name>100 or #score==0 or #score>60 then valid=false;break end
                    rows[#rows+1]={rank=rank,label=name,displayValue=score}
                end
            end
            if valid and #rows>0 then
                table.sort(rows,function(a,b)return a.rank<b.rank end)
                local d=envelope("board");d.boardId=id;d.title=title;d.scope="global";d.format="display";d.rows=rows
                snapshots[#snapshots+1]=d
            end
        end
    end
    return snapshots
end
tracker.ParseBoards=nativeBoardSnapshots
function tracker.CaptureBoards()
    local snapshots=nativeBoardSnapshots()
    for _,d in ipairs(snapshots) do submitBoard(d) end
    return snapshots
end
local function boards()
    tracker.CaptureBoards()
    -- Current-server stats are explicitly labelled server-only, never global.
    local stats={}
    for _,player in ipairs(Players:GetPlayers()) do
        local leaderstats=player:FindFirstChild("leaderstats")
        if leaderstats then for _,stat in ipairs(leaderstats:GetChildren()) do
            if stat:IsA("IntValue") or stat:IsA("NumberValue") then
                local v=stat.Value
                if v>=0 and v%1==0 and v<=9007199254740991 then
                    stats[stat.Name]=stats[stat.Name] or {}
                    table.insert(stats[stat.Name],{username=player.Name,value=v})
                end
            end
        end end
    end
    for name,rows in pairs(stats) do
        table.sort(rows,function(a,b) return a.value==b.value and a.username<b.username or a.value>b.value end)
        local d=envelope("board");d.boardId="server-"..name;d.title=name;d.scope="server";d.rows=rows;submitBoard(d)
    end
    -- Configure paths after inspecting actual global leaderboard GUI structure.
    for _,board in ipairs(config.GlobalBoards or {}) do
        local container=resolve(board.RowsPath)
        if container then
            local rows,seen={},{}
            local valid=true
            for _,row in ipairs(container:GetChildren()) do
                if row:IsA("GuiObject") and row.Visible and row.Name~=(board.TemplateName or "Template") then
                    local username=label(row,board.UsernamePath)
                    local rawValue=label(row,board.ValuePath)
                    if username or rawValue then
                        local value=integer(rawValue)
                        if not username or not username:match("^[%w_]+$") or not value or seen[username:lower()] then valid=false;break end
                        seen[username:lower()]=true;rows[#rows+1]={username=username,value=value}
                    end
                end
            end
            if valid and #rows>0 then
                table.sort(rows,function(a,b)return a.value==b.value and a.username<b.username or a.value>b.value end)
                local d=envelope("board");d.boardId=board.Id;d.title=board.Title;d.scope="global";d.rows=rows;submitBoard(d)
            else tracker.LastError="Global board not readable: "..tostring(board.Id) end
        end
    end
end
function tracker.ExportBoards()
    local report={gameId=game.GameId,candidates={}}
    local roots={workspace,Players.LocalPlayer:WaitForChild("PlayerGui")}
    local function path(item)
        local parts={}
        while item and item~=game do table.insert(parts,1,item.Name);item=item.Parent end
        return parts
    end
    for _,root in ipairs(roots) do for _,item in ipairs(root:GetDescendants()) do
        if item:IsA("SurfaceGui") or item:IsA("BillboardGui") or item:IsA("ScreenGui") then
            local texts={}
            for _,v in ipairs(item:GetDescendants()) do
                if #texts>=500 then break end
                if v:IsA("TextLabel") or v:IsA("TextButton") then
                    if v.Text~="" then texts[#texts+1]={path=path(v),text=v.Text:sub(1,200),visible=v.Visible} end
                end
            end
            report.candidates[#report.candidates+1]={path=path(item),labels=texts}
            if #report.candidates>=100 then break end
        end
    end end
    assert(type(writefile)=="function","writefile unavailable")
    if type(makefolder)=="function" then pcall(makefolder,"Geode") end
    writefile("Geode/leaderboard_gui_capture.json",Http:JSONEncode(report))
    print("[Geode Tracker] Saved Geode/leaderboard_gui_capture.json")
end
function tracker.Stop()
    running=false;tracker.Running=false
    for _,connection in ipairs(connections) do connection:Disconnect() end
    saveQueue()
end
function tracker.Summary()
    return (running and "Running" or "Stopped")..(uploadEnabled and " · Uploads enabled" or " · Private upload settings missing")
        .."\nPets observed: "..tostring(tracker.Captured).." · Board captures: "..tostring(tracker.Boards)
        .." · Uploaded: "..tostring(tracker.Sent).." · Queued: "..tostring(tracker.Queued)
        ..(tracker.LastError~="" and ("\n"..tracker.LastError) or "")
end
task.spawn(function()
    while running do
        local d=uploadEnabled and queue[1]
        if d then
            -- Expire old pending uploads; most recent pet captures are saved separately.
            if DateTime.now().UnixTimestampMillis-DateTime.fromIsoDate(d.observedAt).UnixTimestampMillis>86400000 then
                table.remove(queue,1);saveQueue()
            else
                local ok,result=pcall(requestFn,{Url=config.Url,Method="POST",Headers={
                    ["Content-Type"]="application/json",Authorization="Bearer "..config.Key},Body=Http:JSONEncode(d)})
                if not running or env.GeodeTracker~=tracker then return end
                if ok and result and (result.StatusCode==200 or result.StatusCode==202) then
                    for i,item in ipairs(queue) do if item==d then table.remove(queue,i);break end end
                    tracker.Sent=tracker.Sent+1;tracker.LastError="";saveQueue()
                elseif ok and result and result.StatusCode==400 and type(writefile)=="function" then
                    local archived=pcall(function()
                        writefile("Geode/rejected_"..tostring(DateTime.now().UnixTimestampMillis)..".json",Http:JSONEncode(d))
                    end)
                    if archived then for i,item in ipairs(queue) do if item==d then table.remove(queue,i);break end end;saveQueue() end
                    tracker.LastError="Schema rejected; saved rejected capture for inspection"
                    task.wait(5)
                else
                    tracker.LastError="Upload failed ("..tostring(ok and result and result.StatusCode or "network").."); capture retained"
                    task.wait(10)
                end
            end
        end
        tracker.Queued=#queue;task.wait(1)
    end
end)
task.spawn(function()while running do
    local ok,err=pcall(boards);if not ok then tracker.LastError="Board capture failed: "..tostring(err) end
    task.wait(math.max(15,tonumber(config.BoardInterval) or 30))
end end)
print("[Geode Tracker] Watching PetEvents + PetDrop. Status: getgenv().GeodeTracker")
if not uploadEnabled then print("[Geode Tracker] Capture-only mode. Call getgenv().GeodeTracker.ExportBoards() while global leaderboards are visible.") end
return tracker
