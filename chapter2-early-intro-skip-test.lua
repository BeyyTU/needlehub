-- Beyy Chapter 2 Early Intro Skip Test v1
-- Separate experimental script. The ONLY active action is one early native
-- GUI Skip signal if a connected Skip handler exists while the button is hidden.
-- Never teleports, edits game attributes, modifies camera, or fires remotes.
-- Execute in the lobby BEFORE entering Chapter 2.
local LOBBY=77108422251420
local CH2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-early-intro-skip-test.lua"
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local pl=Players.LocalPlayer
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end

if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then
        warn("[CH2 EARLY] queue_on_teleport unavailable; run as soon as Chapter 2 starts.")
        return
    end
    local ok,scriptText=pcall(function()
        return game:HttpGet(URL.."?warm="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(scriptText)=="string"
        and scriptText:find("Beyy Chapter 2 Early Intro Skip Test v1",1,true)
        and type(loadstring)=="function" and type(loadstring(scriptText))=="function"
    local payload=valid and scriptText or
        ('loadstring(game:HttpGet("'..URL..'?fallback="..tostring(os.time())))()')
    local success,err=pcall(queue,payload)
    if success then
        print("[CH2 EARLY] One-run early Skip experiment armed ("..
            (valid and "preloaded" or "online fallback").."). Join Chapter 2 now.")
    else
        warn("[CH2 EARLY] Queue failed: "..tostring(err))
    end
    return
end
if game.PlaceId~=CH2 then
    warn("[CH2 EARLY] Unsupported place "..tostring(game.PlaceId))
    return
end

local oldStop=env.__BEYY_CH2_EARLY_STOP
if type(oldStop)=="function" then pcall(oldStop) end
local alive=true
local started=os.clock()
local duration=37
local entries={}
local first={}
local prev={}
local connections={}
local lastSave=0
local file="BeyyHub/chapter2_early_intro_skip_test.txt"
local didTry=false
local attemptAt=nil
local attemptMethod=nil
local attemptedBeforeVisible=nil
local skipWasVisible=false
local function elapsed() return os.clock()-started end
local function log(kind,msg)
    if not alive then return end
    local row=string.format("+%.3fs [%s] %s",elapsed(),kind,tostring(msg))
    entries[#entries+1]=row
    if #entries>500 then table.remove(entries,1) end
    print("[CH2 EARLY] "..row)
end
local function firstTime(key,msg)
    if first[key] then return end
    first[key]=elapsed()
    log("FIRST",key.." "..tostring(msg or ""))
end
local function changed(key,value)
    local str=tostring(value)
    if str~=prev[key] then
        prev[key]=str
        log("STATE",key.."="..str)
    end
end
local function connect(signal,fn)
    local ok,c=pcall(function() return signal:Connect(fn) end)
    if ok and c then connections[#connections+1]=c end
end
local function report()
    local summary={
        "CHAPTER 2 EARLY INTRO SKIP TEST v1",
        "Times relative to test injection; game:IsLoaded()="..tostring(game:IsLoaded()),
        "Button exists before visible: "..tostring(first.buttonExists~=nil and
            (first.buttonVisible==nil or first.buttonExists<first.buttonVisible)),
        "Early native signal sent: "..tostring(didTry),
        "Method: "..tostring(attemptMethod),
        "Attempt at +"..tostring(attemptAt and string.format("%.3f",attemptAt) or "N/A").."s",
        "Intro completed at +"..tostring(first.introFinished and string.format("%.3f",first.introFinished) or "NOT OBSERVED").."s",
        "Do not infer that a sent signal was accepted: look for IntroCutsceneFinished and cutscene events.",
        "Only native GUI signals were used; no direct server remote, attribute mutation, teleport or camera manipulation.",
        "=== FIRST OBSERVATIONS ==="
    }
    for _,key in ipairs({"player","gameLoaded","character","leverFolder","cutsceneActive",
        "blackVisible","buttonContainerExists","buttonExists","buttonVisible","introFinished","cutsceneCleared"}) do
        summary[#summary+1]=key..": "..(first[key] and string.format("+%.3fs",first[key]) or "NOT OBSERVED")
    end
    summary[#summary+1]="=== EVENTS ==="
    summary[#summary+1]=table.concat(entries,"\n")
    return table.concat(summary,"\n")
end
local function save(copy)
    local body=report()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end) end
        local ok,err=pcall(writefile,file,body)
        if ok then print("[CH2 EARLY] Saved "..file)
        else warn("[CH2 EARLY] Save error: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok,err=pcall(setclipboard,body)
        if ok then print("[CH2 EARLY] Full result copied to clipboard")
        else warn("[CH2 EARLY] Clipboard error: "..tostring(err)) end
    end
    lastSave=elapsed()
end
local function stop()
    if not alive then return end
    save(false)
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
end
env.__BEYY_CH2_EARLY_STOP=stop
env.__BEYY_CH2_EARLY_REPORT=report
env.__BEYY_CH2_EARLY_COPY=function() save(true) end

log("START","Diagnostic injected, LocalPlayer="..tostring(pl~=nil)..
    " loaded="..tostring(game:IsLoaded()))
if game:IsLoaded() then firstTime("gameLoaded","already loaded") end
if not game:IsLoaded() then
    connect(game.Loaded,function()firstTime("gameLoaded","game.Loaded")end)
end

local watchingPlayer=nil
local function attachPlayer(player)
    if not player or watchingPlayer==player then return end
    watchingPlayer=player
    pl=player
    firstTime("player",player.Name)
    for _,attr in ipairs({"IntroCutsceneFinished","CutsceneActive","NeedleInputLocked",
        "Chapter2ReleaseActive","NeedleRoundComplete"}) do
        changed(attr,player:GetAttribute(attr))
        connect(player:GetAttributeChangedSignal(attr),function()
            local val=player:GetAttribute(attr)
            changed(attr,val)
            if attr=="IntroCutsceneFinished" and val==true then
                firstTime("introFinished","server/player intro flag=true")
            end
            if attr=="CutsceneActive" and val==true then
                firstTime("cutsceneActive","flag=true")
            elseif attr=="CutsceneActive" and val~=true then
                firstTime("cutsceneCleared","CutsceneActive cleared after being active")
            end
        end)
    end
    connect(player.CharacterAdded,function()
        firstTime("character","CharacterAdded")
    end)
end

local function visible(obj)
    local node=obj
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node:IsA("PlayerGui") then return true end
        node=node.Parent
    end
    return false
end
local function getButton()
    local pg=pl and pl:FindFirstChildOfClass("PlayerGui")
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    local container=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local button=container and container:FindFirstChild("Button",true)
    if button and not button:IsA("GuiButton") then button=nil end
    return fade,black,container,button
end
local function handlerCounts(button)
    if type(getconnections)~="function" then return nil,nil end
    local function count(signal)
        local ok,items=pcall(getconnections,signal)
        if not ok or type(items)~="table" then return nil end
        local n=0
        for _,c in ipairs(items) do
            if c.Enabled~=false then n+=1 end
        end
        return n
    end
    return count(button.Activated),count(button.MouseButton1Click)
end
local function safeEarly()
    if not pl or elapsed()>12 then return false end
    if pl:GetAttribute("IntroCutsceneFinished")==true
        or pl:GetAttribute("NeedleRoundComplete")==true
        or pl:GetAttribute("Chapter2ReleaseActive")==true
        or pl:GetAttribute("CutsceneActive")~=true then return false end
    local puzzle=ReplicatedStorage:FindFirstChild("Puzzles")
    if puzzle and ((puzzle:GetAttribute("SolvedPuzzleCount") or 0)>0
        or puzzle:GetAttribute("LeverPuzzleSolved")==true) then return false end
    return true
end
local lastAttemptCheck=0
local function watch()
    if Players.LocalPlayer and Players.LocalPlayer~=watchingPlayer then
        attachPlayer(Players.LocalPlayer)
    end
    if not pl then return end
    if pl.Character then firstTime("character","already present") end
    local workspacePuzzles=Workspace:FindFirstChild("Puzzles")
    local levers=workspacePuzzles and workspacePuzzles:FindFirstChild("LeverPuzzle")
    levers=levers and levers:FindFirstChild("Levers")
    if levers then firstTime("leverFolder","count="..tostring(#levers:GetChildren())) end
    if pl:GetAttribute("IntroCutsceneFinished")==true then
        firstTime("introFinished","already true")
    end
    if pl:GetAttribute("CutsceneActive")==true then firstTime("cutsceneActive","already true") end
    local fade,black,container,button=getButton()
    if container then firstTime("buttonContainerExists","SkipCutsceneButton") end
    if button then firstTime("buttonExists","Button exists") end
    local shown=button and visible(button) or false
    if shown then
        skipWasVisible=true
        firstTime("buttonVisible","native Skip became visible")
    end
    if black and visible(black) then
        firstTime("blackVisible","opacity="..string.format("%.3f",1-black.BackgroundTransparency))
        changed("Black.opacity",string.format("%.2f",1-black.BackgroundTransparency))
    end
    if button then
        changed("Skip.Button.Visible",button.Visible)
        changed("Skip.Button.ParentVisible",container and container.Visible)
        changed("Skip.Button.OnScreen",shown)
        if not didTry and not shown and safeEarly()
            and type(firesignal)=="function" then
            local activated,clicked=handlerCounts(button)
            changed("Skip handlers Activated/MouseButton1Click",
                tostring(activated).."/"..tostring(clicked))
            -- Only execute an actual connected native handler. Never force
            -- a server remote or manufacture IntroCutsceneFinished flags.
            local event=nil
            if clicked and clicked>0 then
                event=button.MouseButton1Click
                attemptMethod="MouseButton1Click"
            elseif activated and activated>0 then
                event=button.Activated
                attemptMethod="Activated"
            end
            if event then
                didTry=true
                attemptAt=elapsed()
                attemptedBeforeVisible=true
                log("ACTION","ONE hidden native Skip signal via "..attemptMethod..
                    " at +"..string.format("%.3f",attemptAt).."s; no direct remote")
                local ok,err=pcall(firesignal,event)
                log("ACTION",ok and "Signal dispatch succeeded (not server confirmation)"
                    or ("Signal dispatch failed: "..tostring(err)))
            end
        end
    end
end

task.spawn(function()
    while alive and elapsed()<duration do
        local ok,err=pcall(watch)
        if not ok then changed("watch error",err) end
        local t=elapsed()
        if t>=10 and lastSave<10 or t>=20 and lastSave<20
            or t>=30 and lastSave<30 then save(false) end
        task.wait(t<15 and 0.05 or 0.16)
    end
    if alive then
        log("DONE","Capture complete; hidden attempt="..tostring(didTry))
        save(true)
        alive=false
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    end
end)
