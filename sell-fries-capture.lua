-- BeyyHub Sell Fries | game map exporter v0.3.0
-- Local client-visible instance metadata; no script sources or remote interception.
return function(ctx)
    local player,state,window,notify,log=ctx.player,ctx.state,ctx.window,ctx.notify,ctx.log
    local Http=game:GetService("HttpService")
    local Players=game:GetService("Players")
    local ReplicatedStorage=game:GetService("ReplicatedStorage")
    local Workspace=game:GetService("Workspace")
    local CollectionService=game:GetService("CollectionService")
    local exportPath="BeyyHub/sell_fries_game_map.json"
    local running=false
    local cancelled=false
    local lastStatus="Waiting for client initialization"
    local interesting={"potato","pile","crate","fry","cook","kitchen","serve","order","customer",
        "drive","power","cable","shop","tycoon","pad","upgrade","machine","fries","peel",
        "shutter","anomal","car","traffic","night","task","inventory","remote","stats"}
    local function label(x)
        return tostring(x or ""):sub(1,100):gsub("[%c]"," ")
    end
    local function path(obj)
        if not obj then return nil end
        local parts={}
        local node=obj
        for i=1,35 do
            if not node or node==game then break end
            if node:IsA("Player") and node~=player then return nil end
            if node:IsA("Model") then
                local subject=Players:GetPlayerFromCharacter(node)
                if subject and subject~=player then return nil end
            end
            table.insert(parts,1,node==player and "LocalPlayer" or label(node.Name))
            node=node.Parent
        end
        return table.concat(parts,".")
    end
    local function value(v)
        local typ=typeof(v)
        if typ=="string" then return label(v) end
        if typ=="number" then return v==v and math.abs(v)<math.huge and v or nil end
        if typ=="boolean" then return v end
        if typ=="Vector3" then return {X=v.X,Y=v.Y,Z=v.Z} end
        if typ=="Vector2" then return {X=v.X,Y=v.Y} end
        if typ=="Color3" then return {R=v.R,G=v.G,B=v.B} end
        if typ=="EnumItem" then return tostring(v) end
        if typ=="Instance" then return path(v) end
        return typ
    end
    local function attrs(obj)
        local a=obj:GetAttributes()
        local out,n={},0
        for k,v in pairs(a) do
            if n>=30 then break end
            -- Read non-credential attributes, skip common free-text identifiers.
            local lower=k:lower()
            if not (lower:find("key") or lower:find("token") or lower:find("auth")
                or lower:find("password") or lower:find("user") or lower:find("name")) then
                out[k]=value(v);n=n+1
            end
        end
        return out
    end
    local function shouldRecord(obj,scope,depth)
        if depth<3 or scope~="Workspace" then return true end
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
            or obj:IsA("UnreliableRemoteEvent") or obj:IsA("ProximityPrompt")
            or obj:IsA("ClickDetector") or obj:IsA("ModuleScript")
            or obj:IsA("LocalScript") or obj:IsA("ValueBase") then return true end
        local name=obj.Name:lower()
        for _,s in ipairs(interesting)do if name:find(s,1,true) then return true end end
        return false
    end
    local function record(obj,scope)
        local address=path(obj)
        if not address then return nil end
        local item={Path=address,Name=label(obj.Name),Class=obj.ClassName}
        local a=attrs(obj)
        if next(a) then item.Attributes=a end
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
            or obj:IsA("UnreliableRemoteEvent") then
            item.Category="Remote"
        elseif obj:IsA("ProximityPrompt") then
            item.Category="Prompt"
            item.Action=label(obj.ActionText)
            item.Object=label(obj.ObjectText)
            item.HoldDuration=obj.HoldDuration
            item.ActivationRange=obj.MaxActivationDistance
            item.Enabled=obj.Enabled
        elseif obj:IsA("ClickDetector") then
            item.ActivationRange=obj.MaxActivationDistance
        elseif obj:IsA("BasePart") then
            item.Position=value(obj.Position)
            item.Size=value(obj.Size)
            item.CanCollide=obj.CanCollide
            item.Anchored=obj.Anchored
        elseif obj:IsA("GuiButton") then
            item.Category="UI Button"
            item.Visible=obj.Visible
            if obj:IsA("TextButton") then item.Label=label(obj.Text) end
        elseif obj:IsA("TextBox") then
            item.Category="UI Input"
            -- Never inspect entered text.
            item.Placeholder=label(obj.PlaceholderText)
        elseif obj:IsA("ValueBase") then
            local ok,v=pcall(function()return obj.Value end)
            if ok then item.Value=value(v) end
        elseif obj:IsA("ModuleScript") or obj:IsA("LocalScript") then
            item.Category="Code metadata only"
        end
        local ok,tags=pcall(CollectionService.GetTags,CollectionService,obj)
        if ok and #tags>0 then item.Tags=tags end
        return item
    end
    local roots={
        {Name="ReplicatedStorage",Object=ReplicatedStorage,Max=13000,Limit=7500},
        {Name="PlayerScripts",Object=player:FindFirstChild("PlayerScripts"),Max=9000,Limit=5000},
        {Name="PlayerGui",Object=player:FindFirstChild("PlayerGui"),Max=9000,Limit=2500},
        {Name="Workspace",Object=Workspace,Max=120000,Limit=8500},
        {Name="ReplicatedFirst",Object=game:GetService("ReplicatedFirst"),Max=3000,Limit=1400},
        {Name="LocalCharacter",Object=player.Character,Max=500,Limit=500}
    }
    local function inspectRoot(spec,report)
        local section={Entries={},Classes={},Visited=0,Skipped=0,Truncated=false}
        report.Sections[spec.Name]=section
        if not spec.Object then report.Errors[#report.Errors+1]=spec.Name.." unavailable";return end
        local queue={{Obj=spec.Object,Depth=0}}
        local idx=1
        while idx<=#queue and section.Visited<spec.Max and not cancelled do
            local entry=queue[idx]
            queue[idx]=false
            idx=idx+1
            local obj=entry.Obj
            if obj and (obj==spec.Object or obj.Parent) and path(obj) then
                section.Visited=section.Visited+1
                section.Classes[obj.ClassName]=(section.Classes[obj.ClassName] or 0)+1
                if shouldRecord(obj,spec.Name,entry.Depth) then
                    if #section.Entries<spec.Limit then
                        local ok,out=pcall(record,obj,spec.Name)
                        if ok and out then section.Entries[#section.Entries+1]=out end
                    else
                        section.Skipped=section.Skipped+1
                    end
                end
                for _,child in ipairs(obj:GetChildren()) do
                    if path(child) then queue[#queue+1]={Obj=child,Depth=entry.Depth+1} end
                end
            end
            if section.Visited%250==0 then task.wait() end
        end
        section.Truncated=idx<=#queue
    end
    local function landmarks(report)
        local found={}
        for _,name in ipairs({"PotatoPile","DriveThru","PowerBoxes","Tycoon","Traffic","Anomalies","Kitchen"}) do
            local obj=Workspace:FindFirstChild(name)
            if obj then
                local data=record(obj,"Landmark")
                if data then found[name]=data end
            end
        end
        local dt=Workspace:FindFirstChild("DriveThru")
        if dt then
            for _,name in ipairs({"Car","Shutter"}) do
                local obj=dt:FindFirstChild(name)
                if obj then found["DriveThru."..name]=record(obj,"Landmark") end
            end
        end
        local powers=Workspace:FindFirstChild("PowerBoxes")
        local power=powers and powers:FindFirstChild("PowerBox1")
        if power then found.PowerBox1=record(power,"Landmark") end
        local folder=ReplicatedStorage:FindFirstChild("Remotes")
        local remotes={}
        if folder then
            for _,obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                    or obj:IsA("UnreliableRemoteEvent") then
                    remotes[#remotes+1]={Path=path(obj),Class=obj.ClassName}
                end
            end
        end
        report.GameSpecific={
            Landmarks=found,Remotes=remotes,
            PlayerAttributes=attrs(player),
            FeatureDiagnostics=state.ExtrasStats or {},
            KnownGameRemotes={
                RemovePotato=folder and folder:FindFirstChild("RemovePotato")~=nil or false,
                CratePut=folder and folder:FindFirstChild("CratePut")~=nil or false,
                PowerCable=folder and folder:FindFirstChild("PowerCable")~=nil or false,
                ShutterPress=folder and folder:FindFirstChild("ShutterPress")~=nil or false
            }
        }
    end
    local function capture()
        if running then notify("Game map","Capture is already running");return end
        running=true;cancelled=false
        state.FullCaptureStatus="Scanning game objects"
        task.spawn(function()
            local report={
                Schema="BeyyHub-SellFries-GameMap-v1",
                PlaceId=game.PlaceId,UniverseId=game.GameId,
                CapturedAtUTC=os.date("!%Y-%m-%dT%H:%M:%SZ"),
                Notes="Client-visible metadata only. Server scripts, script sources, remote argument signatures, and private data cannot be exported.",
                Sections={},GameSpecific={},Errors={}
            }
            local ok,err=pcall(function()
                for _,spec in ipairs(roots) do inspectRoot(spec,report);task.wait() end
                landmarks(report)
            end)
            if not ok then report.Errors[#report.Errors+1]=tostring(err):sub(1,180) end
            if cancelled then running=false;return end
            local encodeOk,json=pcall(function()return Http:JSONEncode(report)end)
            if not encodeOk then
                state.FullCaptureStatus="JSON encoding failed"
                log("GameMapError",json);running=false;return
            end
            local saved=false
            if type(writefile)=="function" then
                saved=pcall(function()
                    if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("BeyyHub")then makefolder("BeyyHub")end
                    writefile(exportPath,json)
                end)
            end
            local copied=false
            if not saved and type(setclipboard)=="function" then copied=pcall(setclipboard,json)end
            state.FullCaptureStatus=saved and ("Saved "..exportPath)
                or copied and "Copied JSON to clipboard"
                or "Export unavailable (need writefile or setclipboard)"
            state.FullCaptureSummary={Bytes=#json,Sections=report.Sections and #roots,Errors=report.Errors,
                Saved=saved,Copied=copied,Path=exportPath}
            notify("Game map",state.FullCaptureStatus)
            log("GameMap",state.FullCaptureStatus..", "..#json.." bytes")
            running=false
        end)
    end
    local tab=window:Tab({Title="Game Capture"})
    tab:Section({Title="One-file game structure export"})
    local info=tab:Paragraph({Title="Capture Status",Desc="Auto capture scheduled"})
    tab:Button({Title="Export full game map (one JSON)",Callback=capture})
    tab:Button({Title="Check export status",Callback=function()notify("Capture",state.FullCaptureStatus or "Unknown")end})
    state.CaptureFull=capture
    state.CapturePath=exportPath
    state.CaptureUnload=function()cancelled=true end
    state.FullCaptureStatus=lastStatus
    task.spawn(function()
        local started=os.clock()
        while state.Running and not cancelled and os.clock()-started<12 do
            local scripts=player:FindFirstChild("PlayerScripts")
            if ReplicatedStorage:FindFirstChild("Remotes") and scripts and scripts:FindFirstChild("Controllers") and os.clock()-started>3 then break end
            task.wait(0.4)
        end
        if state.Running and not cancelled then capture()end
    end)
    task.spawn(function()
        while state.Running and not cancelled do
            info:SetDesc("Status: "..tostring(state.FullCaptureStatus).."\nFile: "..exportPath
                .."\nIncludes remotes, game hierarchy, modules (names only), prompts, UI buttons, workspace parts and local game attributes."
                .."\nDoes not include protected scripts, user inputs or server internals.")
            task.wait(1)
        end
    end)
    log("GameMap","Auto-export scheduled; manual re-export under Game Capture")
    return true
end
