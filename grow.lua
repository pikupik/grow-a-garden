-- Full Garden UI + Farming Logic (ReGui removed) - Ready to paste
-- Place this in a LocalScript (StarterPlayerScripts / PlayerScripts)

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer:WaitForChild("leaderstats")
local Backpack = LocalPlayer:WaitForChild("Backpack")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ShecklesCount = Leaderstats:WaitForChild("Sheckles")
local ok, GameInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)

--// Folders (game specific)
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local Farms = workspace:WaitForChild("Farm")

--// Theme colors
local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
    White = Color3.fromRGB(255,255,255),
    DarkText = Color3.fromRGB(230,230,230)
}

--// Control objects (mimic ReGui return values)
local SelectedSeed = { Selected = "" }
local SelectedSeedStock = { Selected = "" }

local AutoPlant = { Value = false }
local AutoPlantRandom = { Value = false }
local AutoHarvest = { Value = false }
local AutoBuy = { Value = false }
local AutoSell = { Value = false }
local AutoWalk = { Value = false }
local NoClip = { Value = false }

local AutoWalkAllowRandom = { Value = true }
local AutoWalkMaxWait = { Value = 10 }
local SellThreshold = { Value = 15 }

--// Dicts and globals used by logic
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = { Normal = false, Gold = false, Rainbow = false }

local IsSelling = false

-- Utility: create Instance with props
local function Make(class, props, parent)
    local obj = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    if parent then obj.Parent = parent end
    return obj
end

-- Remove old UI if present
do
    local old = PlayerGui:FindFirstChild("GardenUI")
    if old then old:Destroy() end
end

--// Build UI
local ScreenGui = Make("ScreenGui", { Name = "GardenUI", ResetOnSpawn = false }, PlayerGui)

local MainFrame = Make("Frame", {
    Size = UDim2.fromOffset(540, 360),
    Position = UDim2.new(0.25, 0, 0.2, 0),
    BackgroundColor3 = Accent.Brown,
    BorderSizePixel = 0,
    Active = true,
    Draggable = true
}, ScreenGui)
Make("UICorner", { CornerRadius = UDim.new(0, 10) }, MainFrame)
Make("UIStroke", { Thickness = 2, Color = Accent.DarkGreen }, MainFrame)

local Header = Make("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Accent.DarkGreen,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Make("UICorner", { CornerRadius = UDim.new(0, 8) }, Header)
local Title = Make("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Codepik Free",
    TextColor3 = Accent.White,
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    Parent = Header
})

