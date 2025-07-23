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
    -- Main colors
    DarkGreen = Color3.fromRGB(35, 75, 30),
    Green = Color3.fromRGB(60, 130, 50),
    LightGreen = Color3.fromRGB(85, 170, 75),
    Brown = Color3.fromRGB(40, 32, 20),
    LightBrown = Color3.fromRGB(55, 45, 30),
    
    -- Text and accents
    White = Color3.fromRGB(255, 255, 255),
    LightGray = Color3.fromRGB(220, 220, 220),
    Success = Color3.fromRGB(76, 175, 80),
}

--// Enhanced ReGui configuration with modern theme
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

ReGui:DefineTheme("ElegantGardenTheme", {
	-- Window styling with clean look
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.Green,
    
    -- Frame backgrounds
    FrameBg = Accent.LightBrown,
    FrameBgActive = Accent.Green,
    
    -- Headers
	CollapsingHeaderBg = Accent.Green,
	CollapsingHeaderBgActive = Accent.LightGreen,
    
    -- Interactive elements with larger, cleaner styling
    ButtonsBg = Accent.Green,
    ButtonsBgHovered = Accent.LightGreen,
    CheckMark = Accent.Success,
    SliderGrab = Accent.LightGreen,
    
    -- Text styling - larger and more readable
    Text = Accent.White,
    TextDisabled = Accent.LightGray,
    
    -- Combo/Dropdown specific styling
    ComboPreview = Accent.LightBrown,
    ComboPreviewActive = Accent.Green,
    PopupBg = Accent.Brown,
    
    -- Clean separators
    Separator = Accent.DarkGreen,
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

-- New mutation list for harvesting
local MutationList = {}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip
local SelectedMutation, AutoHarvestByMutation -- New variables for mutation harvesting

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `🌿 Codepik v1.3.1`,
        Theme = "ElegantGardenTheme",
		Size = UDim2.fromOffset(360, 280)
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

-- Function to get available mutations from planted crops
-- Function to get full mutation list from plants (Variant-based)
local function GetMutationList(): table
    local Mutations = {
        ["All"] = true
    }

    for _, Plant in next, PlantsPhysical:GetChildren() do
        -- Cek mutasi utama pada tanaman
        local Variant = Plant:FindFirstChild("Variant")
        if Variant and Variant:IsA("StringValue") then
            Mutations[Variant.Value] = true
        end

        -- Cek mutasi pada buah tanaman jika ada
        local Fruits = Plant:FindFirstChild("Fruits")
        if Fruits then
            for _, Fruit in next, Fruits:GetChildren() do
                local Variant = Fruit:FindFirstChild("Variant")
                if Variant and Variant:IsA("StringValue") then
                    Mutations[Variant.Value] = true
                end
            end
        end
    end

    return Mutations
end


local function CanHarvest(Plant): boolean?
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
    if not Prompt.Enabled then return end

    return true
end

-- Enhanced function to check if plant matches selected mutation
-- Enhanced function to check if plant matches selected mutation (based on Variant)
local function IsTargetMutation(Plant): boolean
    if not AutoHarvestByMutation.Value then return true end
    if SelectedMutation.Selected == "All" then return true end

    local Variant = Plant:FindFirstChild("Variant")
    if Variant and Variant.Value == SelectedMutation.Selected then
        return true
    end

    return false
end


-- Modified CollectHarvestable function - removed distance check and added mutation filter
local function CollectHarvestable(Parent, Plants)
    for _, Plant in next, Parent:GetChildren() do
        --// Fruits
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants)
		end

		--// Mutation check - only harvest if it matches selected mutation
		if not IsTargetMutation(Plant) then continue end

		--// Ignore check
		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then continue end

        --// Collect
        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local function GetHarvestablePlants()
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants)
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

	--// Get stocks and update mutation list
	while wait(.1) do
		GetSeedStock()
		GetOwnedSeeds()
		MutationList = GetMutationList() -- Update available mutations
	end
end

local function CreateCheckboxes(Parent, Dict: table)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = `Ignore ${Key}`,
			Callback = function(_, Value)
				Dict[Key] = Value
			end
		})
	end
end

--// Elegant Window Creation
local Window = CreateWindow()

--// Auto-Plant Section with enhanced dropdowns
local PlantNode = Window:TreeNode({Title="🌱 Auto Plant"})

SelectedSeed = PlantNode:Combo({
	Label = "Seed Selection",
	Selected = "",
	GetItems = GetSeedStock,
	-- Enhanced styling for better readability
	ComboHeight = 22,
	ItemSpacing = 2,
})

AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "Enable Auto Plant"
})

AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "Random Placement"
})

PlantNode:Button({
	Text = "🚀 Plant All",
	Callback = AutoPlantLoop,
})

--// Enhanced Auto-Harvest Section with mutation selection
local HarvestNode = Window:TreeNode({Title="🚜 Auto Harvest"})

AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "Enable Auto Harvest"
})

-- New mutation-based harvesting option
AutoHarvestByMutation = HarvestNode:Checkbox({
	Value = false,
	Label = "Harvest by Mutation"
})

SelectedMutation = HarvestNode:Combo({
	Label = "Target Mutation",
	Selected = "All",
	GetItems = function()
		return MutationList
	end,
	ComboHeight = 22,
	ItemSpacing = 2,
})

HarvestNode:Separator({Text="Harvest Filters"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Auto-Buy Section with enhanced dropdown
local BuyNode = Window:TreeNode({Title="🛒 Auto Buy"})
local OnlyShowStock

SelectedSeedStock = BuyNode:Combo({
	Label = "Seed to Purchase",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
	-- Enhanced dropdown styling
	ComboHeight = 22,
	ItemSpacing = 2,
})

AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "Enable Auto Buy"
})

OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "Show Stock Only"
})

BuyNode:Button({
	Text = "💳 Buy All",
	Callback = BuyAllSelectedSeeds,
})

--// Auto-Sell Section
local SellNode = Window:TreeNode({Title="💰 Auto Sell"})

SellNode:Button({
	Text = "💸 Sell Now",
	Callback = SellInventory,
})

AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "Enable Auto Sell"
})

SellThreshold = SellNode:SliderInt({
    Label = "Crop Threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Utilities Section
local UtilityNode = Window:TreeNode({Title="🔧 Utils"})

NoClip = UtilityNode:Checkbox({
	Value = false,
	Label = "No Clip Mode"
})

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Services
StartServices()
