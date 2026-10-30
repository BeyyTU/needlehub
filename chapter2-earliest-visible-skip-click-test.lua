-- Beyy Chapter 2 Earliest Visible Skip Click Test v1
-- Isolated experiment: up to two ordinary GUI mouse clicks, only on the
-- native Chapter 2 INTRO Skip button. Never invokes gameplay remotes,
-- teleports, unlocks the character, changes cutscene attributes or camera.
-- Execute from lobby before entering Chapter 2. Prefer no concurrent auto-Skip.
local LOBBY=77108422251420
local CH2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-earliest-visible-skip-click-test.lua"
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local VIM=game:GetService("VirtualInputManager")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local env=_G
if type(getgenv)=="function" then
    local ok,v=pcall(getgenv)
    if ok and type(v)=="table" then env=v end
end
if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then
        warn("[CH2 FAST SKIP] queue_on_teleport unavailable; run immediately on Chapter 2 entry.")
        return
    end
    local ok,body=pcall(function()
        return game:HttpGet(URL.."?preload="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Earliest Visible Skip Click Test v1",1,true)
        and type(loadstring)=="function" and type(loadstring(body))=="function"
    local payload=valid and body or
        ('loadstring(game:HttpGet("'..URL..'?fallback="..tostring(os.time())))()')
    local queued,err=pcall(queue,payload)
    if queued then
        print("[CH2 FAST SKIP] Test armed ("..(valid and "preloaded" or "online fallback")..
            "). Enter Chapter 2; no main-script changes.")
    else
        warn("[CH2 FAST SKIP] Queue failed: "..tostring(err))
    end
    return
end
if game.PlaceId~=CH2 then
    warn("[CH2 FAST SKIP] Expected Chapter 2; place="..tostring(game.PlaceId))
    return
end

local prevStop=env.__BEYY_CH2_FAST_SKIP_STOP
if type(prevStop)=="function" then pcall(prevStop) end
local started=os.clock()
local alive=true
local duration=42
local player=nil
local records={}
local changedValues={}
local milestones={}
local connections={}
local attempts=0
local busy=false
local lastAttemptAt=-math.huge
local firstSkipVisibleAt=nil
local savePath="BeyyHub/chapter2_earliest_visible_skip_result.txt"
local function elapsed() return os.clock()-started end
local function record(label,msg)
    local entry=string.format("+%.3fs [%s] %s",elapsed(),label,tostring(msg))
    records[#records+1]=entry
    if #records>600 then table.remove(records,1) end
    print("[CH2 FAST SKIP] "..entry)
end
local function first(key,msg)
    if milestones[key]~=nil then return end
    milestones[key]=elapsed()
    record("FIRST",key..": "..tostring(msg or ""))
end
local function changed(key,val)
    local str=tostring(val)
    if changedValues[key]~=str then
        changedValues[key]=str
        record("STATE",key.."="..str)
    end
end
local function connect(signal,cb)
    local ok,c=pcall(function() return signal:Connect(cb) end)
    if ok and c then connections[#connections+1]=c end
end
local function makeReport()
    local summary={
        "CHAPTER 2 EARLIEST VISIBLE SKIP CLICK TEST v1",
        "Time relative to script start, not server start.",
        "Clicked native intro Skip with ordinary mouse input only. No direct remotes or flag changes.",
        "Attempts: "..attempts,
        "=== FIRST TIMES ==="
    }
    for _,key in ipairs({"player","loaded","character","levers","blackout","cutscene",
        "skipCreated","skipVisible","skipFirstClick","skipGone",
        "cutsceneCleared","introFinished"}) do
        summary[#summary+1]=key..": "..(milestones[key]~=nil and
            string.format("+%.3fs",milestones[key]) or "NOT OBSERVED")
    end
    if milestones.skipFirstClick and milestones.introFinished then
        summary[#summary+1]=string.format("Intro complete minus first click = %.3fs",
            milestones.introFinished-milestones.skipFirstClick)
    end
    summary[#summary+1]="=== EVENTS ==="
    summary[#summary+1]=table.concat(records,"\n")
    return table.concat(summary,"\n")
end
local function save(copy)
    local report=makeReport()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then makefolder("BeyyHub") end
        end) end
        local ok,err=pcall(writefile,savePath,report)
        if ok then print("[CH2 FAST SKIP] Saved "..savePath)
        else warn("[CH2 FAST SKIP] Save failed: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok,err=pcall(setclipboard,report)
        if ok then print("[CH2 FAST SKIP] Report COPIED to clipboard")
        else warn("[CH2 FAST SKIP] Clipboard error: "..tostring(err)) end
    end
end
local function stop()
    if not alive then return end
    save(false)
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    table.clear(connections)
end
env.__BEYY_CH2_FAST_SKIP_STOP=stop
env.__BEYY_CH2_FAST_SKIP_COPY=function()save(true)end
env.__BEYY_CH2_FAST_SKIP_REPORT=makeReport

local attached=nil
local function attach(p)
    if not p or attached==p then return end
    player=p
    attached=p
    first("player","LocalPlayer available")
    for _,name in ipairs({"CutsceneActive","IntroCutsceneFinished","NeedleInputLocked",
        "NeedleRoundComplete","Chapter2ReleaseActive"}) do
        changed(name,p:GetAttribute(name))
        connect(p:GetAttributeChangedSignal(name),function()
            local val=p:GetAttribute(name)
            changed(name,val)
            if name=="CutsceneActive" and val==true then first("cutscene","true") end
            if name=="CutsceneActive" and milestones.cutscene and val~=true then
                first("cutsceneCleared","flag cleared")
            end
            if name=="IntroCutsceneFinished" and val==true then first("introFinished","true") end
        end)
    end
    connect(p.CharacterAdded,function() first("character","CharacterAdded") end)
end
local function visible(obj)
    local cur=obj
    while cur do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        if cur:IsA("PlayerGui") then return true end
        cur=cur.Parent
    end
    return false
end
local lastSkipShown=false
local function inspect()
    if not player then return nil end
    if player.Character then first("character","already present") end
    if player:GetAttribute("IntroCutsceneFinished")==true then first("introFinished","true") end
    if player:GetAttribute("CutsceneActive")==true then first("cutscene","true") end
    local puzzles=Workspace:FindFirstChild("Puzzles")
    local lever=puzzles and puzzles:FindFirstChild("LeverPuzzle")
    local list=lever and lever:FindFirstChild("Levers")
    if list then first("levers","#"..tostring(#list:GetChildren())) end
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    local container=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local button=container and container:FindFirstChild("Button",true)
    if button and not button:IsA("GuiButton") then button=nil end
    if button then first("skipCreated","native button exists") end
    local shown=button and visible(button) or false
    if shown then
        first("skipVisible","native button visible")
        firstSkipVisibleAt=firstSkipVisibleAt or elapsed()
    end
    if lastSkipShown and not shown then first("skipGone","native button disappeared") end
    lastSkipShown=shown
    if black and visible(black) then
        local opacity=1-black.BackgroundTransparency
        first("blackout",string.format("opacity %.3f",opacity))
        changed("BlackOpacity",string.format("%.2f",opacity))
    end
    if button then
        changed("ButtonVisible",shown)
        changed("ButtonPosition",tostring(button.AbsolutePosition))
        changed("ButtonSize",tostring(button.AbsoluteSize))
    end
    return button,shown,black
end

local function safeToClick(button,shown)
    if not player or not button or not shown or not button.Parent then return false end
    if elapsed()>19 or player:GetAttribute("CutsceneActive")~=true
        or player:GetAttribute("IntroCutsceneFinished")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("Chapter2ReleaseActive")==true then return false end
    local endUi=player:FindFirstChildOfClass("PlayerGui")
    endUi=endUi and endUi:FindFirstChild("NeedleEndingUI")
    if endUi and endUi:IsA("ScreenGui") and endUi.Enabled then return false end
    local puzzle=ReplicatedStorage:FindFirstChild("Puzzles")
    if puzzle and (puzzle:GetAttribute("LeverPuzzleSolved")==true
        or (tonumber(puzzle:GetAttribute("SolvedPuzzleCount")) or 0)>0) then return false end
    return button.AbsoluteSize.X>8 and button.AbsoluteSize.Y>8
end

local function clickNative(button)
    local pos,size=button.AbsolutePosition,button.AbsoluteSize
    local inset=GuiService:GetGuiInset()
    local x,y=pos.X+size.X/2,pos.Y+size.Y/2
    local variant=attempts==1 and "with-GUI-inset" or "raw-viewport"
    if attempts==1 then x+=inset.X;y+=inset.Y end
    local down=false
    local pg=player and player:FindFirstChildOfClass("PlayerGui")
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    local opacity=black and black:IsA("GuiObject")
        and string.format("%.2f",1-black.BackgroundTransparency) or "unknown"
    record("ACTION",string.format(
        "Native GUI click #%d %s at (%.1f,%.1f); black opacity=%s",
        attempts,variant,x,y,opacity))
    local ok,err=pcall(function()
        VIM:SendMouseMoveEvent(x,y,game)
        task.wait(0.035)
        if not safeToClick(button,visible(button)) then return end
        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        down=true
        task.wait(0.075)
    end)
    if down then pcall(function() VIM:SendMouseButtonEvent(x,y,0,false,game,0) end) end
    record("ACTION",ok and ("Click result: down="..tostring(down).." (server outcome pending)") or
        ("Input error: "..tostring(err)))
end

record("BOOT","Queued test active; loaded="..tostring(game:IsLoaded())..
    " playerReady="..tostring(Players.LocalPlayer~=nil))
if game:IsLoaded() then first("loaded","already true") end
connect(game.Loaded,function()first("loaded","game.Loaded event")end)
connect(UserInputService.InputBegan,function(input,processed)
    if input.KeyCode==Enum.KeyCode.F8 then save(true) end
end)

task.spawn(function()
    while alive and elapsed()<duration do
        if Players.LocalPlayer and Players.LocalPlayer~=attached then attach(Players.LocalPlayer) end
        local ok,button,shown,black=pcall(inspect)
        if not ok then
            changed("InspectorError",button)
        elseif not busy and attempts<2 and safeToClick(button,shown)
            and (attempts==0 or elapsed()-lastAttemptAt>=2.1) then
            busy=true
            attempts+=1
            lastAttemptAt=elapsed()
            first("skipFirstClick","attempt #1 sent toward native button")
            local success,err=pcall(clickNative,button)
            if not success then record("ERROR","Click attempt failed: "..tostring(err)) end
            busy=false
        end
        local t=elapsed()
        if t>=15 and not changedValues.saved15 then
            changedValues.saved15="yes";save(false)
        end
        if t>=30 and not changedValues.saved30 then
            changedValues.saved30="yes";save(false)
        end
        task.wait(t<19 and 0.04 or 0.16)
    end
    if alive then
        record("DONE","42s test finished; clicks="..tostring(attempts))
        save(true)
        alive=false
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
        table.clear(connections)
    end
end)
