-- beyy v103.00 | GitHub PlaceId router
-- Upload this file and the four chapter modules to the same public GitHub repository.
-- Change only BASE_RAW_URL to your repository's RAW URL.
local VERSION = "103.00"
local BASE_RAW_URL = "https://raw.githubusercontent.com/BeyyTU/needlehub/main"
local CACHE_FOLDER = "BeyyHub"
local CACHE_PREFIX = CACHE_FOLDER .. "/v103_00_tabs3_"
local REVISION_FILE = CACHE_FOLDER .. "/github_revision.txt"

local MODULES = {
    [77108422251420] = {file="lobby.lua", name="Lobby"},
    [108628039999641] = {file="chapter1.lua", name="Chapter1"},
    [83445806734780] = {file="chapter2.lua", name="Chapter2"},
    [82626725163709] = {file="chapter3.lua", name="Chapter3"},
}

local target = MODULES[game.PlaceId]
if not target then
    warn("[BeyyHub] Unsupported PlaceId: " .. tostring(game.PlaceId))
    return
end

local function valid(source, moduleName)
    if type(source) ~= "string" or #source < 1500 then return nil end
    if not source:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true) then return nil end
    if not source:find('local __BEYY_MODULE = "' .. moduleName .. '"', 1, true) then return nil end
    return loadstring(source)
end

pcall(function()
    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
        makefolder(CACHE_FOLDER)
    end
end)

local function fetchFresh(url)
    return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1, 1000000000)))
end
local function readCache(path)
    if type(readfile) ~= "function" then return nil end
    local ok, value = pcall(readfile, path)
    return ok and type(value) == "string" and value or nil
end
local function validRevision(value)
    return type(value) == "string" and #value == 40 and value:match("^%x+$") ~= nil
end
local previousRevision = readCache(REVISION_FILE)
if not validRevision(previousRevision) then previousRevision = nil end
local COMMIT_API = "https://api.github.com/repos/BeyyTU/needlehub/commits/main"
local RAW_COMMITS = "https://raw.githubusercontent.com/BeyyTU/needlehub/"
local MAX_ATTEMPTS = 3

local function latestRevision()
    local ok, response = pcall(function()
        return game:GetService("HttpService"):JSONDecode(fetchFresh(COMMIT_API))
    end)
    if ok and type(response) == "table" and validRevision(response.sha) then
        return response.sha
    end
    -- The anonymous GitHub API is rate-limited; online raw main is safer than aborting every AFK round.
    return "main"
end

local function validLoader(value)
    return type(value) == "string" and #value > 1500
        and value:find("BeyyTU/needlehub", 1, true)
        and value:find("local MODULES", 1, true)
        and loadstring(value) ~= nil
end

local function getLatestFile(url, validator)
    for attempt = 1, MAX_ATTEMPTS do
        local ok, value = pcall(fetchFresh, url)
        if ok and validator(value) then return value end
        if attempt < MAX_ATTEMPTS then task.wait(0.4 * attempt) end
    end
    return nil
end

local loaderEnv = _G
if type(getgenv) == "function" then
    local ok, value = pcall(getgenv)
    if ok and type(value) == "table" then loaderEnv = value end
end

local firstRevision = latestRevision()
if firstRevision == "main" then
    warn("[BeyyHub] GitHub revision API unavailable; fetching live raw main instead (no stale-cache fallback)")
end
if loaderEnv.__BEYY_LOADER_PINNED_RUN ~= firstRevision then
    local pinnedPath = CACHE_FOLDER .. "/v103_00_" .. firstRevision .. "_loader.lua"
    local latestRouter = getLatestFile(RAW_COMMITS .. firstRevision .. "/loader.lua", validLoader)
    if not latestRouter and firstRevision ~= "main" then
        local cached = readCache(pinnedPath)
        if validLoader(cached) then latestRouter = cached end
    end
    if not latestRouter then
        warn("[BeyyHub] FAILSAFE: Latest router unavailable; an older router will not be run.")
        return
    end
    loaderEnv.__BEYY_LOADER_PINNED_RUN = firstRevision
    local ok, err = pcall(loadstring(latestRouter))
    loaderEnv.__BEYY_LOADER_PINNED_RUN = nil
    if not ok then warn("[BeyyHub] Latest router failed: " .. tostring(err)) end
    return
end
loaderEnv.__BEYY_LOADER_PINNED_RUN = nil

local revision, source, sourceFunction, moduleCache, downloadBase
for attempt = 1, MAX_ATTEMPTS do
    local requested = attempt == 1 and firstRevision or latestRevision()
    local commitBase = RAW_COMMITS .. requested
    local cachePath = CACHE_FOLDER .. "/v103_00_" .. requested .. "_" .. target.file
    local candidate = getLatestFile(commitBase .. "/" .. target.file, function(value)
        return valid(value, target.name) ~= nil
    end)
    if not candidate and requested ~= "main" then
        local cached = readCache(cachePath)
        if valid(cached, target.name) then candidate = cached end
    end
    if not candidate then
        warn("[BeyyHub] FAILSAFE: No validated " .. target.name .. " module for latest commit " .. requested:sub(1, 7))
        return
    end
    local confirmed = latestRevision()
    if confirmed == requested then
        revision = requested
        source = candidate
        sourceFunction = valid(source, target.name)
        moduleCache = cachePath
        downloadBase = commitBase
        CACHE_PREFIX = CACHE_FOLDER .. "/v103_00_" .. revision .. "_"
        if type(writefile) == "function" then pcall(writefile, moduleCache, source) end
        break
    end
    warn("[BeyyHub] GitHub updated during load (" .. requested:sub(1, 7) ..
         " -> " .. confirmed:sub(1, 7) .. "); retrying newest revision")
