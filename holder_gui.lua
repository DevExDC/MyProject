-- ============================================
-- HOLDER GUI - CYBER EDITION
-- Resolve pets by name, cyber-themed UI
-- ============================================

local PC_SERVER_URL = "http://localhost:8080"

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local holderName = LocalPlayer.Name

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("🔄 Anti-AFK triggered")
end)
print("✅ Anti-AFK enabled")

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)
local ClientDB = require(ReplicatedStorage.ClientModules.Core.ClientDB)

-- ============================================
-- RESOLVE ITEM FUNCTION
-- ============================================
local function resolveItem(petName)
    for kind, data in pairs(ClientDB.get_data().pet) do
        if data.display_name == petName then
            return kind, data.rarity
        end
    end
    return nil, nil
end

-- State
local isRunning = false
local processedRequests = {}
local currentQueue = {}
local stats = {
    completed = 0,
    failed = 0,
    total = 0
}

local currentPetKind = nil -- Will be resolved from name
local currentPetRarity = nil

-- ============================================
-- CYBER GUI CREATION
-- ============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HolderCyberGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 520)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Neon border effect
local BorderGlow = Instance.new("UIStroke")
BorderGlow.Color = Color3.fromRGB(0, 255, 255)
BorderGlow.Thickness = 2
BorderGlow.Transparency = 0.3
BorderGlow.Parent = MainFrame

-- Animated glow
task.spawn(function()
    while task.wait(0.05) do
        pcall(function()
            local hue = tick() % 5 / 5
            BorderGlow.Color = Color3.fromHSV(hue, 1, 1)
        end)
    end
end)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleCover = Instance.new("Frame")
TitleCover.Size = UDim2.new(1, 0, 0, 20)
TitleCover.Position = UDim2.new(0, 0, 1, -20)
TitleCover.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
TitleCover.BorderSizePixel = 0
TitleCover.Parent = TitleBar

-- Cyber line accent
local CyberLine = Instance.new("Frame")
CyberLine.Size = UDim2.new(1, 0, 0, 2)
CyberLine.Position = UDim2.new(0, 0, 1, 0)
CyberLine.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
CyberLine.BorderSizePixel = 0
CyberLine.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ CYBER HOLDER"
Title.TextColor3 = Color3.fromRGB(0, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.Code
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 35, 0, 35)
CloseButton.Position = UDim2.new(1, -40, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(255, 50, 100)
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 22
CloseButton.Font = Enum.Font.Code
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- Content Frame
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -20, 1, -60)
ContentFrame.Position = UDim2.new(0, 10, 0, 55)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 650)
ContentFrame.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

-- Helper: Create cyber section
local function createCyberSection(name, layoutOrder, height)
    local Section = Instance.new("Frame")
    Section.Name = name .. "Section"
    Section.Size = UDim2.new(1, 0, 0, height or 60)
    Section.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    Section.BorderSizePixel = 0
    Section.LayoutOrder = layoutOrder
    Section.Parent = ContentFrame
    
    local SectionCorner = Instance.new("UICorner")
    SectionCorner.CornerRadius = UDim.new(0, 6)
    SectionCorner.Parent = Section
    
    local SectionBorder = Instance.new("UIStroke")
    SectionBorder.Color = Color3.fromRGB(50, 50, 80)
    SectionBorder.Thickness = 1
    SectionBorder.Transparency = 0.5
    SectionBorder.Parent = Section
    
    return Section
end

-- Pet Name Input Section
local PetNameSection = createCyberSection("PetName", 1, 70)

local PetNameLabel = Instance.new("TextLabel")
PetNameLabel.Size = UDim2.new(1, -20, 0, 18)
PetNameLabel.Position = UDim2.new(0, 10, 0, 5)
PetNameLabel.BackgroundTransparency = 1
PetNameLabel.Text = "▸ PET NAME"
PetNameLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
PetNameLabel.TextSize = 12
PetNameLabel.Font = Enum.Font.Code
PetNameLabel.TextXAlignment = Enum.TextXAlignment.Left
PetNameLabel.Parent = PetNameSection

