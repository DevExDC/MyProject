-- ============================================
-- HOLDER GUI - PC SERVER VERSION
-- Beautiful UI for managing pet trades
-- ============================================

local PC_SERVER_URL = "http://localhost:8080" -- Built-in, no need to configure

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local holderName = LocalPlayer.Name

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- State
local isRunning = false
local processedRequests = {}
local currentQueue = {}
local stats = {
    completed = 0,
    failed = 0,
    total = 0
}

-- ============================================
-- GUI CREATION
-- ============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HolderGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 450, 0, 550)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -275)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIShadow = Instance.new("ImageLabel")
UIShadow.Name = "Shadow"
UIShadow.Size = UDim2.new(1, 30, 1, 30)
UIShadow.Position = UDim2.new(0, -15, 0, -15)
UIShadow.BackgroundTransparency = 1
UIShadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
UIShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
UIShadow.ImageTransparency = 0.7
UIShadow.ZIndex = 0
UIShadow.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local TitleCover = Instance.new("Frame")
TitleCover.Size = UDim2.new(1, 0, 0, 25)
TitleCover.Position = UDim2.new(0, 0, 1, -25)
TitleCover.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
TitleCover.BorderSizePixel = 0
TitleCover.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "💰 DevEx Holder System"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 40, 0, 40)
CloseButton.Position = UDim2.new(1, -45, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 20
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

-- Content Frame
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -20, 1, -70)
ContentFrame.Position = UDim2.new(0, 10, 0, 60)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ScrollBarThickness = 4
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 700)
ContentFrame.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 10)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

-- Helper function to create sections
local function createSection(name, layoutOrder)
    local Section = Instance.new("Frame")
    Section.Name = name .. "Section"
    Section.Size = UDim2.new(1, 0, 0, 60)
    Section.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    Section.BorderSizePixel = 0
    Section.LayoutOrder = layoutOrder
    Section.Parent = ContentFrame
    
    local SectionCorner = Instance.new("UICorner")
    SectionCorner.CornerRadius = UDim.new(0, 8)
    SectionCorner.Parent = Section
    
    return Section
end

-- Helper function to create textbox
local function createTextbox(parent, placeholderText, defaultText)
    local TextBox = Instance.new("TextBox")
    TextBox.Size = UDim2.new(1, -20, 0, 40)
    TextBox.Position = UDim2.new(0, 10, 0, 10)
    TextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    TextBox.PlaceholderText = placeholderText
    TextBox.Text = defaultText or ""
    TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    TextBox.TextSize = 14
    TextBox.Font = Enum.Font.Gotham
    TextBox.ClearTextOnFocus = false
    TextBox.Parent = parent
    
    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 6)
    BoxCorner.Parent = TextBox
    
    return TextBox
end

-- Pet Kind Section
local PetKindSection = createSection("PetKind", 1)
local PetKindBox = createTextbox(PetKindSection, "Pet Remote ID (e.g., moon_2025_snorgle)", "")

-- Rarity Section  
local RaritySection = createSection("Rarity", 2)
RaritySection.Size = UDim2.new(1, 0, 0, 110)

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, -20, 0, 20)
RarityLabel.Position = UDim2.new(0, 10, 0, 10)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Rarity Filter:"
RarityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
RarityLabel.TextSize = 13
RarityLabel.Font = Enum.Font.Gotham
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = RaritySection

local rarities = {"All", "Common", "Uncommon", "Rare", "Ultra Rare", "Legendary"}
local selectedRarity = "All"
local rarityButtons = {}

local RarityGrid = Instance.new("Frame")
RarityGrid.Size = UDim2.new(1, -20, 0, 70)
RarityGrid.Position = UDim2.new(0, 10, 0, 35)
RarityGrid.BackgroundTransparency = 1
RarityGrid.Parent = RaritySection

local GridLayout = Instance.new("UIGridLayout")
GridLayout.CellSize = UDim2.new(0, 130, 0, 30)
GridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
GridLayout.Parent = RarityGrid

for _, rarity in ipairs(rarities) do
    local RarityBtn = Instance.new("TextButton")
    RarityBtn.Name = rarity
    RarityBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    RarityBtn.Text = rarity
    RarityBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    RarityBtn.TextSize = 12
    RarityBtn.Font = Enum.Font.Gotham
    RarityBtn.Parent = RarityGrid
    
    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = RarityBtn
    
    rarityButtons[rarity] = RarityBtn
    
    RarityBtn.MouseButton1Click:Connect(function()
        selectedRarity = rarity
        for name, btn in pairs(rarityButtons) do
            if name == rarity then
                btn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end)
end

