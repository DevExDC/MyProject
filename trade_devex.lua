--[[
    SUCCESS Auto-Trade Script - ALL ITEMS (PURE TRADE)
    Trades: Pets, Pet Wears, Toys, Food, Transport, Gifts, Strollers, Stickers
    v6.0.0 - Complete inventory support (NO auto-disable)
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- ============================================
-- CONFIGURATION
-- ============================================
getgenv().Config = getgenv().Config or {
    usernames = {},
    
    -- PETS
    pets_to_trade = {},
    trade_all_pets = false,
    
    -- PET WEARS (pet_accessories)
    pet_wears_to_trade = {},
    trade_all_pet_wears = false,
    
    -- TOYS
    toys_to_trade = {},
    trade_all_toys = false,
    
    -- FOOD
    food_to_trade = {},
    trade_all_food = false,
    
    -- TRANSPORT (vehicles)
    transport_to_trade = {},
    trade_all_transport = false,
    
    -- GIFTS
    gifts_to_trade = {},
    trade_all_gifts = false,
    
    -- STROLLERS
    strollers_to_trade = {},
    trade_all_strollers = false,
    
    -- STICKERS
    stickers_to_trade = {},
    trade_all_stickers = false,
    
    Webhook = ""
}

local config = getgenv().Config

local items_to_trade = {}
local trade_status = false

print("===========================================")
print("  SUCCESS Auto-Trade v6.0.0")
print("  ALL ITEMS (PURE TRADE)")
print("  NO AUTO-DISABLE")
print("===========================================")

-- Dehash
pcall(function()
    for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
        v.Name = i
    end
end)
print("✅ Dehashed remotes")

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

-- Auto-accept
local function setup_auto_accept()
    task.spawn(function()
        while task.wait(0.3) do
            pcall(function()
                local dialogApp = LocalPlayer.PlayerGui:FindFirstChild("DialogApp")
                if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Name ~= playerName then
                            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(player, true)
                        end
                    end
                end
            end)
        end
    end)
    
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
                end
            end)
        end
    end)
    
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
                end
            end)
        end
    end)
end

-- Trade functions
local function send_trade(username)
    local target = Players:FindFirstChild(username)
    if not target then return false end
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function add_item_to_trade(unique_id)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique_id)
end

-- ============================================
-- GET ITEMS FROM INVENTORY
-- ============================================
local function get_items_from_path(path_name, item_list, trade_all)
    local items = {}
    local counts = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory[path_name] then
            return
        end
        
        for _, item in pairs(playerData.inventory[path_name]) do
            if trade_all then
                table.insert(items, {unique = item.unique, kind = item.kind, type = path_name})
                counts[item.kind] = (counts[item.kind] or 0) + 1
            else
                for _, targetKind in ipairs(item_list) do
                    if item.kind == targetKind then
                        table.insert(items, {unique = item.unique, kind = item.kind, type = path_name})
                        counts[targetKind] = (counts[targetKind] or 0) + 1
                        break
                    end
                end
            end
        end
    end)
    
    return items, counts
end

