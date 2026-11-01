-- BeyyHub Chapter 1 | Intro Skip + Cash Tool Upgrades standalone v1
-- Independent from loader.lua and BeyyHub Main. No farming/needle/replay workers.
-- Executor: Potassium and other Luau executors with game:HttpGet/loadstring.
if game.PlaceId ~= 108628039999641 then
    warn("[CH1 Skip+Upgrade] Only runs in Chapter 1 / Farmhouse.")
    return
end

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local VIM=game:GetService("VirtualInputManager")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end

-- OPTIONS: adjust before executing via getgenv().__BEYY_CH1_SKIP_UPGRADES_CONFIG.
-- By default, auto Skip and every cash tool upgrade are ON.
-- Set individual tracks to false to keep them off.
local defaults={
    UpgVacPower=true,UpgVacCooling=true,UpgVacRuntime=true,
    UpgTntPower=true,UpgTntLuck=true,UpgTntCooldown=true,
    UpgCapacity=true,
    UpgHandSpeed=true,UpgHandGrab=true,UpgHandHold=true,
    UpgPitchCooldown=true,UpgPitchHold=true,UpgPitchSweep=true,
    UpgDroneSpeed=true,UpgDroneGrab=true,UpgDroneCapacity=true
}
local cfg=env.__BEYY_CH1_SKIP_UPGRADES_CONFIG
if type(cfg)~="table" then cfg={} end
if cfg.AutoSkipIntro==nil then cfg.AutoSkipIntro=true end
if cfg.AutoUpgradeTools==nil then cfg.AutoUpgradeTools=true end
if type(cfg.Tracks)~="table" then cfg.Tracks={} end
for key,enabled in pairs(defaults) do
    if cfg.Tracks[key]==nil then cfg.Tracks[key]=enabled end
end
env.__BEYY_CH1_SKIP_UPGRADES_CONFIG=cfg

-- Re-executing this standalone stops only its prior instance.
-- Never overwrite the main hub's __BEYY_HUB_CLEANUP or loaded guard.
local prior=env.__BEYY_CH1_SKIP_UPGRADES_STOP
if type(prior)=="function" then pcall(prior) end
local active=true
local function stop()
    active=false
    if env.__BEYY_CH1_SKIP_UPGRADES_STOP==stop then
        env.__BEYY_CH1_SKIP_UPGRADES_STOP=nil
    end
    print("[CH1 Skip+Upgrade] Standalone stopped")
end
env.__BEYY_CH1_SKIP_UPGRADES_STOP=stop

local function isVisible(obj)
    if not obj then return false end
    local node=obj
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node:IsA("PlayerGui") then return true end
        node=node.Parent
    end
    return false
end
local function findOpeningSkip()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local fade=pg and pg:FindFirstChild("CutsceneFade")
    local container=fade and fade:FindFirstChild("SkipCutsceneButton")
    local native=container and container:FindFirstChild("Button")
    if native and native:IsA("GuiButton") and isVisible(native) then return native end
    if not fade then return nil end
    for _,obj in ipairs(fade:GetDescendants()) do
        if obj:IsA("GuiButton") and isVisible(obj) then
            local label=obj.Name:lower()
            if obj:IsA("TextButton") then label=label.." "..obj.Text:lower() end
            if (label:find("skip",1,true) or
                (obj.Parent and obj.Parent.Name:lower():find("skip",1,true)))
                and not label:find("lobby",1,true)
                and not label:find("replay",1,true) then
                return obj
            end
        end
    end
    return nil
end

local function endingStarted()
    return player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("IntroCutsceneFinished")==true
        or (function()
            local pg=player:FindFirstChildOfClass("PlayerGui")
            local ending=pg and pg:FindFirstChild("NeedleEndingUI")
            local results=ending and ending:FindFirstChild("ReturnToLobby",true)
            return results~=nil and isVisible(results)
        end)()
end