-- Set default
rarityButtons["All"].BackgroundColor3 = Color3.fromRGB(76, 175, 80)
rarityButtons["All"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- Neon Toggle Section
local NeonSection = createSection("Neon", 3)
NeonSection.Size = UDim2.new(1, 0, 0, 60)

local NeonToggle = Instance.new("TextButton")
NeonToggle.Size = UDim2.new(0, 60, 0, 40)
NeonToggle.Position = UDim2.new(1, -70, 0, 10)
NeonToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
NeonToggle.Text = ""
NeonToggle.Parent = NeonSection

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = NeonToggle

local ToggleCircle = Instance.new("Frame")
ToggleCircle.Size = UDim2.new(0, 32, 0, 32)
ToggleCircle.Position = UDim2.new(0, 4, 0.5, -16)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleCircle.BorderSizePixel = 0
ToggleCircle.Parent = NeonToggle

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

local NeonLabel = Instance.new("TextLabel")
NeonLabel.Size = UDim2.new(1, -80, 1, 0)
NeonLabel.Position = UDim2.new(0, 10, 0, 0)
NeonLabel.BackgroundTransparency = 1
NeonLabel.Text = "Neon/Mega Only"
NeonLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
NeonLabel.TextSize = 14
NeonLabel.Font = Enum.Font.Gotham
NeonLabel.TextXAlignment = Enum.TextXAlignment.Left
NeonLabel.Parent = NeonSection

local neonEnabled = false

NeonToggle.MouseButton1Click:Connect(function()
    neonEnabled = not neonEnabled
    
    if neonEnabled then
        TweenService:Create(NeonToggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(76, 175, 80)}):Play()
        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(1, -36, 0.5, -16)}):Play()
    else
        TweenService:Create(NeonToggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
        TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 4, 0.5, -16)}):Play()
    end
end)

-- Queue Section
local QueueSection = createSection("Queue", 4)
QueueSection.Size = UDim2.new(1, 0, 0, 150)

local QueueLabel = Instance.new("TextLabel")
QueueLabel.Size = UDim2.new(1, -20, 0, 25)
QueueLabel.Position = UDim2.new(0, 10, 0, 10)
QueueLabel.BackgroundTransparency = 1
QueueLabel.Text = "📋 Trade Queue (0)"
QueueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
QueueLabel.TextSize = 14
QueueLabel.Font = Enum.Font.GothamBold
QueueLabel.TextXAlignment = Enum.TextXAlignment.Left
QueueLabel.Parent = QueueSection

local QueueScroll = Instance.new("ScrollingFrame")
QueueScroll.Size = UDim2.new(1, -20, 1, -45)
QueueScroll.Position = UDim2.new(0, 10, 0, 35)
QueueScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
QueueScroll.BorderSizePixel = 0
QueueScroll.ScrollBarThickness = 3
QueueScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
QueueScroll.Parent = QueueSection

local QueueCorner = Instance.new("UICorner")
QueueCorner.CornerRadius = UDim.new(0, 6)
QueueCorner.Parent = QueueScroll

local QueueLayout = Instance.new("UIListLayout")
QueueLayout.Padding = UDim.new(0, 3)
QueueLayout.Parent = QueueScroll

-- Stats Section
local StatsSection = createSection("Stats", 5)
StatsSection.Size = UDim2.new(1, 0, 0, 80)

local StatsGrid = Instance.new("Frame")
StatsGrid.Size = UDim2.new(1, -20, 1, -20)
StatsGrid.Position = UDim2.new(0, 10, 0, 10)
StatsGrid.BackgroundTransparency = 1
StatsGrid.Parent = StatsSection

local StatsLayout = Instance.new("UIGridLayout")
StatsLayout.CellSize = UDim2.new(0.33, -7, 0, 25)
StatsLayout.CellPadding = UDim2.new(0, 5, 0, 5)
StatsLayout.Parent = StatsGrid

local function createStatLabel(text)
    local Label = Instance.new("TextLabel")
    Label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 12
    Label.Font = Enum.Font.Gotham
    Label.Parent = StatsGrid
    
    local LabelCorner = Instance.new("UICorner")
    LabelCorner.CornerRadius = UDim.new(0, 6)
    LabelCorner.Parent = Label
    
    return Label
end

local CompletedLabel = createStatLabel("✅ Completed: 0")
local FailedLabel = createStatLabel("❌ Failed: 0")
local TotalLabel = createStatLabel("📊 Total: 0")

