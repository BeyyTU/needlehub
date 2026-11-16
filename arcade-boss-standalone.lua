-- BeyyHub Arcade Boss-Aware Standalone v1.0
-- Search for the Needle lobby only (PlaceId 77108422251420).
-- Plays the on-screen arcade through native input. Does NOT spoof kill,
-- score, boss, wave, quit, or reward remotes. Server reward caps still apply.
-- F8 stops + exports. getgenv().BeyyArcadeBossStandalone.Stop() also stops.
if not game:IsLoaded() then game.Loaded:Wait() end
if game.PlaceId ~= 77108422251420 then
    warn("[Arcade Boss] Run this in the Search for the Needle lobby.")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.BeyyArcadeBossStandalone) == "table"
    and type(env.BeyyArcadeBossStandalone.Stop) == "function" then
    pcall(env.BeyyArcadeBossStandalone.Stop)
end

local CFG = {
    MaxPlaySeconds = 150,
    NoProgressSeconds = 32,
    MinRoundSeconds = 12,
    ShotInterval = 0.13,
    BossGoneSeconds = 1.5,
    StartTimeout = 10,
    CreditTimeout = 10,
    BetweenRounds = 1.5,
    RequireBossProgress = true, -- Do not finish on an arbitrary score alone.
}
local controller = {
    Running = true, Status = "Starting", Cycles = 0, Credited = 0,
    Uncredited = 0, LastGain = nil, Version = "1.0",
    Config = CFG, Events = {}
}
env.BeyyArcadeBossStandalone = controller

local connectionList, heldKey = {}, nil
local vim = nil
pcall(function() vim = game:GetService("VirtualInputManager") end)
local function note(kind, data)
    local e = {t = os.clock(), kind = kind, data = data}
    table.insert(controller.Events, e)
    if #controller.Events > 450 then table.remove(controller.Events, 1) end
    if kind ~= "shot" and kind ~= "score" then
        print("[Arcade Boss] " .. tostring(kind) .. ": " .. tostring(data))
    end
end
local function logStatus(s)
    controller.Status = s
    note("status", s)
end
local function gemBalance()
    local a = tonumber(LocalPlayer:GetAttribute("SpinUsableGems"))
    if a ~= nil then return a end
    a = tonumber(LocalPlayer:GetAttribute("Gems"))
    if a ~= nil then return a end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local g = ls and ls:FindFirstChild("Gems")
    return g and tonumber(g.Value) or nil
end
local function view()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local gui = pg and pg:FindFirstChild("ArcadeScreen")
    local arena = gui and gui:FindFirstChild("Arena")
    local world = arena and arena:FindFirstChild("World")
    local hud = arena and arena:FindFirstChild("HUD")
    local overlay = arena and arena:FindFirstChild("Overlay")
    local dim = overlay and overlay:FindFirstChild("Dim")
    local panel = dim and dim:FindFirstChild("Panel")
    local pauseBox = hud and hud:FindFirstChild("PauseBox")
    return {
        gui = gui, arena = arena, world = world,
        scoreFrame = hud and hud:FindFirstChild("Score"),
        waveFrame = hud and hud:FindFirstChild("Wave"),
        overlay = dim,
        pause = pauseBox and pauseBox:FindFirstChild("Pause"),
        leave = panel and panel:FindFirstChild("LEAVE"),
    }
end
local function readHudNumber(root, word)
    if not root then return nil end
    local fallback = nil
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = obj.Text:upper()
            local direct = text:match(word .. "%s*:?%s*([%d,]+)")
            if direct then return tonumber((direct:gsub(",", ""))) end
            if text:match("^%s*[%d,]+%s*$") then
                fallback = tonumber((text:gsub(",", "")))
            end
        end
    end
    return fallback
end
local function state()
    local ui = view()
    return {
        playing = LocalPlayer:GetAttribute("ArcadePlaying") == true,
        screen = ui.gui ~= nil and ui.gui:IsA("ScreenGui") and ui.gui.Enabled,
        arena = ui.arena ~= nil and ui.arena:IsA("GuiObject") and ui.arena.Visible,
        overlay = ui.overlay ~= nil and ui.overlay:IsA("GuiObject") and ui.overlay.Visible,
        score = readHudNumber(ui.scoreFrame, "SCORE"),
        wave = readHudNumber(ui.waveFrame, "WAVE"),
        gems = gemBalance(),
    }
