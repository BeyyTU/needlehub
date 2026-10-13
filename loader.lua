-- beyy v103.00 | fast, SHA-pinned PlaceId router (PR #3 inspired)
local VERSION = "103.00"
local REPO = "BeyyTU/needlehub"
local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/"
local API = "https://api.github.com/repos/" .. REPO .. "/commits/main"
local CACHE_FOLDER = "BeyyHub"
local PLAYER_CACHE_FOLDER = "__BeyyHubModuleCacheV103"
local RUNNER_CACHE_FOLDER = "__BeyyHubCompiledRunnersV103"
local MAX_ATTEMPTS = 3
local MODULES = {
    [77108422251420] = {file="lobby.lua", name="Lobby"},
    [108628039999641] = {file="chapter1.lua", name="Chapter1"},
    [83445806734780] = {file="chapter2.lua", name="Chapter2"},
    [82626725163709] = {file="chapter3.lua", name="Chapter3"},
}
local target = MODULES[game.PlaceId]
if not target then warn("[BeyyHub] Unsupported PlaceId: " .. tostring(game.PlaceId)); return end

local started, requests = os.clock(), 0
local compileSeconds = 0
local function fetch(url)
    requests += 1
    return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" .. tostring(math.random(1,1000000000)))
end
local function validRevision(sha)
    return type(sha) == "string" and #sha == 40 and sha:match("^%x+$") ~= nil
end
local function validated(body)
    if type(body) ~= "string" or #body < 1500 then return nil end
    if not body:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true)
        or not body:find('local __BEYY_MODULE = "' .. target.name .. '"', 1, true) then
        return nil
    end
    local compileStarted = os.clock()
    local ok, fn = pcall(loadstring, body)
    compileSeconds += os.clock() - compileStarted
    return ok and type(fn) == "function" and fn or nil
end
local function readCache(path)
    if type(readfile) ~= "function" then return nil end
    local ok, raw = pcall(readfile, path)
    return ok and type(raw) == "string" and raw or nil
end
local function checkRevision()
    local ok, payload = pcall(function()
        return game:GetService("HttpService"):JSONDecode(fetch(API))
    end)
    if ok and type(payload) == "table" and validRevision(payload.sha) then return payload.sha end
    warn("[BeyyHub] Revision API unavailable; fetching live main, never an unchecked old cache")
    return nil
end

local env = _G
if type(getgenv) == "function" then
    local ok, other = pcall(getgenv)
    if ok and type(other) == "table" then env = other end
end
if type(env.__BEYY_FAST_MODULE_CACHE_V103) ~= "table" then
    env.__BEYY_FAST_MODULE_CACHE_V103 = {}
end
local memory = env.__BEYY_FAST_MODULE_CACHE_V103
if type(env.__BEYY_FAST_COMPILED_CACHE_V103) ~= "table" then
    env.__BEYY_FAST_COMPILED_CACHE_V103 = {}
end
local compiled = env.__BEYY_FAST_COMPILED_CACHE_V103
local player = game:GetService("Players").LocalPlayer
local function sessionFile(create)
    if not player then return nil end
    local folder = player:FindFirstChild(PLAYER_CACHE_FOLDER)
    if folder and not folder:IsA("Folder") then return nil end
    if not folder and create then
        folder = Instance.new("Folder")
        folder.Name = PLAYER_CACHE_FOLDER
        folder.Parent = player
    end
    if not folder then return nil end
    local file = folder:FindFirstChild(target.file)
    if file and not file:IsA("StringValue") then return nil end
    if not file and create then
        file = Instance.new("StringValue")
        file.Name = target.file
        file.Parent = folder
    end
    return file
end

-- A BindableFunction keeps its callback in the original Lua context. This may
-- allow Solara sessions whose global tables reset between executions to reuse
-- an already compiled module. It remains a best-effort cache: failures fall
-- back to the normal verified-source loader.
local function findCompiledRunner()
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild(RUNNER_CACHE_FOLDER)
    if not folder or not folder:IsA("Folder") then return nil end
    local runner = folder:FindFirstChild(target.name)
    return runner and runner:IsA("BindableFunction") and runner or nil
end
local function runnerResponds(runner, revision)
    local finished, ready = false, false
    task.spawn(function()
        local ok, reply = pcall(function() return runner:Invoke("probe", revision) end)
        ready, finished = ok and reply == true, true
    end)
    local deadline = os.clock() + 0.20
    while not finished and os.clock() < deadline do task.wait() end
    return finished and ready
end
local function installCompiledRunner(revision, moduleFn)
    local ok, err = pcall(function()
        local root = game:GetService("ReplicatedStorage")
        local folder = root:FindFirstChild(RUNNER_CACHE_FOLDER)
        if folder and not folder:IsA("Folder") then error("runner cache folder has wrong type") end
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = RUNNER_CACHE_FOLDER
            folder.Parent = root
        end
        local previous = folder:FindFirstChild(target.name)
        if previous then previous:Destroy() end
        local runner = Instance.new("BindableFunction")
        runner.Name = target.name
        runner:SetAttribute("Revision", revision)
        runner.OnInvoke = function(command, requestedRevision)
            if requestedRevision ~= revision then return false, "revision mismatch" end
            if command == "probe" then return true end
            if command ~= "run" then return false, "unknown command" end
            return pcall(moduleFn)
        end
        runner.Parent = folder
    end)
    if not ok then warn("[BeyyHub Cache] instance runner unavailable: " .. tostring(err)) end
