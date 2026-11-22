-- BEYY_YETI_RANKS_CLAIM_TEST_V1
-- Standalone, manually confirmed tester for ReplicatedStorage.YetiRanks.Claim.
-- Uses the game's ordinary RemoteFunction; cannot award server-only rewards
-- or change real YetiKingWins. Does not automatically retry or bulk claim.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then warn("[Beyy Yeti Ranks] No local player") return end
local guiParent=player:WaitForChild("PlayerGui")

local env=_G
if type(getgenv)=="function" then
    local ok,out=pcall(getgenv)
    if ok and type(out)=="table" then env=out end
end
if type(env.BeyyYetiRankTesterStop)=="function" then
    pcall(env.BeyyYetiRankTesterStop)
end

-- Exact milestones from ReplicatedStorage.Shared.Configs.YetiRanksConfig.
local ranks={
    {wins=1,kind="Coins",amount=150,title="Yeti Slayer"},
    {wins=3,kind="Chests",amount=1},
    {wins=5,kind="Coins",amount=300},
    {wins=10,kind="Chests",amount=2,title="Frostbitten"},
    {wins=15,kind="Coins",amount=500},
    {wins=25,kind="Chests",amount=3,title="Glacier Warden"},
    {wins=40,kind="Coins",amount=750},
    {wins=60,kind="Chests",amount=4},
    {wins=90,kind="Coins",amount=1200,title="Avalanche"},
    {wins=130,kind="Chests",amount=5},
    {wins=180,kind="Coins",amount=2000},
    {wins=250,kind="Chests",amount=8,title="King's Bane"},
}
local alive=true
local inFlight=false
local selected=1
local indexed=false
local pendingConfirmKey=nil
local pendingConfirmUntil=0
local lastRequestAt=-math.huge
local attempts={}
local connections={}

local function safe(x,depth,visited)
    local t=typeof(x)
    depth=depth or 0
    if t=="nil" then return "<nil>" end
    if t=="string" then return x:sub(1,1200) end
    if t=="number" or t=="boolean" then return x end
    if t=="Instance" then
        local ok,name=pcall(function()return x:GetFullName()end)
        return ok and name or tostring(x)
    end
    if t=="table" then
        if depth>=3 then return "<nested>" end
        visited=visited or {}
        if visited[x] then return "<cyclic>" end
        visited[x]=true
        local out,n={},0
        for k,v in pairs(x) do
            n+=1
            if n>65 then out.__truncated=true break end
            local name=tostring(k):sub(1,80)
            local low=name:lower()
            if low:find("token",1,true) or low:find("password",1,true)
                or low:find("secret",1,true) or low:find("cookie",1,true)
                or low:find("webhook",1,true) then
                out[name]="<redacted>"
            else
                local ok,r=pcall(safe,v,depth+1,visited)
                if ok then out[name]=r else out[name]="<unavailable>" end
            end
        end
        visited[x]=nil
        return out
    end
    return tostring(x):sub(1,280)
end
local function attrSnapshot()
    local result={}
    for _,name in ipairs({"YetiKingWins","WinterCoins",
        "WinterChestCredits","YetiRanksClaimed"}) do
        result[name]=safe(player:GetAttribute(name))
    end
    return result
end
local function claimRemote()
    local folder=RS:FindFirstChild("YetiRanks")
    local claim=folder and folder:FindFirstChild("Claim")
    return claim and claim:IsA("RemoteFunction") and claim or nil
end
local function export()
    if type(writefile)~="function" then return false end
    if type(makefolder)=="function" then
        local exists=false
        if type(isfolder)=="function" then
            local ok,v=pcall(isfolder,"BeyyHub")
            exists=ok and v==true
        end
        if not exists then pcall(makefolder,"BeyyHub") end
    end
    local ok,doc=pcall(HS.JSONEncode,HS,{
        marker="BEYY_YETI_RANKS_CLAIM_TEST_V1",
        placeId=game.PlaceId,
        notes={
            "All requests are manual and use YetiRanks.Claim.",
            "No-argument and rank-index formats are hypotheses; server responses establish acceptance.",
            "Nil player attributes are not the same as zero persistent balances.",
            "Successful Lua InvokeServer is not proof of an awarded reward."
        },
        attempts=attempts,
    })
    return ok and pcall(writefile,
        "BeyyHub/yeti_ranks_claim_test.json",doc) or false
end

local gui=Instance.new("ScreenGui")
gui.Name="BeyyYetiRanksClaimTest"
gui.IgnoreGuiInset=true
gui.ResetOnSpawn=false
gui.DisplayOrder=10004
gui.Parent=guiParent

local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(433,302)
panel.Position=UDim2.new(1,-15,0,22)
panel.AnchorPoint=Vector2.new(1,0)
panel.BackgroundColor3=Color3.fromRGB(25,30,43)
panel.BorderSizePixel=0;panel.Parent=gui
local panelCorner=Instance.new("UICorner")
panelCorner.CornerRadius=UDim.new(0,10);panelCorner.Parent=panel
local function label(str,x,y,w,h,size)
    local o=Instance.new("TextLabel")
    o.BackgroundTransparency=1
    o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h)
    o.Font=Enum.Font.Gotham;o.TextSize=size or 12
    o.TextColor3=Color3.fromRGB(237,242,250)
    o.TextXAlignment=Enum.TextXAlignment.Left;o.TextWrapped=true
    o.Text=str;o.Parent=panel
    return o
