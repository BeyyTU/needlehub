-- BeyyHub | Lobby developer gem audit (read-only)
-- Scans replicated remotes, visible client UI, and limited client script
-- references. Never invokes developer actions, intercepts calls, changes
-- permissions, creates gems, or reads server-only scripts.
-- Run while standing in the lobby; upload the resulting JSON for review.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RF = game:GetService("ReplicatedFirst")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then warn("[Gem Audit] LocalPlayer missing") return end
local mtg = RS:FindFirstChild("MTG")
local state = mtg and mtg:FindFirstChild("State")
local remoteRoot = mtg and mtg:FindFirstChild("Remotes")
local client = player:FindFirstChild("PlayerScripts")
client = client and client:FindFirstChild("MTGClient")
local gui = player:FindFirstChildOfClass("PlayerGui")
local devKit = gui and gui:FindFirstChild("MTGDevKit")
local path = "Geode/lobby_dev_gem_audit.json"
local function safePath(obj)
    if not obj then return nil end
    local parts = {}
    local node = obj
    while node and #parts < 8 do
        table.insert(parts, 1, tostring(node.Name):sub(1, 80))
        if node == RS or node == RF or node == gui
            or node == player or node == workspace then break end
        node = node.Parent
    end
    return table.concat(parts, ".")
end
local function hasAny(textValue, words)
    local str = tostring(textValue):lower()
    for _, word in ipairs(words) do
        if str:find(word, 1, true) then return true end
    end
    return false
end
local gemWords = {"gem","jewel","currency","reward","grant","award","credit"}
local devWords = {"dev","admin","debug","staff","moderator","command","test"}
local report = {
    Version = 1,
    CapturedAtMs = DateTime.now().UnixTimestampMillis,
    GameId = game.GameId,
    PlaceId = game.PlaceId,
    Role = mtg and mtg:GetAttribute("Role") or nil,
    Phase = state and state:GetAttribute("Phase") or nil,
    ExpectedLocation = "Lobby",
    ScanOnly = true,
    ActionsFired = 0,
    AuthorizationVerified = false,
    ServerSourceAvailable = false,
    NativeDevUI = {
        MTGDevKitPresent = devKit ~= nil,
        MTGDevKitChildren = devKit and #devKit:GetChildren() or 0,
        DevMenuModulePresent = client and client:FindFirstChild("DevMenu") ~= nil or false,
        DevWidgetsModulePresent = client and client:FindFirstChild("DevWidgets") ~= nil or false,
        DevActionRemotePresent = remoteRoot and remoteRoot:FindFirstChild("DevAction") ~= nil or false,
    },
    GemBalanceAttributes = {},
    RemoteInventory = {Count = 0, Exported = 0, Truncated = false, Entries = {}},
    RelatedGuis = {},
    SourceScan = {Candidates = 0, Decompiled = 0, Failed = 0,
        Truncated = false, DecompilerAvailable = type(decompile) == "function",
        Results = {}},
    Interpretation = "The report shows client-visible names and code references only. It cannot prove a gem-grant request exists, whether a client may call it, or whether the server authorizes it. No privileged remote was fired."
}

-- Read existing, numeric gem-balance metadata only (never names or IDs).
for name, value in pairs(player:GetAttributes()) do
    if hasAny(name, {"gem","jewel"}) and type(value) == "number" then
        report.GemBalanceAttributes[tostring(name):sub(1, 80)] = value
    end
end
if mtg then
    local runState = mtg:FindFirstChild("State")
    if runState then
        for name, value in pairs(runState:GetAttributes()) do
            if hasAny(name, {"gem","jewel"}) and type(value) == "number" then
                report.GemBalanceAttributes["State." .. tostring(name):sub(1, 70)] = value
            end
        end
    end
end

-- Inventory replicated remotes, no calls or argument captures.
local remoteScanRoots = {RS}
local scannedRemotes = 0
for _, root in ipairs(remoteScanRoots) do
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
            or obj:IsA("UnreliableRemoteEvent") then
            scannedRemotes += 1
            if #report.RemoteInventory.Entries < 350 then
                local name = obj.Name
                local location = safePath(obj)
                report.RemoteInventory.Entries[#report.RemoteInventory.Entries + 1] = {
                    Name = tostring(name):sub(1, 80),
                    Class = obj.ClassName,
                    Path = location,
                    GemRelated = hasAny(name .. " " .. location, gemWords),
                    DeveloperRelated = hasAny(name .. " " .. location, devWords),
                    InsideMTGRemotes = remoteRoot ~= nil and obj:IsDescendantOf(remoteRoot)
                }
            else
                report.RemoteInventory.Truncated = true
            end
        end
    end
end
report.RemoteInventory.Count = scannedRemotes
report.RemoteInventory.Exported = #report.RemoteInventory.Entries

