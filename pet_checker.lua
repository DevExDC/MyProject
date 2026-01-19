-- ============================================
-- PET WEAR CHECKER - Discord Notifications
-- Checks for specific pet wears every 30 seconds
-- ============================================

if not getgenv().PetWearConfig then
    getgenv().PetWearConfig = {
        WEBHOOK_URL = "",
        WANTED_WEARS = {
            "icey_aura",           -- Example: Icey Aura
            "golden_crown",        -- Example: Golden Crown
            -- Add more pet wear IDs here
        },
        CHECK_INTERVAL = 30,       -- Check every 30 seconds
        NOTIFY_MODE = "once"       -- "once" = notify once | "always" = notify every check | "new" = only notify when first appears
    }
end

local CONFIG = getgenv().PetWearConfig

if CONFIG.WEBHOOK_URL == "" then
    error("❌ Set WEBHOOK_URL!")
end

if #CONFIG.WANTED_WEARS == 0 then
    error("❌ Set WANTED_WEARS!")
end

print("===========================================")
print("  PET WEAR CHECKER")
print("  Checking for wanted pet wears...")
print("===========================================")
print("Wanted wears: " .. #CONFIG.WANTED_WEARS)
print("Check interval: " .. CONFIG.CHECK_INTERVAL .. "s")
print("===========================================")

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- Dehash
print("🔧 Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("✅ Remotes dehashed!")

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Track what we've already notified about
local notified_wears = {}

local function sendWebhook(message)
    if CONFIG.WEBHOOK_URL == "" then return end
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
-- GET PET WEARS FROM INVENTORY
-- ============================================
local function get_pet_wears()
    local wears = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        
        -- Pet wears are in inventory.pet_accessories or inventory.accessories
        if playerData and playerData.inventory then
            -- Try pet_accessories first
            if playerData.inventory.pet_accessories then
                for _, wear in pairs(playerData.inventory.pet_accessories) do
                    table.insert(wears, {
                        kind = wear.kind,
                        unique = wear.unique
                    })
                end
            end
            
            -- Try accessories
            if playerData.inventory.accessories then
                for _, wear in pairs(playerData.inventory.accessories) do
                    table.insert(wears, {
                        kind = wear.kind,
                        unique = wear.unique
                    })
                end
            end
            
            -- Try pet_wear (alternate path)
            if playerData.inventory.pet_wear then
                for _, wear in pairs(playerData.inventory.pet_wear) do
                    table.insert(wears, {
                        kind = wear.kind,
                        unique = wear.unique
                    })
                end
            end
        end
    end)
    return wears
end

-- ============================================
-- CHECK FOR WANTED WEARS
-- ============================================
local function check_for_wanted_wears()
    local wears = get_pet_wears()
    local found_wears = {}
    
    print(string.format("\n🔍 Checking %d pet wears...", #wears))
    
    for _, wear in ipairs(wears) do
        -- Check if this wear is in our wanted list
        for _, wanted in ipairs(CONFIG.WANTED_WEARS) do
            if string.lower(wear.kind) == string.lower(wanted) then
                -- Check notification mode
                if CONFIG.NOTIFY_MODE == "once" then
                    -- Mode 1: Only notify once per wear
                    if notified_wears[wear.kind] then
                        print(string.format("   ℹ️  Found: %s (already notified)", wear.kind))
                    else
                        table.insert(found_wears, wear.kind)
                        notified_wears[wear.kind] = true
                        print(string.format("   ✅ FOUND: %s (first time!)", wear.kind))
                    end
                    
                elseif CONFIG.NOTIFY_MODE == "always" then
                    -- Mode 2: Always notify (spam mode)
                    table.insert(found_wears, wear.kind)
                    print(string.format("   ✅ FOUND: %s (notifying again)", wear.kind))
                    
                elseif CONFIG.NOTIFY_MODE == "new" then
                    -- Mode 3: Only notify when item first appears
                    if notified_wears[wear.kind] then
                        print(string.format("   ℹ️  Found: %s (silent mode)", wear.kind))
                    else
                        table.insert(found_wears, wear.kind)
                        notified_wears[wear.kind] = true
                        print(string.format("   🆕 NEW ITEM: %s", wear.kind))
                    end
                end
            end
        end
    end
    
    -- Send notification for newly found wears
    if #found_wears > 0 then
        local message = string.format("🎉 **FOUND WANTED PET WEAR!**\n\n**Account:** %s\n**Items Found:**", playerName)
        
        for _, wear_kind in ipairs(found_wears) do
            message = message .. string.format("\n• %s", wear_kind)
        end
        
        message = message .. string.format("\n\n*Found at: <t:%d:F>*", os.time())
        
        print("\n📨 Sending webhook notification...")
        sendWebhook(message)
        print("✅ Notification sent!")
    else
        print("   ❌ No wanted wears found")
    end
    
    return #found_wears > 0
end

-- ============================================
-- DEBUG: Print all pet wears
-- ============================================
local function debug_print_all_wears()
    print("\n" .. ("="):rep(50))
    print("🔍 DEBUG: All Pet Wears in Inventory")
    print(("="):rep(50))
    
    local wears = get_pet_wears()
    
    if #wears == 0 then
        print("❌ No pet wears found in inventory")
        print("\nℹ️  Possible inventory paths:")
        print("   • inventory.pet_accessories")
        print("   • inventory.accessories")
        print("   • inventory.pet_wear")
    else
        print(string.format("✅ Found %d pet wears:", #wears))
        for i, wear in ipairs(wears) do
            print(string.format("   %d. %s", i, wear.kind))
        end
    end
    
    print(("="):rep(50))
end

-- ============================================
-- MAIN LOOP
-- ============================================

print("\n✅ Starting pet wear checker...")
print(string.format("   Looking for: %s", table.concat(CONFIG.WANTED_WEARS, ", ")))
print(string.format("   Checking every %d seconds", CONFIG.CHECK_INTERVAL))

-- First check immediately
debug_print_all_wears()
task.wait(2)
check_for_wanted_wears()

-- Then check every X seconds
local check_count = 1
while task.wait(CONFIG.CHECK_INTERVAL) do
    check_count = check_count + 1
    print(string.format("\n========== Check #%d ==========", check_count))
    check_for_wanted_wears()
end
