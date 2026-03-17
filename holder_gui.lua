-- ============================================
-- HOLDER GUI - MODERN CLEAN UI
-- Works with ngrok tunnels for remote access
-- ============================================

-- CONFIGURATION - Paste your ngrok URL here
local NGROK_URL = "https://spinelike-lenora-unmovingly.ngrok-free.dev"

if NGROK_URL:sub(-1) == "/" then
    NGROK_URL = NGROK_URL:sub(1, -2)
end

print("🌐 Using ngrok URL: " .. NGROK_URL)

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
end)
print("✅ Anti-AFK enabled")

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- State
local isRunning = false
local processedRequests = {}
local currentQueue = {}
local stats = {completed = 0, failed = 0, total = 0}
local connectionStatus = "⚠️ Not tested"

-- Config
local selectedRarity = "All"
local neonEnabled = false

-- ============================================
-- MODERN CLEAN GUI
-- ============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HolderGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame (Responsive for all devices)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 340, 0, 480)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

-- Auto-scale for smaller screens
local function updateScale()
    local screenSize = workspace.CurrentCamera.ViewportSize
    local scale = math.min(screenSize.X / 340, screenSize.Y / 480)
    if scale < 1 then
        MainFrame.Size = UDim2.new(0, 340 * scale * 0.95, 0, 480 * scale * 0.95)
        MainFrame.Position = UDim2.new(0.5, -170 * scale * 0.95, 0.5, -240 * scale * 0.95)
    end
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 16)
HeaderCorner.Parent = Header

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 30)
HeaderCover.Position = UDim2.new(0, 0, 1, -30)
HeaderCover.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
HeaderCover.BorderSizePixel = 0
HeaderCover.Parent = Header

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 20, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "💰 DevEx Holder"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 36, 0, 36)
CloseButton.Position = UDim2.new(1, -48, 0, 12)
CloseButton.BackgroundColor3 = Color3.fromRGB(235, 64, 52)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 18
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseButton

-- Content Area
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, -32, 1, -110)
ContentFrame.Position = UDim2.new(0, 16, 0, 68)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
ContentFrame.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 12)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

-- Helper: Create Card
local function createCard(name, height, order)
    local Card = Instance.new("Frame")
    Card.Name = name
    Card.Size = UDim2.new(1, 0, 0, height)
    Card.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    Card.BorderSizePixel = 0
    Card.LayoutOrder = order
    Card.Parent = ContentFrame
    
    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 10)
    CardCorner.Parent = Card
    
    return Card
end

-- 1. Pet ID Input
local PetCard = createCard("PetCard", 65, 1)

local PetLabel = Instance.new("TextLabel")
PetLabel.Size = UDim2.new(1, -24, 0, 18)
PetLabel.Position = UDim2.new(0, 12, 0, 8)
PetLabel.BackgroundTransparency = 1
PetLabel.Text = "🐾 Pet Remote ID"
PetLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
PetLabel.TextSize = 12
PetLabel.Font = Enum.Font.GothamMedium
PetLabel.TextXAlignment = Enum.TextXAlignment.Left
PetLabel.Parent = PetCard

local PetKindBox = Instance.new("TextBox")
PetKindBox.Size = UDim2.new(1, -24, 0, 34)
PetKindBox.Position = UDim2.new(0, 12, 0, 26)
PetKindBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
PetKindBox.PlaceholderText = "e.g., moon_2025_snorgle"
PetKindBox.Text = ""
PetKindBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PetKindBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
PetKindBox.TextSize = 14
PetKindBox.Font = Enum.Font.Gotham
PetKindBox.Parent = PetCard

local PetBoxCorner = Instance.new("UICorner")
PetBoxCorner.CornerRadius = UDim.new(0, 8)
PetBoxCorner.Parent = PetKindBox

-- 2. Filters
local FilterCard = createCard("FilterCard", 85, 2)

local FilterLabel = Instance.new("TextLabel")
FilterLabel.Size = UDim2.new(1, -24, 0, 18)
FilterLabel.Position = UDim2.new(0, 12, 0, 8)
FilterLabel.BackgroundTransparency = 1
FilterLabel.Text = "⚙️ Filters"
FilterLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
FilterLabel.TextSize = 13
FilterLabel.Font = Enum.Font.GothamMedium
FilterLabel.TextXAlignment = Enum.TextXAlignment.Left
FilterLabel.Parent = FilterCard

