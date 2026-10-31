-- BeyyHub Chapter 1 Passive Live Diagnostics v1
-- Monitors Main or Standalone without changing game state or sending remotes.
-- F10: save/copy one report; F11: stop diagnostics only.
return function(options)
    options=options or {}
    local source=options.Source=="standalone" and "standalone" or "main"
    local player=game:GetService("Players").LocalPlayer
    local RS=game:GetService("ReplicatedStorage")
    local WS=game:GetService("Workspace")
    local UIS=game:GetService("UserInputService")
    local Http=game:GetService("HttpService")
    if type(_G.__BEYY_CH1_DIAG_STOP)=="function" then
        pcall(_G.__BEYY_CH1_DIAG_STOP)
    end
    local alive=true
    local started=os.clock()
    local path="BeyyHub/chapter1_"..source.."_diagnostics.txt"
    local events,connections,previous={},{},{}
    local lastSave=-math.huge
    local lastBeat=-math.huge
    local tracks={
        {"UpgTntCooldown","TntCooldown"},{"UpgVacPower","VacuumPower"},
        {"UpgTntPower","TntPower"},{"UpgVacRuntime","VacuumRuntime"},
        {"UpgVacCooling","VacuumCooling"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},
        {"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},
        {"UpgPitchSweep","Pitchfork"},{"UpgDroneSpeed","DroneSpeed"},
        {"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
    }
    local function safe(f,default)
        local ok,res=pcall(f)
        return ok and res or default
    end
    local function record(kind,message)
        if not alive then return end
        local msg=tostring(message)
        if #msg>700 then msg=msg:sub(1,700).."..." end
        local entry=string.format("+%.2fs [%s] %s",os.clock()-started,kind,msg)
        events[#events+1]=entry
        if #events>1400 then table.remove(events,1) end
        if kind=="UPGRADE_REQUEST" or kind=="UPGRADE_CONFIRMED" or
            kind=="SKIP_ATTEMPT" or kind=="NEEDLE_RESULT" or kind=="HANDIN_REQUEST" then
            print("[CH1 DIAG] "..entry)
        end
    end
    local function visible(obj)
        while obj do
            if obj:IsA("GuiObject") and not obj.Visible then return false end
            if obj:IsA("ScreenGui") and not obj.Enabled then return false end
            if obj:IsA("PlayerGui") then return true end
            obj=obj.Parent
        end
        return false
    end
    local function skipStatus()
        local pg=player and player:FindFirstChildOfClass("PlayerGui")
        if not pg then return "PlayerGui unavailable" end
        local names={}
        for _,obj in ipairs(pg:GetDescendants()) do
            if obj:IsA("GuiButton") then
                local text=obj.Name
                if obj:IsA("TextButton") then text=text.." "..obj.Text end
                local parent=obj.Parent
                for _=1,3 do
                    if not parent or parent==pg then break end
                    text=text.." "..parent.Name
                    parent=parent.Parent
                end
                if text:lower():find("skip",1,true) then
                    names[#names+1]=obj:GetFullName()..
                        (visible(obj) and ":VISIBLE" or ":HIDDEN")
                    if #names>=4 then break end
                end
            end
        end
        return #names>0 and table.concat(names,"; ") or "no Skip GUI candidate"
    end
    local function needleStatus()
        local server=WS:FindFirstChild("NeedleObjectiveServer")
        local folder=server and server:FindFirstChild("Needle")
        if not folder then return "NeedleObjectiveServer.Needle not replicated" end
        local exposed,hidden,total=0,0,0
        local detail=""
        for _,part in ipairs(folder:GetDescendants()) do
            if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective")==true then
                total+=1
                local hiddenFlag=part:GetAttribute("HIDDEN_WITHIN")
                if hiddenFlag==nil or hiddenFlag==false then
                    exposed+=1
                    detail="HayId="..tostring(part:GetAttribute("HayId"))..
                        " Pos="..tostring(part.Position)
                else
                    hidden+=1
                end
            end
        end
        return string.format("total=%d exposed=%d hidden=%d %s",total,exposed,hidden,detail)
    end
    local function upgradeStatus()
        local folder=RS:FindFirstChild("NeedleHaystack")
        local module=folder and folder:FindFirstChild("Config")
        local cfg=module and safe(function()return require(module)end,nil)
        local ls=player and player:FindFirstChild("leaderstats")
        local cash=ls and ls:FindFirstChild("Cash")
        local amount=cash and tonumber(cash.Value) or 0
        local rows={}
        for _,item in ipairs(tracks) do
            local selected=options.Enabled and safe(function()return options.Enabled(item[1])end,false)
            if selected then
                local level=tonumber(player:GetAttribute("HayUpgrade"..item[2])) or 1
                local track=cfg and cfg.UPGRADE_TRACKS and cfg.UPGRADE_TRACKS[item[2]]
                local nextLevel=track and track.Levels and track.Levels[level+1]
                local cost=nextLevel and tonumber(nextLevel.Cost)
                if cost then
                    cost*=tonumber(player:GetAttribute("UpgradeCostMultiplier")) or 1
                    if item[2]:sub(1,9)=="Pitchfork" then
                        cost*=tonumber(player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1
                    end
                    cost=math.round(cost*100)/100
                end
                rows[#rows+1]=item[2].." L"..level..
                    (cost and (" next=$"..cost.." ["..(amount>=cost and "AFFORDABLE" or "SAVING").."]") or " MAX/NO CONFIG")
            end
        end
        return string.format("cash=%.2f remote=%s enabled=%d %s",
            amount,tostring(folder and folder:FindFirstChild("BuyUpgrade")~=nil),
            #rows,#rows>0 and table.concat(rows," | ") or "NO ENABLED UPGRADE TRACKS")
    end
    local function snapshot()
        local pg=player and player:FindFirstChildOfClass("PlayerGui")
        local ending=pg and pg:FindFirstChild("NeedleEndingUI")
        local results=ending and ending:FindFirstChild("ReturnToLobby")
        local npc=WS:FindFirstChild("NPC")
        local farmer=npc and npc:FindFirstChild("Farmer_NPC")
        local hrp=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance=(farmer and hrp) and safe(function()
            return string.format("%.1f studs",(farmer:GetPivot().Position-hrp.Position).Magnitude)
        end,"distance unavailable") or "Farmer_NPC/HRP missing"
        return {
            mode=options.Mode and safe(options.Mode,"unknown") or "unknown",
            upgrades=upgradeStatus(),
            needle=needleStatus(),
            needleOwned=tostring(player:GetAttribute("NeedleOwned")),
            hoveredHayId=tostring(player:GetAttribute("HoveredHayId")),
            needlePickupBusy=options.PickupBusy and tostring(safe(options.PickupBusy,false)) or "unknown",
            uiMouseBusy=options.MouseBusy and tostring(safe(options.MouseBusy,false)) or "unknown",
            farmerDistance=distance,
            skip=skipStatus(),
            results=tostring(results and visible(results) or false),
            cutscene=tostring(player:GetAttribute("CutsceneActive")),
            needleInputLocked=tostring(player:GetAttribute("NeedleInputLocked")),
        }
    end
    local fields={"mode","upgrades","needle","needleOwned","hoveredHayId",
        "needlePickupBusy","uiMouseBusy","farmerDistance","skip","results",
        "cutscene","needleInputLocked"}
    local function report()
        local current=safe(snapshot,{})
        local lines={"BeyyHub Chapter 1 LIVE DIAGNOSTICS v1",
            "Mode="..source.." PlaceId="..tostring(game.PlaceId)..
                " JobId="..tostring(game.JobId),
            "Elapsed="..string.format("%.2f",os.clock()-started).."s",
            "=== LIVE STATE ==="}
        for _,key in ipairs(fields) do
            lines[#lines+1]=key.." = "..tostring(current[key])
        end
        lines[#lines+1]="=== TIMELINE ==="
        for _,entry in ipairs(events) do lines[#lines+1]=entry end
        return table.concat(lines,"\n")
    end
    local function save()
        if type(writefile)~="function" then return end
        pcall(function()
            if type(makefolder)=="function" and
                (type(isfolder)~="function" or not isfolder("BeyyHub")) then
                makefolder("BeyyHub")
            end
            writefile(path,report())
        end)
    end
    local function stop()
        if not alive then return end
        record("STOP","Diagnostic stopped")
        alive=false
        for _,connection in ipairs(connections) do
            pcall(function()connection:Disconnect()end)
        end
        save()
        if _G.__BEYY_CH1_DIAG_EVENT==record then
            _G.__BEYY_CH1_DIAG_EVENT=nil
        end
        if _G.__BEYY_CH1_DIAG_STOP==stop then
            _G.__BEYY_CH1_DIAG_STOP=nil
        end
    end
    _G.__BEYY_CH1_DIAG_EVENT=record
    _G.__BEYY_CH1_DIAG_STOP=stop
    _G.__BEYY_CH1_DIAG_REPORT=report
    connections[#connections+1]=UIS.InputBegan:Connect(function(key,used)
        if used then return end
        if key.KeyCode==Enum.KeyCode.F10 then
            save()
            if type(setclipboard)=="function" then pcall(setclipboard,report()) end
            print("[CH1 DIAG] Report saved/copied: "..path)
        elseif key.KeyCode==Enum.KeyCode.F11 then
            stop()
            print("[CH1 DIAG] Diagnostics stopped, automation left running.")
        end
    end)
    task.spawn(function()
        record("START","Passive monitor started; F10 export, F11 stop diagnostics")
        while alive and not (options.Stopped and safe(options.Stopped,false)) do
            local ok,current=pcall(snapshot)
            if ok then
                for _,field in ipairs(fields) do
                    local value=tostring(current[field])
                    if previous[field]~=value then
                        previous[field]=value
                        if field~="farmerDistance" then
                            record("STATE",field.." = "..value)
                        end
                    end
                end
            else record("ERROR","Failed to sample: "..tostring(current)) end
            if os.clock()-lastBeat>=15 then
                lastBeat=os.clock()
                record("HEARTBEAT",tostring(previous.mode)..
                    " | "..tostring(previous.upgrades)..
                    " | needle="..tostring(previous.needle)..
                    " | owned="..tostring(previous.needleOwned)..
                    " | skip="..tostring(previous.skip)..
                    " | farmer="..tostring(current and current.farmerDistance))
            end
            if os.clock()-lastSave>=5 then lastSave=os.clock();save() end
            task.wait(1)
        end
        stop()
    end)
    print("[CH1 DIAG] "..source.." active: "..path..
        " | F10 save/copy | F11 stop DIAGNOSTICS only")
end