-- Left sidebar tabs
local Sidebar = Make("Frame", {
    Size = UDim2.new(0, 140, 1, -44),
    Position = UDim2.new(0, 0, 0, 44),
    BackgroundColor3 = Accent.Green,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Make("UICorner", { CornerRadius = UDim.new(0, 8) }, Sidebar)
Make("UIStroke", { Thickness = 1, Color = Accent.DarkGreen }, Sidebar)

-- Right content area
local ContentFrame = Make("Frame", {
    Size = UDim2.new(1, -140, 1, -44),
    Position = UDim2.new(0, 140, 0, 44),
    BackgroundColor3 = Accent.Brown,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Make("UIStroke", { Thickness = 1, Color = Accent.DarkGreen }, ContentFrame)

-- Tabs
local Tabs = {"Auto-Plant", "Auto-Harvest", "Auto-Buy", "Auto-Sell", "Auto-Walk"}
local TabFrames = {}

local function clearChildren(parent)
    for _, c in ipairs(parent:GetChildren()) do
        if not (c:IsA("UICorner") or c:IsA("UIStroke")) then
            c:Destroy()
        end
    end
end

local function ShowTab(name)
    for k, v in pairs(TabFrames) do v.Visible = (k == name) end
end

-- Create tab buttons and frames
for i, name in ipairs(Tabs) do
    local btn = Make("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, (i-1) * 44),
        BackgroundColor3 = Accent.DarkGreen,
        Text = name,
        TextColor3 = Accent.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = Sidebar
    })
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
    Make("UIStroke", { Thickness = 1, Color = Accent.White }, btn)

    local frame = Make("Frame", {
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Visible = (i == 1),
        Parent = ContentFrame
    })
    TabFrames[name] = frame

    btn.MouseButton1Click:Connect(function()
        ShowTab(name)
    end)
end

-- Helper to create label + a simple toggle button
local function CreateToggle(parent, labelText, target)
    local y = #parent:GetChildren() * 0 -- we'll use manual layout
    local container = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local label = Make("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Accent.White,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    local toggle = Make("TextButton", {
        Size = UDim2.new(0, 80, 0, 26),
        Position = UDim2.new(1, -90, 0, 4),
        BackgroundColor3 = Accent.DarkGreen,
        Text = (target.Value and "ON" or "OFF"),
        TextColor3 = Accent.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = container
    })
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, toggle)
    -- Click toggles the target.Value
    toggle.MouseButton1Click:Connect(function()
        target.Value = not target.Value
        toggle.Text = (target.Value and "ON" or "OFF")
        toggle.BackgroundColor3 = (target.Value and Accent.Green or Accent.DarkGreen)
    end)
    return container, toggle
end

-- Helper to create label + +/- numeric control
local function CreateNumberControl(parent, labelText, target, min, max)
    min = min or 0
    max = max or 9999
    local container = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local label = Make("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Accent.White,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    local minus = Make("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -100, 0, 4),
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Parent = container
    })
    local valueLabel = Make("TextLabel", {
        Size = UDim2.new(0, 40, 0, 28),
        Position = UDim2.new(1, -70, 0, 4),
        Text = tostring(target.Value),
        TextScaled = false,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        BackgroundTransparency = 1,
        TextColor3 = Accent.White,
        Parent = container
    })
    local plus = Make("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -28, 0, 4),
        Text = "+",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Parent = container
    })

    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, minus)
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, plus)

    minus.MouseButton1Click:Connect(function()
        target.Value = math.max(min, target.Value - 1)
        valueLabel.Text = tostring(target.Value)
    end)
    plus.MouseButton1Click:Connect(function()
        target.Value = math.min(max, target.Value + 1)
        valueLabel.Text = tostring(target.Value)
    end)
    return container
end

