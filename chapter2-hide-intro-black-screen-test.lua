-- Beyy Chapter 2 Black Screen Visual Hide Test v1
-- STANDALONE TEST: hides ONLY PlayerGui.CutsceneFade.Black during the intro.
-- Does not touch levers, cutscene status, character, camera or server remotes.
-- Run in lobby before entering Chapter 2, or during Chapter 2 while intro plays.
local LOBBY=77108422251420
local CH2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-hide-intro-black-screen-test.lua"
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local env=_G
if type(getgenv)=="function" then
    local ok,result=pcall(getgenv)
    if ok and type(result)=="table" then env=result end
end
if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then
        warn("[CH2 BLACK TEST] queue_on_teleport unavailable. Run manually immediately on joining Chapter 2.")
        return
    end
    -- Preload now to avoid an HTTP delay on arrival.
    local ok,body=pcall(function()
        return game:HttpGet(URL.."?preload="..tostring(os.time()).."-"..tostring(math.random(10000,99999)))
    end)
    local valid=ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Black Screen Visual Hide Test v1",1,true)
        and type(loadstring)=="function" and type(loadstring(body))=="function"
    local payload=valid and body or
        ('loadstring(game:HttpGet("'..URL..'?run="..tostring(os.time())))()')
    local armed,err=pcall(queue,payload)
    if armed then
        print("[CH2 BLACK TEST] Queued ("..(valid and "preloaded" or "online fallback").."). Enter Chapter 2.")
    else
        warn("[CH2 BLACK TEST] Could not queue: "..tostring(err))
    end
    return
end
if game.PlaceId~=CH2 then
    warn("[CH2 BLACK TEST] Only Chapter 2 supported. PlaceId="..tostring(game.PlaceId))
    return
end

local existing=env.__BEYY_CH2_BLACK_VISUAL_STOP
if type(existing)=="function" then pcall(existing) end

