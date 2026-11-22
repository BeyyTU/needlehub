-- BEYY_FROST_MARKET_SINGLE_REQUEST_V1
-- Explicit, manual normal-market purchase test. No time modification,
-- no automatic purchases, no remote flooding, no reward forgery.
-- Based on the replicated FrostMarketConfig Id/Price schedule.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
local guiParent=player:WaitForChild("PlayerGui")
local env=_G
if type(getgenv)=="function" then
    local ok,e=pcall(getgenv)
    if ok and type(e)=="table" then env=e end
end
if type(env.BeyyFrostMarketTesterStop)=="function" then
    pcall(env.BeyyFrostMarketTesterStop)
end

local items={
    {id="ReindeerAntlers",label="Reindeer Antlers",price=1500,
        start=DateTime.fromUniversalTime(2026,11,21,18,30,0).UnixTimestamp},
    {id="SnowBeanie",label="Snow Beanie",price=2500,
        start=DateTime.fromUniversalTime(2026,11,30,18,30,0).UnixTimestamp},
    {id="SantaHat",label="Santa Hat",price=3500,
        start=DateTime.fromUniversalTime(2026,12,7,18,30,0).UnixTimestamp},
    {id="SnowScarf",label="Snow Scarf",price=4500,
        start=DateTime.fromUniversalTime(2026,12,14,18,30,0).UnixTimestamp},
    {id="FrostWings",label="Frost Wings",price=6000,
        start=DateTime.fromUniversalTime(2026,12,21,18,30,0).UnixTimestamp},
}
local connections={}
local attempts={}
local selected=nil
local pending=false
local lastAttempt=-math.huge
local alive=true
local confirmId=nil
local confirmUntil=0
local function safe(v,depth)
    local t=typeof(v);depth=depth or 0
    if t=="nil" then return "<nil>" end
    if t=="number" or t=="boolean" then return v end
    if t=="string" then return v:sub(1,800) end
    if t=="table" then
        if depth>2 then return "<nested>" end
        local out,n={},0
        for k,x in pairs(v) do
            n+=1
            if n>35 then out.__truncated=true break end
            local key=tostring(k):sub(1,100)
            if not key:lower():find("token",1,true)
                and not key:lower():find("secret",1,true) then
                out[key]=safe(x,depth+1)
            end
        end
        return out
    end
    return tostring(v):sub(1,350)
end
local function marketRemote()
    local folder=RS:FindFirstChild("FrostMarket")
    local buy=folder and folder:FindFirstChild("Buy")
    return buy and buy:IsA("RemoteFunction") and buy or nil
end
local screen=Instance.new("ScreenGui")
screen.Name="BeyyFrostMarketTester"
screen.ResetOnSpawn=false
screen.IgnoreGuiInset=true
screen.DisplayOrder=10001
screen.Parent=guiParent
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(440,369)
panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-14,0,24)
panel.BackgroundColor3=Color3.fromRGB(24,29,41)
panel.BorderSizePixel=0
panel.Parent=screen
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,10)
corner.Parent=panel
local function makeText(text,x,y,w,h,sz,bold)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Position=UDim2.fromOffset(x,y)
    t.Size=UDim2.fromOffset(w,h)
    t.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextColor3=Color3.fromRGB(235,240,250)
    t.TextSize=sz;t.TextWrapped=true
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.Text=text;t.Parent=panel
    return t
end
local function button(txt,x,y,w,h,bg)
    local b=Instance.new("TextButton")
    b.Text=txt;b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(w,h)
    b.Font=Enum.Font.GothamBold;b.TextSize=12
    b.TextColor3=Color3.new(1,1,1)
    b.BackgroundColor3=bg
    b.BorderSizePixel=0;b.Parent=panel
    local rounded=Instance.new("UICorner")
    rounded.CornerRadius=UDim.new(0,5);rounded.Parent=b
    return b
end
makeText("FROST MARKET · EARLY BUY TEST",12,9,400,24,15,true)
local close=button("X",408,9,22,22,Color3.fromRGB(113,52,57))
makeText("One normal server request per confirmed click. An accepted purchase may spend real Winter coins.",12,36,413,40,11,false)
local info=makeText("Choose an item below.",12,77,413,32,12,false)
local status=makeText("Server time: "..os.date("!%Y-%m-%d %H:%M UTC"),12,325,414,35,11,false)
local rowButtons={}
local function refresh()
    for i,item in ipairs(items) do
        local b=rowButtons[i]
        if b then
            local isSelected=selected==i
            b.Text=(isSelected and "[SELECTED] " or "")
                ..item.label.."  |  "..item.price.." coins"
            b.BackgroundColor3=isSelected
                and Color3.fromRGB(57,110,158)
                or Color3.fromRGB(57,68,86)
        end
    end
