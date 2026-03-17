-- ============================================
-- ULTIMATE PET TRADER
-- Single pet OR multiple pets mixed
-- Single user OR multiple users
-- Case-insensitive usernames and pet names
-- ============================================

-- ⚙️ CONFIGURATION EXAMPLES:

-- MODE 1: Single pet to single user
-- getgenv().TradeConfig = {
--     USERNAME = "Player123",
--     PET_NAME = "Dog",
--     AMOUNT = 50,
--     NEON_ONLY = false,
--     MEGA_ONLY = false,
--     FULL_GROWN_ONLY = false,
--     AUTO_KICK = true,
--     NORMAL_MODE = false,
-- }

-- MODE 2: Single pet to multiple users
-- getgenv().TradeConfig = {
--     USERNAMES = {"User1", "User2", "User3"},
--     PET_NAME = "Dog",
--     AMOUNTS = {50, 30, 20},
--     NEON_ONLY = false,
--     MEGA_ONLY = false,
--     FULL_GROWN_ONLY = false,
--     AUTO_KICK = true,
--     NORMAL_MODE = false,
-- }

-- MODE 3: Multiple pets (mixed) to single user
-- getgenv().TradeConfig = {
--     USERNAME = "Player123",
--     PET_NAMES = {"Dog", "Cat", "Pomeranian"},  -- All mixed together!
--     NEON_ONLY = false,
--     MEGA_ONLY = false,
--     FULL_GROWN_ONLY = false,
--     AUTO_KICK = true,
--     NORMAL_MODE = false,
-- }

-- MODE 4: Multiple pets with different amounts/filters
getgenv().TradeConfig = {
    USERNAME = "Player123",
    PETS = {
        {PET_NAME = "Dog", AMOUNT = 50, NEON_ONLY = false},
        {PET_NAME = "Cat"},  -- ALL cats
        {PET_NAME = "Pomeranian", AMOUNT = 20, NEON_ONLY = true},
    },
    FULL_GROWN_ONLY = false,
    AUTO_KICK = true,
    NORMAL_MODE = false,
}

local CONFIG = getgenv().TradeConfig

