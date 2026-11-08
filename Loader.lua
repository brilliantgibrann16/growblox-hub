--[[
    ═════════════════════════════════════════════════════════════════════════
    🌱 NYX HUB — ULTIMATE GROWBLOX SUITE (ByteNet Native Engine v2.0) 🌱
    Author : iannn (@brilliantgibrann16) • Brand: Nyx Hub
    Target : Growblox (PlaceId: 112863874972771 / Universe: 6867373977)
    Engine : 100% Keyless, Native ByteNet Packets & WorldRemotes Luau Suite
    ═════════════════════════════════════════════════════════════════════════
    [REVERSED GROUND-TRUTH NETWORKING MATRIX]:
    ★ Block Place & Break : Net.tile.send({layer, x, y, id, flip})
    ★ Tile Punch / Hit    : Net.act.send({kind = 1, x, y}) + Net.punch.send(seq)
    ★ Tree Harvesting     : Net.harvest.send({x, y})
    ★ Item Drop & Collect : Net.drop.send({id, n, x, y}) & Net.take.send({seq, uid, want})
    ★ Seed Splicing       : Net.splice.send({seq, x, y, seed})
    ★ World Flattener     : Automated 2D Grid flattener (100x60 world matrix)
    ★ Magplant Magnet     : Live scanner for Net.dropAdded / Workspace dropped parts
    ★ Anti-Staff Watchdog : Auto-hop / disconnect on dev or mod arrival
    ★ 0% GPU AFK Saver    : Midnight charcoal AFK overlay (Set3dRenderingEnabled)
    ═════════════════════════════════════════════════════════════════════════
]]--

repeat task.wait(0.2) until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.2)
    LocalPlayer = Players.LocalPlayer
end

-- ═════════════════════════════════════════════════════════════════════════
-- [1] SINGLETON SESSION TOKEN & UI TEARDOWN GUARD
-- ═════════════════════════════════════════════════════════════════════════
local _ENV = (type(getgenv) == "function" and getgenv()) or _G
local MY_SESSION_ID = HttpService:GenerateGUID(false)
_ENV.__GrowbloxHubSession = MY_SESSION_ID

if _ENV.__GrowbloxHubCleanup and type(_ENV.__GrowbloxHubCleanup) == "function" then
    pcall(_ENV.__GrowbloxHubCleanup)
end

local function cleanOldGuis()
    local targets = { LocalPlayer:FindFirstChild("PlayerGui"), CoreGui }
    for _, parent in ipairs(targets) do
        if parent then
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name:find("Rayfield") or child.Name:find("NyxGrowblox") or child.Name:find("GrowbloxHub") or child.Name == "GrowbloxInspectorUI" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end
pcall(cleanOldGuis)

-- ═════════════════════════════════════════════════════════════════════════
-- [2] REVERSED BYTENET & WORLDREMOTES BRIDGE
-- ═════════════════════════════════════════════════════════════════════════
local SharedFolder = RS:WaitForChild("Shared", 10)
local Net = nil
if SharedFolder then
    local netMod = SharedFolder:WaitForChild("Net", 5)
    if netMod and netMod:IsA("ModuleScript") then
        local s, res = pcall(require, netMod)
        if s and type(res) == "table" then
            Net = res
        end
    end
end

local WorldRemotes = RS:FindFirstChild("WorldRemotes")

-- ═════════════════════════════════════════════════════════════════════════
-- [3] CONFIGURATION SCHEMA & PERSISTENCE
-- ═════════════════════════════════════════════════════════════════════════
local CONFIG_FILE = "NyxGrowblox_Config_" .. tostring(LocalPlayer.UserId) .. ".json"

_G.GrowbloxConfig = {
    -- PnB (Place and Break)
    AutoPnB = false,
    PnBMode = "In Front (1 Tile)", -- "In Front (1 Tile)", "Double (2 Tile)", "Surrounding (3x3)"
    PnBDelay = 0.15,
    SelectedBlockId = 1, -- 1 = Dirt, 2 = Rock, etc.
    PunchKind = 1,

    -- Farm & Trees
    AutoHarvest = false,
    AutoPlant = false,
    HarvestRadius = 30,
    SelectedSeedId = 1,

    -- World Clearing (Dirt Flattener)
    AutoClearWorld = false,
    ClearDirt = true,
    ClearRock = true,
    ClearLava = true,
    ClearRadius = 25,

    -- Item Magnet / Magplant
    ItemMagnet = false,
    MagnetRadius = 60,

    -- Auto World Hopper & World Rotator
    AutoWorldHop = false,
    WorldListText = "START, FARM1, FARM2, GEMS1",
    WorldHopInterval = 180, -- Seconds per world before hopping to next
    RandomWorldPrefix = "FARM",
    RandomWorldHop = false,
    AutoClearOnEnter = true,
    AutoHarvestOnEnter = true,
    AutoCollectOnEnter = true,

    -- Player & Physics
    WalkSpeed = 16,
    JumpPower = 50,
    CustomSpeedEnabled = false,
    CustomJumpEnabled = false,
    Noclip = false,
    InfiniteJump = false,

    -- Security & Watchdog
    AntiStaff = true,
    StaffAction = "Notify Only", -- "Notify Only", "Server Hop", "Disconnect"
    AntiAFK = true,
    DarkGpuSaver = false,

    -- Spy
    SpyEnabled = true,
}

