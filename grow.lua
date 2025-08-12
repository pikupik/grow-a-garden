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

-- Simple elegant color palette
local Accent = {
    DarkGreen = Color3.fromRGB(35, 75, 30),
    Green = Color3.fromRGB(60, 130, 50),
    LightGreen = Color3.fromRGB(85, 170, 75),
    Brown = Color3.fromRGB(40, 32, 20),
    LightBrown = Color3.fromRGB(55, 45, 30),
    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(220, 220, 220),
    Success = Color3.fromRGB(76, 175, 80),
}

ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

ReGui:DefineTheme("ElegantGardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.Green,
    FrameBg = Accent.LightBrown,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
	CollapsingHeaderBgActive = Accent.LightGreen,
    ButtonsBg = Accent.Green,
    ButtonsBgHovered = Accent.LightGreen,
    CheckMark = Accent.Success,
    SliderGrab = Accent.LightGreen,
    Text = Accent.White,
    TextDisabled = Accent.LightGray,
    ComboPreview = Accent.LightBrown,
    ComboPreviewActive = Accent.Green,
    PopupBg = Accent.Brown,
    Separator = Accent.DarkGreen,
})

--// Dicts
local SeedStock = {}
local GearStock = {}
local OwnedSeeds = {}
local HarvestIgnores = { Normal = false, Gold = false, Rainbow = false }
local MutationList = {}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip
local SelectedMutation, AutoHarvestByMutation
local SelectedSeedStock, SelectedGearStock, AutoBuyGear
local OnlyShowStock, OnlyShowGearStock

local function CreateWindow()
	return ReGui:Window({
		Title = `🌿 Codepik v1.3.1`,
        Theme = "ElegantGardenTheme",
		Size = UDim2.fromOffset(360, 280)
	})
end

local function Plant(Position, Seed)
	GameEvents.Plant_RE:FireServer(Position, Seed)
	task.wait(0.3)
end

local function GetFarms()
	return Farms:GetChildren()
end

local function GetFarmOwner(Farm)
	return Farm.Important.Data.Owner.Value
end

local function GetFarm(PlayerName)
	for _, Farm in next, GetFarms() do
		if GetFarmOwner(Farm) == PlayerName then
			return Farm
		end
	end
end

local IsSelling = false
local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value
	if IsSelling then return end
	IsSelling = true
	Character:PivotTo(CFrame.new(62, 4, -26))
	while task.wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)
	task.wait(0.2)
	IsSelling = false
end

local function BuySeed(Seed)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyGear(Gear)
	GameEvents.BuyGearStock:FireServer(Gear)
end

local function BuyAllSelectedSeeds()
	local Seed = SelectedSeedStock.Selected
	local Stock = SeedStock[Seed]
	if not Stock or Stock <= 0 then return end
	for i = 1, Stock do
		BuySeed(Seed)
	end
end

local function BuyAllSelectedGears()
	local Gear = SelectedGearStock.Selected
	local Stock = GearStock[Gear]
	if not Stock or Stock <= 0 then return end
	for i = 1, Stock do
		BuyGear(Gear)
	end
end

local function GetSeedInfo(Seed)
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end
	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds)
	for _, Tool in next, Parent:GetChildren() do
		local Name, Count = GetSeedInfo(Tool)
		if Name then
			Seeds[Name] = { Count = Count, Tool = Tool }
		end
	end
end

local function CollectCropsFromParent(Parent, Crops)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if Name then
			table.insert(Crops, Tool)
		end
	end
end

local function GetOwnedSeeds()
	CollectSeedsFromParent(Backpack, OwnedSeeds)
	CollectSeedsFromParent(LocalPlayer.Character, OwnedSeeds)
	return OwnedSeeds
end

local function GetInvCrops()
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(LocalPlayer.Character, Crops)
	return Crops
end