end

-- One revision request per execution. Immutable SHA-backed cache entries do
-- not need further network validation or a second copy of the router.
local revisionStarted = os.clock()
local sha = checkRevision()
local revisionSeconds = os.clock() - revisionStarted
local key = (sha or "main") .. "/" .. target.file
local cachePath = CACHE_FOLDER .. "/v103_00_fast_" .. (sha or "unverified") .. "_" .. target.file
local fn, body, source
local cacheProbe = {memory="unavailable", compiled="unavailable", player="unavailable", disk="unavailable", instance="unavailable"}
if sha then
    local runner = findCompiledRunner()
    cacheProbe.instance = runner and (runner:GetAttribute("Revision") == sha and "matching-revision" or "different-revision") or "missing"
    if runner and runner:GetAttribute("Revision") == sha and runnerResponds(runner, sha) then
        fn = function()
            local succeeded, errorMessage = runner:Invoke("run", sha)
            if not succeeded then error("cached module execution failed: " .. tostring(errorMessage)) end
        end
        body, source = "compiled-instance", "compiled-instance"
    elseif runner and runner:GetAttribute("Revision") == sha then
        cacheProbe.instance = "callback-unavailable"
    end
    local value = memory[key]
    local cached = compiled[key]
    cacheProbe.memory = type(value)
    cacheProbe.compiled = type(cached)
    if not fn and type(value) == "string" and type(cached) == "table"
        and cached.body == value and type(cached.fn) == "function"
        and value:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true)
        and value:find('local __BEYY_MODULE = "' .. target.name .. '"', 1, true) then
        fn, body, source = cached.fn, value, "compiled-memory"
    elseif not fn then
        fn = validated(value)
        if fn then body, source = value, "memory" end
    end
    if not fn then
        local object = sessionFile(false)
        cacheProbe.player = not object and "missing" or
            (object:GetAttribute("Revision") == sha and "matching-revision" or "different-revision")
        if object and object:GetAttribute("Revision") == sha then
            fn = validated(object.Value)
            if fn then body, source = object.Value, "player" end
        end
    end
    if not fn then
        value = readCache(cachePath)
        cacheProbe.disk = type(value)
        fn = validated(value)
        if fn then body, source = value, "disk" end
    end
end
if not fn and sha then
    print(string.format("[BeyyHub Cache] miss: memory=%s compiled=%s player=%s disk=%s instance=%s",
        cacheProbe.memory, cacheProbe.compiled, cacheProbe.player, cacheProbe.disk, cacheProbe.instance))
end
if not fn then
    local url = RAW .. (sha or "main") .. "/" .. target.file
    for attempt = 1, MAX_ATTEMPTS do
        local ok, value = pcall(fetch, url)
        if ok then
            fn = validated(value)
            if fn then body, source = value, "network"; break end
        end
        if attempt < MAX_ATTEMPTS then task.wait(0.3 * attempt) end
    end
end
if not fn or not body then
    warn("[BeyyHub] Latest " .. target.name .. " module unavailable; refusing stale code")
    return
end

if sha and source ~= "compiled-instance" then
    memory[key] = body
    compiled[key] = {body = body, fn = fn}
    installCompiledRunner(sha, fn)
    if source ~= "player" then
        local saved, saveError = pcall(function()
            local object = sessionFile(true)
            if not object then error("player StringValue unavailable") end
            object.Value = body
            object:SetAttribute("Revision", sha)
            if object.Value ~= body or object:GetAttribute("Revision") ~= sha then
                error("player StringValue verification failed")
            end
        end)
        if not saved then
            warn("[BeyyHub Cache] player cache save failed: " .. tostring(saveError))
        end
    end
    if source == "network" and type(writefile) == "function" then
        task.defer(function()
            pcall(function()
                if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
                    makefolder(CACHE_FOLDER)
                end
                writefile(cachePath, body)
            end)
        end)
    end
end

-- The queued payload only fetches the latest router. That router performs a
-- single revision check itself and never recursively fetches another router.
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue then
    local payload = [==[
        local url = "https://raw.githubusercontent.com/BeyyTU/needlehub/main/loader.lua"
        local ok, data = pcall(function()
            return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" ..
                tostring(math.random(1,1000000000)))
        end)
        if not ok or type(data) ~= "string" or #data < 1500 then
            warn("[BeyyHub] Teleport router download failed; execute the latest loader again")
            return
        end
        local fn, err = loadstring(data)
        if not fn then warn("[BeyyHub] Teleport router compile error: " .. tostring(err)); return end
        local success, runtimeError = pcall(fn)
        if not success then warn("[BeyyHub] Teleport router error: " .. tostring(runtimeError)) end
    ]==]
    local ok, err = pcall(queue, payload)
    if not ok then warn("[BeyyHub] Teleport reload queue failed: " .. tostring(err)) end
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun the loader after changing chapters")
end

print(string.format("[BeyyHub Startup] %s source=%s revision=%s requests=%d revisionCheck=%.2fs compile=%.3fs loader=%.2fs",
    target.name, source, (sha or "main"):sub(1,7), requests,
    revisionSeconds, compileSeconds, os.clock() - started))
local moduleStarted = os.clock()
local ok, err = pcall(fn)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
print(string.format("[BeyyHub Startup] %s module returned after %.2fs (module=%.2fs)",
    target.name, os.clock() - started, os.clock() - moduleStarted))