local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function()
        local encoded = HttpService:JSONEncode(_G.GrowbloxConfig)
        writefile(CONFIG_FILE, encoded)
    end)
end

local function loadConfig()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    pcall(function()
        if isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if _G.GrowbloxConfig[k] ~= nil then
                        _G.GrowbloxConfig[k] = v
                    end
                end
            end
        end
    end)
end
loadConfig()

-- ═════════════════════════════════════════════════════════════════════════
-- [4] GROUND-TRUTH COORDINATE & TILE CONVERTER
-- ═════════════════════════════════════════════════════════════════════════
-- Growblox standard 2D world tiles: 1 block = 3.2 studs (or 3 studs).
local TILE_SIZE = 3.2
local WORLD_ORIGIN_X = 0
local WORLD_ORIGIN_Y = 0

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function worldPosToTile(pos)
    local tx = math.floor((pos.X - WORLD_ORIGIN_X) / TILE_SIZE + 0.5)
    local ty = math.floor((pos.Y - WORLD_ORIGIN_Y) / TILE_SIZE + 0.5)
    return math.clamp(tx, 0, 100), math.clamp(ty, 0, 60)
end

local function tileToWorldPos(tx, ty)
    return Vector3.new(tx * TILE_SIZE + WORLD_ORIGIN_X, ty * TILE_SIZE + WORLD_ORIGIN_Y, 0)
end

-- ═════════════════════════════════════════════════════════════════════════
-- [5] NATIVE ACTION DISPATCHERS (BYTENET + FALLBACK)
-- ═════════════════════════════════════════════════════════════════════════
local ActionSeq = 0

-- 1. PUNCH / BREAK BLOCK OR HIT TILE
local function sendPunch(tileX, tileY)
    ActionSeq = (ActionSeq + 1) % 65535
    -- Dispatch native ByteNet packet
    if Net then
        pcall(function()
            if Net.act and Net.act.send then
                Net.act.send({
                    kind = _G.GrowbloxConfig.PunchKind or 1,
                    x = tileX * TILE_SIZE,
                    y = tileY * TILE_SIZE
                })
            end
            if Net.punch and Net.punch.send then
                Net.punch.send(ActionSeq)
            end
        end)
    end

    -- Dual-channel fallback: WorldRemotes
    if WorldRemotes and WorldRemotes:FindFirstChild("PunchPlayer") then
        pcall(function()
            WorldRemotes.PunchPlayer:FireServer(tileX, tileY)
        end)
    end
end

-- 2. PLACE TILE / BLOCK (layer 1 = foreground block, layer 0 = background wallpaper)
local function sendPlaceTile(tileX, tileY, blockId, layer)
    layer = layer or 1
    blockId = blockId or _G.GrowbloxConfig.SelectedBlockId or 1

    if Net and Net.tile and Net.tile.send then
        pcall(function()
            Net.tile.send({
                layer = layer,
                x = tileX,
                y = tileY,
                id = blockId,
                flip = false
            })
        end)
    end

    -- Dual-channel fallback
    if WorldRemotes and WorldRemotes:FindFirstChild("SetTile") then
        pcall(function()
            WorldRemotes.SetTile:FireServer(layer, tileX, tileY, blockId, false)
        end)
    end
end

-- 3. HARVEST TREE
local function sendHarvest(tileX, tileY)
    if Net and Net.harvest and Net.harvest.send then
        pcall(function()
            Net.harvest.send({
                x = tileX,
                y = tileY
            })
        end)
    end

    if WorldRemotes and WorldRemotes:FindFirstChild("HarvestProvider") then
        pcall(function()
            WorldRemotes.HarvestProvider:FireServer(tileX, tileY)
        end)
    end
