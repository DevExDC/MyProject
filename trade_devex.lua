--[[
    SUCCESS Auto-Trade Script - PETS + PET WEARS + TRANSPORT + GIFTS
    Trades pets, pet wears, transport, and gifts together
    v6.0.0 - Added transport and gifts support (NO AUTO-DISABLE)
]]

repeat task.wait() until game:IsLoaded()

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
    pets_to_trade = {},
    pet_wears_to_trade = {},
    trade_all_pet_wears = false,
    transport_to_trade = {},
    trade_all_transport = false,
    gifts_to_trade = {},
    trade_all_gifts = false,
    Webhook = ""
}

local config = getgenv().Config

local pets_unique_ids = {}
local pet_wears_unique_ids = {}
local transport_unique_ids = {}
local gifts_unique_ids = {}
local trade_status = false

print("===========================================")
print("  SUCCESS Auto-Trade System v6.0.0")
print("  PETS + WEARS + TRANSPORT + GIFTS")
print("===========================================")

if #config.pets_to_trade > 0 then
    print("Pet Types to Trade:")
    for i, pet_kind in ipairs(config.pets_to_trade) do
        print(string.format("  [%d] %s", i, pet_kind))
    end
end

if config.trade_all_pet_wears then
    print("Pet Wears: ALL")
elseif #config.pet_wears_to_trade > 0 then
    print("Pet Wears to Trade:")
    for i, wear_kind in ipairs(config.pet_wears_to_trade) do
        print(string.format("  [%d] %s", i, wear_kind))
    end
end

if config.trade_all_transport then
    print("Transport: ALL")
elseif #config.transport_to_trade > 0 then
    print("Transport to Trade:")
    for i, trans_kind in ipairs(config.transport_to_trade) do
        print(string.format("  [%d] %s", i, trans_kind))
    end
end

if config.trade_all_gifts then
    print("Gifts: ALL")
elseif #config.gifts_to_trade > 0 then
    print("Gifts to Trade:")
    for i, gift_kind in ipairs(config.gifts_to_trade) do
        print(string.format("  [%d] %s", i, gift_kind))
    end
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

local function add_item_to_trade(unique_id)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique_id)
end

