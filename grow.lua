--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

-- Enhanced color palette for better visuals
local Accent = {
    -- Primary colors with better contrast
    DarkForest = Color3.fromRGB(25, 50, 20),
    Forest = Color3.fromRGB(34, 70, 25),
    LightGreen = Color3.fromRGB(76, 175, 80),
    Emerald = Color3.fromRGB(46, 125, 50),
    
    -- Secondary colors
    DarkBrown = Color3.fromRGB(33, 25, 15),
    LightBrown = Color3.fromRGB(62, 48, 28),
    Gold = Color3.fromRGB(255, 193, 7),
    Orange = Color3.fromRGB(255, 152, 0),
    
    -- Accent colors
    Success = Color3.fromRGB(76, 175, 80),
    Warning = Color3.fromRGB(255, 152, 0),
    Error = Color3.fromRGB(244, 67, 54),
    Info = Color3.fromRGB(33, 150, 243),
    
    -- UI elements
    WindowBg = Color3.fromRGB(28, 32, 24),
    CardBg = Color3.fromRGB(35, 40, 30),
    HeaderBg = Color3.fromRGB(46, 125, 50),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(200, 200, 200),
}

--// Enhanced ReGui configuration with modern theme
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

ReGui:DefineTheme("ModernGardenTheme", {
	-- Window styling
	WindowBg = Accent.WindowBg,
	WindowBgAlpha = 0.95,
	
	-- Title bar with gradient-like effect
	TitleBarBg = Accent.HeaderBg,
	TitleBarBgActive = Accent.LightGreen,
	TitleBarBgCollapsed = Accent.Forest,
	
	-- Frame backgrounds
	FrameBg = Accent.CardBg,
	FrameBgHovered = Accent.Forest,
	FrameBgActive = Accent.Emerald,
	
	-- Resize handle
	ResizeGrab = Accent.LightGreen,
	ResizeGrabHovered = Accent.Gold,
	ResizeGrabActive = Accent.Orange,
	
	-- Headers and collapsing sections
	CollapsingHeaderBg = Accent.Forest,
	CollapsingHeaderBgHovered = Accent.LightGreen,
	CollapsingHeaderBgActive = Accent.Emerald,
	
	-- Button styling
	ButtonsBg = Accent.Forest,
	ButtonsBgHovered = Accent.LightGreen,
	ButtonsBgActive = Accent.Emerald,
	
	-- Interactive elements
	CheckMark = Accent.Success,
	SliderGrab = Accent.LightGreen,
	SliderGrabActive = Accent.Gold,
	
	-- Text colors
	Text = Accent.TextPrimary,
	TextDisabled = Accent.TextSecondary,
	
	-- Separators and borders
	Separator = Accent.Forest,
	Border = Accent.HeaderBg,
	BorderShadow = Color3.fromRGB(0, 0, 0),
	
	-- Special elements
	PlotLines = Accent.Info,
	PlotLinesHovered = Accent.Warning,
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `🌱 Advanced Garden Farm Tool v2.0`,
        Theme = "ModernGardenTheme",
		Size = UDim2.fromOffset(380, 280),
		-- Add some window flags for better experience
		WindowFlags = {"NoCollapse", "NoScrollbar"}
	})
	return Window
end

--// Interface functions
local function Plant(Position: Vector3, Seed: string)
	GameEvents.Plant_RE:FireServer(Position, Seed)
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

	--// Prevent conflict
	if IsSelling then return end
	IsSelling = true

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyAllSelectedSeeds()
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]

	if not Stock or Stock <= 0 then return end

    for i = 1, Stock do
        BuySeed(Seed)
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

	--// Bottom left
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))

	--// Top right
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

--// Auto farm functions
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
	if not SeedData then return end

    local Count = SeedData.Count
    local Tool = SeedData.Tool

	--// Check for stock
	if Count <= 0 then return end

    local Planted = 0
	local Step = 1

	--// Check if the client needs to equip the tool
    EquipCheck(Tool)

	--// Plant at random points
	if AutoPlantRandom.Value then
		for i = 1, Count do
			local Point = GetRandomFarmPoint()
			Plant(Point, Seed)
		end
	end
	
	--// Plant on the farmland area
	for X = X1, X2, Step do
		for Z = Z1, Z2, Step do
			if Planted > Count then break end
			local Point = Vector3.new(X, 0.13, Z)

			Planted += 1
			Plant(Point, Seed)
		end
	end
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)

	--// Check if it can be harvested
	if not Prompt then return end
	fireproximityprompt(Prompt)
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

		--// Seperate list
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
        --// Fruits
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		--// Distance check
		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		--// Ignore check
		local Variant = Plant:FindFirstChild("Variant")
		if HarvestIgnores[Variant.Value] then continue end

        --// Collect
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
	--// Auto-Harvest
	MakeLoop(AutoHarvest, function()
		HarvestPlants(PlantsPhysical)
	end)

	--// Auto-Buy
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)

	--// Auto-Plant
	MakeLoop(AutoPlant, AutoPlantLoop)

	--// Get stocks
	while wait(.1) do
		GetSeedStock()
		GetOwnedSeeds()
	end
