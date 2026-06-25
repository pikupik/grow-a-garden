local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):FindFirstChild("Networking"))
local Notify = ReplicatedStorage:WaitForChild("Notify")

local Window = Rayfield:CreateWindow({
   Name = "Nexera - GAG 2",
   Icon = 0,
   LoadingTitle = "Nexera Scripts",
   LoadingSubtitle = "by Codepikk",
   ShowText = "NexERA",
   Theme = "Default",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "Nexera_GAG2"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
   KeySettings = {
      Title = "Untitled",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided",
      FileName = "Key",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"Hello"}
   }
})

-----------------------------------------------------------
-- TAB 1: FARM
-----------------------------------------------------------
local FarmTab = Window:CreateTab("Farm", "sprout")

-- Section: HARVEST
local HarvestSection = FarmTab:CreateSection("Harvest")

local isAutoHarvesting = false
HarvestSection:CreateToggle({
   Name = "Auto Harvest",
   CurrentValue = false,
   Flag = "AutoHarvestToggle",
   Callback = function(Value)
      isAutoHarvesting = Value
      
      if Value then
         Notify:Fire("Auto Harvest AKTIF! 🌾")
         task.spawn(function()
            while isAutoHarvesting and task.wait(0.5) do
               pcall(function()
                  local plotId = player:GetAttribute("PlotId")
                  local fruitCount = player:GetAttribute("FruitCount")
                  local maxFruits = player:GetAttribute("MaxFruitCapacity")
                  
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
                     
                     fruitCount = player:GetAttribute("FruitCount") or fruitCount
                  end
               end)
            end
         end)
      else
         Notify:Fire("Auto Harvest DIMATIKAN")
      end
   end,
})

-- Section: WATER (Placeholder buat nanti)
local WaterSection = FarmTab:CreateSection("Water")

WaterSection:CreateToggle({
   Name = "Auto Fill Water (Coming Soon)",
   CurrentValue = false,
   Flag = "AutoWaterToggle",
   Callback = function(Value)
      if Value then
         Notify:Fire("Auto Water belum tersedia. Nanti ya sayang! 💧")
      end
   end,
})

-----------------------------------------------------------
-- TAB 2: ECONOMY
-----------------------------------------------------------
local EconomyTab = Window:CreateTab("Economy", "dollar-sign")

-- Section: SELL
local SellSection = EconomyTab:CreateSection("Sell")

local isAutoSelling = false
SellSection:CreateToggle({
   Name = "Auto Sell All",
   CurrentValue = false,
   Flag = "AutoSellToggle",
   Callback = function(Value)
      isAutoSelling = Value
      
      if Value then
         Notify:Fire("Auto Sell AKTIF! 💰")
         task.spawn(function()
            while isAutoSelling and task.wait(2) do
               pcall(function()
                  local fruitCount = player:GetAttribute("FruitCount") or 0
                  local maxFruits = player:GetAttribute("MaxFruitCapacity") or 100
                  
                  -- Sell kalau tas udah 90% penuh
                  if fruitCount >= (maxFruits * 0.9) then
                     Networking.TeleportButton.Request:Fire("Sell")
                     task.wait(1.5)
                     Networking.NPCS.SellAll:Fire()
                     task.wait(2)
                     Notify:Fire("Fruits sold! 💰")
                  end
               end)
            end
         end)
      else
         Notify:Fire("Auto Sell DIMATIKAN")
      end
   end,
})

-- Load config
Rayfield:LoadConfiguration()
