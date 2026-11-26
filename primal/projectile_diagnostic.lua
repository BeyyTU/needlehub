-- BeyyHub PRIMAL | read-only projectile observation v0.2.0
-- Manual shots only. No hooks, remote traffic, weapon edits, or target data.
if game.GameId ~= 10775092853 then
    warn("[PRIMAL Projectile] Unsupported universe."); return
end
if type(writefile)~="function" or type(makefolder)~="function" then
    warn("[PRIMAL Projectile] Executor file API unavailable."); return
end
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local pg=player and player:WaitForChild("PlayerGui",10)
if not pg then return end
local ok,err=pcall(function()
    if type(isfolder)~="function" or not isfolder("PRIMAL") then makefolder("PRIMAL") end
end)
if not ok and not (type(isfolder)=="function" and isfolder("PRIMAL")) then
    warn("[PRIMAL Projectile] Cannot create folder: "..tostring(err)); return
end
local duration=60
local started=os.clock()
local stopped=false
local connections={}
local tracked={}
local earlyWindow=.5
local partCap=128
local weaponGroups={}
local errors={}
local function elapsed() return os.clock()-started end
local function round(x) return math.floor(x*100+.5)/100 end
local function childPath(root,...)
    for _,name in ipairs({...}) do
        root=root and root:FindFirstChild(name)
    end
    return root
end
local function shown(item)
    if not item then return false end
    while item and item~=pg do
        if item:IsA("GuiObject") and not item.Visible then return false end
        if item:IsA("LayerCollector") and not item.Enabled then return false end
        item=item.Parent
    end
    return item==pg
end
local function readText(item)
    if item and item:IsA("TextLabel") and shown(item) then return item.Text:sub(1,100) end
end
local function currentWeapon()
    local ammo=childPath(pg,"BadWaveWeaponHud","Canvas","Ammo")
    return readText(childPath(ammo,"Weapon")) or "Unknown",
        readText(childPath(ammo,"Count")),
        shown(childPath(ammo,"Reload"))
