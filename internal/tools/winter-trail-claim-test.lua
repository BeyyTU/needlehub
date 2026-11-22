-- BEYY_WINTER_TRAIL_CLAIM_TEST_V1
-- Manual, one-request-per-confirmation diagnostic for WinterTrail.Claim.
-- No automated claims, currency changes, game state edits or remote flooding.
-- Claiming may award a real reward. Inspect server response and inventory.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
local guiParent=player and player:WaitForChild("PlayerGui")
if not guiParent then warn("[Beyy Winter Trail] Local player GUI unavailable") return end

local env=_G
if type(getgenv)=="function" then
    local ok,result=pcall(getgenv)
    if ok and type(result)=="table" then env=result end
end
if type(env.BeyyWinterTrailTestStop)=="function" then
    pcall(env.BeyyWinterTrailTestStop)
end
local alive=true
local pending=false
local selectedDay=7
local withDayArgument=false
local confirmKey=nil
local confirmExpiry=0
local lastAttempt=-math.huge
local attempts={}
local connections={}
local days={
    "First Tracks","Snow Scout","Cold Snap",
    "Frostbite","Whiteout","Deep Winter","The Final Day"
}
local function remote()
    local folder=RS:FindFirstChild("WinterTrail")
    local claim=folder and folder:FindFirstChild("Claim")
    if claim and claim:IsA("RemoteFunction") then return claim end
    return nil
end
local function safe(x,depth,seen)
    local ty=typeof(x)
    depth=depth or 0
    if ty=="nil" then return "<nil>" end
    if ty=="string" then return x:sub(1,900) end
    if ty=="number" or ty=="boolean" then return x end
    if ty=="Instance" then return x:GetFullName() end
    if ty=="table" then
        if depth>=3 then return "<nested>" end
        seen=seen or {}
        if seen[x] then return "<cyclic>" end
        seen[x]=true
        local out,n={},0
        for k,v in pairs(x) do
            n+=1
            if n>75 then out.__truncated=true break end
            local key=tostring(k):sub(1,65)
            local lower=key:lower()
            if lower:find("token",1,true) or lower:find("cookie",1,true)
                or lower:find("secret",1,true)
                or lower:find("password",1,true) then
                out[key]="<redacted>"
            else
                local ok,item=pcall(safe,v,depth+1,seen)
                out[key]=ok and item or "<unavailable>"
            end
        end
        seen[x]=nil
        return out
    end
    return tostring(x):sub(1,280)
end
local function snapshot()
    local d={}
    for _,key in ipairs({"WinterCoins","WinterTrailDay",
        "WinterTrailDays","WinterChestCredits","YetiKingWins"}) do
        d[key]=safe(player:GetAttribute(key))
    end
    return d
end
local function save()
    if type(writefile)~="function" then return false end
    if type(makefolder)=="function" then
        local exists=false
        if type(isfolder)=="function" then
            local ok,v=pcall(isfolder,"BeyyHub")
            exists=ok and v==true
        end
        if not exists then pcall(makefolder,"BeyyHub") end
    end
    local ok,data=pcall(HS.JSONEncode,HS,{
        marker="BEYY_WINTER_TRAIL_CLAIM_TEST_V1",
        placeId=game.PlaceId,
        records=attempts,
        note="Only explicitly confirmed normal WinterTrail.Claim invocations. Nil attributes are not zero balances."
    })
    return ok and pcall(writefile,"BeyyHub/winter_trail_claim_test.json",data) or false
end

local ui=Instance.new("ScreenGui")
ui.Name="BeyyWinterTrailClaimTest"
ui.ResetOnSpawn=false
ui.IgnoreGuiInset=true
ui.DisplayOrder=10003
ui.Parent=guiParent
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(444,420)
panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-15,0,25)
panel.BorderSizePixel=0
panel.BackgroundColor3=Color3.fromRGB(25,30,43)
panel.Parent=ui
local corner=Instance.new("UICorner")
corner.CornerRadius=UDim.new(0,10);corner.Parent=panel
local function label(str,x,y,w,h,size)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Position=UDim2.fromOffset(x,y)
    t.Size=UDim2.fromOffset(w,h)
    t.Font=Enum.Font.Gotham
    t.TextSize=size or 12
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextWrapped=true
    t.TextColor3=Color3.fromRGB(235,240,250)
    t.Text=str
    t.Parent=panel
    return t
end
local function button(txt,x,y,w,h,color)
    local b=Instance.new("TextButton")
    b.Position=UDim2.fromOffset(x,y)
    b.Size=UDim2.fromOffset(w,h)
    b.BorderSizePixel=0
    b.BackgroundColor3=color
    b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold
    b.TextSize=12;b.Text=txt
    b.Parent=panel
    local round=Instance.new("UICorner")
    round.CornerRadius=UDim.new(0,6);round.Parent=b
    return b