end
local function button(str,x,y,w,h,rgb)
    local o=Instance.new("TextButton")
    o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h)
    o.BackgroundColor3=rgb;o.BorderSizePixel=0
    o.Font=Enum.Font.GothamBold;o.TextSize=12
    o.TextColor3=Color3.fromRGB(249,250,255)
    o.Text=str;o.Parent=panel
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,6);c.Parent=o
    return o
end
label("YETI KING · WIN REWARD CLAIM TEST",12,9,390,24,15)
local close=button("X",405,9,20,23,Color3.fromRGB(137,59,66))
label("Manually test a rank reward request. If accepted, the game may grant the real item immediately.",12,39,409,37,11)
local rankLabel=label("",57,83,320,38,13)
local prev=button("<",12,84,36,35,Color3.fromRGB(64,77,99))
local nextBtn=button(">",383,84,36,35,Color3.fromRGB(64,77,99))
local modeBtn=button("REQUEST MODE: NORMAL (NO ARGUMENT)",12,131,407,32,Color3.fromRGB(59,77,108))
local instruction=label("Normal claim: selected rank is only a reference; NO rank number is sent.",12,170,407,38,11)
local testBtn=button("SEND ONE CLAIM REQUEST · CONFIRM TWICE",12,214,407,35,Color3.fromRGB(38,133,98))
local status=label("Ready · No request sent. Results export to workspace/BeyyHub.",12,258,408,35,11)

local function refresh()
    local rank=ranks[selected]
    rankLabel.Text=string.format("#%d · %d wins: %d %s%s",
        selected,rank.wins,rank.amount,rank.kind,
        rank.title and (" + "..rank.title) or "")
    modeBtn.Text=indexed and
        "REQUEST MODE: EXPERIMENTAL CLAIM(RANK INDEX)"
        or "REQUEST MODE: NORMAL (NO ARGUMENT)"
    instruction.Text=indexed
        and ("Experimental: server receives rank index "..selected..
            ". This argument format is unverified.")
        or "Normal: server receives no rank number. Selection only labels the UI."
end
refresh()
local function changeSelection(delta)
    if inFlight then return end
    selected=math.clamp(selected+delta,1,#ranks)
    pendingConfirmKey=nil
    refresh()
end
connections[#connections+1]=prev.Activated:Connect(function()changeSelection(-1)end)
connections[#connections+1]=nextBtn.Activated:Connect(function()changeSelection(1)end)
connections[#connections+1]=modeBtn.Activated:Connect(function()
    if inFlight then return end
    indexed=not indexed
    pendingConfirmKey=nil
    refresh()
end)
connections[#connections+1]=testBtn.Activated:Connect(function()
    if not alive or inFlight then return end
    local key=indexed and ("indexed:"..selected) or "normal"
    local now=os.clock()
    if pendingConfirmKey~=key or now>pendingConfirmUntil then
        pendingConfirmKey=key
        pendingConfirmUntil=now+10
        status.Text="CONFIRM: press again within 10 seconds. An eligible reward may be granted."
        return
    end
    if now-lastRequestAt<10 then
        status.Text="One-request throttle active. Retry after 10 seconds."
        return
    end
    local remote=claimRemote()
    if not remote then
        status.Text="YetiRanks.Claim RemoteFunction is not present in this place."
        return
    end
    pendingConfirmKey=nil
    lastRequestAt=now
    inFlight=true
    testBtn.Text="WAITING FOR SERVER..."
    local rankIndex=selected
    local winThreshold=ranks[selected].wins
    local usesIndex=indexed
    local before=attrSnapshot()
    local at=os.date("!%Y-%m-%dT%H:%M:%SZ")
    instruction.Text=usesIndex and
        ("Invoking Claim("..rankIndex..") ONCE") or
        "Invoking Claim() ONCE"
    task.spawn(function()
        local result=table.pack(pcall(function()
            if usesIndex then return remote:InvokeServer(rankIndex) end
            return remote:InvokeServer()
        end))
        local replies={}
        for i=2,result.n do replies[#replies+1]=safe(result[i]) end
        task.wait(0.5)
        local record={
            utc=at,
            mode=usesIndex and "rank_index_argument" or "no_argument",
            rankIndex=usesIndex and rankIndex or nil,
            uiSelectedRank=rankIndex,
            uiSelectedWinThreshold=winThreshold,
            requestArgs=usesIndex and {rankIndex} or {},
            transportOk=result[1]==true,
            serverResponse=replies,
            attrsBefore=before,
            attrsAfter=attrSnapshot(),
        }
        attempts[#attempts+1]=record
        export()
        print("[Beyy Yeti Rank Test] "..HS:JSONEncode(record))
        if not alive then return end
        inFlight=false
        refresh()
        testBtn.Text="SEND ONE CLAIM REQUEST · CONFIRM TWICE"
        local preview=replies[1]
        if type(preview)=="table" then
            local ok,text=pcall(HS.JSONEncode,HS,preview)
            preview=ok and text or "<could not encode reply>"
        end
        status.Text=(result[1] and "Request completed: " or "Request errored: ")
            ..tostring(preview):sub(1,160)
    end)
end)
local function stop()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()gui:Destroy()end)
end
connections[#connections+1]=close.Activated:Connect(stop)
env.BeyyYetiRankTesterStop=stop
print("[Beyy Yeti Rank Test] Manual tester ready; select a mode, double-confirm.")
