-- BEYY_WINTER_REWARD_STATUS_V1
-- Read-only view of the client's synchronized DataServiceTyped reward state.
-- Source basis: ReplicatedStorage.Shared.Services.Data and DataServiceTyped.Value.
-- Does NOT fire claim/buy remotes, set profile values, or forge rewards.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
if not player then warn("[Beyy Reward Status] LocalPlayer unavailable") return end
local guiParent=player:WaitForChild("PlayerGui")
local env=_G
if type(getgenv)=="function" then
    local ok,out=pcall(getgenv)
    if ok and type(out)=="table" then env=out end
end
if type(env.BeyyWinterRewardStatusStop)=="function" then
    pcall(env.BeyyWinterRewardStatusStop)
end
local alive=true
local reading=false
local connections={}
local snapshots={}
local lastJson=nil
local milestones={1,3,5,10,15,25,40,60,90,130,180,250}
local function compact(v,depth)
    depth=depth or 0
    local t=typeof(v)
    if t=="nil" then return "<unavailable>" end
    if t=="number" then return (v==v and math.abs(v)<math.huge) and v or tostring(v) end
    if t=="boolean" then return v end
    if t=="string" then return v:sub(1,180) end
    if t~="table" then return tostring(v):sub(1,180) end
    if depth>=2 then return "<nested>" end
    local out,n={},0
    for k,x in pairs(v) do
        if n>=100 then out.__truncated=true break end
        local key=tostring(k):sub(1,75)
        if not key:lower():find("password",1,true)
            and not key:lower():find("token",1,true)
            and not key:lower():find("secret",1,true) then
            out[key]=compact(x,depth+1)
            n+=1
        end
    end
    return out
end
local function getClientData()
    local shared=RS:FindFirstChild("Shared")
    local services=shared and shared:FindFirstChild("Services")
    local mod=services and services:FindFirstChild("Data")
    if not mod or not mod:IsA("ModuleScript") then
        error("ReplicatedStorage.Shared.Services.Data unavailable in this place")
    end
    -- The Data module returns {client=<DataServiceTyped.Value>}.
    -- DataServiceTyped.Value.__call() WITHOUT arguments reads the
    -- synchronized table without invoking its setter or replication hook.
    local service=require(mod)
    if type(service)~="table" or service.client==nil then
        error("Data service did not expose a client Value")
    end
    local data=service.client()
    if type(data)~="table" then
        error("Data service client was not loaded as a table")
    end
    return data
end
local function rewardSnapshot(data)
    local rank=type(data.YetiRanks)=="table" and data.YetiRanks or {}
    local trail=type(data.WinterTrail)=="table" and data.WinterTrail or {}
    local wins=tonumber(data.YetiKingWins)
    local claimed=tonumber(rank.Claimed)
    local nextRank=nil
    if claimed then
        local nextIndex=math.clamp(math.floor(claimed)+1,1,#milestones+1)
        local need=milestones[nextIndex]
        if need then
            nextRank={index=nextIndex,winsRequired=need,
                winRequirementMet=wins~=nil and wins>=need or false}
        end
    end
    return {
        signature="BEYY_WINTER_REWARD_STATUS_V1",
        placeId=game.PlaceId,
        observedUtc=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        state={
            YetiKingWins=compact(data.YetiKingWins),
            YetiRanksClaimed=compact(rank.Claimed),
            WinterCoins=compact(data.WinterCoins),
            WinterChestCredits=compact(data.WinterChestCredits),
            WinterTrailDay=compact(trail.Day),
            WinterTrailOpensAt=compact(trail.OpensAt),
            WinterTrailProgress=compact(trail.Progress),
            WinterTrailDays=compact(data.WinterTrailDays),
        },
        nextYetiRank=nextRank,
        warning="A local synchronized snapshot does not prove server claimability; only legitimate server confirmation does.",
    }
end
local function writeSnapshot(snap)
    if type(writefile)~="function" then return false end
    if type(makefolder)=="function" then
        local exists=false
        if type(isfolder)=="function" then
            local ok,x=pcall(isfolder,"BeyyHub")
            exists=ok and x==true
        end
        if not exists then pcall(makefolder,"BeyyHub") end
    end
    local ok,json=pcall(HS.JSONEncode,HS,snap)
    if not ok then return false end
    lastJson=json
    return pcall(writefile,"BeyyHub/winter_reward_status.json",json)
end
local gui=Instance.new("ScreenGui")
gui.Name="BeyyWinterRewardStatus"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=10005
gui.Parent=guiParent
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(420,271)
panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-15,0,25)
panel.BackgroundColor3=Color3.fromRGB(25,30,43)
panel.BorderSizePixel=0
panel.Parent=gui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,10)
corner.Parent=panel
local function textLabel(str,y,h,size)
    local o=Instance.new("TextLabel")
    o.Position=UDim2.fromOffset(12,y)
    o.Size=UDim2.fromOffset(396,h)
    o.BackgroundTransparency=1
    o.Font=Enum.Font.Gotham
    o.TextColor3=Color3.fromRGB(235,241,249)
    o.TextSize=size or 12
    o.TextXAlignment=Enum.TextXAlignment.Left
    o.TextWrapped=true;o.Text=str;o.Parent=panel
    return o
