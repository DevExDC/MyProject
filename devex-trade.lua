-- ============================================
-- EXACT AMOUNT PET TRADER
-- Trades exact number of specific pets to one user
-- ============================================

-- ⚙️ CONFIGURATION
-- Set this BEFORE running the script using getgenv().TradeConfig

local CONFIG = getgenv().TradeConfig

if not CONFIG then
    error("❌ ERROR: No configuration found!\n\nPlease set getgenv().TradeConfig BEFORE loading the script.\n\nExample:\ngetgenv().TradeConfig = {\n    USERNAME = \"Player123\",\n    PET_NAME = \"Dog\",\n    AMOUNT = 50,\n    NEON_ONLY = false,\n    MEGA_ONLY = false,\n    FULL_GROWN_ONLY = false,\n    AUTO_KICK = true,\n    NORMAL_MODE = false,\n}\n")
end

-- Default AUTO_KICK to false if not set
if CONFIG.AUTO_KICK == nil then
    CONFIG.AUTO_KICK = false
end

-- Default NORMAL_MODE to false if not set (fast mode by default)
if CONFIG.NORMAL_MODE == nil then
    CONFIG.NORMAL_MODE = false
end

-- Default FULL_GROWN_ONLY to false if not set
if CONFIG.FULL_GROWN_ONLY == nil then
    CONFIG.FULL_GROWN_ONLY = false
end

-- Auto-detect mode
local MULTI_USER_MODE = CONFIG.USERNAMES and #CONFIG.USERNAMES > 0

if not MULTI_USER_MODE then
    -- Convert single user to list format for compatibility
    CONFIG.USERNAMES = {CONFIG.USERNAME}
    CONFIG.AMOUNTS = {CONFIG.AMOUNT}
end