-- Names/classes of replicated developer/gem GUI components only.
if gui then
    for _, obj in ipairs(gui:GetDescendants()) do
        if #report.RelatedGuis >= 70 then break end
        if (obj:IsA("ScreenGui") or obj:IsA("GuiButton") or obj:IsA("Frame"))
            and hasAny(obj.Name, {"gem","dev","admin","debug"}) then
            report.RelatedGuis[#report.RelatedGuis+1] = {
                Name = tostring(obj.Name):sub(1, 70),
                Class = obj.ClassName,
                Path = safePath(obj)
            }
        end
    end
end

-- A bounded, keyword-only scan of replicated client code.
-- No script is required or executed, and no source/arguments are exported.
local candidates = {}
local seen = {}
local roots = {client, mtg, RF, devKit}
for _, root in ipairs(roots) do
    if root then
        for _, obj in ipairs(root:GetDescendants()) do
            if (obj:IsA("ModuleScript") or obj:IsA("LocalScript"))
                and not seen[obj] then
                seen[obj] = true
                local name = obj.Name:lower()
                local priority = hasAny(name, {"devmenu","devwidgets","admin",
                    "gem","currency","lobby","reward","shop"}) and 2 or 1
                candidates[#candidates+1] = {Object=obj, Priority=priority}
            end
        end
    end
end
table.sort(candidates, function(a,b)
    if a.Priority ~= b.Priority then return a.Priority > b.Priority end
    return safePath(a.Object) < safePath(b.Object)
end)
report.SourceScan.Candidates = #candidates
local scanLimit = math.min(#candidates, 140)
report.SourceScan.Truncated = #candidates > scanLimit
for i = 1, scanLimit do
    local obj = candidates[i].Object
    local row = {
        Name = tostring(obj.Name):sub(1, 80),
        Path = safePath(obj),
        Decompiled = false,
        Categories = {},
        CandidateGemIdentifiers = {},
        MatchedLineNumbers = {},
    }
    if type(decompile) == "function" then
        local ok, source = pcall(decompile, obj)
        if ok and type(source) == "string" then
            row.Decompiled = true
            report.SourceScan.Decompiled += 1
            source = source:sub(1, 220000)
            local categories = {
                Gem = {"gem","jewel","givegem","grantgem","spawngem"},
                DevMenu = {"devaction","devmenu","devwidgets","admin","devkit"},
                RemoteCallMention = {"fireserver","invokeserver"},
                AuthorizationMention = {"permission","authorized","isadmin","allowdev","staff"},
            }
            local lineNo = 0
            local identifiers = {}
            for line in (source .. "\n"):gmatch("(.-)\n") do
                lineNo += 1
                local low = line:lower()
                for category, words in pairs(categories) do
                    if hasAny(low, words) then
                        row.Categories[category] = (row.Categories[category] or 0) + 1
                        local positions = row.MatchedLineNumbers[category] or {}
                        if #positions < 16 then positions[#positions+1] = lineNo end
                        row.MatchedLineNumbers[category] = positions
                    end
                end
                if hasAny(low, gemWords) then
                    for token in line:gmatch("[%a_][%w_]*") do
                        if #token <= 50 and hasAny(token, {"gem","jewel"})
                            and not hasAny(token, {"token","password","secret","user"}) then
                            identifiers[token] = true
                        end
                    end
                end
            end
            for identifier in pairs(identifiers) do
                if #row.CandidateGemIdentifiers < 25 then
                    row.CandidateGemIdentifiers[#row.CandidateGemIdentifiers+1] = identifier
                end
            end
            table.sort(row.CandidateGemIdentifiers)
        else
            report.SourceScan.Failed += 1
            row.Error = "Unavailable or failed to decompile"
        end
    else
        row.Error = "Decompiler not available"
    end
    if (row.Categories.Gem or 0) > 0
        or (row.Categories.DevMenu or 0) > 0
        or hasAny(row.Name, gemWords)
        or hasAny(row.Name, devWords) then
        report.SourceScan.Results[#report.SourceScan.Results+1] = row
    end
end

local ok, errorMessage = pcall(function()
    assert(type(writefile) == "function", "writefile unavailable in this runtime")
    if type(isfolder) == "function" and type(makefolder) == "function"
        and not isfolder("Geode") then makefolder("Geode") end
    writefile(path, Http:JSONEncode(report))
end)
if ok then
    print(string.format("[BeyyHub gem audit] Saved %s | %d remotes | %d code scans | %d matches | no remote calls",
        path, report.RemoteInventory.Count, report.SourceScan.Decompiled,
        #report.SourceScan.Results))
else
    warn("[BeyyHub gem audit] Export failed: " .. tostring(errorMessage))
end
return report
