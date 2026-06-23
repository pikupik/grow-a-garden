-- ╔══════════════════════════════════════════════════╗
-- ║       Grow A Garden 2 - Auto Farm                ║
-- ║       UI: Rayfield | by Claude                   ║
-- ╚══════════════════════════════════════════════════╝

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"))()

local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS         = game:GetService("ReplicatedStorage")

-- Load Networking module
local Networking = require(RS.SharedModules.Networking)
local PlayerState = require(RS.ClientModules.PlayerStateClient)

-- ══════════════════════════════════════
--  STATE
-- ══════════════════════════════════════
local State = {
    AutoHarvest  = false,
    AutoSellAll  = false,
    AutoMagnet   = false,
    AutoAntiAfk  = false,
    AutoClaimGift= false,
    HarvestDelay = 1,
    SellDelay    = 5,
    MagnetDelay  = 3,
    HarvestCount = 0,
    SellCount    = 0,
}

-- ══════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════
local function safefire(net, ...)
    local ok, err = pcall(function() net:Fire(...) end)
    if not ok then
        warn("[AutoFarm] Error:", err)
    end
end

local function getGardens()
    local ok, gardens = pcall(function()
        local replica = PlayerState:GetLocalReplica()
        if not replica then return {} end
        return replica.Data and replica.Data.Gardens or {}
    end)
    return ok and gardens or {}
end

local function getAllFruits()
    local fruits = {}
    local gardens = getGardens()
    for gardenId, gardenData in pairs(gardens) do
        if gardenData.Fruits then
            for fruitId, fruitData in pairs(gardenData.Fruits) do
                table.insert(fruits, {
                    GardenId = gardenId,
                    FruitId  = fruitId,
                    Data     = fruitData,
                })
            end
        end
    end
    return fruits
end

-- ══════════════════════════════════════
--  LOOPS
-- ══════════════════════════════════════

-- Auto Harvest
task.spawn(function()
    while true do
        task.wait(State.HarvestDelay)
        if not State.AutoHarvest then continue end

        local fruits = getAllFruits()
        local harvested = 0
        for _, fruit in ipairs(fruits) do
            if State.AutoHarvest then
                safefire(Networking.Garden.CollectFruit,
                    fruit.GardenId, fruit.FruitId)
                harvested = harvested + 1
                task.wait(0.15)
            end
        end

        if harvested > 0 then
            State.HarvestCount = State.HarvestCount + harvested
        end
    end
end)

-- Auto Sell All
task.spawn(function()
    while true do
        task.wait(State.SellDelay)
        if not State.AutoSellAll then continue end
        local ok, result = pcall(function()
            return Networking.NPCS.SellAll:Fire()
        end)
        if ok and result then
            local sold = result.SoldCount or 0
            State.SellCount = State.SellCount + sold
        end
    end
end)

-- Auto Fruit Magnet
task.spawn(function()
    while true do
        task.wait(State.MagnetDelay)
        if not State.AutoMagnet then continue end
        safefire(Networking.FruitMagnet.Activate)
    end
end)

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(60)
        if not State.AutoAntiAfk then continue end
        safefire(Networking.AntiAfk.RequestHop)
    end
end)

-- Auto Claim Gift/Mailbox
task.spawn(function()
    while true do
        task.wait(30)
        if not State.AutoClaimGift then continue end
        local ok, inbox = pcall(function()
            return Networking.Mailbox.OpenInbox:Fire()
        end)
        if ok and inbox then
            for giftId, _ in pairs(inbox) do
                pcall(function()
                    Networking.Mailbox.Claim:Fire(giftId)
                end)
                task.wait(0.5)
            end
        end
    end
end)

-- ══════════════════════════════════════
--  RAYFIELD UI
-- ══════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name             = "🌱 Grow A Garden 2",
    LoadingTitle     = "Auto Farm",
    LoadingSubtitle  = "by Claude",
    ConfigurationSaving = {
        Enabled  = true,
        FileName = "GAG2_AutoFarm",
    },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- ─── TAB: FARM ───────────────────────
local FarmTab = Window:CreateTab("🌿 Farm", nil)

FarmTab:CreateSection("Auto Harvest")

FarmTab:CreateToggle({
    Name        = "Auto Harvest",
    CurrentValue= false,
    Flag        = "AutoHarvest",
    Callback    = function(v)
        State.AutoHarvest = v
    end,
})

FarmTab:CreateSlider({
    Name        = "Harvest Delay (detik)",
    Range       = {0.5, 10},
    Increment   = 0.5,
    CurrentValue= 1,
    Flag        = "HarvestDelay",
    Callback    = function(v)
        State.HarvestDelay = v
    end,
})

FarmTab:CreateSection("Auto Sell")

FarmTab:CreateToggle({
    Name        = "Auto Sell All",
    CurrentValue= false,
    Flag        = "AutoSellAll",
    Callback    = function(v)
        State.AutoSellAll = v
    end,
})

FarmTab:CreateSlider({
    Name        = "Sell Delay (detik)",
    Range       = {2, 30},
    Increment   = 1,
    CurrentValue= 5,
    Flag        = "SellDelay",
    Callback    = function(v)
        State.SellDelay = v
    end,
})