-- Smart AMOUNTS handling
if #CONFIG.AMOUNTS == 1 and #CONFIG.USERNAMES > 1 then
    -- Single amount for all users - duplicate it
    local single_amount = CONFIG.AMOUNTS[1]
    CONFIG.AMOUNTS = {}
    for i = 1, #CONFIG.USERNAMES do
        CONFIG.AMOUNTS[i] = single_amount
    end
    print(string.format("ℹ️ Using same amount (%d) for all %d users", single_amount, #CONFIG.USERNAMES))
end

-- Validate
if #CONFIG.USERNAMES ~= #CONFIG.AMOUNTS then
    error("❌ ERROR: USERNAMES and AMOUNTS must have the same number of entries!\nYou have " .. #CONFIG.USERNAMES .. " usernames but " .. #CONFIG.AMOUNTS .. " amounts.")
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

-- ============================================
-- RESOLVE PET NAME TO KIND
-- ============================================

local function resolveItem(input)
    local db = require(ReplicatedStorage
        :WaitForChild("ClientDB")
        :WaitForChild("Inventory")
        :WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
        -- priority: kind match
        if v.kind and v.kind:lower() == search then
            return v.kind, v, "kind"
        end
        -- fallback: name match
        if not nameMatch and v.name and v.name:lower() == search then
            nameMatch = v
        end
    end

    if nameMatch then
        return nameMatch.kind, nameMatch, "name"
    end

    return nil
end

print("🔍 Resolving pet: " .. CONFIG.PET_NAME .. "...")
local resolved_kind, resolved_data = resolveItem(CONFIG.PET_NAME)

if not resolved_kind then
    error("❌ Could not resolve pet: " .. CONFIG.PET_NAME .. " — double check the name!")
end

CONFIG.PET_KIND = resolved_kind

print("✅ Resolved → Kind: " .. CONFIG.PET_KIND)

-- ============================================
-- HEADER
-- ============================================
print("\n===========================================")
print("  EXACT AMOUNT PET TRADER")
print("===========================================")
print("Pet Name:     " .. CONFIG.PET_NAME)
print("Pet Kind:     " .. CONFIG.PET_KIND)
print("Neon Only:    " .. tostring(CONFIG.NEON_ONLY))
print("Mega Only:    " .. tostring(CONFIG.MEGA_ONLY or false))
print("Full Grown:   " .. tostring(CONFIG.FULL_GROWN_ONLY))
print("Normal Mode:  " .. tostring(CONFIG.NORMAL_MODE))
print("Auto Kick:    " .. tostring(CONFIG.AUTO_KICK))
print("\nTrade Plan:")
for i, username in ipairs(CONFIG.USERNAMES) do
    print(string.format("  %d. %s → %d pets", i, username, CONFIG.AMOUNTS[i]))
end
print("===========================================\n")

-- ============================================
-- FUNCTIONS
-- ============================================

local function get_pets(count)
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        print(string.format("\n🔍 Searching for %d pets...", count))
        
        for _, pet in pairs(playerData.inventory.pets) do
            local shouldInclude = true
            
            -- Check pet kind
            if pet.kind ~= CONFIG.PET_KIND then
                shouldInclude = false
            end
            
            if shouldInclude then
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega_neon
                local pet_age = pet.properties and pet.properties.age or 0
                
                -- Full grown filter (must be age 6)
                if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                    shouldInclude = false
                end
                
                -- Filter logic
                if shouldInclude then
                    if CONFIG.MEGA_ONLY then
                        -- Only megas
                        if not is_mega then
                            shouldInclude = false
                        end
                    elseif CONFIG.NEON_ONLY then
                        -- Only neons (not megas)
                        if is_mega or not is_neon then
                            shouldInclude = false
                        end
                    else
                        -- Default: Only normals (skip neons and megas)
                        if is_neon or is_mega then
                            shouldInclude = false
                        end
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
    
    print(string.format("✅ Found %d pets", #pets))
    return pets
end

local function send_trade(username)
    local target = Players:FindFirstChild(username)
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
-- MAIN TRADING FUNCTION
-- ============================================

local function trade_to_user(username, amount)
    print("\n" .. ("="):rep(50))
    print(string.format("🎯 TRADING TO: %s (%d pets)", username, amount))
    print(("="):rep(50))
    
    -- Check if target player is in server
    local target = Players:FindFirstChild(username)
    if not target then
        print("❌ ERROR: Player '" .. username .. "' is not in this server!")
        return false
    end
    
    print("✅ Found player: " .. username)
    
    local BATCH_SIZE = 18
    local total_traded = 0
    local trade_number = 1
    
    while total_traded < amount do
        local remaining = amount - total_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        print(string.format("\n========== TRADE #%d ==========", trade_number))
        print(string.format("Progress: %d/%d pets traded", total_traded, amount))
        print(string.format("This batch: %d pets", this_batch))
        
        -- Get pets for this batch
        local pets = get_pets(this_batch)
        
        if #pets == 0 then
            print("\n❌ ERROR: No more pets available!")
            print(string.format("✅ Partial completion: %d/%d to %s", total_traded, amount, username))
            return false
        end
        
        if #pets < this_batch then
            print(string.format("⚠️ WARNING: Only found %d pets (needed %d)", #pets, this_batch))
            this_batch = #pets
        end
        
        -- Send trade request
        print(string.format("📤 Sending trade request to %s...", username))
        if not send_trade(username) then
            print("❌ Failed to send trade request!")
            task.wait(2)
            continue
        end
        
        task.wait(2)
        
        -- Wait for trade GUI
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local timeout = 0
        while not tradeGui.Visible and timeout < 10 do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        if timeout >= 10 then
            print("⚠️ Trade GUI didn't open, retrying...")
            task.wait(2)
            continue
        end
        
        -- Add pets to trade
        print(string.format("📦 Adding %d pets to trade...", #pets))
        local add_delay = CONFIG.NORMAL_MODE and 0.5 or 0.2
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            task.wait(add_delay)
        end
        
        -- Wait for countdown and accept
        print("⏳ Waiting for countdown (6 seconds)...")
        task.wait(6)
        
        if CONFIG.NORMAL_MODE then
            -- NORMAL MODE: Single accept/confirm with longer waits
            print("✅ Accepting trade...")
            accept_trade()
            task.wait(20)  -- 20 second wait before confirming
            
            print("✅ Confirming trade...")
            confirm_trade()
            
            -- Wait for trade to complete
            print("⏳ Waiting for trade to complete...")
            repeat
                task.wait(0.5)
            until not tradeGui.Visible
        else
            -- FAST MODE (DEFAULT): Spam accept/confirm
            print("✅ Accepting trade (spam mode)...")
            local accept_spam = true
            
            task.spawn(function()
                while accept_spam do
                    pcall(function()
                        accept_trade()
                    end)
                    task.wait(0.5)
                end
            end)
            
            task.wait(1)
            
            print("✅ Confirming trade (spam mode)...")
            local confirm_spam = true
            
            task.spawn(function()
                while confirm_spam do
                    pcall(function()
                        confirm_trade()
                    end)
                    task.wait(0.5)
                end
            end)
            
            -- Wait for trade to complete
            print("⏳ Waiting for trade to complete...")
            repeat
                task.wait(0.5)
            until not tradeGui.Visible
            
            -- Stop spamming
            accept_spam = false
            confirm_spam = false
        end
        
        -- Update progress
        total_traded = total_traded + this_batch
        trade_number = trade_number + 1
        
        print(string.format("✅ Trade #%d complete! Progress: %d/%d", trade_number - 1, total_traded, amount))
        
        if total_traded < amount then
            print("⏳ Waiting 2 seconds before next trade...")
            task.wait(2)
        end
    end
    
    print("\n" .. ("="):rep(50))
    print(string.format("✅ COMPLETE: Traded %d/%d to %s", total_traded, amount, username))
    print(("="):rep(50))
    
    return total_traded >= amount
end

local function trade_all_users()
    local total_users = #CONFIG.USERNAMES
    local successful = 0
    local failed = 0
    
    print("\n🚀 Starting multi-user trade process...")
    print(string.format("Total users: %d", total_users))
    
    for i, username in ipairs(CONFIG.USERNAMES) do
        local amount = CONFIG.AMOUNTS[i]
        
        print(string.format("\n[%d/%d] Processing: %s (%d pets)", i, total_users, username, amount))
        
        local success = trade_to_user(username, amount)
        
        if success then
            successful = successful + 1
        else
            failed = failed + 1
        end
        
        -- Wait between users
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
    print("\nDetails:")
    for i, username in ipairs(CONFIG.USERNAMES) do
        print(string.format("  %d. %s → %d pets", i, username, CONFIG.AMOUNTS[i]))
    end
    print(("="):rep(60))
    
    -- Auto-kick if enabled
    if CONFIG.AUTO_KICK then
        print("\n🔴 AUTO_KICK enabled - Kicking in 3 seconds...")
        task.wait(3)
        LocalPlayer:Kick("✅ Trading complete! All trades finished.")
    else
        print("\nℹ️ Auto-kick disabled. You can close the script manually.")
    end
end

-- ============================================
-- RUN
-- ============================================

trade_all_users()
