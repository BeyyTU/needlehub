-- Beyy Chapter 2 Auto Upgrades v26
-- Isolated cash 0.05s check/confirmation and opt-in permanent gem upgrades.
-- Chapter 2 no-levers standalone upgrades, isolated compilation unit.
-- Cash priorities and 0.05s server-confirmation come from BeyyHub Main.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local P=Players.LocalPlayer or Players.PlayerAdded:Wait()
if game.PlaceId~=83445806734780 or not P then return end
local env=_G
if type(getgenv)=="function" then
    local ok,g=pcall(getgenv)
    if ok and type(g)=="table" then env=g end
end
if type(env.__BEYY_CH2_AUTO_UPGRADES_STOP)=="function" then
    pcall(env.__BEYY_CH2_AUTO_UPGRADES_STOP,"reloaded")
end
local alive=true
local createdAt=os.clock()
local cashRequests,cashConfirmed,gemRequests,gemConfirmed=0,0,0,0
local lastStatus,lastError="starting",nil
local settingsOrigin="standalone defaults"
local pendingGem={}
local cashFlags={
    "UpgVacPower","UpgVacCooling","UpgVacRuntime",
    "UpgTntPower","UpgTntLuck","UpgTntCooldown",
    "UpgCapacity","UpgHandSpeed","UpgHandGrab","UpgHandHold",
    "UpgPitchCooldown","UpgPitchHold","UpgPitchSweep",
    "UpgDroneSpeed","UpgDroneGrab","UpgDroneCapacity",
}
-- When Main saved settings are available, reuse its enabled selections.
-- For a clean standalone setup: enable cash tracks except Vacuum Cooling.
local defaults={
    UpgVacPower=true,UpgVacCooling=false,UpgVacRuntime=true,
    UpgTntPower=true,UpgTntLuck=true,UpgTntCooldown=true,
    UpgCapacity=true,UpgHandSpeed=true,UpgHandGrab=true,UpgHandHold=true,
    UpgPitchCooldown=true,UpgPitchHold=true,UpgPitchSweep=true,
    UpgDroneSpeed=true,UpgDroneGrab=true,UpgDroneCapacity=true,
    UpgBagSize=false,UpgExtraTake=false,UpgGemValue=false,UpgHayValue=false,
}
local state={}
for k,v in pairs(defaults) do state[k]=v end
local function accept(source)
    if type(source)~="table" then return false end
    source=source.__elements or source
    if type(source)~="table" then return false end
    local found=false
    for k in pairs(defaults) do
        local value=source[k]
        if type(value)=="table" and value.__type then value=value.value end
        if type(value)=="boolean" then
            state[k]=value
            found=true
        end
    end
    return found
end
if type(readfile)=="function" then
    local ok,raw=pcall(readfile,"BeyyHub/farming_inventory_shared.json")
    if ok and type(raw)=="string" then
        local decoded,data=pcall(function()return HttpService:JSONDecode(raw)end)
        if decoded and accept(data) then settingsOrigin="saved Main settings" end
    end
end
local tok,ts=pcall(function()
    return TeleportService:GetTeleportSetting("BeyyHub_FarmTools_v103")
end)
if tok and accept(ts) then settingsOrigin="Main teleport settings" end
if type(env.__BEYY_CH2_UPGRADE_FLAGS)=="table" and
    accept(env.__BEYY_CH2_UPGRADE_FLAGS) then settingsOrigin="standalone override" end
-- Explicitly requested standalone auto-upgrades: if a stale saved Main
-- configuration has every cash toggle off, use the standalone cash defaults.
-- Never auto-enable permanent gem spending in this fallback.
local selectedCash=0
for _,flag in ipairs({
    "UpgVacPower","UpgVacCooling","UpgVacRuntime",
    "UpgTntPower","UpgTntLuck","UpgTntCooldown",
    "UpgCapacity","UpgHandSpeed","UpgHandGrab","UpgHandHold",
    "UpgPitchCooldown","UpgPitchHold","UpgPitchSweep",
    "UpgDroneSpeed","UpgDroneGrab","UpgDroneCapacity"
}) do
    if state[flag] then selectedCash+=1 end
end
if selectedCash==0 then
    for _,flag in ipairs(cashFlags) do state[flag]=defaults[flag] end
    settingsOrigin=settingsOrigin.." (cash toggles all off: standalone fallback enabled)"
