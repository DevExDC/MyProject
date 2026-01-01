--[[
    SMART AUTO-BUY - NO SPAWN VERSION
    Buys items without spawning character
    Works like the receiver script!
    v3.0.0
]]

repeat wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- ============== CONFIG ==============
getgenv().Config = getgenv().Config or {
    shop_category = "pets",
    item_to_buy = "winter_2025_turtle_doves",
    item_price = 150000,
    currency_type = "gingerbread_2025",
    reserve_currency = 0,
    FARMSYNC_API_KEY = "",
    Webhook = ""
}

local config = getgenv().Config

print("===========================================")
print("  SMART AUTO-BUY v3.0.0 (NO SPAWN)")
print("  Ultra Fast - No Character Loading!")
print("===========================================")
print(string.format("Item: %s", config.item_to_buy))
print(string.format("Category: %s", config.shop_category))
print(string.format("Price: %s %s", string.format("%d", config.item_price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""), config.currency_type))
print("===========================================")

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- ============== DEHASH ==============
print("🔧 Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("✅ Remotes dehashed!")

-- ============== CLIENT DATA ==============
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- ============== CURRENCY DETECTION ==============

local function get_currency_amount()
    local amount = 0
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        
        if not playerData then
            return
        end
        
        -- Try multiple paths
        if playerData[config.currency_type] and type(playerData[config.currency_type]) == "number" then
            amount = playerData[config.currency_type]
        elseif playerData.event and playerData.event[config.currency_type] then
            amount = playerData.event[config.currency_type]
        elseif playerData.currencies and playerData.currencies[config.currency_type] then
            amount = playerData.currencies[config.currency_type]
        elseif config.currency_type == "money" and type(playerData.money) == "number" then
            amount = playerData.money
        end
    end)
    
    return amount
end

-- ============== WEBHOOK ==============

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

-- ============== AUTO-DISABLE ==============

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

-- ============== FORMAT NUMBER ==============

local function formatNumber(num)
    return tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- ============== SMART BUY FUNCTION ==============

local function buy_items(quantity)
    local success = false
    
    pcall(function()
        local args = {
            config.shop_category,
            config.item_to_buy,
            {
                buy_count = quantity
            }
        }
        
        print(string.format("\n📦 Buying %d items...", quantity))
        print(string.format("   Category: %s", config.shop_category))
        print(string.format("   Item: %s", config.item_to_buy))
        print(string.format("   Quantity: %d", quantity))
        
        local result = ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
        
        if result then
            success = true
            print("✅ Purchase request successful!")
        else
            warn("❌ Purchase request failed!")
        end
    end)
    
    return success
end

-- ============== MAIN EXECUTION ==============

print("\n⏳ Waiting for data to load...")
task.wait(3)

print("🔍 Detecting currency...")

local current_currency = get_currency_amount()

if current_currency == 0 then
    warn("❌ Could not detect currency!")
    warn(string.format("   Currency type: %s", config.currency_type))
    warn("\n   Available currencies:")
    
    -- Show what's available
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData then
            print("   Checking playerData...")
            for key, value in pairs(playerData) do
                if type(value) == "number" then
                    print(string.format("   - %s = %s", key, formatNumber(value)))
                end
            end
        end
    end)
    
    sendWebhook(string.format("❌ %s - Failed - Currency detection failed", playerName))
    
    print("\n🔴 Disabling account (currency detection failed)...")
    disableAccount()
    return
end

print(string.format("✅ Current %s: %s", config.currency_type, formatNumber(current_currency)))

-- Calculate purchase
local spendable = current_currency - config.reserve_currency

if spendable <= 0 then
    warn("❌ Not enough currency to buy anything!")
    warn(string.format("   Current: %s", formatNumber(current_currency)))
    warn(string.format("   Reserved: %s", formatNumber(config.reserve_currency)))
    sendWebhook(string.format("❌ %s - Insufficient funds (reserved too much)", playerName))
    
    print("\n🔴 Disabling account (insufficient currency)...")
    disableAccount()
    return
end

if spendable < config.item_price then
    warn("❌ Not enough currency for even 1 item!")
    warn(string.format("   Spendable: %s", formatNumber(spendable)))
    warn(string.format("   Item price: %s", formatNumber(config.item_price)))
    sendWebhook(string.format("❌ %s - Cannot afford item", playerName))
    
    print("\n🔴 Disabling account (cannot afford item)...")
    disableAccount()
    return
end

-- Calculate quantity
local quantity_to_buy = math.floor(spendable / config.item_price)
local total_cost = quantity_to_buy * config.item_price
local expected_leftover = current_currency - total_cost

print("\n" .. ("="):rep(60))
print("📊 PURCHASE CALCULATION")
print(("="):rep(60))
print(string.format("💰 Current %s: %s", config.currency_type, formatNumber(current_currency)))
print(string.format("🔒 Reserved: %s", formatNumber(config.reserve_currency)))
print(string.format("💸 Spendable: %s", formatNumber(spendable)))
print(string.format("🏷️  Price per item: %s", formatNumber(config.item_price)))
print(("─"):rep(60))
print(string.format("🛒 Will buy: %d items", quantity_to_buy))
print(string.format("💵 Total cost: %s", formatNumber(total_cost)))
print(string.format("💰 Expected leftover: %s", formatNumber(expected_leftover)))
print(("="):rep(60))

-- Confirmation
sendWebhook(string.format("🛒 %s - Starting purchase: %d items for %s %s", 
    playerName, quantity_to_buy, formatNumber(total_cost), config.currency_type))

-- Execute purchase
local success = buy_items(quantity_to_buy)

if success then
    print("\n⏳ Waiting for currency to update...")
    task.wait(3)
    
    local new_currency = get_currency_amount()
    local actual_spent = current_currency - new_currency
    
    print("\n" .. ("="):rep(60))
    print("✅ PURCHASE RESULT")
    print(("="):rep(60))
    print(string.format("📦 Items bought: %d", quantity_to_buy))
    print(string.format("💵 Currency spent: %s", formatNumber(actual_spent)))
    print(string.format("💰 Currency remaining: %s", formatNumber(new_currency)))
    print(string.format("📊 Price per item: %s", formatNumber(math.floor(actual_spent / quantity_to_buy))))
    print(("="):rep(60))
    
    sendWebhook(string.format("✅ %s - Purchase Complete!\n📦 Bought: %d items\n💵 Spent: %s\n💰 Remaining: %s", 
        playerName, quantity_to_buy, formatNumber(actual_spent), formatNumber(new_currency)))
    
    -- Disable account
    print("\n🔴 Disabling account...")
    disableAccount()
    
else
    warn("\n❌ Purchase failed!")
    warn("   Possible reasons:")
    warn("   - Item not available")
    warn("   - Shop error")
    warn("   - Incorrect item ID")
    
    sendWebhook(string.format("❌ %s - Purchase failed", playerName))
end

print("\n========================================")
print("✅ SCRIPT COMPLETE")
print("========================================")
