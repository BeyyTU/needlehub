-- BeyyHub Sell Fries | optional game-specific enhancements v0.2.0
-- Readable original implementation, inspired by public game names/paths.
-- WARNING: feature requests are not proof that the server accepted the action.
return function(ctx)
    local state, window, config = ctx.state, ctx.window, ctx.config
    local player, notify, log, on = ctx.player, ctx.notify, ctx.log, ctx.on
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local UIS = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local gui = window.Gui
    local settings = {
        FarmPileCrate=false, ReturnAfterFarm=false, AutoPower=false,
        AutoShutter=false, ReopenShutter=true, AutoPads=false, Radar=false,
        Fullbright=false, InfiniteJump=false, Noclip=false, InstantPeel=false
    }
    state.ExtrasStatus="Installed; awaiting in-game checks"
    state.ExtrasStats={FarmRequests=0, CrateRequests=0, PowerRequests=0,
        ShutterRequests=0, PadTouches=0, FarmConfirmed=0, MissingUpvalues=0, LastAction="Idle"}
    local stats=state.ExtrasStats
    local remotes=ReplicatedStorage:FindFirstChild("Remotes")
    local shutdown=false
    local busy=false
    local initialLighting={
        Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, GlobalShadows=Lighting.GlobalShadows
    }
    local oldCollisions=setmetatable({},{__mode="k"})
    local radarInstances={}
    local lastShutter=0
    local shutterOwned=false
    local nextPower=0
    local nextPad=0
    local nextFarm=0
    local lastMissingLog=0
    local oldPeel
    local sharedStats
    local root
    local lastCarKey=""
    local pileModule
    local function isActive(flag)
        return state.Running and not shutdown and not state.Paused and settings[flag]
    end
    local function remote(name)
        local folder=ReplicatedStorage:FindFirstChild("Remotes")
        local r=folder and folder:FindFirstChild(name)
        return r and r:IsA("RemoteEvent") and r or nil
    end
    local function characterRoot()
        local char=player.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end
    local function goTo(position, returnTo)
        local hrp=characterRoot()
        if not hrp then return nil end
        local old=hrp.CFrame
        if (hrp.Position-position).Magnitude > 10 then
            hrp.CFrame=CFrame.new(position+Vector3.new(0,2.5,0))
            task.wait(0.10)
        end
        return returnTo and old or false
    end
    local function comeBack(old)
        local hrp=characterRoot()
        if old and hrp and state.Running then hrp.CFrame=old end
    end
    local function send(r,...)
        if not r then return false end
        local ok,err=pcall(function(...)r:FireServer(...)end,...)
        if not ok then log("RemoteError",tostring(err):sub(1,150)) end
        return ok
    end
    local function updateAction(t)
        stats.LastAction=t
    end
    local function getUpvalue(fn,index)
        if type(fn)~="function" then return nil end
        local d=debug
        if not d or type(d.getupvalue)~="function" then return nil end
        local ok,a,b=pcall(d.getupvalue,fn,index)
        if not ok then return nil end
        if type(b)=="table" or type(b)=="function" then return b end
        if type(a)=="table" or type(a)=="function" then return a end
        return nil
    end
    local function scanState(fn)
        if type(fn)~="function" then return nil end
        for i=1,16 do
            local up=getUpvalue(fn,i)
            if type(up)=="table" then
                if type(up.partCell)=="table" then return up end
                for _,sub in pairs(up) do
                    if type(sub)=="table" and type(sub.partCell)=="table" then return sub end
                end
            elseif type(up)=="function" then
                for j=1,10 do
                    local nested=getUpvalue(up,j)
                    if type(nested)=="table" and type(nested.partCell)=="table" then return nested end
                end
            end
        end
        return nil
    end
    local function getPileState()
        if pileModule==false then return nil end
        if not pileModule then
            local scripts=player:FindFirstChild("PlayerScripts")
            local controllers=scripts and scripts:FindFirstChild("Controllers")
            local module=controllers and controllers:FindFirstChild("PileController")
            if not module or not module:IsA("ModuleScript") then return nil end
            local ok,p=pcall(require,module)
            if not ok or type(p)~="table" then return nil end
            pileModule=p
        end
        if pileModule then
            return scanState(pileModule.clickAtScreen)
        end
        return nil
    end
    local function topPotato()
        local pileState=getPileState()
        if not pileState then return nil end
        local heights=type(pileState.heights)=="table" and pileState.heights or nil
        local packKey=type(pileState.packKey)=="function" and pileState.packKey or nil
        local best,bestCell,bestTex
        local bestScore=-math.huge
        local seen=0
        for part,cell in pairs(pileState.partCell) do
            seen=seen+1
            if seen>6000 then break end
            if typeof(part)=="Instance" and part:IsA("BasePart") and part.Parent
                and type(cell)=="table" and type(cell[1])=="number" and type(cell[2])=="number"
                and type(cell[3])=="number" then
                local score=part.Position.Y
                local valid=true
                if heights and packKey then
                    local ok,key=pcall(packKey,cell[1],cell[3])
                    local columnH=ok and heights[key] or nil
                    if type(columnH)=="number" then
                        valid=(cell[2]==columnH-1)
                    end
                end
                if valid and score>bestScore then
                    best,bestCell,bestTex=part,cell,
                        (pileState.partTexture and pileState.partTexture[part]) or 1
                    bestScore=score
                end
            end
        end
        return best,bestCell,bestTex
    end
    local function carryInfo()
        local count=tonumber(player:GetAttribute("CarryCount")) or 0
        local raw=tonumber(player:GetAttribute("CarryRaw")) or 0
        local cap=tonumber(player:GetAttribute("CarryCapacity"))
        if not cap then
            local scripts=ReplicatedStorage:FindFirstChild("Shared")
            local statsModule=scripts and scripts:FindFirstChild("Stats")
            if statsModule and statsModule:IsA("ModuleScript") then
                local ok,s=pcall(require,statsModule)
                if ok and type(s)=="table" and type(s.carryCapacity)=="function" then
                    local ok2,n=pcall(s.carryCapacity,player)
                    if ok2 and type(n)=="number" then cap=n end
                end
            end
        end
        return count,raw,math.clamp(cap or 3,1,200)
    end
    local pilePos=Vector3.new(104.7,4,17)
    local cratePos=Vector3.new(52.9,4,19.5)
    local powerPos=Vector3.new(14.1,4.6,36.3)
    local shutterPos=Vector3.new(18.1,4,28.7)
    local function scoopOne()
        local r=remote("RemovePotato")
        if not r then updateAction("RemovePotato remote not found");return false end
        if player:GetAttribute("PotatoBusy")==true then return false end
        local part,cell,texture=topPotato()
        if not part then
            stats.MissingUpvalues=stats.MissingUpvalues+1
            if os.clock()-lastMissingLog>30 then
                lastMissingLog=os.clock()
                log("Farm","PileController cell data unavailable; not sending fabricated coordinates")
            end
            updateAction("Waiting for real pile cells")
            return false
        end
        local old=goTo(part.Position,settings.ReturnAfterFarm)
        if old==nil then return false end
        if not isActive("FarmPileCrate") and not state._forceScoop then
            comeBack(old);return false
        end
        local before=tonumber(player:GetAttribute("CarryCount")) or 0
        local ok=send(r,cell[1],cell[2],cell[3],texture)
        if ok then
            stats.FarmRequests=stats.FarmRequests+1
            updateAction("Potato scoop request sent")
            task.wait(0.16)
            local after=tonumber(player:GetAttribute("CarryCount")) or 0
            if after>before then stats.FarmConfirmed=stats.FarmConfirmed+1 end
        end
        comeBack(old)
        return ok
    end
    local function deposit()
        local r=remote("CratePut")
        if not r then updateAction("CratePut remote not found");return false end
        local count=tonumber(player:GetAttribute("CarryCount")) or 0
        if count<1 then return false end
        local old=goTo(cratePos,settings.ReturnAfterFarm)
        if old==nil then return false end
        local ok=send(r)
        if ok then
            stats.CrateRequests=stats.CrateRequests+1
            updateAction("Crate deposit request sent")
        end
        task.wait(0.15)
        comeBack(old)
        return ok
    end
    local function runFarm()
        if busy then return end
        busy=true
        local ok,err=pcall(function()
            local carry,raw,cap=carryInfo()
            if carry>=cap or (carry>0 and raw>99) then deposit()
            else scoopOne() end
        end)
        if not ok then log("FarmError",tostring(err)) end
        busy=false
    end
    local function powerBroken()
        local boxes=Workspace:FindFirstChild("PowerBoxes")
        local box=boxes and boxes:FindFirstChild("PowerBox1")
        if not box then return nil end
        return box:GetAttribute("PowerBroken")==true and box or nil
    end
    local function fixPower()
        if busy then return end
        local box=powerBroken()
        if not box then return end
        local r=remote("PowerCable")
        if not r then updateAction("PowerCable remote not found");return end
        busy=true
        local ok,err=pcall(function()
            local old=goTo(powerPos,settings.ReturnAfterFarm)
            local prompt=box:FindFirstChildWhichIsA("ProximityPrompt",true)
            if prompt and type(fireproximityprompt)=="function" then
                pcall(fireproximityprompt,prompt)
                task.wait(0.12)
            end
            for i=1,6 do
                if not isActive("AutoPower") then break end
                send(r,box,"Plug",i)
                stats.PowerRequests=stats.PowerRequests+1
                task.wait(0.06)
            end
            if isActive("AutoPower") then send(r,box,"Close") end
            task.wait(0.18)
            comeBack(old)
            updateAction("Power cable repair requests sent; verify PowerBroken")
        end)
        if not ok then log("PowerError",tostring(err))end
        busy=false
        nextPower=os.clock()+5
    end
    local function anomalyKind()
        local dt=Workspace:FindFirstChild("DriveThru")
        if not dt then return false,"No drive-thru" end
        local car=dt:FindFirstChild("Car")
        local carWaiting=dt:GetAttribute("CarWaiting")==true
        if not carWaiting or not car then return false,"No car" end
        local kind=car:GetAttribute("Anomaly")
        local traits=car:GetAttribute("AnomalyTraits")
        local forced=car:GetAttribute("AnomalyForced")
        local patience=dt:GetAttribute("PatienceKind")
        local suspicious=forced==true or patience=="Possessed"
            or (kind~=nil and tostring(kind)~="" and tostring(kind)~="None")
            or (traits~=nil and tostring(traits)~="" and tostring(traits)~="None")
        return suspicious,suspicious and tostring(kind or traits or patience or "Forced") or "Normal"
    end
    local function shutterClosed()
        local dt=Workspace:FindFirstChild("DriveThru")
        local sh=dt and dt:FindFirstChild("Shutter")
        return sh and (sh:GetAttribute("ShutterClosed")==true or sh:GetAttribute("ShutterTo")==1) or false
    end
    local function shutterToggle()
        local r=remote("ShutterPress")
        if not r then updateAction("ShutterPress remote not found");return false end
        local old=goTo(shutterPos,settings.ReturnAfterFarm)
        if old==nil then return false end
        local ok=send(r)
        if ok then
            stats.ShutterRequests=stats.ShutterRequests+1
            updateAction("Shutter toggle request sent")
        end
        task.wait(0.14)
        comeBack(old)
        return ok
    end
    local function checkShutter()
        local suspect,kind=anomalyKind()
        local closed=shutterClosed()
        if suspect and not closed then
            if shutterToggle() then shutterOwned=true; log("Threat","Shutter-close request: "..kind) end
            lastShutter=os.clock()+3
        elseif not suspect and closed and shutterOwned and settings.ReopenShutter then
            if shutterToggle() then shutterOwned=false;log("Threat","Shutter-reopen request") end
            lastShutter=os.clock()+3
        end
    end
    local function buyPads()
        local tycoon=Workspace:FindFirstChild("Tycoon")
        local pads=tycoon and tycoon:FindFirstChild("Pads")
        local root=characterRoot()
        if not pads or not root then return end
        local sent=0
        for _,pad in ipairs(pads:GetChildren()) do
            if not isActive("AutoPads") then break end
            local trigger=pad:FindFirstChild("Trigger")
            if trigger and trigger:IsA("BasePart") and trigger.Parent then
                if type(firetouchinterest)=="function" then
                    local ok=pcall(function()
                        firetouchinterest(root,trigger,0)
                        task.wait(0.04)
                        firetouchinterest(root,trigger,1)
                    end)
                    if ok then
                        stats.PadTouches=stats.PadTouches+1
                        sent=sent+1
                    end
                end
            end
            if sent>=3 then break end
        end
        if sent>0 then updateAction("Tycoon purchase pad contacts: "..sent)end
    end
    local function radarCarKey()
        local suspect,kind=anomalyKind()
        return (suspect and "Threat: " or "Drive-thru: ")..kind
    end
    local function clearRadar()
        for target,items in pairs(radarInstances) do
            if items.Highlight then items.Highlight:Destroy() end
            if items.Billboard then items.Billboard:Destroy() end
            radarInstances[target]=nil
        end
    end
    local function carThreat(car)
        local kind=car:GetAttribute("Anomaly")
        local traits=car:GetAttribute("AnomalyTraits")
        return car:GetAttribute("AnomalyForced")==true
            or (kind~=nil and tostring(kind)~="" and tostring(kind)~="None")
            or (traits~=nil and tostring(traits)~="" and tostring(traits)~="None")
    end
    local function updateCarESP(car)
        if not car or not car:IsA("Model") or not car.Parent then return end
        local suspect=carThreat(car)
        local existing=radarInstances[car]
        if not existing then
            local hilite=Instance.new("Highlight")
            hilite.Name="BeyyFriesAnomalyESP"
            hilite.Adornee=car
            hilite.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            hilite.FillTransparency=0.55
            hilite.OutlineTransparency=0.05
            hilite.Parent=gui
            local part=car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart",true)
            local billboard
            if part then
                billboard=Instance.new("BillboardGui")
                billboard.Name="BeyyFriesCarTag"
                billboard.Adornee=part
                billboard.Size=UDim2.fromOffset(180,42)
                billboard.StudsOffsetWorldSpace=Vector3.new(0,4,0)
                billboard.AlwaysOnTop=true
                billboard.Parent=gui
                local text=Instance.new("TextLabel")
                text.Name="Label"
                text.Size=UDim2.fromScale(1,1)
                text.BackgroundTransparency=1
                text.TextScaled=true
                text.TextStrokeTransparency=0.3
                text.TextColor3=Color3.new(1,1,1)
                text.Parent=billboard
            end
            existing={Highlight=hilite,Billboard=billboard}
            radarInstances[car]=existing
        end
        existing.Highlight.FillColor=suspect and Color3.fromRGB(230,50,48) or Color3.fromRGB(55,210,120)
        existing.Highlight.OutlineColor=suspect and Color3.fromRGB(255,185,185) or Color3.fromRGB(160,255,195)
        if existing.Billboard then
            local l=existing.Billboard:FindFirstChild("Label")
            local hrp=characterRoot()
            local part=car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart",true)
            local d=part and hrp and math.floor((part.Position-hrp.Position).Magnitude) or -1
            if l then l.Text=(suspect and "ANOMALY" or "Customer")..(d>=0 and (" | "..d.." studs") or "") end
        end
    end
    local function scanRadar()
        local active={}
        local traffic=Workspace:FindFirstChild("Traffic")
        if traffic then
            for _,car in ipairs(traffic:GetChildren())do
                if car:IsA("Model") then active[car]=true; updateCarESP(car) end
            end
        end
        local dt=Workspace:FindFirstChild("DriveThru")
        local car=dt and dt:FindFirstChild("Car")
        if car and car:IsA("Model") then active[car]=true;updateCarESP(car) end
        for target,items in pairs(radarInstances)do
            if not active[target] or not target.Parent then
                if items.Highlight then items.Highlight:Destroy()end
                if items.Billboard then items.Billboard:Destroy()end
                radarInstances[target]=nil
            end
        end
    end
    local function setFullbright(enabled)
        if enabled then
            Lighting.Ambient=Color3.new(1,1,1)
            Lighting.OutdoorAmbient=Color3.new(1,1,1)
            Lighting.Brightness=3
            Lighting.ClockTime=14
            Lighting.FogEnd=100000
            Lighting.GlobalShadows=false
        else
            for k,v in pairs(initialLighting)do
                pcall(function()Lighting[k]=v end)
            end
        end
    end
    local function setInstantPeel(v)
        if not sharedStats then
            local shared=ReplicatedStorage:FindFirstChild("Shared")
            local statsModule=shared and shared:FindFirstChild("Stats")
            if statsModule and statsModule:IsA("ModuleScript") then
                local ok,m=pcall(require,statsModule)
                if ok and type(m)=="table" then sharedStats=m end
            end
        end
        if not sharedStats or type(sharedStats.instantPeel)~="function" then
            updateAction("Instant peel local API unavailable")
            return false
        end
        if v then
            if not oldPeel then oldPeel=sharedStats.instantPeel end
            sharedStats.instantPeel=function()return true end
            updateAction("Local instant-peel flag enabled (server may enforce unlock)")
        elseif oldPeel then
            sharedStats.instantPeel=oldPeel
            oldPeel=nil
            updateAction("Original client instant-peel function restored")
        end
        return true
    end
    local function setNoclip(enabled)
        if enabled then return end
        for part,original in pairs(oldCollisions) do
            if part and part.Parent then pcall(function()part.CanCollide=original end)end
            oldCollisions[part]=nil
        end
    end
    on(UIS.JumpRequest,function()
        if isActive("InfiniteJump") then
            local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    on(RunService.Stepped,function()
        if not isActive("Noclip") then return end
        local char=player.Character
        if not char then return end
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                if oldCollisions[part]==nil then oldCollisions[part]=true end
                part.CanCollide=false
            end
        end
    end)
    local function addToggle(tab,title,key,desc,changed)
        local toggle=tab:Toggle({Title=title,Value=settings[key],Callback=function(v)
            settings[key]=v
            if changed then changed(v) end
            log("FriesExtras",title.."="..tostring(v))
        end})
        config:Register("Extras_"..key,toggle)
        return toggle
    end
    local kitchen=window:Tab({Title="Fries Farming"})
    kitchen:Section({Title="Potato supply automation"})
    addToggle(kitchen,"Auto potato pile -> crate","FarmPileCrate")
    addToggle(kitchen,"Return after farm actions","ReturnAfterFarm")
    kitchen:Button({Title="Collect one real pile cell",Callback=function()
        if busy then return end
        state._forceScoop=true
        local ok,err=pcall(scoopOne)
        state._forceScoop=false
        notify("Farm",ok and "Pickup request attempted; check carry count" or tostring(err))
    end})
    kitchen:Button({Title="Deposit carried potatoes",Callback=function()
        local ok,err=pcall(deposit)
        notify("Crate",ok and "Deposit request attempted" or tostring(err))
    end})
    addToggle(kitchen,"Instant peel client flag (experimental)","InstantPeel",nil,function(v)
        if not setInstantPeel(v) and v then
            notify("Peeling","Client Shared.Stats.instantPeel unavailable")
        end
    end)
    kitchen:Section({Title="Kitchen upgrades"})
    addToggle(kitchen,"Auto touch tycoon purchase pads","AutoPads",nil,function(v)
        if v and type(firetouchinterest)~="function" then
            notify("Tycoon","This executor has no firetouchinterest; auto-pad touches won't run")
        end
    end)

    local survival=window:Tab({Title="Fries Survival"})
    survival:Section({Title="Threat protection"})
    addToggle(survival,"Auto close shutter for anomalies","AutoShutter")
    addToggle(survival,"Reopen hub-closed shutter","ReopenShutter")
    addToggle(survival,"Auto repair broken power box","AutoPower")
    survival:Button({Title="Check car anomaly status",Callback=function()
        local danger,kind=anomalyKind()
        notify("Car",(danger and "Danger: " or "Safe / unknown: ")..kind)
    end})
    survival:Button({Title="Manual toggle shutter",Callback=function()
        local ok=shutterToggle()
        notify("Shutter",ok and "Request sent" or "Request unavailable")
    end})
    survival:Section({Title="World radar"})
    addToggle(survival,"Car & anomaly ESP","Radar",nil,function(v)
        if not v then clearRadar()end
    end)
    addToggle(survival,"Fullbright","Fullbright",nil,setFullbright)

    local utility=window:Tab({Title="Fries Travel"})
    utility:Section({Title="World locations (source-reported)"})
    local locations={
        {"Kitchen / peeler",Vector3.new(46.4,4,24.3)},
        {"Potato pile",pilePos},
        {"Potato crate",cratePos},
        {"Drive-thru window",Vector3.new(13.5,4.8,23.3)},
        {"Power box",powerPos},
        {"Item shop",Vector3.new(28.3,4,29.3)},
        {"Merchant",Vector3.new(30,4,157.9)},
        {"Basement padlock",Vector3.new(103.8,3,40.9)}
    }
    for _,entry in ipairs(locations)do
        local text,position=entry[1],entry[2]
        utility:Button({Title="Teleport: "..text,Callback=function()
            local hrp=characterRoot()
            if not hrp then notify("Travel","Character unavailable");return end
            hrp.CFrame=CFrame.new(position+Vector3.new(0,2.5,0))
            updateAction("Teleported to "..text)
        end})
    end
    utility:Section({Title="Movement"})
    addToggle(utility,"Infinite jump","InfiniteJump")
    addToggle(utility,"Noclip","Noclip",nil,function(v)if not v then setNoclip(false)end end)

    local function tickWork()
        if shutdown or not state.Running then return end
        if state.Paused then return end
        local now=os.clock()
        if isActive("AutoPower") and now>=nextPower then
            nextPower=now+2
            local box=powerBroken()
            if box then fixPower() end
        end
        if isActive("AutoShutter") and now>=lastShutter then checkShutter() end
        if isActive("FarmPileCrate") and now>=nextFarm and not busy then
            nextFarm=now+0.4
            runFarm()
        end
        if isActive("AutoPads") and now>=nextPad then
            nextPad=now+2
            buyPads()
        end
        if isActive("Radar") then scanRadar() end
        if isActive("Fullbright") then setFullbright(true) end
    end
    task.spawn(function()
        while state.Running and not shutdown do
            local ok,err=pcall(tickWork)
            if not ok then log("ExtrasError",tostring(err):sub(1,220)) end
            task.wait(0.6)
        end
    end)
    state.ExtrasUnload=function()
        shutdown=true
        clearRadar()
        setNoclip(false)
        setFullbright(false)
        setInstantPeel(false)
    end
    log("ExtrasInstalled","Fries supply, power, shutter, ESP, travel and utility controls added")
    return true
end