end
local function arcadePrompt()
    local machine = workspace:FindFirstChild("Arcade Machine")
    local prompt = machine and machine:FindFirstChild("PlayPrompt", true)
    return prompt and prompt:IsA("ProximityPrompt") and prompt or nil
end
local function key(code, down)
    if not vim then return false end
    return pcall(function() vim:SendKeyEvent(down, code, false, game) end)
end
local function releaseKey()
    if heldKey then key(heldKey, false); heldKey = nil end
end
local function clickAt(x, y)
    x, y = math.floor(x), math.floor(y)
    if vim then
        local ok = pcall(function()
            vim:SendMouseMoveEvent(x, y, game)
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        end)
        if ok then
            task.wait(0.045)
            if pcall(function()
                vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end) then return true end
        end
    end
    if type(mousemoveabs) == "function" and
        pcall(mousemoveabs, x, y) then
        if type(mouse1click) == "function" and pcall(mouse1click) then
            return true
        end
        if type(mouse1press) == "function" and
            type(mouse1release) == "function" and pcall(mouse1press) then
            task.wait(0.045)
            return pcall(mouse1release)
        end
    end
    return false
end
local function clickButton(obj)
    if not obj or not obj:IsA("GuiButton") or not obj.Visible then
        return false
    end
    local size = obj.AbsoluteSize
    local pos = obj.AbsolutePosition
    if size.X <= 0 or size.Y <= 0 then return false end
    return clickAt(pos.X + size.X * 0.5, pos.Y + size.Y * 0.5)
end
local function classify(obj, world)
    local cur = obj
    local boss, enemy = false, false
    while cur and cur ~= world do
        local name = cur.Name:lower()
        if name:find("boss", 1, true) or name:find("ufo", 1, true) then
            boss = true
        end
        for _, term in ipairs({"enemy", "asteroid", "alien", "meteor",
                "invader", "target", "ship", "drone"}) do
            if name:find(term, 1, true) then enemy = true end
        end
        for _, term in ipairs({"bullet", "laser", "player", "shot",
                "crosshair", "background", "healthbar"}) do
            if name:find(term, 1, true) then return nil end
        end
        cur = cur.Parent
    end
    return boss and "boss" or enemy and "enemy" or nil
