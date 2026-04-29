-- ============================================
-- AUTO BUCKS TRANSFER - SENDER ONLY
-- With custom UI like image
-- ============================================

if not getgenv().BucksConfig then
    error("❌ ERROR: No configuration found!\n\nExample:\n\ngetgenv().BucksConfig = {\n    RECEIVER_USERNAME = \"ReceiverName\",\n    WEBHOOK_URL = \"https://discord.com/api/webhooks/...\",\n}")
end

local CONFIG = getgenv().BucksConfig

if not CONFIG.RECEIVER_USERNAME or CONFIG.RECEIVER_USERNAME == "" then
    error("❌ RECEIVER_USERNAME is required!")
end

-- ============================================
-- SETUP
-- ============================================

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name
local HttpService = game:GetService("HttpService")
local request = (syn and syn.request) or (http and http.request) or http_request

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- Dehash
print("🔧 Dehashing remotes...")

local function dehash()
    local router = require(game:GetService("ReplicatedStorage").ClientModules.Core.RouterClient.RouterClient)
    if type(router.init) ~= "function" then
        print("Router.init is not a function")
        return
    end
    local targetTable = nil
    for i = 1, 20 do
        local upv = debug.getupvalue(router.init, i)
        if type(upv) == "table" then
            local valid = true
            local count = 0
            for k, v in pairs(upv) do
                count = count + 1
                if typeof(v) ~= "Instance" then
                    valid = false
                    break
                end
            end
            if valid and count > 0 then
                targetTable = upv
                print("Found remotes table at index:", i)
                break
            end
        end
    end
    if not targetTable then
        print("🔴 Remotes table not found")
        return
    end
    for name, remote in pairs(targetTable) do
        pcall(function()
            remote.Name = name
        end)
    end
    print("✅ Dehash done")
end

dehash()

-- ============================================
-- WEBHOOK
-- ============================================

local function sendWebhook(message)
    if not CONFIG.WEBHOOK_URL or CONFIG.WEBHOOK_URL == "" then return end
    if not request then return end
    
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

-- ============================================
-- GET BUCKS AMOUNT
-- ============================================

local function getBucks()
    local bucks = 0
    pcall(function()
        local bucksText = LocalPlayer.PlayerGui.BucksIndicatorApp.CurrencyIndicator.Container.Amount.Text
        bucksText = bucksText:gsub(",", "")
        bucks = tonumber(bucksText) or 0
    end)
    return bucks
end

-- ============================================
-- HIDE DIALOG UI
-- ============================================

local function hideDialogUI()
    pcall(function()
        LocalPlayer.PlayerGui.DialogApp.Enabled = false
    end)
end

-- ============================================
-- CREATE UI
-- ============================================

