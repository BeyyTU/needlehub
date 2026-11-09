-- Run alongside BeyyHub. Passive observers only; never invokes game remotes.
-- Configure getgenv().GeodeTrackerConfig before running. Requires executor HTTP.
if not game:IsLoaded() then game.Loaded:Wait() end
assert(game.GameId==10770110947,"Crack the Geode only")
local env=getgenv()
local config=env.GeodeTrackerConfig or {}
local uploadEnabled=type(config.Url)=="string" and config.Url:match("^https://") and type(config.Key)=="string" and #config.Key>=32
local requestFn=request or http_request or (syn and syn.request)
if uploadEnabled then assert(type(requestFn)=="function","Executor HTTP request is unavailable") end
if env.GeodeTracker and env.GeodeTracker.Stop then env.GeodeTracker.Stop() end
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local connections,queue={},{}
local running=true
local tracker={Sent=0,Queued=0,LastError="",Captured=0}
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
    queue[#queue+1]=d;tracker.Queued=#queue;saveQueue()
end
local attached=setmetatable({},{__mode="k"})
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
local function boards()
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
        local d=envelope("board");d.boardId="server-"..name;d.title=name;d.scope="server";d.rows=rows;enqueue(d)
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
                local d=envelope("board");d.boardId=board.Id;d.title=board.Title;d.scope="global";d.rows=rows;enqueue(d)
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
    running=false
    for _,connection in ipairs(connections) do connection:Disconnect() end
    saveQueue()
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
                if ok and result and (result.StatusCode==200 or result.StatusCode==202) then
                    table.remove(queue,1);tracker.Sent=tracker.Sent+1;tracker.LastError="";saveQueue()
                elseif ok and result and result.StatusCode==400 and type(writefile)=="function" then
                    local archived=pcall(function()
                        writefile("Geode/rejected_"..tostring(DateTime.now().UnixTimestampMillis)..".json",Http:JSONEncode(d))
                    end)
                    if archived then table.remove(queue,1);saveQueue() end
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
    task.wait(math.max(60,tonumber(config.BoardInterval) or 120))
end end)
print("[Geode Tracker] Watching PetEvents + PetDrop. Status: getgenv().GeodeTracker")
if not uploadEnabled then print("[Geode Tracker] Capture-only mode. Call getgenv().GeodeTracker.ExportBoards() while global leaderboards are visible.") end
return tracker
