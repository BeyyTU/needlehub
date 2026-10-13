-- BeyyHub v103.00 | optional direct-branch fast loader
-- One module request per run; no revision API or unreliable local cache.
local VERSION = "103.00"
local BASE = "https://raw.githubusercontent.com/BeyyTU/needlehub/main/"
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

local begin = os.clock()
local requests, compileSeconds = 0, 0
local function fetch(url)
    requests += 1
    return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" ..
        tostring(math.random(1,1000000000)))
end
local function validate(source)
    if type(source) ~= "string" or #source < 1500 then return nil end
    if not source:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true)
        or not source:find('local __BEYY_MODULE = "' .. target.name .. '"', 1, true) then
        return nil
    end
    local started = os.clock()
    local ok, fn = pcall(loadstring, source)
    compileSeconds += os.clock() - started
    return ok and type(fn) == "function" and fn or nil
end

local fn
for attempt = 1, 3 do
    local ok, source = pcall(fetch, BASE .. target.file)
    if ok then
        fn = validate(source)
        if fn then break end
    end
    if attempt < 3 then task.wait(0.25 * attempt) end
end
if not fn then
    warn("[BeyyHub] Could not download/compile the latest " .. target.name ..
        " module. No outdated cached module was executed.")
    return
end

local env = _G
if type(getgenv) == "function" then
    local ok, candidate = pcall(getgenv)
    if ok and type(candidate) == "table" then env = candidate end
end
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue then
    local payload = [==[
        local url = "https://raw.githubusercontent.com/BeyyTU/needlehub/main/fast-loader.lua"
        local ok, source = pcall(function()
            return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) ..
                "-" .. tostring(math.random(1,1000000000)))
        end)
        if not ok or type(source) ~= "string" or #source < 1500 then
            warn("[BeyyHub] Fast teleport loader unavailable; re-execute manually")
            return
        end
        local compiled, compileError = loadstring(source)
        if not compiled then
            warn("[BeyyHub] Fast teleport loader compile error: " .. tostring(compileError))
            return
        end
        local succeeded, runtimeError = pcall(compiled)
        if not succeeded then
            warn("[BeyyHub] Fast teleport loader error: " .. tostring(runtimeError))
        end
    ]==]
    local ok, err = pcall(queue, payload)
    if not ok then warn("[BeyyHub] Teleport queue failed: " .. tostring(err)) end
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun after changing chapters")
end

print(string.format("[BeyyHub Fast Startup] %s source=live-main requests=%d compile=%.3fs loader=%.2fs",
    target.name, requests, compileSeconds, os.clock() - begin))
local moduleBegin = os.clock()
local ok, err = pcall(fn)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
print(string.format("[BeyyHub Fast Startup] %s module returned after %.2fs (module=%.2fs)",
    target.name, os.clock() - begin, os.clock() - moduleBegin))
