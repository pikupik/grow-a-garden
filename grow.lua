-- ╔══════════════════════════════════════════════════╗
-- ║       Grow A Garden 2 - Auto Farm                ║
-- ║       Simple UI | No Library Needed              ║
-- ╚══════════════════════════════════════════════════╝

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS          = game:GetService("ReplicatedStorage")
local TweenService= game:GetService("TweenService")

local Networking  = require(RS.SharedModules.Networking)
local PlayerState = require(RS.ClientModules.PlayerStateClient)

-- ══════════════════════════════
--  STATE
-- ══════════════════════════════
local State = {
    AutoHarvest  = false,
    AutoSellAll  = false,
    AutoMagnet   = false,
    AutoAntiAfk  = false,
    AutoClaimGift= false,
    HarvestCount = 0,
    SellCount    = 0,
    Minimized    = false,
}

-- ══════════════════════════════
--  HELPERS
-- ══════════════════════════════
local function safefire(net, ...)
    pcall(function() net:Fire(...) end)
end

local function getAllFruits()
    local fruits = {}
    local ok, replica = pcall(function()
        return PlayerState:GetLocalReplica()
    end)
    if not ok or not replica then return fruits end
    local gardens = replica.Data and replica.Data.Gardens or {}
    for gardenId, gardenData in pairs(gardens) do
        if gardenData.Fruits then
            for fruitId, _ in pairs(gardenData.Fruits) do
                table.insert(fruits, { GardenId = gardenId, FruitId = fruitId })
            end
        end
    end
    return fruits
end

-- ══════════════════════════════
--  LOOPS
-- ══════════════════════════════
task.spawn(function()
    while true do
        task.wait(1.5)
        if State.AutoHarvest then
            for _, f in ipairs(getAllFruits()) do
                if not State.AutoHarvest then break end
                safefire(Networking.Garden.CollectFruit, f.GardenId, f.FruitId)
                State.HarvestCount += 1
                task.wait(0.15)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if State.AutoSellAll then
            local ok, result = pcall(function()
                return Networking.NPCS.SellAll:Fire()
            end)
            if ok and result and result.SoldCount then
                State.SellCount += result.SoldCount
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(3)
        if State.AutoMagnet then
            safefire(Networking.FruitMagnet.Activate)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(55)
        if State.AutoAntiAfk then
            safefire(Networking.AntiAfk.RequestHop)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        if State.AutoClaimGift then
            local ok, inbox = pcall(function()
                return Networking.Mailbox.OpenInbox:Fire()
            end)
            if ok and inbox then
                for giftId, _ in pairs(inbox) do
                    pcall(function() Networking.Mailbox.Claim:Fire(giftId) end)
                    task.wait(0.5)
                end
            end
        end
    end
end)

-- ══════════════════════════════
--  UI
-- ══════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "GAG2Farm"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer.PlayerGui

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 400)
main.Position = UDim2.new(0, 20, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local fix = Instance.new("Frame")
fix.Size = UDim2.new(1, 0, 0.5, 0)
fix.Position = UDim2.new(0, 0, 0.5, 0)
fix.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
fix.BorderSizePixel = 0
fix.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🌱 Grow A Garden 2"
title.TextColor3 = Color3.new(1,1,1)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -62, 0.5, -14)
minBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
minBtn.Text = "–"
minBtn.TextColor3 = Color3.new(0,0,0)
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Content frame
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, 0, 1, -36)
content.Position = UDim2.new(0, 0, 0, 36)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = Color3.fromRGB(34,139,34)
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = content

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 8)
padding.Parent = content

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Harvest: 0 | Sell: 0"
statusLabel.TextColor3 = Color3.fromRGB(150,150,150)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.LayoutOrder = 0
statusLabel.Parent = content

task.spawn(function()
    while true do
        task.wait(1)
        statusLabel.Text = string.format(
            "Harvest: %d buah | Sell: %d kali",
            State.HarvestCount, State.SellCount)
    end
end)

-- ── UI BUILDER FUNCTIONS ──────────────
local order = 1

local function makeSection(label)
    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 22)
    sec.BackgroundColor3 = Color3.fromRGB(34,139,34)
    sec.BackgroundTransparency = 0.6
    sec.Text = "  " .. label
    sec.TextColor3 = Color3.fromRGB(180,255,180)
    sec.TextSize = 11
    sec.Font = Enum.Font.GothamBold
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.LayoutOrder = order; order += 1
    sec.Parent = content
    Instance.new("UICorner", sec).CornerRadius = UDim.new(0, 6)
