--//Service
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui

local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

--// Enhanced Color Scheme
local Accent = {
    DarkGreen = Color3.fromRGB(30, 80, 30),
    Green = Color3.fromRGB(60, 140, 60),
    LightGreen = Color3.fromRGB(120, 200, 120),
    Brown = Color3.fromRGB(40, 30, 20),
    Gold = Color3.fromRGB(255, 215, 0),
    Red = Color3.fromRGB(220, 80, 80),
    Blue = Color3.fromRGB(70, 130, 180),
    Orange = Color3.fromRGB(255, 165, 0),
}

--// Enhanced ReGui Configuration
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

ReGui:DefineTheme("EnhancedGardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.LightGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.LightGreen,
    SliderGrab = Accent.LightGreen,
    TextColor = Color3.fromRGB(255, 255, 255),
    AccentColor = Accent.Gold,
})

--// Enhanced Dicts
local SeedStock = {}
local OwnedSeeds = {}
local Statistics = {
    PlantsPlanted = 0,
    PlantsHarvested = 0,
    ShekelsMade = 0,
    SessionStartTime = tick(),
    LastUpdate = tick()
}

local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

local AutoFeatures = {
    Plant = false,
    Harvest = false,
    Buy = false,
    Sell = false,
    Walk = false
}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom
local Window, StatusLabel, MoneyLabel, StatisticsNode

--// Enhanced Window Creation
local function CreateWindow()
	local NewWindow = ReGui:Window({
		Title = `🌱 Codepikk v1.0 | {GameInfo.Name}`,
        Theme = "EnhancedGardenTheme",
		Size = UDim2.fromOffset(380, 280),
        Position = UDim2.fromScale(0.1, 0.1)
	})
    
    -- Add header info
    local HeaderNode = NewWindow:TreeNode({
        Title = "📊 Dashboard",
        DefaultOpen = true
    })
    
    MoneyLabel = HeaderNode:Label({
        Text = `💰 Sheckles: {ShecklesCount.Value:gsub("%d", function(d) return string.char(string.byte("０") + d) end)}`
    })
    
    StatusLabel = HeaderNode:Label({
        Text = "🔄 Status: Ready"
    })
    
    -- Session timer
    local SessionLabel = HeaderNode:Label({
        Text = "⏱️ Session: 00:00"
    })
    
    -- Update session timer
    coroutine.wrap(function()
        while wait(1) do
            local elapsed = tick() - Statistics.SessionStartTime
            local minutes = math.floor(elapsed / 60)
            local seconds = math.floor(elapsed % 60)
            SessionLabel.Text = string.format("⏱️ Session: %02d:%02d", minutes, seconds)
            
            -- Update money display
            MoneyLabel.Text = `💰 Sheckles: {ShecklesCount.Value:gsub("%d+", function(num)
                return string.reverse(string.gsub(string.reverse(num), "...", "%1,"))
            end)}`
        end
    end)()
    
	return NewWindow
end

--// Enhanced Interface Functions
local function Plant(Position: Vector3, Seed: string)
	GameEvents.Plant_RE:FireServer(Position, Seed)
    Statistics.PlantsPlanted = Statistics.PlantsPlanted + 1
    StatusLabel.Text = "🌱 Status: Planting " .. Seed
	wait(.3)
end

local function GetFarms()
	return Farms:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
	local Important = Farm.Important
	local Data = Important.Data
	local Owner = Data.Owner
	return Owner.Value
end

local function GetFarm(PlayerName: string): Folder?
	local Farms = GetFarms()
	for _, Farm in next, Farms do
		local Owner = GetFarmOwner(Farm)
		if Owner == PlayerName then
			return Farm
		end
	end
    return
end

local IsSelling = false
local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value

	if IsSelling then return end
	IsSelling = true
    
    StatusLabel.Text = "💰 Status: Selling crops..."

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then 
            Statistics.ShekelsMade = Statistics.ShekelsMade + (ShecklesCount.Value - PreviousSheckles)
            break 
        end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
    StatusLabel.Text = "✅ Status: Crops sold!"
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
    StatusLabel.Text = "🛒 Status: Buying " .. Seed
end

local function BuyAllSelectedSeeds()
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]

	if not Stock or Stock <= 0 then 
        StatusLabel.Text = "❌ Status: No stock available"
        return 
    end

    StatusLabel.Text = `🛒 Status: Buying {Stock}x {Seed}`
    for i = 1, Stock do
        BuySeed(Seed)
        wait(0.1)
    end
end

local function GetSeedInfo(Seed: Tool): number?
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end
	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name, Count = GetSeedInfo(Tool)
		if not Name then continue end
		Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
	end
end