-- Neon Toggle
local NeonContainer = Instance.new("Frame")
NeonContainer.Size = UDim2.new(1, -24, 0, 30)
NeonContainer.Position = UDim2.new(0, 12, 0, 28)
NeonContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
NeonContainer.BorderSizePixel = 0
NeonContainer.Parent = FilterCard

local NeonContainerCorner = Instance.new("UICorner")
NeonContainerCorner.CornerRadius = UDim.new(0, 8)
NeonContainerCorner.Parent = NeonContainer

local NeonLabel = Instance.new("TextLabel")
NeonLabel.Size = UDim2.new(1, -60, 1, 0)
NeonLabel.Position = UDim2.new(0, 12, 0, 0)
NeonLabel.BackgroundTransparency = 1
NeonLabel.Text = "Neon Only"
NeonLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
NeonLabel.TextSize = 13
NeonLabel.Font = Enum.Font.Gotham
NeonLabel.TextXAlignment = Enum.TextXAlignment.Left
NeonLabel.Parent = NeonContainer

local NeonToggle = Instance.new("TextButton")
NeonToggle.Size = UDim2.new(0, 44, 0, 24)
NeonToggle.Position = UDim2.new(1, -52, 0.5, -12)
NeonToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
NeonToggle.Text = ""
NeonToggle.Parent = NeonContainer

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = NeonToggle

local ToggleCircle = Instance.new("Frame")
ToggleCircle.Size = UDim2.new(0, 18, 0, 18)
ToggleCircle.Position = UDim2.new(0, 3, 0.5, -9)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleCircle.BorderSizePixel = 0
ToggleCircle.Parent = NeonToggle

local CircleCorner = Instance.new("UICorner")
CircleCorner.CornerRadius = UDim.new(1, 0)
CircleCorner.Parent = ToggleCircle

-- Rarity Selector
local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, -24, 0, 16)
RarityLabel.Position = UDim2.new(0, 12, 0, 62)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Rarity: All"
RarityLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
RarityLabel.TextSize = 12
RarityLabel.Font = Enum.Font.GothamMedium
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = FilterCard

-- 3. Status
local StatusCard = createCard("StatusCard", 50, 3)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 1, -16)
StatusLabel.Position = UDim2.new(0, 12, 0, 8)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "⏳ Ready to start"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextWrapped = true
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.Parent = StatusCard

-- 4. Queue
local QueueCard = createCard("QueueCard", 80, 4)

local QueueLabel = Instance.new("TextLabel")
QueueLabel.Size = UDim2.new(1, -24, 0, 18)
QueueLabel.Position = UDim2.new(0, 12, 0, 6)
QueueLabel.BackgroundTransparency = 1
QueueLabel.Text = "📋 Queue (0)"
QueueLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
QueueLabel.TextSize = 13
QueueLabel.Font = Enum.Font.GothamMedium
QueueLabel.TextXAlignment = Enum.TextXAlignment.Left
QueueLabel.Parent = QueueCard

local QueueScroll = Instance.new("ScrollingFrame")
QueueScroll.Size = UDim2.new(1, -24, 1, -30)
QueueScroll.Position = UDim2.new(0, 12, 0, 26)
QueueScroll.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
QueueScroll.BorderSizePixel = 0
QueueScroll.ScrollBarThickness = 2
QueueScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80)
QueueScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
QueueScroll.Parent = QueueCard

local QueueScrollCorner = Instance.new("UICorner")
QueueScrollCorner.CornerRadius = UDim.new(0, 6)
QueueScrollCorner.Parent = QueueScroll

local QueueLayout = Instance.new("UIListLayout")
QueueLayout.Padding = UDim.new(0, 2)
QueueLayout.Parent = QueueScroll

-- 5. Stats
local StatsCard = createCard("StatsCard", 42, 5)

local StatsContainer = Instance.new("Frame")
StatsContainer.Size = UDim2.new(1, -24, 1, -12)
StatsContainer.Position = UDim2.new(0, 12, 0, 6)
StatsContainer.BackgroundTransparency = 1
StatsContainer.Parent = StatsCard

