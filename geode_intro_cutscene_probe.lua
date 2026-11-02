-- Crack the Geode! | Standalone loading/cutscene investigation v1
-- Does not alter the Geode hub or server progression.
-- Run shortly BEFORE entering a chapter or DURING the visible loading scene.
-- Optional reversible local test: getgenv().GeodeIntroProbe.TryHide()
-- Restore: getgenv().GeodeIntroProbe.Restore()
-- Camera test: getgenv().GeodeIntroProbe.UnlockCamera()
-- Export: getgenv().GeodeIntroProbe.Export()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local gui = player:WaitForChild("PlayerGui", 20)
if not gui then warn("[Geode Intro] PlayerGui unavailable");return end
local env = getgenv and getgenv() or _G
if env.GeodeIntroProbe and env.GeodeIntroProbe.Stop then
    pcall(env.GeodeIntroProbe.Stop)
end
local probe = {Running=true, Hiding=false, StartedAt=os.time(), Events={}, Samples={}, MaxSeconds=75}
env.GeodeIntroProbe = probe

local keyWords = {"intro","cutscene","cinematic","loading","transition","fade","blackout","splash","overlay","cover"}
local ignored = {"geodehub","geode hub","potassium"}
local originals = {}
local remembered = {}
local lastSignature = ""
local lastSampleAt = 0
local nextPrint = 0

local function keyword(name, words)
    name = tostring(name):lower()
    for _,w in ipairs(words) do if name:find(w,1,true) then return true end end
    return false
end

