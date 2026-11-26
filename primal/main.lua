-- BeyyHub | PRIMAL: Evolved v0.1.0
-- Standalone, read-only client status panel.
local VERSION = "0.1.0"
local TARGET_UNIVERSE = 10775092853
if game.GameId ~= TARGET_UNIVERSE then
    warn("[PRIMAL] Unsupported universe: " .. tostring(game.GameId))
    return
end

local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then
    warn("[PRIMAL] LocalPlayer is unavailable.")
    return
end
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[PRIMAL] PlayerGui is unavailable.")
    return
end

local NAME = "BeyyHub_PRIMAL_Status"
local previous = playerGui:FindFirstChild(NAME)
if previous then previous:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = NAME
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = playerGui

local function create(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = parent
    return object
end

local panel = create("Frame", gui, {
    Size = UDim2.fromOffset(340, 220),
    Position = UDim2.new(0.5, -170, 0.5, -110),
    BackgroundColor3 = Color3.fromRGB(22, 25, 31),
    BorderSizePixel = 0,
})
create("UICorner", panel, {CornerRadius = UDim.new(0, 10)})
create("UIStroke", panel, {Color = Color3.fromRGB(67, 77, 91)})
local function label(text, x, y, w, h, size, color)
    return create("TextLabel", panel, {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), Font = Enum.Font.Gotham,
        Text = text, TextSize = size, TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end
local white = Color3.fromRGB(239, 243, 249)
local muted = Color3.fromRGB(165, 176, 192)
label("BeyyHub  /  PRIMAL", 16, 12, 260, 26, 20, white)
label("CLIENT STATUS  |  v" .. VERSION, 16, 42, 300, 18, 12, muted)
label("Place: " .. tostring(game.PlaceId), 16, 79, 308, 20, 14, white)
label("Universe: " .. tostring(game.GameId), 16, 103, 308, 20, 14, white)
label("Game version: " .. tostring(game.PlaceVersion), 16, 127, 308, 20, 14, white)
local status = label("Character: checking", 16, 151, 308, 20, 14, white)
label("RightControl to show / hide", 16, 190, 308, 18, 12, muted)
local close = create("TextButton", panel, {
    Position = UDim2.fromOffset(295, 12), Size = UDim2.fromOffset(29, 28),
    BackgroundColor3 = Color3.fromRGB(46, 52, 62), TextColor3 = white,
    Font = Enum.Font.GothamBold, Text = "X", TextSize = 14,
    AutoButtonColor = true, BorderSizePixel = 0,
})
create("UICorner", close, {CornerRadius = UDim.new(0, 6)})

local connections = {}
local alive = true
local function update()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    status.Text = humanoid and humanoid.Health > 0 and "Character: active"
        or "Character: unavailable / respawning"
end

connections[#connections + 1] = Input.InputBegan:Connect(function(key, processed)
    if not processed and not Input:GetFocusedTextBox()
        and key.KeyCode == Enum.KeyCode.RightControl then
        panel.Visible = not panel.Visible
    end
end)
connections[#connections + 1] = close.Activated:Connect(function()
    gui:Destroy()
end)
gui.Destroying:Connect(function()
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end)
update()
task.spawn(function()
    while alive do
        task.wait(1)
        if alive then update() end
    end
end)
print("[PRIMAL] v" .. VERSION .. " loaded. RightControl toggles the panel.")