local StatsLayout = Instance.new("UIListLayout")
StatsLayout.FillDirection = Enum.FillDirection.Horizontal
StatsLayout.Padding = UDim.new(0, 8)
StatsLayout.Parent = StatsContainer

local function createStatBox(text, color)
    local Box = Instance.new("Frame")
    Box.Size = UDim2.new(0.32, 0, 1, 0)
    Box.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Box.BorderSizePixel = 0
    Box.Parent = StatsContainer
    
    local BoxCorner = Instance.new("UICorner")
    BoxCorner.CornerRadius = UDim.new(0, 6)
    BoxCorner.Parent = Box
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = color
    Label.TextSize = 11
    Label.Font = Enum.Font.GothamMedium
    Label.Parent = Box
    
    return Label
end

local CompletedLabel = createStatBox("✅ 0", Color3.fromRGB(120, 220, 120))
local FailedLabel = createStatBox("❌ 0", Color3.fromRGB(255, 120, 120))
local TotalLabel = createStatBox("📊 0", Color3.fromRGB(140, 200, 255))

-- 6. Start Button
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(1, -32, 0, 42)
StartButton.Position = UDim2.new(0, 16, 1, -52)
StartButton.BackgroundColor3 = Color3.fromRGB(88, 180, 90)
StartButton.Text = "▶️  START"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 15
StartButton.Font = Enum.Font.GothamBold
StartButton.Parent = MainFrame

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 12)
StartCorner.Parent = StartButton

-- ============================================
-- FUNCTIONS
-- ============================================

-- Toggle animations
NeonToggle.MouseButton1Click:Connect(function()
    neonEnabled = not neonEnabled
    
    local targetColor = neonEnabled and Color3.fromRGB(88, 180, 90) or Color3.fromRGB(60, 60, 80)
    local targetPos = neonEnabled and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    
    TweenService:Create(NeonToggle, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor}):Play()
    TweenService:Create(ToggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = targetPos}):Play()
    
    NeonLabel.Text = neonEnabled and "Neon Only ✓" or "Neon Only"
end)

-- Close button
CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Rarity cycle (click rarity label to cycle)
local rarities = {"All", "Common", "Uncommon", "Rare", "Ultra Rare", "Legendary"}
local rarityColors = {
    All = Color3.fromRGB(140, 200, 255),
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(120, 220, 120),
    Rare = Color3.fromRGB(100, 150, 255),
    ["Ultra Rare"] = Color3.fromRGB(200, 100, 255),
    Legendary = Color3.fromRGB(255, 200, 50)
}

local rarityIndex = 1
RarityLabel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        rarityIndex = rarityIndex % #rarities + 1
        selectedRarity = rarities[rarityIndex]
        RarityLabel.Text = "Rarity: " .. selectedRarity
        RarityLabel.TextColor3 = rarityColors[selectedRarity]
    end
end)

