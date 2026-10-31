-- Beyy Chapter 2 Standalone V31-style Rebuild v2
-- v31: fast Picture/Color shared anchor + near-keypad Submit; no lever actions.
-- Retain v6 CINEFIX3 deferred intro Skip, v9 jump-safe return, standalone
-- v28 Vacuum/TNT upgrades, and persistent replay teleport auto-loading.
-- Does not modify BeyyHub Main's integrated v33.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-deferred-invisible-skip-test.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",
        cache="BeyyHub/chapter2_integrated_v33_cutscene_v6_cinefix3.lua"},
    {name="HOLD",file="chapter2-puzzle-position-diagnostic.lua",
        marker="Beyy Chapter 2 Teleport-Hold and Return Diagnostic v9",
        cache="BeyyHub/chapter2_v31_rebuild_hold_v9_jumpfix.lua"},
    {name="PUZZLES",file="chapter2-no-levers-puzzles-keypad-confirm-test.lua",
        marker="Beyy Chapter 2 No-Levers Puzzle Worker v31 KEYPAD QUICK SUBMIT TEST",
        cache="BeyyHub/chapter2_v31_rebuild_puzzles_v31.lua"},
    {name="UPGRADES",file="chapter2-standalone-cutscene-upgrades.lua",
        marker="Beyy Chapter 2 Standalone Cutscene Auto Upgrades v28 (Vacuum Power + TNT Power + TNT Speed)",
        cache="BeyyHub/chapter2_standalone_cutscene_upgrades_v28.lua"},
}
local function log(line)
    print("[CH2 STANDALONE] "..tostring(line))
end
local function fail(message)
    warn("[CH2 STANDALONE] "..tostring(message))
end
local function valid(body,item)
    return type(body)=="string" and #body>3000
        and body:find(item.marker,1,true)~=nil
end
local function compile(body)
    local ok,fn,err=pcall(loadstring,body)
    if ok and type(fn)=="function" then return fn,nil end
    return nil,tostring(ok and err or fn)
end
local function request(item,attempt)
    return game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/"..
        item.file.."?chapter2-v31-rebuild-v2="..tostring(os.time())..
        "-"..tostring(attempt))
end
local function fetch(item,allowCache)
    -- A lobby preflight saves the exact verified component to the executor's
    -- disk when available; Chapter 2 uses it without another network request.
    if allowCache and type(readfile)=="function" then
        local ok,data=pcall(readfile,item.cache)
        if ok and valid(data,item) then
            local fn,err=compile(data)
            if fn then return fn,"cached",data end
            fail(item.name.." cached source compile: "..tostring(err))
        end
    end
    local reason="no response"
    for attempt=1,3 do
        local ok,body=pcall(request,item,attempt)
        if ok and valid(body,item) then
            local fn,err=compile(body)
            if fn then return fn,"downloaded",body end
            reason="compile: "..tostring(err)
        else
            reason=ok and "invalid response/version" or tostring(body)
        end
        task.wait(0.25*attempt)
    end
    return nil,reason,nil
end
local function cache(item,body)
    if not body or type(writefile)~="function" then return end
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end)
    end
    pcall(writefile,item.cache,body)
end
local env=_G
if type(getgenv)=="function" then
    local ok,val=pcall(getgenv)
    if ok and type(val)=="table" then env=val end
end
if game.PlaceId==LOBBY then
    -- Preflight all four independently versioned modules before queuing the small bootstrap.
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        fail("queue_on_teleport unavailable. Execute loader again in Chapter 2.")
        return
    end
    local allGood=true
    for _,item in ipairs(paths) do
        local fn,source,body=fetch(item,true)
        if fn then
            cache(item,body)
            log("Lobby preflight "..item.name.." compiled ("..source..")")
        else
            allGood=false
            fail("Lobby preflight "..item.name.." failed: "..source)
        end
    end
    if not allGood then
        fail("At least one module failed preflight. Nothing queued.")
        return
    end
    local fn,why,body=fetch({name="BOOTSTRAP",
        file="chapter2-no-levers-cutscene-test.lua",
        marker="Beyy Chapter 2 Standalone V31-style Rebuild v2",
        cache="BeyyHub/chapter2_v31_rebuild_v2_bootstrap.lua"},false)
    if not fn then
        fail("Bootstrap failed preflight: "..tostring(why))
        return
    end
    local ok,err=pcall(queue,body)
    if not ok then
        fail("queue_on_teleport failed: "..tostring(err))
    else
        log("V31-style solver, cutscene, return and TNT/Vacuum upgrades queued for Chapter 2.")
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    fail("This script runs only from the lobby or Chapter 2.")
    return
