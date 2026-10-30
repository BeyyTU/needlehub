-- Beyy Chapter 2 Intro Black Screen Diagnostic v2
-- Standalone, passive. Does not click Skip, change camera, teleport, or modify BeyyHub.
-- Execute in Lobby BEFORE entering Chapter 2 to record the earliest available client state.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-intro-black-screen-diagnostic.lua"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer

if game.PlaceId==LOBBY then
    local env=_G
    if type(getgenv)=="function" then
        local ok,value=pcall(getgenv)
        if ok and type(value)=="table" then env=value end
    end
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        warn("[CH2 DIAG] queue_on_teleport is unavailable; run diagnostic manually as soon as Chapter 2 loads.")
        return
    end
    -- Queue the actual script text, not an HTTP fetch at destination.
    -- This avoids losing the first seconds of the black screen to download latency.
    local ok,body=pcall(function()
        return game:HttpGet(URL.."?preload="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Intro Black Screen Diagnostic v2",1,true)
        and type(loadstring)=="function" and loadstring(body)
    local payload=valid and body or
        ('loadstring(game:HttpGet("'..URL..'?run="..tostring(os.time())))()')
    local armed,err=pcall(queue,payload)
    if armed then
        print("[CH2 DIAG] Queued "..(valid and "preloaded, zero-download" or "online fallback")..
            " recorder for Chapter 2. Join the Chapter 2 round now.")
        print("[CH2 DIAG] Main BeyyHub files have NOT been changed.")
    else
        warn("[CH2 DIAG] Could not queue diagnostic: "..tostring(err))
    end
    return
end

if game.PlaceId~=CHAPTER2 then
    warn("[CH2 DIAG] Only runs in Lobby or Chapter 2. Current place="..tostring(game.PlaceId))
    return
end

local GLOBAL=(type(getgenv)=="function" and getgenv()) or _G
if type(GLOBAL.__BEYY_CH2_INTRO_DIAG_STOP)=="function" then
    pcall(GLOBAL.__BEYY_CH2_INTRO_DIAG_STOP)
end

local started=os.clock()
local alive=true
local connections={}
local events={}
local MAX_EVENTS=650
local first={}
local prev={}
local PATH="BeyyHub/chapter2_intro_black_screen_log.txt"
local watchFor=75
local lastSave=0
local lastGuiScan=-math.huge
local lastCoreScan=-math.huge
local lastSoundScan=-math.huge
local lastHeartbeat=-math.huge

local function elapsed() return os.clock()-started end
local function stamp()
    return string.format("+%.3fs",elapsed())
end
local function valueText(x)
    if x==nil then return "nil" end
    local ok,s=pcall(tostring,x)
    if not ok then return "<unreadable>" end
    s=s:gsub("[%c]+"," ")
    return #s>125 and s:sub(1,125).."..."
        or s
end
local function record(category,message)
    if not alive then return end
    local entry=stamp().." ["..category.."] "..valueText(message)
    events[#events+1]=entry
    if #events>MAX_EVENTS then table.remove(events,1) end
    print("[CH2 DIAG] "..entry)
end
local function milestone(key,message)
    if first[key]~=nil then return end
    first[key]=elapsed()
    record("FIRST",key..": "..valueText(message))
end
local function changed(key,value,category)
    local s=valueText(value)
    if prev[key]~=s then
        prev[key]=s
        record(category or "STATE",key.." = "..s)
    end
end
local function connect(signal,callback)
    local ok,conn=pcall(function() return signal:Connect(callback) end)
    if ok and conn then connections[#connections+1]=conn end
end

local attrNames={
    "IntroCutsceneFinished","CutsceneActive","NeedleInputLocked",
    "Chapter2ReleaseActive","NeedleRoundComplete","NeedleOwned",
    "CutscenePlaying","IntroFinished","Loading","GameStarted"
}
local function summarize()
    local order={
        "firstPlayer","firstGUI","firstSkip","firstSkipGone",
        "firstCover","firstCoverGone","firstCamera","firstCharacter",
        "firstRoot","firstLeverFolder","firstPuzzleWorkspace",
        "firstPuzzleRemotes","introFinished","firstUnlocked",
        "firstCowSound","firstHubUI"
    }
    local lines={}
    for _,key in ipairs(order) do
        if first[key]~=nil then
            lines[#lines+1]=key.." = +"..string.format("%.3f",first[key]).."s"
        else
            lines[#lines+1]=key.." = NOT OBSERVED"
        end
    end
    return table.concat(lines,"\n")
end
local function report()
    return table.concat({
        "CHAPTER 2 INTRO BLACK SCREEN DIAGNOSTIC v2",
        "Timing is relative to diagnostic start in the destination client, not the server's round start.",
        "PlaceId: "..tostring(game.PlaceId),
        "Elapsed: "..string.format("%.2f",elapsed()).."s",
        "game:IsLoaded(): "..tostring(game:IsLoaded()),
        "Passive only: no click, unlock, camera edit, remote fire, or teleport.",
        "IMPORTANT: Visible GUI/Camera observations CANNOT see every Roblox engine rendering overlay.",
        "=== MILESTONES ===",summarize(),
        "=== EVENTS ("..tostring(#events)..") ===",
        table.concat(events,"\n")
    },"\n")
end
local function save(copy)
    local text=report()
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end)
    end
    if type(writefile)=="function" then
        local ok,err=pcall(writefile,PATH,text)
        if ok then print("[CH2 DIAG] Saved "..PATH)
        else warn("[CH2 DIAG] Save failed: "..tostring(err)) end
    else
        print("[CH2 DIAG] No writefile; copy console lines manually.")
    end
    if copy then
        if type(setclipboard)=="function" then
            local ok,err=pcall(setclipboard,text)
            if ok then print("[CH2 DIAG] Complete report COPIED TO CLIPBOARD. Paste into ChatGPT.")
            else warn("[CH2 DIAG] Clipboard failed: "..tostring(err)) end
        else
            print("[CH2 DIAG] setclipboard unavailable. Log stored if writefile is available.")
        end
    end
    print("[CH2 DIAG] MILESTONE SUMMARY\n"..summarize())
    lastSave=elapsed()
end
local function stop()
    if not alive then return end
    save(false)
    alive=false
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    print("[CH2 DIAG] Tracing stopped; Main BeyyHub untouched.")
end
GLOBAL.__BEYY_CH2_INTRO_DIAG_STOP=stop
GLOBAL.__BEYY_CH2_INTRO_DIAG_COPY=function() save(true) end
GLOBAL.__BEYY_CH2_INTRO_DIAG_REPORT=report

record("BOOT","Probe injected; loaded="..tostring(game:IsLoaded())..
    " player="..tostring(player~=nil))
if not game:IsLoaded() then
    connect(game.Loaded,function() milestone("gameLoaded","game.Loaded fired") end)
else
    milestone("gameLoaded","already true when injected")
end

-- Queued scripts may run before Players.LocalPlayer is created.
-- The first version captured nil once and therefore missed the GUI, Skip and
-- player attributes for the entire session. Subscribe as soon as it appears.
local connectedPlayer=nil
local function attachPlayer(candidate)
    if not candidate or connectedPlayer==candidate then return end
    player=candidate
    connectedPlayer=candidate
    milestone("firstPlayer","LocalPlayer became available: "..candidate.Name)
    record("BOOT","LocalPlayer found; registering GUI, character and attribute observers")
    for _,name in ipairs(attrNames) do
        changed("Player."..name,player:GetAttribute(name),"ATTR")
        connect(player:GetAttributeChangedSignal(name),function()
            changed("Player."..name,player:GetAttribute(name),"ATTR")
            if name=="IntroCutsceneFinished" and player:GetAttribute(name)==true then
                milestone("introFinished","server/player marked the intro complete")
            elseif name=="NeedleInputLocked" and player:GetAttribute(name)==false then
                milestone("firstUnlocked","NeedleInputLocked=false")
            end
        end)
    end
    if player:GetAttribute("IntroCutsceneFinished")==true then
        milestone("introFinished","already true on injection")
    end
    if player:GetAttribute("NeedleInputLocked")==false then
        milestone("firstUnlocked","already false on injection")
    end
    connect(player.AttributeChanged,function(name)
        local n=name:lower()
        if n:find("intro",1,true) or n:find("cutscene",1,true)
            or n:find("input",1,true) or n:find("loading",1,true)
            or n:find("skip",1,true) or n:find("round",1,true) then
            changed("ExtraAttribute."..name,player:GetAttribute(name),"ATTR")
        end
    end)
    connect(player.CharacterAdded,function(char)
        milestone("firstCharacter","CharacterAdded")
        record("CHAR","CharacterAdded: "..char.Name)
    end)
    -- Watch whether PlayerGui has been constructed before visible ScreenGuis.
    connect(player.ChildAdded,function(child)
        if child:IsA("PlayerGui") then
            milestone("firstGUI","PlayerGui ChildAdded")
            record("GUI","PlayerGui created")
        end
    end)
    local pg=player:FindFirstChildOfClass("PlayerGui")
    if pg then milestone("firstGUI","PlayerGui already exists at LocalPlayer attachment") end
end
attachPlayer(player)

local rootWatched=nil
local humanoidWatched=nil
local cameraWatched=nil
local function watchCharacter()
    local character=player and player.Character
    if not character then
        changed("Character","missing","CHAR")
        return
    end
    milestone("firstCharacter","already replicated")
    changed("Character","present","CHAR")
    local root=character:FindFirstChild("HumanoidRootPart")
    if root and root~=rootWatched then
        rootWatched=root
        milestone("firstRoot","HumanoidRootPart exists")
        changed("Root.Anchored",root.Anchored,"CHAR")
        connect(root:GetPropertyChangedSignal("Anchored"),function()
            changed("Root.Anchored",root.Anchored,"CHAR")
        end)
    end
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid~=humanoidWatched then
        humanoidWatched=humanoid
        record("CHAR","Humanoid present")
        connect(humanoid:GetPropertyChangedSignal("WalkSpeed"),function()
            changed("Humanoid.WalkSpeed",humanoid.WalkSpeed,"CHAR")
        end)
        connect(humanoid:GetPropertyChangedSignal("PlatformStand"),function()
            changed("Humanoid.PlatformStand",humanoid.PlatformStand,"CHAR")
        end)
    end
    if humanoid then
        changed("Humanoid.WalkSpeed",humanoid.WalkSpeed,"CHAR")
        changed("Humanoid.PlatformStand",humanoid.PlatformStand,"CHAR")
    end
end
local function watchCamera()
    local camera=Workspace.CurrentCamera
    if not camera then
        changed("CurrentCamera","nil","CAMERA")
        return
    end
    if cameraWatched~=camera then
        cameraWatched=camera
        milestone("firstCamera","CurrentCamera created")
        changed("CurrentCamera","present","CAMERA")
        connect(camera:GetPropertyChangedSignal("CameraType"),function()
            changed("CameraType",camera.CameraType,"CAMERA")
        end)
        connect(camera:GetPropertyChangedSignal("CameraSubject"),function()
            changed("CameraSubject",camera.CameraSubject and camera.CameraSubject.ClassName,"CAMERA")
        end)
    end
    changed("CameraType",camera.CameraType,"CAMERA")
    changed("CameraSubject",camera.CameraSubject and camera.CameraSubject.ClassName,"CAMERA")
    changed("Viewport",camera.ViewportSize,"CAMERA")
end

local function isVisible(obj)
    local current=obj
    while current do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current:IsA("PlayerGui") or current:IsA("CoreGui") then return true end
        current=current.Parent
    end
    return false
end
local function path(obj)
    local out={}
    local cur=obj
    for _=1,5 do
        if not cur then break end
        table.insert(out,1,cur.Name)
        cur=cur.Parent
    end
    return table.concat(out,"/")
end
local function skipText(button)
    local n=button.Name:lower()
    if n:find("skip",1,true) then return true end
    if button:IsA("TextButton") and button.Text:lower():find("skip",1,true) then return true end
    for _,obj in ipairs(button:GetChildren()) do
        if obj:IsA("TextLabel") and obj.Text:lower():find("skip",1,true) then return true end
    end
    return false
end
local lastSkip=nil
local lastCover=nil
local function scanGui()
    local pg=player and player:FindFirstChildOfClass("PlayerGui")
    if not pg then
        changed("PlayerGui","missing","GUI")
        return
    end
    milestone("firstGUI","PlayerGui exists")
    changed("PlayerGui","present","GUI")
    local screens={}
    for _,g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            screens[#screens+1]=g.Name.."(order="..tostring(g.DisplayOrder)..")"
            if g.Name=="BeyyNativeHub" then milestone("firstHubUI","BeyyHub GUI has appeared") end
        end
    end
    table.sort(screens)
    changed("EnabledScreenGuis",table.concat(screens,", "):sub(1,440),"GUI")
    local camera=Workspace.CurrentCamera
    local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
    local vw,vh=math.max(1,viewport.X),math.max(1,viewport.Y)
    local skip=nil
    local cover=nil
    local bestScore=-math.huge
    for _,g in ipairs(pg:GetDescendants()) do
        if g:IsA("GuiObject") and isVisible(g) then
            if g:IsA("GuiButton") and not skip and skipText(g)
                and not path(g):find("NeedleEndingUI",1,true) then
                skip=g
            end
            local pos,size=g.AbsolutePosition,g.AbsoluteSize
            if size.X>vw*0.80 and size.Y>vh*0.72
                and pos.X<vw*0.20 and pos.Y<vh*0.20 then
                local bg=g.BackgroundTransparency
                local col=g.BackgroundColor3
                local darkness=(col.R+col.G+col.B)/3
                local hint=g.Name:lower()
                local named=hint:find("load",1,true)
                    or hint:find("black",1,true) or hint:find("fade",1,true)
                    or hint:find("cover",1,true) or hint:find("intro",1,true)
                local image=(g:IsA("ImageLabel") or g:IsA("ImageButton"))
                    and g.ImageTransparency<0.25
                local blackBg=bg<0.4 and darkness<0.19
                if blackBg or named or image then
                    local score=(1-bg)*2+(1-darkness)*2+(named and 0.5 or 0)
                    if score>bestScore then
                        cover=g
                        bestScore=score
                    end
                end
            end
        end
    end
    local skipName=skip and path(skip) or nil
    if skipName~=lastSkip then
        if skip then
            milestone("firstSkip",skipName)
            record("SKIP","Visible Skip candidate: "..skipName..
                " pos="..valueText(skip.AbsolutePosition)..
                " size="..valueText(skip.AbsoluteSize))
        elseif lastSkip then
            milestone("firstSkipGone","Skip no longer visible")
            record("SKIP","Skip candidate disappeared")
        end
        lastSkip=skipName
    end
    local coverName=cover and (path(cover)..
        " bgOpacity="..string.format("%.2f",1-cover.BackgroundTransparency)..
        " rgb="..valueText(cover.BackgroundColor3)) or nil
    if coverName~=lastCover then
        if cover then
            milestone("firstCover",coverName)
            record("OVERLAY","Full-screen overlay candidate: "..coverName)
        elseif lastCover then
            milestone("firstCoverGone","Visible overlay candidate disappeared")
            record("OVERLAY","No covering PlayerGui candidate found")
        end
        lastCover=coverName
    end
end

local lastCore=nil
local function scanCore()
    local ok,items=pcall(function()
        local cg=game:GetService("CoreGui")
        local arr={}
        for _,obj in ipairs(cg:GetChildren()) do
            if obj:IsA("ScreenGui") then
                arr[#arr+1]=obj.Name..":"..tostring(obj.Enabled)
            end
        end
        table.sort(arr)
        return arr
    end)
    local state=ok and table.concat(items,", "):sub(1,320)
        or "CoreGui inaccessible from this executor"
    if state~=lastCore then lastCore=state;record("COREGUI",state) end
end

local function scanPuzzles()
    local w=Workspace:FindFirstChild("Puzzles")
    local r=ReplicatedStorage:FindFirstChild("Puzzles")
    if w then milestone("firstPuzzleWorkspace","Workspace.Puzzles exists") end
    if r then milestone("firstPuzzleRemotes","ReplicatedStorage.Puzzles exists") end
    changed("Workspace.Puzzles",w and "present" or "missing","PUZZLE")
    changed("ReplicatedStorage.Puzzles",r and "present" or "missing","PUZZLE")
    local lever=w and w:FindFirstChild("LeverPuzzle")
    local folder=lever and lever:FindFirstChild("Levers")
    if folder then milestone("firstLeverFolder","LeverPuzzle.Levers count="..tostring(#folder:GetChildren())) end
    changed("Lever targets",folder and tostring(#folder:GetChildren()) or "missing","PUZZLE")
    if r then
        for _,a in ipairs({"EscapeReady","LeverPuzzleSolved","SolvedPuzzleCount"}) do
            changed("Puzzles."..a,r:GetAttribute(a),"PUZZLE")
        end
    end
end
local function scanSound()
    local list={}
    local ok=pcall(function()
        for _,s in ipairs(SoundService:GetDescendants()) do
            if s:IsA("Sound") and s.IsPlaying then
                local n=s.Name:lower()
                if n:find("cow",1,true) or n:find("moo",1,true)
                    or n:find("intro",1,true) or n:find("cutscene",1,true) then
                    list[#list+1]=s.Name
                end
            end
        end
    end)
    if ok and #list>0 then
        milestone("firstCowSound","Playing named intro/cow sound(s): "..table.concat(list,","))
        changed("NamedSoundsPlaying",table.concat(list,","),"AUDIO")
    end
end

connect(UserInputService.InputBegan,function(input,processed)
    if input.KeyCode==Enum.KeyCode.F8 then
        save(true)
    elseif input.KeyCode==Enum.KeyCode.F7 then
        record("MANUAL","F7 pressed (black screen still visible? Use this as a visual time marker)")
        save(false)
    end
end)
connect(UserInputService.WindowFocused,function()record("WINDOW","window focused")end)
connect(UserInputService.WindowFocusReleased,function()record("WINDOW","window focus lost")end)
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),watchCamera)
record("BOOT","F7 = visual marker; F8 = copy full report; automatic save at 15/30/45/75 sec.")
record("BOOT","This diagnostic cannot bypass Roblox engine loading; it identifies client-visible gates.")

task.spawn(function()
    while alive and elapsed()<watchFor do
        local t=elapsed()
        if Players.LocalPlayer~=connectedPlayer and Players.LocalPlayer then
            attachPlayer(Players.LocalPlayer)
        end
        watchCharacter()
        watchCamera()
        scanPuzzles()
        if t-lastGuiScan>= (t<=18 and 0.10 or 0.25) then
            lastGuiScan=t
            local ok,err=pcall(scanGui)
            if not ok then changed("GUI scan error",err,"ERROR") end
        end
        if t-lastCoreScan>=1.0 then
            lastCoreScan=t
            scanCore()
        end
        if t-lastSoundScan>=0.75 then
            lastSoundScan=t
            scanSound()
        end
        if t-lastHeartbeat>=2 then
            lastHeartbeat=t
            record("HEARTBEAT","loaded="..tostring(game:IsLoaded())..
                " playerReady="..tostring(player~=nil)..
                " guiReady="..tostring(player and player:FindFirstChildOfClass("PlayerGui")~=nil)..
                " blackCandidate="..tostring(lastCover~=nil)..
                " visibleSkip="..tostring(lastSkip~=nil)..
                " introDone="..valueText(player and player:GetAttribute("IntroCutsceneFinished"))..
                " inputLocked="..valueText(player and player:GetAttribute("NeedleInputLocked")))
        end
        if (t>=15 and lastSave<15) or (t>=30 and lastSave<30)
            or (t>=45 and lastSave<45) then
            save(false)
        end
        task.wait(t<=18 and 0.10 or 0.25)
    end
    if alive then
        record("DONE","75-second passive capture completed")
        save(true)
        alive=false
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
        table.clear(connections)
    end
end)
