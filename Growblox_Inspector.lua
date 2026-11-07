--[[
    ═════════════════════════════════════════════════════════════════════════
    🔍 GROWBLOX GROUND-TRUTH RECON & REMOTE SPY INSPECTOR 🔍
    Author: iannn (@brilliantgibrann16) • Project: growblox-hub
    Target: Growblox (PlaceId: 112863874972771)
    ═════════════════════════════════════════════════════════════════════════
    Purpose:
    Dumps real ReplicatedStorage hierarchy, Workspace tiles/drops structure,
    and intercepts live FireServer/InvokeServer network traffic with exact args.
    ═════════════════════════════════════════════════════════════════════════
]]--

repeat task.wait(0.2) until game:IsLoaded()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do
    task.wait(0.2)
    LocalPlayer = Players.LocalPlayer
end

local DumpResults = {
    PlaceId = game.PlaceId,
    JobId = game.JobId,
    Remotes = {},
    Modules = {},
    WorkspaceRoots = {},
    BackpackTools = {},
    PlayerGuiRoots = {},
    CapturedTraffic = {},
}

-- 1. Scan ReplicatedStorage
for _, desc in ipairs(RS:GetDescendants()) do
    if desc:IsA("RemoteEvent") then
        table.insert(DumpResults.Remotes, { Type = "RemoteEvent", Name = desc.Name, Path = desc:GetFullName() })
    elseif desc:IsA("RemoteFunction") then
        table.insert(DumpResults.Remotes, { Type = "RemoteFunction", Name = desc.Name, Path = desc:GetFullName() })
    elseif desc:IsA("ModuleScript") then
        table.insert(DumpResults.Modules, { Name = desc.Name, Path = desc:GetFullName() })
    end
end

-- 2. Scan Workspace Children (to see where tiles/blocks/drops live)
for _, child in ipairs(Workspace:GetChildren()) do
    table.insert(DumpResults.WorkspaceRoots, {
        Name = child.Name,
        ClassName = child.ClassName,
        ChildCount = #child:GetChildren()
    })
end

-- 3. Scan Backpack Tools
local bp = LocalPlayer:FindFirstChild("Backpack")
if bp then
    for _, t in ipairs(bp:GetChildren()) do
        table.insert(DumpResults.BackpackTools, { Name = t.Name, ClassName = t.ClassName })
    end
end

-- 4. Scan PlayerGui Roots
local pgui = LocalPlayer:FindFirstChild("PlayerGui")
if pgui then
    for _, g in ipairs(pgui:GetChildren()) do
        table.insert(DumpResults.PlayerGuiRoots, { Name = g.Name, ClassName = g.ClassName })
    end
end

-- 5. Format & Export Initial Hierarchy
local function serializeTable(val)
    local s = pcall(function() return HttpService:JSONEncode(val) end)
    return s or tostring(val)
end

local dumpText = "=== GROWBLOX GROUND TRUTH RECON ===\n"
dumpText = dumpText .. "PlaceId: " .. tostring(game.PlaceId) .. "\n\n"

dumpText = dumpText .. "--- [REMOTES IN REPLICATEDSTORAGE] ---\n"
for _, r in ipairs(DumpResults.Remotes) do
    dumpText = dumpText .. string.format("[%s] %s (Path: %s)\n", r.Type, r.Name, r.Path)
end

dumpText = dumpText .. "\n--- [MODULES IN REPLICATEDSTORAGE] ---\n"
for _, m in ipairs(DumpResults.Modules) do
    dumpText = dumpText .. string.format("[Module] %s (Path: %s)\n", m.Name, m.Path)
end

dumpText = dumpText .. "\n--- [WORKSPACE ROOT OBJECTS] ---\n"
for _, w in ipairs(DumpResults.WorkspaceRoots) do
    dumpText = dumpText .. string.format("[Workspace] %s (%s, children: %d)\n", w.Name, w.ClassName, w.ChildCount)
end

dumpText = dumpText .. "\n--- [BACKPACK TOOLS] ---\n"
for _, t in ipairs(DumpResults.BackpackTools) do
    dumpText = dumpText .. string.format("[Tool] %s (%s)\n", t.Name, t.ClassName)
end

dumpText = dumpText .. "\n--- [PLAYERGUI SCREENS] ---\n"
for _, g in ipairs(DumpResults.PlayerGuiRoots) do
    dumpText = dumpText .. string.format("[Gui] %s (%s)\n", g.Name, g.ClassName)
end

-- Output to File & Clipboard
if type(writefile) == "function" then
    pcall(writefile, "Growblox_Recon.txt", dumpText)
end
if type(setclipboard) == "function" then
    pcall(setclipboard, dumpText)
end

print("═══════════════════════════════════════════════════")
print("✅ GROWBLOX RECON COMPLETE! Copied to clipboard & saved to Growblox_Recon.txt")
print(string.format("Found %d Remotes, %d Modules, %d Workspace objects.", #DumpResults.Remotes, #DumpResults.Modules, #DumpResults.WorkspaceRoots))
print("═══════════════════════════════════════════════════")

-- 6. Hook Namecall for Live Punch & Place Interception
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
                    table.insert(strArgs, string.format("arg%d(%s)=%s", i, typeof(v), tostring(v)))
                end
                local logLine = string.format("[%s] %s:%s(%s)", method, self:GetFullName(), method, table.concat(strArgs, ", "))
                print("⚡ [LIVE REMOTE] " .. logLine)

                if type(appendfile) == "function" then
                    pcall(appendfile, "Growblox_LiveTraffic.txt", logLine .. "\n")
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(rawMeta, true)
    print("🎯 Live Remote Spy hooked! Now punch or place any block in Growblox to see live remote parameters in F9 / Growblox_LiveTraffic.txt.")
end
