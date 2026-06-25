local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ALL INCLUDES FOR ROBLOX SCRIPTING
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
      FileName = "Big Hub"
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

-- UI FARM TAB CREATION
local FarmTab = Window:CreateTab("Farm", "sprout")
-- AUTO HARVEST TOGGLE (Working Logic)
local isAutoHarvesting = false

local HarvestToogle = FarmTab:CreateToggle({
   Name = "Auto Harvest",
   CurrentValue = false,
   Flag = "AutoHarvestToggle",
   Callback = function(Value)
      isAutoHarvesting = Value
      
      if Value then
         Notify:Fire("Harvesting...")
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
         Notify:Fire("Auto Harvest Disabled")
      end
   end,
})

local WateringToogle = FarmTab:CreateToggle({
   Name = "FIll ALl Water Example",
   CurrentValue = false,
   Flag = "AutoHarvestToggle",
   Callback = function(Value)
      isAutoHarvesting = Value
      
      if Value then
         Notify:Fire("Harvesting...")
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
         Notify:Fire("Auto Harvest Disabled")
      end
   end,
})

-- EXAMPLE: Auto Sell Toggle (tinggal kamu isi sendiri)
local EconTab = Window:CreateTab("Economy", "dollar-sign")

local SellToggle = EconTab:CreateToggle({
   Name = "Auto Sell (When Full)",
   CurrentValue = false,
   Flag = "AutoSellToggle",
   Callback = function(Value)
      -- TODO: Isi logic auto sell di sini
   end,
})

-- EXAMPLE: Auto Claim Toggle
local ClaimToggle = EconTab:CreateToggle({
   Name = "Auto Claim Mail",
   CurrentValue = false,
   Flag = "AutoClaimToggle",
   Callback = function(Value)
      -- TODO: Isi logic auto claim di sini
   end,
})

Rayfield:LoadConfiguration()