end

-- 4. TAKE DROPPED ITEM
local function sendTakeDrop(dropUid, wantAmount)
    ActionSeq = (ActionSeq + 1) % 65535
    wantAmount = wantAmount or 1

    if Net and Net.take and Net.take.send then
        pcall(function()
            Net.take.send({
                seq = ActionSeq,
                uid = dropUid,
                want = wantAmount
            })
        end)
    end

    if WorldRemotes and WorldRemotes:FindFirstChild("TakeDrop") then
        pcall(function()
            WorldRemotes.TakeDrop:InvokeServer(dropUid)
        end)
    end
end

-- 5. WORLD HOPPING & ENTER WORLD DISPATCHER
local function sendEnterWorld(worldName)
    worldName = tostring(worldName or ""):upper():gsub("%s+", "")
    if worldName == "" then return end

    -- Channel 1: Net.CALLS.SwapWorld via Net.call
    if Net and type(Net.call) == "function" then
        pcall(function()
            Net.call("SwapWorld", worldName)
        end)
    end

    -- Channel 2: WorldRemotes.EnterWorld / SwapWorld
    if WorldRemotes then
        if WorldRemotes:FindFirstChild("EnterWorld") then
            pcall(function()
                WorldRemotes.EnterWorld:InvokeServer(worldName)
            end)
        elseif WorldRemotes:FindFirstChild("SwapWorld") then
            pcall(function()
                WorldRemotes.SwapWorld:InvokeServer(worldName)
            end)
        end
    end
end

-- ═════════════════════════════════════════════════════════════════════════
-- [6] CORE GROWTOPIA AUTOMATION WORKERS
-- ═════════════════════════════════════════════════════════════════════════

