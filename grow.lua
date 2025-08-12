-- Full script: Codepik v1.0 (with Auto-Buy Seeds, Gear, and Eggs)

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

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

--// ReGui configuration (Ui library)
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

--// Dicts
local SeedStock = {}
local GearStock = {}
local EggStock = {}
local OwnedSeeds = {}
-- Note: owned gears/eggs typically are tools too; we only need stock for buying

local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false,
	Wet = false,
	Windstruck = false,
	Moonlit = false,
	Chilled = false,
	Choc = false,
	Sandy = false,
	Bloodlit = false,
	Tranquil = false,
	Twisted = false,
	Drenched = false,
	Frozen = false,
	Aurora = false,
	HoneyGlazed = false,
	Zombified = false,
	Shocked = false,
	Celestial = false,
	Disco = false
}

--// Globals
local SelectedSeed, SelectedSeedStock
local SelectedGearStock, SelectedEggStock
local AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, AutoBuyGear, AutoBuyEgg, SellThreshold, NoClip, AutoWalkAllowRandom
local AutoSell, AutoWalk, AutoWalkMaxWait, AutoWalkStatus

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `Codepik v1.0`,
        Theme = "GardenTheme",
		Size = UDim2.fromOffset(300, 200)
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

--// Buy functions for seeds/gears/eggs
local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyGear(GearName: string)
	-- assume server event name BuyGearStock exists
	GameEvents.BuyGearStock:FireServer(GearName)
end

local function BuyEgg(EggName: string)
	-- assume server event name BuyEggStock exists
	GameEvents.BuyEggStock:FireServer(EggName)
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

local function BuyAllSelectedEggs()
    local Egg = SelectedEggStock.Selected
    local Stock = EggStock[Egg]

	if not Stock or Stock <= 0 then return end

    for i = 1, Stock do
        BuyEgg(Egg)
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
	local SeedShop = PlayerGui:FindFirstChild("Seed_Shop")
	if not SeedShop then return {} end

	-- try to locate the items container robustly
	local ItemsContainer
	local anyChild = SeedShop:FindFirstChildWhichIsA("Frame", true)
	if anyChild and anyChild.Parent then
		ItemsContainer = anyChild.Parent
	end

	local NewList = {}

	for _, Item in next, (ItemsContainer and ItemsContainer:GetChildren() or {}) do
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

-- new: gear stock getter
local function GetGearStock(IgnoreNoStock: boolean?): table
	local GearShop = PlayerGui:FindFirstChild("Gear_Shop") or PlayerGui:FindFirstChild("Tool_Shop")
	if not GearShop then return {} end

	local ItemsContainer
	local anyChild = GearShop:FindFirstChildWhichIsA("Frame", true)
	if anyChild and anyChild.Parent then
		ItemsContainer = anyChild.Parent
	end

	local NewList = {}

	for _, Item in next, (ItemsContainer and ItemsContainer:GetChildren() or {}) do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end

		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		if IgnoreNoStock then
			if StockCount <= 0 then continue end
			NewList[Item.Name] = StockCount
			continue
		end

		GearStock[Item.Name] = StockCount
	end

	return IgnoreNoStock and NewList or GearStock
end

-- new: egg stock getter
local function GetEggStock(IgnoreNoStock: boolean?): table
	local EggShop = PlayerGui:FindFirstChild("Egg_Shop") or PlayerGui:FindFirstChild("EggShop")
	if not EggShop then return {} end

	local ItemsContainer
	local anyChild = EggShop:FindFirstChildWhichIsA("Frame", true)
	if anyChild and anyChild.Parent then
		ItemsContainer = anyChild.Parent
	end

	local NewList = {}

	for _, Item in next, (ItemsContainer and ItemsContainer:GetChildren() or {}) do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end

		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		if IgnoreNoStock then
			if StockCount <= 0 then continue end
			NewList[Item.Name] = StockCount
			continue
		end

		EggStock[Item.Name] = StockCount
	end

	return IgnoreNoStock and NewList or EggStock
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