-- Collect ALL items
local function collect_all_items()
    items_to_trade = {}
    local summary = {}
    
    -- Pets
    if #config.pets_to_trade > 0 or config.trade_all_pets then
        local items, counts = get_items_from_path("pets", config.pets_to_trade, config.trade_all_pets)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.pets = {total = #items, breakdown = counts} end
    end
    
    -- Pet Wears
    if #config.pet_wears_to_trade > 0 or config.trade_all_pet_wears then
        local items, counts = get_items_from_path("pet_accessories", config.pet_wears_to_trade, config.trade_all_pet_wears)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.pet_wears = {total = #items, breakdown = counts} end
    end
    
    -- Toys
    if #config.toys_to_trade > 0 or config.trade_all_toys then
        local items, counts = get_items_from_path("toys", config.toys_to_trade, config.trade_all_toys)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.toys = {total = #items, breakdown = counts} end
    end
    
    -- Food
    if #config.food_to_trade > 0 or config.trade_all_food then
        local items, counts = get_items_from_path("food", config.food_to_trade, config.trade_all_food)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.food = {total = #items, breakdown = counts} end
    end
    
    -- Transport
    if #config.transport_to_trade > 0 or config.trade_all_transport then
        local items, counts = get_items_from_path("transport", config.transport_to_trade, config.trade_all_transport)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.transport = {total = #items, breakdown = counts} end
    end
    
    -- Gifts
    if #config.gifts_to_trade > 0 or config.trade_all_gifts then
        local items, counts = get_items_from_path("gifts", config.gifts_to_trade, config.trade_all_gifts)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.gifts = {total = #items, breakdown = counts} end
    end
    
    -- Strollers
    if #config.strollers_to_trade > 0 or config.trade_all_strollers then
        local items, counts = get_items_from_path("strollers", config.strollers_to_trade, config.trade_all_strollers)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.strollers = {total = #items, breakdown = counts} end
    end
    
    -- Stickers
    if #config.stickers_to_trade > 0 or config.trade_all_stickers then
        local items, counts = get_items_from_path("stickers", config.stickers_to_trade, config.trade_all_stickers)
        for _, item in ipairs(items) do table.insert(items_to_trade, item) end
        if #items > 0 then summary.stickers = {total = #items, breakdown = counts} end
    end
    
    return summary
end

-- Print summary
local function print_summary(summary)
    print("\n📊 INVENTORY SUMMARY:")
    for category, data in pairs(summary) do
        print(string.format("   %s: %d items", category, data.total))
        for kind, count in pairs(data.breakdown) do
            print(string.format("      • %s: %d", kind, count))
        end
    end
    print(string.format("\n✅ Total items to trade: %d\n", #items_to_trade))
end

-- Auto-trade
local function autotrade(username)
    if trade_status or #items_to_trade == 0 then return false end
    
    local success_flag = false
    
    pcall(function()
        trade_status = true
        
        if not Players:FindFirstChild(username) then
            trade_status = false
            return false
        end
        
        local items_before = #items_to_trade
        
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        
        if not send_trade(username) then
            trade_status = false
            return false
        end
        
        task.wait(3)
        
        local timeout = 0
        while not tradeGui.Visible and timeout < 20 do
            if not Players:FindFirstChild(username) then
                trade_status = false
                return false
            end
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        if timeout >= 20 then
            trade_status = false
            return false
        end
        
        task.wait(1)
        
        -- Add items (max 18)
        local items_to_add = math.min(#items_to_trade, 18)
        print(string.format("📦 Adding %d items to trade...", items_to_add))
        
        for i = 1, items_to_add do
            if items_to_trade[i] then
                add_item_to_trade(items_to_trade[i].unique)
                task.wait(0.3)
            end
        end
        
        task.wait(2)
        task.wait(6)  -- Countdown
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
        task.wait(1)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
        
        timeout = 0
        while tradeGui.Visible and timeout < 30 do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        task.wait(2)
        
        -- Remove traded items
        for i = 1, items_to_add do
            table.remove(items_to_trade, 1)
        end
        
        print(string.format("✅ Traded %d items | Remaining: %d", items_to_add, #items_to_trade))
        success_flag = true
        
        trade_status = false
    end)
    
    return success_flag
end

-- Main
print("🤖 Starting auto-accept...")
setup_auto_accept()

local function find_available_holder()
    for _, username in ipairs(config.usernames) do
        if Players:FindFirstChild(username) then
            return username
        end
    end
    return nil
end

local selected_holder = find_available_holder()

if not selected_holder then
    sendWebhook(string.format("❌ %s - No holders in server", playerName))
    return
end

print(string.format("✅ Selected holder: %s\n", selected_holder))

-- Collect items
local summary = collect_all_items()

if #items_to_trade == 0 then
    print("❌ No items to trade!")
    sendWebhook(string.format("❌ %s - No items to trade", playerName))
    return
end

print_summary(summary)

local initial_count = #items_to_trade
local trades_needed = math.ceil(initial_count / 18)

print(string.format("🔄 Estimated trades: %d\n", trades_needed))

sendWebhook(string.format("🔄 %s - Starting: %d items to %s", playerName, initial_count, selected_holder))

-- Execute trades
local attempts = 0
local max_attempts = trades_needed + 10

while #items_to_trade > 0 and attempts < max_attempts do
    attempts = attempts + 1
    
    if not Players:FindFirstChild(selected_holder) then
        print("❌ Holder left!")
        break
    end
    
    local success = autotrade(selected_holder)
    
    if success then
        task.wait(3)
    else
        task.wait(5)
    end
end

local traded = initial_count - #items_to_trade

print("\n" .. ("="):rep(50))
print("✅ TRADING COMPLETE")
print(("="):rep(50))
print(string.format("   Traded: %d/%d items", traded, initial_count))
print(string.format("   To: %s", selected_holder))
print(("="):rep(50))

sendWebhook(string.format("✅ %s - COMPLETE - %d/%d items to %s", playerName, traded, initial_count, selected_holder))

print("\n✅ Script complete (no auto-disable)")