end
-- Queue the same v31-style standalone entry point on EVERY Chapter 2 arrival.
-- queue_on_teleport is normally consumed by a single teleport, so the new
-- server must arm it again for the next replay.
local function armReplayAutoload()
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        fail("Replay autoload unavailable: executor does not expose queue_on_teleport.")
        return false
    end
    local payload=[==[
-- Chapter 2 v31-style puzzle + cinematic + upgrades: replay continuation.
local Players=game:GetService("Players")
local url="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local deadline=os.clock()+15
while os.clock()<deadline and (not game:IsLoaded() or not Players.LocalPlayer) do
    task.wait(0.10)
end
for attempt=1,8 do
    local ok,body=pcall(function()
        return game:HttpGet(url.."?standalone-replay="..tostring(os.time()).."-"..tostring(attempt))
    end)
    if ok and type(body)=="string"
        and body:find("Beyy Chapter 2 Standalone V31-style Rebuild v2",1,true) then
        local fn,compileError=loadstring(body)
        if fn then
            local ran,runError=pcall(fn)
            if ran then return end
            warn("[CH2 STANDALONE] Replay autoload execution: "..tostring(runError))
        else
            warn("[CH2 STANDALONE] Replay autoload compile: "..tostring(compileError))
        end
    end
    task.wait(0.25)
end
warn("[CH2 STANDALONE] Replay autoload could not load the standalone script.")
]==]
    local ok,err=pcall(queue,payload)
    if not ok then
        fail("Replay autoload queue failed: "..tostring(err))
        return false
    end
    log("REPLAY AUTOLOAD ARMED: v31 puzzles + camera/Skip/return + TNT/Vacuum upgrades after next teleport.")
    return true
end
local function launch(item)
    local fn,source=fetch(item,true)
    if not fn then
        fail(item.name.." could not start: "..tostring(source))
        return false
    end
    local ok,err=pcall(fn)
    if not ok then
        fail(item.name.." startup error: "..tostring(err))
        return false
    end
    log(item.name.." started ("..source..")")
    return true
end
-- Capture the spawn position before any puzzle worker moves the character.
-- The v9 return controller uses this immutable starting position only after
-- all three puzzles are server-confirmed.
if env.__BEYY_CH2_HOLD_FOLLOW_SOLVER==true then
    fail("Another integrated Chapter 2 puzzle/return worker is active. Restart Roblox and run only this standalone.")
    return false
end
local player=Players.LocalPlayer
local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not root then
    local deadline=os.clock()+5
    repeat
        task.wait(0.05)
        player=Players.LocalPlayer
        root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    until root or os.clock()>=deadline
end
if not root then
    fail("No initial HumanoidRootPart: refusing unsafe return position")
    return false
end
env.__BEYY_CH2_HOLD_CAPTURE={Character=player.Character,CFrame=root.CFrame}
env.__BEYY_CH2_HOLD_FOLLOW_SOLVER=true
log("V31 REBUILD v2: saved spawn and facing "..tostring(root.Position))
log("Components: v31 keypad quick-submit / CINEFIX3 deferred Skip and camera / v9 jumpfix return / v28 three-track upgrades")
local okCutscene=launch(paths[1])
local okHold=launch(paths[2])
local okPuzzle=launch(paths[3])
local okUpgrade=launch(paths[4])
if not (okCutscene and okHold and okPuzzle and okUpgrade) then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " hold="..tostring(okHold).." puzzle="..tostring(okPuzzle)..
        " upgrades="..tostring(okUpgrade))
    for _,key in ipairs({
        "__BEYY_CH2_COMBO_STOP","__BEYY_CH2_SPOT_STOP",
        "__BEYY_CH2_CUTSCENE_ONLY_STOP","__BEYY_CH2_AUTO_UPGRADES_STOP"}) do
        if type(env[key])=="function" then pcall(env[key],"partial v31 startup cleanup") end
    end
    env.__BEYY_CH2_HOLD_FOLLOW_SOLVER=nil
    env.__BEYY_CH2_HOLD_CAPTURE=nil
    return false
end
log("V31-style Picture/Color/Number active (NO lever requests); native intro Skip deferred until 3/3.")
log("3/3: immediate return to saved hay spawn with sudden-snapback-only correction.")
log("Cutscene non-final bypass CINEFIX3; final ending protected; TNT Power/Speed + Vacuum Power at 0.05s.")
armReplayAutoload()
return true
