--[[
    SUCCESS Auto-Trade Script - SIMPLIFIED
    Trades ALL pets (normal, neon, mega) of specified kinds to holder
    v3.0.0
]]

repeat wait() until game:IsLoaded()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Configuration
getgenv().Config = getgenv().Config or {
    usernames = {},
    pets_to_trade = {},
    Webhook = "",
    FARMSYNC_API_KEY = ""
}

local config = getgenv().Config

local pets_unique_ids = {}
local trade_status = false
local completedTrades = {}

print("===========================================")
print("  SUCCESS Auto-Trade System v3.0.0")
print("  Trades ALL pets of specified kinds")
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

local function add_items_in_trade(unique)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
end

-- Get ALL pets of specified kinds (normal, neon, mega - everything!)
local function get_all_pets()
    local foundPets = {}
    local playerData = Data.get_data()[playerName]
    
    if not playerData or not playerData.inventory or not playerData.inventory.pets then
        warn("No pet data found")
        return foundPets
    end
    
    print("\n🔍 Searching for pets...")
    print("Target pet kinds: " .. table.concat(config.pets_to_trade, ", "))
    print("---")
    
    local normalCount = 0
    local neonCount = 0
    local megaCount = 0
    
    for _, pet in pairs(playerData.inventory.pets) do
        -- Check if this pet matches any of the specified kinds
        for _, petKind in pairs(config.pets_to_trade) do
            if pet.kind == petKind then
                -- Get pet properties
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega
                
                -- Add to trade list (ALL types!)
                table.insert(foundPets, pet.unique)
                
                -- Count by type for logging
                if is_mega then
                    megaCount = megaCount + 1
                    print(string.format("✅ Found MEGA %s", pet.kind))
                elseif is_neon then
                    neonCount = neonCount + 1
                    print(string.format("✅ Found NEON %s", pet.kind))
                else
                    normalCount = normalCount + 1
                    print(string.format("✅ Found NORMAL %s", pet.kind))
                end
                
                break -- Don't check other pet kinds once matched
            end
        end
    end
    
    print("---")
    print(string.format("📊 Total found: %d pets", #foundPets))
    print(string.format("   Normal: %d | Neon: %d | Mega: %d", normalCount, neonCount, megaCount))
    
    return foundPets
end

-- Main auto trade function
local function autotrade(username)
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    
    -- Phase 1: Send trade request
    if #pets_unique_ids > 0 and not tradeGui.Visible then
        trade_status = false
        local success = send_trade(username)
        if not success then
            return false
        end
        print(string.format("📤 Trade request sent to %s", username))
        task.wait(2)
    
    -- Phase 2: Add items to trade
    elseif not trade_status and tradeGui.Visible then
        local counter = 0
        local maxSlots = math.min(#pets_unique_ids, 18) -- Max 18 pets per trade
        
        print(string.format("Adding %d pets to trade...", maxSlots))
        
        while #pets_unique_ids > 0 and counter < maxSlots do
            local petUnique = table.remove(pets_unique_ids, 1)
            add_items_in_trade(petUnique)
            counter = counter + 1
            task.wait(0.5)
        end
        
        print(string.format("✅ Added %d pets | Remaining: %d", counter, #pets_unique_ids))
        trade_status = true
        task.wait(1)
    
    -- Phase 3: Accept and confirm trade
    elseif trade_status and tradeGui.Visible then
        task.wait(1)
        first_trade_accept()
        print("✅ Trade accepted")
        task.wait(1.5)
        confirm_trade()
        print("✅ Trade confirmed")
        
        -- Wait for trade to close
        local timeout = 0
        repeat
            task.wait(0.5)
            timeout = timeout + 0.5
        until not tradeGui.Visible or timeout > 10
        
        if timeout > 10 then
            warn("Trade timeout")
            return false
        end
        
        task.wait(2)
        trade_status = false
    end
    
    return true
end

-- Main execution
print(string.format("\n📋 Configuration:"))
print(string.format("   • Holder: %s", table.concat(config.usernames, ", ")))
print(string.format("   • Pet Kinds: %s", table.concat(config.pets_to_trade, ", ")))
print(string.format("   • Webhook: %s\n", config.Webhook ~= "" and "Enabled" or "Disabled"))

local totalPetsTraded = 0

for index, username in ipairs(config.usernames) do
    print(string.format("\n┌────────────────────────────────────┐"))
    print(string.format("│ 📊 Holder [%d/%d]: %s", index, #config.usernames, username))
    print(string.format("└────────────────────────────────────┘\n"))
    
    -- Check if holder is in server
    if not Players:FindFirstChild(username) then
        warn(string.format("❌ %s is not in the server!", username))
        sendWebhook(string.format("❌ %s - Failed - Not In Server", username))
        continue
    end
    
    -- Get ALL pets of specified kinds
    pets_unique_ids = get_all_pets()
    
    if #pets_unique_ids == 0 then
        warn(string.format("❌ No pets found for %s!", username))
        sendWebhook(string.format("❌ %s - No Pets Found", username))
        continue
    end
    
    print(string.format("\n✅ Found %d total pets to trade", #pets_unique_ids))
    
    -- Execute trades
    local totalTraded = #pets_unique_ids
    local tradesNeeded = math.ceil(#pets_unique_ids / 18)
    
    print(string.format("🔄 Executing %d trade(s)...\n", tradesNeeded))
    
    for tradeNum = 1, tradesNeeded do
        print(string.format("Trade %d/%d:", tradeNum, tradesNeeded))
        
        local attempts = 0
        local maxAttempts = 50
        
        repeat
            local success = autotrade(username)
            if not success and attempts > 10 then
                warn("Trade failed after multiple attempts")
                break
            end
            task.wait(1)
            attempts = attempts + 1
        until #pets_unique_ids == 0 or not Players:FindFirstChild(username) or attempts >= maxAttempts
        
        -- Check if holder left
        if not Players:FindFirstChild(username) then
            warn(string.format("⚠️ %s left the game!", username))
            sendWebhook(string.format("⚠️ %s - Incomplete - Player Left (Traded: %d)", username, totalTraded - #pets_unique_ids))
            break
        end
        
        if attempts >= maxAttempts then
            warn("Max attempts reached")
            sendWebhook(string.format("❌ %s - Failed - Max Attempts (Traded: %d)", username, totalTraded - #pets_unique_ids))
            break
        end
        
        task.wait(3) -- Cooldown between trades
    end
    
    -- Log completion
    if #pets_unique_ids == 0 then
        print(string.format("\n✅ Successfully traded %d pets with %s", totalTraded, username))
        sendWebhook(string.format("✅ %s - COMPLETE - Traded: %d pets", username, totalTraded))
        table.insert(completedTrades, username)
        totalPetsTraded = totalPetsTraded + totalTraded
    end
    
    task.wait(5) -- Cooldown before next holder
end

print("\n┌────────────────────────────────────┐")
print("│ 🎉 All Trades Completed!           │")
print(string.format("│ ✅ Success: %d/%d holders", #completedTrades, #config.usernames))
print(string.format("│ ✅ Total Pets Traded: %d", totalPetsTraded))
print("└────────────────────────────────────┘\n")

-- Final webhook
sendWebhook(string.format("✅ %s - ALL COMPLETE - Total Traded: %d pets", playerName, totalPetsTraded))

-- Auto-disable account
print("🔴 Disabling account...")
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