end
local function log(message) print("[CH2 UPGRADES] "..tostring(message)) end
local function status(message)
    if lastStatus==message then return end
    lastStatus=message
    if message:find("error",1,true) or message:find("Waiting for upgrade config",1,true)
        or message:find("No cash upgrades enabled",1,true) then log(message) end
end
local function needleFolder()
    return ReplicatedStorage:FindFirstChild("NeedleHaystack")
end
local function cash()
    local ls=P:FindFirstChild("leaderstats")
    local value=ls and ls:FindFirstChild("Cash")
    return value and tonumber(value.Value) or 0
end
    local function createAutoUpgradeRuntime(options)
        local config, configModule, pending
        local idle,waitKey=true,"upgrades"
        local tracks = {
            {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
            {"UpgVacRuntime","VacuumRuntime"},
            {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
            {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
            {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
            {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
            {"UpgTntCooldown","TntCooldown"},
        }
        local lastStatus
        local function status(text)
            if text~=lastStatus then lastStatus=text;options.Status(text) end
        end
        local function level(name) return tonumber(options.Player:GetAttribute("HayUpgrade"..name)) or 1 end
        local function cost(name, entry)
            local price=tonumber(entry.Cost)
            if not price or price<0 or price~=price or price==math.huge then return nil end
            price*=tonumber(options.Player:GetAttribute("UpgradeCostMultiplier")) or 1
            if name:sub(1,9)=="Pitchfork" then price*=tonumber(options.Player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
            return math.round(price*100)/100
        end
        local function tick()
            idle,waitKey=true,"upgrades"
            local folder=options.Folder()
            local module=folder and folder:FindFirstChild("Config")
            local remote=folder and folder:FindFirstChild("BuyUpgrade")
            if not module or not remote or not remote:IsA("RemoteEvent") then status("Waiting for upgrade config / remote"); return end
            if configModule~=module or not config then
                local loaded=require(module)
                assert(type(loaded)=="table" and type(loaded.UPGRADE_TRACKS)=="table","Invalid upgrade config")
                config,configModule=loaded,module
                if options.OnConfig then options.OnConfig(loaded) end
            end
            if pending then
                idle=false
                local confirmedLevel=level(pending.Name)
                if confirmedLevel~=pending.Level or not options.State[pending.Flag] then
                    if confirmedLevel>pending.Level and options.OnConfirmed then options.OnConfirmed(pending,confirmedLevel) end
                    pending=nil
                elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
                else
                    status("Server did not confirm "..pending.Name.."; retrying")
                    pending=nil
                end
            end
            local cash=tonumber(options.Cash()) or 0
            local selected, available, vacuum, power, earlyTnt, lateTnt=0,{},nil,nil,nil,nil
            for _,entry in ipairs(tracks) do
                if options.State[entry[1]] then
                    selected+=1
                    local track=config.UPGRADE_TRACKS[entry[2]]
                    local current=level(entry[2])
                    local nextLevel=track and track.Levels and track.Levels[current+1]
                    local price=nextLevel and cost(entry[2],nextLevel)
                    if price then
                        local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                        if entry[2]=="TntCooldown" then
                            -- Tracks start at L1: two purchases reach L3.
                            if current<3 then earlyTnt=target else lateTnt=target end
                        else
                            available[#available+1]=target
                        end
                        if entry[2]=="VacuumPower" then power=target end
                        if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                    end
                end
            end
            if selected==0 then status("No cash upgrades enabled"); return end
            if #available==0 and not earlyTnt and not lateTnt then status("Selected cash upgrades are maxed or unavailable"); return end
            local target
            if earlyTnt then
                if cash<earlyTnt.Cost then waitKey="upgrades-cash";status(string.format("Saving for TntCooldown: $%.2f / $%.2f",cash,earlyTnt.Cost)); return end
                target=earlyTnt
            elseif power then
                if cash<power.Cost then waitKey="upgrades-cash";status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
                target=power
            elseif vacuum and cash>=vacuum.Cost*0.75 then
                if cash<vacuum.Cost then waitKey="upgrades-cash";status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
                target=vacuum
            else
                for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
                -- Remaining TNT speed levels wait until all other enabled tracks finish.
                if #available==0 and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
            end
            if not target then
                waitKey="upgrades-cash"
                local cheapest=available[1] or lateTnt
                for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
                status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
            end
            idle=false
            -- Reserve before sending: replication may confirm the purchase immediately.
            pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Started=os.clock(),Until=os.clock()+0.05}
            remote:FireServer(target.Name)
            if options.OnRequested then options.OnRequested(pending) end
            status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
        end
        return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
            local ok,err=pcall(tick)
            if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
        end}
    end
    
    
    

local function report()
    local active={}
    for _,name in ipairs(cashFlags) do if state[name] then active[#active+1]=name end end
    return table.concat({
        "CHAPTER 2 STANDALONE AUTO-UPGRADES v26",
        "Enabled cash: "..table.concat(active,", "),
        "Settings source: "..settingsOrigin,
        "Cash requests / confirmations: "..cashRequests.." / "..cashConfirmed,
        "Permanent requests / confirmations: "..gemRequests.." / "..gemConfirmed,
        "Cash balance: "..tostring(cash()),
        "Status: "..tostring(lastStatus),
        "Error: "..tostring(lastError or "none"),
        "Worker alive: "..tostring(alive),
        "Elapsed: "..string.format("%.2fs",os.clock()-createdAt),
    },"\n")
end
local function stop(reason)
    if not alive then return end
    alive=false
    log("Worker stopped: "..tostring(reason))
end
env.__BEYY_CH2_AUTO_UPGRADES_STOP=stop
env.__BEYY_CH2_AUTO_UPGRADES_REPORT=report
local numCash=0
for _,name in ipairs(cashFlags) do if state[name] then numCash+=1 end end
log(string.format("Running (%d cash tracks, Cooling=%s); %s; cash tick/confirmation 0.05s",
    numCash,tostring(state.UpgVacCooling),settingsOrigin))
local runtime=createAutoUpgradeRuntime({
    State=state,Player=P,Folder=needleFolder,Cash=cash,
    Status=status,
    OnRequested=function()cashRequests+=1 end,
    OnConfirmed=function(pending,current)
        cashConfirmed+=1
        log(string.format("Cash %s L%d->L%d confirmed in %.3fs",
            pending.Name,pending.Level,current,os.clock()-pending.Started))
    end,
})
task.spawn(function()
    while alive do
        runtime.Tick()
        task.wait(0.05)
    end
end)
local gemNames={
    UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
    UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage",
}
local gemConfig=nil
local function tickGem(key,name)
    if not state[key] then return end
    if not gemConfig then
        local sh=ReplicatedStorage:FindFirstChild("Shared")
        local configs=sh and sh:FindFirstChild("Configs")
        local module=configs and configs:FindFirstChild("UpgradeConfig")
        if not module then return end
        local ok,c=pcall(require,module)
        if not ok then lastError=tostring(c);return end
        gemConfig=c
    end
    local ok,upgrade=pcall(function()return gemConfig.getUpgrade(name)end)
    if not ok or not upgrade then return end
    local level=tonumber(P:GetAttribute("Upgrade"..name)) or 0
    local last=pendingGem[name]
    if last and last.Level~=level then
        if level>last.Level then
            gemConfirmed+=1
            log(string.format("Permanent %s L%d->L%d confirmed in %.3fs",
                name,last.Level,level,os.clock()-last.At))
        end
        pendingGem[name]=nil
        last=nil
    end
    local mOk,maxLevel=pcall(function()return gemConfig:getMaxLevel(upgrade)end)
    if not mOk or type(maxLevel)~="number" or level>=maxLevel then return end
    local pOk,price=pcall(function()return gemConfig:getPrice(upgrade,level)end)
    if not pOk or type(price)~="number"
        or (tonumber(P:GetAttribute("Gems")) or 0)<price then return end
    if last and os.clock()-last.At<0.25 then return end
    local f=needleFolder()
    local remote=f and f:FindFirstChild("BuyUpgrade")
    if not (remote and remote:IsA("RemoteEvent")) then return end
    pendingGem[name]={Level=level,At=os.clock()}
    local sent,err=pcall(function()remote:FireServer(name)end)
    if sent then gemRequests+=1 else lastError=tostring(err);pendingGem[name]=nil end
end
task.spawn(function()
    while alive do
        task.wait(0.5)
        if not alive then break end
        for flag,name in pairs(gemNames) do
            local ok,err=pcall(tickGem,flag,name)
            if not ok then lastError=tostring(err);log("Gem upgrade error: "..lastError) end
        end
    end
end)