task.spawn(function()
    local began=os.clock()
    local seen=false
    local attempted=false
    local nextClick=0
    local attempts=0
    -- Only operate near script startup: never touch the ending's Skip button.
    while active and cfg.AutoSkipIntro and os.clock()-began<30 do
        task.wait(0.05)
        if endingStarted() then break end
        local button=findOpeningSkip()
        if not button then
            if seen and attempted then
                print("[CH1 Skip+Upgrade] Native opening Skip disappeared; complete")
                return
            end
            continue
        end
        seen=true
        local now=os.clock()
        if now<nextClick then continue end
        nextClick=now+0.35
        attempts+=1
        local pos,size=button.AbsolutePosition,button.AbsoluteSize
        if size.X<=0 or size.Y<=0 then continue end
        local inset=GuiService:GetGuiInset()
        local x,y=pos.X+size.X/2+inset.X,pos.Y+size.Y/2+inset.Y
        local pressed=false
        local ok,err=pcall(function()
            VIM:SendMouseMoveEvent(x,y,game)
            task.wait(0.025)
            if not active or endingStarted() then return end
            VIM:SendMouseButtonEvent(x,y,0,true,game,0)
            pressed=true
            task.wait(0.06)
        end)
        if pressed then pcall(function()
            VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        end) end
        local signalSent=false
        if type(firesignal)=="function" and active and not endingStarted() then
            signalSent=pcall(function()firesignal(button.Activated)end)
        end
        attempted=attempted or pressed or signalSent
        print(("[CH1 Skip+Upgrade] Intro Skip attempt=%d sent=%s signal=%s %s"):format(
            attempts,tostring(pressed),tostring(signalSent),not ok and tostring(err) or ""))
        if attempts>=12 then break end
    end
    if active and cfg.AutoSkipIntro then
        print("[CH1 Skip+Upgrade] Intro-only Skip scan completed (no ending action)")
    end
end)

local function cash()
    local stats=player:FindFirstChild("leaderstats")
    local value=stats and stats:FindFirstChild("Cash")
    return value and tonumber(value.Value) or 0
end

-- Verbatim Chapter 1 Main/Chapter 5 fast cash-upgrade scheduling logic.
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
        pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Started=os.clock(),Until=os.clock()+0.25}
        remote:FireServer(target.Name)
        if options.OnRequested then options.OnRequested(pending) end
        status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
    end
    return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
        local ok,err=pcall(tick)
        if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
    end}
end


local lastStatus,lastStatusAt="",-math.huge
local requests,confirmations=0,0
local engine=createAutoUpgradeRuntime({
    State=setmetatable({}, {__index=function(_,key)
        return active and cfg.AutoUpgradeTools==true and cfg.Tracks[key]==true
    end}),
    Player=player,
    Cash=cash,
    Folder=function() return RS:FindFirstChild("NeedleHaystack") end,
    Status=function(message)
        local now=os.clock()
        -- Keep the exact main upgrade cadence while avoiding cash-status spam.
        if message~=lastStatus and (now-lastStatusAt>=2 or
            message:find("error",1,true) or message:find("maxed",1,true)) then
            lastStatus=message;lastStatusAt=now
            print("[CH1 Skip+Upgrade] "..message)
        end
    end,
    OnRequested=function(pending)
        requests+=1
        if requests<=5 or requests%15==0 then
            print(("[CH1 Skip+Upgrade] Upgrade request #%d %s L%d->L%d cash=%.2f"):format(
                requests,pending.Name,pending.Level,pending.Level+1,cash()))
        end
    end,
    OnConfirmed=function(pending,current)
        confirmations+=math.max(0,current-pending.Level)
        print(("[CH1 Skip+Upgrade] CONFIRMED %s L%d->L%d in %.3fs"):format(
            pending.Name,pending.Level,current,os.clock()-pending.Started))
    end
})
print("[CH1 Skip+Upgrade] Standalone active: intro Skip="..
    tostring(cfg.AutoSkipIntro).." fast upgrades="..tostring(cfg.AutoUpgradeTools)..
    " (0.05s polling, 16 cash tracks by default; no farming/key/replay)")
task.spawn(function()
    while active do
        if cfg.AutoUpgradeTools then engine.Tick() end
        task.wait(0.05)
    end
end)
