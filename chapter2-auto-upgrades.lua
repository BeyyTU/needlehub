-- Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)
-- Chapter 2 no-levers standalone: only buy VacuumPower when affordable.
-- All other cash and permanent gem upgrade purchases are disabled.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local P=Players.LocalPlayer or Players.PlayerAdded:Wait()
if game.PlaceId~=83445806734780 or not P then return end
local env=_G
if type(getgenv)=="function" then
    local ok,g=pcall(getgenv)
    if ok and type(g)=="table" then env=g end
end
if type(env.__BEYY_CH2_AUTO_UPGRADES_STOP)=="function" then
    pcall(env.__BEYY_CH2_AUTO_UPGRADES_STOP,"Vacuum Power-only upgrade mode")
end
local alive=true
local started=os.clock()
local requests,confirmations=0,0
local lastStatus,lastError="starting",nil
local state={UpgVacPower=true}
local function log(message)
    print("[CH2 UPGRADES] "..tostring(message))
end
local function status(message)
    if message==lastStatus then return end
    lastStatus=message
    if message:find("error",1,true)
        or message:find("Waiting for upgrade config",1,true)
        or message:find("maxed or unavailable",1,true) then
        log(message)
    end
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
        local tracks = {{"UpgVacPower","VacuumPower"}}
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
            pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Cost=target.Cost,Started=os.clock(),Until=os.clock()+0.05}
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
    return table.concat({
        "CHAPTER 2 STANDALONE AUTO-UPGRADES v27",
        "Mode: VACUUM POWER ONLY",
        "Other cash upgrades: DISABLED",
        "Permanent gem upgrades: DISABLED",
        "VacuumPower requests / confirmations: "..requests.." / "..confirmations,
        "Cash balance: "..tostring(cash()),
        "Current VacuumPower level: "..
            tostring(P:GetAttribute("HayUpgradeVacuumPower")),
        "Status: "..tostring(lastStatus),
        "Error: "..tostring(lastError or "none"),
        "Worker alive: "..tostring(alive),
        "Elapsed: "..string.format("%.2fs",os.clock()-started),
    },"\n")
end
local function stop(reason)
    if not alive then return end
    alive=false
    log("Stopped: "..tostring(reason))
end
env.__BEYY_CH2_AUTO_UPGRADES_STOP=stop
env.__BEYY_CH2_AUTO_UPGRADES_REPORT=report
log("VacuumPower ONLY: checking affordability every 0.05s; purchase confirmation 0.05s")
local runtime=createAutoUpgradeRuntime({
    State=state,Player=P,Folder=needleFolder,Cash=cash,
    Status=status,
    OnRequested=function(pending)
        requests+=1
        if requests<=3 then
            log(string.format("Requested VacuumPower L%d ($%.2f)",
                pending.Level+1,pending.Cost))
        end
    end,
    OnConfirmed=function(pending,current)
        confirmations+=1
        log(string.format("VacuumPower L%d -> L%d confirmed in %.3fs",
            pending.Level,current,os.clock()-pending.Started))
    end,
})
task.spawn(function()
    while alive do
        runtime.Tick()
        task.wait(0.05)
    end
end)
