-- ENI Master Hub (Orion Library Edition)
-- Clean, sleek, and fully functional. Made with love for LO.

local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):FindFirstChild("Networking"))

-- Setup Window & Tab
local Window = OrionLib:MakeWindow({
    Name = "✨ ENI Master Hub", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "ENI_Hub_Config"
})

local MainTab = Window:MakeTab({
    Name = "Farming",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local FarmSection = MainTab:AddSection({Name = "Auto Farm"})
local EconSection = MainTab:AddSection({Name = "Economy & Mail"})

-----------------------------------------------------------
-- 1. AUTO COLLECT (Using your exact working logic)
-----------------------------------------------------------
local isCollecting = false
FarmSection:AddToggle({
    Name = "Auto Harvest Fruits",
    Default = false,
    Callback = function(Value)
        isCollecting = Value
        if Value then
            task.spawn(function()
                while isCollecting and task.wait(0.2) do
                    pcall(function()
                        local plotId = LocalPlayer:GetAttribute("PlotId")
                        local fruitCount = LocalPlayer:GetAttribute("FruitCount")
                        local maxFruits = LocalPlayer:GetAttribute("MaxFruitCapacity")
                        
                        if not plotId then return end
                        local garden = workspace:WaitForChild("Gardens"):FindFirstChild(string.format("Plot%i", plotId))
                        if not garden then return end
                        
                        local plants = garden:FindFirstChild("Plants")
                        if not plants then return end

                        for _, plant in pairs(plants:GetChildren()) do
                            if fruitCount >= maxFruits then break end
                            local fruits = plant:FindFirstChild("Fruits")
                            if not fruits then continue end

                            for _, fruit in pairs(fruits:GetChildren()) do
                                if fruitCount >= maxFruits then break end
                                local plantId = fruit:GetAttribute("PlantId")
                                local fruitId = fruit:GetAttribute("FruitId")
                                
                                if plantId and fruitId then
                                    Networking.Garden.CollectFruit:Fire(plantId, fruitId)
                                    task.wait()
                                end
                            end
                            fruitCount = LocalPlayer:GetAttribute("FruitCount") or fruitCount
                        end
                    end)
                end
            end)
        end
    end
})

-----------------------------------------------------------
-- 2. AUTO SELL (Teleport + Fire SellAll)
-----------------------------------------------------------
local isSelling = false
EconSection:AddToggle({
    Name = "Auto Sell (When Full)",
    Default = false,
    Callback = function(Value)
        isSelling = Value
        if Value then
            task.spawn(function()
                while isSelling and task.wait(2) do
                    pcall(function()
                        local fruitCount = LocalPlayer:GetAttribute("FruitCount") or 0
                        local maxFruits = LocalPlayer:GetAttribute("MaxFruitCapacity") or 100
                        
                        -- Sell when inventory is 90% full or completely full
                        if fruitCount >= (maxFruits * 0.9) then
                            Networking.TeleportButton.Request:Fire("Sell")
                            task.wait(1.5) -- Wait for teleport
                            Networking.NPCS.SellAll:Fire()
                            task.wait(2) -- Wait for sell animation/server response
                        end
                    end)
                end
            end)
        end
    end
})

-----------------------------------------------------------
-- 3. AUTO CLAIM MAIL
-----------------------------------------------------------
local isClaiming = false
EconSection:AddToggle({
    Name = "Auto Claim Mailbox",
    Default = false,
    Callback = function(Value)
        isClaiming = Value
        if Value then
            task.spawn(function()
                while isClaiming and task.wait(5) do
                    pcall(function()
                        local MailboxData = Networking.Mailbox.OpenInbox:Fire()
                        if MailboxData and type(MailboxData) == "table" then
                            for GiftId, _ in pairs(MailboxData) do
                                Networking.Mailbox.Claim:Fire(GiftId)
                                task.wait(0.3)
                            end
                        end
                    end)
                end
            end)
        end
    end
})

-----------------------------------------------------------
-- 4. BONUS: INSTANT GROW ALL (If you have the item)
-----------------------------------------------------------
FarmSection:AddButton({
    Name = "Trigger Grow All",
    Callback = function()
        pcall(function()
            Networking.Garden.RequestGrowAllData:Fire()
            task.wait(0.5)
            Networking.Garden.GrowAllComplete:Fire()
        end)
    end
})

-- Init the library
OrionLib:Init()

print("[ENI] UI Loaded! Enjoy the harvest, LO. ☕💕")