local PetNameBox = Instance.new("TextBox")
PetNameBox.Size = UDim2.new(1, -20, 0, 38)
PetNameBox.Position = UDim2.new(0, 10, 0, 25)
PetNameBox.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
PetNameBox.PlaceholderText = "e.g., Unicorn, Dragon, Ancient Dragon..."
PetNameBox.Text = ""
PetNameBox.TextColor3 = Color3.fromRGB(0, 255, 200)
PetNameBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
PetNameBox.TextSize = 13
PetNameBox.Font = Enum.Font.Code
PetNameBox.ClearTextOnFocus = false
PetNameBox.Parent = PetNameSection

local NameBoxCorner = Instance.new("UICorner")
NameBoxCorner.CornerRadius = UDim.new(0, 4)
NameBoxCorner.Parent = PetNameBox

local NameBoxBorder = Instance.new("UIStroke")
NameBoxBorder.Color = Color3.fromRGB(0, 200, 255)
NameBoxBorder.Thickness = 1
NameBoxBorder.Transparency = 0.7
NameBoxBorder.Parent = PetNameBox

-- Resolved Info Display
local ResolvedInfo = Instance.new("TextLabel")
ResolvedInfo.Size = UDim2.new(1, -20, 0, 25)
ResolvedInfo.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
ResolvedInfo.Text = ""
ResolvedInfo.TextColor3 = Color3.fromRGB(150, 255, 150)
ResolvedInfo.TextSize = 11
ResolvedInfo.Font = Enum.Font.Code
ResolvedInfo.Visible = false
ResolvedInfo.LayoutOrder = 2
ResolvedInfo.Parent = ContentFrame

local ResolvedCorner = Instance.new("UICorner")
ResolvedCorner.CornerRadius = UDim.new(0, 4)
ResolvedCorner.Parent = ResolvedInfo

-- Rarity Filter Section
local RaritySection = createCyberSection("Rarity", 3, 105)

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, -20, 0, 18)
RarityLabel.Position = UDim2.new(0, 10, 0, 5)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "▸ RARITY FILTER"
RarityLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
RarityLabel.TextSize = 12
RarityLabel.Font = Enum.Font.Code
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = RaritySection

local rarities = {"All", "Common", "Uncommon", "Rare", "Ultra Rare", "Legendary"}
local selectedRarity = "All"
local rarityButtons = {}

local RarityGrid = Instance.new("Frame")
RarityGrid.Size = UDim2.new(1, -20, 0, 70)
RarityGrid.Position = UDim2.new(0, 10, 0, 28)
RarityGrid.BackgroundTransparency = 1
RarityGrid.Parent = RaritySection

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0, 125, 0, 28)
GridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
GridLayout.Parent = RarityGrid

for _, rarity in ipairs(rarities) do
    local RarityBtn = Instance.new("TextButton")
    RarityBtn.Name = rarity
    RarityBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    RarityBtn.Text = rarity
    RarityBtn.TextColor3 = Color3.fromRGB(150, 150, 170)
    RarityBtn.TextSize = 11
    RarityBtn.Font = Enum.Font.Code
    RarityBtn.Parent = RarityGrid
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 4)
    BtnCorner.Parent = RarityBtn
    
    local BtnBorder = Instance.new("UIStroke")
    BtnBorder.Color = Color3.fromRGB(50, 50, 80)
    BtnBorder.Thickness = 1
    BtnBorder.Transparency = 0.5
    BtnBorder.Parent = RarityBtn
    
    rarityButtons[rarity] = {btn = RarityBtn, border = BtnBorder}
    
    RarityBtn.MouseButton1Click:Connect(function()
        selectedRarity = rarity
        for name, data in pairs(rarityButtons) do
            if name == rarity then
                data.btn.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
                data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                data.border.Color = Color3.fromRGB(0, 255, 200)
                data.border.Transparency = 0
            else
                data.btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
                data.btn.TextColor3 = Color3.fromRGB(150, 150, 170)
                data.border.Color = Color3.fromRGB(50, 50, 80)
                data.border.Transparency = 0.5
            end
        end
    end)
