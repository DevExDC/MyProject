--[[
    SUCCESS Auto-Trade Script - ALL PET TYPES AT ONCE
    Trades ALL specified pet types together (not sequential)
    v4.0.0 - Optimized for speed
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

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Configuration
getgenv().Config = getgenv().Config or {
    usernames = {},
    pets_to_trade = {},  -- ALL types will be traded together!
    Webhook = "",
    FARMSYNC_API_KEY = ""
}

local config = getgenv().Config

local pets_unique_ids = {}
local trade_status = false
local completedTrades = {}

print("===========================================")
print("  SUCCESS Auto-Trade System v4.0.0")
print("  ALL PET TYPES TRADED TOGETHER!")
print("===========================================")
print("Pet Types to Trade:")
for i, pet_kind in ipairs(config.pets_to_trade) do
    print(string.format("  [%d] %s", i, pet_kind))
end
print("===========================================")

-- Dehash
local function dehash()
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
dehash()

-- Disable account
local function disableAccount()
    if config.FARMSYNC_API_KEY == "" then 
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
    end)
end

-- Webhook
local function sendWebhook(message)
    if config.Webhook == "" then return end
    
    pcall(function()
        request({
            Url = config.Webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

-- Auto-accept incoming trade requests
local function setup_auto_accept()
    task.spawn(function()
        local dialogApp = LocalPlayer.PlayerGui:FindFirstChild("DialogApp")
        
        while task.wait(0.3) do
            pcall(function()
                if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Name ~= playerName then
                            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(player, true)
                            print("✅ Auto-accepted trade from " .. player.Name)
                        end
                    end
                end
            end)
        end
    end)
end

-- Auto-accept negotiations
local function setup_auto_negotiate()
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    first_trade_accept()
                end
            end)
        end
    end)
end

-- Auto-confirm trades
local function setup_auto_confirm()
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    confirm_trade()
                end
            end)
        end
    end)
end

-- Trade functions
local function first_trade_accept()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

local function send_trade(username)
    local target = Players:FindFirstChild(username)
    if not target then
        warn(string.format("Player %s not found!", username))
        return false
    end
    
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function add_pet_to_trade(unique_id)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique_id)
end

