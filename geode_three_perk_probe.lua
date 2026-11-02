-- Crack the Geode! / Geode Hub -- standalone three-perk probe
-- Runs ONCE at the next ready Endless perk offer.
-- Does not edit the main hub. Tests native pick calls and logs server acknowledgments.
-- Recommended: test account. Disable Auto Select Perk during probe.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local mtg = ReplicatedStorage:WaitForChild("MTG")
local cards = require(player:WaitForChild("PlayerScripts"):WaitForChild("MTGClient"):WaitForChild("PerkCards"))
local endlessRemote = mtg:WaitForChild("Remotes"):WaitForChild("Endless")
local env = getgenv and getgenv() or _G

if env.GeodeThreePerkProbeRunning then
    warn("[Three Perk Probe] Probe already running")
    return
end
env.GeodeThreePerkProbeRunning = true

if env.GeodeHub and env.GeodeHub.AutoPerks and env.GeodeHub.AutoPerks.Stop then
    pcall(env.GeodeHub.AutoPerks.Stop)
end

local function owned()
    local raw = player:GetAttribute("Perks") or "{}"
    local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
    return ok and type(t) == "table" and t or {}
end

local log = {Version=1, Experiment="Three native perk pick calls for one Endless offer",
    StartedAt=os.time(), Attempts={}, PickedEvents={}}

local connection = endlessRemote.OnClientEvent:Connect(function(message)
    if type(message) == "table" and message.Type == "Picked" then
        local event = {At=os.clock(), Offer=tostring(message.Offer),
            Index=message.Index, Perk=message.Perk}
        table.insert(log.PickedEvents, event)
        print("[Three Perk Probe] SERVER Picked", event.Offer, event.Index, event.Perk)
    end
end)

local function finish()
    if connection then connection:Disconnect(); connection=nil end
    log.FinishedAt = os.time()
    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function"
                and not isfolder("Geode") then makefolder("Geode") end
            writefile("Geode/three_perk_probe.json", HttpService:JSONEncode(log))
        end)
    end
    env.GeodeThreePerkProbeRunning = false
    print("[Three Perk Probe] Finished; see Geode/three_perk_probe.json")
end

print("[Three Perk Probe] Waiting up to 180 seconds for a ready three-card Endless offer")
local offer, key
local timeout = os.clock() + 180
while os.clock() < timeout do
    local p = cards._debug and cards._debug.P
    local o = p and p.Offer
    if p and p.Open and p.Ready and not p.Picked and o and o.Offer ~= nil
        and not o.Test and type(o.Cards) == "table" and #o.Cards >= 3 then
        offer, key = o, tostring(o.Offer)
        break
    end
    task.wait(.05)
end

if not offer then
    log.Error = "No live three-card perk offer before timeout"
    warn("[Three Perk Probe] Timed out")
    finish()
    return
end

local before = owned()
log.Offer = key
log.Before = before
log.Cards = {}
for i=1,3 do
    local c=offer.Cards[i]
    log.Cards[i]={Index=i,Id=c and c.Id,Rarity=c and c.Rarity}
end

-- Deliberately do not change native Ready/Picked state.
-- Native rejection is NOT proof of server-side rejection.
print("[Three Perk Probe] Offer", key, "trying three native choices")
for i=1,3 do
    local p=cards._debug and cards._debug.P
    local event={Index=i, At=os.clock(),
        BeforeOpen=p and p.Open or false,
        BeforeReady=p and p.Ready or false,
        BeforePicked=p and p.Picked or false}
    local ok,err=pcall(cards._pick,i,false)
    event.CallOk=ok
    if not ok then event.Error=tostring(err) end
    p=cards._debug and cards._debug.P
    event.AfterOpen=p and p.Open or false
    event.AfterReady=p and p.Ready or false
    event.AfterPicked=p and p.Picked or false
    table.insert(log.Attempts,event)
    print("[Three Perk Probe] Choice",i,"function returned",ok,"picked state",event.AfterPicked)
end

task.wait(4)
local after=owned()
log.After=after
log.Changes={}
local distinct=0
local seen={}
for i=1,3 do
    local id=log.Cards[i].Id
    if type(id)=="string" and not seen[id] then
        seen[id]=true
        local change=(tonumber(after[id]) or 0)-(tonumber(before[id]) or 0)
        log.Changes[id]=change
        if change>0 then distinct+=1 end
        print("[Three Perk Probe] Replicated perk",id,"delta",change)
    end
end
log.DistinctPerksChanged=distinct
log.Interpretation=distinct==3 and
    "Three distinct perks increased; verify server Picked events." or
    "Fewer than three distinct perks changed. Client _pick gating may be the cause; server rules remain unproven."
print("[Three Perk Probe]",log.Interpretation)
finish()
