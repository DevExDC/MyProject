--[[
    SUCCESS RECEIVER - Accepts All Trades
    Run this on 1 account to receive all pets after aging
    v2.0 - Fixed API loading with dehash
]]

repeat wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("🔄 Anti-AFK triggered")
end)
print("✅ Anti-AFK enabled")

-- Configuration
getgenv().Config = getgenv().Config or {
    FARMSYNC_API_KEY = "",
    Webhook = "",
    CheckInterval = 1,  -- Check for trades every 1 second (faster!)
    AcceptDelay = 0.5,   -- Quick accept
    AutoDehash = true    -- Auto-dehash on start
}

local config = getgenv().Config

-- ============== DEHASH ==============
local function dehash()
    if not config.AutoDehash then return end
    
    local function rename(remotename, hashedremote)
        hashedremote.Name = remotename
    end
    
    pcall(function()
        table.foreach(
            getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7),
            rename
        )
    end)
    print("✅ Dehashed remotes")
end

-- Dehash BEFORE loading API
dehash()

-- Small wait to ensure dehashing completed
task.wait(1)

-- ============== UTILITIES ==============

local function sendWebhook(content)
    if not config.Webhook or config.Webhook == "" then
        return
    end
    
    pcall(function()
        request({
            Url = config.Webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                content = content,
                username = "Success Receiver"
            })
        })
    end)
end

local function disableAccount()
    if not config.FARMSYNC_API_KEY or config.FARMSYNC_API_KEY == "" then
        print("⚠️ No API key, skipping auto-disable")
        return
    end
    
    pcall(function()
        request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. config.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
        
        print("🔴 Account disabled!")
        sendWebhook(string.format("🔴 %s - Account Disabled", playerName))
    end)
end

-- ============== LOAD API ==============

print("📡 Loading Adopt Me API...")

local success, API = pcall(function()
    return ReplicatedStorage:WaitForChild("API", 10)
end)

if not success or not API then
    warn("❌ Failed to load API! Script cannot continue.")
    warn("Make sure you're in Adopt Me and the game is fully loaded!")
    sendWebhook(string.format("❌ %s - Failed to load API", playerName))
    return
end

print("✅ API loaded successfully!")

-- ============== TRADE SYSTEM ==============

-- Track stats
local tradesAccepted = 0
local petsReceived = 0
local lastTradePartner = nil
local lastTradeTime = 0

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🎯 SUCCESS RECEIVER STARTED")
print(string.format("👤 Account: %s", playerName))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

sendWebhook(string.format("🎯 %s - Success Receiver Online", playerName))

-- Auto-accept incoming trade dialog
task.spawn(function()
    local dialogApp = LocalPlayer.PlayerGui:WaitForChild("DialogApp")
    
    while task.wait(0.3) do
        pcall(function()
            if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Name ~= playerName then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(player, true)
                        print(string.format("✅ Auto-accepted trade request from %s", player.Name))
                    end
                end
            end
        end)
    end
end)

-- Auto-accept negotiations
task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
            if tradeGui and tradeGui.Frame.Visible then
                -- Accept negotiation
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
            end
        end)
    end
end)

-- Auto-confirm trades
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
            if tradeGui and tradeGui.Frame.Visible then
                -- Confirm trade
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
            end
        end)
    end
end)

-- Count pets in inventory
local function countMyPets()
    local count = 0
    pcall(function()
        local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                count = count + 1
            end
        end
    end)
    return count
end

-- Main monitoring loop
print("\n🔍 Monitoring for incoming trades...\n")

local checkCount = 0

while true do
    task.wait(config.CheckInterval)
    
    checkCount = checkCount + 1
    
    -- Log status every 30 checks (30 seconds at 1s interval)
    if checkCount % 30 == 0 then
        local petCount = countMyPets()
        print(string.format("📊 Status: %d trades | %d pets | Inventory: %d", tradesAccepted, petsReceived, petCount))
    end
    
    -- No additional logic needed - the auto-accept loops handle everything!
end