end
local report={
    manifest={version="0.2.0",placeId=tostring(game.PlaceId),universeId=tostring(game.GameId),
        placeVersion=game.PlaceVersion,capturedAt=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        gravity=workspace.Gravity,streamingEnabled=workspace.StreamingEnabled,
        durationLimit=duration,earlyObservationWindowSeconds=earlyWindow,
        scope="Manual, client-visible projectile and local HUD observations. No remote payloads, target identifiers or world coordinates are exported.",
        caveats={
            "BW_Projectiles may contain visual effects or projectiles from other players; observations cannot establish ownership or authoritative ballistics.",
            "No projectile part observed does not prove hitscan.",
            "Hit-marker visibility changes are local visual feedback, not proof of server-accepted damage.",
            "Sampled speeds are derived from local visual movement, not guaranteed weapon muzzle velocity.",
            "Early and later samples are time windows, not confirmed flight or impact phases.",
            "Mouse presses and releases include game-processed input but are not proof of firing.",
            "Ammo decreases may reflect inventory updates or other actions; they are not proof of firing."
        }},
    weaponObservations={}, projectileVisuals={}, counts={
        manualFireInputs=0,processedMousePresses=0,unprocessedMousePresses=0,
        mouseReleases=0,ammoDecreaseTransitions=0,ammoIncreaseTransitions=0,
        hitMarkerAppearances=0,observedParts=0,skippedParts=0,
        sampleErrors=0},
    errors=errors
}
local function group(name)
    local g=weaponGroups[name]
    if not g then
        g={weapon=name,manualFireInputs=0,processedMousePresses=0,unprocessedMousePresses=0,
            mouseReleases=0,ammoDecreaseTransitions=0,ammoIncreaseTransitions=0,
            hitMarkerAppearances=0,ammoReadings={},reloadSeen=false}
        weaponGroups[name]=g
        report.weaponObservations[#report.weaponObservations+1]=g
    end
    return g
end
local markerBefore=shown(childPath(pg,"BadWaveHitMarker","Marker"))
local lastAmmo,lastWeapon
connections[#connections+1]=UIS.InputBegan:Connect(function(input,processed)
    if input.KeyCode==Enum.KeyCode.F8 then stopped=true; return end
    if not UIS:GetFocusedTextBox() and input.UserInputType==Enum.UserInputType.MouseButton1 then
        local name=currentWeapon()
        local g=group(name)
        report.counts.manualFireInputs+=1
        g.manualFireInputs+=1
        local key=processed and "processedMousePresses" or "unprocessedMousePresses"
        report.counts[key]+=1; g[key]+=1
    end
end)
connections[#connections+1]=UIS.InputEnded:Connect(function(input)
    if not UIS:GetFocusedTextBox() and input.UserInputType==Enum.UserInputType.MouseButton1 then
        local name=currentWeapon()
        report.counts.mouseReleases+=1
        group(name).mouseReleases+=1
    end
end)
local function sampleHud()
    local name,ammo,reload=currentWeapon()
    if name~="Unknown" or ammo~=nil then
        local g=group(name)
        if ammo and (ammo~=lastAmmo or name~=lastWeapon) and #g.ammoReadings<100 then
            g.ammoReadings[#g.ammoReadings+1]=ammo
        end
        if name==lastWeapon then
            local previous,current=tonumber(lastAmmo),tonumber(ammo)
            if previous and current and previous~=current then
                local key=current<previous and "ammoDecreaseTransitions" or "ammoIncreaseTransitions"
                report.counts[key]+=1; g[key]+=1
            end
        end
        g.reloadSeen=g.reloadSeen or reload
    end
    lastAmmo,lastWeapon=ammo,name
    local visible=shown(childPath(pg,"BadWaveHitMarker","Marker"))
    if visible and not markerBefore then
        report.counts.hitMarkerAppearances+=1
        group(name).hitMarkerAppearances+=1
    end
    markerBefore=visible
end
local folder
local folderConnection
local seen=setmetatable({},{__mode="k"})
local function newWindow()
    return {samples=0,sumSpeed=0,peakSpeed=0,sumVerticalSpeed=0}
end
local function observe(part,preexisting)
    if not part:IsA("BasePart") or seen[part] then return end
    seen[part]=true
    if #report.projectileVisuals>=partCap then report.counts.skippedParts+=1; return end
    local now=os.clock()
    local row={class=part.ClassName,anchored=part.Anchored,
        preexisting=preexisting==true,observedLifetimeSeconds=0,
        early=newWindow(),later=newWindow()}
    report.projectileVisuals[#report.projectileVisuals+1]=row
    report.counts.observedParts+=1
    tracked[part]={row=row,position=part.Position,time=now,first=now}
end
local function bindFolder(newFolder)
    if folderConnection then folderConnection:Disconnect(); folderConnection=nil end
    folder=newFolder
    if folder then
        folderConnection=folder.DescendantAdded:Connect(function(instance)
            local success=pcall(observe,instance)
            if not success then report.counts.sampleErrors+=1 end
        end)
        for _,instance in ipairs(folder:GetDescendants()) do
            if instance:IsA("BasePart") then pcall(observe,instance,true) end
        end
    end
end
local function sampleProjectiles()
    local current=workspace:FindFirstChild("BW_Projectiles")
    if current~=folder then bindFolder(current) end
    local now=os.clock()
    for part,t in pairs(tracked) do
        if not folder or not part:IsDescendantOf(folder) then
            tracked[part]=nil
        else
            local dt=now-t.time
            if dt>=.015 then
                local position=part.Position
                local displacement=position-t.position
                local speed=displacement.Magnitude/dt
                local vertical=displacement.Y/dt
                local row=t.row
                row.observedLifetimeSeconds=round(now-t.first)
                if speed==speed and speed<math.huge and math.abs(vertical)<math.huge then
                    local window=(not row.preexisting and now-t.first<=earlyWindow) and row.early or row.later
                    window.samples+=1
                    window.sumSpeed+=speed
                    window.peakSpeed=math.max(window.peakSpeed,speed)
                    window.sumVerticalSpeed+=vertical
                end
                t.position,t.time=position,now
            end
        end
    end
end
print("[PRIMAL Projectile] v0.2.0 recording for 60 seconds. Shoot manually; F8 saves early.")
local success,reason=pcall(function()
    while not stopped and elapsed()<duration do
        local sampled,why=pcall(function() sampleHud(); sampleProjectiles() end)
        if not sampled then
            report.counts.sampleErrors+=1
            if #errors<10 then errors[#errors+1]=tostring(why):sub(1,200) end
        end
        game:GetService("RunService").Heartbeat:Wait()
    end
end)
if not success then errors[#errors+1]=tostring(reason):sub(1,200) end
for _,c in ipairs(connections) do c:Disconnect() end
if folderConnection then folderConnection:Disconnect() end
for _,row in ipairs(report.projectileVisuals) do
    for _,window in ipairs({row.early,row.later}) do
        if window.samples>0 then
            window.meanSpeed=round(window.sumSpeed/window.samples)
            window.meanVerticalSpeed=round(window.sumVerticalSpeed/window.samples)
            window.peakSpeed=round(window.peakSpeed)
        end
        window.sumSpeed=nil; window.sumVerticalSpeed=nil
    end
end
report.manifest.elapsedSeconds=round(elapsed())
report.manifest.endedBy=stopped and "F8" or (success and "time limit" or "error")
report.manifest.projectileFolderObserved=folder~=nil or report.counts.observedParts>0
report.manifest.partial=not success or report.counts.sampleErrors>0 or report.counts.skippedParts>0
local path="PRIMAL/projectile_"..os.date("!%Y%m%d_%H%M%S").."_"..tostring(math.random(100000,999999))..".json"
local saved,why=pcall(function() writefile(path,Http:JSONEncode(report)) end)
if saved then
    print("[PRIMAL Projectile] Saved: "..path)
    print(string.format("[PRIMAL Projectile] Inputs=%d | Projectile visuals=%d | Hit-marker appearances=%d",
        report.counts.manualFireInputs,report.counts.observedParts,report.counts.hitMarkerAppearances))
else warn("[PRIMAL Projectile] Export failed: "..tostring(why)) end
