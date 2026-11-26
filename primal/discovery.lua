-- BeyyHub PRIMAL | client-visible structure report v0.2.0
-- One-shot, read-only inventory. No remote calls, hooks, decompilation,
-- property writes, gameplay input, or collection of other player data.
local VERSION = "0.2.0"
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
local outputPath = "PRIMAL/discovery_" .. stamp .. ".json"
local function ensureFolder(path)
    if type(isfolder) == "function" and isfolder(path) then return end
    local ok, err = pcall(makefolder, path)
    if not ok and not (type(isfolder) == "function" and isfolder(path)) then
        error("Cannot create " .. path .. ": " .. tostring(err))
    end
end
local ok, err = pcall(function()
    ensureFolder("PRIMAL")
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
local counts = {remotes = 0, world_parts = 0, ui = 0, objects = 0}
local classCounts, rootCounts, scanErrors = {}, {}, {}
local visited = 0
local skippedCharacters = 0

local function add(group, row)
    counts[group] += 1
    groups[group][#groups[group] + 1] = row
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
    while #stack > 0 do
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
    scanErrors = scanErrors,
    incomplete = #scanErrors > 0,
    scope = "Client-visible instance metadata in selected service roots and local player containers. Streamed-out and server-only instances are unavailable. Names and paths are instance labels, not unique IDs. Snapshot may change during traversal.",
}
local report = {manifest = manifest, remotes = groups.remotes,
    world_parts = groups.world_parts, ui = groups.ui, objects = groups.objects}
local saved, reason = pcall(function()
    local encoded = HttpService:JSONEncode(report)
    writefile(outputPath, encoded)
end)
if saved then
    print("[PRIMAL Discovery] Saved: " .. outputPath)
    print(string.format("[PRIMAL Discovery] Remotes=%d | Parts=%d | UI=%d | Other=%d",
        counts.remotes, counts.world_parts, counts.ui, counts.objects))
    if manifest.incomplete then warn("[PRIMAL Discovery] Report is partial; check manifest.") end
else
    warn("[PRIMAL Discovery] Single-file export failed: " .. tostring(reason))
end
