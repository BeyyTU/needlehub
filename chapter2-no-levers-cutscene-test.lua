-- Beyy Chapter 2 Standalone Cutscene + Upgrades v1
-- Only: non-final cutscene bypass (including native intro Skip) and VacuumPower auto upgrades.
-- No puzzle worker, lever solver, teleport, spawn return, key pickup or hand-in automation.
-- This standalone loader is independent; Main's integrated v33 remains unchanged.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-deferred-invisible-skip-test.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",
        cache="BeyyHub/chapter2_integrated_v33_cutscene_v6_cinefix3.lua"},
    {name="UPGRADES",file="chapter2-auto-upgrades.lua",
        marker="Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)",
        cache="BeyyHub/chapter2_integrated_v33_vacuum_v27.lua"},
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
        item.file.."?chapter2-cutscene-upgrades-v1="..tostring(os.time())..
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
    -- Preflight only the cutscene and upgrade modules. Queue this small bootstrap.
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
        marker="Beyy Chapter 2 Standalone Cutscene + Upgrades v1",
        cache="BeyyHub/chapter2_cutscene_upgrades_v1_bootstrap.lua"},false)
    if not fn then
        fail("Bootstrap failed preflight: "..tostring(why))
        return
    end
    local ok,err=pcall(queue,body)
    if not ok then
        fail("queue_on_teleport failed: "..tostring(err))
    else
        log("Cutscene and upgrade modules compiled; standalone bootstrap queued for Chapter 2.")
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
-- Do not set the integrated solver's globals or capture a return-to-spawn CFrame.
-- Running Main's integrated controller simultaneously would still execute
-- Main's own puzzle worker; keep this standalone isolated.
if env.__BEYY_CH2_HOLD_FOLLOW_SOLVER==true then
    fail("Integrated Chapter 2 solver/return is already marked active in this session. Restart Roblox to run cutscene/upgrades only.")
    return false
end

log("STANDALONE v1: cutscene bypass (CINEFIX3) + VacuumPower-only upgrades (v27)")
log("No puzzle completer, no teleport/return controller, no key automation.")
local okCutscene=launch(paths[1])
local okUpgrade=launch(paths[2])
if not okCutscene or not okUpgrade then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " upgrades="..tostring(okUpgrade)..
        ". Check console for exact module error.")
    return false
end
log("Both modules running. Intro native Skip is automatic; non-final cinematic bypass works on native flags.")
log("Final needle ending stays protected. Cutscene F8 report; upgrades remain VacuumPower only.")
return true
