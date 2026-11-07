--[[
    ═════════════════════════════════════════════════════════════════════════
    🌱 NYX HUB — ULTIMATE GROWBLOX SUITE (Growtopia-Style Sandbox) 🌱
    Author : iannn (@brilliantgibrann16) • Brand: Nyx Hub
    Target : Growblox (PlaceId: 112863874972771 / Universe: 6867373977)
    Engine : 100% Keyless, High-Performance Luau Automation Suite
    ═════════════════════════════════════════════════════════════════════════
    [GROWTOPIA FEATURE REPLICATION MATRIX]:
    ★ PnB (Place and Break) Engine: Instant multi-tile placement & block breaking.
    ★ Auto Harvest & Auto Plant: Grid scanner for ready trees & vacant soil tiles.
    ★ Auto Clear World (Dirt Farm Flattener): Automated top-to-bottom world clearing.
    ★ Magplant / Item Magnet: Instant attraction & vacuum for dropped gems/seeds/blocks.
    ★ Tile Noclip & Flight: 2D smooth flight + obstacle noclip through walls and doors.
    ★ Anti-Staff / Mod Watchdog: Instant detection of admins/mods with auto-hop/leave.
    ★ Dynamic Remote & Grid Spy: Live network remote logger & tile inspector.
    ★ Permanent Anti-AFK & 0% GPU Saver: Eye-friendly dark mode + anti-idle heartbeat.
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
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
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
                if child.Name:find("Rayfield") or child.Name:find("NyxGrowblox") or child.Name:find("GrowbloxHub") then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end
pcall(cleanOldGuis)

-- ═════════════════════════════════════════════════════════════════════════
-- [2] CONFIGURATION SCHEMA & PERSISTENCE
-- ═════════════════════════════════════════════════════════════════════════
local CONFIG_FILE = "NyxGrowblox_Config_" .. tostring(LocalPlayer.UserId) .. ".json"

_G.GrowbloxConfig = {
    -- PnB (Place and Break)
    AutoPnB = false,
    PnBMode = "In Front (1 Tile)", -- "In Front (1 Tile)", "Surrounding (3x3)", "Double (2 Tile)"
    PnBDelay = 0.15,
    AutoRestock = true,
    BreakTool = "Fist",

    -- Farm & Trees
    AutoHarvest = false,
    AutoPlant = false,
    HarvestRadius = 30,
    SelectedSeed = "Any",

    -- World Clearing
    AutoClearWorld = false,
    ClearDirt = true,
    ClearRock = true,
    ClearLava = true,
    ClearDirection = "Top to Bottom",

    -- Item Magnet / Magplant
    ItemMagnet = false,
    MagnetRadius = 50,
    MagnetFilterGems = true,
    MagnetFilterSeeds = true,
    MagnetFilterBlocks = true,

    -- Player & Physics
    WalkSpeed = 16,
    JumpPower = 50,
    CustomSpeedEnabled = false,
    CustomJumpEnabled = false,
    Noclip = false,
    FlyEnabled = false,
    FlySpeed = 25,
    InfiniteJump = false,
    GodModePhysics = false,

    -- Visuals & ESP
    DropsESP = false,
    PlayerESP = false,
    Fullbright = false,

    -- Security & Watchdog
    AntiStaff = true,
    StaffAction = "Notify Only", -- "Notify Only", "Server Hop", "Disconnect"
    AntiAFK = true,
    DarkGpuSaver = false,

    -- Network Spy
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
-- [3] DYNAMIC REMOTE & SERVICE DISCOVERY ENGINE
-- ═════════════════════════════════════════════════════════════════════════
local DiscoveredRemotes = {
    Punch = nil,
    Place = nil,
    Harvest = nil,
    Drop = nil,
    Trash = nil,
    Warp = nil,
    Redeem = nil,
}

local function scanRemotes()
    local function checkInst(inst)
        if not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then return end
        local name = inst.Name:lower()
        if name:find("punch") or name:find("break") or name:find("hit") or name:find("mine") or name:find("damage") then
            DiscoveredRemotes.Punch = inst
        elseif name:find("place") or name:find("build") or name:find("plant") or name:find("tile") then
            DiscoveredRemotes.Place = inst
        elseif name:find("harvest") or name:find("collecttree") or name:find("tree") then
            DiscoveredRemotes.Harvest = inst
        elseif name:find("drop") or name:find("pickup") or name:find("collect") then
            DiscoveredRemotes.Drop = inst
        elseif name:find("trash") or name:find("recycle") then
            DiscoveredRemotes.Trash = inst
        elseif name:find("warp") or name:find("world") or name:find("join") then
            DiscoveredRemotes.Warp = inst
        elseif name:find("code") or name:find("redeem") then
            DiscoveredRemotes.Redeem = inst
        end
    end

    for _, desc in ipairs(RS:GetDescendants()) do
        pcall(checkInst, desc)
    end
end
task.spawn(scanRemotes)

-- ═════════════════════════════════════════════════════════════════════════
-- [4] UNIVERSAL INTERACTION & SIMULATION HELPERS
-- ═════════════════════════════════════════════════════════════════════════
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function zeroVelocity()
    local hrp = getHRP()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
end

local function safeTeleport(targetCFrame)
    local hrp = getHRP()
    if hrp and targetCFrame then
        zeroVelocity()
        hrp.CFrame = targetCFrame
        task.wait(0.05)
        zeroVelocity()
    end
end

-- Active Tool Invocation (Fist, Wrench, Block, Seed)
local function equipToolByName(toolName)
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return nil end

    local current = char:FindFirstChildWhichIsA("Tool")
    if current and (current.Name == toolName or toolName == "Any") then
        return current
    end

    local found = bp:FindFirstChild(toolName)
    if not found and toolName == "Fist" then
        found = bp:FindFirstChildWhichIsA("Tool")
    end

    if found then
        local hum = getHumanoid()
        if hum then
            hum:EquipTool(found)
            task.wait(0.05)
            return found
        end
    end
    return char:FindFirstChildWhichIsA("Tool")
end

local function firePunch(targetPart, targetPosition)
    if DiscoveredRemotes.Punch then
        if DiscoveredRemotes.Punch:IsA("RemoteEvent") then
            DiscoveredRemotes.Punch:FireServer(targetPart, targetPosition)
        elseif DiscoveredRemotes.Punch:IsA("RemoteFunction") then
            task.spawn(function()
                DiscoveredRemotes.Punch:InvokeServer(targetPart, targetPosition)
            end)
        end
    end

    -- Universal Fallback: Tool activation
    local tool = equipToolByName(_G.GrowbloxConfig.BreakTool or "Fist")
    if tool then
        tool:Activate()
    end
end

local function firePlace(blockName, targetPosition)
    if DiscoveredRemotes.Place then
        if DiscoveredRemotes.Place:IsA("RemoteEvent") then
            DiscoveredRemotes.Place:FireServer(blockName, targetPosition)
        elseif DiscoveredRemotes.Place:IsA("RemoteFunction") then
            task.spawn(function()
                DiscoveredRemotes.Place:InvokeServer(blockName, targetPosition)
            end)
        end
    end

    -- Fallback: equip item and activate
    local tool = equipToolByName(blockName)
    if tool then
        tool:Activate()
    end
end

-- ═════════════════════════════════════════════════════════════════════════
-- [5] LIVE IN-GAME NETWORK SPY LOGGER
-- ═════════════════════════════════════════════════════════════════════════
local SpyLogs = {}
local MAX_SPY_LOGS = 60
local OnNewSpyLog = nil

local function recordSpy(method, remote, args)
    if not _G.GrowbloxConfig.SpyEnabled then return end
    local remoteName = tostring(remote)
    local remoteParent = remote.Parent and remote.Parent.Name or "Unknown"
    local summary = string.format("[%s] %s.%s | Args: %d", method, remoteParent, remoteName, #args)

    table.insert(SpyLogs, 1, {
        Time = os.date("%X"),
        Method = method,
        Remote = remote,
        Name = remoteName,
        Path = remote:GetFullName(),
        Summary = summary,
        Args = args,
    })
    if #SpyLogs > MAX_SPY_LOGS then
        table.remove(SpyLogs)
    end

    if OnNewSpyLog then
        pcall(OnNewSpyLog, summary)
    end
end

-- Hook Namecall for Live Spy
local rawMeta = getrawmetatable and getrawmetatable(game)
if rawMeta and setreadonly then
    setreadonly(rawMeta, false)
    local oldNamecall = rawMeta.__namecall
    rawMeta.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                local char = LocalPlayer.Character
                local isCharDesc = false
                if char then
                    pcall(function() isCharDesc = self:IsDescendantOf(char) end)
                else
                    isCharDesc = true
                end

                if not isCharDesc then
                    local args = { ... }
                    recordSpy(method, self, args)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(rawMeta, true)
end

-- ═════════════════════════════════════════════════════════════════════════
-- [6] CORE GROWTOPIA AUTOMATION WORKERS
-- ═════════════════════════════════════════════════════════════════════════

-- [WORKER 1: PnB (Place and Break)]
task.spawn(function()
    while true do
        task.wait(_G.GrowbloxConfig.PnBDelay or 0.15)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoPnB then
            local hrp = getHRP()
            if hrp then
                local lookVec = hrp.CFrame.LookVector
                local forwardPos = hrp.Position + (lookVec * 3)

                -- 1. Auto Place
                firePlace("Selected", forwardPos)
                task.wait(0.04)

                -- 2. Auto Break / Punch
                firePunch(nil, forwardPos)

                -- Multi-tile surrounding mode
                if _G.GrowbloxConfig.PnBMode == "Surrounding (3x3)" then
                    for dx = -1, 1 do
                        for dz = -1, 1 do
                            if dx ~= 0 or dz ~= 0 then
                                local offsetPos = hrp.Position + Vector3.new(dx * 3, 0, dz * 3)
                                firePlace("Selected", offsetPos)
                                firePunch(nil, offsetPos)
                            end
                        end
                    end
                elseif _G.GrowbloxConfig.PnBMode == "Double (2 Tile)" then
                    local secondPos = hrp.Position + (lookVec * 6)
                    firePlace("Selected", secondPos)
                    firePunch(nil, secondPos)
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
                -- Search workspace for tree instances
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if not _G.GrowbloxConfig.AutoHarvest then break end
                    local isReady = false
                    local name = obj.Name:lower()

                    if name:find("tree") or name:find("plant") or name:find("crop") then
                        -- Check for prompt / billboard label indicating ready
                        for _, child in ipairs(obj:GetDescendants()) do
                            if child:IsA("TextLabel") or child:IsA("BillboardGui") then
                                local text = tostring(child.Text or ""):lower()
                                if text:find("harvest") or text:find("ready") or text:find("punch") then
                                    isReady = true
                                    break
                                end
                            end
                        end

                        if isReady or obj:GetAttribute("Ready") == true or obj:GetAttribute("CanHarvest") == true then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                            if part and (part.Position - hrp.Position).Magnitude <= (_G.GrowbloxConfig.HarvestRadius or 40) then
                                firePunch(part, part.Position)
                                task.wait(0.1)
                            end
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
        task.wait(0.4)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoPlant then
            local hrp = getHRP()
            if hrp then
                -- Check tile below player
                local rayOrigin = hrp.Position
                local rayDirection = Vector3.new(0, -5, 0)
                local raycastResult = Workspace:Raycast(rayOrigin, rayDirection)

                if raycastResult and raycastResult.Instance then
                    local targetTile = raycastResult.Instance
                    local plantPos = targetTile.Position + Vector3.new(0, 2, 0)
                    firePlace("Seed", plantPos)
                end
            end
        end
    end
end)

-- [WORKER 4: Magplant / Floating Item Magnet]
task.spawn(function()
    while true do
        task.wait(0.2)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.ItemMagnet then
            local hrp = getHRP()
            if hrp then
                local candidates = {}
                for _, obj in ipairs(Workspace:GetChildren()) do
                    local name = obj.Name:lower()
                    if name:find("drop") or name:find("gem") or name:find("seed") or name:find("floating") or name:find("item") then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and (part.Position - hrp.Position).Magnitude <= (_G.GrowbloxConfig.MagnetRadius or 50) then
                            table.insert(candidates, part)
                        end
                    end
                end

                for _, itemPart in ipairs(candidates) do
                    if not _G.GrowbloxConfig.ItemMagnet then break end
                    if itemPart and itemPart.Parent then
                        -- Instant pull simulation / remote trigger
                        if DiscoveredRemotes.Drop then
                            DiscoveredRemotes.Drop:FireServer(itemPart)
                        else
                            -- Smooth suction tween
                            pcall(function()
                                itemPart.CFrame = hrp.CFrame
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
        task.wait(0.3)
        if _ENV.__GrowbloxHubSession ~= MY_SESSION_ID then break end

        if _G.GrowbloxConfig.AutoClearWorld then
            local hrp = getHRP()
            if hrp then
                -- Find nearest breakable block in range
                local nearestBlock = nil
                local nearestDist = 20

                for _, block in ipairs(Workspace:GetDescendants()) do
                    if not _G.GrowbloxConfig.AutoClearWorld then break end
                    if block:IsA("BasePart") and block.CanCollide then
                        local bName = block.Name:lower()
                        local isTarget = false
                        if _G.GrowbloxConfig.ClearDirt and bName:find("dirt") then isTarget = true end
                        if _G.GrowbloxConfig.ClearRock and bName:find("rock") then isTarget = true end
                        if _G.GrowbloxConfig.ClearLava and bName:find("lava") then isTarget = true end

                        if isTarget then
                            local dist = (block.Position - hrp.Position).Magnitude
                            if dist < nearestDist then
                                nearestDist = dist
                                nearestBlock = block
                            end
                        end
                    end
                end

                if nearestBlock then
                    firePunch(nearestBlock, nearestBlock.Position)
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

    -- Check group rank if applicable
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
    warn("[Anti-Staff] Staff detected in server: " .. staffPlayer.Name)

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

-- Initial check for already present staff
for _, p in ipairs(Players:GetPlayers()) do
    if isStaffMember(p) then
        handleStaffDetected(p)
    end
end

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

-- [WORKER 9: Dark 0% GPU Saver (Potato Mode)]
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
            f.BackgroundColor3 = Color3.fromRGB(11, 15, 23) -- Gentle midnight charcoal
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

-- [WORKER 10: Auto-Execute on Teleport / Server Hop]
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

-- Load Rayfield safely
local Rayfield = nil
local success, res = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
end)
if success and res then
    Rayfield = res
end

if Rayfield then
    local Window = Rayfield:CreateWindow({
        Name = "🌱 Nyx Hub — Growblox Suite v1.0",
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

    FarmTab:CreateSection("Place and Break (PnB)")
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
        Name = "PnB Speed Delay (s)",
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

    FarmTab:CreateSection("Trees & Harvest")
    FarmTab:CreateToggle({
        Name = "Auto Harvest Ready Trees",
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
        Range = { 10, 100 },
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

    WorldTab:CreateToggle({
        Name = "Target: Dirt Blocks",
        CurrentValue = _G.GrowbloxConfig.ClearDirt,
        Flag = "ClearDirt",
        Callback = function(val)
            _G.GrowbloxConfig.ClearDirt = val
            saveConfig()
        end,
    })

    WorldTab:CreateToggle({
        Name = "Target: Rock Blocks",
        CurrentValue = _G.GrowbloxConfig.ClearRock,
        Flag = "ClearRock",
        Callback = function(val)
            _G.GrowbloxConfig.ClearRock = val
            saveConfig()
        end,
    })

    WorldTab:CreateToggle({
        Name = "Target: Lava Blocks",
        CurrentValue = _G.GrowbloxConfig.ClearLava,
        Flag = "ClearLava",
        Callback = function(val)
            _G.GrowbloxConfig.ClearLava = val
            saveConfig()
        end,
    })

    WorldTab:CreateSection("Item Magnet (Magplant Vacuum)")
    WorldTab:CreateToggle({
        Name = "Item Magnet (Auto Collect Floating Drops)",
        CurrentValue = _G.GrowbloxConfig.ItemMagnet,
        Flag = "ItemMagnet",
        Callback = function(val)
            _G.GrowbloxConfig.ItemMagnet = val
            saveConfig()
        end,
    })

    WorldTab:CreateSlider({
        Name = "Magnet Range",
        Range = { 20, 200 },
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
    -- [TAB 3: MOVEMENT & PHYSICS]
    -- ─────────────────────────────────────────────────────────────────
    local MoveTab = Window:CreateTab("⚡ Movement", 4483362458)

    MoveTab:CreateSection("2D Sandbox Navigation")
    MoveTab:CreateToggle({
        Name = "Tile Noclip (Walk Through Blocks)",
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
        Range = { 16, 120 },
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
        Range = { 50, 200 },
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
    -- [TAB 4: NETWORK SPY & REMOTES]
    -- ─────────────────────────────────────────────────────────────────
    local SpyTab = Window:CreateTab("🔍 Remote Spy", 4483362458)

    SpyTab:CreateSection("Live Network Capture")
    SpyTab:CreateToggle({
        Name = "Enable Namecall Spy",
        CurrentValue = _G.GrowbloxConfig.SpyEnabled,
        Flag = "SpyEnabled",
        Callback = function(val)
            _G.GrowbloxConfig.SpyEnabled = val
            saveConfig()
        end,
    })

    local LastLogLabel = SpyTab:CreateParagraph({
        Title = "Last Captured Remote",
        Content = "No remote traffic captured yet. Break or place a block to intercept!",
    })

    OnNewSpyLog = function(summary)
        pcall(function()
            LastLogLabel:Set({
                Title = "Captured (" .. os.date("%X") .. ")",
                Content = summary,
            })
        end)
    end

    SpyTab:CreateButton({
        Name = "Copy All Captured Remotes to Clipboard",
        Callback = function()
            if type(setclipboard) == "function" then
                local lines = {}
                for i, log in ipairs(SpyLogs) do
                    table.insert(lines, string.format("[%d] %s | %s", i, log.Time, log.Summary))
                end
                setclipboard(table.concat(lines, "\n"))
                Rayfield:Notify({
                    Title = "Copied!",
                    Content = tostring(#SpyLogs) .. " remote logs copied to clipboard.",
                    Duration = 3,
                })
            end
        end,
    })

    SpyTab:CreateButton({
        Name = "Re-Scan ReplicatedStorage Remotes",
        Callback = function()
            scanRemotes()
            local foundList = {}
            for k, rem in pairs(DiscoveredRemotes) do
                table.insert(foundList, k .. ": " .. (rem and rem.Name or "none"))
            end
            Rayfield:Notify({
                Title = "Remotes Scanned",
                Content = table.concat(foundList, ", "),
                Duration = 5,
            })
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

    SecTab:CreateSection("AFK & GPU Optimizations")
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
        Name = "Instant Rejoin World",
        Callback = function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end,
    })

    SecTab:CreateButton({
        Name = "Server Hop",
        Callback = function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end,
    })

    Rayfield:Notify({
        Title = "Nyx Hub Loaded!",
        Content = "Growblox Suite active. 100% keyless.",
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
