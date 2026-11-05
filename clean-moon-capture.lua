-- Clean the Moon | BeyyHub Client Game Mapper v1.0.0
-- Collects CLIENT-VISIBLE metadata ONLY. No server-code access, hooking,
-- script decompilation, private chat, secrets, or remote payload interception.
return function(context)
    local player=context.player
    local state=context.state
    local notify=context.notify
    local log=context.log
    local Http=game:GetService("HttpService")
    local Players=game:GetService("Players")
    local CS=game:GetService("CollectionService")
    local workspace=game:GetService("Workspace")
    local rs=game:GetService("ReplicatedStorage")
    local folder="CleanMoonHub"
    local mapPath=folder.."/clean_moon_game_map.json"
    local diagPath=folder.."/clean_moon_diagnostics.json"
    local active=false
    local stopped=false
    local count=0
    local lastSummary=nil
    local keywords={
        "moon","clean","sweep","dust","debris","trash","junk","meteor","rock","resource",
        "collect","pickup","harvest","scrap","loot","sell","cash","money","coin","gem",
        "backpack","bag","tank","capacity","storage","upgrade","multiplier","boot",
        "broom","brush","vacuum","tool","robot","drone","base","plot","build","conveyor",
        "zone","crater","area","gate","unlock","barrier","vehicle","crawler","rebirth",
        "reward","progress","quest","round","pet","equipment","craft","spawn"
    }
    local forbidden={"password","passwd","secret","token","apikey","api_key",
        "cookie","webhook","authorization","authcode","license","serial","keysystem",
        "sessionid","accountid","userid","user_id","email","telephone","phonenum"}
    local function safeName(value)
        local s=tostring(value or ""):sub(1,120):gsub("[%c]"," ")
        local n=s:lower():gsub("%s+","")
        for _,part in ipairs(forbidden) do
            if n:find(part,1,true) then return "<redacted>" end
        end
        return s
    end
    local function path(obj)
        if typeof(obj)~="Instance" then return nil end
        local parts={}
        local cursor=obj
        for _=1,35 do
            if not cursor or cursor==game then break end
            if cursor:IsA("Player") and cursor~=player then return nil end
            if cursor:IsA("Model") then
                local owner=Players:GetPlayerFromCharacter(cursor)
                if owner and owner~=player then return nil end
            end
            if cursor==player then
                table.insert(parts,1,"LocalPlayer")
            elseif cursor==player.Character then
                table.insert(parts,1,"LocalCharacter")
            else
                local n=safeName(cursor.Name)
                if n=="<redacted>" then return nil end
                table.insert(parts,1,n)
            end
            cursor=cursor.Parent
        end
        return #parts>0 and table.concat(parts,".") or nil
    end
    local function safeValue(value,allowText)
        local ty=typeof(value)
        if ty=="number" then
            if value~=value or value==math.huge or value==-math.huge then return nil end
            return math.round(value*10000)/10000
        elseif ty=="boolean" then return value
        elseif ty=="string" then
            if not allowText then return "<string>" end
            return safeName(value)
        elseif ty=="Vector3" then
            return {X=math.round(value.X*1000)/1000,Y=math.round(value.Y*1000)/1000,Z=math.round(value.Z*1000)/1000}
        elseif ty=="Vector2" then return {X=value.X,Y=value.Y}
        elseif ty=="Color3" then
            return {R=math.round(value.R*255),G=math.round(value.G*255),B=math.round(value.B*255)}
        elseif ty=="CFrame" then return {Position=safeValue(value.Position)}
        elseif ty=="EnumItem" then return tostring(value)
        elseif ty=="Instance" then return path(value)
        elseif ty=="BrickColor" then return tostring(value)
        end
        return "<"..ty..">"
    end
    local function safeAttributes(obj)
        local ok,a=pcall(function()return obj:GetAttributes()end)
        if not ok or type(a)~="table" then return nil end
        local values,n={},0
        for k,v in pairs(a) do
            local name=safeName(k)
            if name~="<redacted>" and n<45 then
                local allowText=name:lower():match("state") or name:lower():match("phase")
                    or name:lower():match("zone") or name:lower():match("type")
                    or name:lower():match("mode") or name:lower():match("tool")
                    or name:lower():match("status") or name:lower():match("class")
                values[name]=safeValue(v,allowText~=nil)
                n=n+1
            end
        end
        return next(values) and values or nil
    end
    local function relevantName(obj)
        local name=obj.Name:lower()
        for _,word in ipairs(keywords) do
            if name:find(word,1,true) then return true end
        end
        return false
    end
    local function interesting(obj,scope,level)
        if level<3 then return true end
        if scope~="Workspace" and scope~="PlayerGui" then return true end
        if scope=="PlayerGui" then
            return obj:IsA("GuiButton") or obj:IsA("ScreenGui")
                or obj:IsA("TextBox") or obj:IsA("ProximityPrompt")
                or obj:IsA("ValueBase") or relevantName(obj)
        end
        if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") or obj:IsA("RemoteFunction")
            or obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector")
            or obj:IsA("TouchTransmitter") or obj:IsA("Tool")
            or obj:IsA("ModuleScript") or obj:IsA("LocalScript") or obj:IsA("ValueBase") then
            return true
        end
        return relevantName(obj)
    end
    local function describe(obj,scope,level)
        local address=path(obj)
        if not address then return nil end
        local out={Path=address,Name=safeName(obj.Name),Class=obj.ClassName,Depth=level}
        local attributes=safeAttributes(obj)
        if attributes then out.Attributes=attributes end
        local tagsOk,tags=pcall(CS.GetTags,CS,obj)
        if tagsOk and #tags>0 then
            out.Tags={}
            for i=1,math.min(#tags,16) do
                local n=safeName(tags[i])
                if n~="<redacted>" then out.Tags[#out.Tags+1]=n end
            end
        end
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            out.Kind="Remote"
        elseif obj:IsA("ProximityPrompt") then
            out.Kind="Prompt"
            out.Action=safeName(obj.ActionText)
            out.Object=safeName(obj.ObjectText)
            out.HoldDuration=obj.HoldDuration
            out.MaxActivationDistance=obj.MaxActivationDistance
            out.Enabled=obj.Enabled
            out.RequiresLineOfSight=obj.RequiresLineOfSight
        elseif obj:IsA("ClickDetector") then
            out.Kind="Click"
            out.MaxActivationDistance=obj.MaxActivationDistance
        elseif obj:IsA("TouchTransmitter") then
            out.Kind="Touch"
        elseif obj:IsA("Tool") then
            out.Kind="Tool"
            out.RequiresHandle=obj.RequiresHandle
            out.CanBeDropped=obj.CanBeDropped
            out.ToolTip=safeName(obj.ToolTip)
        elseif obj:IsA("BasePart") then
            out.Kind="Part"
            out.Position=safeValue(obj.Position)
            out.Size=safeValue(obj.Size)
            out.Anchored=obj.Anchored
            out.CanTouch=obj.CanTouch
            out.CanCollide=obj.CanCollide
            out.Transparency=obj.Transparency
        elseif obj:IsA("GuiButton") then
            out.Kind="UIControl"
            out.Visible=obj.Visible
            if obj:IsA("TextButton") then out.Text=safeName(obj.Text) end
        elseif obj:IsA("TextBox") then
            out.Kind="UIInput"
            out.Placeholder=safeName(obj.PlaceholderText)
            -- Never record TextBox.Text: it can contain keys/private input.
        elseif obj:IsA("ValueBase") then
            out.Kind="Value"
            local ok,v=pcall(function()return obj.Value end)
            if ok then out.Value=safeValue(v,false) end
        elseif obj:IsA("ModuleScript") or obj:IsA("LocalScript") or obj:IsA("Script") then
            out.Kind="CodeMetadataOnly"
        end
        if obj:IsA("GuiObject") then out.Visible=obj.Visible end
        return out
    end
    local limits={
        {Name="ReplicatedStorage",Root=rs,Visit=25000,Save=10000},
        {Name="ReplicatedFirst",Root=game:GetService("ReplicatedFirst"),Visit=5000,Save=1600},
        {Name="PlayerScripts",Root=player:FindFirstChild("PlayerScripts"),Visit=17000,Save=9000},
        {Name="PlayerGui",Root=player:FindFirstChild("PlayerGui"),Visit=35000,Save=3500},
        {Name="Backpack",Root=player:FindFirstChild("Backpack"),Visit=3000,Save=1500},
        {Name="LocalCharacter",Root=player.Character,Visit=3000,Save=1600},
        {Name="Workspace",Root=workspace,Visit=150000,Save=13000},
        {Name="StarterPack",Root=game:GetService("StarterPack"),Visit=2000,Save=1200},
        {Name="Lighting",Root=game:GetService("Lighting"),Visit=2000,Save=1200}
    }
    local function scanScope(spec,report)
        local entry={Nodes={},ClassCounts={},Visited=0,Omitted=0,Truncated=false}
        report.Scopes[spec.Name]=entry
        local root=spec.Root
        if not root then
            report.Errors[#report.Errors+1]=spec.Name.." not present"
            return
        end
        local queue={{Node=root,Level=0}}
        local index=1
        while index<=#queue and entry.Visited<spec.Visit and state.Running and not stopped do
            local record=queue[index]
            queue[index]=false
            index=index+1
            local node=record.Node
            if node and (node==root or node.Parent) and node.Name~="BeyyMoonNativeHub" and path(node) then
                entry.Visited=entry.Visited+1
                entry.ClassCounts[node.ClassName]=(entry.ClassCounts[node.ClassName] or 0)+1
                if interesting(node,spec.Name,record.Level) then
                    if #entry.Nodes<spec.Save then
                        local ok,description=pcall(describe,node,spec.Name,record.Level)
                        if ok and description then
                            entry.Nodes[#entry.Nodes+1]=description
                            if description.Kind=="Remote" then
                                report.RemoteCatalog[#report.RemoteCatalog+1]={Path=description.Path,Class=description.Class}
                            elseif description.Kind=="Prompt" or description.Kind=="Click" or description.Kind=="Touch" then
                                if #report.InteractionCatalog<2500 then
                                    report.InteractionCatalog[#report.InteractionCatalog+1]=description
                                end
                            end
                        end
                    else
                        entry.Omitted=entry.Omitted+1
                    end
                end
                local ok,children=pcall(node.GetChildren,node)
                if ok then
                    for _,child in ipairs(children) do
                        if path(child) then
                            queue[#queue+1]={Node=child,Level=record.Level+1}
                        end
                    end
                end
            end
            if entry.Visited>0 and entry.Visited%250==0 then task.wait() end
        end
        entry.Truncated=index<=#queue
        report.TotalVisited=report.TotalVisited+entry.Visited
        report.TotalRecorded=report.TotalRecorded+#entry.Nodes
    end
    local function localInfo(report)
        local info={PlayerAttributes=safeAttributes(player),LocalLeaderstats={}}
        local stats=player:FindFirstChild("leaderstats")
        if stats then
            for _,obj in ipairs(stats:GetChildren()) do
                if obj:IsA("ValueBase") then
                    info.LocalLeaderstats[#info.LocalLeaderstats+1]={
                        Name=safeName(obj.Name),Class=obj.ClassName,
                        Value=safeValue(obj.Value,false)
                    }
                end
            end
        end
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if root then info.CharacterPosition=safeValue(root.Position) end
        local backpack=player:FindFirstChild("Backpack")
        info.EquippedTools={}
        for _,place in ipairs({char,backpack}) do
            if place then
                for _,obj in ipairs(place:GetChildren()) do
                    if obj:IsA("Tool") then
                        info.EquippedTools[#info.EquippedTools+1]={Name=safeName(obj.Name),
                            Parent=place==char and "Character" or "Backpack"}
                    end
                end
            end
        end
        report.LocalState=info
        local roots={}
        for _,obj in ipairs(workspace:GetChildren()) do
            if #roots>=250 then break end
            local address=path(obj)
            if address then
                roots[#roots+1]={Path=address,Class=obj.ClassName,Attributes=safeAttributes(obj)}
            end
        end
        report.WorkspaceRoots=roots
        local focus={}
        for _,scope in ipairs({"Workspace","ReplicatedStorage","PlayerScripts"}) do
            local section=report.Scopes[scope]
            if section then
                for _,node in ipairs(section.Nodes)do
                    if relevantName({Name=node.Name}) and #focus<2600 then
                        focus[#focus+1]={Path=node.Path,Class=node.Class,Kind=node.Kind,
                            Position=node.Position,Attributes=node.Attributes}
                    end
                end
            end
        end
        report.ProgressionCandidates=focus
    end
    local function ensureFolder()
        if type(isfolder)=="function" then
            local ok,result=pcall(isfolder,folder)
            if ok and result then return true end
        end
        return type(makefolder)=="function" and pcall(makefolder,folder)
    end
    local function save(path,data)
        if type(writefile)~="function" then return false,"writefile not available" end
        if not ensureFolder() then return false,"Cannot create output directory" end
        local ok,err=pcall(writefile,path,data)
        return ok,ok and nil or tostring(err)
    end
    local function wrapPrior(snapshot)
        if type(readfile)~="function" then
            return {Schema="CleanMoonHub-GameMap-v1",UniverseId=game.GameId,Places={}}
        end
        local previous
        local ok,src=pcall(readfile,mapPath)
        if ok and type(src)=="string" and #src<16000000 then
            local decodedOk,decoded=pcall(Http.JSONDecode,Http,src)
            if decodedOk and type(decoded)=="table" and tonumber(decoded.UniverseId)==game.GameId
                and type(decoded.Places)=="table" then
                previous=decoded
            end
        end
        return previous or {Schema="CleanMoonHub-GameMap-v1",UniverseId=game.GameId,Places={}}
    end
    local function capture(label)
        if active then notify("Capture","Already scanning");return end
        if stopped or not state.Running then return end
        active=true
        state.CaptureStatus="Scanning game objects"
        local phase=safeName(label or "Manual")
        task.spawn(function()
            local report={
                Schema="CleanMoonHub-PlaceSnapshot-v1",PlaceId=game.PlaceId,
                UniverseId=game.GameId,PlaceName=safeName(game.Name),Phase=phase,
                CapturedAtUTC=os.date("!%Y-%m-%dT%H:%M:%SZ"),Errors={},
                Notes={
                    "Client-visible game metadata only: no server scripts, bytecode, source code, or network hooks.",
                    "Remotes are names/classes only; argument signatures and server validation are unknown.",
                    "String values and text box contents are not exported.",
                    "Some world sections are capped; see Truncated and Omitted fields."
                },
                Scopes={},RemoteCatalog={},InteractionCatalog={},ProgressionCandidates={},
                TotalVisited=0,TotalRecorded=0,LocalState={},WorkspaceRoots={}
            }
            local ok,err=pcall(function()
                for _,scope in ipairs(limits) do
                    scanScope(scope,report)
                    task.wait()
                end
                localInfo(report)
            end)
            if not ok then report.Errors[#report.Errors+1]="Capture error: "..tostring(err):sub(1,250) end
            if stopped or not state.Running then active=false;return end
            state.CaptureStatus="Encoding map"
            local merged=wrapPrior(report)
            merged.Places[tostring(game.PlaceId)]=report
            merged.LatestPlaceId=game.PlaceId
            merged.LastCaptureAtUTC=report.CapturedAtUTC
            merged.Version="1.0.0"
            local jsonOk,encoded=pcall(Http.JSONEncode,Http,merged)
            if not jsonOk or type(encoded)~="string" then
                state.CaptureStatus="Map JSON encoding error"
                log("CaptureError",tostring(encoded))
                active=false
                return
            end
            local saved,reason=save(mapPath,encoded)
            local copied=false
            if not saved and type(setclipboard)=="function" then copied=pcall(setclipboard,encoded) end
            local diagnostics={
                Schema="CleanMoonHub-Diagnostics-v1",
                PlaceId=game.PlaceId,UniverseId=game.GameId,
                CaptureAtUTC=report.CapturedAtUTC,Phase=phase,
                Status=saved and "File saved" or copied and "Copied to clipboard" or "Unable to export",
                MapPath=mapPath,MapBytes=#encoded,
                TotalVisited=report.TotalVisited,TotalRecorded=report.TotalRecorded,
                Remotes=#report.RemoteCatalog,Interactions=#report.InteractionCatalog,
                Candidates=#report.ProgressionCandidates,Errors=report.Errors,Scopes={},
                LocalTools=report.LocalState.EquippedTools
            }
            for name,section in pairs(report.Scopes) do
                diagnostics.Scopes[name]={Visited=section.Visited,
                    Recorded=#section.Nodes,Omitted=section.Omitted,Truncated=section.Truncated}
            end
            local diagOK,diagJSON=pcall(Http.JSONEncode,Http,diagnostics)
            if diagOK and type(diagJSON)=="string" then save(diagPath,diagJSON) end
            count=count+1
            state.CaptureStatus=saved and ("Saved "..mapPath) or copied
                and "Copied full map JSON to clipboard" or ("Export unavailable: "..tostring(reason))
            lastSummary=diagnostics
            state.CaptureSummary=diagnostics
            log("Capture",state.CaptureStatus.." / "..report.TotalVisited.." objects inspected")
            notify("Game Capture",state.CaptureStatus)
            active=false
        end)
    end
    local function reportStatus()
        if not lastSummary then return "No completed capture yet" end
        return tostring(lastSummary.TotalVisited).." inspected / "
            ..tostring(lastSummary.TotalRecorded).." recorded / "
            ..tostring(lastSummary.Remotes).." remotes / "
            ..tostring(lastSummary.Interactions).." interactions"
    end
    state.CaptureNow=capture
    state.CaptureReport=reportStatus
    state.CapturePath=mapPath
    state.DiagnosticPath=diagPath
    state.CaptureStatus="Ready"
    state.StopCapture=function()stopped=true end
    task.spawn(function()
        local started=os.clock()
        while state.Running and not stopped and os.clock()-started<12 do
            if player:FindFirstChild("PlayerScripts") and rs:FindFirstChildWhichIsA("Folder")
                and os.clock()-started>3 then break end
            task.wait(0.5)
        end
        if state.Running and not stopped then capture("Automatic") end
    end)
    return true
end