local function CollectCropsFromParent(Parent, Crops: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if not Name then continue end
		table.insert(Crops, Tool)
	end
end

local function GetOwnedSeeds(): table
	local Character = LocalPlayer.Character
	CollectSeedsFromParent(Backpack, OwnedSeeds)
	CollectSeedsFromParent(Character, OwnedSeeds)
	return OwnedSeeds
end

local function GetInvCrops(): table
	local Character = LocalPlayer.Character
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(Character, Crops)
	return Crops
end

local function GetArea(Base: BasePart)
	local Center = Base:GetPivot()
	local Size = Base.Size
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))
	return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid
    if Tool.Parent ~= Backpack then return end
    Humanoid:EquipTool(Tool)
end

--// Enhanced Auto Farm Functions
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local PlantsPhysical = MyImportant.Plants_Physical

local Dirt = PlantLocations:FindFirstChildOfClass("Part")
local X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint(): Vector3
    local FarmLands = PlantLocations:GetChildren()
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)
    return Vector3.new(X, 4, Z)
end

local function AutoPlantLoop()
	local Seed = SelectedSeed.Selected
	local SeedData = OwnedSeeds[Seed]
	if not SeedData then 
        StatusLabel.Text = "❌ Status: No seeds available"
        return 
    end

    local Count = SeedData.Count
    local Tool = SeedData.Tool

	if Count <= 0 then 
        StatusLabel.Text = "❌ Status: Out of seeds"
        return 
    end

    local Planted = 0
	local Step = 1
    EquipCheck(Tool)
    
    StatusLabel.Text = `🌱 Status: Planting {Count}x {Seed}`

	if AutoPlantRandom.Value then
		for i = 1, Count do
			local Point = GetRandomFarmPoint()
			Plant(Point, Seed)
		end
	else
        for X = X1, X2, Step do
            for Z = Z1, Z2, Step do
                if Planted >= Count then break end
                local Point = Vector3.new(X, 0.13, Z)
                Planted += 1
                Plant(Point, Seed)
            end
        end
    end
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
	fireproximityprompt(Prompt)
    Statistics.PlantsHarvested = Statistics.PlantsHarvested + 1
end

local function GetSeedStock(IgnoreNoStock: boolean?): table
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Blueberry", true).Parent
	local NewList = {}

	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end

		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		if IgnoreNoStock then
			if StockCount <= 0 then continue end
			NewList[Item.Name] = StockCount
			continue
		end

		SeedStock[Item.Name] = StockCount
	end

	return IgnoreNoStock and NewList or SeedStock
end

local function CanHarvest(Plant): boolean?
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
    if not Prompt.Enabled then return end
    return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance: boolean?)
	local Character = LocalPlayer.Character
	local PlayerPosition = Character:GetPivot().Position

    for _, Plant in next, Parent:GetChildren() do
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		local Variant = Plant:FindFirstChild("Variant")
		if HarvestIgnores[Variant.Value] then continue end

        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local function GetHarvestablePlants(IgnoreDistance: boolean?)
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    return Plants
end

local function HarvestPlants(Parent: Model)
	local Plants = GetHarvestablePlants()
    if #Plants > 0 then
        StatusLabel.Text = `🚜 Status: Harvesting {#Plants} plants`
    end
    for _, Plant in next, Plants do
        HarvestPlant(Plant)
    end
end

local function AutoSellCheck()
    local CropCount = #GetInvCrops()
    if not AutoSell.Value then return end
    if CropCount < SellThreshold.Value then return end
    SellInventory()
end

local function AutoWalkLoop()
	if IsSelling then return end

    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid
    local Plants = GetHarvestablePlants(true)
	local RandomAllowed = AutoWalkAllowRandom.Value
	local DoRandom = #Plants == 0 or math.random(1, 3) == 2

    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
		StatusLabel.Text = "🚶 Status: Walking to random point"
        return
    end
   
    for _, Plant in next, Plants do
        local Position = Plant:GetPivot().Position
        Humanoid:MoveTo(Position)
		StatusLabel.Text = `🚶 Status: Walking to {Plant.Name}`
    end
end

local function NoclipLoop()
    local Character = LocalPlayer.Character
    if not NoClip.Value then return end
    if not Character then return end

    for _, Part in Character:GetDescendants() do
        if Part:IsA("BasePart") then
            Part.CanCollide = false
        end
    end
end

local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while wait(.01) do
			if not Toggle.Value then continue end
			Func()
		end
	end)()
end

local function StartServices()
	MakeLoop(AutoWalk, function()
		local MaxWait = AutoWalkMaxWait.Value
		AutoWalkLoop()
		wait(math.random(1, MaxWait))
	end)

	MakeLoop(AutoHarvest, function()
		HarvestPlants(PlantsPhysical)
	end)

	MakeLoop(AutoBuy, BuyAllSelectedSeeds)
	MakeLoop(AutoPlant, AutoPlantLoop)

	while wait(.1) do
		GetSeedStock()
		GetOwnedSeeds()
	end