-- Helper to create a dropdown list (simplified)
local function CreateDropdown(parent, labelText, itemsProvider, selectedTable)
    local container = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local label = Make("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = Accent.White,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })
    local current = Make("TextLabel", {
        Size = UDim2.new(0, 200, 0, 26),
        Position = UDim2.new(1, -210, 0, 8),
        BackgroundColor3 = Accent.DarkGreen,
        Text = selectedTable.Selected ~= "" and selectedTable.Selected or "<none>",
        TextColor3 = Accent.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = container
    })
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, current)
    local openBtn = Make("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -30, 0, 8),
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = container
    })
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, openBtn)

    local dropdown = Make("Frame", {
        Size = UDim2.new(0, 220, 0, 120),
        Position = UDim2.new(0, 0, 1, 6),
        BackgroundColor3 = Accent.DarkGreen,
        Visible = false,
        Parent = container
    })
    Make("UICorner", { CornerRadius = UDim.new(0, 6) }, dropdown)
    Make("UIStroke", { Thickness = 1, Color = Accent.White }, dropdown)

    local function refreshItems()
        -- clear
        for _, c in ipairs(dropdown:GetChildren()) do
            if not (c:IsA("UICorner") or c:IsA("UIStroke")) then c:Destroy() end
        end
        local items = itemsProvider()
        local y = 0
        for key, val in pairs(items) do
            local btn = Make("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                Position = UDim2.new(0, 0, 0, y),
                BackgroundTransparency = 0,
                BackgroundColor3 = Accent.Brown,
                Text = tostring(key) .. " (" .. tostring(val) .. ")",
                TextColor3 = Accent.White,
                Font = Enum.Font.Gotham,
                TextSize = 14,
                Parent = dropdown
            })
            Make("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
            btn.MouseButton1Click:Connect(function()
                selectedTable.Selected = tostring(key)
                current.Text = selectedTable.Selected
                dropdown.Visible = false
            end)
            y = y + 28
        end
    end

    openBtn.MouseButton1Click:Connect(function()
        dropdown.Visible = not dropdown.Visible
        if dropdown.Visible then refreshItems() end
    end)
    return container
end

-- Fill Auto-Plant tab
do
    local frame = TabFrames["Auto-Plant"]
    clearChildren(frame)
    CreateDropdown(frame, "Seed to plant:", function()
        -- use SeedStock ignore-empty listing
        local list = {}
        -- refresh Stock first (non-blocking)
        pcall(function() 
            for k,v in pairs(SeedStock) do list[k] = v end
        end)
        return list
    end, SelectedSeed)

    local toggle, _ = CreateToggle(frame, "Enabled", AutoPlant)
    toggle.LayoutOrder = 1
    local randToggle = CreateToggle(frame, "Plant at random", AutoPlantRandom)
    Make("TextButton", {
        Size = UDim2.new(0, 120, 0, 30),
        Position = UDim2.new(0, 0, 0, 100),
        Text = "Plant all now",
        Parent = frame
    }).MouseButton1Click:Connect(function()
        -- run single plant loop
        coroutine.wrap(function() 
            -- call existing AutoPlantLoop (defined below)
            if type(AutoPlantLoop) == "function" then
                AutoPlantLoop()
            end
        end)()
    end)
end

-- Fill Auto-Harvest tab
do
    local frame = TabFrames["Auto-Harvest"]
    clearChildren(frame)
    CreateToggle(frame, "Enabled", AutoHarvest)
    -- ignores section
    local ignoreLabel = Make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 54),
        BackgroundTransparency = 1,
        Text = "Ignores:",
        TextColor3 = Accent.White,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = frame
    })
    local checkNormal = CreateToggle(frame, "Ignore Normal", { Value = HarvestIgnores.Normal })
    local checkGold = CreateToggle(frame, "Ignore Gold", { Value = HarvestIgnores.Gold })
    local checkRainbow = CreateToggle(frame, "Ignore Rainbow", { Value = HarvestIgnores.Rainbow })
    -- wire toggles to HarvestIgnores
    checkNormal.MouseButton1Click = nil
    -- The above creates UI only — but the actual values are read directly from HarvestIgnores table by harvesting logic
    -- For clarity, clicking these toggles will update HarvestIgnores if needed
    -- Let's connect the toggles properly:
    do
        local tbtns = {}
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("Frame") then
                for _, inner in ipairs(child:GetChildren()) do
                    if inner:IsA("TextButton") and inner.Text ~= "Plant all now" then
                        table.insert(tbtns, inner)
                    end
                end
            end
        end
    end
    -- We'll add dedicated toggles for the three ignores:
    local ystart = 30
    local function makeIgnoreToggle(text, key, ypos)
        local c = Make("Frame", { Size = UDim2.new(1,0,0,34), Position = UDim2.new(0,0,0,ypos), BackgroundTransparency = 1, Parent = frame })
        local lbl = Make("TextLabel", { Size = UDim2.new(0.7,0,1,0), BackgroundTransparency = 1, Text = text, TextColor3 = Accent.White, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
        local btn = Make("TextButton", { Size = UDim2.new(0,80,0,26), Position = UDim2.new(1,-90,0,4), BackgroundColor3 = Accent.DarkGreen, Text = (HarvestIgnores[key] and "ON" or "OFF"), TextColor3 = Accent.White, Font = Enum.Font.GothamBold, Parent = c })
        btn.MouseButton1Click:Connect(function()
            HarvestIgnores[key] = not HarvestIgnores[key]
            btn.Text = (HarvestIgnores[key] and "ON" or "OFF")
            btn.BackgroundColor3 = (HarvestIgnores[key] and Accent.Green or Accent.DarkGreen)
        end)
    end
    makeIgnoreToggle("Ignore Normal", "Normal", 40)
    makeIgnoreToggle("Ignore Gold", "Gold", 80)
    makeIgnoreToggle("Ignore Rainbow", "Rainbow", 120)
end

-- Fill Auto-Buy tab
do
    local frame = TabFrames["Auto-Buy"]
    clearChildren(frame)
    CreateDropdown(frame, "Seed to buy:", function()
        -- only list stocks >0
        local list = {}
        for k, v in pairs(SeedStock) do
            if v and v > 0 then list[k] = v end
        end
        return list
    end, SelectedSeedStock)
    CreateToggle(frame, "Enabled", AutoBuy)
    local onlyStockFrame = Make("Frame", { Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1, Parent = frame })
    local onlyStockLabel = Make("TextLabel", { Size = UDim2.new(0.7,0,1,0), BackgroundTransparency = 1, Text = "Only show stock", TextColor3 = Accent.White, Parent = onlyStockFrame })
    local onlyStockBtn = Make("TextButton", { Size = UDim2.new(0,80,0,26), Position = UDim2.new(1,-90,0,4), BackgroundColor3 = Accent.DarkGreen, Text = "OFF", Parent = onlyStockFrame })
    local OnlyShowStock = { Value = false }
    onlyStockBtn.MouseButton1Click:Connect(function()
        OnlyShowStock.Value = not OnlyShowStock.Value
        onlyStockBtn.Text = (OnlyShowStock.Value and "ON" or "OFF")
        onlyStockBtn.BackgroundColor3 = (OnlyShowStock.Value and Accent.Green or Accent.DarkGreen)
    end)

    local buyAllBtn = Make("TextButton", { Size = UDim2.new(0,120,0,30), Position = UDim2.new(0,0,0,90), Text = "Buy all selected", Parent = frame })
    buyAllBtn.MouseButton1Click:Connect(function()
        coroutine.wrap(function() 
            if type(BuyAllSelectedSeeds) == "function" then BuyAllSelectedSeeds() end
        end)()
    end)
end

-- Fill Auto-Sell tab
do
    local frame = TabFrames["Auto-Sell"]
    clearChildren(frame)
    local sellNowBtn = Make("TextButton", { Size = UDim2.new(0,140,0,30), Position = UDim2.new(0,0,0,6), Text = "Sell inventory now", Parent = frame })
    sellNowBtn.MouseButton1Click:Connect(function()
        coroutine.wrap(function() 
            SellInventory()
        end)()
    end)
    CreateToggle(frame, "Enabled", AutoSell)
    CreateNumberControl(frame, "Crops threshold", SellThreshold, 1, 199)
end

-- Fill Auto-Walk tab
do
    local frame = TabFrames["Auto-Walk"]
    clearChildren(frame)
    CreateToggle(frame, "Enabled", AutoWalk)
    CreateToggle(frame, "Allow random points", AutoWalkAllowRandom)
    CreateToggle(frame, "NoClip", NoClip)
    CreateNumberControl(frame, "Max delay", AutoWalkMaxWait, 1, 120)
    local statusLabel = Make("TextLabel", { Size = UDim2.new(1,0,0,30), Position = UDim2.new(0,0,0,140), BackgroundTransparency = 1, Text = "Status: None", TextColor3 = Accent.White, Font = Enum.Font.Gotham, TextSize = 14, Parent = frame })
    -- We'll update AutoWalkStatus in the logic section to set this label's Text
end

--// Core Farming Functions (mostly copied from original, adapted to UI controls)

local function Plant(Position, Seed)
    if not Position or not Seed then return end
    if GameEvents:FindFirstChild("Plant_RE") then
        GameEvents.Plant_RE:FireServer(Position, Seed)
    end
    task.wait(0.3)
end

local function GetFarms()
    return Farms:GetChildren()
end

local function GetFarmOwner(Farm)
    local Important = Farm:FindFirstChild("Important")
    if not Important then return nil end
    local Data = Important:FindFirstChild("Data")
    if not Data then return nil end
    local Owner = Data:FindFirstChild("Owner")
    if not Owner then return nil end
    return Owner.Value
end

local function GetFarm(PlayerName)
    local farms = GetFarms()
    for _, Farm in ipairs(farms) do
        local Owner = GetFarmOwner(Farm)
        if Owner == PlayerName then
            return Farm
        end
    end
    return nil
end

local function SellInventory()
    if IsSelling then return end
    IsSelling = true
    local Character = LocalPlayer.Character
    if not Character or not Character.PrimaryPart then IsSelling = false; return end
    local Previous = Character:GetPivot()
    local PreviousSheckles = ShecklesCount.Value

    -- move to sell spot (hardcoded from your script)
    pcall(function() Character:PivotTo(CFrame.new(62, 4, -26)) end)

    while task.wait() do
        if ShecklesCount.Value ~= PreviousSheckles then break end
        if GameEvents:FindFirstChild("Sell_Inventory") then
            GameEvents.Sell_Inventory:FireServer()
        end
    end
    -- restore
    pcall(function() Character:PivotTo(Previous) end)
    task.wait(0.2)
    IsSelling = false
end

local function BuySeed(Seed)
    if GameEvents:FindFirstChild("BuySeedStock") then
        GameEvents.BuySeedStock:FireServer(Seed)
    end
end

local function BuyAllSelectedSeeds()
    local Seed = SelectedSeedStock.Selected
    if not Seed or Seed == "" then return end
    local Stock = SeedStock[Seed]
    if not Stock or Stock <= 0 then return end
    for i = 1, Stock do
        BuySeed(Seed)
        task.wait(0.05)
    end
end

local function GetSeedInfo(Seed)
    local PlantName = Seed:FindFirstChild("Plant_Name")
    local Count = Seed:FindFirstChild("Numbers")
    if not PlantName then return nil end
    return PlantName.Value, (Count and Count.Value or 0)
end

local function CollectSeedsFromParent(Parent, Seeds)
    for _, Tool in ipairs(Parent:GetChildren()) do
        local Name, Count = GetSeedInfo(Tool)
        if not Name then continue end
        Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
    end
end

local function CollectCropsFromParent(Parent, Crops)
    for _, Tool in ipairs(Parent:GetChildren()) do
        local Name = Tool:FindFirstChild("Item_String")
        if not Name then continue end
        table.insert(Crops, Tool)
    end
end

local function GetOwnedSeeds()
    OwnedSeeds = {}
    local Character = LocalPlayer.Character
    if Backpack then CollectSeedsFromParent(Backpack, OwnedSeeds) end
    if Character then CollectSeedsFromParent(Character, OwnedSeeds) end
    return OwnedSeeds
end

local function GetInvCrops()
    local Character = LocalPlayer.Character
    local Crops = {}
    if Backpack then CollectCropsFromParent(Backpack, Crops) end
    if Character then CollectCropsFromParent(Character, Crops) end
    return Crops
end

local function GetArea(Base)
    if not Base then return 0,0,0,0 end
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
    if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    if Tool.Parent ~= Backpack then return end
    Humanoid:EquipTool(Tool)
end

-- Auto farm init (get player's farm)
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm and MyFarm:FindFirstChild("Important")
local PlantLocations = MyImportant and MyImportant:FindFirstChild("Plant_Locations")
local PlantsPhysical = MyImportant and MyImportant:FindFirstChild("Plants_Physical")

local Dirt = PlantLocations and PlantLocations:FindFirstChildOfClass("Part")
local X1, Z1, X2, Z2 = 0,0,0,0
if Dirt then
    X1, Z1, X2, Z2 = GetArea(Dirt)
else
    -- fallback: find first plantland if exists
    if PlantLocations then
        local part = PlantLocations:FindFirstChildOfClass("Part")
        if part then X1, Z1, X2, Z2 = GetArea(part) end
    end
end

local function GetRandomFarmPoint()
    if not PlantLocations then return Vector3.new(0,4,0) end
    local FarmLands = PlantLocations:GetChildren()
    if #FarmLands == 0 then return Vector3.new(0,4,0) end
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local aX1, aZ1, aX2, aZ2 = GetArea(FarmLand)
    local X = math.random(aX1, aX2)
    local Z = math.random(aZ1, aZ2)
    return Vector3.new(X, 4, Z)
end

-- AutoPlantLoop (connected to AutoPlant.Value)
function AutoPlantLoop()
    local seedName = SelectedSeed.Selected
    if not seedName or seedName == "" then return end

    local SeedData = OwnedSeeds[seedName]
    if not SeedData then return end

    local Count = SeedData.Count or 0
    local Tool = SeedData.Tool

    if Count <= 0 then return end

    local Planted = 0
    local Step = 1

    EquipCheck(Tool)

    if AutoPlantRandom.Value then
        for i = 1, Count do
            local Point = GetRandomFarmPoint()
            Plant(Point, seedName)
        end
    end

    for X = X1, X2, Step do
        for Z = Z1, Z2, Step do
            if Planted > Count then break end
            local Point = Vector3.new(X, 0.13, Z)
            Planted = Planted + 1
            Plant(Point, seedName)
            task.wait(0.03)
        end
    end
end

local function HarvestPlant(Plant)
    if not Plant then return end
    local Prompt = Plant:FindFirstChildWhichIsA("ProximityPrompt", true) or Plant:FindFirstChild("ProximityPrompt", true)
    if not Prompt then return end
    pcall(function() fireproximityprompt(Prompt) end)
end

local function GetSeedStock(IgnoreNoStock)
    -- read seed shop UI in PlayerGui
    -- this function tries to find seed frames under PlayerGui.Seed_Shop
    -- if not found, returns current SeedStock table
    local SeedShop = PlayerGui:FindFirstChild("Seed_Shop")
    if not SeedShop then
        return IgnoreNoStock and {} or SeedStock
    end
    local itemsContainer
    -- some games nest items; attempt to find a child with "Blueberry" as example
    local sample = SeedShop:FindFirstChild("Blueberry", true)
    if sample then itemsContainer = sample.Parent end
    if not itemsContainer then
        -- fallback: use first scrolling frame or Frame with children
        for _, v in ipairs(SeedShop:GetDescendants()) do
            if v:IsA("Frame") and #v:GetChildren() > 0 then
                itemsContainer = v
                break
            end
        end
    end
    local NewList = {}
    if not itemsContainer then return IgnoreNoStock and NewList or SeedStock end

    for _, Item in ipairs(itemsContainer:GetChildren()) do
        local MainFrame = Item:FindFirstChild("Main_Frame")
        if not MainFrame then
            -- sometimes item itself has stock text
            MainFrame = Item
        end
        local StockTextObj = MainFrame:FindFirstChild("Stock_Text")
        if not StockTextObj and MainFrame:FindFirstChildWhichIsA("TextLabel") then
            -- try to find something with digits
            for _, txt in ipairs(MainFrame:GetChildren()) do
                if txt:IsA("TextLabel") and tostring(txt.Text):match("%d+") then
                    StockTextObj = txt
                    break
                end
            end
        end
        local StockCount = 0
        if StockTextObj and tostring(StockTextObj.Text):match("%d+") then
            StockCount = tonumber(tostring(StockTextObj.Text):match("%d+")) or 0
        end

        if IgnoreNoStock then
            if StockCount > 0 then
                NewList[Item.Name] = StockCount
            end
        else
            SeedStock[Item.Name] = StockCount
        end
    end
    return IgnoreNoStock and NewList or SeedStock
end

local function CanHarvest(Plant)
    local Prompt = Plant:FindFirstChildWhichIsA("ProximityPrompt", true) or Plant:FindFirstChild("ProximityPrompt", true)
    if not Prompt then return false end
    if not Prompt.Enabled then return false end
    return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance)
    local Character = LocalPlayer.Character
    if not Character then return Plants end
    local PlayerPosition = Character:GetPivot().Position
    for _, Plant in ipairs(Parent:GetChildren()) do
        local Fruits = Plant:FindFirstChild("Fruits")
        if Fruits then
            CollectHarvestable(Fruits, Plants, IgnoreDistance)
        end
        local ok, pos = pcall(function() return Plant:GetPivot().Position end)
        if not ok then continue end
        local Distance = (PlayerPosition - pos).Magnitude
        if not IgnoreDistance and Distance > 15 then continue end
        local Variant = Plant:FindFirstChild("Variant")
        if Variant and HarvestIgnores[Variant.Value] then continue end
        if CanHarvest(Plant) then table.insert(Plants, Plant) end
    end
    return Plants
end

local function GetHarvestablePlants(IgnoreDistance)
    if not PlantsPhysical then return {} end
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    return Plants
end

local function HarvestPlants(Parent)
    local Plants = GetHarvestablePlants()
    for _, Plant in ipairs(Plants) do
        HarvestPlant(Plant)
        task.wait(0.02)
    end
end

local function AutoSellCheck()
    local CropCount = #GetInvCrops()
    if not AutoSell.Value then return end
    if CropCount < SellThreshold.Value then return end
    SellInventory()
end

local AutoWalkStatus = { Text = "None" } -- minimal binding to UI (we'll try to find status label and update it)
-- find the status label in Auto-Walk tab (weak binding)
do
    local frame = TabFrames["Auto-Walk"]
    if frame then
        for _, c in ipairs(frame:GetChildren()) do
            if c:IsA("TextLabel") and c.Text:find("Status") then
                AutoWalkStatus = c
                break
            end
        end
    end
end

local function AutoWalkLoop()
    if IsSelling then return end
    local Character = LocalPlayer.Character
    if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end

    local Plants = {}
    if PlantsPhysical then Plants = GetHarvestablePlants(true) end
    local RandomAllowed = AutoWalkAllowRandom.Value
    local DoRandom = (#Plants == 0) or (math.random(1, 3) == 2)

    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
        if AutoWalkStatus then pcall(function() AutoWalkStatus.Text = "Random point" end) end
        return
    end

    for _, Plant in ipairs(Plants) do
        local ok, pos = pcall(function() return Plant:GetPivot().Position end)
        if ok and pos then
            Humanoid:MoveTo(pos)
            if AutoWalkStatus then pcall(function() AutoWalkStatus.Text = Plant.Name end) end
            task.wait(0.5)
        end
    end
end

local function NoclipLoop()
    local Character = LocalPlayer.Character
    if not NoClip.Value then return end
    if not Character then return end
    for _, Part in ipairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then
            Part.CanCollide = false
        end
    end
end

-- Utility: wrap a function in a loop while toggle true
local function MakeLoop(Toggle, Func)
    coroutine.wrap(function()
        while task.wait(0.01) do
            if not Toggle.Value then continue end
            local ok, err = pcall(Func)
            if not ok then
                -- print("Loop error:", err)
            end
        end
    end)()
end

-- Update owned seeds & seed stock periodically
local function StartStateUpdater()
    coroutine.wrap(function()
        while task.wait(0.2) do
            pcall(function() GetSeedStock(); GetOwnedSeeds() end)
        end
    end)()
end

-- Connections for live UI -> game updates
RunService.Stepped:Connect(function()
    -- apply noclip continuously if enabled
    if NoClip.Value then NoclipLoop() end
end)

-- Listen to Backpack add (to trigger sell check)
Backpack.ChildAdded:Connect(function()
    pcall(AutoSellCheck)
end)

--// Start all loops / services
function StartServices()
    -- auto-walk loop
    MakeLoop(AutoWalk, function()
        local MaxWait = AutoWalkMaxWait.Value or 10
        AutoWalkLoop()
        task.wait(math.random(1, MaxWait))
    end)

    -- auto-harvest
    MakeLoop(AutoHarvest, function()
        if PlantsPhysical then HarvestPlants(PlantsPhysical) end
    end)

    -- auto-buy
    MakeLoop(AutoBuy, function()
        BuyAllSelectedSeeds()
    end)

    -- auto-plant
    MakeLoop(AutoPlant, AutoPlantLoop)

    -- seed/owned updater
    StartStateUpdater()
end

-- Start services immediately
StartServices()

-- Inform user
print("[GardenUI] UI loaded and services started.")
