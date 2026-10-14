-- BeyyHub Ranch: native PuzzleDone(piece) one-shot validation probe.
-- IMPORTANT: execute BEFORE attaching the UFO part, without the regular BeyyHub.
-- Sends exactly one PuzzleDone:FireServer(piece) request per incoming native puzzle.
-- Does not simulate input, fire other game remotes, or change any GUI.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local started=os.clock()
local report={}
local types={
    VentPuzzle="UfoVentMinigame",
    WirePuzzle="UfoWireMinigame",
    AlignPuzzle="UfoAlignMinigame"
}
local seen={}
local activeSessions={}
local listeners={}
local closedCount=0
local maxDuration=600

local function api(name)
    if name=="setclipboard" and type(setclipboard)=="function" then return setclipboard end
    if name=="toclipboard" and type(toclipboard)=="function" then return toclipboard end
    if name=="writefile" and type(writefile)=="function" then return writefile end
    local f=rawget(_G,name)
    if type(f)=="function" then return f end
    if type(getgenv)=="function" then
        local ok,env=pcall(getgenv)
        if ok and type(env)=="table" and type(rawget(env,name))=="function" then
            return rawget(env,name)
        end
    end
end
local function log(s)
    local line=string.format("[Ranch PuzzleDone Probe] +%.2fs %s",os.clock()-started,tostring(s))
    report[#report+1]=line
    print(line)
end
local function export(reason)
    local content=table.concat(report,"\n")
    local write=api("writefile")
    if write then
        local ok,err=pcall(write,"beyyhub-ranch-puzzledone-test.txt",content)
        if not ok then warn("[Ranch PuzzleDone Probe] Save failed: "..tostring(err)) end
    end
    local copy=api("setclipboard") or api("toclipboard")
    if copy then
        local ok,err=pcall(copy,content)
        if ok then
            print("[Ranch PuzzleDone Probe] Report copied ("..reason.."). Press Ctrl+V in ChatGPT.")
        else
            warn("[Ranch PuzzleDone Probe] Clipboard failed: "..tostring(err))
        end
    else
        warn("[Ranch PuzzleDone Probe] Clipboard unavailable; use saved text file.")
    end
end
local function safeName(obj)
    if typeof(obj)~="Instance" then return tostring(obj) end
    local ok,name=pcall(function()return obj:GetFullName()end)
    return ok and name or obj.Name
end
local function state(piece)
    local ufo=Workspace:FindFirstChild("UfoSplitted")
    local parts=ufo and tostring(ufo:GetAttribute("PartsReturned")) or "missing"
    local returned=piece and tostring(piece:GetAttribute("Returned")) or "missing"
    local revealed=piece and tostring(piece:GetAttribute("Revealed")) or "missing"
    local glow=piece and tostring(piece:FindFirstChild("WiredGlow")~=nil) or "missing"
    return "PartsReturned="..parts.." Returned="..returned..
        " Revealed="..revealed.." WiredGlow="..glow
end
local function isGuiOpen(guiName)
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local gui=pg and pg:FindFirstChild(guiName)
    local panel=gui and gui:FindFirstChild("Panel")
    return gui and gui:IsA("ScreenGui") and gui.Enabled
        and panel and panel:IsA("GuiObject") and panel.Visible
end

local folder=ReplicatedStorage:WaitForChild("UfoCrash",15)
local remotes=folder and folder:WaitForChild("Remotes",15)
local done=remotes and remotes:FindFirstChild("PuzzleDone")
if not done or not done:IsA("RemoteEvent") then
    log("ERROR: PuzzleDone RemoteEvent missing; no request sent")
    export("setup failed")
    return
end
log("Ready. Attach a Ranch UFO part. Do not interact with the puzzle UI.")
log("Will capture piece from native VentPuzzle/WirePuzzle/AlignPuzzle event.")
log("Only PuzzleDone(piece) is tested; no WireLight or other remote is fired.")

for remoteName,guiName in pairs(types) do
    local remote=remotes:FindFirstChild(remoteName)
    if remote and remote:IsA("RemoteEvent") then
        listeners[#listeners+1]=remote.OnClientEvent:Connect(function(piece,...)
            local parent=Workspace:FindFirstChild("UfoSplitted")
            if typeof(piece)~="Instance" or not parent or not piece:IsDescendantOf(parent) then
                log("IGNORED "..remoteName.." invalid part: "..safeName(piece))
                return
            end
            local session={
                name=remoteName,guiName=guiName,piece=piece,
                eventAt=os.clock(),requested=false,openedAt=nil,
                earlyLogged=false,closed=false
            }
            seen[remoteName]=session
            activeSessions[#activeSessions+1]=session
            log("CAPTURED "..remoteName.." piece="..safeName(piece)..
                " | "..state(piece))
        end)
        log("Listening for "..remoteName)
    else
        log("WARNING: "..remoteName.." remote missing; this puzzle cannot be tested")
    end
end
export("ready; execute before opening puzzle")

local nextCheck=os.clock()
while os.clock()-started<maxDuration do
    for _,session in ipairs(activeSessions) do
        if not session.closed then
            local open=isGuiOpen(session.guiName)
            if open and not session.openedAt then
                session.openedAt=os.clock()
                log(session.guiName.." UI OPENED for "..safeName(session.piece))
            end
            if open and session.openedAt and not session.requested then
                session.requested=true -- mark first, prohibiting any retry
                session.sentAt=os.clock()
                session.before=state(session.piece)
                local ok,err=pcall(function()done:FireServer(session.piece)end)
                log("ONE REQUEST "..session.name.." -> PuzzleDone:FireServer(piece)"..
                    " localFireSucceeded="..tostring(ok)..
                    " argument="..safeName(session.piece))
                if not ok then log("Local FireServer error: "..tostring(err)) end
                log("Before: "..session.before)
            end
            if session.requested and open and not session.earlyLogged
                and os.clock()-session.sentAt>=2.5 then
                session.earlyLogged=true
                log(session.guiName.." STILL OPEN 2.5s after request; no instant closure confirmed"..
                    " | "..state(session.piece))
                export("2.5-second result")
            end
            if session.openedAt and not open then
                session.closed=true
                closedCount+=1
                local after=state(session.piece)
                log(session.guiName.." CLOSED: elapsedSinceUI="..
                    string.format("%.2f",os.clock()-session.openedAt)..
                    "s; elapsedSinceRequest="..
                    (session.sentAt and string.format("%.2f",os.clock()-session.sentAt) or "not sent")..
                    "s; "..after)
                log("Interpretation: quick closure is promising but NOT proof of server validation.")
                export("puzzle closed")
            elseif not session.openedAt and os.clock()-session.eventAt>20 then
                session.closed=true
                log("TIMEOUT: no GUI appeared within 20s for "..session.name..
                    "; no request sent")
                export("UI timeout")
            end
        end
    end
    task.wait(0.10)
end
for _,conn in ipairs(listeners) do pcall(function()conn:Disconnect()end)end
log("FINISHED; UI events="..#activeSessions..
    "; closed="..closedCount.."; one request max per captured event.")
export("final")