end

local function makeToggle(label, stateKey, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    row.BorderSizePixel = 0
    row.LayoutOrder = order; order += 1
    row.Parent = content
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.new(1,1,1)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 24)
    btn.Position = UDim2.new(1, -52, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(150,150,150)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    btn.MouseButton1Click:Connect(function()
        State[stateKey] = not State[stateKey]
        local on = State[stateKey]
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = on
                and Color3.fromRGB(34,139,34)
                or  Color3.fromRGB(60,60,60)
        }):Play()
        btn.Text = on and "ON" or "OFF"
        btn.TextColor3 = on
            and Color3.new(1,1,1)
            or  Color3.fromRGB(150,150,150)
        if callback then callback(on) end
    end)
end

local function makeButton(label, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(34,139,34)
    btn.Text = label
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order; order += 1
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(20, 100, 20)
        }):Play()
        task.delay(0.1, function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(34,139,34)
            }):Play()
        end)
        if callback then callback() end
    end)
end

-- notify sederhana
local function notify(msg, duration)
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 240, 0, 40)
    notif.Position = UDim2.new(0.5, -120, 0, 60)
    notif.BackgroundColor3 = Color3.fromRGB(34,139,34)
    notif.BorderSizePixel = 0
    notif.ZIndex = 10
    notif.Parent = gui
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)

    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, -10, 1, 0)
    nl.Position = UDim2.new(0, 8, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text = msg
    nl.TextColor3 = Color3.new(1,1,1)
    nl.TextSize = 12
    nl.Font = Enum.Font.GothamBold
    nl.ZIndex = 11
    nl.Parent = notif

    TweenService:Create(notif, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -120, 0, 70)
    }):Play()
    task.delay(duration or 3, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(nl, TweenInfo.new(0.3), {
            TextTransparency = 1
        }):Play()
        task.delay(0.3, function() notif:Destroy() end)
    end)
end

-- ── BUILD UI ─────────────────────────
makeSection("🌿 HARVEST")
makeToggle("Auto Harvest", "AutoHarvest")
makeToggle("Auto Fruit Magnet", "AutoMagnet")

makeSection("💰 SELL")
makeToggle("Auto Sell All", "AutoSellAll")
makeButton("Sell Sekarang", function()
    local ok, result = pcall(function()
        return Networking.NPCS.SellAll:Fire()
    end)
    if ok and result then
        notify("✅ Terjual: " .. (result.SoldCount or "?") ..
               " | " .. (result.TotalSellValue or "?") .. " Sheckles", 4)
    else
        notify("❌ Tidak ada buah / error", 3)
    end
end)

makeButton("Preview Harga", function()
    local ok, result = pcall(function()
        return Networking.NPCS.PreviewSellAll:Fire()
    end)
    if ok and result then
        notify("💰 " .. (result.TotalSellValue or "?") ..
               " Sheckles | " .. (result.FruitCount or "?") .. " buah", 4)
    else
        notify("❌ Tidak ada data", 3)
    end
end)

makeSection("🎁 GIFT & MISC")
makeToggle("Auto Claim Gift", "AutoClaimGift")
makeButton("Claim Gift Sekarang", function()
    local ok, inbox = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)
    if ok and inbox then
        local count = 0
        for giftId, _ in pairs(inbox) do
            pcall(function() Networking.Mailbox.Claim:Fire(giftId) end)
            count += 1
            task.wait(0.5)
        end
        notify("🎁 " .. count .. " gift di-claim!", 3)
    else
        notify("📭 Mailbox kosong", 3)
    end
end)

makeSection("⚙️ UTILITAS")
makeToggle("Anti AFK", "AutoAntiAfk")
makeButton("Pakai Semua Daily Deal", function()
    local ok = pcall(function()
        Networking.NPCS.UseDailyDealAll:Fire()
    end)
    notify(ok and "✅ Daily deal dipakai!" or "❌ Gagal", 3)
end)

-- ── MINIMIZE / CLOSE ─────────────────
minBtn.MouseButton1Click:Connect(function()
    State.Minimized = not State.Minimized
    content.Visible = not State.Minimized
    main.Size = State.Minimized
        and UDim2.new(0, 260, 0, 36)
        or  UDim2.new(0, 260, 0, 400)
    minBtn.Text = State.Minimized and "□" or "–"
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

notify("🌱 Auto Farm loaded!", 3)
print("[GAG2] Auto Farm loaded!")
