-- Crack the Geode! / standalone direct perk protocol probe v2
-- Attempts ONE live offer: native first selection, then two direct requests
-- using the exact captured native RemoteEvent argument structure.
-- Diagnostic only; intentionally does not modify the main hub.
-- Recommended: test/alt account. Disable normal Auto Select Perk.

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local mtg = ReplicatedStorage:WaitForChild("MTG")
local remote = mtg:WaitForChild("Remotes"):WaitForChild("Endless")
local cards = require(player:WaitForChild("PlayerScripts"):WaitForChild("MTGClient"):WaitForChild("PerkCards"))
local env = getgenv and getgenv() or _G

if env.GeodePerkDirectProbeRunning then
    warn("[Perk Direct Probe] Already running")
    return
end
env.GeodePerkDirectProbeRunning = true

local report = {
    Version = 2, StartedAt = os.time(), Attempts = {}, ServerEvents = {},
    Purpose = "Compare native client selection vs direct server request for choices 2 and 3"
}
local eventsConnection, captureActive, captured = nil, false, nil

local function safeValue(v, depth)
    depth = depth or 0
    if depth > 3 then return "[depth limit]" end
    local kind = typeof(v)
    if kind == "Instance" then return v:GetFullName() end
    if kind == "Vector3" or kind == "CFrame" then return tostring(v) end
    if type(v) == "table" then
        local out = {}
        for k, x in pairs(v) do
            local key = type(k)=="string" and k or tostring(k)
            out[key] = safeValue(x, depth + 1)
        end
        return out
    end
    if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then return v end
    return tostring(v)
end

local function getOwned()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(player:GetAttribute("Perks") or "{}")
    end)
    return ok and type(data)=="table" and data or {}
end

local function cleanUp()
    captureActive = false
    if eventsConnection then eventsConnection:Disconnect(); eventsConnection = nil end
    report.FinishedAt = os.time()
    if type(writefile)=="function" then
        local ok, err = pcall(function()
            if type(isfolder)=="function" and type(makefolder)=="function"
                and not isfolder("Geode") then makefolder("Geode") end
            writefile("Geode/three_perk_direct_probe.json", HttpService:JSONEncode(report))
        end)
        if not ok then warn("[Perk Direct Probe] Couldn't save: " .. tostring(err)) end
    end
    env.GeodePerkDirectProbeRunning = false
    print("[Perk Direct Probe] Finished. Export: Geode/three_perk_direct_probe.json")
end