-- ============================================
-- GET ALL PET WEARS
-- ============================================
local function get_all_pet_wears()
    local all_wears = {}
    local wear_counts = {}
    local total_wear_count = 0
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory then return end
        
        local wear_inventory = playerData.inventory.pet_accessories 
                            or playerData.inventory.accessories 
                            or playerData.inventory.pet_wear
        
        if not wear_inventory then return end
        
        for _, wear in pairs(wear_inventory) do
            total_wear_count = total_wear_count + 1
        end
        
        if config.trade_all_pet_wears then
            for _, wear in pairs(wear_inventory) do
                table.insert(all_wears, wear.unique)
                wear_counts[wear.kind] = (wear_counts[wear.kind] or 0) + 1
            end
        else
            for _, wear in pairs(wear_inventory) do
                for _, targetKind in ipairs(config.pet_wears_to_trade) do
                    if wear.kind == targetKind then
                        table.insert(all_wears, wear.unique)
                        wear_counts[targetKind] = (wear_counts[targetKind] or 0) + 1
                        break
                    end
                end
            end
        end
    end)
    
    if total_wear_count > 0 then
        print(string.format("\n👗 Pet Wears Summary:"))
        print(string.format("   • Total pet wears: %d", total_wear_count))
        print(string.format("   • Matching target wears: %d", #all_wears))
        
        if #all_wears > 0 then
            print("   Breakdown by type:")
            for kind, count in pairs(wear_counts) do
                print(string.format("   • %s: %d", kind, count))
            end
        end
    end
    
    return all_wears, total_wear_count
end

-- ============================================
-- GET ALL TRANSPORT
-- ============================================
local function get_all_transport()
    local all_transport = {}
    local transport_counts = {}
    local total_transport_count = 0
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.transport then return end
        
        for _, vehicle in pairs(playerData.inventory.transport) do
            total_transport_count = total_transport_count + 1
        end
        
        if config.trade_all_transport then
            for _, vehicle in pairs(playerData.inventory.transport) do
                table.insert(all_transport, vehicle.unique)
                transport_counts[vehicle.kind] = (transport_counts[vehicle.kind] or 0) + 1
            end
        else
            for _, vehicle in pairs(playerData.inventory.transport) do
                for _, targetKind in ipairs(config.transport_to_trade) do
                    if vehicle.kind == targetKind then
                        table.insert(all_transport, vehicle.unique)
                        transport_counts[targetKind] = (transport_counts[targetKind] or 0) + 1
                        break
                    end
                end
            end
        end
    end)
    
    if total_transport_count > 0 then
        print(string.format("\n🚗 Transport Summary:"))
        print(string.format("   • Total transport: %d", total_transport_count))
        print(string.format("   • Matching target transport: %d", #all_transport))
        
        if #all_transport > 0 then
            print("   Breakdown by type:")
            for kind, count in pairs(transport_counts) do
                print(string.format("   • %s: %d", kind, count))
            end
        end
    end
    
    return all_transport, total_transport_count
end

-- ============================================
-- GET ALL GIFTS
-- ============================================
local function get_all_gifts()
    local all_gifts = {}
    local gift_counts = {}
    local total_gift_count = 0
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.gifts then return end
        
        for _, gift in pairs(playerData.inventory.gifts) do
            total_gift_count = total_gift_count + 1
        end
        
        if config.trade_all_gifts then
            for _, gift in pairs(playerData.inventory.gifts) do
                table.insert(all_gifts, gift.unique)
                gift_counts[gift.kind] = (gift_counts[gift.kind] or 0) + 1
            end
        else
            for _, gift in pairs(playerData.inventory.gifts) do
                for _, targetKind in ipairs(config.gifts_to_trade) do
                    if gift.kind == targetKind then
                        table.insert(all_gifts, gift.unique)
                        gift_counts[targetKind] = (gift_counts[targetKind] or 0) + 1
                        break
                    end
                end
            end
        end
    end)
    
    if total_gift_count > 0 then
        print(string.format("\n🎁 Gifts Summary:"))
        print(string.format("   • Total gifts: %d", total_gift_count))
        print(string.format("   • Matching target gifts: %d", #all_gifts))
        
        if #all_gifts > 0 then
            print("   Breakdown by type:")
            for kind, count in pairs(gift_counts) do
                print(string.format("   • %s: %d", kind, count))
            end
        end
    end
    
    return all_gifts, total_gift_count
end

-- Get ALL pets of ALL specified types
local function get_all_pets()
    local all_pets = {}
    local pet_counts = {}
    local total_inventory_count = 0
    
    for _, kind in ipairs(config.pets_to_trade) do
        pet_counts[kind] = 0
    end
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            total_inventory_count = total_inventory_count + 1
        end
        
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
    
    if total_inventory_count > 0 then
        print(string.format("\n📦 Pets Summary:"))
        print(string.format("   • Total pets in inventory: %d", total_inventory_count))
        print(string.format("   • Matching target types: %d", #all_pets))
        
        if #all_pets > 0 then
            print("   Breakdown by type:")
            for kind, count in pairs(pet_counts) do
                if count > 0 then
                    print(string.format("   • %s: %d", kind, count))
                end
            end
        end
    end
    
    return all_pets, total_inventory_count
end

-- Count functions
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

local function count_pet_wears_in_inventory()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory then return end
        
        local wear_inventory = playerData.inventory.pet_accessories 
                            or playerData.inventory.accessories 
                            or playerData.inventory.pet_wear
        
        if not wear_inventory then return end
        
        if config.trade_all_pet_wears then
            for _ in pairs(wear_inventory) do
                count = count + 1
            end
        else
            for _, wear in pairs(wear_inventory) do
                for _, targetKind in ipairs(config.pet_wears_to_trade) do
                    if wear.kind == targetKind then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end)
    return count
end

local function count_transport_in_inventory()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.transport then return end
        
        if config.trade_all_transport then
            for _ in pairs(playerData.inventory.transport) do
                count = count + 1
            end
        else
            for _, vehicle in pairs(playerData.inventory.transport) do
                for _, targetKind in ipairs(config.transport_to_trade) do
                    if vehicle.kind == targetKind then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end)
    return count
end

local function count_gifts_in_inventory()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.gifts then return end
        
        if config.trade_all_gifts then
            for _ in pairs(playerData.inventory.gifts) do
                count = count + 1
            end
        else
            for _, gift in pairs(playerData.inventory.gifts) do
                for _, targetKind in ipairs(config.gifts_to_trade) do
                    if gift.kind == targetKind then
                        count = count + 1
                        break
                    end
                end
            end
        end
    end)
    return count
end

-- ============================================
-- AUTO-TRADE WITH ALL ITEMS
-- ============================================
local function autotrade(username)
    if trade_status then
        return false
    end
    
    local total_items = #pets_unique_ids + #pet_wears_unique_ids + #transport_unique_ids + #gifts_unique_ids
    
    if total_items == 0 then
        print("No items left to trade")
        return true
    end
    
    local success_flag = false
    
    pcall(function()
        trade_status = true
        
        local holder = Players:FindFirstChild(username)
        if not holder then
            warn(string.format("❌ %s is NOT in the server!", username))
            trade_status = false
            return false
        end
        
        local pets_before = count_pets_in_inventory()
        local wears_before = count_pet_wears_in_inventory()
        local transport_before = count_transport_in_inventory()
        local gifts_before = count_gifts_in_inventory()
        
        print(string.format("📦 Before - Pets: %d | Wears: %d | Transport: %d | Gifts: %d", 
            pets_before, wears_before, transport_before, gifts_before))
        
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        
        if not send_trade(username) then
            print("❌ Failed to send trade request")
            trade_status = false
            return false
        end
        
        print(string.format("📤 Trade request sent to %s", username))
        task.wait(3)
        
        print("⏳ Waiting for trade window to open...")
        local timeout = 0
        local max_wait = 20
        
        while not tradeGui.Visible and timeout < max_wait do
            if not Players:FindFirstChild(username) then
                warn(string.format("❌ %s left the game while waiting!", username))
                trade_status = false
                return false
            end
            
            task.wait(0.5)
            timeout = timeout + 0.5
            
            if timeout % 5 == 0 then
                print(string.format("   Still waiting... (%ds/%ds)", timeout, max_wait))
            end
        end
        
        if timeout >= max_wait then
            warn(string.format("⚠️ Trade window didn't open after %ds", max_wait))
            trade_status = false
            return false
        end
        
        print("✅ Trade window opened")
        task.wait(1)
        
        local items_to_add = math.min(total_items, 18)
        print(string.format("📦 Adding %d items to trade...", items_to_add))
        
        local items_added = 0
        
        -- Add pets
        for i = 1, #pets_unique_ids do
            if pets_unique_ids[i] and items_added < 18 then
                add_item_to_trade(pets_unique_ids[i])
                items_added = items_added + 1
                task.wait(0.3)
            end
        end
        
        -- Add pet wears
        for i = 1, #pet_wears_unique_ids do
            if pet_wears_unique_ids[i] and items_added < 18 then
                add_item_to_trade(pet_wears_unique_ids[i])
                items_added = items_added + 1
                task.wait(0.3)
            end
        end
        
        -- Add transport
        for i = 1, #transport_unique_ids do
            if transport_unique_ids[i] and items_added < 18 then
                add_item_to_trade(transport_unique_ids[i])
                items_added = items_added + 1
                task.wait(0.3)
            end
        end
        
        -- Add gifts
        for i = 1, #gifts_unique_ids do
            if gifts_unique_ids[i] and items_added < 18 then
                add_item_to_trade(gifts_unique_ids[i])
                items_added = items_added + 1
                task.wait(0.3)
            end
        end
        
        print(string.format("✅ Added %d items to trade", items_added))
        task.wait(2)
        
        print("⏱️ Waiting for 6-second countdown...")
        task.wait(6)
        
        print("✅ Clicking accept...")
        first_trade_accept()
        task.wait(1)
        
        print("✅ Confirming trade...")
        confirm_trade()
        
        print("⏳ Waiting for trade to complete...")
        timeout = 0
        max_wait = 30
        
        while tradeGui.Visible and timeout < max_wait do
            task.wait(0.5)
            timeout = timeout + 0.5
        end
        
        task.wait(2)
        
        local pets_after = count_pets_in_inventory()
        local wears_after = count_pet_wears_in_inventory()
        local transport_after = count_transport_in_inventory()
        local gifts_after = count_gifts_in_inventory()
        
        local pets_traded = pets_before - pets_after
        local wears_traded = wears_before - wears_after
        local transport_traded = transport_before - transport_after
        local gifts_traded = gifts_before - gifts_after
        
        print(string.format("📦 After - Pets: %d | Wears: %d | Transport: %d | Gifts: %d", 
            pets_after, wears_after, transport_after, gifts_after))
        print(string.format("✅ Traded - Pets: %d | Wears: %d | Transport: %d | Gifts: %d", 
            pets_traded, wears_traded, transport_traded, gifts_traded))
        
        if pets_traded > 0 or wears_traded > 0 or transport_traded > 0 or gifts_traded > 0 then
            for i = 1, pets_traded do table.remove(pets_unique_ids, 1) end
            for i = 1, wears_traded do table.remove(pet_wears_unique_ids, 1) end
            for i = 1, transport_traded do table.remove(transport_unique_ids, 1) end
            for i = 1, gifts_traded do table.remove(gifts_unique_ids, 1) end
            
            print(string.format("📋 Remaining - Pets: %d | Wears: %d | Transport: %d | Gifts: %d", 
                #pets_unique_ids, #pet_wears_unique_ids, #transport_unique_ids, #gifts_unique_ids))
            success_flag = true
        else
            warn("⚠️ No items traded! Refreshing lists...")
            pets_unique_ids, _ = get_all_pets()
            pet_wears_unique_ids, _ = get_all_pet_wears()
            transport_unique_ids, _ = get_all_transport()
            gifts_unique_ids, _ = get_all_gifts()
            success_flag = false
        end
        
        trade_status = false
    end)
    
    return success_flag
end

-- Main execution
print(string.format("\n📋 Configuration:"))
print(string.format("   • Holders: %s", table.concat(config.usernames, " or ")))
print(string.format("   • Pet Types: %d", #config.pets_to_trade))
print(string.format("   • Pet Wears: %s", config.trade_all_pet_wears and "ALL" or tostring(#config.pet_wears_to_trade)))
print(string.format("   • Transport: %s", config.trade_all_transport and "ALL" or tostring(#config.transport_to_trade)))
print(string.format("   • Gifts: %s", config.trade_all_gifts and "ALL" or tostring(#config.gifts_to_trade)))
print(string.format("   • Webhook: %s\n", config.Webhook ~= "" and "Enabled" or "Disabled"))

print("🤖 Starting auto-accept systems...")
setup_auto_accept()
setup_auto_negotiate()
setup_auto_confirm()
print("✅ Auto-accept enabled\n")

local function find_available_holder()
    for index, username in ipairs(config.usernames) do
        if Players:FindFirstChild(username) then
            print(string.format("✅ Found holder: %s (option %d)", username, index))
            return username
        else
            print(string.format("⚠️  %s not in game (option %d)", username, index))
        end
    end
    return nil
end

print("\n┌────────────────────────────────────┐")
print("│ 🔍 Searching for available holder...│")
print("└────────────────────────────────────┘")

local selected_holder = find_available_holder()

if not selected_holder then
    local all_usernames = table.concat(config.usernames, ", ")
    local error_msg = string.format("❌ NONE of the holders are in the server!\nTried: %s", all_usernames)
    warn(error_msg)
    sendWebhook(string.format("❌ %s - No holders in server (%s)", playerName, all_usernames))
    return
end

print(string.format("\n┌────────────────────────────────────┐"))
print(string.format("│ 📊 Selected Holder: %s", selected_holder))
print(string.format("└────────────────────────────────────┘"))

-- Get ALL items
pets_unique_ids, total_pets = get_all_pets()
pet_wears_unique_ids, total_wears = get_all_pet_wears()
transport_unique_ids, total_transport = get_all_transport()
gifts_unique_ids, total_gifts = get_all_gifts()

local total_items = #pets_unique_ids + #pet_wears_unique_ids + #transport_unique_ids + #gifts_unique_ids

if total_items == 0 then
    warn("❌ No items to trade!")
    sendWebhook(string.format("❌ %s - No items to trade", playerName))
    return
end

print(string.format("\n✅ Total items: %d (Pets: %d | Wears: %d | Transport: %d | Gifts: %d)", 
    total_items, #pets_unique_ids, #pet_wears_unique_ids, #transport_unique_ids, #gifts_unique_ids))

local initial_pet_count = #pets_unique_ids
local initial_wear_count = #pet_wears_unique_ids
local initial_transport_count = #transport_unique_ids
local initial_gift_count = #gifts_unique_ids

local tradesNeeded = math.ceil(total_items / 18)
print(string.format("\n🔄 Will need approximately %d trade(s)...\n", tradesNeeded))

local tradeAttempts = 0
local maxTrades = tradesNeeded + 10
local consecutiveFailures = 0
local maxConsecutiveFailures = 3

while total_items > 0 and tradeAttempts < maxTrades do
    tradeAttempts = tradeAttempts + 1
    total_items = #pets_unique_ids + #pet_wears_unique_ids + #transport_unique_ids + #gifts_unique_ids
    
    print(string.format("\n=== Trade Attempt %d ===", tradeAttempts))
    
    local holder = Players:FindFirstChild(selected_holder)
    if not holder then
        warn(string.format("❌ %s left the game!", selected_holder))
        local pets_traded = initial_pet_count - #pets_unique_ids
        local wears_traded = initial_wear_count - #pet_wears_unique_ids
        local transport_traded = initial_transport_count - #transport_unique_ids
        local gifts_traded = initial_gift_count - #gifts_unique_ids
        sendWebhook(string.format("❌ %s - Holder left - Pets: %d/%d | Wears: %d/%d | Transport: %d/%d | Gifts: %d/%d", 
            playerName, pets_traded, initial_pet_count, wears_traded, initial_wear_count,
            transport_traded, initial_transport_count, gifts_traded, initial_gift_count))
        break
    end
    
    local success = autotrade(selected_holder)
    
    if not success then
        consecutiveFailures = consecutiveFailures + 1
        
        if Players:FindFirstChild(selected_holder) then
            warn(string.format("⚠️ Trade failed (%d/%d consecutive)", consecutiveFailures, maxConsecutiveFailures))
            
            if consecutiveFailures >= maxConsecutiveFailures then
                warn("⚠️ Multiple failures - waiting longer...")
                task.wait(10)
                consecutiveFailures = 0
            else
                task.wait(5)
            end
        else
            warn(string.format("❌ %s left!", selected_holder))
            break
        end
    else
        consecutiveFailures = 0
        task.wait(3)
    end
end

local pets_traded = initial_pet_count - #pets_unique_ids
local wears_traded = initial_wear_count - #pet_wears_unique_ids
local transport_traded = initial_transport_count - #transport_unique_ids
local gifts_traded = initial_gift_count - #gifts_unique_ids
local total_traded = pets_traded + wears_traded + transport_traded + gifts_traded

print("\n┌────────────────────────────────────┐")
print("│ 🎉 Trading Session Complete!       │")
print(string.format("│ ✅ Traded to: %s", selected_holder))
print(string.format("│ ✅ Pets: %d", pets_traded))
print(string.format("│ ✅ Wears: %d", wears_traded))
print(string.format("│ ✅ Transport: %d", transport_traded))
print(string.format("│ ✅ Gifts: %d", gifts_traded))
print(string.format("│ ✅ Total: %d", total_traded))
print("└────────────────────────────────────┘\n")

sendWebhook(string.format("✅ %s - COMPLETE\nPets: %d | Wears: %d | Transport: %d | Gifts: %d | Total: %d to %s", 
    playerName, pets_traded, wears_traded, transport_traded, gifts_traded, total_traded, selected_holder))

print("\n========================================")
print("✅ SCRIPT COMPLETE")
print("========================================")
