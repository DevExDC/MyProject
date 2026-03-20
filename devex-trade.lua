-- ============================================
-- UNIVERSAL TRADER V4
-- Trade ANY category: pets, vehicles, toys, food, etc.
-- Supports category prefixes (1_ = pets, 2_ = vehicles, etc.)
-- ============================================

local CONFIG = getgenv().TradeConfig

if not CONFIG then
    error("❌ ERROR: No configuration found!\n\nPlease set getgenv().TradeConfig BEFORE loading the script.")
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

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Default settings
if CONFIG.AUTO_KICK == nil then CONFIG.AUTO_KICK = false end
if CONFIG.NORMAL_MODE == nil then CONFIG.NORMAL_MODE = false end
if CONFIG.FULL_GROWN_ONLY == nil then CONFIG.FULL_GROWN_ONLY = false end

-- ============================================
-- CATEGORY MAPPINGS
-- ============================================
local CATEGORY_MAP = {
    pets = "1",
    vehicles = "2",
    toys = "3",
    food = "4",
    gifts = "5",
    -- Add more as needed
}

-- ============================================
-- CASE-INSENSITIVE PLAYER FINDER
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
-- ITEM NAME RESOLVER (Any Category)
-- ============================================
local function resolveItem(input, category)
    local db = require(ReplicatedStorage:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
        -- Filter by category if specified
        if category and v.category and v.category:lower() ~= category:lower() then
            continue
        end
        
        if v.kind and v.kind:lower() == search then
            return v.kind, v, "kind"
        end
        if not nameMatch and v.name and v.name:lower() == search then
            nameMatch = v
        end
    end

    if nameMatch then
        return nameMatch.kind, nameMatch, "name"
    end

    return nil
end

-- ============================================
-- GET CATEGORY PREFIX FOR ITEM
-- ============================================
local function getCategoryPrefix(itemKind)
    -- Get item data
    local db = require(ReplicatedStorage:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    
    for _, v in pairs(db) do
        if v.kind == itemKind then
            local category = v.category or "pets"
            
            -- Map category name to number prefix
            if category:lower():find("pet") then return "1"
            elseif category:lower():find("vehicle") or category:lower():find("car") then return "2"
            elseif category:lower():find("toy") then return "3"
            elseif category:lower():find("food") then return "4"
            elseif category:lower():find("gift") then return "5"
            else return "1" end  -- Default to pets
        end
    end
    
    return "1"  -- Default
end

-- ============================================
-- COUNT ITEMS OF SPECIFIC KIND
-- ============================================
local function countItems(itemKind, category)
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory then return end
        
        -- Determine which inventory to check
        local inventoryKey = "pets"  -- default
        if category then
            if category:lower():find("vehicle") then inventoryKey = "vehicles"
            elseif category:lower():find("toy") then inventoryKey = "toys"
            elseif category:lower():find("food") then inventoryKey = "food"
            elseif category:lower():find("gift") then inventoryKey = "gifts"
            end
        end
        
        local items = playerData.inventory[inventoryKey]
        if not items then return end
        
        for _, item in pairs(items) do
            if item.kind == itemKind then
                count = count + 1
            end
        end
    end)
    return count
end

-- ============================================
-- GET ITEMS WITH FILTERS
-- ============================================
local function getFilteredItems(itemKind, filters, category)
    local items = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory then return end
        
        -- Determine inventory key
        local inventoryKey = "pets"
        if category then
            if category:lower():find("vehicle") then inventoryKey = "vehicles"
            elseif category:lower():find("toy") then inventoryKey = "toys"
            elseif category:lower():find("food") then inventoryKey = "food"
            elseif category:lower():find("gift") then inventoryKey = "gifts"
            end
        end
        
        local inventory = playerData.inventory[inventoryKey]
        if not inventory then return end
        
        for _, item in pairs(inventory) do
            if item.kind == itemKind then
                local props = item.properties or {}
                
                -- Apply filters
                if filters.NEON_ONLY and not props.neon then continue end
                if filters.MEGA_ONLY and not props.mega_neon then continue end
                if filters.FULL_GROWN_ONLY and (props.age or 0) ~= 6 then continue end
                
                table.insert(items, item.unique)
            end
        end
    end)
    
    return items