end

local function CreateCheckboxes(Parent, Dict: table)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = Key,
			Callback = function(_, Value)
				Dict[Key] = Value
			end
		})
	end
end

--// Enhanced Window Creation
Window = CreateWindow()

--// Statistics Section
StatisticsNode = Window:TreeNode({Title="📈 Statistics"})
local PlantedLabel = StatisticsNode:Label({Text = "🌱 Planted: 0"})
local HarvestedLabel = StatisticsNode:Label({Text = "🚜 Harvested: 0"})
local EarnedLabel = StatisticsNode:Label({Text = "💰 Earned: 0"})

-- Update statistics
coroutine.wrap(function()
    while wait(2) do
        PlantedLabel.Text = `🌱 Planted: {Statistics.PlantsPlanted}`
        HarvestedLabel.Text = `🚜 Harvested: {Statistics.PlantsHarvested}`
        EarnedLabel.Text = `💰 Earned: {Statistics.ShekelsMade}`
    end
end)()

--// Enhanced Auto-Plant Section
local PlantNode = Window:TreeNode({Title="🌱 Auto-Plant System"})
SelectedSeed = PlantNode:Combo({
	Label = "🌾 Select Seed",
	Selected = "",
	GetItems = GetSeedStock,
})
AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Plant"
})
AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "🎲 Random Planting"
})
PlantNode:Button({
	Text = "🌱 Plant All Now",
	Callback = AutoPlantLoop,
})

--// Enhanced Auto-Harvest Section
local HarvestNode = Window:TreeNode({Title="🚜 Auto-Harvest System"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Harvest"
})
HarvestNode:Separator({Text="🚫 Harvest Filters:"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Enhanced Auto-Buy Section
local BuyNode = Window:TreeNode({Title="🛒 Auto-Buy System"})
local OnlyShowStock

SelectedSeedStock = BuyNode:Combo({
	Label = "💰 Select Seed to Buy",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
})
AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Buy"
})
OnlyShowStock = BuyNode:Checkbox({
	Value = true,
	Label = "📦 Show In-Stock Only"
})
BuyNode:Button({
	Text = "🛒 Buy All Now",
	Callback = BuyAllSelectedSeeds,
})

--// Enhanced Auto-Sell Section
local SellNode = Window:TreeNode({Title="💰 Auto-Sell System"})
SellNode:Button({
	Text = "💰 Sell Inventory Now",
	Callback = SellInventory, 
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Sell"
})
SellThreshold = SellNode:SliderInt({
    Label = "📊 Crop Threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Enhanced Auto-Walk Section
local WalkNode = Window:TreeNode({Title="🚶 Auto-Walk System"})
AutoWalk = WalkNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Walk"
})
AutoWalkAllowRandom = WalkNode:Checkbox({
	Value = true,
	Label = "🎲 Allow Random Walking"
})
NoClip = WalkNode:Checkbox({
	Value = false,
	Label = "👻 Enable NoClip"
})
AutoWalkMaxWait = WalkNode:SliderInt({
    Label = "⏱️ Max Walk Delay",
    Value = 10,
    Minimum = 1,
    Maximum = 120,
})

--// Quick Actions Section
local QuickNode = Window:TreeNode({Title="⚡ Quick Actions"})
QuickNode:Button({
    Text = "🚀 Enable All Automation",
    Callback = function()
        AutoPlant.Value = true
        AutoHarvest.Value = true
        AutoBuy.Value = true
        AutoSell.Value = true
        AutoWalk.Value = true
        StatusLabel.Text = "🚀 Status: All systems activated!"
    end
})
QuickNode:Button({
    Text = "⏹️ Disable All Automation",
    Callback = function()
        AutoPlant.Value = false
        AutoHarvest.Value = false
        AutoBuy.Value = false
        AutoSell.Value = false
        AutoWalk.Value = false
        StatusLabel.Text = "⏹️ Status: All systems stopped"
    end
})

--// Enhanced Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Keybind System
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        Window.Enabled = not Window.Enabled
    elseif input.KeyCode == Enum.KeyCode.F2 then
        AutoPlant.Value = not AutoPlant.Value
        StatusLabel.Text = `🌱 Auto-Plant: {AutoPlant.Value and "ON" or "OFF"}`
    elseif input.KeyCode == Enum.KeyCode.F3 then
        AutoHarvest.Value = not AutoHarvest.Value
        StatusLabel.Text = `🚜 Auto-Harvest: {AutoHarvest.Value and "ON" or "OFF"}`
    end
end)

--// Startup Message
StatusLabel.Text = "✅ Codepikk Free loaded!"
wait(3)
StatusLabel.Text = "🔄 Status: Ready for farming!"

--// Start Services
StartServices()
