-- BeyyHub targeted lobby gem/dev UI audit
-- Read-only: no RemoteFunction calls, require(), GUI manipulation or auth tests.
-- Summarizes client-visible references without exporting privileged arguments.

local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local P=Players.LocalPlayer
if not P then warn("[Gem Focus] No LocalPlayer") return end
local mtg=RS:FindFirstChild("MTG")
local client=P:FindFirstChild("PlayerScripts")
client=client and client:FindFirstChild("MTGClient")
local config=mtg and mtg:FindFirstChild("Config")
local remotes=mtg and mtg:FindFirstChild("Remotes")
local gui=P:FindFirstChildOfClass("PlayerGui")
local inspect={
    {Label="DevWidgets",Object=client and client:FindFirstChild("DevWidgets")},
    {Label="Native DevMenu",Object=client and client:FindFirstChild("DevMenu")},
    {Label="Admin config",Object=config and config:FindFirstChild("Admin")},
    {Label="AdminReveal config",Object=config and config:FindFirstChild("AdminReveal")},
    {Label="AbuseEvent",Object=client and client:FindFirstChild("AbuseEvent")},
    {Label="LobbyUI",Object=client and client:FindFirstChild("LobbyUI")},
}
local report={
    Version=1,AtMs=DateTime.now().UnixTimestampMillis,
    Role=mtg and mtg:GetAttribute("Role")or nil,
    Phase=mtg and mtg:FindFirstChild("State")and mtg.State:GetAttribute("Phase")or nil,
    ScanOnly=true,RemoteCalls=0,MenuOpened=false,AuthorizationTested=false,
    ServerSourceVisible=false,DecompilerAvailable=type(decompile)=="function",
    DevActionPresent=remotes and remotes:FindFirstChild("DevAction")~=nil,
    DevActionClass=remotes and remotes:FindFirstChild("DevAction")
        and remotes.DevAction.ClassName or nil,
    NativeDevKitPresent=gui and gui:FindFirstChild("MTGDevKit")~=nil or false,
    Modules={},
    Note="Only client-visible metadata and keyword flags. A DevAction RemoteFunction existing does not mean a gem-spawn action is authorized. This report omits exact remote payloads, credentials, identities and raw decompiled source."
}
local keywords={
    gem={"gem","jewel"},
    spawn={"spawn","give","grant","credit","award","addgem","dropgem"},
    admin={"devaction","devmenu","devwidgets","admin","permission","authorized"},
    data={"datastore","messagingservice","globalgems","publishasync","subscribeasync"},
    remote={"fireserver","invokeserver","onserverinvoke","onserverevent"},
    ui={"textbutton","createbutton","button","label","input","menu","widget"}
}
local function contains(hay,needle)
    return string.find(hay,needle,1,true)~=nil
end
local function hit(line,words)
    for _,w in ipairs(words)do if contains(line,w)then return true end end
    return false
end
local function safeLabels(line)
    -- UI-facing display strings ONLY. Never export callable command IDs
    -- from remote lines, authorization branches or parameter structures.
    local lower=line:lower()
    if hit(lower,keywords.remote) or hit(lower,{"password","secret","token",
        "userid","username","http","key","authoriz","permission","grant",
        "roles","groupid","membership","getfenv","loadstring"})then return {}end
    local labels={}
    for quoted in line:gmatch('"(.-)"')do
        if #quoted>=4 and #quoted<=48 and hit(quoted:lower(),{"gem","spawn","give","drop"})
            and not hit(quoted:lower(),{"mtg_","_v1","http","player","userid"})then
            labels[#labels+1]=quoted
        end
        if #labels>=8 then break end
    end
    return labels
end
for _,item in ipairs(inspect)do
    local obj=item.Object
    local row={Name=item.Label,Present=obj~=nil,Class=obj and obj.ClassName or nil,
        Decompiled=false,SourceLength=0,Lines=0,Categories={},
        RelatedReferences={},UiTextLabels={},Error=nil}
    if obj and type(decompile)=="function"and obj:IsA("LuaSourceContainer")then
        local ok,src=pcall(decompile,obj)
        if ok and type(src)=="string"then
            row.Decompiled=true
            row.SourceLength=#src
            src=src:sub(1,240000)
            local foundLabels={}
            for line in (src.."\n"):gmatch("(.-)\n")do
                row.Lines+=1
                local lower=line:lower()
                local flags={}
                for category,words in pairs(keywords)do
                    if hit(lower,words)then
                        flags[#flags+1]=category
                        row.Categories[category]=(row.Categories[category]or 0)+1
                    end
                end
                if #flags>0 and #row.RelatedReferences<110
                    and (hit(lower,keywords.gem) or
                        (hit(lower,keywords.spawn)and hit(lower,keywords.admin)))then
                    row.RelatedReferences[#row.RelatedReferences+1]={
                        Line=row.Lines,Flags=flags,
                        HasCall=hit(lower,keywords.remote),
                        HasUiReference=hit(lower,keywords.ui),
                        HasDataStoreReference=hit(lower,keywords.data)
                    }
                    for _,label in ipairs(safeLabels(line))do foundLabels[label]=true end
                end
            end
            for label in pairs(foundLabels)do
                if #row.UiTextLabels<30 then
                    row.UiTextLabels[#row.UiTextLabels+1]=label
                end
            end
            table.sort(row.UiTextLabels)
        else row.Error="Decompile unavailable"end
    else row.Error=obj and"Decompile unavailable"or"Module not replicated"end
    report.Modules[#report.Modules+1]=row
end
local path="Geode/lobby_gem_dev_focus.json"
local ok,err=pcall(function()
    assert(type(writefile)=="function","writefile unavailable")
    if type(isfolder)=="function"and type(makefolder)=="function"
        and not isfolder("Geode")then makefolder("Geode")end
    writefile(path,Http:JSONEncode(report))
end)
if ok then
    print("[Gem Focus] Saved "..path.."; no developer actions executed.")
else
    warn("[Gem Focus] Export failed: "..tostring(err))
end
return report