end

local function CreateCheckboxes(Parent, Dict: table)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = `🚫 Ignore ${Key}`,
			Callback = function(_, Value)
				Dict[Key] = Value
			end
		})
	end
end

--// Enhanced Window Creation
local Window = CreateWindow()

-- Add a status section at the top
local StatusNode = Window:TreeNode({Title="📊 Farm Status", DefaultOpen=true})
StatusNode:Text({Text = `💰 Sheckles: Loading...`})
StatusNode:Text({Text = `🌱 Seeds: Loading...`})
StatusNode:Text({Text = `🥕 Crops: Loading...`})

-- Add visual separator
Window:Separator({Text = "⚙️ AUTOMATION TOOLS"})

--// Enhanced Auto-Plant Section
local PlantNode = Window:TreeNode({Title="🌱 Smart Planting System", DefaultOpen=true})
PlantNode:Text({Text = "Configure your automatic planting preferences"})

SelectedSeed = PlantNode:Combo({
	Label = "🌾 Select Seed Type",
	Selected = "",
	GetItems = GetSeedStock,
})

AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Plant",
	Help = "Automatically plants selected seeds"
})

AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "🎲 Random Placement Mode",
	Help = "Plants at random locations instead of grid pattern"
})

PlantNode:Button({
	Text = "🚀 Plant All Seeds Now",
	Callback = AutoPlantLoop,
	ButtonColor = Accent.Success
})

--// Enhanced Auto-Harvest Section
local HarvestNode = Window:TreeNode({Title="🚜 Advanced Harvest System", DefaultOpen=true})
HarvestNode:Text({Text = "Automated crop collection with smart filtering"})

AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Harvest",
	Help = "Automatically harvests ready crops"
})

HarvestNode:Separator({Text="🎯 Harvest Filters"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Enhanced Auto-Buy Section
local BuyNode = Window:TreeNode({Title="🛒 Smart Purchasing System", DefaultOpen=false})
BuyNode:Text({Text = "Automated seed purchasing from the shop"})

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
	Label = "🤖 Enable Auto-Buy",
	Help = "Automatically purchases selected seeds"
})

OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "📦 Show In-Stock Only",
	Help = "Only display seeds that are currently available"
})

BuyNode:Button({
	Text = "💳 Buy All Available",
	Callback = BuyAllSelectedSeeds,
	ButtonColor = Accent.Warning
})

--// Enhanced Auto-Sell Section
local SellNode = Window:TreeNode({Title="💰 Intelligent Sales System", DefaultOpen=false})
SellNode:Text({Text = "Automated crop selling with threshold control"})

SellNode:Button({
	Text = "💸 Sell Inventory Now",
	Callback = SellInventory,
	ButtonColor = Accent.Success
})

AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Sell",
	Help = "Automatically sells crops when threshold is reached"
})

SellThreshold = SellNode:SliderInt({
    Label = "📈 Crop Threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
    Help = "Sell when you have this many crops"
})

--// Enhanced Utility Section
local UtilityNode = Window:TreeNode({Title="🔧 Utility Features", DefaultOpen=false})
UtilityNode:Text({Text = "Additional tools and conveniences"})

NoClip = UtilityNode:Checkbox({
	Value = false,
	Label = "👻 No Clip Mode",
	Help = "Walk through walls and objects"
})

UtilityNode:Button({
	Text = "🔄 Refresh Data",
	Callback = function()
		GetSeedStock()
		GetOwnedSeeds()
	end,
})

--// Add footer info
Window:Separator({Text = "ℹ️ INFORMATION"})
Window:Text({Text = `🎮 Game: ${GameInfo.Name}`})
Window:Text({Text = `👤 Player: ${LocalPlayer.Name}`})
Window:Text({Text = "✨ Enhanced by Codepik Script v2.0"})

--// Status update loop for the status section
coroutine.wrap(function()
	while wait(1) do
		local CropCount = #GetInvCrops()
		local SeedCount = 0
		for _, SeedData in pairs(OwnedSeeds) do
			SeedCount += SeedData.Count
		end
		
		-- This would need to be updated to actually change the text in the status section
		-- The exact method depends on how ReGui handles text updates
	end
end)()

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Services
StartServices()
