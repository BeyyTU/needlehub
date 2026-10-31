-- Beyy Chapter 2 Standalone Integrated v33 (v32 puzzles / v6 invisible Skip / v9 return / v27 VacuumPower)
-- Canonical Chapter 2 standalone entry point; replaces legacy v26 workflow.
-- Same four components as the latest tested experiment:
-- v32 no-levers Picture/Color/Number, v6 deferred/invisible native intro Skip,
-- v9 immediate spawn return/snapback correction and v27 VacuumPower only.
-- Also embedded by BeyyHub Main to guarantee feature parity.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-deferred-invisible-skip-test.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",
        cache="BeyyHub/chapter2_integrated_v33_cutscene_v6_camfix3.lua"},
    {name="HOLD",file="chapter2-puzzle-position-diagnostic.lua",
        marker="Beyy Chapter 2 Teleport-Hold and Return Diagnostic v9",
        cache="BeyyHub/chapter2_integrated_v33_return_v9_jumpfix.lua"},
    {name="PUZZLES",file="chapter2-no-levers-puzzles-dual-range-test.lua",
        marker="Beyy Chapter 2 No-Levers Puzzle Worker v32 DUAL RANGE TEST",
        cache="BeyyHub/chapter2_integrated_v33_puzzles_v32.lua"},
    {name="UPGRADES",file="chapter2-auto-upgrades.lua",
        marker="Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)",
        cache="BeyyHub/chapter2_integrated_v33_vacuum_v27.lua"},
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
        item.file.."?chapter2-integrated-v33="..tostring(os.time())..
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
        file="chapter2-no-levers-cutscene-test.lua",
        marker="Beyy Chapter 2 Standalone Integrated v33",
        cache="BeyyHub/chapter2_integrated_v33_bootstrap.lua"},false)
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
log("INTEGRATED v33: v32 puzzles / v6 invisible deferred Skip / v9 instant return / v27 VacuumPower ONLY")
log("Loading: cutscene v6 INVISIBLE DEFERRED INTRO -> return v9 -> v32 unchanged solver -> Vacuum Power")
local okCutscene=launch(paths[1])
local okHold=launch(paths[2])
-- Do NOT wait 1.2s or force the diagnostic's 4/5 point. The existing
-- worker chooses its verified room anchor and v9 watches only large snapbacks.
local okPuzzle=launch(paths[3])
local okUpgrade=launch(paths[4])
if not okCutscene or not okHold or not okPuzzle or not okUpgrade then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " hold="..tostring(okHold)..
        " puzzle="..tostring(okPuzzle)..
        " upgrades="..tostring(okUpgrade)..
        ". Check console for exact module error.")
    return false
else
    log("Four modules running: v32 native puzzles, visually hidden deferred intro Skip v6, v9 instant return, VacuumPower.")
    log("3/3: IMMEDIATE return to saved spawn even during cutscene; room snapback correction stays active.")
    log("F8: combined puzzle/hidden Skip/upgrade report; F9: return report; F12: cancel hold.")
end
return true