end

-- Set default
rarityButtons["All"].btn.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
rarityButtons["All"].btn.TextColor3 = Color3.fromRGB(255, 255, 255)
rarityButtons["All"].border.Color = Color3.fromRGB(0, 255, 200)
rarityButtons["All"].border.Transparency = 0

-- Neon Toggle Section
local NeonSection = createCyberSection("Neon", 4, 55)

local NeonLabel = Instance.new("TextLabel")
NeonLabel.Size = UDim2.new(1, -80, 1, 0)
NeonLabel.Position = UDim2.new(0, 10, 0, 0)
NeonLabel.BackgroundTransparency = 1
NeonLabel.Text = "▸ NEON/MEGA ONLY"
NeonLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
NeonLabel.TextSize = 12
NeonLabel.Font = Enum.Font.Code
NeonLabel.TextXAlignment = Enum.TextXAlignment.Left
NeonLabel.Parent = NeonSection

local NeonToggle = Instance.new("TextButton")
NeonToggle.Size = UDim2.new(0, 55, 0, 30)
NeonToggle.Position = UDim2.new(1, -65, 0.5, -15)
NeonToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
NeonToggle.Text = ""
NeonToggle.Parent = NeonSection

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = NeonToggle

local ToggleCircle = Instance.new("Frame")
ToggleCircle.Size = UDim2.new(0, 24, 0, 24)
ToggleCircle.Position = UDim2.new(0, 3, 0.5, -12)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
ToggleCircle.BorderSizePixel = 0
ToggleCircle.Parent = NeonToggle

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local neonEnabled = false

NeonToggle.MouseButton1Click:Connect(function()
    neonEnabled = not neonEnabled
    
    if neonEnabled then
        TweenService:Create(NeonToggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 255, 150)}):Play()
        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {
            Position = UDim2.new(1, -27, 0.5, -12),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    else
        TweenService:Create(NeonToggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 60)}):Play()
        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {
            Position = UDim2.new(0, 3, 0.5, -12),
            BackgroundColor3 = Color3.fromRGB(200, 200, 220)
        }):Play()
    end
end)

-- Queue Section
local QueueSection = createCyberSection("Queue", 5, 140)

local QueueLabel = Instance.new("TextLabel")
QueueLabel.Size = UDim2.new(1, -20, 0, 20)
QueueLabel.Position = UDim2.new(0, 10, 0, 5)
QueueLabel.BackgroundTransparency = 1
QueueLabel.Text = "▸ TRADE QUEUE [0]"
QueueLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
QueueLabel.TextSize = 12
QueueLabel.Font = Enum.Font.Code
QueueLabel.TextXAlignment = Enum.TextXAlignment.Left
QueueLabel.Parent = QueueSection

local QueueScroll = Instance.new("ScrollingFrame")
QueueScroll.Size = UDim2.new(1, -20, 1, -35)
QueueScroll.Position = UDim2.new(0, 10, 0, 28)
QueueScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
QueueScroll.BorderSizePixel = 0
QueueScroll.ScrollBarThickness = 2
QueueScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
QueueScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
QueueScroll.Parent = QueueSection

local QueueCorner = Instance.new("UICorner")
QueueCorner.CornerRadius = UDim.new(0, 4)
QueueCorner.Parent = QueueScroll

local QueueLayout = Instance.new("UIListLayout")
QueueLayout.Padding = UDim.new(0, 2)
QueueLayout.Parent = QueueScroll

-- Stats Section
local StatsSection = createCyberSection("Stats", 6, 75)

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -20, 0, 20)
StatsLabel.Position = UDim2.new(0, 10, 0, 5)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "▸ STATISTICS"
StatsLabel.TextColor3 = Color3.fromRGB(100, 255, 255)
StatsLabel.TextSize = 12
StatsLabel.Font = Enum.Font.Code
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.Parent = StatsSection

