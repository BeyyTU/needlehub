-- BeyyHub v103.00 | Winter / Christmas event compatibility | PlaceId 87963815262778
local __BEYY_MODULE = "Winter"
local __BEYY_SCRIPT_VERSION = "103.00"
if game.PlaceId ~= 87963815262778 then
    warn("[BeyyHub Winter] This module is only for the Christmas! place")
    return
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local HS = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- The winter boss protocol has not yet been captured. Native Chapter 3/4/5
-- PitchforkDig is attempted ONLY when the identical remote, replicated
-- BossHealth and BossWeakPoint fields, range and ownership are all present.
-- No speculative remotes, arbitrary teleporting or anti-cheat bypasses.
local env = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then env = value end
end
if type(env.BeyyWinterStop) == "function" then
    pcall(env.BeyyWinterStop)
end

local alive = true
local enabled = false
local connections = {}
local cachedBoss, lastScan, lastHitAt = nil, 0, -math.huge
local hitsSent, healthDrops = 0, 0
local lastBossHealth = nil
local lastStatus = ""
local updateStatus = function(_) end

local function describe(v)
    local kind = typeof(v)
    if kind == "Vector3" or kind == "CFrame" or kind == "Color3" or kind == "BrickColor" then
        return tostring(v)
    end
    if kind == "Instance" then return v:GetFullName() end
    if kind == "number" or kind == "string" or kind == "boolean" or kind == "nil" then
        return v
    end
    return tostring(v)
end
local function attributes(item)
    local values = {}
    if not item then return values end
    local ok, data = pcall(function() return item:GetAttributes() end)
    if ok and type(data) == "table" then
        for key, value in pairs(data) do
            if #tostring(key) <= 90 then values[tostring(key)] = describe(value) end
        end
    end
    return values
end
local function status(message)
    if message == lastStatus then return end
    lastStatus = message
    updateStatus(message)
    print("[BeyyHub Winter] " .. message)
end
local function relevantName(str)
    local n = str:lower()
    for _, term in ipairs({"boss", "winter", "christmas", "snow", "frost", "yeti",
        "santa", "krampus", "ice", "golem", "gift", "present", "sleigh"}) do
        if n:find(term,1,true) then return true end
    end
    return false
end
local function bossScore(inst)
    if not inst:IsA("Model") then return -1 end
    local score = 0
    if inst:GetAttribute("BossHealth") ~= nil then score += 12 end
    if inst:GetAttribute("BossWeakPoint") ~= nil then score += 10 end
    if inst:GetAttribute("BossState") ~= nil then score += 6 end
    if relevantName(inst.Name) then score += 2 end
    if not inst:FindFirstChild("RootPart") and not inst:FindFirstChild("HumanoidRootPart")
        and not inst.PrimaryPart then score -= 2 end
    return score
end
local function findBoss(force)
    if not force and os.clock()-lastScan < 1.5
        and cachedBoss and cachedBoss.Parent then return cachedBoss end
    lastScan = os.clock()
    local best, score = nil, 4
    local nodes = WS:GetDescendants()
    for i = 1, #nodes do
        local node = nodes[i]
        if node:IsA("Model") then
            local candidate = bossScore(node)
            if candidate > score then best, score = node, candidate end
        end
        if i % 2000 == 0 then task.wait() end
    end
    cachedBoss = best
    return best
end
local function nativeRemote(name)
    local needle = RS:FindFirstChild("NeedleHaystack")
    local r = needle and needle:FindFirstChild(name)
    return r and r:IsA("RemoteEvent") and r or nil
end
local function characterHead()
    local c = LocalPlayer.Character
    local humanoid = c and c:FindFirstChildOfClass("Humanoid")
    if not c or not humanoid or humanoid.Health <= 0 then return nil end
    return c:FindFirstChild("Head"), humanoid
end
local function findWeakpoint(boss, name)
    local target = name:lower()
    local mappings = {
        head = {"head","fb_head","bosshead","weakpointhead"},
        chest = {"chest","upperTorso","fb_body"},
        body = {"body","torso","fb_body"},
        belly = {"belly","fb_body"},
    }
    local accepted = { [target] = true }
    local extra = mappings[target]
    if extra then for _, n in ipairs(extra) do accepted[n:lower()] = true end end
    local best, bestScore
    for _, node in ipairs(boss:GetDescendants()) do
        if node:IsA("BasePart") and accepted[node.Name:lower()] then
            local score = (node.Name:lower() == target) and 2 or 1
            if not bestScore or score > bestScore then best, bestScore = node, score end
        end
    end
    return best
