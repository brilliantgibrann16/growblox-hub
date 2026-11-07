--[[
    ═════════════════════════════════════════════════════════════════════════
    🌱 GROWBLOX AUTO-RECON & 1-CLICK ALL-IN-ONE CLIPBOARD SPY (v2.0) 🌱
    Author: iannn (@brilliantgibrann16) • Project: growblox-hub
    Target: Growblox (PlaceId: 112863874972771)
    ═════════════════════════════════════════════════════════════════════════
    FITUR OTOMATIS:
    1. Deep-dump skema paket ByteNet (Net.punch, Net.tile, Net.take, Net.harvest).
    2. Decompile source code Net & WorldCodec (jika didukung executor).
    3. Hook langsung Net.punch.send, Net.tile.send, Net.call, dan Namecall.
    4. Indikator Live Checklist di layar:
       - 🥊 Status Punch: [BELUM] -> [✔ TERDETEKSI!]
       - 🧱 Status Place: [BELUM] -> [✔ TERDETEKSI!]
    5. Tombol 1-Click Copy ke Clipboard begitu Bubu selesai tes.
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

local DumpResults = {
    PlaceId = game.PlaceId,
    JobId = game.JobId,
    Player = LocalPlayer.Name,
    UserId = LocalPlayer.UserId,
    Remotes = {},
    Modules = {},
    WorkspaceRoots = {},
    BackpackTools = {},
    PlayerGuiRoots = {},
    PlayerScripts = {},
    NetPackets = {},
    NetSource = nil,
    CapturedTraffic = {},
}

local PunchDetected = false
local PlaceDetected = false

-- ═════════════════════════════════════════════════════════════════════════
-- [1] DEEP TABLE SERIALIZER
-- ═════════════════════════════════════════════════════════════════════════
local function deepSerialize(tbl, depth, maxDepth)
    depth = depth or 1
    maxDepth = maxDepth or 3
    if depth > maxDepth then return "{...}" end
    if type(tbl) ~= "table" then return tostring(tbl) end

    local entries = {}
    for k, v in pairs(tbl) do
        local keyName = tostring(k)
        if type(v) == "table" then
            table.insert(entries, keyName .. " = " .. deepSerialize(v, depth + 1, maxDepth))
        elseif type(v) == "function" then
            table.insert(entries, keyName .. " = [function]")
        else
            table.insert(entries, keyName .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")")
        end
    end
    return "{\n" .. string.rep("  ", depth) .. table.concat(entries, ",\n" .. string.rep("  ", depth)) .. "\n" .. string.rep("  ", depth - 1) .. "}"
end

-- ═════════════════════════════════════════════════════════════════════════
-- [2] STATIC RECON & NET INTROSPECTION
-- ═════════════════════════════════════════════════════════════════════════
local function runStaticScan()
    -- Scan Remotes & Modules
    for _, desc in ipairs(RS:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            table.insert(DumpResults.Remotes, { Type = "RemoteEvent", Name = desc.Name, Path = desc:GetFullName() })
        elseif desc:IsA("RemoteFunction") then
            table.insert(DumpResults.Remotes, { Type = "RemoteFunction", Name = desc.Name, Path = desc:GetFullName() })
        elseif desc:IsA("ModuleScript") then
            table.insert(DumpResults.Modules, { Name = desc.Name, Path = desc:GetFullName() })
        end
    end

    -- Deep Introspect Shared.Net
    local sharedFolder = RS:FindFirstChild("Shared")
    if sharedFolder then
        local netMod = sharedFolder:FindFirstChild("Net")
        if netMod and netMod:IsA("ModuleScript") then
            local s, Net = pcall(require, netMod)
            if s and type(Net) == "table" then
                for k, v in pairs(Net) do
                    if type(v) == "table" then
                        DumpResults.NetPackets[tostring(k)] = deepSerialize(v, 1, 3)
                    end
                end
            end

            -- Try Decompile Net
            local decomp = decompile or (syn and syn.decompile) or (fluxus and fluxus.decompile)
            if type(decomp) == "function" then
                pcall(function()
                    DumpResults.NetSource = decomp(netMod)
                end)
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

    -- Scan Backpack
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            table.insert(DumpResults.BackpackTools, { Name = t.Name, ClassName = t.ClassName })
        end
    end

    -- Scan PlayerScripts
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        for _, desc in ipairs(ps:GetDescendants()) do
            if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
                table.insert(DumpResults.PlayerScripts, { Name = desc.Name, Path = desc:GetFullName(), ClassName = desc.ClassName })
            end
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
-- [3] HOOK NET PACKETS & NAMECALL
-- ═════════════════════════════════════════════════════════════════════════
local OnTrafficCaptured = nil

-- 3A. Hook Net Module Functions directly
local sharedFolder = RS:FindFirstChild("Shared")
if sharedFolder then
    local netMod = sharedFolder:FindFirstChild("Net")
    if netMod and netMod:IsA("ModuleScript") then
        local s, Net = pcall(require, netMod)
        if s and type(Net) == "table" then
            -- Hook individual packet.send
            for packetName, packet in pairs(Net) do
                if type(packet) == "table" and type(packet.send) == "function" then
                    local oldSend = packet.send
                    packet.send = function(...)
                        local args = { ... }
                        local encodedArgs = "{"
                        for i, arg in ipairs(args) do
                            local sArg = tostring(arg)
                            if type(arg) == "table" then
                                pcall(function() sArg = HttpService:JSONEncode(arg) end)
                            end
                            encodedArgs = encodedArgs .. string.format("[%d]=%s, ", i, sArg)
                        end
                        encodedArgs = encodedArgs .. "}"

                        local detail = string.format("[Net.%s.send] %s", packetName, encodedArgs)
                        table.insert(DumpResults.CapturedTraffic, 1, {
                            Time = os.date("%X"),
                            Detail = detail,
                        })

                        local pLower = packetName:lower()
                        if pLower:find("punch") or pLower:find("hit") or pLower:find("break") then
                            PunchDetected = true
                        elseif pLower:find("tile") or pLower:find("place") or pLower:find("plant") then
                            PlaceDetected = true
                        end

                        if OnTrafficCaptured then
                            pcall(OnTrafficCaptured, detail)
                        end
                        return oldSend(...)
                    end
                end
            end

            -- Hook Net.call
            if type(Net.call) == "function" then
                local oldCall = Net.call
                Net.call = function(...)
                    local args = { ... }
                    local detail = string.format("[Net.call] Args: %s", deepSerialize(args, 1, 2))
                    table.insert(DumpResults.CapturedTraffic, 1, {
                        Time = os.date("%X"),
                        Detail = detail,
                    })
                    local a1 = tostring(args[1] or ""):lower()
                    if a1:find("punch") or a1:find("break") then
                        PunchDetected = true
                    elseif a1:find("tile") or a1:find("place") then
                        PlaceDetected = true
                    end
                    if OnTrafficCaptured then
                        pcall(OnTrafficCaptured, detail)
                    end
                    return oldCall(...)
                end
            end
        end
    end
end

-- 3B. Hook Namecall (for WorldRemotes & ByteNetReliable)
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
                    elseif typeof(v) == "buffer" then
                        valStr = string.format("[buffer len=%d]", buffer.len(v))
                    end
                    table.insert(strArgs, string.format("arg%d(%s)=%s", i, typeof(v), valStr))
                end

                local detail = string.format("[%s] %s:%s(%s)", method, self:GetFullName(), method, table.concat(strArgs, ", "))
                table.insert(DumpResults.CapturedTraffic, 1, {
                    Time = os.date("%X"),
                    Detail = detail,
                    Remote = self,
                })

                local rName = self.Name:lower()
                if rName:find("tile") or rName:find("place") then
                    PlaceDetected = true
                elseif rName:find("punch") or rName:find("break") then
                    PunchDetected = true
                end

                if #DumpResults.CapturedTraffic > 80 then
                    table.remove(DumpResults.CapturedTraffic)
                end

                if OnTrafficCaptured then
                    pcall(OnTrafficCaptured, detail)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(rawMeta, true)
end

-- ═════════════════════════════════════════════════════════════════════════
-- [4] REPORT GENERATOR
-- ═════════════════════════════════════════════════════════════════════════
local function buildFullReport()
    local text = "═════════════════════════════════════════════════════════════\n"
    text = text .. "🌱 GROWBLOX COMPREHENSIVE GROUND-TRUTH REPORT (v2.0) 🌱\n"
    text = text .. "PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId) .. "\n"
    text = text .. "Player: " .. LocalPlayer.Name .. " (" .. tostring(LocalPlayer.UserId) .. ")\n"
    text = text .. "Captured Live Traffic Count: " .. tostring(#DumpResults.CapturedTraffic) .. "\n"
    text = text .. "Punch Detected: " .. tostring(PunchDetected) .. " | Place Detected: " .. tostring(PlaceDetected) .. "\n"
    text = text .. "═════════════════════════════════════════════════════════════\n\n"

    text = text .. "--- [1. LIVE INTERCEPTED NETWORK TRAFFIC (NET & REMOTES)] ---\n"
    if #DumpResults.CapturedTraffic == 0 then
        text = text .. "(Belum ada traffic remote yang tertangkap.)\n"
    else
        for i, log in ipairs(DumpResults.CapturedTraffic) do
            text = text .. string.format("[%02d] %s | %s\n", i, log.Time, log.Detail)
        end
    end

    text = text .. "\n--- [2. INTROSPECTED NET PACKETS (BYTENET SCHEMAS)] ---\n"
    for pName, schema in pairs(DumpResults.NetPackets) do
        text = text .. string.format("▶ Net.%s Schema:\n%s\n\n", pName, schema)
    end

    if DumpResults.NetSource then
        text = text .. "\n--- [2.1 DECOMPILED SHARED.NET SOURCE CODE] ---\n"
        text = text .. DumpResults.NetSource .. "\n"
    end

    text = text .. "\n--- [3. ALL REMOTES IN REPLICATEDSTORAGE] ---\n"
    for _, r in ipairs(DumpResults.Remotes) do
        text = text .. string.format("[%s] %s | Path: %s\n", r.Type, r.Name, r.Path)
    end

    text = text .. "\n--- [4. PLAYERSCRIPTS LOCAL AND MODULE SCRIPTS] ---\n"
    for _, s in ipairs(DumpResults.PlayerScripts) do
        text = text .. string.format("[%s] %s | Path: %s\n", s.ClassName, s.Name, s.Path)
    end

    text = text .. "\n--- [5. WORKSPACE ROOT DIRECTORIES & OBJECTS] ---\n"
    for _, w in ipairs(DumpResults.WorkspaceRoots) do
        text = text .. string.format("[Workspace] %s (%s, Total Children: %d)\n", w.Name, w.ClassName, w.ChildCount)
    end

    text = text .. "\n--- [6. BACKPACK TOOLS & INVENTORY] ---\n"
    for _, t in ipairs(DumpResults.BackpackTools) do
        text = text .. string.format("[Tool] %s (%s)\n", t.Name, t.ClassName)
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

-- ═════════════════════════════════════════════════════════════════════════
-- [5] INTERACTIVE FLOATING CARD WITH LIVE CHECKLIST
-- ═════════════════════════════════════════════════════════════════════════
local function createFloatingUI()
    local parent = CoreGui or LocalPlayer:FindFirstChild("PlayerGui")
    if not parent then return end

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
    frame.Size = UDim2.new(0, 360, 0, 240)
    frame.Position = UDim2.new(0.5, -180, 0.04, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 20, 32)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 130, 220)
    stroke.Thickness = 1.5
    stroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Text = "🌱 GROWBLOX GROUND-TRUTH SPY v2.0"
    title.TextColor3 = Color3.fromRGB(240, 245, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    -- Status Checklist
    local punchLabel = Instance.new("TextLabel")
    punchLabel.Text = "🥊 Pukul (Punch) Blok: [ BELUM ]"
    punchLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    punchLabel.Font = Enum.Font.GothamBold
    punchLabel.TextSize = 11
    punchLabel.Size = UDim2.new(1, -20, 0, 18)
    punchLabel.Position = UDim2.new(0, 10, 0, 32)
    punchLabel.BackgroundTransparency = 1
    punchLabel.TextXAlignment = Enum.TextXAlignment.Left
    punchLabel.Parent = frame

    local placeLabel = Instance.new("TextLabel")
    placeLabel.Text = "🧱 Pasang (Place) Blok/Bibit: [ BELUM ]"
    placeLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    placeLabel.Font = Enum.Font.GothamBold
    placeLabel.TextSize = 11
    placeLabel.Size = UDim2.new(1, -20, 0, 18)
    placeLabel.Position = UDim2.new(0, 10, 0, 52)
    placeLabel.BackgroundTransparency = 1
    placeLabel.TextXAlignment = Enum.TextXAlignment.Left
    placeLabel.Parent = frame

    -- Live Traffic Log
    local liveBox = Instance.new("Frame")
    liveBox.Size = UDim2.new(1, -20, 0, 50)
    liveBox.Position = UDim2.new(0, 10, 0, 74)
    liveBox.BackgroundColor3 = Color3.fromRGB(22, 30, 48)
    liveBox.BorderSizePixel = 0
    liveBox.Parent = frame

    local liveBoxCorner = Instance.new("UICorner")
    liveBoxCorner.CornerRadius = UDim.new(0, 6)
    liveBoxCorner.Parent = liveBox

    local liveLabel = Instance.new("TextLabel")
    liveLabel.Text = "⚡ Traffic: 0 calls\n(Coba pukul 1 tanah & pasang 1 blok di world!)"
    liveLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
    liveLabel.Font = Enum.Font.Code
    liveLabel.TextSize = 10
    liveLabel.Size = UDim2.new(1, -12, 1, 0)
    liveLabel.Position = UDim2.new(0, 6, 0, 0)
    liveLabel.BackgroundTransparency = 1
    liveLabel.TextXAlignment = Enum.TextXAlignment.Left
    liveLabel.TextYAlignment = Enum.TextYAlignment.Center
    liveLabel.TextWrapped = true
    liveLabel.Parent = liveBox

    -- Copy Button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1, -20, 0, 40)
    copyBtn.Position = UDim2.new(0, 10, 0, 132)
    copyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 240)
    copyBtn.Text = "📋 COPY SEMUA HASIL RECON (SIAP PASTE)"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 11
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = copyBtn

    -- Instructions
    local instr = Instance.new("TextLabel")
    instr.Text = "Urutan: Masuk world -> Pukul 1x -> Pasang 1x -> Klik Copy!"
    instr.TextColor3 = Color3.fromRGB(130, 200, 255)
    instr.Font = Enum.Font.Gotham
    instr.TextSize = 10
    instr.Size = UDim2.new(1, -20, 0, 20)
    instr.Position = UDim2.new(0, 10, 0, 178)
    instr.BackgroundTransparency = 1
    instr.Parent = frame

    local function updateLabels(detail)
        if PunchDetected then
            punchLabel.Text = "🥊 Pukul (Punch) Blok: [ ✔ TERDETEKSI! ]"
            punchLabel.TextColor3 = Color3.fromRGB(100, 240, 150)
        end
        if PlaceDetected then
            placeLabel.Text = "🧱 Pasang (Place) Blok/Bibit: [ ✔ TERDETEKSI! ]"
            placeLabel.TextColor3 = Color3.fromRGB(100, 240, 150)
        end
        liveLabel.Text = string.format("⚡ Traffic: %d calls | Last:\n%s", #DumpResults.CapturedTraffic, detail:sub(1, 65))
        if PunchDetected or PlaceDetected then
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
        end
    end

    OnTrafficCaptured = function(detail)
        pcall(updateLabels, detail)
    end

    copyBtn.MouseButton1Click:Connect(function()
        copyReportToClipboard()
        copyBtn.Text = "✅ BERHASIL DICOPY KE CLIPBOARD!"
        copyBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 100)
        task.wait(2)
        copyBtn.Text = "📋 COPY SEMUA HASIL RECON (SIAP PASTE)"
        copyBtn.BackgroundColor3 = (PunchDetected or PlaceDetected) and Color3.fromRGB(40, 160, 90) or Color3.fromRGB(50, 120, 240)
    end)

    pcall(function() sg.Parent = parent end)
end

pcall(createFloatingUI)
