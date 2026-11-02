-- GeodeHub | temporary early-Mining phase probe
-- Standalone experiment: never changes geode-mirror/main.lua.
-- Run when loading a chapter, with the Beyy hub loaded and its intro hide enabled.
-- It attempts at most one early pickup window, restores the client phase and
-- pickup toggle, and leaves a diagnostic JSON file.
-- Run on an alt; the server may reject requests sent before real Mining.

local Players=game:GetService("Players")
local Storage=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local P=Players.LocalPlayer
local env=getgenv()
if env.GeodeEarlyMiningProbe and env.GeodeEarlyMiningProbe.Running then
    warn("[Early Mining] A phase probe is already running");return
end
local api={Running=true,Status="Arming",Samples={},StartedAt=os.clock(),Attempted=false}
env.GeodeEarlyMiningProbe=api
local mtg=Storage:WaitForChild("MTG",15)
local state=mtg and mtg:WaitForChild("State",10)
local client=P and P:FindFirstChild("PlayerScripts") and P.PlayerScripts:FindFirstChild("MTGClient")
if not state or not client then
    api.Running=false
    warn("[Early Mining] Game state/modules are not available");return api
end
local okModule,S=pcall(require,client:WaitForChild("State",10))
if not okModule then
    api.Running=false
    warn("[Early Mining] Could not read native State module:",S);return api
end
local original,phaseSpoofed,pickup,wasPickupEnabled,requestsBefore,feedbackBefore,bagBefore
local stopRequested=false
local testStarted=false
local restored=false