local function GetArea(Base)
	local Center, Size = Base:GetPivot(), Base.Size
	local X1, Z1 = math.ceil(Center.X - Size.X/2), math.ceil(Center.Z - Size.Z/2)
	local X2, Z2 = math.floor(Center.X + Size.X/2), math.floor(Center.Z + Size.Z/2)
	return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
	if Tool.Parent == Backpack then
		LocalPlayer.Character.Humanoid:EquipTool(Tool)
	end
end

--// My farm vars
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local PlantsPhysical = MyImportant.Plants_Physical
local Dirt = PlantLocations:FindFirstChildOfClass("Part")
local X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint()
	local FarmLand = PlantLocations:GetChildren()[math.random(#PlantLocations:GetChildren())]
	local x1, z1, x2, z2 = GetArea(FarmLand)
	return Vector3.new(math.random(x1, x2), 4, math.random(z1, z2))
end

local function AutoPlantLoop()
	local Seed = SelectedSeed.Selected
	local SeedData = OwnedSeeds[Seed]
	if not SeedData or SeedData.Count <= 0 then return end
	EquipCheck(SeedData.Tool)
	if AutoPlantRandom.Value then
		for i = 1, SeedData.Count do
			Plant(GetRandomFarmPoint(), Seed)
		end
	else
		local Planted, Step = 0, 1
		for X = X1, X2, Step do
			for Z = Z1, Z2, Step do
				if Planted > SeedData.Count then return end
				Planted += 1
				Plant(Vector3.new(X, 0.13, Z), Seed)
			end
		end
	end
end

local function HarvestPlant(Plant)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if Prompt then fireproximityprompt(Prompt) end
end

local function GetSeedStock(IgnoreNoStock)
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Blueberry", true).Parent
	local NewList = {}
	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end
		local StockCount = tonumber(MainFrame.Stock_Text.Text:match("%d+"))
		if IgnoreNoStock and StockCount <= 0 then continue end
		if IgnoreNoStock then
			NewList[Item.Name] = StockCount
		else
			SeedStock[Item.Name] = StockCount
		end
	end
	return IgnoreNoStock and NewList or SeedStock
end

local function GetGearStock(IgnoreNoStock)
	local GearShop = PlayerGui.Gear_Shop
	local Items = GearShop:FindFirstChild("Hoe", true).Parent
	local NewList = {}
	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end
		local StockCount = tonumber(MainFrame.Stock_Text.Text:match("%d+"))
		if IgnoreNoStock and StockCount <= 0 then continue end
		if IgnoreNoStock then
			NewList[Item.Name] = StockCount
		else
			GearStock[Item.Name] = StockCount
		end
	end
	return IgnoreNoStock and NewList or GearStock
end

local function GetMutationList()
	local Mutations = { ["All"] = true }
	for _, Plant in next, PlantsPhysical:GetChildren() do
		local Variant = Plant:FindFirstChild("Variant")
		if Variant then Mutations[Variant.Value] = true end
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			for _, Fruit in next, Fruits:GetChildren() do
				local FV = Fruit:FindFirstChild("Variant")
				if FV then Mutations[FV.Value] = true end
			end
		end
	end
	return Mutations
end

local function CanHarvest(Plant)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	return Prompt and Prompt.Enabled
end

local function IsTargetMutation(Plant)
	if not AutoHarvestByMutation.Value then return true end
	if SelectedMutation.Selected == "All" then return true end
	local Variant = Plant:FindFirstChild("Variant")
	return Variant and Variant.Value == SelectedMutation.Selected
end

local function CollectHarvestable(Parent, Plants)
	for _, Plant in next, Parent:GetChildren() do
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then CollectHarvestable(Fruits, Plants) end
		if not IsTargetMutation(Plant) then continue end
		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then continue end
		if CanHarvest(Plant) then table.insert(Plants, Plant) end
	end
	return Plants
end

local function GetHarvestablePlants()
	return CollectHarvestable(PlantsPhysical, {})
end

local function HarvestPlants()
	for _, Plant in next, GetHarvestablePlants() do
		HarvestPlant(Plant)
	end
end

local function AutoSellCheck()
	if AutoSell.Value and #GetInvCrops() >= SellThreshold.Value then
		SellInventory()
	end
end

local function NoclipLoop()
	if NoClip.Value and LocalPlayer.Character then
		for _, Part in LocalPlayer.Character:GetDescendants() do
			if Part:IsA("BasePart") then Part.CanCollide = false end
		end
	end
end

local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while task.wait(0.01) do
			if Toggle.Value then Func() end
		end
	end)()
end

local function StartServices()
	MakeLoop(AutoHarvest, HarvestPlants)
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)
	MakeLoop(AutoBuyGear, BuyAllSelectedGears)
	MakeLoop(AutoPlant, AutoPlantLoop)
	while task.wait(0.1) do
		GetSeedStock()
		GetGearStock()
		GetOwnedSeeds()
		MutationList = GetMutationList()
	end