-- Get ALL pets of ALL specified types (TOGETHER!)
local function get_all_pets()
    local all_pets = {}
    local pet_counts = {}  -- Track counts per type
    
    -- Initialize counters
    for _, kind in ipairs(config.pets_to_trade) do
        pet_counts[kind] = 0
    end
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        -- Collect ALL pets of ALL specified types
        for _, pet in pairs(playerData.inventory.pets) do
            for _, targetKind in ipairs(config.pets_to_trade) do
                if pet.kind == targetKind then
                    table.insert(all_pets, pet.unique)
                    pet_counts[targetKind] = pet_counts[targetKind] + 1
                    break
                end
            end
        end
    end)
    
    -- Print breakdown
    if #all_pets > 0 then
        print(string.format("\n📦 Found %d total pets:", #all_pets))
        for kind, count in pairs(pet_counts) do
            if count > 0 then
                print(string.format("   • %s: %d", kind, count))
            end
        end
    end
    
    return all_pets
end

-- Count ALL pets of ALL specified types
local function count_pets_in_inventory()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                for _, targetKind in ipairs(config.pets_to_trade) do
                    if pet.kind == targetKind then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end)
    return count
end

-- Auto-trade with better completion detection
local function autotrade(username)
    if trade_status then
        return false
    end
    
    if #pets_unique_ids == 0 then
        print("No pets left to trade")
        return true
    end
    
    local success_flag = false
    
    pcall(function()
        trade_status = true
        
        -- Count pets BEFORE trade
        local pets_before = count_pets_in_inventory()
        print(string.format("📦 Pets in inventory before trade: %d", pets_before))
        
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        
        -- Send trade request
        if not send_trade(username) then
            print("❌ Failed to send trade request")
            trade_status = false
            return false
        end
        
        print("📤 Trade request sent to " .. username)
        task.wait(3)
        
        -- Wait for trade window to open
        local timeout = 0
        while not tradeGui.Visible and timeout < 15 do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        if timeout >= 15 then
            warn("❌ Trade window didn't open")
            trade_status = false
            return false
        end
        
        print("✅ Trade window opened")
        task.wait(1)
        
        -- Add pets (max 18 per trade) - MIXED TYPES!
        local pets_to_add = math.min(#pets_unique_ids, 18)
        print(string.format("📦 Adding %d pets to trade (mixed types)...", pets_to_add))
        
        for i = 1, pets_to_add do
            if pets_unique_ids[i] then
                add_pet_to_trade(pets_unique_ids[i])
                task.wait(0.3)
            end
        end
        
        print("✅ All pets added to trade")
        task.wait(2)
        
        -- Wait for countdown
        print("⏱️ Waiting for 6-second countdown...")
        task.wait(6)
        
        -- Accept
        print("✅ Clicking accept...")
        first_trade_accept()
        task.wait(1)
        
        -- Confirm
        print("✅ Confirming trade...")
        confirm_trade()
        
        -- Wait for trade to close
        print("⏳ Waiting for trade to complete...")
        timeout = 0
        local max_wait = 30
        
        while tradeGui.Visible and timeout < max_wait do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        -- Wait for inventory update
        task.wait(2)
        
        -- Count pets AFTER trade
        local pets_after = count_pets_in_inventory()
        local pets_actually_traded = pets_before - pets_after
        
        print(string.format("📦 Pets after trade: %d", pets_after))
        print(string.format("✅ Actually traded: %d pets", pets_actually_traded))
        
        if pets_actually_traded > 0 then
            -- Remove traded pets from list
            for i = 1, pets_actually_traded do
                table.remove(pets_unique_ids, 1)
            end
            print(string.format("📋 Remaining pets: %d", #pets_unique_ids))
            success_flag = true
        else
            warn("⚠️ No pets traded! Refreshing list...")
            pets_unique_ids = get_all_pets()
            success_flag = false
        end
        
        trade_status = false
    end)
    
    return success_flag
end

-- Main execution
print(string.format("\n📋 Configuration:"))
print(string.format("   • Holder: %s", table.concat(config.usernames, ", ")))
print(string.format("   • Pet Types: %d (ALL traded together!)", #config.pets_to_trade))
print(string.format("   • Webhook: %s\n", config.Webhook ~= "" and "Enabled" or "Disabled"))

-- Start auto-systems
print("🤖 Starting auto-accept systems...")
setup_auto_accept()
setup_auto_negotiate()
setup_auto_confirm()
print("✅ Auto-accept enabled\n")

local totalPetsTraded = 0

for index, username in ipairs(config.usernames) do
    print(string.format("\n┌────────────────────────────────────┐"))
    print(string.format("│ 📊 Holder [%d/%d]: %s", index, #config.usernames, username))
    print(string.format("└────────────────────────────────────┘"))
    
    -- Check if holder is in server
    if not Players:FindFirstChild(username) then
        warn(string.format("❌ %s is not in the server!", username))
        sendWebhook(string.format("❌ %s - Failed - Not In Server", playerName))
        continue
    end
    
    -- Get ALL pets of ALL types
    pets_unique_ids = get_all_pets()
    
    if #pets_unique_ids == 0 then
        warn(string.format("❌ No pets found!"))
        sendWebhook(string.format("❌ %s - No Pets Found", playerName))
        continue
    end
    
    local initial_pet_count = #pets_unique_ids
    
    -- Execute trades
    local tradesNeeded = math.ceil(#pets_unique_ids / 18)
    print(string.format("\n🔄 Will need approximately %d trade(s)...\n", tradesNeeded))
    
    local tradeAttempts = 0
    local maxTrades = tradesNeeded + 5
    
    while #pets_unique_ids > 0 and tradeAttempts < maxTrades do
        tradeAttempts = tradeAttempts + 1
        
        print(string.format("\n=== Trade Attempt %d ===", tradeAttempts))
        
        -- Check if holder still in server
        if not Players:FindFirstChild(username) then
            warn(string.format("⚠️ %s left the game!", username))
            local traded_so_far = initial_pet_count - #pets_unique_ids
            sendWebhook(string.format("⚠️ %s - Incomplete - Player Left (Traded: %d/%d)", playerName, traded_so_far, initial_pet_count))
            break
        end
        
        local success = autotrade(username)
        
        if not success then
            warn("Trade attempt failed, retrying...")
            task.wait(3)
        else
            task.wait(3)
        end
    end
    
    -- Log completion
    local traded_count = initial_pet_count - #pets_unique_ids
    
    if #pets_unique_ids == 0 then
        print(string.format("\n✅ Successfully traded ALL %d pets with %s", traded_count, username))
        sendWebhook(string.format("✅ %s - COMPLETE - Traded: %d pets (all types)", playerName, traded_count))
        table.insert(completedTrades, username)
        totalPetsTraded = totalPetsTraded + traded_count
    else
        warn(string.format("\n⚠️ Partial trade: %d/%d pets traded to %s", traded_count, initial_pet_count, username))
        sendWebhook(string.format("⚠️ %s - PARTIAL - Traded: %d/%d pets", playerName, traded_count, initial_pet_count))
        totalPetsTraded = totalPetsTraded + traded_count
    end
    
    task.wait(5)
end

print("\n┌────────────────────────────────────┐")
print("│ 🎉 Trading Session Complete!       │")
print(string.format("│ ✅ Success: %d/%d holders", #completedTrades, #config.usernames))
print(string.format("│ ✅ Total Pets Traded: %d", totalPetsTraded))
print("└────────────────────────────────────┘\n")

-- Final webhook
sendWebhook(string.format("✅ %s - SESSION COMPLETE - Total: %d pets (all types)", playerName, totalPetsTraded))

-- Only disable if ALL pets are traded
local remaining_pets = count_pets_in_inventory()

if remaining_pets == 0 then
    print("🔴 All pets traded - Disabling account...")
    disableAccount()
else
    print(string.format("⚠️ Still have %d pets - NOT disabling account", remaining_pets))
    sendWebhook(string.format("⚠️ %s - Has %d pets remaining - NOT DISABLED", playerName, remaining_pets))
end

print("\n========================================")
print("✅ SCRIPT COMPLETE")
print("========================================")