-- [WORKER 1: PnB (Place and Break) Native Loop]
task.spawn(function()
    while true do
        task.wait(_G.GrowbloxConfig.PnBDelay or 0.15)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoPnB then
            local hrp = getHRP()
            if hrp then
                local currentTileX, currentTileY = worldPosToTile(hrp.Position)
                local lookVec = hrp.CFrame.LookVector
                local forwardTileX = currentTileX + (lookVec.X >= 0 and 1 or -1)
                local forwardTileY = currentTileY

                -- Mode 1: In Front (1 Tile)
                sendPlaceTile(forwardTileX, forwardTileY, _G.GrowbloxConfig.SelectedBlockId or 1, 1)
                task.wait(0.04)
                sendPunch(forwardTileX, forwardTileY)

                -- Mode 2: Double (2 Tile Horizontal)
                if _G.GrowbloxConfig.PnBMode == "Double (2 Tile)" then
                    local secondTileX = currentTileX + (lookVec.X >= 0 and 2 or -2)
                    sendPlaceTile(secondTileX, forwardTileY, _G.GrowbloxConfig.SelectedBlockId or 1, 1)
                    task.wait(0.02)
                    sendPunch(secondTileX, forwardTileY)

                -- Mode 3: Surrounding (3x3 Perimeter)
                elseif _G.GrowbloxConfig.PnBMode == "Surrounding (3x3)" then
                    for dx = -1, 1 do
                        for dy = -1, 1 do
                            if dx ~= 0 or dy ~= 0 then
                                local targetX = currentTileX + dx
                                local targetY = currentTileY + dy
                                sendPlaceTile(targetX, targetY, _G.GrowbloxConfig.SelectedBlockId or 1, 1)
                                sendPunch(targetX, targetY)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- [WORKER 2: Auto Harvest Ready Trees]
task.spawn(function()
    while true do
        task.wait(0.5)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoHarvest then
            local hrp = getHRP()
            if hrp then
                local playerTileX, playerTileY = worldPosToTile(hrp.Position)
                local rad = math.floor((_G.GrowbloxConfig.HarvestRadius or 30) / TILE_SIZE)

                for dx = -rad, rad do
                    for dy = -rad, rad do
                        if not _G.GrowbloxConfig.AutoHarvest then break end
                        local targetX = playerTileX + dx
                        local targetY = playerTileY + dy
                        -- Check proximity
                        if math.sqrt(dx*dx + dy*dy) <= rad then
                            sendHarvest(targetX, targetY)
                            sendPunch(targetX, targetY)
                        end
                    end
                end
            end
        end
    end
end)

-- [WORKER 3: Auto Plant Seeds]
task.spawn(function()
    while true do
        task.wait(0.35)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoPlant then
            local hrp = getHRP()
            if hrp then
                local currentTileX, currentTileY = worldPosToTile(hrp.Position)
                -- Plant on tile below player
                local plantTileY = currentTileY - 1
                sendPlaceTile(currentTileX, plantTileY, _G.GrowbloxConfig.SelectedSeedId or 1, 1)
            end
        end
    end
end)

-- [WORKER 4: Magplant / Instant Item Magnet]
task.spawn(function()
    while true do
        task.wait(0.25)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.ItemMagnet then
            local hrp = getHRP()
            if hrp then
                -- Vacuum floating objects in workspace
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if not _G.GrowbloxConfig.ItemMagnet then break end
                    local name = obj.Name:lower()
                    if name:find("drop") or name:find("gem") or name:find("seed") or name:find("item") then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and (part.Position - hrp.Position).Magnitude <= (_G.GrowbloxConfig.MagnetRadius or 60) then
                            local uid = obj:GetAttribute("uid") or obj:GetAttribute("UID") or 1
                            sendTakeDrop(uid, 1)
                            pcall(function()
                                part.CFrame = hrp.CFrame
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- [WORKER 5: Auto Clear World (Dirt Farm Flattener)]
task.spawn(function()
    while true do
        task.wait(0.2)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoClearWorld then
            local hrp = getHRP()
            if hrp then
                local currentTileX, currentTileY = worldPosToTile(hrp.Position)
                local rad = math.floor((_G.GrowbloxConfig.ClearRadius or 25) / TILE_SIZE)

                for dy = rad, -rad, -1 do
                    for dx = -rad, rad do
                        if not _G.GrowbloxConfig.AutoClearWorld then break end
                        local targetX = currentTileX + dx
                        local targetY = currentTileY + dy
                        sendPunch(targetX, targetY)
                    end
                end
            end
        end
    end
end)

-- [WORKER 6: Anti-Staff & Mod Watchdog]
local StaffKeywords = { "owner", "admin", "mod", "executive", "developer", "importanfarhan", "staff" }
local function isStaffMember(player)
    if player == LocalPlayer then return false end
    local name = player.Name:lower()
    local display = player.DisplayName:lower()

    for _, kw in ipairs(StaffKeywords) do
        if name:find(kw) or display:find(kw) then
            return true
        end
    end

    local isHighRank = false
    pcall(function()
        if player:IsInGroup(34900000) or player:GetRankInGroup(34900000) > 100 then
            isHighRank = true
        end
    end)
    return isHighRank
end

local function handleStaffDetected(staffPlayer)
    if not _G.GrowbloxConfig.AntiStaff then return end
    warn("[Anti-Staff] Staff detected: " .. staffPlayer.Name)

    if _G.GrowbloxConfig.StaffAction == "Server Hop" then
        task.spawn(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    elseif _G.GrowbloxConfig.StaffAction == "Disconnect" then
        LocalPlayer:Kick("[Nyx Hub] Staff member detected: " .. staffPlayer.Name)
    end
end

Players.PlayerAdded:Connect(function(player)
    if isStaffMember(player) then
        handleStaffDetected(player)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if isStaffMember(p) then
        handleStaffDetected(p)
    end
end

-- [WORKER 6.1: Auto World Hopper & Infinite World Rotator]
task.spawn(function()
    local currentWorldIndex = 1
    while true do
        task.wait(1)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoWorldHop then
            local interval = _G.GrowbloxConfig.WorldHopInterval or 180
            for sec = 1, interval do
                task.wait(1)
                if not _G.GrowbloxConfig.AutoWorldHop or _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then
                    break
                end
            end

            if _G.GrowbloxConfig.AutoWorldHop then
                local targetWorld = ""
                if _G.GrowbloxConfig.RandomWorldHop then
                    local prefix = _G.GrowbloxConfig.RandomWorldPrefix or "FARM"
                    targetWorld = prefix .. tostring(math.random(100, 9999))
                else
                    local rawList = _G.GrowbloxConfig.WorldListText or ""
                    local worlds = {}
                    for w in rawList:gmatch("[^,%s]+") do
                        table.insert(worlds, w)
                    end
                    if #worlds > 0 then
                        currentWorldIndex = ((currentWorldIndex - 1) % #worlds) + 1
                        targetWorld = worlds[currentWorldIndex]
                        currentWorldIndex = currentWorldIndex + 1
                    end
                end

                if targetWorld ~= "" then
                    warn("[Nyx Hub] Auto-Hopping to World: " .. targetWorld)
                    sendEnterWorld(targetWorld)
                    task.wait(5)
                end
            end
        end
    end
end)

-- [WORKER 7: Character Physics, Noclip & Respawn Reapplication]
RunService.Stepped:Connect(function()
    if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then return end
    if _G.GrowbloxConfig.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

local function applyPlayerPhysics()
    local hum = getHumanoid()
    if hum then
        if _G.GrowbloxConfig.CustomSpeedEnabled then
            hum.WalkSpeed = _G.GrowbloxConfig.WalkSpeed or 16
        end
        if _G.GrowbloxConfig.CustomJumpEnabled then
            hum.JumpPower = _G.GrowbloxConfig.JumpPower or 50
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyPlayerPhysics()
end)

UserInputService.JumpRequest:Connect(function()
    if _G.GrowbloxConfig.InfiniteJump then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- [WORKER 8: Permanent Anti-AFK Heartbeat]
LocalPlayer.Idled:Connect(function()
    if _G.GrowbloxConfig.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

task.spawn(function()
    while true do
        task.wait(45)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end
        if _G.GrowbloxConfig.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(50, 50))
            end)
        end
    end
end)

-- [WORKER 10: Auto-Execute on Teleport / Server Hop & Solara Anti-Crash]
local function setupAutoExecuteOnTeleport()
    local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (_ENV and _ENV.queueonteleport)
    if type(qot) == "function" then
        local payload = 'repeat task.wait(0.2) until game:IsLoaded() task.wait(1.5) loadstring(game:HttpGet("https://raw.githubusercontent.com/brilliantgibrann16/growblox-hub/main/Loader.lua"))()'
        pcall(qot, payload)
    end
end
LocalPlayer.OnTeleport:Connect(function()
    setupAutoExecuteOnTeleport()
end)

-- Solara v3 Compatibility Bridge: Auto queue on world swap
setupAutoExecuteOnTeleport()
local DarkFrame = nil
local function toggleDarkGpuSaver(enable)
    if enable then
        RunService:Set3dRenderingEnabled(false)
        if not DarkFrame then
            local sg = Instance.new("ScreenGui")
            sg.Name = "NyxDarkGpuSaver"
            sg.IgnoreGuiInset = true
            sg.ResetOnSpawn = false
            sg.DisplayOrder = 999999

            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 1, 0)
            f.BackgroundColor3 = Color3.fromRGB(11, 15, 23)
            f.BorderSizePixel = 0
            f.Parent = sg

            local lbl = Instance.new("TextLabel")
            lbl.Text = "🌙 NYX HUB — 0% GPU AFK MODE ACTIVE\n(Tap toggle to restore 3D viewport)"
            lbl.TextColor3 = Color3.fromRGB(130, 200, 255)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 16
            lbl.Size = UDim2.new(1, 0, 0, 80)
            lbl.Position = UDim2.new(0, 0, 0.5, -40)
            lbl.BackgroundTransparency = 1
            lbl.Parent = f

            local parent = CoreGui or LocalPlayer:FindFirstChild("PlayerGui")
            if parent then sg.Parent = parent end
            DarkFrame = sg
        end
    else
        RunService:Set3dRenderingEnabled(true)
        if DarkFrame then
            DarkFrame:Destroy()
            DarkFrame = nil
        end
    end
end

-- ═════════════════════════════════════════════════════════════════════════
-- [7] RAYFIELD LIQUID GLASS UI (31-KEY COLOR SPEC)
-- ═════════════════════════════════════════════════════════════════════════
local LiquidGlassTheme = {
    TextColor = Color3.fromRGB(240, 245, 255),
    Background = Color3.fromRGB(15, 20, 32),
    Topbar = Color3.fromRGB(18, 26, 44),
    Shadow = Color3.fromRGB(5, 8, 14),
    NotificationBackground = Color3.fromRGB(20, 30, 50),
    NotificationActionsBackground = Color3.fromRGB(30, 45, 75),
    TabBackground = Color3.fromRGB(20, 28, 46),
    TabStroke = Color3.fromRGB(40, 60, 100),
    TabBackgroundSelected = Color3.fromRGB(35, 55, 90),
    TabTextColor = Color3.fromRGB(170, 190, 225),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),
    ElementBackground = Color3.fromRGB(20, 30, 50),
    ElementBackgroundHover = Color3.fromRGB(28, 42, 70),
    ElementStroke = Color3.fromRGB(45, 70, 115),
    ElementTextColor = Color3.fromRGB(240, 245, 255),
    SecondaryElementBackground = Color3.fromRGB(25, 38, 62),
    SecondaryElementStroke = Color3.fromRGB(50, 78, 125),
    SecondaryElementTextColor = Color3.fromRGB(190, 210, 240),
    SliderBackground = Color3.fromRGB(28, 42, 68),
    SliderProgress = Color3.fromRGB(70, 150, 255),
    SliderStroke = Color3.fromRGB(55, 85, 140),
    ToggleBackground = Color3.fromRGB(28, 42, 68),
    ToggleEnabled = Color3.fromRGB(70, 150, 255),
    ToggleDisabled = Color3.fromRGB(45, 55, 75),
    ToggleEnabledStroke = Color3.fromRGB(100, 180, 255),
    ToggleDisabledStroke = Color3.fromRGB(60, 75, 95),
    ToggleEnabledOuterStroke = Color3.fromRGB(80, 160, 255),
    ToggleDisabledOuterStroke = Color3.fromRGB(50, 65, 85),
    DropdownSelected = Color3.fromRGB(35, 55, 90),
    DropdownUnselected = Color3.fromRGB(20, 30, 50),
    InputBackground = Color3.fromRGB(22, 32, 54),
}

local Rayfield = nil
local s, res = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
end)
if s and res then
    Rayfield = res
end

if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "🌱 Nyx Hub — Growblox ByteNet Suite v2.0",
        LoadingTitle = "Nyx Hub Growblox",
        LoadingSubtitle = "by iannn (@brilliantgibrann16)",
        ConfigurationSaving = {
            Enabled = false,
        },
        KeySystem = false,
        Theme = LiquidGlassTheme,
    })

    -- ─────────────────────────────────────────────────────────────────
    -- [TAB 1: FARM & PnB]
    -- ─────────────────────────────────────────────────────────────────
    local FarmTab = Window:CreateTab("🌾 PnB & Farm", 4483362458)

    FarmTab:CreateSection("Place and Break (Native ByteNet)")
    FarmTab:CreateToggle({
        Name = "Auto PnB (Auto Place & Break)",
        CurrentValue = _G.GrowbloxConfig.AutoPnB,
        Flag = "AutoPnB",
        Callback = function(val)
            _G.GrowbloxConfig.AutoPnB = val
            saveConfig()
        end,
    })

    FarmTab:CreateDropdown({
        Name = "PnB Mode",
        Options = { "In Front (1 Tile)", "Double (2 Tile)", "Surrounding (3x3)" },
        CurrentOption = { _G.GrowbloxConfig.PnBMode },
        MultipleOptions = false,
        Flag = "PnBMode",
        Callback = function(val)
            _G.GrowbloxConfig.PnBMode = val[1]
            saveConfig()
        end,
    })

    FarmTab:CreateSlider({
        Name = "PnB Delay (s)",
        Range = { 0.05, 0.5 },
        Increment = 0.01,
        Suffix = "s",
        CurrentValue = _G.GrowbloxConfig.PnBDelay,
        Flag = "PnBDelay",
        Callback = function(val)
            _G.GrowbloxConfig.PnBDelay = val
            saveConfig()
        end,
    })

    FarmTab:CreateSlider({
        Name = "Selected Block ID",
        Range = { 1, 20 },
        Increment = 1,
        CurrentValue = _G.GrowbloxConfig.SelectedBlockId,
        Flag = "SelectedBlockId",
        Callback = function(val)
            _G.GrowbloxConfig.SelectedBlockId = val
            saveConfig()
        end,
    })

    FarmTab:CreateSection("Trees & Harvest")
    FarmTab:CreateToggle({
        Name = "Auto Harvest Trees (Native Net.harvest)",
        CurrentValue = _G.GrowbloxConfig.AutoHarvest,
        Flag = "AutoHarvest",
        Callback = function(val)
            _G.GrowbloxConfig.AutoHarvest = val
            saveConfig()
        end,
    })

    FarmTab:CreateToggle({
        Name = "Auto Plant Seeds (Below Player)",
        CurrentValue = _G.GrowbloxConfig.AutoPlant,
        Flag = "AutoPlant",
        Callback = function(val)
            _G.GrowbloxConfig.AutoPlant = val
            saveConfig()
        end,
    })

    FarmTab:CreateSlider({
        Name = "Harvest Scan Radius",
        Range = { 10, 80 },
        Increment = 5,
        Suffix = " studs",
        CurrentValue = _G.GrowbloxConfig.HarvestRadius,
        Flag = "HarvestRadius",
        Callback = function(val)
            _G.GrowbloxConfig.HarvestRadius = val
            saveConfig()
        end,
    })

    -- ─────────────────────────────────────────────────────────────────
    -- [TAB 2: WORLD CLEAR & MAGNET]
    -- ─────────────────────────────────────────────────────────────────
    local WorldTab = Window:CreateTab("🌍 World & Magnet", 4483362458)

    WorldTab:CreateSection("Auto Clear World (Dirt Farm Flattener)")
    WorldTab:CreateToggle({
        Name = "Auto Clear World",
        CurrentValue = _G.GrowbloxConfig.AutoClearWorld,
        Flag = "AutoClearWorld",
        Callback = function(val)
            _G.GrowbloxConfig.AutoClearWorld = val
            saveConfig()
        end,
    })

    WorldTab:CreateSlider({
        Name = "Clear Grid Radius",
        Range = { 10, 50 },
        Increment = 5,
        Suffix = " studs",
        CurrentValue = _G.GrowbloxConfig.ClearRadius,
        Flag = "ClearRadius",
        Callback = function(val)
            _G.GrowbloxConfig.ClearRadius = val
            saveConfig()
        end,
    })

    WorldTab:CreateSection("Item Magnet (Magplant Vacuum)")
    WorldTab:CreateToggle({
        Name = "Item Magnet (Net.take + Suction)",
        CurrentValue = _G.GrowbloxConfig.ItemMagnet,
        Flag = "ItemMagnet",
        Callback = function(val)
            _G.GrowbloxConfig.ItemMagnet = val
            saveConfig()
        end,
    })

    WorldTab:CreateSlider({
        Name = "Magnet Range",
        Range = { 20, 150 },
        Increment = 10,
        Suffix = " studs",
        CurrentValue = _G.GrowbloxConfig.MagnetRadius,
        Flag = "MagnetRadius",
        Callback = function(val)
            _G.GrowbloxConfig.MagnetRadius = val
            saveConfig()
        end,
    })

    -- ─────────────────────────────────────────────────────────────────
    -- [TAB 3: AUTO ROTATOR / WORLD HOPPER]
    -- ─────────────────────────────────────────────────────────────────
    local HopTab = Window:CreateTab("🌐 World Rotator", 4483362458)

    HopTab:CreateSection("Auto World Hopper (Tinggal Diem AFK)")
    HopTab:CreateToggle({
        Name = "Enable Auto World Rotator",
        CurrentValue = _G.GrowbloxConfig.AutoWorldHop,
        Flag = "AutoWorldHop",
        Callback = function(val)
            _G.GrowbloxConfig.AutoWorldHop = val
            saveConfig()
        end,
    })

    HopTab:CreateInput({
        Name = "World List (Pisahkan Koma)",
        PlaceholderText = "FARM1, FARM2, GEMS1",
        RemoveTextAfterFocusLost = false,
        CurrentValue = _G.GrowbloxConfig.WorldListText,
        Flag = "WorldListText",
        Callback = function(val)
            _G.GrowbloxConfig.WorldListText = val
            saveConfig()
        end,
    })

    HopTab:CreateSlider({
        Name = "Waktu per World (Detik)",
        Range = { 30, 600 },
        Increment = 10,
        Suffix = "s",
        CurrentValue = _G.GrowbloxConfig.WorldHopInterval,
        Flag = "WorldHopInterval",
        Callback = function(val)
            _G.GrowbloxConfig.WorldHopInterval = val
            saveConfig()
        end,
    })

    HopTab:CreateSection("Random World Discovery (Cari World Kosong)")
    HopTab:CreateToggle({
        Name = "Random World Hop (Auto Prefix)",
        CurrentValue = _G.GrowbloxConfig.RandomWorldHop,
        Flag = "RandomWorldHop",
        Callback = function(val)
            _G.GrowbloxConfig.RandomWorldHop = val
            saveConfig()
        end,
    })

    HopTab:CreateInput({
        Name = "Random World Prefix",
        PlaceholderText = "FARM",
        RemoveTextAfterFocusLost = false,
        CurrentValue = _G.GrowbloxConfig.RandomWorldPrefix,
        Flag = "RandomWorldPrefix",
        Callback = function(val)
            _G.GrowbloxConfig.RandomWorldPrefix = val
            saveConfig()
        end,
    })

    -- ─────────────────────────────────────────────────────────────────
    -- [TAB 4: MOVEMENT & PHYSICS]
    -- ─────────────────────────────────────────────────────────────────
    local MoveTab = Window:CreateTab("⚡ Movement", 4483362458)

    MoveTab:CreateSection("2D Movement & Physics")
    MoveTab:CreateToggle({
        Name = "Tile Noclip (Pass Through Blocks)",
        CurrentValue = _G.GrowbloxConfig.Noclip,
        Flag = "Noclip",
        Callback = function(val)
            _G.GrowbloxConfig.Noclip = val
            saveConfig()
        end,
    })

    MoveTab:CreateToggle({
        Name = "Infinite Jump",
        CurrentValue = _G.GrowbloxConfig.InfiniteJump,
        Flag = "InfiniteJump",
        Callback = function(val)
            _G.GrowbloxConfig.InfiniteJump = val
            saveConfig()
        end,
    })

    MoveTab:CreateToggle({
        Name = "Custom WalkSpeed",
        CurrentValue = _G.GrowbloxConfig.CustomSpeedEnabled,
        Flag = "CustomSpeedEnabled",
        Callback = function(val)
            _G.GrowbloxConfig.CustomSpeedEnabled = val
            applyPlayerPhysics()
            saveConfig()
        end,
    })

    MoveTab:CreateSlider({
        Name = "WalkSpeed Value",
        Range = { 16, 100 },
        Increment = 2,
        CurrentValue = _G.GrowbloxConfig.WalkSpeed,
        Flag = "WalkSpeed",
        Callback = function(val)
            _G.GrowbloxConfig.WalkSpeed = val
            applyPlayerPhysics()
            saveConfig()
        end,
    })

    MoveTab:CreateToggle({
        Name = "Custom JumpPower",
        CurrentValue = _G.GrowbloxConfig.CustomJumpEnabled,
        Flag = "CustomJumpEnabled",
        Callback = function(val)
            _G.GrowbloxConfig.CustomJumpEnabled = val
            applyPlayerPhysics()
            saveConfig()
        end,
    })

    MoveTab:CreateSlider({
        Name = "JumpPower Value",
        Range = { 50, 150 },
        Increment = 5,
        CurrentValue = _G.GrowbloxConfig.JumpPower,
        Flag = "JumpPower",
        Callback = function(val)
            _G.GrowbloxConfig.JumpPower = val
            applyPlayerPhysics()
            saveConfig()
        end,
    })

    -- ─────────────────────────────────────────────────────────────────
    -- [TAB 5: SECURITY & AFK]
    -- ─────────────────────────────────────────────────────────────────
    local SecTab = Window:CreateTab("🛡️ Security & AFK", 4483362458)

    SecTab:CreateSection("Anti-Staff Protection")
    SecTab:CreateToggle({
        Name = "Anti-Staff Watchdog",
        CurrentValue = _G.GrowbloxConfig.AntiStaff,
        Flag = "AntiStaff",
        Callback = function(val)
            _G.GrowbloxConfig.AntiStaff = val
            saveConfig()
        end,
    })

    SecTab:CreateDropdown({
        Name = "Action on Staff Join",
        Options = { "Notify Only", "Server Hop", "Disconnect" },
        CurrentOption = { _G.GrowbloxConfig.StaffAction },
        MultipleOptions = false,
        Flag = "StaffAction",
        Callback = function(val)
            _G.GrowbloxConfig.StaffAction = val[1]
            saveConfig()
        end,
    })

    SecTab:CreateSection("AFK & 0% GPU")
    SecTab:CreateToggle({
        Name = "Permanent Anti-AFK",
        CurrentValue = _G.GrowbloxConfig.AntiAFK,
        Flag = "AntiAFK",
        Callback = function(val)
            _G.GrowbloxConfig.AntiAFK = val
            saveConfig()
        end,
    })

    SecTab:CreateToggle({
        Name = "Dark 0% GPU Saver (Potato AFK)",
        CurrentValue = _G.GrowbloxConfig.DarkGpuSaver,
        Flag = "DarkGpuSaver",
        Callback = function(val)
            _G.GrowbloxConfig.DarkGpuSaver = val
            toggleDarkGpuSaver(val)
            saveConfig()
        end,
    })

    SecTab:CreateButton({
        Name = "Server Hop",
        Callback = function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end,
    })

    Rayfield:Notify({
        Title = "Nyx Hub Growblox Loaded!",
        Content = "ByteNet Native Engine v2.0 Active.",
        Duration = 4,
    })
end

-- Cleanup handler for re-injects
_ENV.__GrowbloxHubCleanup = function()
    pcall(cleanOldGuis)
    if DarkFrame then
        pcall(function() DarkFrame:Destroy() end)
    end
end