FarmTab:CreateButton({
    Name     = "Sell Sekarang",
    Callback = function()
        local ok, result = pcall(function()
            return Networking.NPCS.SellAll:Fire()
        end)
        if ok and result then
            Rayfield:Notify({
                Title    = "Sell Berhasil!",
                Content  = "Terjual: " .. (result.SoldCount or "?") ..
                           " buah | Harga: " .. (result.TotalSellValue or "?"),
                Duration = 4,
                Image    = "rbxassetid://4483345998",
            })
        else
            Rayfield:Notify({
                Title   = "Sell Gagal",
                Content = "Coba lagi atau tidak ada buah",
                Duration= 3,
            })
        end
    end,
})

FarmTab:CreateSection("Fruit Magnet")

FarmTab:CreateToggle({
    Name        = "Auto Fruit Magnet",
    CurrentValue= false,
    Flag        = "AutoMagnet",
    Callback    = function(v)
        State.AutoMagnet = v
    end,
})

FarmTab:CreateSlider({
    Name        = "Magnet Delay (detik)",
    Range       = {1, 10},
    Increment   = 0.5,
    CurrentValue= 3,
    Flag        = "MagnetDelay",
    Callback    = function(v)
        State.MagnetDelay = v
    end,
})

FarmTab:CreateButton({
    Name     = "Aktifkan Magnet Sekarang",
    Callback = function()
        safefire(Networking.FruitMagnet.Activate)
        Rayfield:Notify({
            Title   = "Magnet!",
            Content = "Menarik semua buah...",
            Duration= 2,
        })
    end,
})

-- ─── TAB: MISC ───────────────────────
local MiscTab = Window:CreateTab("⚙️ Misc", nil)

MiscTab:CreateSection("Utilitas")

MiscTab:CreateToggle({
    Name        = "Anti AFK",
    CurrentValue= false,
    Flag        = "AutoAntiAfk",
    Callback    = function(v)
        State.AutoAntiAfk = v
    end,
})

MiscTab:CreateToggle({
    Name        = "Auto Claim Gift (Mailbox)",
    CurrentValue= false,
    Flag        = "AutoClaimGift",
    Callback    = function(v)
        State.AutoClaimGift = v
    end,
})

MiscTab:CreateButton({
    Name     = "Claim Gift Sekarang",
    Callback = function()
        local ok, inbox = pcall(function()
            return Networking.Mailbox.OpenInbox:Fire()
        end)
        if ok and inbox then
            local count = 0
            for giftId, _ in pairs(inbox) do
                pcall(function()
                    Networking.Mailbox.Claim:Fire(giftId)
                end)
                count = count + 1
                task.wait(0.5)
            end
            Rayfield:Notify({
                Title   = "Gift Claimed!",
                Content = count .. " gift berhasil di-claim",
                Duration= 3,
                Image   = "rbxassetid://4483345998",
            })
        else
            Rayfield:Notify({
                Title   = "Tidak Ada Gift",
                Content = "Mailbox kosong atau error",
                Duration= 3,
            })
        end
    end,
})

MiscTab:CreateSection("Daily Deal")

MiscTab:CreateButton({
    Name     = "Cek Daily Deal",
    Callback = function()
        local ok, result = pcall(function()
            return Networking.NPCS.CheckDailyDeal:Fire()
        end)
        if ok and result then
            Rayfield:Notify({
                Title   = "Daily Deal",
                Content = tostring(result),
                Duration= 5,
            })
        end
    end,
})

MiscTab:CreateButton({
    Name     = "Pakai Semua Daily Deal",
    Callback = function()
        local ok, result = pcall(function()
            return Networking.NPCS.UseDailyDealAll:Fire()
        end)
        Rayfield:Notify({
            Title   = ok and "Daily Deal Used!" or "Gagal",
            Content = ok and "Semua daily deal dipakai" or "Error",
            Duration= 3,
        })
    end,
})

-- ─── TAB: INFO ───────────────────────
local InfoTab = Window:CreateTab("📊 Info", nil)

InfoTab:CreateSection("Status Farm")

InfoTab:CreateParagraph({
    Title   = "Cara Pakai",
    Content = "1. Aktifkan Auto Harvest & Auto Sell\n" ..
              "2. Set delay sesuai keinginan\n" ..
              "3. Aktifkan Anti AFK agar tidak di-kick\n" ..
              "4. Auto Magnet bantu collect buah lebih cepat\n" ..
              "5. Auto Claim Gift untuk klaim hadiah mailbox",
})

InfoTab:CreateButton({
    Name     = "Refresh Stats",
    Callback = function()
        Rayfield:Notify({
            Title   = "📊 Stats",
            Content = string.format(
                "Harvest: %d buah\nSell: %d kali",
                State.HarvestCount,
                State.SellCount
            ),
            Duration= 5,
        })
    end,
})

InfoTab:CreateButton({
    Name     = "Preview Harga Jual",
    Callback = function()
        local ok, result = pcall(function()
            return Networking.NPCS.PreviewSellAll:Fire()
        end)
        if ok and result then
            Rayfield:Notify({
                Title   = "💰 Preview Sell",
                Content = string.format(
                    "Total: %s Sheckles\nBuah: %s",
                    tostring(result.TotalSellValue or "?"),
                    tostring(result.FruitCount or "?")
                ),
                Duration= 5,
                Image   = "rbxassetid://4483345998",
            })
        end
    end,
})

print("[GAG2] Auto Farm loaded!")
Rayfield:Notify({
    Title   = "🌱 Grow A Garden 2",
    Content = "Auto Farm berhasil di-load!",
    Duration= 4,
    Image   = "rbxassetid://4483345998",
})