end
label("WINTER TRAIL · CLAIM TEST",12,10,395,23,16)
local close=button("X",410,10,22,23,Color3.fromRGB(135,60,64))
label("Test the normal claim endpoint. If accepted, this may immediately claim a real reward.",12,40,420,34,11)
local details=label("Select a day. Default mode sends NO arguments.",12,78,420,30,12)
local dayButtons={}
for i,name in ipairs(days) do
    local row=math.floor((i-1)/2)
    local col=(i-1)%2
    local x=12+col*215
    local y=117+row*40
    local b=button("DAY "..i.." · "..name,x,y,202,34,Color3.fromRGB(57,70,90))
    dayButtons[i]=b
    connections[#connections+1]=b.Activated:Connect(function()
        if pending then return end
        selectedDay=i;confirmKey=nil
        details.Text="Selected day "..i.." ("..name..")"
        for j,v in ipairs(dayButtons) do
            v.BackgroundColor3=j==i and Color3.fromRGB(55,118,169)
                or Color3.fromRGB(57,70,90)
        end
    end)
end
dayButtons[selectedDay].BackgroundColor3=Color3.fromRGB(55,118,169)
local modeButton=button("MODE: NORMAL CLAIM (NO ARG)",12,283,420,34,Color3.fromRGB(66,77,107))
local testButton=button("TEST CLAIM · CONFIRM TWICE",12,325,420,35,Color3.fromRGB(37,132,95))
local status=label("Ready. Result will be saved in BeyyHub/winter_trail_claim_test.json.",12,368,420,44,11)
connections[#connections+1]=modeButton.Activated:Connect(function()
    if pending then return end
    withDayArgument=not withDayArgument
    confirmKey=nil
    modeButton.Text=withDayArgument
        and "MODE: EXPERIMENTAL CLAIM(DAY "..selectedDay..")"
        or "MODE: NORMAL CLAIM (NO ARG)"
    status.Text=withDayArgument and
        "Day parameter is an unverified protocol hypothesis. One manual request only."
        or "Normal claim attempt: no arguments (may claim next earned day)."
end)
local function invoke()
    if pending or not alive then return end
    local selected=days[selectedDay]
    local key=(withDayArgument and "day_" or "next_")..selectedDay
    local now=os.clock()
    if key~=confirmKey or now>confirmExpiry then
        confirmKey=key;confirmExpiry=now+10
        status.Text="CONFIRM by clicking again within 10 seconds. A real earned reward may be claimed."
        return
    end
    if now-lastAttempt<8 then
        status.Text="One-request throttle active. Try again after 8 seconds."
        return
    end
    local claim=remote()
    if not claim then
        status.Text="WinterTrail.Claim RemoteFunction missing in this place."
        return
    end
    confirmKey=nil;lastAttempt=now;pending=true
    testButton.Text="AWAITING SERVER..."
    local usingDayArg=withDayArgument
    local day=selectedDay
    local before=snapshot()
    local utc=os.date("!%Y-%m-%dT%H:%M:%SZ")
    details.Text="Requesting "..(usingDayArg and ("day "..day) or "normal next claim").."..."
    task.spawn(function()
        local response=table.pack(pcall(function()
            if usingDayArg then return claim:InvokeServer(day) end
            return claim:InvokeServer()
        end))
        task.wait(0.35)
        local values={}
        for i=2,response.n do values[#values+1]=safe(response[i]) end
        local entry={
            utc=utc,mode=usingDayArg and "experimental_day_argument" or "no_argument",
            selectedDay=day,selectedName=selected,
            transportOk=response[1]==true,
            response=values,
            before=before,after=snapshot(),
        }
        attempts[#attempts+1]=entry
        save()
        print("[Beyy Winter Trail Claim Test] "..HS:JSONEncode(entry))
        if not alive then return end
        pending=false
        testButton.Text="TEST CLAIM · CONFIRM TWICE"
        details.Text="Response received. Exported JSON; inspect F9 for details."
        local preview=values[1]
        if type(preview)=="table" then
            local ok,json=pcall(HS.JSONEncode,HS,preview)
            preview=ok and json or tostring(preview)
        end
        status.Text=(response[1] and "Call completed: " or "Call errored: ")
            ..tostring(preview or "<nil>"):sub(1,180)
    end)
end
connections[#connections+1]=testButton.Activated:Connect(invoke)
local function stop()
    alive=false
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    pcall(function()ui:Destroy()end)
end
connections[#connections+1]=close.Activated:Connect(stop)
env.BeyyWinterTrailTestStop=stop
print("[Beyy Winter Trail Claim] Ready. Manual testing only; no automatic requests.")