local function run()
    local hub = env.GeodeHub
    if hub and hub.AutoPerks and type(hub.AutoPerks.Stop)=="function" then
        pcall(function() hub.AutoPerks.Stop() end)
    end

    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        report.Error = "Executor does not support hookmetamethod/getnamecallmethod; no requests sent"
        warn("[Perk Direct Probe] Namecall capture unavailable. No requests sent.")
        return
    end

    eventsConnection = remote.OnClientEvent:Connect(function(message)
        if type(message) ~= "table" then return end
        local e = {At=os.clock(), Type=tostring(message.Type)}
        for _,k in ipairs({"Offer","Index","Perk","Reason","Error","Code","Success"}) do
            if message[k] ~= nil then e[k] = safeValue(message[k]) end
        end
        table.insert(report.ServerEvents,e)
        if #report.ServerEvents <= 30 then
            print("[Perk Direct Probe] Server:", e.Type, e.Index, e.Perk, e.Reason or e.Error)
        end
    end)

    local prior
    local handler = function(self, ...)
        if captureActive and self == remote and getnamecallmethod() == "FireServer" then
            if captured == nil then captured = table.pack(...) end
        end
        return prior(self, ...)
    end
    local hook = type(newcclosure)=="function" and newcclosure(handler) or handler
    local okHook, old = pcall(hookmetamethod, game, "__namecall", hook)
    if not okHook or type(old)~="function" then
        report.Error = "Unable to install temporary capture hook: "..tostring(old)
        warn("[Perk Direct Probe] Can't capture native request; no requests sent")
        return
    end
    prior=old
    -- The passive forwarding hook remains installed after completion but stops capturing.

    print("[Perk Direct Probe] Waiting up to 180 seconds for a live offer")
    local offer
    local deadline=os.clock()+180
    while os.clock()<deadline do
        local p=cards._debug and cards._debug.P
        local o=p and p.Offer
        if p and p.Open and p.Ready and not p.Picked
            and o and o.Offer~=nil and not o.Test
            and type(o.Cards)=="table" and #o.Cards>=3 then
            offer=o
            break
        end
        task.wait(.05)
    end
    if not offer then
        report.Error="No ready three-card offer before timeout"
        return
    end

    report.Offer=tostring(offer.Offer)
    report.Cards={}
    for i=1,3 do
        report.Cards[i]={Index=i,Id=offer.Cards[i].Id,Rarity=offer.Cards[i].Rarity}
    end
    report.Before=getOwned()
    print("[Perk Direct Probe] Capturing actual native selection for offer",report.Offer)

    captureActive=true
    local ok,err=pcall(cards._pick,1,false)
    captureActive=false
    table.insert(report.Attempts,{Index=1,Method="native _pick",CallOk=ok,Error=not ok and tostring(err) or nil})

    if not captured then
        report.Error="Native function did not send Endless FireServer; no direct requests sent"
        return
    end
    local n=captured.n or #captured
    report.CapturedArgs={}
    for i=1,n do report.CapturedArgs[i]=safeValue(captured[i]) end

    -- Be conservative: require an explicit pick/perk command marker.
    local function hasPickMarker(value, depth)
        depth=depth or 0
        if type(value)=="string" then
            local s=value:lower()
            return s=="pick" or s=="pickperk" or s=="chooseperk" or s=="perkpick" or s=="selectperk"
        end
        if type(value)~="table" or depth>=3 then return false end
        for k,v in pairs(value) do
            if type(k)=="string" and (k=="Type" or k=="Action" or k=="Op" or k=="Command") and hasPickMarker(v, depth+1) then return true end
            if type(k)=="number" and hasPickMarker(v,depth+1) then return true end
        end
        return false
    end
    local marker=false
    for i=1,n do if hasPickMarker(captured[i]) then marker=true;break end end
    if not marker then
        report.Error="Native protocol has no recognisable Pick command; refusing to guess the request format"
        print("[Perk Direct Probe] Unknown native request; inspect CapturedArgs in JSON")
        return
    end

    -- Find a single unequivocal 1-based selection index in the captured request.
    local candidates={}
    local permitted={index=true,choice=true,selection=true,cardindex=true,
                     perkindex=true,selectedindex=true,option=true,selected=true}
    for i=1,n do
        local arg=captured[i]
        if type(arg)=="number" and arg==1 then
            candidates[#candidates+1]={position=i,kind="scalar"}
        elseif type(arg)=="table" then
            for k,v in pairs(arg) do
                if type(k)=="string" and permitted[k:lower()] and tonumber(v)==1 then
                    candidates[#candidates+1]={position=i,kind="field",field=k}
                end
            end
        end
    end
    if #candidates~=1 then
        report.Error="Ambiguous native index field ("..#candidates.." candidates); no direct requests sent"
        print("[Perk Direct Probe] Ambiguous index mapping; see CapturedArgs in JSON")
        return
    end

    local slot=candidates[1]
    report.IndexLocation=safeValue(slot)
    for index=2,3 do
        local args=table.create(n)
        for i=1,n do
            if type(captured[i])=="table" then
                args[i]=table.clone(captured[i])
            else args[i]=captured[i] end
        end
        if slot.kind=="scalar" then
            args[slot.position]=index
        else
            args[slot.position][slot.field]=index
        end
        local attempt={At=os.clock(),Index=index,Method="captured Endless remote protocol"}
        local sent, sendErr=pcall(function() remote:FireServer(table.unpack(args,1,n)) end)
        attempt.CallOk=sent
        if not sent then attempt.Error=tostring(sendErr) end
        table.insert(report.Attempts,attempt)
        print("[Perk Direct Probe] Sent choice",index,"directly, call returned",sent)
        task.wait(.03)
    end
    task.wait(5)

    report.After=getOwned()
    report.Changes={}
    report.DistinctPerksChanged=0
    local seen={}
    for i=1,3 do
        local id=report.Cards[i].Id
        if type(id)=="string" and not seen[id] then
            seen[id]=true
            local change=(tonumber(report.After[id]) or 0)-(tonumber(report.Before[id]) or 0)
            report.Changes[id]=change
            if change>0 then report.DistinctPerksChanged += 1 end
            print("[Perk Direct Probe] Perk delta:",id,change)
        end
    end
    if report.DistinctPerksChanged>=3 then
        report.Interpretation="All 3 distinct perks increased according to replicated inventory"
    elseif report.DistinctPerksChanged==1 then
        report.Interpretation="Only one distinct perk increased; likely one-selection server rule"
    else
        report.Interpretation="Mixed/unclear result; inspect server responses and owned perk deltas"
    end
    print("[Perk Direct Probe]",report.Interpretation)
end

local ok,err=xpcall(run,debug.traceback)
if not ok then
    report.Error=tostring(err)
    warn("[Perk Direct Probe] Error:",err)
end
cleanUp()