end

-- ============================================
-- DETECT MODE & BUILD ITEMS LIST
-- ============================================
local itemsList = {}
local MIXED_MODE = false
local MULTI_USER_MODE = false

if CONFIG.ITEM_NAMES then
    -- MODE: Multiple items mixed
    MIXED_MODE = true
    for _, itemName in ipairs(CONFIG.ITEM_NAMES) do
        table.insert(itemsList, {
            ITEM_NAME = itemName,
            CATEGORY = CONFIG.CATEGORY,
            NEON_ONLY = CONFIG.NEON_ONLY or false,
            MEGA_ONLY = CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.ITEMS then
    -- MODE: Custom items configuration
    for _, itemConfig in ipairs(CONFIG.ITEMS) do
        table.insert(itemsList, {
            ITEM_NAME = itemConfig.NAME,
            CATEGORY = itemConfig.CATEGORY,
            AMOUNT = itemConfig.AMOUNT,
            NEON_ONLY = itemConfig.NEON_ONLY or false,
            MEGA_ONLY = itemConfig.MEGA_ONLY or false,
        })
    end
else
    -- MODE: Single item type
    table.insert(itemsList, {
        ITEM_NAME = CONFIG.ITEM_NAME or CONFIG.PET_NAME,
        CATEGORY = CONFIG.CATEGORY,
        AMOUNT = CONFIG.AMOUNT,
        NEON_ONLY = CONFIG.NEON_ONLY or false,
        MEGA_ONLY = CONFIG.MEGA_ONLY or false,
    })
end

-- Check for multi-user mode
if CONFIG.USERNAMES then
    MULTI_USER_MODE = true
end

-- ============================================
-- HEADER
-- ============================================
print("===========================================")
print("  🔄 UNIVERSAL TRADER V4")
print("  Trade any category: pets, vehicles, toys")
print("===========================================")

if MIXED_MODE then
    print("🎯 MODE: Mixed Items")
    print("Items: " .. table.concat(CONFIG.ITEM_NAMES or CONFIG.PET_NAMES, ", "))
    print("To: " .. CONFIG.USERNAME)
elseif MULTI_USER_MODE then
    print("🎯 MODE: Multi-User")
    print("Users: " .. #CONFIG.USERNAMES)
    print("Item: " .. (CONFIG.ITEM_NAME or CONFIG.PET_NAME))
else
    print("🎯 MODE: Single Item, Single User")
    print("To: " .. CONFIG.USERNAME)
    print("Item: " .. (CONFIG.ITEM_NAME or CONFIG.PET_NAME))
    print("Amount: " .. CONFIG.AMOUNT)
end

print("===========================================")

-- ============================================
-- TRADE FUNCTIONS
-- ============================================

local function requestTrade(player)
    local success = false
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/RequestTrade"):InvokeServer(player, {})
        success = true
    end)
    return success
end

local function openTradeGUI()
    local success = false
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/OpenTradingUI"):InvokeServer({})
        success = true
    end)
    return success
end

local function addItemToTrade(itemUnique, categoryPrefix)
    local success = false
    pcall(function()
        local itemId = categoryPrefix .. "_" .. itemUnique
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(itemId)
        success = true
    end)
    return success
end

local function acceptTrade()
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptTradeRequest"):FireServer()
    end)
end

local function confirmTrade()
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer({})
    end)
end

