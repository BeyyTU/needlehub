-- Beyy Chapter 2 Puzzle + Teleport Hold Combined Test v2
-- Experimental 4-module bootstrap: native cutscene, bounded position hold,
-- no-levers 3-puzzle worker, Vacuum Power-only cash upgrader.
-- Follow the verified puzzle worker's room point; return to the captured
-- original Chapter2 starting spot at 3/3 confirmed puzzles.
-- Does not change BeyyHub Main or the normal Chapter 2 standalone.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-puzzle-hold-combined-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-only.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v4",
        cache="BeyyHub/chapter2_v26_cutscene.lua"},
    {name="HOLD",file="chapter2-puzzle-position-diagnostic.lua",
        marker="Beyy Chapter 2 Teleport-Hold and Return Diagnostic v6",
        cache="BeyyHub/chapter2_hold_v6_solver_anchor_return.lua"},
    {name="PUZZLES",file="chapter2-no-levers-puzzles-core.lua",
        marker="Beyy Chapter 2 No-Levers Puzzle Worker v26",
        cache="BeyyHub/chapter2_v26_puzzles.lua"},
    {name="UPGRADES",file="chapter2-auto-upgrades.lua",
        marker="Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)",
        cache="BeyyHub/chapter2_v27_vacuum_power_only.lua"},
}
local function log(line)
    print("[CH2 HOLD TEST] "..tostring(line))
end
local function fail(message)
    warn("[CH2 HOLD TEST] "..tostring(message))
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
        item.file.."?hold-v2="..tostring(os.time())..
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
    -- Queue only the small bootstrap. Preflight validates all four modules
    -- separately rather than queuing their combined source in one payload.
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
        file="chapter2-puzzle-hold-combined-test.lua",
        marker="Beyy Chapter 2 Puzzle + Teleport Hold Combined Test v2",
        cache="BeyyHub/chapter2_hold_test_v2_bootstrap.lua"},false)
    if not fn then
        fail("Bootstrap failed preflight: "..tostring(why))
        return
    end
    local ok,err=pcall(queue,body)
    if not ok then
        fail("queue_on_teleport failed: "..tostring(err))
    else
        log("Four modules compiled and compact hold-test bootstrap queued. Enter Chapter 2.")
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    fail("This script runs only from the lobby or Chapter 2.")
    return
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
-- Capture the genuine Chapter2 start before any controller moves our
-- character. Preserve its full CFrame, including facing direction.
local env=_G
if type(getgenv)=="function" then
    local ok,global=pcall(getgenv)
    if ok and type(global)=="table" then env=global end
end
local player=Players.LocalPlayer
local char=player and player.Character
local root=char and char:FindFirstChild("HumanoidRootPart")
if not root then
    local deadline=os.clock()+5
    repeat
        task.wait(0.05)
        player=Players.LocalPlayer
        char=player and player.Character
        root=char and char:FindFirstChild("HumanoidRootPart")
    until root or os.clock()>=deadline
end
if root then
    env.__BEYY_CH2_HOLD_CAPTURE={Character=char,CFrame=root.CFrame}
    log("Original Chapter2 start saved: "..tostring(root.Position))
else
    fail("No root to capture original start; return-to-start may be unavailable")
end
env.__BEYY_CH2_HOLD_FOLLOW_SOLVER=true
log("Loading: working cutscene v4 -> solver-follow HOLD -> no-levers puzzles -> Vacuum Power")
local okCutscene=launch(paths[1])
local okHold=launch(paths[2])
-- Do NOT wait 1.2s or force the diagnostic's 4/5 point. The existing
-- worker chooses its verified room anchor and v6 watches its position.
local okPuzzle=launch(paths[3])
local okUpgrade=launch(paths[4])
if not okCutscene or not okHold or not okPuzzle or not okUpgrade then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " hold="..tostring(okHold)..
        " puzzle="..tostring(okPuzzle)..
        " upgrades="..tostring(okUpgrade)..
        ". Check console for exact module error.")
else
    log("Four test modules running. Holds the solver's chosen in-room position.")
    log("At 3/3 confirmed puzzles, hold stops and a bounded return to captured start begins.")
    log("F9 position/return report; F8 puzzle report; F12 abort hold without a forced return.")
end