if not CONFIG then
    error("❌ ERROR: No configuration found!")
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
-- PET NAME RESOLVER (Case-insensitive)
-- ============================================
local function resolveItem(input)
    local db = require(ReplicatedStorage:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
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
-- DETECT MODE & BUILD PETS LIST
-- ============================================
local petsList = {}
local MIXED_MODE = false
local MULTI_USER_MODE = false

if CONFIG.PET_NAMES then
    -- MODE: Multiple pets mixed to single user
    MIXED_MODE = true
    for _, petName in ipairs(CONFIG.PET_NAMES) do
        table.insert(petsList, {
            PET_NAME = petName,
            NEON_ONLY = CONFIG.NEON_ONLY or false,
            MEGA_ONLY = CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PETS then
    -- MODE: Multiple pets with individual settings
    MIXED_MODE = true
    for _, petConfig in ipairs(CONFIG.PETS) do
        table.insert(petsList, {
            PET_NAME = petConfig.PET_NAME,
            AMOUNT = petConfig.AMOUNT,
            NEON_ONLY = petConfig.NEON_ONLY or CONFIG.NEON_ONLY or false,
            MEGA_ONLY = petConfig.MEGA_ONLY or CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PET_NAME then
    -- MODE: Single pet
    table.insert(petsList, {
        PET_NAME = CONFIG.PET_NAME,
        AMOUNT = CONFIG.AMOUNT,
        NEON_ONLY = CONFIG.NEON_ONLY or false,
        MEGA_ONLY = CONFIG.MEGA_ONLY or false,
    })
else
    error("❌ No pet configuration found! Use PET_NAME, PET_NAMES, or PETS")
end

-- Detect multi-user mode
if CONFIG.USERNAMES and #CONFIG.USERNAMES > 0 then
    MULTI_USER_MODE = true
else
    CONFIG.USERNAMES = {CONFIG.USERNAME}
    if CONFIG.AMOUNT then
        CONFIG.AMOUNTS = {CONFIG.AMOUNT}
    end
end

-- Smart AMOUNTS handling for multi-user
if MULTI_USER_MODE and CONFIG.AMOUNTS then
    if #CONFIG.AMOUNTS == 1 and #CONFIG.USERNAMES > 1 then
        local single_amount = CONFIG.AMOUNTS[1]
        CONFIG.AMOUNTS = {}
        for i = 1, #CONFIG.USERNAMES do
            CONFIG.AMOUNTS[i] = single_amount
        end
    end
    
    if #CONFIG.USERNAMES ~= #CONFIG.AMOUNTS then
        error("❌ ERROR: USERNAMES and AMOUNTS must have the same number of entries!")
    end
end

-- ============================================
-- RESOLVE ALL PET NAMES
-- ============================================
print("\n🔍 Resolving pet names...")
for i, petConfig in ipairs(petsList) do
    local resolved_kind, resolved_data = resolveItem(petConfig.PET_NAME)
    
    if not resolved_kind then
        error("❌ Could not resolve pet: " .. petConfig.PET_NAME)
    end
    
    petConfig.PET_KIND = resolved_kind
    print(string.format("  %d. %s → %s", i, petConfig.PET_NAME, resolved_kind))
end

-- ============================================
-- HEADER
-- ============================================
print("\n===========================================")
print("  ULTIMATE PET TRADER")
print("===========================================")
if MIXED_MODE then
    print("Mode:         MIXED PETS")
    print("Pet Types:    " .. #petsList)
    for i, pet in ipairs(petsList) do
        local amountText = pet.AMOUNT and tostring(pet.AMOUNT) or "ALL"
        local filterText = ""
        if pet.NEON_ONLY then filterText = " (neon)"
        elseif pet.MEGA_ONLY then filterText = " (mega)" end
        print(string.format("  %d. %s - %s%s", i, pet.PET_NAME, amountText, filterText))
    end
else
    print("Mode:         SINGLE PET")
    print("Pet Name:     " .. petsList[1].PET_NAME)
    print("Pet Kind:     " .. petsList[1].PET_KIND)
    print("Neon Only:    " .. tostring(petsList[1].NEON_ONLY))
    print("Mega Only:    " .. tostring(petsList[1].MEGA_ONLY))
end
print("Full Grown:   " .. tostring(CONFIG.FULL_GROWN_ONLY))
print("Normal Mode:  " .. tostring(CONFIG.NORMAL_MODE))
print("Auto Kick:    " .. tostring(CONFIG.AUTO_KICK))
print("\nTarget Users: " .. #CONFIG.USERNAMES)
for i, username in ipairs(CONFIG.USERNAMES) do
    local amountText = CONFIG.AMOUNTS and CONFIG.AMOUNTS[i] or "ALL PETS"
    print(string.format("  %d. %s → %s", i, username, amountText))
end
print("===========================================\n")

-- ============================================
-- PET COLLECTION FUNCTIONS
-- ============================================

-- For SINGLE pet mode
local function get_single_pet_type(petConfig, count)
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == petConfig.PET_KIND then
                local shouldInclude = true
                
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega_neon
                local pet_age = pet.properties and pet.properties.age or 0
                
                -- Full grown filter
                if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                    shouldInclude = false
                end
                
                -- Type filter
                if shouldInclude then
                    if petConfig.MEGA_ONLY then
                        if not is_mega then shouldInclude = false end
                    elseif petConfig.NEON_ONLY then
                        if is_mega or not is_neon then shouldInclude = false end
                    else
                        if is_neon or is_mega then shouldInclude = false end
                    end
                end
                
                if shouldInclude then
                    table.insert(pets, pet.unique)
                    if #pets >= count then break end
                end
            end
        end
    end)
    
    return pets
end

-- For MIXED pets mode
local function get_mixed_pets(batch_size, petTypeStats)
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            if #pets >= batch_size then break end
            
            for _, petConfig in ipairs(petsList) do
                if pet.kind == petConfig.PET_KIND then
                    local stats = petTypeStats[petConfig.PET_KIND]
                    
                    if stats.collected < stats.target then
                        local shouldInclude = true
                        
                        local is_neon = pet.properties and pet.properties.neon
                        local is_mega = pet.properties and pet.properties.mega_neon
                        local pet_age = pet.properties and pet.properties.age or 0
                        
                        -- Full grown filter
                        if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                            shouldInclude = false
                        end
                        
                        -- Type filter
                        if shouldInclude then
                            if petConfig.MEGA_ONLY then
                                if not is_mega then shouldInclude = false end
                            elseif petConfig.NEON_ONLY then
                                if is_mega or not is_neon then shouldInclude = false end
                            else
                                if is_neon or is_mega then shouldInclude = false end
                            end
                        end
                        
                        if shouldInclude then
                            table.insert(pets, {
                                unique = pet.unique,
                                kind = petConfig.PET_KIND,
                                name = petConfig.PET_NAME
                            })
                            stats.collected = stats.collected + 1
                            
                            if #pets >= batch_size then break end
                        end
                    end
                    
                    break
                end
            end
        end
    end)
    
    return pets
end

-- ============================================
-- TRADE FUNCTIONS
-- ============================================
local function send_trade(username)
    local target = findPlayer(username)
    if not target then
        print("❌ Player not found: " .. username)
        return false
    end
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

-- ============================================
-- SINGLE PET MODE TRADING
-- ============================================
local function trade_single_pet_to_user(username, amount)
    print("\n" .. ("="):rep(50))
    print(string.format("🎯 TRADING TO: %s (%d pets)", username, amount))
    print(("="):rep(50))
    
    local target = findPlayer(username)
    if not target then
        print("❌ ERROR: Player '" .. username .. "' is not in this server!")
        return false
    end
    
    print("✅ Found player: " .. target.Name)
    
    local BATCH_SIZE = 18
    local total_traded = 0
    local trade_number = 1
    
    while total_traded < amount do
        local remaining = amount - total_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        print(string.format("\n========== TRADE #%d ==========", trade_number))
        print(string.format("Progress: %d/%d pets traded", total_traded, amount))
        
        local pets = get_single_pet_type(petsList[1], this_batch)
        
        if #pets == 0 then
            print("\n❌ No more pets available!")
            return false
        end
        
        print(string.format("✅ Found %d pets", #pets))
        
        -- Send trade
        if not send_trade(username) then
            task.wait(2)
            continue
        end
        
        task.wait(2)
        
        -- Wait for GUI
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
        
        -- Add pets
        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for _, petUnique in ipairs(pets) do
            add_pet(petUnique)
            task.wait(add_delay)
        end
        
        -- Accept/Confirm
        task.wait(6)
        
        if CONFIG.NORMAL_MODE then
            accept_trade()
            task.wait(20)
            confirm_trade()
            repeat task.wait(0.5) until not tradeGui.Visible
        else
            local accept_spam = true
            task.spawn(function()
                while accept_spam do pcall(accept_trade) task.wait(0.5) end
            end)
            
            task.wait(1)
            
            local confirm_spam = true
            task.spawn(function()
                while confirm_spam do pcall(confirm_trade) task.wait(0.5) end
            end)
            
            repeat task.wait(0.5) until not tradeGui.Visible
            
            accept_spam = false
            confirm_spam = false
        end
        
        total_traded = total_traded + #pets
        trade_number = trade_number + 1
        
        print(string.format("✅ Trade complete! Progress: %d/%d", total_traded, amount))
        
        if total_traded < amount then
            task.wait(2)
        end
    end
    
    print(string.format("\n✅ COMPLETE: Traded %d to %s", total_traded, username))
    return true
end

-- ============================================
-- MIXED PETS MODE TRADING
-- ============================================
local function trade_mixed_pets_to_user(username)
    print("\n" .. ("="):rep(50))
    print(string.format("🎯 TRADING MIXED PETS TO: %s", username))
    print(("="):rep(50))
    
    local target = findPlayer(username)
    if not target then
        print("❌ ERROR: Player '" .. username .. "' is not in this server!")
        return false
    end
    
    print("✅ Found player: " .. target.Name)
    
    local BATCH_SIZE = 18
    local trade_number = 1
    local totalTraded = {}
    local petTypeStats = {}
    
    -- Initialize stats
    for _, petConfig in ipairs(petsList) do
        totalTraded[petConfig.PET_KIND] = 0
        petTypeStats[petConfig.PET_KIND] = {
            collected = 0,
            target = petConfig.AMOUNT or math.huge
        }
    end
    
    while true do
        print(string.format("\n========== TRADE #%d ==========", trade_number))
        
        local pets = get_mixed_pets(BATCH_SIZE, petTypeStats)
        
        if #pets == 0 then
            print("✅ No more pets to trade!")
            break
        end
        
        -- Count pets in batch
        local batchCount = {}
        for _, pet in ipairs(pets) do
            batchCount[pet.name] = (batchCount[pet.name] or 0) + 1
        end
        
        print(string.format("📦 Found %d pets:", #pets))
        for name, count in pairs(batchCount) do
            print(string.format("   - %s: %d", name, count))
        end
        
        -- Send trade
        if not send_trade(username) then
            task.wait(2)
            continue
        end
        
        task.wait(2)
        
        -- Wait for GUI
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
        
        -- Add pets
        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for _, pet in ipairs(pets) do
            add_pet(pet.unique)
            task.wait(add_delay)
        end
        
        -- Accept/Confirm
        task.wait(6)
        
        if CONFIG.NORMAL_MODE then
            accept_trade()
            task.wait(20)
            confirm_trade()
            repeat task.wait(0.5) until not tradeGui.Visible
        else
            local accept_spam = true
            task.spawn(function()
                while accept_spam do pcall(accept_trade) task.wait(0.5) end
            end)
            
            task.wait(1)
            
            local confirm_spam = true
            task.spawn(function()
                while confirm_spam do pcall(confirm_trade) task.wait(0.5) end
            end)
            
            repeat task.wait(0.5) until not tradeGui.Visible
            
            accept_spam = false
            confirm_spam = false
        end
        
        -- Update totals
        for _, pet in ipairs(pets) do
            totalTraded[pet.kind] = totalTraded[pet.kind] + 1
        end
        
        print(string.format("✅ Trade #%d complete!", trade_number))
        trade_number = trade_number + 1
        task.wait(2)
    end
    
    -- Summary
    print("\n" .. ("="):rep(50))
    print("✅ COMPLETE:")
    for _, petConfig in ipairs(petsList) do
        print(string.format("   %s: %d traded", petConfig.PET_NAME, totalTraded[petConfig.PET_KIND]))
    end
    print(("="):rep(50))
    
    return true
end

-- ============================================
-- MAIN EXECUTION
-- ============================================
local function run_trader()
    local total_users = #CONFIG.USERNAMES
    local successful = 0
    local failed = 0
    
    print("\n🚀 Starting trade process...")
    print(string.format("Total users: %d", total_users))
    
    for i, username in ipairs(CONFIG.USERNAMES) do
        print(string.format("\n[%d/%d] Processing: %s", i, total_users, username))
        
        local success
        if MIXED_MODE then
            success = trade_mixed_pets_to_user(username)
        else
            local amount = CONFIG.AMOUNTS[i]
            success = trade_single_pet_to_user(username, amount)
        end
        
        if success then
            successful = successful + 1
        else
            failed = failed + 1
        end
        
        if i < total_users then
            print("\n⏳ Waiting 3 seconds before next user...")
            task.wait(3)
        end
    end
    
    -- Final summary
    print("\n\n" .. ("="):rep(60))
    print("🎉 ALL TRADES COMPLETE!")
    print(("="):rep(60))
    print(string.format("Total users: %d", total_users))
    print(string.format("✅ Successful: %d", successful))
    print(string.format("❌ Failed: %d", failed))
    print(("="):rep(60))
    
    if CONFIG.AUTO_KICK then
        print("\n🔴 AUTO_KICK enabled - Kicking in 3 seconds...")
        task.wait(3)
        LocalPlayer:Kick("✅ Trading complete!")
    end
end

run_trader()