-- Update functions
local function updateQueue()
    for _, child in pairs(QueueScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    for i, req in ipairs(currentQueue) do
        local QueueItem = Instance.new("TextLabel")
        QueueItem.Size = UDim2.new(1, 0, 0, 18)
        QueueItem.BackgroundTransparency = 1
        QueueItem.Text = string.format("%d. %s (%d pets)", i, req.username, req.pets_needed)
        QueueItem.TextColor3 = Color3.fromRGB(200, 200, 220)
        QueueItem.TextSize = 11
        QueueItem.Font = Enum.Font.Gotham
        QueueItem.TextXAlignment = Enum.TextXAlignment.Left
        QueueItem.Parent = QueueScroll
    end
    
    QueueScroll.CanvasSize = UDim2.new(0, 0, 0, #currentQueue * 20)
    QueueLabel.Text = string.format("📋 Queue (%d)", #currentQueue)
end

local function updateStats()
    CompletedLabel.Text = "✅ " .. stats.completed
    FailedLabel.Text = "❌ " .. stats.failed
    TotalLabel.Text = "📊 " .. stats.total
end

-- API functions
local function testConnection()
    local success, result = pcall(function()
        return request({
            Url = NGROK_URL .. "/requests",
            Method = "GET"
        })
    end)
    
    if success and result.StatusCode == 200 then
        StatusLabel.Text = "✅ Connected to server!"
        return true
    else
        StatusLabel.Text = "❌ Connection failed!"
        return false
    end
end

local function get_pending_requests()
    local requests = {}
    pcall(function()
        local response = request({
            Url = NGROK_URL .. "/requests",
            Method = "GET"
        })
        
        if response.StatusCode == 200 then
            requests = HttpService:JSONDecode(response.Body)
        end
    end)
    return requests
end

local function get_pets(count)
    local petKind = PetKindBox.Text
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[holderName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            local shouldInclude = true
            
            if pet.kind ~= petKind then
                shouldInclude = false
            end
            
            if shouldInclude then
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega_neon
                local pet_age = pet.properties and pet.properties.age or 0
                
                -- ALWAYS skip age 6
                if pet_age >= 6 then
                    shouldInclude = false
                end
                
                -- Neon filter
                if shouldInclude and neonEnabled then
                    -- When neon toggle is ON: only neons, skip megas
                    if is_mega then
                        shouldInclude = false
                    end
                    if not is_neon then
                        shouldInclude = false
                    end
                elseif shouldInclude and not neonEnabled then
                    -- When neon toggle is OFF: only normal pets, skip neons and megas
                    if is_neon or is_mega then
                        shouldInclude = false
                    end
                end
                
                -- Rarity filter
                if shouldInclude and selectedRarity ~= "All" then
                    local petRarity = pet.rarity or "common"
                    local filterRarity = selectedRarity:lower():gsub(" ", "_")
                    if filterRarity ~= petRarity:lower() then
                        shouldInclude = false
                    end
                end
            end
            
            if shouldInclude then
                table.insert(pets, pet.unique)
                if #pets >= count then
                    break
                end
            end
        end
    end)
    
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
            Url = NGROK_URL .. "/complete",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({username = username})
        })
    end)
end

local function trade_to_receiver(username, total_pets_needed)
    StatusLabel.Text = string.format("🔄 Trading to %s (%d pets)...", username, total_pets_needed)
    
    local BATCH_SIZE = 18
    local pets_traded = 0
    local trade_number = 1
    
    while pets_traded < total_pets_needed do
        local remaining = total_pets_needed - pets_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        local target = Players:FindFirstChild(username)
        if not target then
            StatusLabel.Text = "❌ " .. username .. " left!"
            if pets_traded > 0 then mark_complete(username) end
            return false
        end
        
        local pets = get_pets(this_batch)
        
        if #pets < this_batch then
            if #pets > 0 then
                this_batch = #pets
            else
                StatusLabel.Text = string.format("❌ Out of pets! (%d/%d)", pets_traded, total_pets_needed)
                if pets_traded > 0 then mark_complete(username) end
                return false
            end
        end
        
        StatusLabel.Text = string.format("📤 Trade #%d to %s...", trade_number, username)
        
        if not send_trade(username) then
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
            task.wait(2)
            continue
        end
        
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            StatusLabel.Text = string.format("📦 Adding... (%d/%d)", i, #pets)
            task.wait(0.2)
        end
        
        StatusLabel.Text = "⏳ Waiting for countdown..."
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
            task.wait(2)
            continue
        end
        
        pets_traded = pets_traded + this_batch
        trade_number = trade_number + 1
        
        StatusLabel.Text = string.format("✅ %d/%d pets traded", pets_traded, total_pets_needed)
        
        if pets_traded < total_pets_needed then
            task.wait(2)
        end
    end
    
    mark_complete(username)
    return pets_traded >= total_pets_needed
end

-- Main Loop
local function mainLoop()
    while isRunning do
        StatusLabel.Text = "📡 Checking..."
        
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

-- Start Button
StartButton.MouseButton1Click:Connect(function()
    if PetKindBox.Text == "" then
        StatusLabel.Text = "❌ Enter Pet Remote ID!"
        return
    end
    
    isRunning = not isRunning
    
    if isRunning then
        if not testConnection() then
            isRunning = false
            return
        end
        
        StartButton.Text = "⏸️  STOP"
        StartButton.BackgroundColor3 = Color3.fromRGB(235, 64, 52)
        task.spawn(mainLoop)
    else
        StartButton.Text = "▶️  START"
        StartButton.BackgroundColor3 = Color3.fromRGB(88, 180, 90)
        StatusLabel.Text = "⏸️ Stopped"
    end
end)

-- Make draggable
local dragging, dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

print("✅ Modern Holder GUI Loaded!")
print("🌐 Server: " .. NGROK_URL)