local function AutoWalkLoop()
	if IsSelling then return end

    local Character = LocalPlayer.Character
    local Humanoid = Character.Humanoid

    local Plants = GetHarvestablePlants(true)
	local RandomAllowed = AutoWalkAllowRandom.Value
	local DoRandom = #Plants == 0 or math.random(1, 3) == 2

    --// Random point
    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
		AutoWalkStatus.Text = "Random point"
        return
    end
   
    --// Move to each plant
    for _, Plant in next, Plants do
        local Position = Plant:GetPivot().Position
        Humanoid:MoveTo(Position)
		AutoWalkStatus.Text = Plant.Name
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
	--// Auto-Walk
	MakeLoop(AutoWalk, function()
		local MaxWait = AutoWalkMaxWait.Value
		AutoWalkLoop()
		wait(math.random(1, MaxWait))
	end)

	--// Auto-Harvest
	MakeLoop(AutoHarvest, function()
		HarvestPlants(PlantsPhysical)
	end)

	--// Auto-Buy Seeds
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)

	--// Auto-Buy Gear
	MakeLoop(AutoBuyGear, BuyAllSelectedGears)

	--// Auto-Buy Eggs
	MakeLoop(AutoBuyEgg, BuyAllSelectedEggs)

	--// Auto-Plant
	MakeLoop(AutoPlant, AutoPlantLoop)

	--// Get stocks
	while wait(.1) do
		GetSeedStock()
		GetOwnedSeeds()
		GetGearStock()
		GetEggStock()
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

--// Window
local Window = CreateWindow()

--// Auto-Plant
local PlantNode = Window:TreeNode({Title="Auto-Plant 🥕"})
SelectedSeed = PlantNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = GetSeedStock,
})
AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "Plant at random points"
})
PlantNode:Button({
	Text = "Plant all",
	Callback = AutoPlantLoop,
})

--// Auto-Harvest
local HarvestNode = Window:TreeNode({Title="Auto-Harvest 🚜"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
HarvestNode:Separator({Text="Ignores:"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Auto-Buy Seeds
local BuyNode = Window:TreeNode({Title="Auto-Buy 🥕"})
local OnlyShowStock

SelectedSeedStock = BuyNode:Combo({
	Label = "Seed Name",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
})
AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "Show list stock"
})
BuyNode:Button({
	Text = "Buy all Seeds",
	Callback = BuyAllSelectedSeeds,
})

--// Auto-Buy Gear
local GearNode = Window:TreeNode({Title="Auto-Buy Gear ⚙️"})
local OnlyShowGearStock

SelectedGearStock = GearNode:Combo({
	Label = "Gear Name",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowGearStock and OnlyShowGearStock.Value
		return GetGearStock(OnlyStock)
	end,
})
AutoBuyGear = GearNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
OnlyShowGearStock = GearNode:Checkbox({
	Value = false,
	Label = "Show list stock"
})
GearNode:Button({
	Text = "Buy all Gears",
	Callback = BuyAllSelectedGears,
})

--// Auto-Buy Eggs
local EggNode = Window:TreeNode({Title="Auto-Buy Egg 🥚"})
local OnlyShowEggStock

SelectedEggStock = EggNode:Combo({
	Label = "Egg Name",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowEggStock and OnlyShowEggStock.Value
		return GetEggStock(OnlyStock)
	end,
})
AutoBuyEgg = EggNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
OnlyShowEggStock = EggNode:Checkbox({
	Value = false,
	Label = "Show list stock"
})
EggNode:Button({
	Text = "Buy all Eggs",
	Callback = BuyAllSelectedEggs,
})

--// Auto-Sell
local SellNode = Window:TreeNode({Title="Auto-Sell 💰"})
SellNode:Button({
	Text = "Sell inventory",
	Callback = SellInventory, 
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
SellThreshold = SellNode:SliderInt({
    Label = "Crops threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Auto-Walk
local WallNode = Window:TreeNode({Title="Local Player 🚶"})
AutoWalkStatus = WallNode:Label({
	Text = "None"
})
AutoWalk = WallNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoWalkAllowRandom = WallNode:Checkbox({
	Value = true,
	Label = "Allow random points"
})
NoClip = WallNode:Checkbox({
	Value = false,
	Label = "NoClip"
})
AutoWalkMaxWait = WallNode:SliderInt({
    Label = "Max delay",
    Value = 10,
    Minimum = 1,
    Maximum = 120,
})

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Services
StartServices()