end

local function CreateCheckboxes(Parent, Dict)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = `Ignore ${Key}`,
			Callback = function(_, v) Dict[Key] = v end
		})
	end
end

--// UI
local Window = CreateWindow()

-- Auto Plant
local PlantNode = Window:TreeNode({Title="🌱 Auto Plant"})
SelectedSeed = PlantNode:Combo({ Label = "Seed Selection", Selected = "", GetItems = GetSeedStock })
AutoPlant = PlantNode:Checkbox({ Value = false, Label = "Enable Auto Plant" })
AutoPlantRandom = PlantNode:Checkbox({ Value = false, Label = "Random Placement" })
PlantNode:Button({ Text = "🚀 Plant All", Callback = AutoPlantLoop })

-- Auto Harvest
local HarvestNode = Window:TreeNode({Title="🚜 Auto Harvest"})
AutoHarvest = HarvestNode:Checkbox({ Value = false, Label = "Enable Auto Harvest" })
AutoHarvestByMutation = HarvestNode:Checkbox({ Value = false, Label = "Harvest by Mutation" })
SelectedMutation = HarvestNode:Combo({ Label = "Target Mutation", Selected = "All", GetItems = function() return MutationList end })
HarvestNode:Separator({Text="Harvest Filters"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

-- Auto Buy Seeds
local BuyNode = Window:TreeNode({Title="🛒 Auto Buy Seeds"})
SelectedSeedStock = BuyNode:Combo({
	Label = "Seed to Purchase",
	Selected = "",
	GetItems = function()
		return GetSeedStock(OnlyShowStock and OnlyShowStock.Value)
	end,
})
AutoBuy = BuyNode:Checkbox({ Value = false, Label = "Enable Auto Buy Seeds" })
OnlyShowStock = BuyNode:Checkbox({ Value = false, Label = "Show Stock Only" })
BuyNode:Button({ Text = "💳 Buy All Seeds", Callback = BuyAllSelectedSeeds })

-- Auto Buy Gear
local GearNode = Window:TreeNode({Title="🛠 Auto Buy Gear"})
SelectedGearStock = GearNode:Combo({
	Label = "Gear to Purchase",
	Selected = "",
	GetItems = function()
		return GetGearStock(OnlyShowGearStock and OnlyShowGearStock.Value)
	end,
})
AutoBuyGear = GearNode:Checkbox({ Value = false, Label = "Enable Auto Buy Gear" })
OnlyShowGearStock = GearNode:Checkbox({ Value = false, Label = "Show Gear Stock Only" })
GearNode:Button({ Text = "🛒 Buy All Gears", Callback = BuyAllSelectedGears })

-- Auto Sell
local SellNode = Window:TreeNode({Title="💰 Auto Sell"})
SellNode:Button({ Text = "💸 Sell Now", Callback = SellInventory })
AutoSell = SellNode:Checkbox({ Value = false, Label = "Enable Auto Sell" })
SellThreshold = SellNode:SliderInt({ Label = "Crop Threshold", Value = 15, Minimum = 1, Maximum = 199 })

-- Utilities
local UtilityNode = Window:TreeNode({Title="🔧 Player Visual"})
NoClip = UtilityNode:Checkbox({ Value = false, Label = "No Clip Mode" })

-- Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

-- Start services
StartServices()