local function createUI()
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NOTTOOL"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 200)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Make it draggable
    local dragging = false
    local dragInput, mousePos, framePos
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    mainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            mainFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Header
    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(50, 205, 50)
    header.BorderSizePixel = 0
    header.Text = "● " .. playerName .. " | VoHub"
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 18
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = mainFrame
    
    local headerPadding = Instance.new("UIPadding")
    headerPadding.PaddingLeft = UDim.new(0, 15)
    headerPadding.Parent = header
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -30, 0, 30)
    statusLabel.Position = UDim2.new(0, 15, 0, 50)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "📊 No pet/egg equipped, retrying.."
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 14
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- Stats Container
    local statsContainer = Instance.new("Frame")
    statsContainer.Name = "StatsContainer"
    statsContainer.Size = UDim2.new(1, -30, 0, 80)
    statsContainer.Position = UDim2.new(0, 15, 0, 90)
    statsContainer.BackgroundTransparency = 1
    statsContainer.Parent = mainFrame
    
    -- Bucks Remaining Icon
    local bucksIcon = Instance.new("TextLabel")
    bucksIcon.Size = UDim2.new(0, 30, 0, 30)
    bucksIcon.Position = UDim2.new(0, 0, 0, 0)
    bucksIcon.BackgroundTransparency = 1
    bucksIcon.Text = "💵"
    bucksIcon.TextSize = 20
    bucksIcon.Parent = statsContainer
    
    -- Bucks Remaining Label
    local bucksLabel = Instance.new("TextLabel")
    bucksLabel.Size = UDim2.new(0, 150, 0, 30)
    bucksLabel.Position = UDim2.new(0, 35, 0, 0)
    bucksLabel.BackgroundTransparency = 1
    bucksLabel.Text = "0"
    bucksLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    bucksLabel.Font = Enum.Font.GothamBold
    bucksLabel.TextSize = 24
    bucksLabel.TextXAlignment = Enum.TextXAlignment.Left
    bucksLabel.Parent = statsContainer
    
    -- Bucks Transferred Icon
    local transferIcon = Instance.new("TextLabel")
    transferIcon.Size = UDim2.new(0, 30, 0, 30)
    transferIcon.Position = UDim2.new(0, 0, 0, 40)
    transferIcon.BackgroundTransparency = 1
    transferIcon.Text = "💎"
    transferIcon.TextSize = 20
    transferIcon.Parent = statsContainer
    
    -- Bucks Transferred Label
    local transferLabel = Instance.new("TextLabel")
    transferLabel.Size = UDim2.new(0, 150, 0, 30)
    transferLabel.Position = UDim2.new(0, 35, 0, 40)
    transferLabel.BackgroundTransparency = 1
    transferLabel.Text = "0"
    transferLabel.TextColor3 = Color3.fromRGB(255, 100, 150)
    transferLabel.Font = Enum.Font.GothamBold
    transferLabel.TextSize = 24
    transferLabel.TextXAlignment = Enum.TextXAlignment.Left
    transferLabel.Parent = statsContainer
    
    -- Timer Label
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Size = UDim2.new(0, 200, 0, 40)
    timerLabel.Position = UDim2.new(1, -220, 0, 90)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text = "⏱️ 0:00:00:00"
    timerLabel.TextColor3 = Color3.new(1, 1, 1)
    timerLabel.Font = Enum.Font.GothamBold
    timerLabel.TextSize = 20
    timerLabel.TextXAlignment = Enum.TextXAlignment.Right
    timerLabel.Parent = mainFrame
    
    return {
        gui = screenGui,
        status = statusLabel,
        bucks = bucksLabel,
        transferred = transferLabel,
        timer = timerLabel
    }
end

-- ============================================
-- SPAWN INTO GAME
-- ============================================

local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    print("📍 Choosing team...")
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {
        source_for_logging = "intro_sequence"
    })
    task.wait(1)

    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)

    task.wait(3)

    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("DailyLoginAPI/ClaimDailyReward"):InvokeServer()
        UIManager.set_app_visibility("DailyLoginApp", false)
    end)

    print("✅ Entered the game!")
end

print("⏳ Entering game...")
enter_the_game()

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
print("✅ Character loaded!")

-- Unsubscribe from house
print("⏳ Waiting 15s before unsubscribing from house...")
task.wait(15)
pcall(function()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(LocalPlayer, true)
end)
task.wait(5)

-- Hide Dialog UI
hideDialogUI()

-- Create UI
local ui = createUI()

-- ============================================
-- FIND PLAYER
-- ============================================

local function findPlayer(username)
    local search = username:lower()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == search then
            return player
        end
    end
    return nil
end

-- ============================================
-- TIMER
-- ============================================

local startTime = os.time()