local started=os.clock()
local alive=true
local connections={}
local entries={}
local times={}
local overlay=nil
local originalVisible=nil
local restored=false
local introDoneAt=nil
local file="BeyyHub/chapter2_black_screen_visual_test.txt"
local function elapsed() return os.clock()-started end
local function emit(kind,msg)
    local line=string.format("+%.3fs [%s] %s",elapsed(),kind,tostring(msg))
    entries[#entries+1]=line
    if #entries>450 then table.remove(entries,1) end
    print("[CH2 BLACK TEST] "..line)
end
local function once(name,details)
    if times[name] then return end
    times[name]=elapsed()
    emit("FIRST",name.." "..tostring(details or ""))
end
local function connect(signal,cb)
    local ok,c=pcall(function() return signal:Connect(cb) end)
    if ok and c then connections[#connections+1]=c end
end
local function report()
    local rows={
        "CHAPTER 2 BLACK SCREEN VISUAL HIDE TEST v1",
        "Times from queued script injection, not server round start.",
        "Only a local GUI was changed. This does NOT start puzzles or fast-forward the server.",
        "Whether the camera scene was visible must be determined visually.",
        "=== MILESTONES ==="
    }
    for _,key in ipairs({"player","loaded","character","overlayFound",
        "overlayHidden","skipVisible","introFinished","overlayRestored",
        "sceneVisibleByF6","stillBlackByF7"}) do
        rows[#rows+1]=key.." = "..(times[key] and string.format("+%.3fs",times[key]) or "NOT OBSERVED")
    end
    rows[#rows+1]="=== EVENTS ==="
    rows[#rows+1]=table.concat(entries,"\n")
    return table.concat(rows,"\n")
end
local function save(copy)
    local body=report()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then
            pcall(function()
                if type(isfolder)~="function" or not isfolder("BeyyHub") then
                    makefolder("BeyyHub")
                end
            end)
        end
        local ok,err=pcall(writefile,file,body)
        if ok then print("[CH2 BLACK TEST] Saved "..file)
        else warn("[CH2 BLACK TEST] Save failed: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok,err=pcall(setclipboard,body)
        if ok then print("[CH2 BLACK TEST] Report copied")
        else warn("[CH2 BLACK TEST] Clipboard error: "..tostring(err)) end
    end
end
local function restore(reason)
    if restored then return end
    restored=true
    if overlay and overlay.Parent and originalVisible~=nil then
        local ok,err=pcall(function() overlay.Visible=originalVisible end)
        if not ok then emit("WARN","Restore failed: "..tostring(err)) end
    end
    once("overlayRestored",reason)
end
local function stop()
    if not alive then return end
    restore("test stopped")
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    table.clear(connections)
    save(false)
end
env.__BEYY_CH2_BLACK_VISUAL_STOP=stop
env.__BEYY_CH2_BLACK_VISUAL_COPY=function()save(true)end
env.__BEYY_CH2_BLACK_VISUAL_REPORT=report

connect(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F6 then
        once("sceneVisibleByF6","user marked 3D scene visible; F6")
    elseif input.KeyCode==Enum.KeyCode.F7 then
        once("stillBlackByF7","user marked screen still black; F7")
    elseif input.KeyCode==Enum.KeyCode.F8 then
        save(true)
    end
end)
local player=nil
local hadPlayer=false
local lastSkip=false
local lastAnchor=nil
emit("START","Injected. F6=scene visible, F7=still black, F8=copy report.")
if game:IsLoaded() then once("loaded","game already loaded")
else connect(game.Loaded,function() once("loaded","game.Loaded") end) end

task.spawn(function()
    while alive and elapsed()<35 do
        local t=elapsed()
        player=Players.LocalPlayer or player
        if player and not hadPlayer then
            hadPlayer=true
            once("player","LocalPlayer appeared")
        end
        if player then
            if player.Character then
                once("character","local Character exists")
                local root=player.Character:FindFirstChild("HumanoidRootPart")
                if root and root.Anchored~=lastAnchor then
                    lastAnchor=root.Anchored
                    emit("STATE","Character anchored="..tostring(lastAnchor))
                end
            end
            local done=player:GetAttribute("IntroCutsceneFinished")==true
            if done and not introDoneAt then
                introDoneAt=t
                once("introFinished","IntroCutsceneFinished=true")
            end
            local pg=player:FindFirstChildOfClass("PlayerGui")
            local fade=pg and pg:FindFirstChild("CutsceneFade")
            local black=fade and fade:FindFirstChild("Black",true)
            if black and black:IsA("GuiObject") then
                if overlay~=black then
                    overlay=black
                    originalVisible=black.Visible
                    once("overlayFound","CutsceneFade.Black; initially visible="..tostring(originalVisible))
                end
                if not introDoneAt and not restored then
                    if black.Visible then
                        local ok,err=pcall(function()black.Visible=false end)
                        if ok then once("overlayHidden","black GUI made invisible")
                        else emit("WARN","Cannot hide black GUI: "..tostring(err)) end
                    end
                end
                if introDoneAt and not restored then
                    local fadeFinished=(not fade.Enabled)
                        or black.BackgroundTransparency>=0.98
                    if fadeFinished or t-introDoneAt>5 then
                        restore(fadeFinished and "intro fade transparent/disabled" or
                            "restored after max 5s post-intro")
                    end
                end
            end
            local skip=fade and fade:FindFirstChild("SkipCutsceneButton",true)
            local button=skip and skip:FindFirstChild("Button",true)
            if button and button:IsA("GuiButton") and button.Visible and not lastSkip then
                local parent=button.Parent
                local shown=true
                while parent and parent~=pg do
                    if parent:IsA("GuiObject") and not parent.Visible then shown=false;break end
                    if parent:IsA("ScreenGui") and not parent.Enabled then shown=false;break end
                    parent=parent.Parent
                end
                if shown then
                    once("skipVisible","native Skip exists; can click normally")
                    lastSkip=true
                end
            end
        end
        if t>15 and not times.saved15 then
            times.saved15=t
            save(false)
        end
        task.wait(t<18 and 0.03 or 0.1)
    end
    if alive then
        restore("35s test cleanup")
        once("complete","35s test ended")
        save(true)
        alive=false
        for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
        table.clear(connections)
    end
end)
