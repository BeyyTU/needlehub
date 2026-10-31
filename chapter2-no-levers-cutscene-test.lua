-- Beyy Chapter 2 No-Levers + Working Cutscene + Upgrades v26
-- Small modular bootstrap: working cutscene v4, no-levers 3-puzzle worker,
-- Vacuum Power-only cash upgrader. No hay-return teleports.
-- Does not modify BeyyHub Main.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-only.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v4",
        cache="BeyyHub/chapter2_v26_cutscene.lua"},
    {name="PUZZLES",file="chapter2-no-levers-puzzles-core.lua",
        marker="Beyy Chapter 2 No-Levers Puzzle Worker v26",
        cache="BeyyHub/chapter2_v26_puzzles.lua"},
    {name="UPGRADES",file="chapter2-auto-upgrades.lua",
        marker="Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)",
        cache="BeyyHub/chapter2_v27_vacuum_power_only.lua"},
}
local function log(line)
    print("[CH2 V26] "..tostring(line))
end
local function fail(message)
    warn("[CH2 V26] "..tostring(message))
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
        item.file.."?v26="..tostring(os.time())..
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
    -- Queue a 5KB bootstrap instead of 166KB of embedded scripts. This avoids
    -- queue-size limits and validates the three modules individually.
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
        marker="Beyy Chapter 2 No-Levers + Working Cutscene + Upgrades v26",
        cache="BeyyHub/chapter2_v26_bootstrap.lua"},false)
    if not fn then
        fail("Bootstrap failed preflight: "..tostring(why))
        return
    end
    local ok,err=pcall(queue,body)
    if not ok then
        fail("queue_on_teleport failed: "..tostring(err))
    else
        log("Three modules compiled and small bootstrap queued. Enter Chapter 2.")
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
log("Loading modules: cutscene v4 -> no-levers puzzles -> VACUUM POWER ONLY")
local okCutscene=launch(paths[1])
local okPuzzle=launch(paths[2])
local okUpgrade=launch(paths[3])
if not okCutscene or not okPuzzle or not okUpgrade then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " puzzle="..tostring(okPuzzle)..
        " upgrades="..tostring(okUpgrade)..
        ". Check console for exact module error.")
else
    log("All 3 modules started. F8 copies puzzle/cutscene/upgrade diagnostics.")
end
