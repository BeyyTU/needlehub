-- Chapter 1 TNT split timing test only. Does not modify BeyyHub.
if game.PlaceId ~= 108628039999641 then
    warn("[C1 TNT Test] Run in Chapter 1 only.")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
if not player then return end
local env = type(getgenv) == "function" and getgenv() or _G
if type(env.BeyyC1TntSplitTest) == "table" and type(env.BeyyC1TntSplitTest.Stop) == "function" then
    pcall(env.BeyyC1TntSplitTest.Stop)
end

local alive, enabled = true, false
local settings = {LightCooldown = 0, ThrowDelay = 0.5}
local stats = {LightRequests = 0, LitConfirmed = 0, ThrowRequests = 0, Denied = 0, Timeouts = 0, ThrowErrors = 0}
local phase, nextLight, pendingAt, litAt, expiresAt = "idle", 0, 0, 0, 0
local remote, remoteConnection, gui
local connections = {}
local lastStatus = "Paused. Turn OFF the hub's Auto Use TNT first."
local lastStatusAt = 0
local configModule, gameConfig

local function status(message)
    if lastStatus ~= message then
        lastStatus = message
        lastStatusAt = os.clock()
        print("[C1 TNT Test] " .. message)
    end
end

local function config()
    local folder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local module = folder and folder:FindFirstChild("Config")
    if module ~= configModule then
        configModule, gameConfig = module, nil
        if module and module:IsA("ModuleScript") then
            local ok, result = pcall(require, module)
            if ok and type(result) == "table" then gameConfig = result end
        end
    end
    return gameConfig
end

local function serverCooldown()
    local cfg = config()
    local value = tonumber(player:GetAttribute("TntCooldown"))
        or (cfg and tonumber(cfg.TNT_COOLDOWN)) or 20
    if value ~= value or value == math.huge or value <= 0 then value = 20 end
    return math.max(0.5, value)
end

local function blocked()
    return player:GetAttribute("NeedleInputLocked") == true
        or player:GetAttribute("CutsceneActive") == true
        or player:GetAttribute("HintViewerOpen") == true
        or player:GetAttribute("NeedleOwned") == true
        or player:GetAttribute("NeedleHandInProgress") == true
end

local function onReply(action, value)
    if not alive then return end
    local now = os.clock()
    if action == "denied" then
        stats.Denied += 1
        phase = "idle"
        local remaining = tonumber(value)
        if not remaining or remaining < 0 or remaining ~= remaining or remaining == math.huge then remaining = 1 end
        nextLight = math.max(nextLight, now + remaining + 0.05)
        status(string.format("Server denied TNT action. Retry in %.2fs", math.max(0, nextLight-now)))
    elseif action == "lit" then
        if phase ~= "waiting" then return end
        stats.LitConfirmed += 1
        litAt = now
        local fuse = tonumber(value)
        expiresAt = now + ((fuse and fuse > 0 and fuse < math.huge) and fuse or 2.9)
        nextLight = math.max(nextLight, now + math.max(serverCooldown(), settings.LightCooldown))
        phase = "lit"
        status(string.format("Light confirmed. Throw delay %.2fs; fuse ~%.2fs", settings.ThrowDelay, expiresAt-now))
    end
end

local function bindRemote()
    local folder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local current = folder and folder:FindFirstChild("TntAction")
    if current and not current:IsA("RemoteEvent") then current = nil end
    if current ~= remote then
        if remoteConnection then remoteConnection:Disconnect(); remoteConnection = nil end
        remote = current
        phase = "idle"
        if remote then remoteConnection = remote.OnClientEvent:Connect(onReply) end
    end
    return remote ~= nil
end

local function tryStep()
    if not enabled then return end
    if not bindRemote() then status("Waiting for NeedleHaystack.TntAction"); return end
    if blocked() then status("Paused for cutscene, needle or input lock"); return end
    if player:GetAttribute("TntOwned") ~= true then status("Waiting for TNT ownership"); return end
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    local now = os.clock()
    if phase == "waiting" then
        if now - pendingAt > 2 then
            phase = "idle"
            stats.Timeouts += 1
            status("No light confirmation; waiting for server cooldown")
        end
        return
    end
    if phase == "lit" then
        if now >= expiresAt - 0.05 then
            phase = "idle"
            stats.Timeouts += 1
            status("Lit fuse expired before throw")
            return
        end
        if now - litAt < settings.ThrowDelay then return end
        local camera = Workspace.CurrentCamera
        if not camera then status("Waiting for camera to throw"); return end
        local origin = camera.CFrame
        local velocity = camera.CFrame.LookVector * 40 + Vector3.new(0, 8, 0)
        phase = "idle"
        local ok, err = pcall(function() remote:FireServer("throw", origin, velocity) end)
        if ok then
            stats.ThrowRequests += 1
            status("Throw request sent. This is not server hit confirmation.")
        else
            stats.ThrowErrors += 1
            status("Throw error: " .. tostring(err))
        end
        return
    end
    if now < nextLight then return end
    phase, pendingAt = "waiting", now
    nextLight = now + math.max(settings.LightCooldown, serverCooldown())
    local ok, err = pcall(function() remote:FireServer("light") end)
    if ok then
        stats.LightRequests += 1
        status("Light requested; waiting for server confirmation")
    else
        phase = "idle"
        nextLight = math.max(nextLight, now + 1)
        status("Light error: " .. tostring(err))
    end