end
for i,item in ipairs(items) do
    local y=108+(i-1)*39
    local b=button("",12,y,416,33,Color3.fromRGB(57,68,86))
    rowButtons[i]=b
    connections[#connections+1]=b.Activated:Connect(function()
        if pending or not alive then return end
        selected=i
        confirmId=nil
        local delta=item.start-os.time()
        local release=delta>0 and "Not yet scheduled" or "Scheduled start passed"
        info.Text=item.label.." · "..release
        status.Text="Press the TEST SELECTED button twice to confirm spending."
        refresh()
    end)
end
refresh()
local testBtn=button("TEST SELECTED (DOUBLE CONFIRM)",12,306,416,18,
    Color3.fromRGB(33,124,90))
local function exportReport()
    if type(writefile)~="function" then return end
    if type(makefolder)=="function" then
        local ok,exists=true,false
        if type(isfolder)=="function" then
            ok,exists=pcall(isfolder,"BeyyHub")
        end
        if not ok or not exists then pcall(makefolder,"BeyyHub") end
    end
    local doc={
        marker="BEYY_FROST_MARKET_TEST_V1",
        placeId=game.PlaceId,
        timestampUtc=os.date("!%Y-%m-%dT%H:%M:%SZ"),
        purchases=attempts,
        note="Only one normal Buy:InvokeServer(itemId) per explicit test. Response is not proof of persistent ownership."
    }
    local ok,json=pcall(HS.JSONEncode,HS,doc)
    if ok then
        pcall(writefile,"BeyyHub/frost_market_test.json",json)
    end
end
connections[#connections+1]=testBtn.Activated:Connect(function()
    if not alive or pending then return end
    local item=items[selected or 0]
    if not item then
        status.Text="Select one of the five market items first."
        return
    end
    local now=os.clock()
    if confirmId~=item.id or now>confirmUntil then
        confirmId=item.id
        confirmUntil=now+9
        status.Text="CONFIRM: Click TEST again within 9 seconds. Could spend "..item.price.." Winter coins."
        return
    end
    if now-lastAttempt<5 then
        status.Text="Test cooldown: try again in a few seconds."
        return
    end
    local remote=marketRemote()
    if not remote then
        status.Text="FrostMarket.Buy RemoteFunction not found in this place."
        return
    end
    confirmId=nil
    lastAttempt=now
    pending=true
    testBtn.Text="WAITING FOR SERVER..."
    info.Text="Sending one Buy:InvokeServer("..item.id..") request."
    local coinsBefore=player:GetAttribute("WinterCoins")
    local startedUtc=os.date("!%Y-%m-%dT%H:%M:%SZ")
    task.spawn(function()
        -- The precise Buy protocol is not included in the replicated Config.
        -- This single identifier argument is a hypothesis, not a guarantee.
        local result=table.pack(pcall(function()
            return remote:InvokeServer(item.id)
        end))
        task.wait(0.4)
        local coinsAfter=player:GetAttribute("WinterCoins")
        local response={}
        for i=2,result.n do response[#response+1]=safe(result[i]) end
        local entry={
            itemId=item.id,itemPrice=item.price,
            scheduledStart=item.start,attemptUtc=startedUtc,
            clientBeforeSchedule=os.time()<item.start,
            callSucceeded=result[1]==true,
            serverResponse=response,
            coinsBefore=safe(coinsBefore),
            coinsAfter=safe(coinsAfter),
        }
        attempts[#attempts+1]=entry
        exportReport()
        print("[Beyy Frost Market Test] "..HS:JSONEncode(entry))
        if not alive then return end
        pending=false
        testBtn.Text="TEST SELECTED (DOUBLE CONFIRM)"
        info.Text="Request finished for "..item.label..
            ". View F9 console or frost_market_test.json for full response."
        local returned=#response>0 and tostring(response[1]) or "<no value>"
        status.Text=string.format("Call %s; result %s; coins %s -> %s",
            result[1] and "OK" or "ERROR",returned:sub(1,55),
            tostring(coinsBefore),tostring(coinsAfter))
    end)
end)
local function stop()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()screen:Destroy()end)
end
connections[#connections+1]=close.Activated:Connect(stop)
env.BeyyFrostMarketTesterStop=stop
print("[Beyy Frost Market Test] Ready. Select one item, then double-confirm. No automatic transactions.")