-- ============================================
-- MAIN TRADING LOGIC
-- ============================================
local function tradeToUser(username, itemName, amount, filters, category)
    print(string.format("\n🎯 Starting trade to: %s", username))
    print(string.format("📦 Item: %s | Amount: %d", itemName, amount))
    
    -- Resolve item
    local itemKind, itemData = resolveItem(itemName, category)
    if not itemKind then
        print("❌ Could not resolve item: " .. itemName)
        return false
    end
    
    -- Get category prefix
    local categoryPrefix = getCategoryPrefix(itemKind)
    print(string.format("📁 Category prefix: %s", categoryPrefix))
    
    -- Get filtered items
    local availableItems = getFilteredItems(itemKind, filters, category)
    print(string.format("✅ Found %d items available", #availableItems))
    
    if #availableItems < amount then
        print(string.format("⚠️ Warning: Only have %d items, need %d", #availableItems, amount))
    end
    
    local totalTraded = 0
    local tradeCount = 0
    
    while totalTraded < amount do
        tradeCount = tradeCount + 1
        print(string.format("\n--- Trade #%d ---", tradeCount))
        
        -- Find player
        local targetPlayer = findPlayer(username)
        while not targetPlayer do
            print("⏳ Waiting for player...")
            task.wait(5)
            targetPlayer = findPlayer(username)
        end
        
        -- Request trade
        print("📤 Requesting trade...")
        while not requestTrade(targetPlayer) do
            task.wait(1)
        end
        task.wait(2)
        
        -- Open GUI
        print("🖥️ Opening trade GUI...")
        while not openTradeGUI() do
            task.wait(10)
        end
        task.wait(2)
        
        -- Add items
        local neededThisTrade = math.min(4, amount - totalTraded)
        print(string.format("➕ Adding %d items...", neededThisTrade))
        
        local addedCount = 0
        for i = totalTraded + 1, totalTraded + neededThisTrade do
            if availableItems[i] then
                if addItemToTrade(availableItems[i], categoryPrefix) then
                    addedCount = addedCount + 1
                    if not CONFIG.NORMAL_MODE then
                        task.wait(0.2)
                    else
                        task.wait(3)
                    end
                end
            end
        end
        
        print(string.format("✅ Added %d items", addedCount))
        
        -- Accept & Confirm
        task.wait(2)
        print("✅ Accepting trade...")
        
        if CONFIG.NORMAL_MODE then
            acceptTrade()
            task.wait(20)
            confirmTrade()
            task.wait(5)
        else
            for i = 1, 20 do
                acceptTrade()
                confirmTrade()
                task.wait(0.1)
            end
            task.wait(3)
        end
        
        totalTraded = totalTraded + addedCount
        print(string.format("📊 Progress: %d/%d", totalTraded, amount))
    end
    
    print(string.format("✅ COMPLETE! Traded %d items to %s", totalTraded, username))
    return true
end

-- ============================================
-- EXECUTE TRADES
-- ============================================

if MULTI_USER_MODE then
    -- Multi-user mode
    for i, username in ipairs(CONFIG.USERNAMES) do
        local amount = CONFIG.AMOUNTS and CONFIG.AMOUNTS[i] or CONFIG.AMOUNT
        local filters = {
            NEON_ONLY = CONFIG.NEON_ONLY,
            MEGA_ONLY = CONFIG.MEGA_ONLY,
            FULL_GROWN_ONLY = CONFIG.FULL_GROWN_ONLY,
        }
        
        tradeToUser(username, CONFIG.ITEM_NAME or CONFIG.PET_NAME, amount, filters, CONFIG.CATEGORY)
    end
elseif MIXED_MODE then
    -- Mixed items mode - trade all items to one user
    for _, item in ipairs(itemsList) do
        local filters = {
            NEON_ONLY = item.NEON_ONLY,
            MEGA_ONLY = item.MEGA_ONLY,
            FULL_GROWN_ONLY = CONFIG.FULL_GROWN_ONLY,
        }
        
        local count = countItems(resolveItem(item.ITEM_NAME, item.CATEGORY), item.CATEGORY)
        if count > 0 then
            tradeToUser(CONFIG.USERNAME, item.ITEM_NAME, count, filters, item.CATEGORY)
        end
    end
else
    -- Single item, single user
    local filters = {
        NEON_ONLY = CONFIG.NEON_ONLY,
        MEGA_ONLY = CONFIG.MEGA_ONLY,
        FULL_GROWN_ONLY = CONFIG.FULL_GROWN_ONLY,
    }
    
    tradeToUser(CONFIG.USERNAME, CONFIG.ITEM_NAME or CONFIG.PET_NAME, CONFIG.AMOUNT, filters, CONFIG.CATEGORY)
end

-- ============================================
-- CLEANUP
-- ============================================

if CONFIG.AUTO_KICK then
    print("\n🔴 Auto-kick enabled - Kicking in 5s...")
    task.wait(5)
    LocalPlayer:Kick("Trading complete!")
end

print("\n✅ ALL TRADES COMPLETE!")