end
local inactive = {
    Sleeping=true, Intro=true, Rising=true, Falling=true,
    Returning=true, Unavailable=true, Defeated=true, PhaseTransition=true,
}
local function bossTick()
    if not enabled then return end
    local boss = findBoss(false)
    if not boss then status("No replicated boss rig found; use Copy Winter Scan"); return end
    local hp = tonumber(boss:GetAttribute("BossHealth"))
    local name = boss:GetAttribute("BossWeakPoint")
    local state = tostring(boss:GetAttribute("BossState") or "")
    if not hp or hp <= 0 or type(name) ~= "string" or name == "" then
        status("Boss found, but native health/weak-point protocol is not confirmed")
        return
    end
    if inactive[state] or boss:GetAttribute("BossHidden") == true then
        status("Waiting for active boss: " .. state); return
    end
    if boss:GetAttribute("BossVulnerable") == false then
        status("Waiting for boss vulnerability"); return
    end
    local endAt = tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
    if endAt and WS:GetServerTimeNow() >= endAt
        and boss:GetAttribute("BossWeakPointDizzy") ~= true then
        status("Waiting for next weak-point window"); return
    end
    if LocalPlayer:GetAttribute("NeedleInputLocked") == true
        or LocalPlayer:GetAttribute("CutsceneActive") == true
        or LocalPlayer:GetAttribute("BossHeld") == true
        or LocalPlayer:GetAttribute("BossRagdolled") == true then
        status("Waiting for game input to unlock"); return
    end
    if LocalPlayer:GetAttribute("PitchforkOwned") ~= true then
        status("Pitchfork not owned (native protocol required)"); return
    end
    local remote = nativeRemote("PitchforkDig")
    if not remote then status("Winter boss uses an unverified combat remote"); return end
    local head = characterHead()
    if not head then status("Waiting for living character"); return end
    local part = findWeakpoint(boss, name)
    if not part then
        status("Weak-point part '" .. name .. "' not found; capture Winter Scan")
        return
    end
    local diff = part.Position-head.Position
    local reach = math.clamp(tonumber(LocalPlayer:GetAttribute("PitchforkReach")) or 13, 13, 24)
    if diff.Magnitude > reach then
        status(string.format("Move within %.1f studs of %s (currently %.1f)",reach,name,diff.Magnitude))
        return
    end
    if diff.Magnitude < 0.01 then return end
    local t = os.clock()
    if t-lastHitAt < math.max(0.1,tonumber(LocalPlayer:GetAttribute("PitchforkCooldown")) or 0.85) then
        return
    end
    lastHitAt = t
    local ok, err = pcall(function()
        remote:FireServer("Boss",head.Position,diff.Unit)
    end)
    if ok then
        hitsSent += 1
        status("Native weak-point request sent (" .. name .. "); awaiting server damage")
    else
        status("PitchforkDig failed: " .. tostring(err))
    end
end