spawn(function()
    while true do
        local elapsed = os.time() - startTime
        local days = math.floor(elapsed / 86400)
        local hours = math.floor((elapsed % 86400) / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60
        
        ui.timer.Text = string.format("⏱️ %d:%02d:%02d:%02d", days, hours, minutes, seconds)
        task.wait(1)
    end
end)

-- ============================================
-- MAIN SENDER LOGIC
-- ============================================

print("\n💰 STARTING BUCKS TRANSFER")

local initialBucks = getBucks()
print(string.format("💰 Starting bucks: %d", initialBucks))
sendWebhook(string.format("🚀 %s - SENDER started with %d bucks\nReceiver: %s", 
    playerName, initialBucks, CONFIG.RECEIVER_USERNAME))

ui.status.Text = "🔍 Looking for receiver..."
ui.status.TextColor3 = Color3.fromRGB(255, 220, 100)

-- Find receiver
print(string.format("\n🔍 Looking for receiver: %s", CONFIG.RECEIVER_USERNAME))
local receiver = findPlayer(CONFIG.RECEIVER_USERNAME)

while not receiver do
    print("⏳ Receiver not found, waiting...")
    task.wait(5)
    receiver = findPlayer(CONFIG.RECEIVER_USERNAME)
end

print(string.format("✅ Found receiver: %s", receiver.Name))
ui.status.Text = "✅ Receiver found - Starting transfers..."
ui.status.TextColor3 = Color3.fromRGB(100, 255, 100)

task.wait(2)

-- Start buying hotdogs
print("\n🌭 Starting hotdog purchase loop...")
sendWebhook(string.format("🌭 %s - Starting hotdog purchases to %s", playerName, receiver.Name))

ui.status.Text = "💸 Transferring bucks..."
ui.status.TextColor3 = Color3.fromRGB(100, 255, 100)

local totalSpent = 0
local purchaseCount = 0
local lastWebhookTime = os.time()
local webhookInterval = 3600 -- 1 hour

while true do
    local currentBucks = getBucks()
    
    -- Update UI
    ui.bucks.Text = tostring(currentBucks)
    ui.transferred.Text = tostring(totalSpent)
    
    -- Buy hotdog
    print(string.format("\n💸 Buying hotdog... (Bucks: %d)", currentBucks))
    
    local buySuccess = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PlaceableToolAPI/BuyRefreshment"):InvokeServer(
            "hotdog_stand",
            receiver,
            50  -- Price
        )
    end)
    
    if buySuccess then
        print("✅ Purchase sent!")
    else
        print("❌ Purchase failed!")
    end
    
    -- Wait and check if bucks decreased
    task.wait(2)
    hideDialogUI()
    
    local newBucks = getBucks()
    
    if newBucks < currentBucks then
        local spent = currentBucks - newBucks
        totalSpent = totalSpent + spent
        purchaseCount = purchaseCount + 1
        
        print(string.format("✅ Hotdog bought! Spent: %d | Total spent: %d | Remaining: %d", 
            spent, totalSpent, newBucks))
        
        -- Update UI
        ui.bucks.Text = tostring(newBucks)
        ui.transferred.Text = tostring(totalSpent)
    else
        print("⚠️ Bucks didn't decrease, purchase may have failed")
    end
    
    -- Webhook every hour
    if os.time() - lastWebhookTime >= webhookInterval then
        local remaining = getBucks()
        sendWebhook(string.format("📊 %s - HOURLY UPDATE\nBucks remaining: %d\nTotal transferred: %d\nPurchases: %d", 
            playerName, remaining, totalSpent, purchaseCount))
        lastWebhookTime = os.time()
    end
    
    -- Check if out of bucks
    if newBucks < 50 then
        print("\n⚠️ Not enough bucks for another purchase!")
        ui.status.Text = "⚠️ Out of bucks!"
        ui.status.TextColor3 = Color3.fromRGB(255, 100, 100)
        
        sendWebhook(string.format("⚠️ %s - OUT OF BUCKS!\nRemaining: %d\nTotal transferred: %d\nPurchases: %d", 
            playerName, newBucks, totalSpent, purchaseCount))
        break
    end
    
    task.wait(2)  -- Wait 2 seconds before next purchase
end

print("\n✅ TRANSFER COMPLETE!")
print(string.format("Total transferred: %d bucks", totalSpent))
print(string.format("Total purchases: %d", purchaseCount))

ui.status.Text = "✅ Transfer complete!"
ui.status.TextColor3 = Color3.fromRGB(100, 255, 100)