local function record(kind, data)
    probe.Events[#probe.Events+1] = {At=os.clock(),Kind=kind,Data=data}
    if #probe.Events>180 then table.remove(probe.Events,1) end
end

local function cleanPath(inst)
    local ok,path = pcall(function() return inst:GetFullName() end)
    return ok and path or tostring(inst)
end

local function isShown(inst)
    local cur=inst
    while cur and cur~=game do
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        cur=cur.Parent
    end
    return true
end

local function candidates()
    local result={}
    for _,inst in ipairs(gui:GetDescendants()) do
        if (inst:IsA("ScreenGui") or inst:IsA("GuiObject"))
            and keyword(inst.Name,keyWords) and not keyword(cleanPath(inst),ignored) then
            result[#result+1]=inst
        end
    end
    return result
end

local function capture()
    local mtg=ReplicatedStorage:FindFirstChild("MTG")
    local state=mtg and mtg:FindFirstChild("State")
    local cam=workspace.CurrentCamera
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local screenGuis={}
    for _,child in ipairs(gui:GetDescendants()) do
        if child:IsA("ScreenGui") then
            screenGuis[#screenGuis+1]={Path=cleanPath(child),Enabled=child.Enabled}
        end
    end
    local overlays={}
    for _,inst in ipairs(candidates()) do
        local prop
        if inst:IsA("ScreenGui") then prop=inst.Enabled else prop=inst.Visible end
        overlays[#overlays+1]={
            Path=cleanPath(inst),Class=inst.ClassName,Shown=isShown(inst),Property=prop
        }
    end
    return {
        T=math.floor((os.clock()-probe.Zero)*10+.5)/10,
        Role=mtg and mtg:GetAttribute("Role") or "MTG not loaded",
        Phase=state and state:GetAttribute("Phase") or "State unavailable",
        RunStart=state and tostring(state:GetAttribute("RunStart")) or "",
        CameraType=cam and tostring(cam.CameraType) or "none",
        CameraSubject=cam and cam.CameraSubject and cleanPath(cam.CameraSubject) or "none",
        Character=char and char.Name or "none",
        HumanoidAlive=hum and hum.Health>0 or false,
        WalkSpeed=hum and hum.WalkSpeed or nil,
        RootAnchored=root and root.Anchored or nil,
        ScreenGuis=screenGuis,Overlays=overlays
    }
end

local function applyHide()
    local hidden=0
    for _,inst in ipairs(candidates()) do
        if inst.Parent then
            if originals[inst]==nil then
                local isScreen=inst:IsA("ScreenGui")
                originals[inst]={Mode=isScreen and "Enabled" or "Visible",
                    Old=isScreen and inst.Enabled or (not isScreen and inst.Visible)}
            end
            if inst:IsA("ScreenGui") then
                if inst.Enabled then inst.Enabled=false;hidden+=1 end
            elseif inst:IsA("GuiObject") then
                if inst.Visible then inst.Visible=false;hidden+=1 end
            end
        end
    end
    return hidden
end

function probe.Scan()
    local shot=capture()
    print("[Geode Intro] Role:",shot.Role,"Phase:",shot.Phase,"Camera:",shot.CameraType)
    print("[Geode Intro] ScreenGui count:",#shot.ScreenGuis,"Candidate overlay count:",#shot.Overlays)
    for _,v in ipairs(shot.Overlays) do
        print("[Geode Intro] Overlay:",v.Path,"shown=",v.Shown,"property=",v.Property)
    end
    return shot
end

function probe.TryHide()
    if not probe.Running then warn("[Geode Intro] Probe is stopped");return end
    probe.Hiding=true
    local hidden=applyHide()
    record("TryHide",{Changed=hidden,TotalCandidates=#candidates()})
    print("[Geode Intro] Reversible local hide enabled. Hidden now:",hidden,
        "Use getgenv().GeodeIntroProbe.Restore() to undo.")
end

function probe.Restore()
    probe.Hiding=false
    local count=0
    for inst,original in pairs(originals) do
        if inst and inst.Parent then
            pcall(function()inst[original.Mode]=original.Old end)
            count+=1
        end
        originals[inst]=nil
    end
    record("Restore",{Count=count})
    print("[Geode Intro] Restored saved GUI properties:",count)
end

function probe.UnlockCamera()
    local mtg=ReplicatedStorage:FindFirstChild("MTG")
    local cam=workspace.CurrentCamera
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local hub=env.GeodeHub
    if not mtg or mtg:GetAttribute("Role")~="Game" or not cam or not hum then
        print("[Geode Intro] Camera unlock requires active Game role and character")
        return false
    end
    if hub and hub.Endless and (hub.Endless.Enabled or hub.Endless.Stage=="Boss") then
        print("[Geode Intro] Camera owned by Endless/boss; refusing to override")
        return false
    end
    record("CameraUnlock",{Before=tostring(cam.CameraType),Subject=cleanPath(hum)})
    cam.CameraType=Enum.CameraType.Custom
    cam.CameraSubject=hum
    print("[Geode Intro] Camera reset to normal character control (game may reclaim it)")
    return true
end

function probe.Export()
    local saved={Version=1,StartedAt=probe.StartedAt,DurationSeconds=os.clock()-probe.Zero,
        Hiding=probe.Hiding,GameId=game.GameId,PlaceId=game.PlaceId,JobId=game.JobId,
        Samples=probe.Samples,Events=probe.Events,ClientModules=probe.ClientModules,
        ReplicatedFirst=probe.ReplicatedFirst}
    if type(writefile)~="function" then
        warn("[Geode Intro] writefile unavailable; diagnostic stays in memory")
        return false
    end
    local ok,err=pcall(function()
        if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("Geode") then makefolder("Geode") end
        writefile("Geode/intro_cutscene_probe.json",HttpService:JSONEncode(saved))
    end)
    if not ok then warn("[Geode Intro] Export failed:",err) end
    return ok
end

function probe.Stop()
    if not probe.Running then return end
    probe.Running=false
    probe.Restore()
    probe.Export()
    print("[Geode Intro] Stopped")
end

probe.Zero=os.clock()
probe.ClientModules={}
local ps=player:FindFirstChild("PlayerScripts")
if ps then
    for _,inst in ipairs(ps:GetDescendants()) do
        if (inst:IsA("LocalScript") or inst:IsA("ModuleScript")) and keyword(inst.Name,keyWords) then
            probe.ClientModules[#probe.ClientModules+1]=cleanPath(inst)
        end
    end
end
probe.ReplicatedFirst={}
for _,inst in ipairs(ReplicatedFirst:GetDescendants()) do
    probe.ReplicatedFirst[#probe.ReplicatedFirst+1]=cleanPath(inst)
    if #probe.ReplicatedFirst>=100 then break end
end
record("Started",{ClientModules=probe.ClientModules,ReplicatedFirst=probe.ReplicatedFirst})
print("[Geode Intro] Monitoring UI, camera and game phase for 75 seconds")
print("[Geode Intro] To TEST hiding the intro during its playback, run:")
print('getgenv().GeodeIntroProbe.TryHide()')
print("[Geode Intro] To restore: getgenv().GeodeIntroProbe.Restore()")
print("[Geode Intro] Optional camera test: getgenv().GeodeIntroProbe.UnlockCamera()")

task.spawn(function()
    while probe.Running and os.clock()-probe.Zero<probe.MaxSeconds do
        if probe.Hiding then applyHide() end
        local ok,shot=pcall(capture)
        if ok then
            local names={}
            for _,v in ipairs(shot.Overlays) do if v.Shown then names[#names+1]=v.Path end end
            table.sort(names)
            local signature=tostring(shot.Role).."|"..tostring(shot.Phase).."|"..
                tostring(shot.CameraType).."|"..table.concat(names,";")
            if signature~=lastSignature or os.clock()-lastSampleAt>=2 then
                probe.Samples[#probe.Samples+1]=shot
                if #probe.Samples>110 then table.remove(probe.Samples,1) end
                lastSampleAt=os.clock()
            end
            if signature~=lastSignature and os.clock()>=nextPrint then
                print("[Geode Intro] t=",shot.T,"Role=",shot.Role,"Phase=",shot.Phase,
                    "Camera=",shot.CameraType,"Shown candidates=",#names)
                for i=1,math.min(#names,4) do print("[Geode Intro] Visible:",names[i]) end
                nextPrint=os.clock()+.8
            end
            lastSignature=signature
        else
            record("CaptureError",tostring(shot))
        end
        task.wait(.2)
    end
    if probe.Running then
        probe.Stop()
        print("[Geode Intro] Finished. File: Geode/intro_cutscene_probe.json")
    end
end)
return probe