local function snapshot(label)
    local hub=env.GeodeHub
    local p=hub and hub.Pickup
    local okPhase,modulePhase=pcall(S.run,"Phase")
    local current={
        Label=label,Seconds=math.floor((os.clock()-api.StartedAt)*100)/100,
        GameRole=mtg:GetAttribute("Role"),
        ReplicatedPhase=state:GetAttribute("Phase"),
        ModulePhase=okPhase and tostring(modulePhase)or "unavailable",
        MoundLocked=state:GetAttribute("MoundLocked"),
        BagCount=P:GetAttribute("BagCount"),
        PickupEnabled=p and p.Enabled,
        PickupStatus=p and p.Status,
        Requests=p and p.Requests or 0,
        Feedback=p and p.Feedback or 0,
        Items=p and p.Items or 0,
    }
    api.Samples[#api.Samples+1]=current
    print("[Early Mining]",label,
        "Role=",tostring(current.GameRole),
        "Attribute=",tostring(current.ReplicatedPhase),
        "State.run=",tostring(current.ModulePhase),
        "Requests=",tostring(current.Requests),
        "Feedback=",tostring(current.Feedback),
        "Bag=",tostring(current.BagCount))
    return current
end

function api.Export()
    if type(writefile)~="function"then return false,"writefile unavailable"end
    local ok,err=pcall(function()
        if type(makefolder)=="function" and type(isfolder)=="function"
            and not isfolder("Geode")then makefolder("Geode")end
        writefile("Geode/early_mining_probe.json",
            Http:JSONEncode({
                Version=1,Attempted=api.Attempted,Status=api.Status,
                LastTestDurationSeconds=os.clock()-api.StartedAt,
                GameId=game.GameId,PlaceId=game.PlaceId,Samples=api.Samples,
            }))
    end)
    if not ok then return false,tostring(err)end
    return true
end

local function restore()
    if restored then return end
    restored=true
    -- Do not overwrite a different phase sent by the game in the meantime.
    if phaseSpoofed and state.Parent and state:GetAttribute("Phase")=="Mining" then
        pcall(function()state:SetAttribute("Phase",original)end)
    end
    if pickup and pickup.Running then
        -- If pickup was previously disabled, keep it disabled.
        -- If it was enabled, resume it after our single-request test.
        if wasPickupEnabled and not pickup.Enabled then
            pcall(pickup.Start)
        elseif not wasPickupEnabled and pickup.Enabled then
            pcall(pickup.Stop)
        end
    end
end

function api.Stop()
    if not api.Running then return end
    stopRequested=true
    api.Running=false
    restore()
    snapshot("Stopped")
    api.Export()
    print("[Early Mining] Probe stopped and local state restored")
end

task.spawn(function()
    local success,err=xpcall(function()
        api.Status="Waiting for intro hide and Game/Waiting phase"
        local deadline=os.clock()+65
        local armedAt
        while not stopRequested and os.clock()<deadline do
            local hub=env.GeodeHub
            local intro=hub and hub.IntroVisuals
            if hub and hub.Running and intro and intro.Enabled
                and intro.Status and intro.Status:find("Hiding chapter",1,true)
                and mtg:GetAttribute("Role")=="Game"
                and state:GetAttribute("Phase")=="Waiting" then
                -- Trigger as soon as the current hub has actually hidden the intro.
                armedAt=os.clock()
                break
            end
            task.wait(.04)
        end
        if not armedAt or stopRequested then
            api.Status="No matching intro phase detected within 65 seconds"
            print("[Early Mining] No intro/Waiting transition detected; run this before entering a chapter")
            return
        end
        local hub=env.GeodeHub
        pickup=hub.Pickup
        if not pickup or not pickup.Running then
            api.Status="Auto Pickup missing";return
        end
        if hub.Endless and hub.Endless.Enabled then
            api.Status="Auto Endless must be disabled for controlled test";return
        end
        if pickup.NativeHeldOwner or pickup.Suspended then
            api.Status="Pickup is owned or suspended by another controller";return
        end
        if state:GetAttribute("MoundLocked")==true then
            api.Status="Mound is locked; skipped request";return
        end
        original=state:GetAttribute("Phase")
        wasPickupEnabled=pickup.Enabled
        requestsBefore=pickup.Requests
        feedbackBefore=pickup.Feedback
        bagBefore=P:GetAttribute("BagCount")
        snapshot("Before")
        if original~="Waiting" then api.Status="Phase changed before test";return end
        api.Attempted=true
        api.Status="Temporarily setting client phase to Mining"
        state:SetAttribute("Phase","Mining")
        phaseSpoofed=true
        snapshot("Spoofed")
        if not pickup.Enabled then pickup.Start()end
        local cutoff=os.clock()+.45
        local requestSeen=false
        while not stopRequested and os.clock()<cutoff do
            if pickup.Requests>requestsBefore then requestSeen=true;break end
            task.wait(.015)
        end
        -- Stop early so repeated rejected pickup requests are not spammed.
        pickup.Stop()
        snapshot(requestSeen and "After first request"or "No request in test window")
        restore()
        snapshot("Restored")
        -- Allow pending server response to arrive without spoofing phase.
        task.wait(1.0)
        local after=snapshot("Server result after 1 second")
        local gained=(tonumber(after.BagCount)or 0)-(tonumber(bagBefore)or 0)
        local deltaFeedback=(tonumber(after.Feedback)or 0)-(tonumber(feedbackBefore)or 0)
        local deltaRequest=(tonumber(after.Requests)or 0)-(tonumber(requestsBefore)or 0)
        api.Status="Done: requests="..deltaRequest..
            ", feedback="..deltaFeedback..", bag delta="..gained
        print("[Early Mining] FINAL:",api.Status)
        if deltaRequest>0 and (deltaFeedback>0 or gained>0) then
            print("[Early Mining] At least one pickup was acknowledged; verify whether it happened before native Mining.")
        else
            print("[Early Mining] No server-confirmed early mining; local phase alone is not proven to work.")
        end
    end,debug.traceback)
    restore()
    api.Running=false
    if not success then
        api.Status="Error: "..tostring(err)
        warn("[Early Mining]",err)
    end
    api.Export()
    print("[Early Mining] File: Geode/early_mining_probe.json")
end)
return api
