--[[
    ═════════════════════════════════════════════════════════════════════════
    🌱 GROWBLOX AUTO-RECON & 1-CLICK ALL-IN-ONE CLIPBOARD SPY 🌱
    Author: iannn (@brilliantgibrann16) • Project: growblox-hub
    Target: Growblox (PlaceId: 112863874972771)
    ═════════════════════════════════════════════════════════════════════════
    FITUR OTOMATIS:
    1. Sekali execute, LANGSUNG otomatis copy struktur awal ke clipboard.
    2. Muncul UI mini melayang di layar (Floating Liquid Glass Card).
    3. Live namecall hook otomatis rekam setiap remote saat Bubu mukul/naruh blok.
    4. Tombol 1-Click "📋 COPY SEMUA DATA KE CLIPBOARD" buat copy gabungan:
       - Semua RemoteEvent & RemoteFunction di ReplicatedStorage
       - Semua ModuleScript (Data, Items, Configs)
       - Struktur Workspace (Folder Tiles, Blocks, Drops)
       - Tools di Backpack
       - Live Intercepted Remotes dengan tipe dan nilai argumen lengkap!
    ═════════════════════════════════════════════════════════════════════════
]]--

repeat task.wait(0.2) until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do
    task.wait(0.2)
    LocalPlayer = Players.LocalPlayer
end

-- ═════════════════════════════════════════════════════════════════════════
-- [1] DATA CONTAINER & COLLECTOR
-- ═════════════════════════════════════════════════════════════════════════
local DumpResults = {
    PlaceId = game.PlaceId,
    JobId = game.JobId,
    Remotes = {},
    Modules = {},
    WorkspaceRoots = {},
    BackpackTools = {},
    PlayerGuiRoots = {},
    CapturedTraffic = {},
    ModuleExports = {},
}