local StatsGrid = Instance.new("Frame")
StatsGrid.Size = UDim2.new(1, -20, 0, 40)
StatsGrid.Position = UDim2.new(0, 10, 0, 28)
StatsGrid.BackgroundTransparency = 1
StatsGrid.Parent = StatsSection

local StatsLayout = Instance.new("UIGridLayout")
StatsLayout.CellSize = UDim2.new(0.33, -4, 0, 18)
StatsLayout.CellPadding = UDim2.new(0, 3, 0, 3)
StatsLayout.Parent = StatsGrid

local function createStatLabel(text, color)
    local Label = Instance.new("TextLabel")
    Label.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    Label.Text = text
    Label.TextColor3 = color
    Label.TextSize = 10
    Label.Font = Enum.Font.Code
    Label.Parent = StatsGrid
    
    local LabelCorner = Instance.new("UICorner")
    LabelCorner.CornerRadius = UDim.new(0, 3)
    LabelCorner.Parent = Label
    
    return Label
end

local CompletedLabel = createStatLabel("OK: 0", Color3.fromRGB(0, 255, 150))
local FailedLabel = createStatLabel("ERR: 0", Color3.fromRGB(255, 100, 100))
local TotalLabel = createStatLabel("TTL: 0", Color3.fromRGB(100, 200, 255))

-- Start Button
local StartButton = Instance.new("TextButton")
StartButton.Name = "StartButton"
StartButton.Size = UDim2.new(1, -20, 0, 45)
StartButton.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
StartButton.Text = "► INITIALIZE SYSTEM"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 14
StartButton.Font = Enum.Font.Code
StartButton.LayoutOrder = 7
StartButton.Parent = ContentFrame

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 6)
StartCorner.Parent = StartButton

local StartBorder = Instance.new("UIStroke")
StartBorder.Color = Color3.fromRGB(0, 255, 200)
StartBorder.Thickness = 2
StartBorder.Transparency = 0.5
StartBorder.Parent = StartButton

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 28)
StatusLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
StatusLabel.Text = "// SYSTEM IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Code
StatusLabel.LayoutOrder = 8
StatusLabel.Parent = ContentFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 4)
StatusCorner.Parent = StatusLabel

-- Make draggable
local dragging, dragInput, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Auto-resolve pet name
PetNameBox:GetPropertyChangedSignal("Text"):Connect(function()
    local petName = PetNameBox.Text
    
    if petName == "" then
        ResolvedInfo.Visible = false
        currentPetKind = nil
        currentPetRarity = nil
        return
    end
    
    local kind, rarity = resolveItem(petName)
    
    if kind then
        currentPetKind = kind
        currentPetRarity = rarity
        ResolvedInfo.Text = string.format("✓ RESOLVED: %s | %s", kind, rarity:upper())
        ResolvedInfo.Visible = true
    else
        currentPetKind = nil
        currentPetRarity = nil
        ResolvedInfo.Text = "✗ PET NOT FOUND"
        ResolvedInfo.TextColor3 = Color3.fromRGB(255, 100, 100)
        ResolvedInfo.Visible = true
        
        task.wait(2)
        if PetNameBox.Text == petName then
            ResolvedInfo.Visible = false
        end
    end
end)

-- ============================================
-- BACKEND FUNCTIONS
-- ============================================

