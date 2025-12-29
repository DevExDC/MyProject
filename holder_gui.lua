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
    
    print("\n=== PET SEARCH DEBUG ===")
    print("Looking for pet kind: " .. petKind)
    print("Rarity filter: " .. selectedRarity)
    print("Neon only: " .. tostring(neonEnabled))
    
    local checked = 0
    local matched = 0
    
    for _, pet in pairs(playerData.inventory.pets) do
        checked = checked + 1
        
        -- Check pet kind
        if pet.kind ~= petKind then
            continue
        end
        
        local is_neon = pet.properties and pet.properties.neon
        local is_mega = pet.properties and pet.properties.mega
        
        -- Neon filter
        if neonEnabled then
            if not (is_neon or is_mega) then
                print("  Skipped: Not neon/mega")
                continue
            end
        end
        
        -- Rarity filter (if not "All")
        if selectedRarity ~= "All" then
            local petRarity = pet.rarity or "common"
            local filterRarity = selectedRarity:lower():gsub(" ", "_")
            
            -- Make both lowercase for comparison
            if filterRarity ~= petRarity:lower() then
                print("  Skipped: Rarity mismatch (pet=" .. petRarity .. ", filter=" .. filterRarity .. ")")
                continue
            end
        end
        
        matched = matched + 1
        table.insert(pets, pet.unique)
        print("  ✅ Matched pet #" .. matched)
        
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
    StatusLabel.Text = string.format("🔄 Trading to %s (needs %d pets total)...", username, total_pets_needed)
    
    local BATCH_SIZE = 18 -- Max pets per trade in Adopt Me
    local pets_traded = 0
    local trade_number = 1
    local had_shortage = false
    
    while pets_traded < total_pets_needed do
        local remaining = total_pets_needed - pets_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        print(string.format("\n=== TRADE #%d ===", trade_number))
        print(string.format("Progress: %d/%d pets traded", pets_traded, total_pets_needed))
        print(string.format("This batch: %d pets", this_batch))
        
        -- Check if player still in server
        local target = Players:FindFirstChild(username)
        
        if not target then
            print("❌ PLAYER LEFT: " .. username)
            StatusLabel.Text = "❌ " .. username .. " left the server!"
            
            if pets_traded > 0 then
                print(string.format("⚠️ PARTIAL TRADE: Sent %d/%d pets before player left", pets_traded, total_pets_needed))
                StatusLabel.Text = string.format("⚠️ Partial: %d/%d pets (player left)", pets_traded, total_pets_needed)
                mark_complete(username) -- Mark as done even if partial
            end
            
            return false
        end
        
        print("✅ Found player: " .. target.Name)
        
        -- Get pets for this batch
        local pets = get_pets(this_batch)
        
        print("Pets found: " .. #pets .. " (need " .. this_batch .. ")")
        
        if #pets < this_batch then
            print("❌ NOT ENOUGH PETS IN INVENTORY")
            
            if #pets > 0 then
                -- Trade what we have
                print(string.format("⚠️ Trading partial batch: %d pets instead of %d", #pets, this_batch))
                this_batch = #pets
                had_shortage = true
            else
                -- No pets left at all
                StatusLabel.Text = string.format("❌ Out of pets! Traded %d/%d total", pets_traded, total_pets_needed)
                
                -- Tell receiver we don't have enough
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
                    print(string.format("📨 Sent status to %s: insufficient_pets (%d sent)", username, pets_traded))
                end)
                
                if pets_traded > 0 then
                    print(string.format("⚠️ PARTIAL COMPLETION: %d/%d pets", pets_traded, total_pets_needed))
                    mark_complete(username) -- Mark as done with partial
                end
                
                return false
            end
        end
        
        print("Sending trade request...")
        StatusLabel.Text = string.format("📤 Trade #%d: Sending to %s...", trade_number, username)
        
        if not send_trade(username) then
            print("❌ SEND TRADE FAILED")
            StatusLabel.Text = "❌ Failed to send trade request"
            task.wait(2)
            continue -- Try again
        end
        
        print("✅ Trade request sent, waiting for window...")
        task.wait(2) -- Reduced from 3 to 2
        
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        
        local timeout = 0
        while not tradeGui.Visible and timeout < 10 do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        if timeout >= 10 then
            print("❌ TRADE WINDOW TIMEOUT")
            StatusLabel.Text = "❌ Trade window timeout - retrying..."
            task.wait(2)
            continue -- Try again
        end
        
        print("✅ Trade window opened")
        
        -- Add pets to trade
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            print("Added pet " .. i .. "/" .. #pets)
            StatusLabel.Text = string.format("📦 Trade #%d: Adding pets... (%d/%d)", trade_number, i, #pets)
            task.wait(0.2) -- Reduced from 0.3 to 0.2
        end
        
        print("Accepting trade...")
        StatusLabel.Text = string.format("✅ Trade #%d: Waiting for countdown...", trade_number)
        task.wait(6) -- 6 second countdown in Adopt Me
        accept_trade()
        StatusLabel.Text = string.format("✅ Trade #%d: Accepted!", trade_number)
        task.wait(0.5) -- Brief wait after accept
        print("Confirming trade...")
        StatusLabel.Text = string.format("✅ Trade #%d: Confirming...", trade_number)
        confirm_trade()
        StatusLabel.Text = string.format("✅ Trade #%d: Confirmed!", trade_number)
        
        -- Wait for trade to complete
        timeout = 0
        repeat
            task.wait(0.5)
            timeout = timeout + 0.5
        until not tradeGui.Visible or timeout > 20
        
        if timeout > 20 then
            print("⚠️ CONFIRM TIMEOUT")
            StatusLabel.Text = "⚠️ Trade confirmation timeout - retrying..."
            task.wait(2)
            continue -- Try again
        end
        
        print(string.format("✅ TRADE #%d COMPLETE", trade_number))
        
        pets_traded = pets_traded + this_batch
        trade_number = trade_number + 1
        
        StatusLabel.Text = string.format("✅ Progress: %d/%d pets traded to %s", pets_traded, total_pets_needed, username)
        
        -- If we had a shortage, stop trying
        if had_shortage then
            print("⚠️ Stopping due to inventory shortage")
            break
        end
        
        -- Wait before next trade
        if pets_traded < total_pets_needed then
            print("Waiting 2 seconds before next trade...")
            task.wait(2) -- Reduced from 3 to 2
        end
    end
    
    if pets_traded >= total_pets_needed then
        print(string.format("\n🎉 ALL TRADES COMPLETE FOR %s", username))
        print(string.format("Total: %d pets in %d trades", pets_traded, trade_number - 1))
        StatusLabel.Text = string.format("🎉 Completed! Traded %d pets to %s", pets_traded, username)
    else
        print(string.format("\n⚠️ PARTIAL TRADE FOR %s", username))
        print(string.format("Total: %d/%d pets in %d trades", pets_traded, total_pets_needed, trade_number - 1))
        StatusLabel.Text = string.format("⚠️ Partial: %d/%d pets to %s", pets_traded, total_pets_needed, username)
    end
    
    -- Mark as complete on server (even if partial)
    mark_complete(username)
    
    return pets_traded >= total_pets_needed
end

-- Main Loop
local function mainLoop()
    while isRunning do
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
            task.wait(10) -- Only wait when no requests
        else
            -- Process ONLY the first request, then recheck
            local request = currentQueue[1]
            stats.total = stats.total + 1
            
            local success = trade_to_receiver(request.username, request.pets_needed)
            
            if success then
                stats.completed = stats.completed + 1
                processedRequests[request.username] = true
            else
                stats.failed = stats.failed + 1
                processedRequests[request.username] = true -- Mark as processed even if failed
            end
            
            updateStats()
            task.wait(2) -- Brief wait before checking for next request
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