end

local function element(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local screen = player:WaitForChild("PlayerGui")
gui = element("ScreenGui", screen, {
    Name = "BeyyChapter1TntTimingTest", ResetOnSpawn = false,
    IgnoreGuiInset = false, DisplayOrder = 20050
})
local frame = element("Frame", gui, {
    Size = UDim2.fromOffset(420, 270), Position = UDim2.new(0.5, -210, 0.12, 0),
    BackgroundColor3 = Color3.fromRGB(23, 25, 32), BorderSizePixel = 0
})
element("UICorner", frame, {CornerRadius = UDim.new(0, 8)})
local function label(text, y, size)
    return element("TextLabel", frame, {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, y),
        Size = UDim2.fromOffset(390, size or 28), Text = text,
        TextColor3 = Color3.fromRGB(236, 239, 247),
        TextSize = 15, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true
    })
end
label("CHAPTER 1  |  TNT SPLIT TIMING TEST", 8, 26)
local hint = label("Disable Auto Use TNT in BeyyHub before testing.", 34, 25)
hint.TextColor3 = Color3.fromRGB(255, 194, 107)

local function numericField(title, key, y, maximum)
    label(title, y, 27)
    local box = element("TextBox", frame, {
        Position = UDim2.fromOffset(302, y), Size = UDim2.fromOffset(100, 26),
        BackgroundColor3 = Color3.fromRGB(48, 55, 66),
        TextColor3 = Color3.new(1, 1, 1), TextSize = 16,
        Font = Enum.Font.Code, ClearTextOnFocus = false,
        Text = string.format("%.2f", settings[key])
    })
    connections[#connections+1] = box.FocusLost:Connect(function()
        local number = tonumber(box.Text)
        if number and number == number and number >= 0 and number <= maximum then
            settings[key] = number
            status(string.format("%s set to %.2fs", title, number))
        end
        box.Text = string.format("%.2f", settings[key])
    end)
end

numericField("Light cooldown (s)", "LightCooldown", 69, 60)
numericField("Throw delay after lit (s)", "ThrowDelay", 105, 5)

local runButton = element("TextButton", frame, {
    Position = UDim2.fromOffset(14, 146), Size = UDim2.fromOffset(188, 32),
    Text = "START TEST", BackgroundColor3 = Color3.fromRGB(49, 104, 74),
    TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Code, TextSize = 15
})
local stopButton = element("TextButton", frame, {
    Position = UDim2.fromOffset(217, 146), Size = UDim2.fromOffset(185, 32),
    Text = "STOP / REMOVE", BackgroundColor3 = Color3.fromRGB(111, 52, 52),
    TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Code, TextSize = 15
})
local statusLabel = label("Paused", 188, 40)
statusLabel.TextSize = 13
local statsLabel = label("", 231, 30)
statsLabel.TextSize = 12
local function stop()
    if not alive then return end
    alive, enabled = false, false
    if remoteConnection then remoteConnection:Disconnect(); remoteConnection = nil end
    for _,connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
    table.clear(connections)
    if gui then gui:Destroy(); gui = nil end
    if env.BeyyC1TntSplitTest and env.BeyyC1TntSplitTest.Stop == stop then
        env.BeyyC1TntSplitTest = nil
    end
    print("[C1 TNT Test] Stopped. Main hub and its settings were not modified.")
end

connections[#connections+1] = runButton.Activated:Connect(function()
    enabled = not enabled
    if not enabled then phase = "idle" end
    runButton.Text = enabled and "PAUSE TEST" or "START TEST"
    status(enabled and "Running separate TNT timing test" or "Paused")
end)
connections[#connections+1] = stopButton.Activated:Connect(stop)
connections[#connections+1] = player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then stop() end
end)
connections[#connections+1] = player.CharacterAdded:Connect(function()
    phase = "idle"
    nextLight = math.max(nextLight, os.clock() + 1)
end)

env.BeyyC1TntSplitTest = {
    Stop = stop,
    SetEnabled = function(value)
        enabled = alive and value == true
        if not enabled then phase = "idle" end
        if runButton and runButton.Parent then runButton.Text = enabled and "PAUSE TEST" or "START TEST" end
    end,
    Settings = settings,
    Stats = stats
}

task.spawn(function()
    local lastUI = 0
    while alive do
        local ok, err = pcall(tryStep)
        if not ok then
            phase = "idle"
            nextLight = math.max(nextLight, os.clock() + 1)
            status("Test worker error: " .. tostring(err))
        end
        if os.clock() - lastUI >= 0.2 and gui and gui.Parent then
            lastUI = os.clock()
            statusLabel.Text = lastStatus
            local remaining = math.max(0, nextLight - os.clock())
            statsLabel.Text = string.format(
                "Light %d  |  Lit %d  |  Throw %d  |  Denied %d  |  Next %.1fs",
                stats.LightRequests, stats.LitConfirmed, stats.ThrowRequests, stats.Denied, remaining
            )
        end
        task.wait(0.05)
    end
end)
print("[C1 TNT Test] Ready. Disabled by default; use START TEST after disabling the hub's Auto Use TNT.")