end
local function acquireTarget(shotIndex)
    local ui = view()
    if not ui.arena or not ui.world then return nil end
    local arenaPos, arenaSize = ui.arena.AbsolutePosition, ui.arena.AbsoluteSize
    local choices = {}
    for _, obj in ipairs(ui.world:GetDescendants()) do
        if obj:IsA("GuiObject") and obj.Visible then
            local size = obj.AbsoluteSize
            if size.X >= 4 and size.Y >= 4 and
                size.X < arenaSize.X * 0.65 and
                size.Y < arenaSize.Y * 0.65 then
                local category = classify(obj, ui.world)
                if category then
                    local pos = obj.AbsolutePosition + size / 2
                    if pos.X >= arenaPos.X and pos.Y >= arenaPos.Y and
                        pos.X <= arenaPos.X + arenaSize.X and
                        pos.Y <= arenaPos.Y + arenaSize.Y then
                        table.insert(choices, {
                            x = pos.X, y = pos.Y, category = category,
                            name = obj.Name,
                        })
                    end
                end
            end
        end
    end
    local bosses, enemies = {}, {}
    for _, t in ipairs(choices) do
        if t.category == "boss" then
            table.insert(bosses, t)
        else
            table.insert(enemies, t)
        end
    end
    if #bosses > 0 then
        return bosses[(shotIndex - 1) % #bosses + 1], true
    end
    if #enemies > 0 then
        return enemies[(shotIndex - 1) % #enemies + 1], false
    end
    local phase = shotIndex * 0.63
    return {
        x = arenaPos.X + arenaSize.X * (0.5 + math.cos(phase) * 0.29),
        y = arenaPos.Y + arenaSize.Y * (0.5 + math.sin(phase) * 0.27),
        category = "sweep", name = "fallback"
    }, false
end

function controller.Export()
    local report = {
        version = controller.Version, status = controller.Status,
        cycles = controller.Cycles, credited = controller.Credited,
        uncredited = controller.Uncredited, lastGain = controller.LastGain,
        state = state(), config = CFG, events = controller.Events,
    }
    local ok, json = pcall(function() return HttpService:JSONEncode(report) end)
    if not ok then warn("[Arcade Boss] JSON encode failed."); return nil end
    env.BeyyArcadeBossStandaloneLastJSON = json
    if type(writefile) == "function" then
        if type(makefolder) == "function" then
            pcall(function()
                if type(isfolder) ~= "function" or not isfolder("BeyyHub") then
                    makefolder("BeyyHub")
                end
            end)
        end
        pcall(writefile, "BeyyHub/arcade_boss_standalone_result.json", json)
    end
    local clip = (type(setclipboard) == "function" and setclipboard)
        or (type(toclipboard) == "function" and toclipboard)
    if clip then pcall(clip, json) end
    print("[Arcade Boss] Report exported to file/clipboard when supported.")
    return json
end
function controller.Stop(reason)
    if not controller.Running then return end
    controller.Running = false
    releaseKey()
    logStatus(reason or "Stopped")
    controller.Export()
end
table.insert(connectionList, UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.F8 then controller.Stop("F8 stop") end
end))

local arcadeFolder = ReplicatedStorage:FindFirstChild("Arcade")
if arcadeFolder then
    for _, remoteName in ipairs({"ArcadeReport", "ArcadeSession"}) do
        local remote = arcadeFolder:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            table.insert(connectionList, remote.OnClientEvent:Connect(function(...)
                local args = {}
                for i, value in ipairs({...}) do args[i] = tostring(value):sub(1, 140) end
                note("remote_" .. remoteName, args)
            end))
        end
    end
end
local function begin()
    local s = state()
    if s.playing and s.arena then
        note("session", "Using already-open arcade.")
        return true
    end
    if s.playing or s.screen then
        return false, "Arcade is partly open; close it normally before restarting."
    end
    local prompt = arcadePrompt()
    if not prompt then return false, "PlayPrompt not found." end
    if type(fireproximityprompt) ~= "function" then
        return false, "Executor lacks fireproximityprompt."
    end
    if not pcall(fireproximityprompt, prompt) then
        return false, "Failed to activate PlayPrompt."
    end
    local deadline = os.clock() + CFG.StartTimeout
    while controller.Running and os.clock() < deadline do
        s = state()
        if s.playing and s.screen and s.arena then
            note("session", "Server-confirmed arcade start.")
            return true
        end
        task.wait(0.05)
    end
    return false, "Arcade start was not confirmed."
end
local movement = {
    Enum.KeyCode.W, Enum.KeyCode.D,
    Enum.KeyCode.S, Enum.KeyCode.A
}
local function playToBossClear()
    local t0 = os.clock()
    local lastScore, lastScoreAt = state().score, os.clock()
    local shots = 0
    local bossSeen, bossLastSeen = false, 0
    local bossScoreStart, bossWaveStart = nil, nil
    while controller.Running and os.clock() - t0 < CFG.MaxPlaySeconds do
        local s = state()
        if not s.playing or not s.arena then
            return false, "Arcade ended before a verified boss clear."
        end
        if s.overlay then
            return false, "Arcade overlay appeared before boss clear; leaving it open."
        end
        if s.score and (lastScore == nil or s.score > lastScore) then
            lastScore = s.score
            lastScoreAt = os.clock()
            note("score", {score = s.score, wave = s.wave})
        end
        if os.clock() - lastScoreAt > CFG.NoProgressSeconds then
            return false, "Score stalled; cannot confirm server acceptance."
        end
        shots = shots + 1
        local selectedKey = movement[math.floor((os.clock() - t0) / 1.15) % 4 + 1]
        if selectedKey ~= heldKey then
            releaseKey()
            if key(selectedKey, true) then heldKey = selectedKey end
        end
        local target, bossVisible = acquireTarget(shots)
        if not target then return false, "Arcade target surface missing." end
        if bossVisible then
            if not bossSeen then
                bossSeen = true
                bossScoreStart, bossWaveStart = s.score, s.wave
                note("boss_seen", {score = s.score, wave = s.wave,
                    target = target.name})
            end
            bossLastSeen = os.clock()
        end
        if not clickAt(target.x, target.y) then
            return false, "Native mouse input not supported."
        end
        if shots % 30 == 0 then
            note("shot", {shots = shots, target = target.category,
                score = s.score, wave = s.wave})
        end
        -- A wave advance after a visible boss is stronger evidence than a
        -- fabricated "boss defeated" remote. Score alone is only suggestive.
        local waveAdvance = bossSeen and s.wave ~= nil and
            bossWaveStart ~= nil and s.wave > bossWaveStart
        local bossGone = bossSeen and not bossVisible and
            os.clock() - bossLastSeen >= CFG.BossGoneSeconds
        local scoreAdvance = bossSeen and s.score ~= nil and
            bossScoreStart ~= nil and s.score > bossScoreStart
        if os.clock() - t0 >= CFG.MinRoundSeconds and
            ((waveAdvance and bossGone) or
            (bossGone and scoreAdvance and bossWaveStart == nil)) then
            note("boss_progress", {waveAdvanced = waveAdvance,
                bossGone = bossGone, scoreAdvanced = scoreAdvance,
                score = s.score, wave = s.wave,
                evidence = "inferred from visible boss + gameplay progression"})
            releaseKey()
            return true
        end
        task.wait(CFG.ShotInterval)
    end
    releaseKey()
    return false, "Timed out waiting for visible boss and wave completion."
end
local function nativeLeave()
    local s = state()
    if not s.playing or not s.screen then
        return false, "Server does not show an active arcade on exit."
    end
    if s.score == nil or s.wave == nil then
        return false, "Score or wave unreadable; will not forge exit values."
    end
    local ui = view()
    if not s.overlay then
        if not clickButton(ui.pause) then return false, "Pause button unavailable." end
        local deadline = os.clock() + 3
        while controller.Running and os.clock() < deadline do
            if state().overlay then break end
            task.wait(0.05)
        end
    end
    if not state().overlay then return false, "Pause overlay did not appear." end
    ui = view()
    if not clickButton(ui.leave) then return false, "Native LEAVE button unavailable." end
    local deadline = os.clock() + 8
    while controller.Running and os.clock() < deadline do
        if not state().playing then
            note("native_leave", {score = s.score, wave = s.wave})
            return true
        end
        task.wait(0.05)
    end
    return false, "Native LEAVE did not close server session."
end
local function cycle()
    local before = gemBalance()
    local ok, why = begin()
    if not ok then return false, why end
    logStatus("Playing through boss/wave progression")
    local cleared, clearReason = playToBossClear()
    if not cleared then return false, clearReason end
    local left, leaveReason = nativeLeave()
    if not left then return false, leaveReason end
    local after = gemBalance()
    local deadline = os.clock() + CFG.CreditTimeout
    while controller.Running and before ~= nil and
        after ~= nil and after <= before and os.clock() < deadline do
        task.wait(0.1)
        after = gemBalance()
    end
    controller.Cycles = controller.Cycles + 1
    controller.LastGain = before and after and after - before or nil
    note("cycle_result", {before = before, after = after,
        gain = controller.LastGain, cycles = controller.Cycles})
    if controller.LastGain == nil or controller.LastGain <= 0 then
        controller.Uncredited = controller.Uncredited + 1
        return false, "Boss/wave progressed, but server awarded no confirmed gems."
    end
    controller.Credited = controller.Credited + 1
    print("[Arcade Boss] Credited round " .. controller.Credited ..
        ": +" .. tostring(controller.LastGain) .. " gems.")
    return true
end

task.spawn(function()
    logStatus("Started. F8 stops and exports diagnostic JSON.")
    if not vim and not (type(mousemoveabs) == "function" and
        (type(mouse1click) == "function" or
        (type(mouse1press) == "function" and type(mouse1release) == "function"))) then
        controller.Stop("No supported native mouse input.")
        return
    end
    while controller.Running do
        local ok, credited, reason = xpcall(cycle, function(err)
            return tostring(err) .. " " .. debug.traceback()
        end)
        if not controller.Running then break end
        if not ok then
            controller.Stop("Script error: " .. tostring(credited))
            break
        end
        if not credited then
            controller.Stop("Paused: " .. tostring(reason))
            break
        end
        logStatus("Reward verified; preparing next session")
        task.wait(CFG.BetweenRounds)
    end
    releaseKey()
    for _, conn in ipairs(connectionList) do
        pcall(function() conn:Disconnect() end)
    end
end)
return controller