-- Start Button
local StartButton = Instance.new("TextButton")
StartButton.Name = "StartButton"
StartButton.Size = UDim2.new(1, -20, 0, 50)
StartButton.Position = UDim2.new(0, 10, 0, 0)
StartButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
StartButton.Text = "▶️ START MONITORING"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 16
StartButton.Font = Enum.Font.GothamBold
StartButton.LayoutOrder = 6
StartButton.Parent = ContentFrame

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 8)
StartCorner.Parent = StartButton

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "⏸️ Idle - Click START to begin"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.LayoutOrder = 7
StatusLabel.Parent = ContentFrame

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
        QueueItem.Size = UDim2.new(1, -5, 0, 25)
        QueueItem.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        QueueItem.Text = string.format("  %d. %s - %d pets", i, request.username, request.pets_needed)
        QueueItem.TextColor3 = Color3.fromRGB(200, 200, 200)
        QueueItem.TextSize = 11
        QueueItem.Font = Enum.Font.Gotham
        QueueItem.TextXAlignment = Enum.TextXAlignment.Left
        QueueItem.Parent = QueueScroll
        
        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 4)
        ItemCorner.Parent = QueueItem
    end
    
    QueueScroll.CanvasSize = UDim2.new(0, 0, 0, #currentQueue * 28)
    QueueLabel.Text = string.format("📋 Trade Queue (%d)", #currentQueue)
end

local function updateStats()
    CompletedLabel.Text = "✅ Completed: " .. stats.completed
    FailedLabel.Text = "❌ Failed: " .. stats.failed
    TotalLabel.Text = "📊 Total: " .. stats.total
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
    local petKind = PetKindBox.Text
    
    if petKind == "" then
        return {}
    end
    
    for _, pet in pairs(playerData.inventory.pets) do
        if pet.kind == petKind then
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
                if selectedRarity:lower():gsub(" ", "_") ~= petRarity:lower() then
                    continue
                end
            end
            
            table.insert(pets, pet.unique)
            
            if #pets >= count then
                break
            end
        end
    end
    
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

local function trade_to_receiver(username, pet_count)
    StatusLabel.Text = string.format("🔄 Trading %d pets to %s...", pet_count, username)
    
    if not Players:FindFirstChild(username) then
        StatusLabel.Text = "❌ " .. username .. " not in server!"
        return false
    end
    
    local pets = get_pets(pet_count)
    
    if #pets < pet_count then
        StatusLabel.Text = string.format("❌ Not enough pets! Have %d, need %d", #pets, pet_count)
        return false
    end
    
    if not send_trade(username) then
        StatusLabel.Text = "❌ Failed to send trade request"
        return false
    end
    
    task.wait(3)
    
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    
    local timeout = 0
    while not tradeGui.Visible and timeout < 10 do
        task.wait(0.5)
        timeout = timeout + 0.5
    end
    
    if timeout >= 10 then
        StatusLabel.Text = "❌ Trade window timeout"
        return false
    end
    
    for i, petUnique in ipairs(pets) do
        add_pet(petUnique)
        StatusLabel.Text = string.format("📦 Adding pets... (%d/%d)", i, #pets)
        task.wait(0.5)
    end
    
    task.wait(2)
    accept_trade()
    task.wait(2)
    confirm_trade()
    
    timeout = 0
    repeat
        task.wait(0.5)
        timeout = timeout + 0.5
    until not tradeGui.Visible or timeout > 15
    
    if timeout > 15 then
        StatusLabel.Text = "⚠️ Trade confirmation timeout"
        return false
    end
    
    StatusLabel.Text = "✅ Trade completed!"
    return true
end

-- Main Loop
local function mainLoop()
    while isRunning do
        task.wait(10)
        
        StatusLabel.Text = "📡 Checking for requests..."
        
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
            StatusLabel.Text = "⏳ Waiting for requests..."
        else
            for i, request in ipairs(currentQueue) do
                stats.total = stats.total + 1
                
                local success = trade_to_receiver(request.username, request.pets_needed)
                
                if success then
                    stats.completed = stats.completed + 1
                    processedRequests[request.username] = true
                else
                    stats.failed = stats.failed + 1
                end
                
                updateStats()
                task.wait(5)
            end
        end
    end
end

-- Start/Stop Button
StartButton.MouseButton1Click:Connect(function()
    if PetKindBox.Text == "" then
        StatusLabel.Text = "❌ Please enter Pet Remote ID!"
        return
    end
    
    isRunning = not isRunning
    
    if isRunning then
        StartButton.Text = "⏸️ STOP MONITORING"
        StartButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        StatusLabel.Text = "✅ Monitoring started!"
        task.spawn(mainLoop)
    else
        StartButton.Text = "▶️ START MONITORING"
        StartButton.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        StatusLabel.Text = "⏸️ Monitoring stopped"
    end
end)

print("✅ Holder GUI Loaded!")
print("💰 DevEx Holder System Ready")
