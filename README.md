# 🌱 Nyx Hub — Growblox Automation Suite

100% Keyless, zero-ad, high-performance Roblox script suite for **Growblox** (Growtopia recreation on Roblox) created by **iannn** ([@brilliantgibrann16](https://github.com/brilliantgibrann16)).

Target Game: **Growblox** (`PlaceId: 112863874972771`) by ExecutiveStudio.

---

## 🚀 Execution Loadstring

Paste this one-liner into your Roblox executor (Xeno, Solara, Wave, Volcano, Delta, Fluxus, Sober, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/brilliantgibrann16/growblox-hub/main/Loader.lua"))()
```

---

## ✨ Growtopia-Style Feature Matrix

### 🌾 1. PnB (Place and Break) & Farming
- **Auto PnB (Place & Break)**: Automates rapid block placement and breaking for seed & gem farming.
- **Multi-Tile Modes**:
  - `In Front (1 Tile)`: Classic single-tile farming.
  - `Double (2 Tile)`: 2-tile horizontal stream.
  - `Surrounding (3x3)`: Full 3x3 perimeter clearing.
- **Configurable Speed Delay**: Custom slider from `0.05s` to `0.5s` for zero-lag farming.
- **Auto Harvest**: Real-time scanner for mature trees (`Punch to harvest!`).
- **Auto Plant**: Automatically detects vacant soil tiles below player and plants equipped seeds.

### 🌍 2. World Clearing & Magplant Magnet
- **Auto Clear World (Dirt Farm Flattener)**: Automates clearing whole worlds from dirt, rock, and lava.
- **Magplant / Item Magnet**: Sucks in all dropped floating gems, seeds, and blocks within a 20–200 stud radius.

### ⚡ 3. 2D Movement & Physics
- **Tile Noclip**: Walk through solid blocks and locked doors.
- **Infinite Jump**: Seamless vertical platforming without jump delay.
- **WalkSpeed & JumpPower Sliders**: Persistent movement speed across respawns.

### 🔍 4. In-Game Remote Spy & Scanner
- **Live Namecall Interceptor**: Intercepts `FireServer` and `InvokeServer` calls in real-time.
- **1-Click Copy**: Export all captured remote arguments and paths to the clipboard.
- **Re-Scan Button**: Instantly refresh discovered `ReplicatedStorage` remotes on game updates.

### 🛡️ 5. Anti-Staff & Server Watchdog
- **Anti-Staff Watchdog**: Detects developers, moderators, and group staff joining the server.
- **Action Modes**: `Notify Only`, `Server Hop`, or `Instant Disconnect`.
- **Permanent Anti-AFK**: Input emulation heartbeat to prevent 20-minute disconnect kicks.
- **Dark 0% GPU Saver**: Eye-friendly midnight charcoal overlay (`RunService:Set3dRenderingEnabled(false)`) for overnight AFK farming.
