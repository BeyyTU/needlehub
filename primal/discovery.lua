-- BeyyHub PRIMAL | client-visible structure report v0.1.0
-- One-shot, read-only inventory. No remote calls, hooks, decompilation,
-- property writes, gameplay input, or collection of other player data.
local VERSION = "0.1.0"
local TARGET_UNIVERSE = 10775092853
if game.GameId ~= TARGET_UNIVERSE then
    warn("[PRIMAL Discovery] Wrong universe: " .. tostring(game.GameId))
    return
end
if type(writefile) ~= "function" or type(makefolder) ~= "function" then
    warn("[PRIMAL Discovery] Executor file output is unavailable.")
    return
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local stamp = os.date("!%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(100000, 999999))
local folder = "PRIMAL/discovery_" .. stamp
local function ensureFolder(path)
    if type(isfolder) == "function" and isfolder(path) then return end
    local ok, err = pcall(makefolder, path)
    if not ok and not (type(isfolder) == "function" and isfolder(path)) then
        error("Cannot create " .. path .. ": " .. tostring(err))
    end
end
local ok, err = pcall(function()
    ensureFolder("PRIMAL")
    ensureFolder(folder)
end)
if not ok then warn("[PRIMAL Discovery] " .. tostring(err)); return end

local roots = {}
local function addRoot(instance, label)
    if instance then roots[#roots + 1] = {instance = instance, label = label} end
end
for _, service in ipairs({
    "Workspace", "ReplicatedStorage", "ReplicatedFirst", "Lighting",
    "SoundService", "StarterGui", "StarterPack", "StarterPlayer", "Teams",
}) do
    local found, instance = pcall(function() return game:GetService(service) end)
    if found then addRoot(instance, service) end
end
if player then
    addRoot(player:FindFirstChildOfClass("PlayerGui"), "LocalPlayer.PlayerGui")
    addRoot(player:FindFirstChildOfClass("Backpack"), "LocalPlayer.Backpack")
    addRoot(player:FindFirstChild("PlayerScripts"), "LocalPlayer.PlayerScripts")
    addRoot(player.Character, "LocalPlayer.Character")
end

local skip = {}
for _, other in ipairs(Players:GetPlayers()) do
    if other.Character then skip[other.Character] = true end
end

local groups = {
    remotes = {}, world_parts = {}, ui = {}, objects = {}
}
local files = {}
local counts = {remotes = 0, world_parts = 0, ui = 0, objects = 0}
local sequence = {remotes = 0, world_parts = 0, ui = 0, objects = 0}
local classCounts, rootCounts, scanErrors = {}, {}, {}
local visited = 0
local skippedCharacters = 0
local CHUNK = 1000
local failed = false

local function writeJSON(filename, value)
    local success, reason = pcall(function()
        writefile(folder .. "/" .. filename, HttpService:JSONEncode(value))
    end)
    if not success then
        failed = true
        warn("[PRIMAL Discovery] Write failed: " .. filename .. ": " .. tostring(reason))
    end
    return success
end

local function flush(group)
    local rows = groups[group]
    if #rows == 0 then return end
    sequence[group] += 1
    local filename = string.format("%s_%03d.json", group, sequence[group])
    if writeJSON(filename, {category = group, rows = rows}) then
        files[#files + 1] = {file = filename, category = group, count = #rows}
    end
    groups[group] = {}
end

local function add(group, row)
    counts[group] += 1
    local rows = groups[group]
    rows[#rows + 1] = row
    if #rows >= CHUNK then flush(group) end
end

local function classify(instance)
    if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")
        or instance:IsA("UnreliableRemoteEvent") then
        return "remotes"
    elseif instance:IsA("BasePart") then
        return "world_parts"
    elseif instance:IsA("GuiObject") or instance:IsA("LayerCollector") then
        return "ui"
    end
    return "objects"
end

local function inspect(instance, rootLabel, path)
    local class = instance.ClassName
    local row = {root = rootLabel, path = path, class = class}
    local group = classify(instance)
    -- Deliberately omit script source, remote payloads, attribute values,
    -- UI text, player names/IDs, and precise world coordinates.
    if group == "world_parts" then
        local size = instance.Size
        row.size = {x = size.X, y = size.Y, z = size.Z}
        row.anchored = instance.Anchored
    elseif group == "ui" and instance:IsA("GuiObject") then
        row.visible = instance.Visible
    end
    add(group, row)
    classCounts[class] = (classCounts[class] or 0) + 1
    rootCounts[rootLabel] = (rootCounts[rootLabel] or 0) + 1
end

local started = os.clock()
print("[PRIMAL Discovery] Starting client-visible structure scan...")
for _, root in ipairs(roots) do
    local stack = {{instance = root.instance, path = root.label, isRoot = true}}
    while #stack > 0 and not failed do
        local node = table.remove(stack)
        local instance = node.instance
        if not node.isRoot and skip[instance] then
            skippedCharacters += 1
        else
            local success, reason = pcall(function()
                if not node.isRoot then
                    inspect(instance, root.label, node.path)
                    visited += 1
                end
                local children = instance:GetChildren()
                for i = #children, 1, -1 do
                    local child = children[i]
                    stack[#stack + 1] = {
                        instance = child,
                        path = node.path .. "/" .. child.Name
                    }
                end
            end)
            if not success then
                if #scanErrors < 30 then
                    scanErrors[#scanErrors + 1] = {root = root.label, error = tostring(reason)}
                end
            end
            if visited % 500 == 0 then task.wait() end
        end
    end
    if failed then break end
end
for _, group in ipairs({"remotes", "world_parts", "ui", "objects"}) do
    flush(group)
end

local manifest = {
    version = VERSION,
    capturedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    placeId = tostring(game.PlaceId),
    universeId = tostring(game.GameId),
    placeVersion = game.PlaceVersion,
    streamingEnabled = workspace.StreamingEnabled,
    elapsedSeconds = math.floor((os.clock() - started) * 100) / 100,
    visited = visited,
    counts = counts,
    classCounts = classCounts,
    rootCounts = rootCounts,
    skippedCharacterRoots = skippedCharacters,
    files = files,
    scanErrors = scanErrors,
    incomplete = failed or #scanErrors > 0,
    scope = "Client-visible instance metadata in selected service roots and local player containers. Streamed-out and server-only instances are unavailable. Names and paths are instance labels, not unique IDs. Snapshot may change during traversal.",
}
if writeJSON("manifest.json", manifest) then
    print("[PRIMAL Discovery] Saved: " .. folder .. "/manifest.json")
    print(string.format("[PRIMAL Discovery] Remotes=%d | Parts=%d | UI=%d | Other=%d",
        counts.remotes, counts.world_parts, counts.ui, counts.objects))
    if manifest.incomplete then warn("[PRIMAL Discovery] Report is partial; check manifest.") end
end