end
if not source or not sourceFunction then
    warn("[BeyyHub] FAILSAFE: Repository kept changing; rerun the loader.")
    return
end

-- Invalidate old script caches only after the selected revision has a valid module.
-- Revision-specific paths also prevent stale reuse when deletion is unsupported.
if revision and revision ~= "main" then
    if revision ~= previousRevision then
        if type(delfile) == "function" then
            local oldPrefixes = {"v103_00_", "v103_00_ui1_", "v103_00_rot2_", "v103_00_tabs3_"}
            if previousRevision then table.insert(oldPrefixes, "v103_00_" .. previousRevision .. "_") end
            for _, prefix in ipairs(oldPrefixes) do
                for _, file in ipairs({"loader.lua", "lobby.lua", "chapter1.lua", "chapter2.lua", "chapter3.lua"}) do
                    pcall(delfile, CACHE_FOLDER .. "/" .. prefix .. file)
                end
            end
        end
        print("[BeyyHub] GitHub update detected: " .. revision:sub(1, 7) .. "; old script caches invalidated")
    end
    if type(writefile) == "function" then pcall(writefile, REVISION_FILE, revision) end
end
print("[BeyyHub] Loading " .. target.name .. " | revision " .. (selectedRevision and selectedRevision:sub(1, 7) or "unverified"))

-- Keep the tiny router available offline for queued teleport reloads.
-- Only the module for the current place is downloaded and executed.
local loaderCache = CACHE_PREFIX .. "loader.lua"
local latestRouter = getLatestFile(downloadBase .. "/loader.lua", validLoader)
if latestRouter and type(writefile) == "function" then
    pcall(writefile, loaderCache, latestRouter)
end

local getEnv = (type(getgenv) == "function" and getgenv) or function() return _G end
local okEnv, env = pcall(getEnv)
if not okEnv or type(env) ~= "table" then env = _G end
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue then
    local payload = [==[
        local API = "https://api.github.com/repos/BeyyTU/needlehub/commits/main"
        local RAW = "https://raw.githubusercontent.com/BeyyTU/needlehub/"
        local function fetchFresh(url)
            return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) ..
                "-" .. tostring(math.random(1, 1000000000)))
        end
        local function checkRevision()
            local ok, value = pcall(function()
                return game:GetService("HttpService"):JSONDecode(fetchFresh(API))
            end)
            if ok and type(value) == "table" and type(value.sha) == "string"
                and #value.sha == 40 and value.sha:match("^%x+$") then
                return value.sha
            end
            return "main"
        end
        local function validRouter(data)
            return type(data) == "string" and #data > 1500
                and data:find("BeyyTU/needlehub", 1, true)
                and data:find("local MODULES", 1, true)
                and loadstring(data) ~= nil
        end
        for attempt = 1, 3 do
            local revision = checkRevision()
            local body
            local url = RAW .. revision .. "/loader.lua"
            for retry = 1, 3 do
                local ok, value = pcall(fetchFresh, url)
                if ok and validRouter(value) then body = value; break end
                if retry < 3 then task.wait(0.4 * retry) end
            end
            if not body and revision ~= "main" and type(readfile) == "function" then
                local path = "BeyyHub/v103_00_" .. revision .. "_loader.lua"
                local ok, cached = pcall(readfile, path)
                if ok and validRouter(cached) then body = cached end
            end
            if not body then
                warn("[BeyyHub] FAILSAFE: Latest teleport router unavailable.")
                return
            end
            local confirmed = checkRevision()
            if confirmed == revision then
                local environment = _G
                if type(getgenv) == "function" then
                    local ok, value = pcall(getgenv)
                    if ok and type(value) == "table" then environment = value end
                end
                environment.__BEYY_LOADER_PINNED_RUN = revision
                local ok, err = pcall(loadstring(body))
                environment.__BEYY_LOADER_PINNED_RUN = nil
                if not ok then warn("[BeyyHub] Teleport reload error: " .. tostring(err)) end
                return
            end
            warn("[BeyyHub] Repository updated during teleport reload; fetching newer router")
        end
        warn("[BeyyHub] FAILSAFE: GitHub changed repeatedly during teleport; rerun the loader.")
    ]==]
    local ok, err = pcall(queue, payload)
    if not ok then warn("[BeyyHub] Could not register teleport reload: " .. tostring(err)) end
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun loader after changing chapters")
end

local ok, err = pcall(sourceFunction)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