local function runStaticScan()
    DumpResults.Remotes = {}
    DumpResults.Modules = {}
    DumpResults.WorkspaceRoots = {}
    DumpResults.BackpackTools = {}
    DumpResults.PlayerGuiRoots = {}
    DumpResults.ModuleExports = {}

    -- Scan ReplicatedStorage
    for _, desc in ipairs(RS:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            table.insert(DumpResults.Remotes, { Type = "RemoteEvent", Name = desc.Name, Path = desc:GetFullName() })
        elseif desc:IsA("RemoteFunction") then
            table.insert(DumpResults.Remotes, { Type = "RemoteFunction", Name = desc.Name, Path = desc:GetFullName() })
        elseif desc:IsA("ModuleScript") then
            table.insert(DumpResults.Modules, { Name = desc.Name, Path = desc:GetFullName() })
        end
    end

    -- Introspect Key Shared Modules (Net, ItemDB, WorldCodec, BlocksDB)
    local sharedFolder = RS:FindFirstChild("Shared")
    if sharedFolder then
        local targetModules = { "Net", "ItemDB", "WorldCodec", "BlocksDB", "Inventory", "DropBox", "CommandList" }
        for _, modName in ipairs(targetModules) do
            local mod = sharedFolder:FindFirstChild(modName)
            if mod and mod:IsA("ModuleScript") then
                local s, res = pcall(require, mod)
                if s and type(res) == "table" then
                    local keys = {}
                    for k, v in pairs(res) do
                        local valPreview = tostring(v)
                        if typeof(v) == "table" then
                            valPreview = "{... " .. tostring(#v) .. " items}"
                        end
                        table.insert(keys, string.format("%s (%s = %s)", tostring(k), typeof(v), valPreview:sub(1, 40)))
                    end
                    table.sort(keys)
                    DumpResults.ModuleExports[modName] = keys
                end
            end
        end
    end

    -- Scan Workspace Roots
    for _, child in ipairs(Workspace:GetChildren()) do
        table.insert(DumpResults.WorkspaceRoots, {
            Name = child.Name,
            ClassName = child.ClassName,
            ChildCount = #child:GetChildren()
        })
    end

    -- Scan Backpack Tools
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            table.insert(DumpResults.BackpackTools, { Name = t.Name, ClassName = t.ClassName })
        end
    end

    -- Scan PlayerGui
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        for _, g in ipairs(pgui:GetChildren()) do
            table.insert(DumpResults.PlayerGuiRoots, { Name = g.Name, ClassName = g.ClassName })
        end
    end
end

runStaticScan()

-- ═════════════════════════════════════════════════════════════════════════
-- [2] REPORT BUILDER & EXPORTER
-- ═════════════════════════════════════════════════════════════════════════
local function buildFullReport()
    local text = "═════════════════════════════════════════════════════════════\n"
    text = text .. "🌱 GROWBLOX COMPREHENSIVE GROUND-TRUTH REPORT 🌱\n"
    text = text .. "PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId) .. "\n"
    text = text .. "Player: " .. LocalPlayer.Name .. " (" .. tostring(LocalPlayer.UserId) .. ")\n"
    text = text .. "Captured Live Traffic Count: " .. tostring(#DumpResults.CapturedTraffic) .. "\n"
    text = text .. "═════════════════════════════════════════════════════════════\n\n"

    text = text .. "--- [1. LIVE INTERCEPTED NETWORK TRAFFIC (PUNCH/PLACE/HARVEST)] ---\n"
    if #DumpResults.CapturedTraffic == 0 then
        text = text .. "(Belum ada traffic remote yang tertangkap. Silakan pukul atau pasang blok!)\n"
    else
        for i, log in ipairs(DumpResults.CapturedTraffic) do
            text = text .. string.format("[%02d] %s | %s\n", i, log.Time, log.Detail)
        end
    end

    text = text .. "\n--- [2. ALL REMOTES IN REPLICATEDSTORAGE] ---\n"
    if #DumpResults.Remotes == 0 then
        text = text .. "(Tidak ada RemoteEvent/RemoteFunction di ReplicatedStorage)\n"
    else
        for _, r in ipairs(DumpResults.Remotes) do
            text = text .. string.format("[%s] %s\n      Path: %s\n", r.Type, r.Name, r.Path)
        end
    end

    text = text .. "\n--- [3. ALL MODULESCRIPTS IN REPLICATEDSTORAGE] ---\n"
    for _, m in ipairs(DumpResults.Modules) do
        text = text .. string.format("[Module] %s | Path: %s\n", m.Name, m.Path)
    end

    if DumpResults.ModuleExports and next(DumpResults.ModuleExports) then
        text = text .. "\n--- [3.1 INTROSPECTED MODULE EXPORTS & KEYS] ---\n"
        for modName, keys in pairs(DumpResults.ModuleExports) do
            text = text .. string.format("▶ Module '%s' (%d keys/exports):\n", modName, #keys)
            for _, kStr in ipairs(keys) do
                text = text .. "   - " .. kStr .. "\n"
            end
        end
    end

    text = text .. "\n--- [4. WORKSPACE ROOT DIRECTORIES & OBJECTS] ---\n"
    for _, w in ipairs(DumpResults.WorkspaceRoots) do
        text = text .. string.format("[Workspace] %s (%s, Total Children: %d)\n", w.Name, w.ClassName, w.ChildCount)
    end

    text = text .. "\n--- [5. BACKPACK TOOLS] ---\n"
    if #DumpResults.BackpackTools == 0 then
        text = text .. "(Backpack kosong)\n"
    else
        for _, t in ipairs(DumpResults.BackpackTools) do
            text = text .. string.format("[Tool] %s (%s)\n", t.Name, t.ClassName)
        end
    end

    text = text .. "\n--- [6. PLAYERGUI ROOT ELEMENTS] ---\n"
    for _, g in ipairs(DumpResults.PlayerGuiRoots) do
        text = text .. string.format("[Gui] %s (%s)\n", g.Name, g.ClassName)
    end

    text = text .. "\n═════════════════════════════════════════════════════════════\n"
    text = text .. "END OF DUMP REPORT\n"
    return text
end

local function copyReportToClipboard()
    local report = buildFullReport()
    local setcb = setclipboard or (Clipboard and Clipboard.set) or (syn and syn.write_clipboard)
    local copied = false
    if type(setcb) == "function" then
        pcall(setcb, report)
        copied = true
    end
    if type(writefile) == "function" then
        pcall(writefile, "Growblox_FullReport.txt", report)
    end
    return copied
end

-- Auto-copy initial recon directly to clipboard on execution
task.spawn(function()
    task.wait(0.5)
    copyReportToClipboard()
end)

-- ═════════════════════════════════════════════════════════════════════════
-- [3] LIVE NAMECALL SPY HOOK
-- ═════════════════════════════════════════════════════════════════════════
local OnTrafficCaptured = nil

local rawMeta = getrawmetatable and getrawmetatable(game)
if rawMeta and setreadonly then
    setreadonly(rawMeta, false)
    local oldNamecall = rawMeta.__namecall
    rawMeta.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" then
            if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                local args = { ... }
                local strArgs = {}
                for i, v in ipairs(args) do
                    local valStr = tostring(v)
                    if typeof(v) == "table" then
                        pcall(function() valStr = HttpService:JSONEncode(v) end)
                    elseif typeof(v) == "Instance" then
                        valStr = v:GetFullName()
                    end
                    table.insert(strArgs, string.format("arg%d(%s)=%s", i, typeof(v), valStr))
                end

                local detail = string.format("[%s] %s:%s(%s)", method, self:GetFullName(), method, table.concat(strArgs, ", "))
                table.insert(DumpResults.CapturedTraffic, 1, {
                    Time = os.date("%X"),
                    Detail = detail,
                    Remote = self,
                })

                -- Limit to 80 recent calls
                if #DumpResults.CapturedTraffic > 80 then
                    table.remove(DumpResults.CapturedTraffic)
                end

                if OnTrafficCaptured then
                    pcall(OnTrafficCaptured, detail, #DumpResults.CapturedTraffic)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(rawMeta, true)
end

-- ═════════════════════════════════════════════════════════════════════════
-- [4] SLEEK ON-SCREEN FLOATING CARD (1-CLICK COPY BUTTON)
-- ═════════════════════════════════════════════════════════════════════════
local function createFloatingUI()
    local parent = CoreGui or LocalPlayer:FindFirstChild("PlayerGui")
    if not parent then return end

    -- Destroy old instances
    for _, c in ipairs(parent:GetChildren()) do
        if c.Name == "GrowbloxInspectorUI" then
            pcall(function() c:Destroy() end)
        end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "GrowbloxInspectorUI"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 200)
    frame.Position = UDim2.new(0.5, -170, 0.05, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 100, 170)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Text = "🌱 GROWBLOX RECON & LIVE SPY"
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Size = UDim2.new(1, -20, 0, 26)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    -- Status Subtitle
    local sub = Instance.new("TextLabel")
    sub.Text = string.format("Found: %d Remotes | %d Modules", #DumpResults.Remotes, #DumpResults.Modules)
    sub.TextColor3 = Color3.fromRGB(140, 170, 215)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 12
    sub.Size = UDim2.new(1, -20, 0, 18)
    sub.Position = UDim2.new(0, 10, 0, 34)
    sub.BackgroundTransparency = 1
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = frame

    -- Live Traffic Counter & Preview
    local liveBox = Instance.new("Frame")
    liveBox.Size = UDim2.new(1, -20, 0, 48)
    liveBox.Position = UDim2.new(0, 10, 0, 56)
    liveBox.BackgroundColor3 = Color3.fromRGB(22, 30, 48)
    liveBox.BorderSizePixel = 0
    liveBox.Parent = frame

    local liveBoxCorner = Instance.new("UICorner")
    liveBoxCorner.CornerRadius = UDim.new(0, 6)
    liveBoxCorner.Parent = liveBox

    local liveLabel = Instance.new("TextLabel")
    liveLabel.Text = "⚡ Traffic: 0 calls\n(Pukul / pasang blok buat nangkep remote)"
    liveLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
    liveLabel.Font = Enum.Font.Code
    liveLabel.TextSize = 11
    liveLabel.Size = UDim2.new(1, -12, 1, 0)
    liveLabel.Position = UDim2.new(0, 6, 0, 0)
    liveLabel.BackgroundTransparency = 1
    liveLabel.TextXAlignment = Enum.TextXAlignment.Left
    liveLabel.TextYAlignment = Enum.TextYAlignment.Center
    liveLabel.TextWrapped = true
    liveLabel.Parent = liveBox

    -- Update hook for live label
    OnTrafficCaptured = function(detail, count)
        liveLabel.Text = string.format("⚡ Traffic: %d calls | Last:\n%s", count, detail:sub(1, 65))
    end

    -- Big Copy Button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1, -20, 0, 42)
    copyBtn.Position = UDim2.new(0, 10, 0, 112)
    copyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 240)
    copyBtn.Text = "📋 COPY SEMUA DATA KE CLIPBOARD"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 12
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = copyBtn

    -- Footer notice
    local notice = Instance.new("TextLabel")
    notice.Text = "✓ Auto-copied to clipboard on load! Geser card ini kalo ngehalangin."
    notice.TextColor3 = Color3.fromRGB(100, 220, 160)
    notice.Font = Enum.Font.Gotham
    notice.TextSize = 10
    notice.Size = UDim2.new(1, -20, 0, 20)
    notice.Position = UDim2.new(0, 10, 0, 160)
    notice.BackgroundTransparency = 1
    notice.Parent = frame

    copyBtn.MouseButton1Click:Connect(function()
        copyReportToClipboard()
        copyBtn.Text = "✅ BERHASIL DICOPY! (Siap Paste)"
        copyBtn.BackgroundColor3 = Color3.fromRGB(35, 170, 95)
        task.wait(2)
        copyBtn.Text = "📋 COPY SEMUA DATA KE CLIPBOARD"
        copyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 240)
    end)

    pcall(function() sg.Parent = parent end)
end

pcall(createFloatingUI)