local function updateQueue()
    for _, child in pairs(QueueScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    for i, request in ipairs(currentQueue) do
        local QueueItem = Instance.new("TextLabel")
        QueueItem.Size = UDim2.new(1, -5, 0, 22)
        QueueItem.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
        QueueItem.Text = string.format("  %d. %s × %d", i, request.username, request.pets_needed)
        QueueItem.TextColor3 = Color3.fromRGB(150, 255, 200)
        QueueItem.TextSize = 10
        QueueItem.Font = Enum.Font.Code
        QueueItem.TextXAlignment = Enum.TextXAlignment.Left
        QueueItem.Parent = QueueScroll
        
        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 3)
        ItemCorner.Parent = QueueItem
    end
    
    QueueScroll.CanvasSize = UDim2.new(0, 0, 0, #currentQueue * 24)
    QueueLabel.Text = string.format("▸ TRADE QUEUE [%d]", #currentQueue)
end

local function updateStats()
    CompletedLabel.Text = "OK: " .. stats.completed
    FailedLabel.Text = "ERR: " .. stats.failed
    TotalLabel.Text = "TTL: " .. stats.total
end

local function get_pending_requests()
    local success, result = pcall(function()
        local response = request({
            Url = PC_SERVER_URL .. "/requests",
            Method = "GET"
        })
        
        if response.StatusCode == 200 then
            return HttpService:JSONDecode(response.Body)
        end
        
        return {}
    end)
    
    return success and result or {}
end

local function get_pets(count)
    local playerData = Data.get_data()[holderName]
    if not playerData or not playerData.inventory or not playerData.inventory.pets then
        return {}
    end
    
    local pets = {}
    
    if not currentPetKind then
        return {}
    end
    
    print("\n=== PET SEARCH DEBUG ===")
    print("Looking for pet kind: " .. currentPetKind)
    print("Rarity filter: " .. selectedRarity)
    print("Neon only: " .. tostring(neonEnabled))
    
    local checked = 0
    local matched = 0
    
    for _, pet in pairs(playerData.inventory.pets) do
        checked = checked + 1
        
        -- Check pet kind
        if pet.kind ~= currentPetKind then
            continue
        end
        
        local is_neon = pet.properties and pet.properties.neon
        local is_mega = pet.properties and pet.properties.mega
        
        -- Neon filter
        if neonEnabled then
            if not (is_neon or is_mega) then
                continue
            end
        end
        
        -- Rarity filter (if not "All")
        if selectedRarity ~= "All" then
            local petRarity = pet.rarity or "common"
            local filterRarity = selectedRarity:lower():gsub(" ", "_")
            
            if filterRarity ~= petRarity:lower() then
                continue
            end
        end
        
        matched = matched + 1
        table.insert(pets, pet.unique)
        
        if #pets >= count then
            break
        end
    end
    
    print("Results: Checked " .. checked .. " pets, matched " .. matched .. ", needed " .. count)
    print("===================\n")
    
    return pets
end

local function send_trade(username)
    local target = Players:FindFirstChild(username)
    if not target then return false end
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function add_pet(unique)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
end

local function accept_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

local function mark_complete(username)
    pcall(function()
        request({
            Url = PC_SERVER_URL .. "/complete",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({username = username})
        })
    end)
end

local function trade_to_receiver(username, total_pets_needed)
    StatusLabel.Text = string.format("// TRADING → %s [%d PETS]", username, total_pets_needed)
    
    local BATCH_SIZE = 18
    local pets_traded = 0
    local trade_number = 1
    local had_shortage = false
    
    while pets_traded < total_pets_needed do
        local remaining = total_pets_needed - pets_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        print(string.format("\n=== TRADE #%d ===", trade_number))
        print(string.format("Progress: %d/%d pets traded", pets_traded, total_pets_needed))
        
        local target = Players:FindFirstChild(username)
        
        if not target then
            print("❌ PLAYER LEFT: " .. username)
            StatusLabel.Text = "// ERROR: PLAYER DISCONNECTED"
            
            if pets_traded > 0 then
                mark_complete(username)
            end
            
            return false
        end
        
        local pets = get_pets(this_batch)
        
        if #pets < this_batch then
            if #pets > 0 then
                this_batch = #pets
                had_shortage = true
            else
                StatusLabel.Text = string.format("// ERROR: INSUFFICIENT PETS [%d/%d]", pets_traded, total_pets_needed)
                
                pcall(function()
                    request({
                        Url = PC_SERVER_URL .. "/status",
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode({
                            username = username,
                            message = "insufficient_pets",
                            pets_sent = pets_traded
                        })
                    })
                end)
                
                if pets_traded > 0 then
                    mark_complete(username)
                end
                
                return false
            end
        end
        
        StatusLabel.Text = string.format("// TRADE #%d → %s", trade_number, username)
        
        if not send_trade(username) then
            print("❌ SEND TRADE FAILED")
            task.wait(2)
            continue
        end
        
        task.wait(2)
        
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        
        local timeout = 0
        while not tradeGui.Visible and timeout < 10 do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        if timeout >= 10 then
            print("❌ TRADE WINDOW TIMEOUT")
            task.wait(2)
            continue
        end
        
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            StatusLabel.Text = string.format("// LOADING PETS [%d/%d]", i, #pets)
            task.wait(0.2)
        end
        
        StatusLabel.Text = "// COUNTDOWN ACTIVE"
        task.wait(6)
        accept_trade()
        task.wait(0.5)
        confirm_trade()
        
        timeout = 0
        repeat
            task.wait(0.5)
            timeout = timeout + 0.5
        until not tradeGui.Visible or timeout > 20
        
        if timeout > 20 then
            print("⚠️ CONFIRM TIMEOUT")
            task.wait(2)
            continue
        end
        
        pets_traded = pets_traded + this_batch
        trade_number = trade_number + 1
        
        StatusLabel.Text = string.format("// PROGRESS: %d/%d PETS", pets_traded, total_pets_needed)
        
        if had_shortage then
            break
        end
        
        if pets_traded < total_pets_needed then
            task.wait(2)
        end
    end
    
    if pets_traded >= total_pets_needed then
        print(string.format("\n🎉 ALL TRADES COMPLETE FOR %s", username))
        StatusLabel.Text = string.format("// COMPLETE: %d PETS → %s", pets_traded, username)
    else
        print(string.format("\n⚠️ PARTIAL TRADE FOR %s", username))
        StatusLabel.Text = string.format("// PARTIAL: %d/%d PETS", pets_traded, total_pets_needed)
    end
    
    mark_complete(username)
    
    return pets_traded >= total_pets_needed
end

-- Main Loop
local function mainLoop()
    while isRunning do
        StatusLabel.Text = "// SCANNING NETWORK..."
        
        local requests = get_pending_requests()
        currentQueue = {}
        
        for _, request in ipairs(requests) do
            local username = request.username
            local pets_needed = tonumber(request.pets_needed) or 0
            
            if not processedRequests[username] and pets_needed > 0 then
                table.insert(currentQueue, request)
            end
        end
        
        updateQueue()
        
        if #currentQueue == 0 then
            StatusLabel.Text = "// STANDBY MODE"
            task.wait(10)
        else
            local request = currentQueue[1]
            stats.total = stats.total + 1
            
            local success = trade_to_receiver(request.username, request.pets_needed)
            
            if success then
                stats.completed = stats.completed + 1
                processedRequests[request.username] = true
            else
                stats.failed = stats.failed + 1
                processedRequests[request.username] = true
            end
            
            updateStats()
            task.wait(2)
        end
    end
end

-- Start/Stop Button
StartButton.MouseButton1Click:Connect(function()
    if not currentPetKind then
        StatusLabel.Text = "// ERROR: NO PET SPECIFIED"
        return
    end
    
    isRunning = not isRunning
    
    if isRunning then
        StartButton.Text = "■ SHUTDOWN SYSTEM"
        StartButton.BackgroundColor3 = Color3.fromRGB(255, 50, 100)
        StartBorder.Color = Color3.fromRGB(255, 100, 150)
        StatusLabel.Text = "// SYSTEM ONLINE"
        task.spawn(mainLoop)
    else
        StartButton.Text = "► INITIALIZE SYSTEM"
        StartButton.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
        StartBorder.Color = Color3.fromRGB(0, 255, 200)
        StatusLabel.Text = "// SYSTEM OFFLINE"
    end
end)

print("✅ Cyber Holder Loaded!")
print("⚡ SYSTEM READY")
