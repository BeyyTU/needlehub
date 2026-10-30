-- BeyyHub Chapter 2 Hay Return: exact-position capture (standalone)
-- Stand at the hay pile, face the intended direction, then execute this script.
-- Captures HumanoidRootPart CFrame plus camera orientation and offset.
-- Creates a persistent file consumed by Chapter 2 Early Full Puzzles Test v13+.
local CHAPTER2=83445806734780
local SAVE_PATH="BeyyHub/chapter2_hay_return.json"
local BACKUP_PATH="BeyyHub_chapter2_hay_return.json"
local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

if game.PlaceId~=CHAPTER2 then
    warn("[CH2 HAY CAPTURE] Go to Chapter 2 and stand at the hay pile before capturing.")
    return
end

local player=Players.LocalPlayer
if not player then
    warn("[CH2 HAY CAPTURE] LocalPlayer unavailable.")
    return
end
local character=player.Character
local root=character and character:FindFirstChild("HumanoidRootPart")
local camera=Workspace.CurrentCamera
if not root or not camera then
    warn("[CH2 HAY CAPTURE] Character HumanoidRootPart or CurrentCamera unavailable.")
    return
end
if player:GetAttribute("NeedleRoundComplete")==true then
    warn("[CH2 HAY CAPTURE] Avoid capturing during the final ending.")
    return
end

local target=root.CFrame
local cameraCF=camera.CFrame
local position=target.Position
local relative=target:ToObjectSpace(cameraCF)
local function numbers(cf)
    return {cf:GetComponents()}
end
local payload={
    version=1,
    placeId=CHAPTER2,
    characterCFrame=numbers(target),
    cameraCFrame=numbers(cameraCF),
    cameraRelativeCFrame=numbers(relative),
    capturedPosition={position.X,position.Y,position.Z},
    capturedAtUnix=os.time()
}
local json=HttpService:JSONEncode(payload)
local savedTo=nil
if type(writefile)=="function" then
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end)
    end
    if pcall(writefile,SAVE_PATH,json) then
        savedTo=SAVE_PATH
    elseif pcall(writefile,BACKUP_PATH,json) then
        savedTo=BACKUP_PATH
    end
end

local components={target:GetComponents()}
local function asLuaCFrame(parts)
    local formatted={}
    for i,v in ipairs(parts) do
        formatted[i]=string.format("%.9f",v)
    end
    return "CFrame.new("..table.concat(formatted,", ")..")"
end
local view=cameraCF.LookVector
local msg=table.concat({
    "CHAPTER 2 HAY RETURN CAPTURE",
    "PlaceId="..tostring(game.PlaceId),
    "SavedFile="..tostring(savedTo or "NOT SAVED - writefile unavailable/failed"),
    ("StandingPosition=%.6f, %.6f, %.6f"):format(position.X,position.Y,position.Z),
    "CharacterCFrame="..asLuaCFrame(components),
    ("CameraLookVector=%.8f, %.8f, %.8f"):format(view.X,view.Y,view.Z),
    "CaptureJSON="..json
},"\n")
print("[CH2 HAY CAPTURE] "..msg)
if type(setclipboard)=="function" then
    local ok=pcall(setclipboard,msg)
    if ok then
        print("[CH2 HAY CAPTURE] Exact position, facing, and camera data copied to clipboard.")
    else
        warn("[CH2 HAY CAPTURE] Clipboard failed; copy the printed CaptureJSON.")
    end
else
    warn("[CH2 HAY CAPTURE] setclipboard unavailable; copy the printed CaptureJSON.")
end
if savedTo then
    print("[CH2 HAY CAPTURE] Saved destination ready for the standalone Chapter 2 puzzle test.")
else
    warn("[CH2 HAY CAPTURE] Nothing saved. Send the CaptureJSON to the developer to embed the destination.")
end