local function snapshot()
    local report = {
        marker="BEYY_WINTER_SCAN_V1", timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        placeId=game.PlaceId, bossRequestsSent=hitsSent, bossHealthDrops=healthDrops,
        playerAttributes=attributes(LocalPlayer), bossCandidates={},
        remotes={}, worldObjects={}, guiHints={}
    }
    local worldNodes = WS:GetDescendants()
    for _, node in ipairs(worldNodes) do
        if node:IsA("Model") and bossScore(node) > 4 and #report.bossCandidates < 35 then
            local parts = {}
            for _, child in ipairs(node:GetDescendants()) do
                if child:IsA("BasePart") and #parts < 50 then parts[#parts+1] = child.Name end
            end
            report.bossCandidates[#report.bossCandidates+1] = {
                path=node:GetFullName(),attributes=attributes(node),parts=parts
            }
        elseif relevantName(node.Name) and #report.worldObjects < 110 then
            report.worldObjects[#report.worldObjects+1] = node:GetFullName() .. " [" .. node.ClassName .. "]"
        end
    end
    for _, node in ipairs(RS:GetDescendants()) do
        if (node:IsA("RemoteEvent") or node:IsA("RemoteFunction"))
            and #report.remotes < 180 then
            report.remotes[#report.remotes+1] = node:GetFullName() .. " [" .. node.ClassName .. "]"
        end
    end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, node in ipairs(pg:GetDescendants()) do
            if node:IsA("TextLabel") and relevantName(node.Text)
                and #report.guiHints < 40 then
                report.guiHints[#report.guiHints+1] = string.sub(node.Text,1,140)
            end
        end
    end
    return HS:JSONEncode(report)
end
local function export()
    local ok, body = pcall(snapshot)
    if not ok then status("Scan failed: "..tostring(body));return end
    env.BeyyWinterLastScan = body
    local copied, saved = false, false
    if type(setclipboard) == "function" then
        copied=pcall(setclipboard,body)
    end
    if type(writefile) == "function" then
        pcall(function()
            if type(makefolder)=="function" and type(isfolder)=="function"
                and not isfolder("BeyyHub") then makefolder("BeyyHub") end
        end)
        saved=pcall(writefile,"BeyyHub/winter_map_capture.json",body)
    end
    status("Winter Scan: "..(copied and "copied" or "clipboard unavailable")
        .." / "..(saved and "saved to BeyyHub/winter_map_capture.json" or "not saved"))
    print("[BeyyHub Winter] Scan available as getgenv().BeyyWinterLastScan when supported")
end

-- Self-contained compact native UI. Old chapter modules and saves are untouched.
local parent
local ok, guiParent = pcall(function()
    if type(gethui)=="function" then return gethui() end
    return game:GetService("CoreGui")
end)
parent = ok and guiParent or LocalPlayer:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "BeyyHubWinter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = parent
local window = Instance.new("Frame")
window.Name = "WinterPanel"
window.Size = UDim2.fromOffset(370,294)
window.Position = UDim2.new(0.5,-185,0.4,-147)
window.BackgroundColor3=Color3.fromRGB(20,23,33)
window.BorderSizePixel=0
window.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,12)
corner.Parent=window
local stroke=Instance.new("UIStroke")
stroke.Color=Color3.fromRGB(65,79,114)
stroke.Transparency=0.3
stroke.Parent=window
local function textLabel(value,y,height,bold)
    local v=Instance.new("TextLabel")
    v.BackgroundTransparency=1
    v.Position=UDim2.fromOffset(18,y)
    v.Size=UDim2.new(1,-36,0,height)
    v.Text=value
    v.TextColor3=Color3.fromRGB(234,240,255)
    v.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    v.TextSize=bold and 16 or 12
    v.TextWrapped=true
    v.TextXAlignment=Enum.TextXAlignment.Left
    v.TextYAlignment=Enum.TextYAlignment.Center
    v.Parent=window
    return v
end
local title=textLabel("BeyyHub  •  WINTER EVENT",12,26,true)
textLabel("Christmas! | Experimental boss compatibility",43,25,false)
local toggle=Instance.new("TextButton")
toggle.Position=UDim2.fromOffset(16,82)
toggle.Size=UDim2.new(1,-32,0,42)
toggle.BackgroundColor3=Color3.fromRGB(46,53,74)
toggle.TextColor3=Color3.fromRGB(240,245,255)
toggle.Font=Enum.Font.GothamBold
toggle.TextSize=12
toggle.Text="Auto Boss Weakpoint (verified native protocol): OFF"
toggle.Parent=window
local tc=Instance.new("UICorner");tc.CornerRadius=UDim.new(0,8);tc.Parent=toggle
table.insert(connections,toggle.MouseButton1Click:Connect(function()
    enabled=not enabled
    toggle.Text="Auto Boss Weakpoint (verified native protocol): "..(enabled and "ON" or "OFF")
    toggle.BackgroundColor3=enabled and Color3.fromRGB(40,91,82) or Color3.fromRGB(46,53,74)
    status(enabled and "Monitoring native combat protocol..." or "Boss automation disabled")
end))
local stateLabel=textLabel("Status: awaiting winter objects",132,54,false)
stateLabel.TextColor3=Color3.fromRGB(166,199,231)
updateStatus=function(message) if stateLabel and stateLabel.Parent then stateLabel.Text="Status: "..message end end
local scanBtn=Instance.new("TextButton")
scanBtn.Position=UDim2.fromOffset(16,197)
scanBtn.Size=UDim2.new(1,-32,0,37)
scanBtn.BackgroundColor3=Color3.fromRGB(52,78,130)
scanBtn.Text="Copy / Save Winter Map & Boss Scan"
scanBtn.Font=Enum.Font.GothamBold
scanBtn.TextSize=12
scanBtn.TextColor3=Color3.fromRGB(250,250,255)
scanBtn.Parent=window
local sc=Instance.new("UICorner");sc.CornerRadius=UDim.new(0,8);sc.Parent=scanBtn
table.insert(connections,scanBtn.MouseButton1Click:Connect(export))
textLabel("RightControl: show/hide   •   Scan contains local game metadata only",246,28,false)
local function stop()
    if not alive then return end
    alive=false
    enabled=false
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end)end
    pcall(function()gui:Destroy()end)
    if env.BeyyWinterStop == stop then env.BeyyWinterStop=nil end
end
env.BeyyWinterStop=stop
table.insert(connections,UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        window.Visible=not window.Visible
    end
end))
local dragging, origin, startPosition=false,nil,nil
table.insert(connections,window.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        origin=input.Position
        startPosition=window.Position
    end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-origin
        window.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,
            startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end
end))
task.spawn(function()
    while alive do
        task.wait(0.12)
        local ok,err=pcall(bossTick)
        if not ok then status("Boss worker: "..tostring(err)) end
    end
end)
task.spawn(function()
    while alive do
        task.wait(1.2)
        local boss=findBoss(false)
        if boss then
            local hp=tonumber(boss:GetAttribute("BossHealth"))
            if hp and lastBossHealth and hp < lastBossHealth then healthDrops+=1 end
            lastBossHealth=hp
            if not enabled then
                status("Boss: "..boss.Name.." | state="..tostring(boss:GetAttribute("BossState"))
                    .." | HP="..tostring(hp).." | weak="..tostring(boss:GetAttribute("BossWeakPoint")))
            end
        elseif not enabled then
            status("Waiting for winter boss to spawn; scan is available")
        end
    end
end)
print("[BeyyHub Winter] Loaded Christmas! place support. Boss protocol unverified; scan and cautious native weakpoint mode ready.")