end
local function button(str,x,y,w)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(w,33)
    b.Position=UDim2.fromOffset(x,y)
    b.BackgroundColor3=Color3.fromRGB(53,99,143)
    b.BorderSizePixel=0
    b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold;b.TextSize=12
    b.Text=str;b.Parent=panel
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,6);c.Parent=b
    return b
end
textLabel("WINTER REWARDS · REAL DATA STATUS",9,24,16)
textLabel("Reads synchronized data only. Does not call claim or shop remotes.",38,28,11)
local status=textLabel("Ready. Read the current profile when data is loaded.",75,33,12)
local first=textLabel("Yeti wins: —  |  Yeti rank claims: —",114,23,13)
local second=textLabel("Winter coins: —  |  Chest credits: —",138,23,13)
local third=textLabel("Winter Trail day: —  |  Opens at: —",163,24,12)
local info=textLabel("Reward data is not expected to be Player attributes.",190,27,11)
local readBtn=button("READ DATA",12,226,183)
local copyBtn=button("COPY RESULT",207,226,201)
local function refresh()
    if reading or not alive then return end
    reading=true
    status.Text="Reading DataServiceTyped client value..."
    readBtn.Text="READING..."
    task.spawn(function()
        local ok,result=pcall(function()
            local data=getClientData()
            return rewardSnapshot(data)
        end)
        if not alive then return end
        reading=false
        readBtn.Text="READ DATA"
        if not ok then
            status.Text="Read failed: "..tostring(result):sub(1,150)
            print("[Beyy Reward Status] Error: "..tostring(result))
            return
        end
        snapshots[#snapshots+1]=result
        local s=result.state
        local function txt(x)
            return type(x)=="table" and "<table>" or tostring(x)
        end
        first.Text="Yeti wins: "..txt(s.YetiKingWins)
            .."  |  Rank claims: "..txt(s.YetiRanksClaimed)
        second.Text="Winter coins: "..txt(s.WinterCoins)
            .."  |  Chest credits: "..txt(s.WinterChestCredits)
        third.Text="Winter Trail day: "..txt(s.WinterTrailDay)
            .."  |  Opens at: "..txt(s.WinterTrailOpensAt)
        local nextRank=result.nextYetiRank
        info.Text=nextRank
            and ("Next rank "..nextRank.index.." needs "..nextRank.winsRequired..
                " wins; threshold met: "..tostring(nextRank.winRequirementMet))
            or "Next rank could not be inferred from available client data."
        local exported=writeSnapshot(result)
        local jsonOk,json=pcall(HS.JSONEncode,HS,result)
        if jsonOk then lastJson=json end
        status.Text=exported and "DATA READ · JSON EXPORTED"
            or "DATA READ · NO FILE API (use copy result)"
        print("[Beyy Reward Status] "..(jsonOk and json or "JSON encoding failed"))
    end)
end
connections[#connections+1]=readBtn.Activated:Connect(refresh)
connections[#connections+1]=copyBtn.Activated:Connect(function()
    if not lastJson then status.Text="Read data first." return end
    local copy=(type(setclipboard)=="function" and setclipboard)
        or (type(toclipboard)=="function" and toclipboard)
    if not copy then status.Text="Clipboard API unavailable; use exported JSON."
    else
        local ok=pcall(copy,lastJson)
        status.Text=ok and "JSON copied to clipboard" or "Clipboard copy failed"
    end
end)
local function stop()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()gui:Destroy()end)
end
env.BeyyWinterRewardStatusStop=stop
print("[Beyy Reward Status] Ready. Click READ DATA to inspect local synchronized progression.")
